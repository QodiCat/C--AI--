import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/app_config.dart';
import '../../ai_stylist/presentation/ai_stylist_page.dart';
import 'outfit_images.dart';

class MyOutfitsPage extends StatefulWidget {
  const MyOutfitsPage({super.key, this.client});
  final ApiClient? client;
  @override
  State<MyOutfitsPage> createState() => _MyOutfitsPageState();
}

class _MyOutfitsPageState extends State<MyOutfitsPage> {
  late final client = widget.client ?? ApiClient(baseUrl: AppConfig.apiBaseUrl);
  late OutfitCatalog catalog = OutfitCatalog(client);
  List<dynamic>? outfits;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final response = await client.get('/outfits');
      if (mounted) {
        setState(() {
          outfits = response['data'] as List;
          catalog = OutfitCatalog(client);
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> add(bool ai) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ai
            ? Scaffold(
                appBar: AppBar(title: const Text('AI 生成搭配')),
                body: const AiStylistPage())
            : ManualOutfitPage(client: client)));
    if (mounted) await load();
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
      onRefresh: load,
      child: ListView(padding: const EdgeInsets.all(20), children: [
        Text('我的搭配', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        Wrap(spacing: 12, children: [
          FilledButton.icon(
              onPressed: () => add(false),
              icon: const Icon(Icons.add),
              label: const Text('手动添加')),
          OutlinedButton.icon(
              onPressed: () => add(true),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('AI 生成')),
        ]),
        const SizedBox(height: 16),
        if (error != null) TextButton(onPressed: load, child: Text(error!)),
        if (outfits == null && error == null)
          const Center(child: CircularProgressIndicator()),
        if (outfits?.isEmpty == true)
          const Padding(
              padding: EdgeInsets.all(24),
              child: Text('还没有搭配，选择衣物组合或让 AI 帮你生成。')),
        ...?outfits?.map((raw) {
          final outfit = raw as Map<String, dynamic>;
          return Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            (outfit['name'] as String?)?.isNotEmpty == true
                                ? outfit['name'] as String
                                : '未命名搭配',
                            style: Theme.of(context).textTheme.titleLarge),
                        Text(outfit['source'] == 'manual' ? '手动搭配' : 'AI 搭配'),
                        Text([
                          outfit['scene'],
                          outfit['style'],
                          outfit['season']
                        ].where((v) => v != null && v != '').join(' · ')),
                        const SizedBox(height: 12),
                        OutfitImages(
                            ids: outfitItemIds(outfit['itemIds']),
                            catalog: catalog),
                      ])));
        }),
      ]));
}

class ManualOutfitPage extends StatefulWidget {
  const ManualOutfitPage({super.key, required this.client});
  final ApiClient client;
  @override
  State<ManualOutfitPage> createState() => _ManualOutfitPageState();
}

class _ManualOutfitPageState extends State<ManualOutfitPage> {
  late final catalog = OutfitCatalog(widget.client);
  final name = TextEditingController();
  final scene = TextEditingController();
  final style = TextEditingController();
  final selected = <String>{};
  bool saving = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    scene.dispose();
    style.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (name.text.trim().isEmpty || selected.length < 2) {
      setState(() => error = '填写搭配名称，并至少选择两件单品');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.client.post('/outfits', body: {
        'name': name.text.trim(),
        'scene': scene.text.trim(),
        'style': style.text.trim(),
        'itemIds': selected.toList()
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('手动添加搭配')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        TextField(
            controller: name,
            enabled: !saving,
            decoration: const InputDecoration(labelText: '搭配名称')),
        TextField(
            controller: scene,
            enabled: !saving,
            decoration: const InputDecoration(labelText: '场景（可选）')),
        TextField(
            controller: style,
            enabled: !saving,
            decoration: const InputDecoration(labelText: '风格（可选）')),
        const SizedBox(height: 16),
        Text('已选择 ${selected.length} 件'),
        if (selected.isNotEmpty)
          OutfitImages(ids: selected.toList(), catalog: catalog),
        const SizedBox(height: 16),
        FutureBuilder<List<Map<String, dynamic>>>(
            future: catalog.items(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Text('衣橱加载失败，请返回重试');
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = snapshot.data!
                  .where((item) =>
                      item['managementStatus'] == 'normal' &&
                      item['wearableStatus'] == 'wearable')
                  .toList();
              if (items.isEmpty) return const Text('暂无可穿衣物，请先添加到衣橱。');
              return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: items.map((item) {
                    final id = item['id'] as String;
                    return SizedBox(
                        width: 130,
                        child: Card(
                            color: selected.contains(id)
                                ? Theme.of(context)
                                    .colorScheme
                                    .secondaryContainer
                                : null,
                            child: InkWell(
                                key: ValueKey("outfit-item-$id"),
                                onTap: saving
                                    ? null
                                    : () => setState(() {
                                          if (!selected.add(id)) {
                                            selected.remove(id);
                                          }
                                        }),
                                child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Column(children: [
                                      GarmentImage(
                                          item: item, catalog: catalog),
                                      Text(item['name'] as String, maxLines: 2),
                                      Icon(selected.contains(id)
                                          ? Icons.check_circle
                                          : Icons.radio_button_unchecked)
                                    ])))));
                  }).toList());
            }),
        if (error != null)
          Text(error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        const SizedBox(height: 16),
        FilledButton(
            onPressed: saving ? null : save,
            child: Text(saving ? '保存中…' : '保存搭配')),
      ]));
}
