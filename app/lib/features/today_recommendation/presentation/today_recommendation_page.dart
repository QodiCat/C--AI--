import "package:flutter/material.dart";

import "../../../core/network/api_client.dart";
import "../../../core/network/app_config.dart";
import "../../../core/widgets/section_card.dart";
import "../data/today_recommendation_repository.dart";

class TodayRecommendationPage extends StatefulWidget {
  const TodayRecommendationPage({super.key});

  @override
  State<TodayRecommendationPage> createState() =>
      _TodayRecommendationPageState();
}

class _TodayRecommendationPageState extends State<TodayRecommendationPage> {
  late final TodayRecommendationRepository _repository;
  List<dynamic>? _recommendations;
  bool _isLoading = false;
  String _weather = "晴";
  String _scene = "上班";
  final _temperature = TextEditingController(text: "26");
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = TodayRecommendationRepository(
      ApiClient(baseUrl: AppConfig.apiBaseUrl),
    );
  }

  Future<void> _loadRecommendation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await _repository.generateTodayRecommendation(
          weather: _weather, temperature: _temperature.text, scene: _scene);
      if (mounted) setState(() => _recommendations = data);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey("today-recommendation-page"),
      padding: const EdgeInsets.all(20),
      children: [
        Text("今日推荐", style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text("天气和场景由用户主动输入，不依赖系统天气与日历。"),
        const SizedBox(height: 18),
        SectionCard(
          title: "今日条件",
          subtitle: "确认天气、温度和主要场景后生成推荐。",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                    child: DropdownButtonFormField<String>(
                        initialValue: _weather,
                        decoration: const InputDecoration(labelText: "天气"),
                        items: ["晴", "阴", "雨", "雪", "其他"]
                            .map((e) =>
                                DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (v) => setState(() => _weather = v!))),
                const SizedBox(width: 12),
                Expanded(
                    child: TextField(
                        controller: _temperature,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: "温度°C")))
              ]),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                  initialValue: _scene,
                  decoration: const InputDecoration(labelText: "今日场景"),
                  items: ["上班", "上课", "约会", "聚会", "运动", "旅行", "居家"]
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _scene = v!)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _isLoading ? null : _loadRecommendation,
                child: Text(_isLoading ? "生成中..." : "获取今日推荐"),
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              if (_recommendations != null)
                ..._recommendations!.map((entry) {
                  final data = entry as Map<String, dynamic>;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(data["name"] as String),
                    subtitle: Text(data["reason"] as String),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }
}
