import "dart:typed_data";

import "package:file_selector/file_selector.dart";
import "package:flutter/material.dart";

class WardrobeItem {
  const WardrobeItem(this.name, this.category, this.color, this.icon, this.tint,
      {this.image});
  final String name, category, color;
  final IconData icon;
  final Color tint;
  final Uint8List? image;
}

class WardrobePage extends StatefulWidget {
  const WardrobePage({super.key});
  @override
  State<WardrobePage> createState() => _WardrobePageState();
}

class _WardrobePageState extends State<WardrobePage> {
  String category = "全部";
  final search = TextEditingController();
  static const categories = ["全部", "上装", "下装", "外套", "裙装", "鞋履", "包袋", "配饰"];
  final items = <WardrobeItem>[
    const WardrobeItem(
        "米白色棉质衬衫", "上装", "米白", Icons.checkroom, Color(0xFFEDE1D1)),
    const WardrobeItem(
        "灰色针织上衣", "上装", "灰色", Icons.dry_cleaning, Color(0xFFD8D5D1)),
    const WardrobeItem(
        "复古直筒牛仔裤", "下装", "蓝色", Icons.straighten, Color(0xFFBCC9CF)),
    const WardrobeItem(
        "卡其色风衣", "外套", "卡其", Icons.dry_cleaning_outlined, Color(0xFFD7C4AA)),
    const WardrobeItem(
        "通勤手提包", "包袋", "米色", Icons.shopping_bag_outlined, Color(0xFFE4D5C3)),
    const WardrobeItem(
        "白色休闲鞋", "鞋履", "白色", Icons.roller_skating_outlined, Color(0xFFEAE7E0)),
    const WardrobeItem(
        "米白半身裙", "裙装", "米白", Icons.checkroom_outlined, Color(0xFFE8DED1)),
    const WardrobeItem(
        "黑色西装", "外套", "黑色", Icons.business_center_outlined, Color(0xFFBBB9B5)),
  ];

  List<WardrobeItem> get visibleItems => items.where((item) {
        final q = search.text.trim().toLowerCase();
        return (category == "全部" || item.category == category) &&
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
        if (visibleItems.isEmpty)
          const SliverFillRemaining(child: Center(child: Text("没有找到符合条件的衣物")))
        else
          SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                      (context, i) => _WardrobeCard(
                          item: visibleItems[i],
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      ItemDetailPage(item: visibleItems[i])))),
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
    const group =
        XTypeGroup(label: "图片", extensions: ["jpg", "jpeg", "png", "webp"]);
    final file = await openFile(acceptedTypeGroups: const [group]);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    final result = await Navigator.push<WardrobeItem>(context,
        MaterialPageRoute(builder: (_) => UploadProcessingPage(image: bytes)));
    if (result != null) setState(() => items.insert(0, result));
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
                const Wrap(spacing: 8, children: [
                  Chip(label: Text("春秋")),
                  Chip(label: Text("夏季")),
                  Chip(label: Text("冬季"))
                ]),
                const SizedBox(height: 16),
                OutlinedButton(
                    onPressed: () {
                      setState(() {
                        search.clear();
                        category = "全部";
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
                    child: item.image != null
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
  const UploadProcessingPage({super.key, required this.image});
  final Uint8List image;
  @override
  State<UploadProcessingPage> createState() => _UploadProcessingPageState();
}

class _UploadProcessingPageState extends State<UploadProcessingPage> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) {
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => RecognitionResultPage(image: widget.image)));
      }
    });
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
            _ProgressTile(image: widget.image, title: "上传中", value: .8),
            const SizedBox(height: 12),
            const _ProgressTile(
                icon: Icons.auto_awesome, title: "AI识别中", value: .6),
            const SizedBox(height: 12),
            const _ProgressTile(
                icon: Icons.content_cut, title: "智能抠图", value: .4),
            const Spacer(),
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
  final double value;
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
        Text("${(value * 100).round()}%",
            style: const TextStyle(color: Color(0xFF858078)))
      ]));
}

class RecognitionResultPage extends StatefulWidget {
  const RecognitionResultPage({super.key, required this.image});
  final Uint8List image;
  @override
  State<RecognitionResultPage> createState() => _RecognitionResultPageState();
}

class _RecognitionResultPageState extends State<RecognitionResultPage> {
  final name = TextEditingController(text: "米白色棉质衬衫");
  String category = "上装", color = "米白";
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
                    child: Image.memory(widget.image,
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
                  items: ["上装", "下装", "外套", "裙装", "鞋履", "包袋"]
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => category = v!)),
              const SizedBox(height: 10),
              TextField(
                  controller: TextEditingController(text: color),
                  onChanged: (v) => color = v,
                  decoration: const InputDecoration(labelText: "颜色")),
            ])),
        const SizedBox(height: 16),
        OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add),
            label: const Text("继续添加更多图片")),
        const SizedBox(height: 12),
        FilledButton(
            onPressed: () => Navigator.pop(
                context,
                WardrobeItem(
                    name.text.trim().isEmpty ? "未命名单品" : name.text.trim(),
                    category,
                    color,
                    Icons.checkroom,
                    const Color(0xFFE9DED0),
                    image: widget.image)),
            child: const Text("保存并加入衣橱")),
      ]));
}

class ItemDetailPage extends StatelessWidget {
  const ItemDetailPage({super.key, required this.item});
  final WardrobeItem item;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: const Text("单品详情"),
          centerTitle: true,
          backgroundColor: const Color(0xFFFAF8F4),
          actions: [TextButton(onPressed: () {}, child: const Text("保存"))]),
      body: ListView(children: [
        Container(
            height: 310,
            color: item.tint.withValues(alpha: .65),
            child: item.image != null
                ? Image.memory(item.image!, fit: BoxFit.contain)
                : Icon(item.icon, size: 175, color: const Color(0xFFA48C72))),
        ...[
          ("名称", item.name),
          ("分类", "${item.category}  ›  衣物"),
          ("颜色", item.color),
          ("品牌", "COS"),
          ("尺码", "M"),
          ("季节", "春秋"),
          ("风格", "通勤"),
          ("场景", "办公"),
          ("材质", "棉 100%"),
          ("购买价格", "¥ 399")
        ].map((e) => ListTile(
            tileColor: Colors.white,
            title: Text(e.$1),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(e.$2, style: const TextStyle(color: Color(0xFF77716A))),
              const Icon(Icons.chevron_right,
                  size: 19, color: Color(0xFFAAA49C))
            ]))),
        Padding(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              Expanded(
                  child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.local_laundry_service_outlined),
                      label: const Text("标记待清洗"))),
              const SizedBox(width: 8),
              Expanded(
                  child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.archive_outlined),
                      label: const Text("标记闲置"))),
              const SizedBox(width: 8),
              IconButton.outlined(
                  onPressed: () => Navigator.pop(context),
                  color: Colors.redAccent,
                  icon: const Icon(Icons.delete_outline))
            ])),
      ]));
}
