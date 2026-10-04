import "dart:typed_data";
import "package:flutter/material.dart";
import "../../../core/network/api_client.dart";
import "../../../core/network/app_config.dart";
import "../data/wardrobe_repository.dart";
import "../models/wardrobe_item.dart";

class RecognitionResultPage extends StatefulWidget {
  const RecognitionResultPage(
      {super.key,
      required this.image,
      required this.originalImageUri,
      required this.candidate,
      this.cutoutUrl,
      this.repository});
  final Uint8List image;
  final String originalImageUri;
  final Map<String, dynamic> candidate;
  final String? cutoutUrl;
  final WardrobeRepository? repository;
  @override
  State<RecognitionResultPage> createState() => _RecognitionResultPageState();
}

class _RecognitionResultPageState extends State<RecognitionResultPage> {
  late final name =
      TextEditingController(text: widget.candidate["name"] as String);
  late final colorController =
      TextEditingController(text: widget.candidate["primaryColor"] as String);
  late final categoryLevel2 =
      TextEditingController(text: widget.candidate["categoryLevel2"] as String);
  late final material = TextEditingController(
      text: widget.candidate["material"] as String? ?? "");
  late final brand =
      TextEditingController(text: widget.candidate["brand"] as String? ?? "");
  late String category = widget.candidate["categoryLevel1"] as String;
  late String color = widget.candidate["primaryColor"] as String;
  @override
  void dispose() {
    name.dispose();
    colorController.dispose();
    categoryLevel2.dispose();
    material.dispose();
    brand.dispose();
    super.dispose();
  }

  bool saving = false;
  late final repository = widget.repository ??
      WardrobeRepository(ApiClient(baseUrl: AppConfig.apiBaseUrl));

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      await repository.createItem({
        ...Map<String, dynamic>.from(widget.candidate)
          ..remove("candidateId")
          ..remove("confidence")
          ..remove("uncertainFields"),
        "cutoutImageUrl": widget.candidate["cutoutImageUrl"],
        "material": material.text.trim(),
        "brand": brand.text.trim(),
        "name": name.text.trim().isEmpty ? "未命名单品" : name.text.trim(),
        "categoryLevel1": category,
        "categoryLevel2": categoryLevel2.text.trim().isEmpty
            ? "其他"
            : categoryLevel2.text.trim(),
        "primaryColor": colorController.text.trim().isEmpty
            ? "待确认"
            : colorController.text.trim(),
        "originalImageUrl": widget.originalImageUri,
        "managementStatus": "normal",
        "wearableStatus": "wearable",
      });
      if (!mounted) return;
      Navigator.pop(
          context,
          WardrobeItem(name.text.trim().isEmpty ? "未命名单品" : name.text.trim(),
              category, color, Icons.checkroom, const Color(0xFFE9DED0),
              image: widget.image));
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: const Text("识别结果"), backgroundColor: const Color(0xFFFAF8F4)),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Text("已识别 1 件单品，请确认并保存",
            style: TextStyle(color: Color(0xFF8C877F))),
        const SizedBox(height: 18),
        Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFEAE5DD))),
            child: Column(children: [
              Row(children: [
                ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: widget.cutoutUrl != null
                        ? Image.network(widget.cutoutUrl!,
                            width: 96, height: 110, fit: BoxFit.contain)
                        : Image.memory(widget.image,
                            width: 96, height: 110, fit: BoxFit.cover)),
                const SizedBox(width: 14),
                Expanded(
                    child: TextField(
                        controller: name,
                        decoration: const InputDecoration(labelText: "名称")))
              ]),
              const Divider(height: 26),
              DropdownButtonFormField(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: "分类"),
                  items: ["上装", "下装", "外套", "裙装", "鞋履", "包袋", "配饰"]
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => category = v!)),
              const SizedBox(height: 10),
              TextField(
                  controller: colorController,
                  onChanged: (v) => color = v,
                  decoration: const InputDecoration(labelText: "颜色")),
              TextField(
                  controller: categoryLevel2,
                  decoration: const InputDecoration(labelText: "细分类")),
              TextField(
                  controller: material,
                  decoration: const InputDecoration(labelText: "材质（请确认）")),
              TextField(
                  controller: brand,
                  decoration: const InputDecoration(labelText: "品牌（无法确认时留空）")),
              const SizedBox(height: 12),
              Text("季节：${(widget.candidate['seasons'] as List).join('、')}"),
              Text("风格：${(widget.candidate['styles'] as List).join('、')}"),
              Text("场景：${(widget.candidate['scenes'] as List).join('、')}"),
              Text(
                  "图案：${widget.candidate['pattern'] ?? ''} · 版型：${widget.candidate['fit'] ?? ''}"),
              if ((widget.candidate['uncertainFields'] as List?)?.isNotEmpty ==
                  true)
                Text(
                    "需人工确认：${(widget.candidate['uncertainFields'] as List).join('、')}"),
            ])),
        const SizedBox(height: 16),
        FilledButton(
            onPressed: saving ? null : _save,
            child: Text(saving ? "保存中..." : "保存并加入衣橱")),
      ]));
}
