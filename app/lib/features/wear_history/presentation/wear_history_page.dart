import "package:flutter/material.dart";
import "../../../core/network/api_client.dart";
import "../../../core/network/app_config.dart";
import "../data/wear_history_repository.dart";

class WearHistoryPage extends StatefulWidget {
  const WearHistoryPage({super.key});
  @override
  State<WearHistoryPage> createState() => _State();
}

class _State extends State<WearHistoryPage> {
  late final repo =
      WearHistoryRepository(ApiClient(baseUrl: AppConfig.apiBaseUrl));
  bool loading = true;
  List<dynamic> outfits = [], logs = [];
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final values = await Future.wait([repo.outfits(), repo.logs()]);
      if (mounted) {
        setState(() {
          outfits = values[0];
          logs = values[1];
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void toast(String s) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  @override
  Widget build(BuildContext context) => RefreshIndicator(
      onRefresh: load,
      child: ListView(
          key: const ValueKey("wear-history-page"),
          padding: const EdgeInsets.all(20),
          children: [
            Text("搭配与记录", style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            if (loading)
              const Center(child: CircularProgressIndicator())
            else if (error != null)
              Text(error!)
            else ...[
              Text("我的搭配", style: Theme.of(context).textTheme.titleLarge),
              if (outfits.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text("保存 AI 搭配或创建手动搭配后会显示在这里")),
              ...outfits.map((raw) {
                final v = raw as Map<String, dynamic>;
                return Card(
                    child: ListTile(
                        title: Text((v["name"] ?? "未命名搭配").toString()),
                        subtitle: Text(
                            "${v["scene"] ?? "日常"} · ${v["source"] == "ai" ? "AI创建" : "手动创建"} · ${v["rating"] ?? 0}分"),
                        trailing: FilledButton(
                            onPressed: () async {
                              await repo.wear(v["id"]);
                              toast("已标记今天穿了这套");
                              await load();
                            },
                            child: const Text("今天穿"))));
              }),
              const SizedBox(height: 20),
              Text("穿搭日历记录", style: Theme.of(context).textTheme.titleLarge),
              if (logs.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(16), child: Text("暂无穿搭记录")),
              ...logs.map((raw) {
                final v = raw as Map<String, dynamic>;
                return ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: Text(v["wearDate"] ?? ""),
                    subtitle: Text(
                        "${v["scene"] ?? "日常"}${(v["note"] ?? "").toString().isEmpty ? "" : " · ${v["note"]}"}"));
              })
            ]
          ]));
}
