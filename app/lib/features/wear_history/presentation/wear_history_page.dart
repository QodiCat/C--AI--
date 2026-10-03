import "package:flutter/material.dart";
import "../../../core/network/api_client.dart";
import "../../../core/network/app_config.dart";

class WearHistoryPage extends StatefulWidget {
  const WearHistoryPage({super.key});
  @override
  State<WearHistoryPage> createState() => _WearHistoryPageState();
}

class _WearHistoryPageState extends State<WearHistoryPage> {
  final client = ApiClient(baseUrl: AppConfig.apiBaseUrl);
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  List<dynamic> logs = [], outfits = [];
  bool loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final period = "${month.year}-${month.month.toString().padLeft(2, '0')}";
      final values = await Future.wait(
          [client.get("/wear-logs?month=$period"), client.get("/outfits")]);
      if (mounted) {
        setState(() {
          logs = values[0]["data"] as List;
          outfits = values[1]["data"] as List;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String outfitName(String id) {
    final matches = outfits.where((o) => o["id"] == id);
    return matches.isEmpty ? "已删除搭配" : matches.first["name"] as String;
  }

  Future<void> record() async {
    if (outfits.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("请先在 AI 搭配中保存一套搭配")));
      return;
    }
    String selected = outfits.first["id"] as String;
    final note = TextEditingController();
    final weather = TextEditingController();
    final temperature = TextEditingController();
    String? saveError;
    bool saving = false;
    await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (dialogContext, update) => AlertDialog(
                  title: const Text("记录今日穿搭"),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    DropdownButtonFormField<String>(
                        initialValue: selected,
                        items: outfits
                            .map((o) => DropdownMenuItem(
                                value: o["id"] as String,
                                child: Text(o["name"] as String)))
                            .toList(),
                        onChanged: (v) => selected = v!),
                    TextField(
                        controller: weather,
                        decoration: const InputDecoration(labelText: "天气")),
                    TextField(
                        controller: temperature,
                        decoration: const InputDecoration(labelText: "温度 °C")),
                    TextField(
                        controller: note,
                        decoration: const InputDecoration(labelText: "备注")),
                    if (saveError != null) Text(saveError!),
                  ])),
                  actions: [
                    TextButton(
                        onPressed:
                            saving ? null : () => Navigator.pop(dialogContext),
                        child: const Text("取消")),
                    FilledButton(
                        onPressed: saving
                            ? null
                            : () async {
                                if (weather.text.trim().isEmpty ||
                                    temperature.text.trim().isEmpty) {
                                  update(() => saveError = "请填写天气和温度");
                                  return;
                                }
                                update(() {
                                  saving = true;
                                  saveError = null;
                                });
                                try {
                                  final now = DateTime.now();
                                  await client.post("/wear-logs", body: {
                                    "outfitId": selected,
                                    "wearDate":
                                        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}",
                                    "weather": weather.text.trim(),
                                    "temperature": temperature.text.trim(),
                                    "scene": "日常",
                                    "note": note.text.trim()
                                  });
                                  if (dialogContext.mounted) {
                                    Navigator.pop(dialogContext);
                                  }
                                } catch (e) {
                                  if (dialogContext.mounted) {
                                    update(() {
                                      saving = false;
                                      saveError = e.toString();
                                    });
                                  }
                                }
                              },
                        child: Text(saving ? "保存中…" : "保存"))
                  ],
                )));
    note.dispose();
    weather.dispose();
    temperature.dispose();
    if (mounted) await load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      body: RefreshIndicator(
          onRefresh: load,
          child: ListView(
              key: const ValueKey("wear-history-page"),
              padding: const EdgeInsets.all(20),
              children: [
                Row(children: [
                  Expanded(
                      child: Text("穿搭记录",
                          style: Theme.of(context).textTheme.headlineMedium)),
                  IconButton(
                      onPressed: loading ? null : record,
                      icon: const Icon(Icons.add))
                ]),
                Row(children: [
                  IconButton(
                      onPressed: loading
                          ? null
                          : () {
                              month = DateTime(month.year, month.month - 1);
                              load();
                            },
                      icon: const Icon(Icons.chevron_left)),
                  Expanded(
                      child: Text("${month.year}年 ${month.month}月",
                          textAlign: TextAlign.center)),
                  IconButton(
                      onPressed: loading
                          ? null
                          : () {
                              month = DateTime(month.year, month.month + 1);
                              load();
                            },
                      icon: const Icon(Icons.chevron_right))
                ]),
                if (loading) const Center(child: CircularProgressIndicator()),
                if (error != null)
                  TextButton(onPressed: load, child: Text(error!)),
                if (!loading && error == null && logs.isEmpty)
                  const Padding(
                      padding: EdgeInsets.all(24), child: Text("本月还没有穿搭记录")),
                ...logs.map((raw) {
                  final log = raw as Map<String, dynamic>;
                  return Card(
                      child: ListTile(
                    title: Text(
                        "${log['wearDate']} · ${outfitName(log['outfitId'] as String)}"),
                    subtitle: Text(
                        "${log['weather']} ${log['temperature']}°C\n${log['note'] ?? ''}"),
                    isThreeLine: true,
                    onTap: () => showDialog<void>(
                        context: context,
                        builder: (_) =>
                            AlertDialog(
                                title:
                                    Text(outfitName(log['outfitId'] as String)),
                                content: Text(
                                    "日期：${log['wearDate']}\n场景：${log['scene']}\n心情：${log['mood']}\n评分：${log['rating']}\n备注：${log['note']}"),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text("关闭"))
                                ])),
                  ));
                }),
              ])));
}
