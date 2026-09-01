import "package:flutter/material.dart";

class TodayRecommendationPage extends StatefulWidget {
  const TodayRecommendationPage({super.key});
  @override
  State<TodayRecommendationPage> createState() =>
      _TodayRecommendationPageState();
}

class _TodayRecommendationPageState extends State<TodayRecommendationPage> {
  int look = 0;
  static const looks = [
    [
      Icons.checkroom,
      Icons.dry_cleaning,
      Icons.straighten,
      Icons.shopping_bag_outlined,
      Icons.roller_skating_outlined
    ],
    [
      Icons.dry_cleaning_outlined,
      Icons.checkroom,
      Icons.dry_cleaning,
      Icons.work_outline,
      Icons.directions_walk
    ],
    [
      Icons.checkroom_outlined,
      Icons.dry_cleaning,
      Icons.straighten,
      Icons.shopping_bag,
      Icons.roller_skating
    ],
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
          body: ListView(
        key: const ValueKey("today-recommendation-page"),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        children: [
          Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text("今日穿搭推荐",
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 5),
                  const Text("根据天气、场景和你的风格推荐",
                      style: TextStyle(color: Color(0xFF8C8881))),
                ])),
            CircleAvatar(
                backgroundColor: const Color(0xFFEAF0E7),
                child: IconButton(
                    icon: const Icon(Icons.notifications_none),
                    onPressed: () {}))
          ]),
          const SizedBox(height: 18),
          const Wrap(spacing: 8, children: [
            _Pill(icon: Icons.wb_sunny_outlined, text: "晴 22°C"),
            _Pill(icon: Icons.business_center_outlined, text: "通勤")
          ]),
          const SizedBox(height: 22),
          Container(
              height: 340,
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFF2E9DD), Color(0xFFFBF8F2)]),
                  borderRadius: BorderRadius.circular(24)),
              child: Stack(children: [
                Positioned(
                    top: 18, right: 18, child: _Pill(text: "LOOK ${look + 1}")),
                Center(
                    child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 16,
                        runSpacing: 18,
                        children: looks[look].asMap().entries.map((e) {
                          const sizes = [104.0, 82.0, 98.0, 76.0, 70.0];
                          return Container(
                              width: sizes[e.key],
                              height: sizes[e.key] + 20,
                              decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: .72),
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: const [
                                    BoxShadow(
                                        color: Color(0x12000000),
                                        blurRadius: 18,
                                        offset: Offset(0, 8))
                                  ]),
                              child: Icon(e.value,
                                  size: sizes[e.key] * .58,
                                  color: e.key.isEven
                                      ? const Color(0xFFB99D7D)
                                      : const Color(0xFFD8C8B3)));
                        }).toList())),
              ])),
          const SizedBox(height: 16),
          Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFEAE5DD)),
                  borderRadius: BorderRadius.circular(18)),
              child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.auto_awesome,
                          size: 18, color: Color(0xFF718867)),
                      SizedBox(width: 7),
                      Text("推荐理由",
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700))
                    ]),
                    SizedBox(height: 9),
                    Text("温暖柔和的浅色系通勤穿搭，简约干练又有亲和力，适合晴天 22°C 的舒适温度。",
                        style:
                            TextStyle(height: 1.6, color: Color(0xFF6F6A63))),
                  ])),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: OutlinedButton.icon(
                    onPressed: () =>
                        setState(() => look = (look + 1) % looks.length),
                    icon: const Icon(Icons.refresh),
                    label: const Text("换一套"),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 50),
                        foregroundColor: const Color(0xFF596650),
                        side: const BorderSide(color: Color(0xFF9DAD96)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))))),
            const SizedBox(width: 12),
            Expanded(
                flex: 2,
                child: FilledButton.icon(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("已保存为今天的穿搭记录"))),
                    icon: const Icon(Icons.check),
                    label: const Text("今天穿这套"))),
          ]),
        ],
      ));
}

class _Pill extends StatelessWidget {
  final IconData? icon;
  final String text;
  const _Pill({this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: const Color(0xFFF0EDE7),
          borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: const Color(0xFF77716A)),
          const SizedBox(width: 5)
        ],
        Text(text,
            style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF605B55),
                fontWeight: FontWeight.w600))
      ]));
}
