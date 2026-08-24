import "dart:io";

import "package:file_selector/file_selector.dart";
import "package:flutter/material.dart";
import "../../../core/network/api_client.dart";
import "../../../core/network/app_config.dart";
import "../data/wardrobe_repository.dart";

class WardrobePage extends StatefulWidget {
  const WardrobePage({super.key});
  @override
  State<WardrobePage> createState() => _WardrobePageState();
}

class _WardrobePageState extends State<WardrobePage> {
  late final WardrobeRepository repo =
      WardrobeRepository(ApiClient(baseUrl: AppConfig.apiBaseUrl));
  final search = TextEditingController();
  String category = "全部";
  bool loading = true;
  String? error;
  List<dynamic> items = [];
  static const categories = ["全部", "上装", "下装", "裙装", "外套", "鞋履", "包袋", "配饰"];
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final value =
          await repo.fetchItems(query: search.text.trim(), category: category);
      if (mounted) setState(() => items = value);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> add() async {
    final name = TextEditingController(), color = TextEditingController();
    String kind = "上装";
    XFile? image;
    const imageTypes =
        XTypeGroup(label: "图片", extensions: ["jpg", "jpeg", "png", "webp"]);
    final ok = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setDialog) => AlertDialog(
                    title: const Text("录入单品"),
                    content: SizedBox(
                        width: 360,
                        child: SingleChildScrollView(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                              InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () async {
                                    final picked = await openFile(
                                        acceptedTypeGroups: [imageTypes]);
                                    if (context.mounted && picked != null) {
                                      setDialog(() => image = picked);
                                    }
                                  },
                                  child: Container(
                                      height: 180,
                                      width: double.infinity,
                                      clipBehavior: Clip.antiAlias,
                                      decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerHighest,
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      child: image == null
                                          ? const Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                  Icon(
                                                      Icons
                                                          .add_photo_alternate_outlined,
                                                      size: 48),
                                                  SizedBox(height: 8),
                                                  Text("点击选择衣物图片")
                                                ])
                                          : Stack(
                                              fit: StackFit.expand,
                                              children: [
                                                  Image.file(File(image!.path),
                                                      fit: BoxFit.cover),
                                                  Positioned(
                                                      right: 8,
                                                      bottom: 8,
                                                      child: FilledButton
                                                          .tonalIcon(
                                                              onPressed:
                                                                  () async {
                                                                final picked =
                                                                    await openFile(
                                                                        acceptedTypeGroups: [
                                                                      imageTypes
                                                                    ]);
                                                                if (context
                                                                        .mounted &&
                                                                    picked !=
                                                                        null) {
                                                                  setDialog(() =>
                                                                      image =
                                                                          picked);
                                                                }
                                                              },
                                                              icon: const Icon(
                                                                  Icons.edit),
                                                              label: const Text(
                                                                  "更换")))
                                                ]))),
                              const SizedBox(height: 12),
                              TextField(
                                  controller: name,
                                  decoration:
                                      const InputDecoration(labelText: "名称")),
                              TextField(
                                  controller: color,
                                  decoration:
                                      const InputDecoration(labelText: "主色")),
                              DropdownButtonFormField(
                                  initialValue: kind,
                                  items: categories
                                      .skip(1)
                                      .map((e) => DropdownMenuItem(
                                          value: e, child: Text(e)))
                                      .toList(),
                                  onChanged: (v) => setDialog(() => kind = v!),
                                  decoration:
                                      const InputDecoration(labelText: "分类"))
                            ]))),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text("取消")),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text("保存"))
                    ])));
    if (ok != true) return;
    if (image == null) {
      notice("请选择一张衣物图片");
      return;
    }
    if (name.text.trim().isEmpty) {
      notice("请输入单品名称");
      return;
    }
    try {
      await repo.createItem({
        "name": name.text.trim(),
        "categoryLevel1": kind,
        "categoryLevel2": "其他$kind",
        "primaryColor": color.text.trim().isEmpty ? "未设置" : color.text.trim(),
        "seasons": [],
        "styles": [],
        "scenes": [],
        "customTags": [],
        "originalImageUrl": Uri.file(image!.path).toString(),
        "managementStatus": "normal",
        "wearableStatus": "wearable"
      });
      await load();
    } catch (e) {
      notice(e.toString());
    }
  }

  void notice(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> menu(Map<String, dynamic> item, String action) async {
    try {
      if (action == "clean") {
        await repo.updateStatus(item["id"], item["managementStatus"],
            item["wearableStatus"] == "wearable" ? "cleaning" : "wearable");
      }
      if (action == "archive") {
        await repo.updateStatus(item["id"], "archived", item["wearableStatus"]);
      }
      if (!mounted) return;
      if (action == "delete") {
        final yes = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
                    title: const Text("删除单品？"),
                    content: const Text("历史搭配仍会保留，衣橱中将不再显示该单品。"),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text("取消")),
                      FilledButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text("删除"))
                    ]));
        if (!mounted) return;
        if (yes == true) await repo.deleteItem(item["id"]);
      }
      await load();
    } catch (e) {
      notice(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
      onRefresh: load,
      child: ListView(
          key: const ValueKey("wardrobe-page"),
          padding: const EdgeInsets.all(20),
          children: [
            Row(children: [
              Expanded(
                  child: Text("数字衣橱",
                      style: Theme.of(context).textTheme.headlineMedium)),
              FilledButton.icon(
                  onPressed: add,
                  icon: const Icon(Icons.add),
                  label: const Text("录入"))
            ]),
            const SizedBox(height: 16),
            TextField(
                controller: search,
                onSubmitted: (_) => load(),
                decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: "搜索名称、品牌或标签",
                    suffixIcon: IconButton(
                        onPressed: load,
                        icon: const Icon(Icons.arrow_forward)))),
            const SizedBox(height: 12),
            SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                    children: categories
                        .map((e) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                                label: Text(e),
                                selected: category == e,
                                onSelected: (_) {
                                  category = e;
                                  load();
                                })))
                        .toList())),
            const SizedBox(height: 16),
            if (loading)
              const Center(child: CircularProgressIndicator())
            else if (error != null)
              Center(child: Text("加载失败：$error"))
            else if (items.isEmpty)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.all(40), child: Text("还没有符合条件的单品")))
            else
              ...items.map((raw) {
                final item = raw as Map<String, dynamic>;
                final status =
                    item["wearableStatus"] == "wearable" ? "可穿" : "待清洗";
                return Card(
                    child: ListTile(
                        leading: _ItemThumbnail(
                            imageUrl: item["originalImageUrl"]?.toString(),
                            fallback: (item["name"] ?? "衣")
                                .toString()
                                .characters
                                .first),
                        title: Text(item["name"] ?? "未命名"),
                        subtitle: Text(
                            "${item["categoryLevel1"]} · ${item["primaryColor"]} · $status"),
                        trailing: PopupMenuButton<String>(
                            onSelected: (v) => menu(item, v),
                            itemBuilder: (_) => [
                                  PopupMenuItem(
                                      value: "clean",
                                      child: Text(
                                          status == "可穿" ? "标记待清洗" : "恢复可穿")),
                                  const PopupMenuItem(
                                      value: "archive", child: Text("归档")),
                                  const PopupMenuItem(
                                      value: "delete", child: Text("删除"))
                                ])));
              })
          ]));
}

class _ItemThumbnail extends StatelessWidget {
  const _ItemThumbnail({required this.imageUrl, required this.fallback});

  final String? imageUrl;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(imageUrl ?? "");
    Widget? image;
    if (uri?.scheme == "file") {
      image = Image.file(File.fromUri(uri!),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Center(child: Text(fallback)));
    } else if (uri?.scheme == "http" || uri?.scheme == "https") {
      image = Image.network(imageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Center(child: Text(fallback)));
    }

    return ClipOval(
        child: ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: SizedBox(
                width: 40,
                height: 40,
                child: image ?? Center(child: Text(fallback)))));
  }
}
