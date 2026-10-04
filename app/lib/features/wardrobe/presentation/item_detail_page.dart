import "package:flutter/material.dart";
import "../../../core/network/api_client.dart";
import "../../../core/network/app_config.dart";
import "../data/wardrobe_repository.dart";
import "dart:convert";
import "../models/wardrobe_item.dart";

class ItemDetailPage extends StatefulWidget {
  const ItemDetailPage({super.key, required this.item});
  final WardrobeItem item;
  @override
  State<ItemDetailPage> createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends State<ItemDetailPage> {
  final repository =
      WardrobeRepository(ApiClient(baseUrl: AppConfig.apiBaseUrl));
  bool saving = false;
  late final Map<String, dynamic> data = Map.from(widget.item.data);
  String field(String key) {
    final value = data[key];
    if (value == null || value == "" || value == "[]" || value == "null") {
      return "未填写";
    }
    if (["seasons", "styles", "scenes"].contains(key)) {
      try {
        return (jsonDecode(value as String) as List).join("、");
      } catch (_) {
        return "未填写";
      }
    }
    return value.toString();
  }

  Future<void> status(String management, String wearable) async {
    setState(() => saving = true);
    try {
      await repository.updateStatus(data["id"] as String, management, wearable);
      if (mounted) {
        setState(() {
          data["managementStatus"] = management;
          data["wearableStatus"] = wearable;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> remove() async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
                title: const Text("删除单品"),
                content: const Text("确认从衣橱中删除这件单品？"),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text("取消")),
                  FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text("删除"))
                ]));
    if (confirmed != true || !mounted) return;
    setState(() => saving = true);
    try {
      await repository.deleteItem(data["id"] as String);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text("单品详情")),
      body: ListView(children: [
        SizedBox(
            height: 310,
            child: widget.item.imageUrl != null
                ? Image.network(widget.item.imageUrl!, fit: BoxFit.contain)
                : const Icon(Icons.checkroom, size: 120)),
        for (final entry in {
          "名称": "name",
          "分类": "categoryLevel1",
          "细分类": "categoryLevel2",
          "颜色": "primaryColor",
          "品牌": "brand",
          "尺码": "size",
          "季节": "seasons",
          "风格": "styles",
          "场景": "scenes",
          "材质": "material",
          "图案": "pattern",
          "版型": "fit",
          "管理状态": "managementStatus",
          "可穿状态": "wearableStatus"
        }.entries)
          ListTile(title: Text(entry.key), subtitle: Text(field(entry.value))),
        Padding(
            padding: const EdgeInsets.all(20),
            child: Wrap(spacing: 8, children: [
              OutlinedButton(
                  onPressed: saving
                      ? null
                      : () => status(
                          data["managementStatus"] as String,
                          data["wearableStatus"] == "wearable"
                              ? "washing"
                              : "wearable"),
                  child: Text(
                      data["wearableStatus"] == "wearable" ? "标记待清洗" : "标记可穿")),
              OutlinedButton(
                  onPressed: saving
                      ? null
                      : () => status(
                          data["managementStatus"] == "normal"
                              ? "archived"
                              : "normal",
                          data["wearableStatus"] as String),
                  child: Text(
                      data["managementStatus"] == "normal" ? "归档" : "恢复使用")),
              IconButton(
                  onPressed: saving ? null : remove,
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.red),
            ])),
      ]));
}
