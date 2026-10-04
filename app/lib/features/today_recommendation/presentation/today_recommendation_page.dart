import "package:flutter/material.dart";
import "../../../core/network/api_client.dart";
import "../../../core/network/app_config.dart";
import "../../outfits/presentation/outfit_images.dart";
import "../data/today_recommendation_repository.dart";

class TodayRecommendationPage extends StatefulWidget {
  const TodayRecommendationPage({super.key});
  @override
  State<TodayRecommendationPage> createState() =>
      _TodayRecommendationPageState();
}

class _TodayRecommendationPageState extends State<TodayRecommendationPage> {
  final client = ApiClient(baseUrl: AppConfig.apiBaseUrl);
  late final catalog = OutfitCatalog(client);
  final weather = TextEditingController();
  final temperature = TextEditingController();
  final scene = TextEditingController(text: "通勤");
  List<dynamic> candidates = [];
  int look = 0;
  bool loading = false;
  String? error;
  @override
  void dispose() {
    weather.dispose();
    temperature.dispose();
    scene.dispose();
    super.dispose();
  }

  Future<void> generate() async {
    if (weather.text.trim().isEmpty ||
        temperature.text.trim().isEmpty ||
        scene.text.trim().isEmpty) {
      setState(() => error = "请填写实际天气、温度和场景");
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await TodayRecommendationRepository(client)
          .generateTodayRecommendation(
              weather: weather.text.trim(),
              temperature: temperature.text.trim(),
              scene: scene.text.trim());
      if (mounted) {
        setState(() {
          candidates = result;
          look = 0;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> save() async {
    setState(() => loading = true);
    try {
      await client.post("/ai/outfits/save",
          body: Map<String, dynamic>.from(candidates[look] as Map));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("已保存到我的搭配")));
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> wear() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final saved = await client.post("/ai/outfits/save",
          body: Map<String, dynamic>.from(candidates[look] as Map));
      final now = DateTime.now();
      final date =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      await client.post("/wear-logs", body: {
        "outfitId": saved["data"]["id"],
        "wearDate": date,
        "weather": weather.text.trim(),
        "temperature": temperature.text.trim(),
        "scene": scene.text.trim()
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("已保存今天的穿搭记录")));
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
          body: ListView(
              key: const ValueKey("today-recommendation-page"),
              padding: const EdgeInsets.all(20),
              children: [
            Text("今日穿搭推荐", style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text("填写当前天气，从你的真实衣橱中生成搭配"),
            TextField(
                controller: weather,
                decoration: const InputDecoration(labelText: "当前天气")),
            TextField(
                controller: temperature,
                keyboardType: const TextInputType.numberWithOptions(
                    signed: true, decimal: true),
                decoration: const InputDecoration(labelText: "温度 °C")),
            TextField(
                controller: scene,
                decoration: const InputDecoration(labelText: "穿搭场景")),
            const SizedBox(height: 16),
            FilledButton.icon(
                onPressed: loading ? null : generate,
                icon: const Icon(Icons.auto_awesome),
                label: Text(loading ? "处理中…" : "生成今日推荐")),
            if (error != null)
              Padding(padding: const EdgeInsets.all(12), child: Text(error!)),
            if (candidates.isNotEmpty)
              Card(
                  child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(candidates[look]["name"] as String,
                                style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 12),
                            Text(candidates[look]["reason"] as String),
                            const SizedBox(height: 12),
                            OutfitImages(
                                ids: outfitItemIds(candidates[look]["itemIds"]),
                                catalog: catalog),
                            Wrap(spacing: 8, children: [
                              TextButton(
                                  onPressed: loading
                                      ? null
                                      : () => setState(() => look =
                                          (look + 1) % candidates.length),
                                  child: const Text("换一套")),
                              TextButton(
                                  onPressed: loading ? null : save,
                                  child: const Text("保存到我的搭配")),
                              FilledButton(
                                  onPressed: loading ? null : wear,
                                  child: const Text("今天穿这套"))
                            ]),
                          ]))),
          ]));
}
