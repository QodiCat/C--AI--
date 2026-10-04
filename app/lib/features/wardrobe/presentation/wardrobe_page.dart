import "dart:typed_data";
import "dart:convert";

import "package:image_picker/image_picker.dart";
import "package:flutter/material.dart";

import "../../../core/network/api_client.dart";
import "../../../core/network/app_config.dart";
import "../data/wardrobe_repository.dart";
import "batch_upload_page.dart";

class WardrobeItem {
  const WardrobeItem(this.name, this.category, this.color, this.icon, this.tint,
      {this.image, this.imageUrl, this.data = const {}});
  final String name, category, color;
  final IconData icon;
  final Color tint;
  final Uint8List? image;
  final String? imageUrl;
  final Map<String, dynamic> data;
}

class WardrobePage extends StatefulWidget {
  const WardrobePage({super.key});
  @override
  State<WardrobePage> createState() => _WardrobePageState();
}

class _WardrobePageState extends State<WardrobePage> {
  String category = "全部";
  String? season;
  final search = TextEditingController();
  static const categories = ["全部", "上装", "下装", "外套", "裙装", "鞋履", "包袋", "配饰"];
  final items = <WardrobeItem>[];
  bool loading = true;
  String? loadError;
  final repository =
      WardrobeRepository(ApiClient(baseUrl: AppConfig.apiBaseUrl));

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final rows = await repository.fetchItems();
      final loaded = <WardrobeItem>[];
      for (final row in rows) {
        final uri = (row["cutoutImageUrl"] as String?)?.isNotEmpty == true
            ? row["cutoutImageUrl"] as String
            : row["originalImageUrl"] as String;
        final imageUrl = await repository.resolveImage(uri);
        loaded.add(WardrobeItem(
            row["name"] as String,
            row["categoryLevel1"] as String,
            row["primaryColor"] as String,
            Icons.checkroom,
            const Color(0xFFE9DED0),
            imageUrl: imageUrl,
            data: Map<String, dynamic>.from(row as Map)));
      }
      if (mounted) {
        setState(() {
          items
            ..clear()
            ..addAll(loaded);
          loading = false;
          loadError = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          loading = false;
          loadError = "衣橱加载失败，请检查网络后重试";
        });
      }
    }
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  List<WardrobeItem> get visibleItems => items.where((item) {
        final q = search.text.trim().toLowerCase();
        return (category == "全部" || item.category == category) &&
            (season == null ||
                (item.data["seasons"] as String? ?? "[]").contains(season!)) &&
            (q.isEmpty ||
                item.name.toLowerCase().contains(q) ||
                item.color.contains(q));
      }).toList();

  @override
  Widget build(BuildContext context) => Scaffold(
          body:
              CustomScrollView(key: const ValueKey("wardrobe-page"), slivers: [
        SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            sliver: SliverToBoxAdapter(
                child: Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text("我的衣橱",
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 4),
                    Text("共 ${visibleItems.length} 件单品",
                        style: const TextStyle(color: Color(0xFF8B867F)))
                  ])),
              IconButton.filledTonal(
                  onPressed: _showAddChoices,
                  icon: const Icon(Icons.add),
                  tooltip: "添加衣物"),
            ]))),
        SliverToBoxAdapter(
            child: SizedBox(
                height: 46,
                child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 7),
                    itemBuilder: (_, i) {
                      final value = categories[i];
                      return ChoiceChip(
                          label: Text(value),
                          selected: category == value,
                          onSelected: (_) => setState(() => category = value),
                          showCheckmark: false,
                          selectedColor: const Color(0xFF718867),
                          labelStyle: TextStyle(
                              color: category == value
                                  ? Colors.white
                                  : const Color(0xFF615D57),
                              fontWeight: FontWeight.w600));
                    }))),
        SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            sliver: SliverToBoxAdapter(
                child: TextField(
                    controller: search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                        hintText: "搜索衣物名称、颜色…",
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                            icon: const Icon(Icons.tune),
                            onPressed: _showFilters),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                            borderSide: BorderSide.none,
                            borderRadius: BorderRadius.circular(14)))))),
        if (loading)
          const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()))
        else if (loadError != null)
          SliverFillRemaining(
              child: Center(
                  child: TextButton(
                      onPressed: _loadItems, child: Text(loadError!))))
        else if (visibleItems.isEmpty)
          const SliverFillRemaining(child: Center(child: Text("没有找到符合条件的衣物")))
        else
          SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                      (context, i) => _WardrobeCard(
                          item: visibleItems[i],
                          onTap: () async {
                            await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        ItemDetailPage(item: visibleItems[i])));
                            if (mounted) await _loadItems();
                          }),
                      childCount: visibleItems.length),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: .79,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12))),
      ]));

  Future<void> _showAddChoices() async {
    final source = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: const Color(0xFFFAF8F4),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
        builder: (c) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: const Color(0xFFD7D2CA),
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              const Text("添加衣物",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text("选择一种方式开始添加",
                  style: TextStyle(color: Color(0xFF8B867F))),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                    child: _AddChoice(
                        icon: Icons.photo_camera_outlined,
                        title: "拍照添加",
                        subtitle: "拍摄衣物照片\nAI自动识别与抠图",
                        onTap: () => Navigator.pop(c, "camera"))),
                const SizedBox(width: 12),
                Expanded(
                    child: _AddChoice(
                        icon: Icons.photo_library_outlined,
                        title: "从相册添加",
                        subtitle: "选择已有图片\n批量识别衣物",
                        onTap: () => Navigator.pop(c, "gallery")))
              ]),
            ])));
    if (source == null) return;
    try {
      final picker = ImagePicker();
      final List<XFile> files;
      if (source == "camera") {
        final file = await picker.pickImage(
            source: ImageSource.camera,
            maxWidth: 1900,
            maxHeight: 1900,
            imageQuality: 85);
        files = file == null ? [] : [file];
      } else {
        files = await picker.pickMultiImage(
            maxWidth: 1900, maxHeight: 1900, imageQuality: 85);
      }
      if (files.isEmpty || !mounted) return;
      if (files.length > 9) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("每批最多选择 9 张图片，请重新选择")));
        return;
      }
      final photos = <BatchPhoto>[];
      for (final file in files) {
        final bytes = await file.readAsBytes();
        if (bytes.length > 10 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("${file.name} 超过 10 MB，请重新选择")));
          }
          return;
        }
        final extension = file.name.split(".").last.toLowerCase();
        photos.add(BatchPhoto(
            bytes,
            file.name,
            extension == "png"
                ? "image/png"
                : extension == "webp"
                    ? "image/webp"
                    : "image/jpeg"));
      }
      if (!mounted) return;
      if (photos.length == 1) {
        final photo = photos.first;
        await Navigator.push<WardrobeItem>(
            context,
            MaterialPageRoute(
                builder: (_) => UploadProcessingPage(
                    image: photo.bytes,
                    fileName: photo.name,
                    contentType: photo.contentType)));
      } else {
        await Navigator.push<void>(context,
            MaterialPageRoute(builder: (_) => BatchUploadPage(photos: photos)));
      }
      if (mounted) await _loadItems();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("无法读取图片，请检查权限后重试")));
      }
    }
  }

  void _showFilters() => showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("搜索与筛选",
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 18),
                const Text("颜色", style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                    spacing: 8,
                    children: ["米白", "黑色", "灰色", "蓝色", "卡其"]
                        .map((e) => FilterChip(
                            label: Text(e),
                            selected: search.text == e,
                            onSelected: (_) {
                              setState(() => search.text = e);
                              Navigator.pop(c);
                            }))
                        .toList()),
                const SizedBox(height: 14),
                const Text("季节", style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                    spacing: 8,
                    children: ["春", "夏", "秋", "冬"]
                        .map((value) => ChoiceChip(
                            label: Text(value),
                            selected: season == value,
                            onSelected: (selected) {
                              setState(() => season = selected ? value : null);
                              Navigator.pop(c);
                            }))
                        .toList()),
                const SizedBox(height: 16),
                OutlinedButton(
                    onPressed: () {
                      setState(() {
                        search.clear();
                        category = "全部";
                        season = null;
                      });
                      Navigator.pop(c);
                    },
                    child: const Text("重置筛选")),
              ])));
}

class _WardrobeCard extends StatelessWidget {
  const _WardrobeCard({required this.item, required this.onTap});
  final WardrobeItem item;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
          onTap: onTap,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: Container(
                    width: double.infinity,
                    color: item.tint.withValues(alpha: .68),
                    child: item.imageUrl != null
                        ? Image.network(item.imageUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.broken_image_outlined))
                        : item.image != null
                            ? Image.memory(item.image!, fit: BoxFit.cover)
                            : Icon(item.icon,
                                size: 80, color: const Color(0xFF9F876E)))),
            Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text("${item.category} · ${item.color}",
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF8C877F)))
                    ])),
          ])));
}

class _AddChoice extends StatelessWidget {
  const _AddChoice(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 8),
              child: Column(children: [
                Icon(icon, size: 42, color: const Color(0xFF625E58)),
                const SizedBox(height: 15),
                Text(title,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 12, height: 1.5, color: Color(0xFF969088)))
              ]))));
}

class UploadProcessingPage extends StatefulWidget {
  const UploadProcessingPage(
      {super.key,
      required this.image,
      required this.fileName,
      required this.contentType});
  final Uint8List image;
  final String fileName;
  final String contentType;
  @override
  State<UploadProcessingPage> createState() => _UploadProcessingPageState();
}

class _UploadProcessingPageState extends State<UploadProcessingPage> {
  late final _repository =
      WardrobeRepository(ApiClient(baseUrl: AppConfig.apiBaseUrl));
  String? _error;

  @override
  void initState() {
    super.initState();
    _upload();
  }

  Future<void> _upload() async {
    setState(() => _error = null);
    try {
      final uri = await _repository.uploadImage(
          widget.image, widget.fileName, widget.contentType);
      final candidate = await _repository.recognizeImage(uri);
      final cutoutUrl =
          await _repository.resolveImage(candidate["cutoutImageUrl"] as String);
      if (!mounted) return;
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => RecognitionResultPage(
                  image: widget.image,
                  originalImageUri: uri,
                  candidate: candidate,
                  cutoutUrl: cutoutUrl)));
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = "上传失败，请检查网络后重试");
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: const Text("正在上传与识别"),
          backgroundColor: const Color(0xFFFAF8F4)),
      body: Padding(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("多层处理，稍等片刻", style: TextStyle(color: Color(0xFF8C877F))),
            const SizedBox(height: 22),
            _ProgressTile(image: widget.image, title: "上传中", value: null),
            const SizedBox(height: 12),
            const _ProgressTile(
                icon: Icons.auto_awesome, title: "AI识别中", value: null),
            const SizedBox(height: 12),
            const _ProgressTile(
                icon: Icons.content_cut, title: "智能抠图", value: null),
            const Spacer(),
            if (_error != null) ...[
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 10),
              FilledButton.icon(
                  onPressed: _upload,
                  icon: const Icon(Icons.refresh),
                  label: const Text("重新上传")),
            ] else
              const Center(
                  child: Text("识别完成后将自动进入确认页",
                      style: TextStyle(color: Color(0xFF8C877F)))),
            const SizedBox(height: 28),
          ])));
}

class _ProgressTile extends StatelessWidget {
  const _ProgressTile(
      {this.image, this.icon, required this.title, required this.value});
  final Uint8List? image;
  final IconData? icon;
  final String title;
  final double? value;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEAE5DD))),
      child: Row(children: [
        ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
                width: 72,
                height: 72,
                child: image != null
                    ? Image.memory(image!, fit: BoxFit.cover)
                    : ColoredBox(
                        color: const Color(0xFFF0EAE2),
                        child: Icon(icon, color: const Color(0xFFA28C73))))),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 11),
          LinearProgressIndicator(
              value: value,
              color: const Color(0xFF718867),
              backgroundColor: const Color(0xFFE6E3DD),
              borderRadius: BorderRadius.circular(4))
        ])),
        const SizedBox(width: 12),
        Text(value == null ? "处理中" : "${(value! * 100).round()}%",
            style: const TextStyle(color: Color(0xFF858078)))
      ]));
}

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
