import "package:flutter/material.dart";

class WearHistoryPage extends StatelessWidget {
  const WearHistoryPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
          body: ListView(
              key: const ValueKey("wear-history-page"),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text("穿搭记录", style: Theme.of(context).textTheme.headlineMedium),
              IconButton.filledTonal(
                  onPressed: () => _record(context),
                  icon: const Icon(Icons.add))
            ]),
            const SizedBox(height: 5),
            const Text("记录每一天的穿搭，留下美好回忆",
                style: TextStyle(color: Color(0xFF8C8881))),
            const SizedBox(height: 22),
            Row(children: [
              IconButton(
                  onPressed: () {}, icon: const Icon(Icons.chevron_left)),
              const Expanded(
                  child: Text("2024年 5月",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700))),
              IconButton(
                  onPressed: () {}, icon: const Icon(Icons.chevron_right))
            ]),
            const SizedBox(height: 18),
            _WearCard(
                date: "20",
                weekday: "周一",
                weather: "晴 · 22°C",
                mood: "😊 不错",
                rating: 4,
                color: const Color(0xFFE9DED0),
                onTap: () => _detail(context)),
            const SizedBox(height: 14),
            _WearCard(
                date: "18",
                weekday: "周六",
                weather: "多云 · 20°C",
                mood: "😄 开心",
                rating: 5,
                color: const Color(0xFFDDE2D4),
                onTap: () => _detail(context)),
            const SizedBox(height: 14),
            _WearCard(
                date: "16",
                weekday: "周四",
                weather: "晴 · 24°C",
                mood: "😌 平静",
                rating: 4,
                color: const Color(0xFFE7E1D8),
                onTap: () => _detail(context)),
          ]));
  void _record(BuildContext c) => showModalBottomSheet(
      context: c,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (_) => const _RecordSheet());
  void _detail(BuildContext c) => Navigator.push(
      c, MaterialPageRoute(builder: (_) => const WearDetailPage()));
}

class _WearCard extends StatelessWidget {
  final String date, weekday, weather, mood;
  final int rating;
  final Color color;
  final VoidCallback onTap;
  const _WearCard(
      {required this.date,
      required this.weekday,
      required this.weather,
      required this.mood,
      required this.rating,
      required this.color,
      required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFECE7DF))),
          child: Row(children: [
            SizedBox(
                width: 42,
                child: Column(children: [
                  Text(date,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w800)),
                  Text(weekday,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF8A857E)))
                ])),
            const SizedBox(width: 10),
            Container(
                width: 90,
                height: 94,
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.checkroom,
                    size: 52, color: Color(0xFFB59A7B))),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(weather,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 9),
                  Text(mood),
                  const SizedBox(height: 9),
                  Row(
                      children: List.generate(
                          5,
                          (i) => Icon(
                              i < rating
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              size: 18,
                              color: const Color(0xFFE1B453))))
                ])),
            const Icon(Icons.chevron_right, color: Color(0xFFAAA59E)),
          ])));
}

class WearDetailPage extends StatelessWidget {
  const WearDetailPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: const Text("5月20日 · 穿搭详情"),
          backgroundColor: const Color(0xFFFAF8F4),
          elevation: 0,
          actions: [
            IconButton(onPressed: () {}, icon: const Icon(Icons.more_horiz))
          ]),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Container(
            height: 260,
            decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFFD9CCBC), Color(0xFFF0E8DD)]),
                borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.checkroom,
                size: 150, color: Color(0xFFA88C6C))),
        const SizedBox(height: 18),
        const Text("今天的穿搭",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Row(
            children: [
          Icons.checkroom,
          Icons.dry_cleaning,
          Icons.straighten,
          Icons.shopping_bag_outlined,
          Icons.directions_walk
        ]
                .map((i) => Expanded(
                    child: Container(
                        height: 62,
                        margin: const EdgeInsets.only(right: 7),
                        decoration: BoxDecoration(
                            color: const Color(0xFFF1ECE4),
                            borderRadius: BorderRadius.circular(12)),
                        child: Icon(i, color: const Color(0xFFB39878)))))
                .toList()),
        const SizedBox(height: 22),
        const _DetailLine(label: "心情", value: "😊 不错"),
        const _DetailLine(label: "评分", value: "★★★★☆", gold: true),
        const SizedBox(height: 10),
        const Text("备注", style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text("开会一整天，穿着很舒适，配色也很温柔，得到同事夸奖～",
            style: TextStyle(color: Color(0xFF69645E), height: 1.6)),
      ]));
}

class _DetailLine extends StatelessWidget {
  final String label, value;
  final bool gold;
  const _DetailLine(
      {required this.label, required this.value, this.gold = false});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        Text(value,
            style: TextStyle(
                color: gold ? const Color(0xFFE1B453) : const Color(0xFF57534E),
                fontSize: gold ? 20 : 14))
      ]));
}

class _RecordSheet extends StatefulWidget {
  const _RecordSheet();
  @override
  State<_RecordSheet> createState() => _RecordSheetState();
}

class _RecordSheetState extends State<_RecordSheet> {
  int mood = 2, rating = 4;
  @override
  Widget build(BuildContext context) => Padding(
      padding: EdgeInsets.fromLTRB(
          20, 18, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: SingleChildScrollView(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(
            child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFFD8D3CB),
                    borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 18),
        const Text("记录这套穿搭",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        Container(
            height: 92,
            decoration: BoxDecoration(
                color: const Color(0xFFF3EEE7),
                borderRadius: BorderRadius.circular(16)),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Icons.checkroom,
                  Icons.dry_cleaning,
                  Icons.straighten,
                  Icons.shopping_bag_outlined,
                  Icons.directions_walk
                ]
                    .map((i) =>
                        Icon(i, color: const Color(0xFFB19778), size: 34))
                    .toList())),
        const SizedBox(height: 18),
        const Text("今天心情", style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ["😞", "😐", "😊", "😄"]
                .asMap()
                .entries
                .map((e) => ChoiceChip(
                    label: Text(e.value, style: const TextStyle(fontSize: 20)),
                    selected: mood == e.key,
                    onSelected: (_) => setState(() => mood = e.key)))
                .toList()),
        const SizedBox(height: 18),
        const Text("穿搭评分", style: TextStyle(fontWeight: FontWeight.w700)),
        Row(
            children: List.generate(
                5,
                (i) => IconButton(
                    onPressed: () => setState(() => rating = i + 1),
                    icon: Icon(
                        i < rating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: const Color(0xFFE1B453),
                        size: 32)))),
        const TextField(
            maxLength: 100,
            maxLines: 2,
            decoration: InputDecoration(
                hintText: "记录一下今天的穿搭感受吧…",
                filled: true,
                fillColor: Color(0xFFF8F6F2),
                border: OutlineInputBorder(borderSide: BorderSide.none))),
        const SizedBox(height: 12),
        FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text("穿搭记录已保存")));
            },
            child: const Text("保存穿搭记录")),
      ])));
}
