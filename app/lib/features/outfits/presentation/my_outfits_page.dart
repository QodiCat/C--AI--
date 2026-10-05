import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/app_config.dart';
import '../../today_recommendation/presentation/today_recommendation_page.dart';
import 'outfit_images.dart';
import 'outfit_editor_page.dart';

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
  String? filter;
  final deleting = <String>{};
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
                appBar: AppBar(title: const Text('今日 AI 搭配')),
                body: TodayRecommendationPage(client: client))
            : OutfitEditorPage(client: client, categories: categories)));
    if (mounted) await load();
  }

  List<String> get categories => (outfits ?? [])
      .map((outfit) => outfit['category'] as String? ?? '')
      .where((category) => category.isNotEmpty)
      .toSet()
      .toList()
    ..sort();

  Future<void> edit(Map<String, dynamic> outfit) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => OutfitEditorPage(
          client: client, outfit: outfit, categories: categories),
    ));
    if (saved == true && mounted) await load();
  }

  Future<void> remove(Map<String, dynamic> outfit) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: const Text('删除搭配'),
              content: Text('确认删除“${outfit['name']}”？衣橱里的衣物和已有穿搭记录会保留。'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('取消')),
                FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('确认删除')),
              ],
            ));
    if (confirmed != true || !mounted) return;
    final id = outfit['id'] as String;
    setState(() => deleting.add(id));
    try {
      await client.delete('/outfits/$id');
      if (mounted) await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => deleting.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      body: RefreshIndicator(
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
                  label: const Text('今日 AI 搭配')),
            ]),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: [
              ChoiceChip(
                  label: const Text('全部'),
                  selected: filter == null,
                  onSelected: (_) => setState(() => filter = null)),
              ChoiceChip(
                  label: const Text('未分类'),
                  selected: filter == '',
                  onSelected: (_) => setState(() => filter = '')),
              ...categories.map((category) => ChoiceChip(
                  label: Text(category),
                  selected: filter == category,
                  onSelected: (_) => setState(() => filter = category))),
            ]),
            if (filter != null &&
                outfits != null &&
                !outfits!.any((o) => (o['category'] ?? '') == filter))
              const Padding(
                  padding: EdgeInsets.all(16), child: Text('这个分类还没有搭配')),
            if (error != null) TextButton(onPressed: load, child: Text(error!)),
            if (outfits == null && error == null)
              const Center(child: CircularProgressIndicator()),
            if (outfits?.isEmpty == true)
              const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('还没有搭配，选择衣物组合或让 AI 帮你生成。')),
            ...?outfits
                ?.where(
                    (o) => filter == null || (o['category'] ?? '') == filter)
                .map((raw) {
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
                            Text(outfit['source'] == 'manual'
                                ? '手动搭配'
                                : 'AI 搭配'),
                            Chip(
                                label: Text((outfit['category'] as String?)
                                            ?.isNotEmpty ==
                                        true
                                    ? outfit['category'] as String
                                    : '未分类')),
                            Text([
                              outfit['scene'],
                              outfit['style'],
                              outfit['season']
                            ].where((v) => v != null && v != '').join(' · ')),
                            const SizedBox(height: 12),
                            OutfitImages(
                                ids: outfitItemIds(outfit['itemIds']),
                                catalog: catalog),
                            Wrap(spacing: 8, children: [
                              TextButton.icon(
                                  key: ValueKey("edit-${outfit['id']}"),
                                  onPressed: deleting.contains(outfit['id'])
                                      ? null
                                      : () => edit(outfit),
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text('编辑')),
                              TextButton.icon(
                                  key: ValueKey("delete-${outfit['id']}"),
                                  onPressed: deleting.contains(outfit['id'])
                                      ? null
                                      : () => remove(outfit),
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('删除')),
                            ]),
                          ])));
            }),
          ])));
}
