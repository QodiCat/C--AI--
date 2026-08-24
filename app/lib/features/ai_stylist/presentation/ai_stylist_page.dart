import "package:flutter/material.dart";
import "../../../core/network/api_client.dart";
import "../../../core/network/app_config.dart";
import "../data/ai_stylist_repository.dart";

class AiStylistPage extends StatefulWidget {
  const AiStylistPage({super.key});
  @override
  State<AiStylistPage> createState() => _State();
}

class _State extends State<AiStylistPage> {
  late final repo =
      AiStylistRepository(ApiClient(baseUrl: AppConfig.apiBaseUrl));
  String scene = "通勤", season = "秋", weather = "晴", style = "极简";
  final temperature = TextEditingController(text: "24");
  bool loading = false;
  List<dynamic>? candidates;
  String? error;
  Future<void> generate() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final v = await repo.generateOutfits(
          scene: scene,
          season: season,
          weather: weather,
          temperature: temperature.text,
          style: style);
      if (mounted) setState(() => candidates = v);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void toast(String v) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(v)));
  Widget select(String label, String value, List<String> values,
          ValueChanged<String> onChanged) =>
      DropdownButtonFormField<String>(
          initialValue: value,
          decoration: InputDecoration(labelText: label),
          items: values
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (v) => onChanged(v!));
  @override
  Widget build(BuildContext context) => ListView(
          key: const ValueKey("ai-stylist-page"),
          padding: const EdgeInsets.all(20),
          children: [
            Text("AI造型师", style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            Wrap(spacing: 12, runSpacing: 12, children: [
              SizedBox(
                  width: 150,
                  child: select("场景", scene, ["通勤", "约会", "聚会", "运动", "旅行"],
                      (v) => setState(() => scene = v))),
              SizedBox(
                  width: 150,
                  child: select("季节", season, ["春", "夏", "秋", "冬"],
                      (v) => setState(() => season = v))),
              SizedBox(
                  width: 150,
                  child: select("天气", weather, ["晴", "阴", "雨", "雪"],
                      (v) => setState(() => weather = v))),
              SizedBox(
                  width: 150,
                  child: select("风格", style, ["极简", "通勤", "休闲", "运动", "复古"],
                      (v) => setState(() => style = v))),
              SizedBox(
                  width: 150,
                  child: TextField(
                      controller: temperature,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "温度°C")))
            ]),
            const SizedBox(height: 16),
            FilledButton.icon(
                onPressed: loading ? null : generate,
                icon: const Icon(Icons.auto_awesome),
                label: Text(loading ? "生成中…" : "生成 3 套搭配")),
            if (error != null)
              Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error))),
            if (candidates != null)
              ...candidates!.map((raw) {
                final c = raw as Map<String, dynamic>;
                return Card(
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c["name"],
                                  style:
                                      Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 6),
                              Text(c["reason"]),
                              const SizedBox(height: 10),
                              Text("${(c["itemIds"] as List).length} 件衣橱单品"),
                              Wrap(children: [
                                TextButton.icon(
                                    onPressed: () async {
                                      await repo.save(c);
                                      toast("已保存到搭配");
                                    },
                                    icon: const Icon(Icons.bookmark_outline),
                                    label: const Text("保存")),
                                TextButton.icon(
                                    onPressed: () async {
                                      await repo.feedback(c["name"], "like");
                                      toast("已记录喜欢");
                                    },
                                    icon: const Icon(Icons.thumb_up_outlined),
                                    label: const Text("喜欢")),
                                TextButton(
                                    onPressed: generate,
                                    child: const Text("换一批"))
                              ])
                            ])));
              })
          ]);
}
