import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import 'outfit_images.dart';

class OutfitEditorPage extends StatefulWidget {
  const OutfitEditorPage(
      {super.key,
      required this.client,
      this.outfit,
      this.categories = const []});
  final ApiClient client;
  final Map<String, dynamic>? outfit;
  final List<String> categories;
  @override
  State<OutfitEditorPage> createState() => _OutfitEditorPageState();
}

class _OutfitEditorPageState extends State<OutfitEditorPage> {
  late final catalog = OutfitCatalog(widget.client);
  late final name =
      TextEditingController(text: widget.outfit?['name'] as String? ?? '');
  late final scene =
      TextEditingController(text: widget.outfit?['scene'] as String? ?? '');
  late final style =
      TextEditingController(text: widget.outfit?['style'] as String? ?? '');
  late final category =
      TextEditingController(text: widget.outfit?['category'] as String? ?? '');
  late final season =
      TextEditingController(text: widget.outfit?['season'] as String? ?? '');
  late final selected = outfitItemIds(widget.outfit?['itemIds']).toSet();
  bool saving = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    scene.dispose();
    style.dispose();
    category.dispose();
    season.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (name.text.trim().isEmpty ||
        selected.length < (widget.outfit == null ? 2 : 1)) {
      setState(() => error =
          widget.outfit == null ? '填写搭配名称，并至少选择两件单品' : '填写搭配名称，并至少保留一件单品');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final body = {
        'name': name.text.trim(),
        'scene': scene.text.trim(),
        'style': style.text.trim(),
        'category': category.text.trim(),
        'season': season.text.trim(),
        'itemIds': selected.toList(),
      };
      if (category.text.trim().length > 50) {
        setState(() => error = '分类名称最多 50 个字符');
        return;
      }
      if (widget.outfit == null) {
        await widget.client.post('/outfits', body: body);
      } else {
        await widget.client
            .patch('/outfits/${widget.outfit!['id']}', body: body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(widget.outfit == null ? '手动添加搭配' : '编辑搭配')),
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
        TextField(
            controller: season,
            enabled: !saving,
            decoration: const InputDecoration(labelText: '季节（可选）')),
        TextField(
            controller: category,
            enabled: !saving,
            maxLength: 50,
            decoration: const InputDecoration(
                labelText: '分类（可自定义）', hintText: '例如：上班、周末、运动')),
        if (widget.categories.isNotEmpty)
          Wrap(
              spacing: 8,
              children: widget.categories
                  .map((value) => ActionChip(
                      label: Text(value),
                      onPressed: saving
                          ? null
                          : () => setState(() => category.text = value)))
                  .toList()),
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
                          item['wearableStatus'] == 'wearable' ||
                      selected.contains(item['id']))
                  .toList();
              final availableIds =
                  snapshot.data!.map((item) => item['id']).toSet();
              items.addAll(selected
                  .where((id) => !availableIds.contains(id))
                  .map((id) => <String, dynamic>{
                        'id': id,
                        'name': '已删除单品（点击移除）',
                        'originalImageUrl': ''
                      }));
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
