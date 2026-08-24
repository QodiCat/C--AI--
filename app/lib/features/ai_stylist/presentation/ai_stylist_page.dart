import "package:flutter/material.dart";

import "../../../core/network/api_client.dart";
import "../../../core/network/app_config.dart";
import "../../../core/widgets/section_card.dart";
import "../data/ai_stylist_repository.dart";

class AiStylistPage extends StatefulWidget {
  const AiStylistPage({super.key});

  @override
  State<AiStylistPage> createState() => _AiStylistPageState();
}

class _AiStylistPageState extends State<AiStylistPage> {
  late final AiStylistRepository _repository;
  List<dynamic>? _candidates;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _repository = AiStylistRepository(
      ApiClient(baseUrl: AppConfig.apiBaseUrl),
    );
  }

  Future<void> _generate() async {
    setState(() {
      _isLoading = true;
    });

    final candidates = await _repository.generateOutfits();

    if (!mounted) {
      return;
    }

    setState(() {
      _candidates = candidates;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey("ai-stylist-page"),
      padding: const EdgeInsets.all(20),
      children: [
        Text("AI造型师", style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text("当前阶段先保证 AI 请求链路清晰，再迭代交互细节。"),
        const SizedBox(height: 18),
        SectionCard(
          title: "生成搭配",
          subtitle: "调用后端 `/ai/outfits/generate`，后端再通过 provider 调第三方服务。",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilledButton(
                onPressed: _isLoading ? null : _generate,
                child: Text(_isLoading ? "生成中..." : "生成 3 套搭配"),
              ),
              const SizedBox(height: 16),
              if (_candidates != null)
                ..._candidates!.map((entry) {
                  final candidate = entry as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2E8DD),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(candidate["name"] as String),
                          const SizedBox(height: 6),
                          Text(candidate["reason"] as String),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }
}
