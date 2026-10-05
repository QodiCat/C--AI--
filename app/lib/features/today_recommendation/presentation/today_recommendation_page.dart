import "package:flutter/material.dart";
import "../data/current_location.dart";
import "../../../core/network/api_client.dart";
import "../../../core/network/app_config.dart";
import "../../outfits/presentation/outfit_images.dart";
import "../data/today_recommendation_repository.dart";

class TodayRecommendationPage extends StatefulWidget {
  const TodayRecommendationPage(
      {super.key, this.client, this.locate = currentLocation});
  final ApiClient? client;
  final Future<Coordinates> Function() locate;
  @override
  State<TodayRecommendationPage> createState() =>
      _TodayRecommendationPageState();
}

class _TodayRecommendationPageState extends State<TodayRecommendationPage> {
  late final client = widget.client ?? ApiClient(baseUrl: AppConfig.apiBaseUrl);
  late final catalog = OutfitCatalog(client);
  Map<String, dynamic>? conditions;
  String recommendationScene = "通勤";
  final scene = TextEditingController(text: "通勤");
  List<dynamic> candidates = [];
  int look = 0;
  bool loading = false;
  String? error;
  @override
  void dispose() {
    scene.dispose();
    super.dispose();
  }

  Future<void> generate() async {
    if (scene.text.trim().isEmpty) {
      setState(() => error = "请选择穿搭场景");
      return;
    }
    setState(() {
      loading = true;
      error = null;
      candidates = [];
      conditions = null;
    });
    try {
      final location = await widget.locate();
      final requestedScene = scene.text.trim();
      final result = await TodayRecommendationRepository(client)
          .generateTodayRecommendation(
              location: location, scene: requestedScene);
      if (mounted) {
        setState(() {
          candidates = result["candidates"] as List<dynamic>;
          conditions = result["weather"] as Map<String, dynamic>;
          recommendationScene = requestedScene;
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
      final date = conditions!["date"] as String;
      await client.post("/wear-logs", body: {
        "outfitId": saved["data"]["id"],
        "wearDate": date,
        "weather": conditions!["weather"],
        "temperature": conditions!["temperature"].toString(),
        "scene": recommendationScene
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
            Text("今日 AI 搭配", style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text("点击生成后获取当前位置与天气，从你的衣橱中推荐今日搭配"),
            if (conditions != null)
              Card(
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                "当前位置：${conditions!["latitude"]}, ${conditions!["longitude"]}"),
                            Text(
                                "${conditions!["date"]} · ${conditions!["timezone"]}"),
                            Text(
                                "${conditions!["weather"]} · 当前 ${conditions!["temperature"]}°C · 体感 ${conditions!["feelsLike"]}°C"),
                            Text(
                                "今日 ${conditions!["minimum"]}–${conditions!["maximum"]}°C · 风速 ${conditions!["wind"]} km/h"),
                            Text("天气时间：${conditions!["time"]}"),
                            const Text("天气数据：Open-Meteo"),
                          ]))),
            TextField(
                controller: scene,
                enabled: !loading,
                decoration: const InputDecoration(labelText: "穿搭场景")),
            const SizedBox(height: 16),
            FilledButton.icon(
                onPressed: loading ? null : generate,
                icon: const Icon(Icons.auto_awesome),
                label: Text(loading ? "定位并生成中…" : "获取天气并生成今日搭配")),
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
