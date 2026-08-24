import "package:flutter/material.dart";

import "../../../core/network/api_client.dart";
import "../../../core/network/app_config.dart";
import "../../../core/widgets/section_card.dart";
import "../data/wardrobe_repository.dart";

class WardrobePage extends StatefulWidget {
  const WardrobePage({super.key});

  @override
  State<WardrobePage> createState() => _WardrobePageState();
}

class _WardrobePageState extends State<WardrobePage> {
  late final WardrobeRepository _repository;
  late Future<List<dynamic>> _itemsFuture;

  @override
  void initState() {
    super.initState();
    _repository = WardrobeRepository(
      ApiClient(baseUrl: AppConfig.apiBaseUrl),
    );
    _itemsFuture = _repository.fetchItems();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey("wardrobe-page"),
      padding: const EdgeInsets.all(20),
      children: [
        Text("数字衣橱", style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text("先把衣橱跑通，再把 AI 能力往上叠加。"),
        const SizedBox(height: 18),
        SectionCard(
          title: "衣橱列表",
          subtitle: "当前页面已经直接对接后端 `/items` 接口。",
          child: FutureBuilder<List<dynamic>>(
            future: _itemsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return Text("加载失败：${snapshot.error}");
              }

              final items = snapshot.data ?? [];
              return Column(
                children: items.map((item) {
                  final data = item as Map<String, dynamic>;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFE8DED2),
                      child: Text(data["name"].toString().substring(0, 1)),
                    ),
                    title: Text(data["name"] as String),
                    subtitle: Text(
                      "${data["categoryLevel1"]} · ${data["categoryLevel2"]} · ${data["primaryColor"]}",
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}
