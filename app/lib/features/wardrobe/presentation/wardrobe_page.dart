import "package:image_picker/image_picker.dart";
import "package:flutter/material.dart";

import "../../../core/network/api_client.dart";
import "../../../core/network/app_config.dart";
import "../data/wardrobe_repository.dart";
import "../data/wardrobe_display_repository.dart";
import "../models/wardrobe_display_preferences.dart";
import "wardrobe_display_settings_page.dart";
import "batch_upload_page.dart";

import "../models/wardrobe_item.dart";
import "upload_processing_page.dart";
import "item_detail_page.dart";

class WardrobePage extends StatefulWidget {
  const WardrobePage({super.key, this.client});
  final ApiClient? client;
  @override
  State<WardrobePage> createState() => _WardrobePageState();
}

class _WardrobePageState extends State<WardrobePage> {
  String category = "全部";
  String? season;
  final search = TextEditingController();
  WardrobeDisplayPreferences display = const WardrobeDisplayPreferences();
  List<String> get categories => ["全部", ...display.visibleCategories];
  final items = <WardrobeItem>[];
  bool loading = true;
  String? loadError;
  late final client = widget.client ?? ApiClient(baseUrl: AppConfig.apiBaseUrl);
  late final repository = WardrobeRepository(client);
  late final displayRepository = WardrobeDisplayRepository(client);

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final responses = await Future.wait<dynamic>(
          [repository.fetchItems(), displayRepository.fetch()]);
      final rows = responses[0] as List<dynamic>;
      final preferences = responses[1] as WardrobeDisplayPreferences;
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
          display = preferences;
          if (!categories.contains(category)) category = "全部";
          if (season != null &&
              display.seasons.isNotEmpty &&
              !display.seasons.contains(season)) {
            season = null;
          }
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
        return display.matches(item.data) &&
            (category == "全部" || item.category == category) &&
            (season == null ||
                WardrobeDisplayPreferences.itemSeasons(item.data["seasons"])
                    .contains(season!)) &&
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
                    Text(display.summary),
                    Text("共 ${visibleItems.length} 件单品",
                        style: const TextStyle(color: Color(0xFF8B867F)))
                  ])),
              IconButton(
                  onPressed: loading ? null : _editDisplay,
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: "衣橱显示设置"),
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

  Future<void> _editDisplay() async {
    final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) =>
                WardrobeDisplaySettingsPage(repository: displayRepository)));
    if (saved == true && mounted) {
      await _loadItems();
    }
  }

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
                    children: (display.seasons.isEmpty
                            ? WardrobeDisplayPreferences.allSeasons
                            : display.seasons)
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
