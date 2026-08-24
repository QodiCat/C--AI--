import "package:flutter/material.dart";

import "../../../core/network/api_client.dart";
import "../../../core/network/app_config.dart";
import "../../../core/widgets/section_card.dart";
import "../data/today_recommendation_repository.dart";

class TodayRecommendationPage extends StatefulWidget {
  const TodayRecommendationPage({super.key});

  @override
  State<TodayRecommendationPage> createState() => _TodayRecommendationPageState();
}

class _TodayRecommendationPageState extends State<TodayRecommendationPage> {
  late final TodayRecommendationRepository _repository;
  List<dynamic>? _recommendations;
  bool _isLoading = false;

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

    final data = await _repository.generateTodayRecommendation();

    if (!mounted) {
      return;
    }

    setState(() {
      _recommendations = data;
      _isLoading = false;
    });
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
          subtitle: "当前使用固定条件示例，后续接页面表单即可替换。",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilledButton(
                onPressed: _isLoading ? null : _loadRecommendation,
                child: Text(_isLoading ? "生成中..." : "获取今日推荐"),
              ),
              const SizedBox(height: 16),
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
