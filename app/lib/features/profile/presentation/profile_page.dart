import "dart:convert";
import "package:flutter/material.dart";
import "../../../core/network/api_client.dart";
import "../../../core/network/app_config.dart";
import "../data/profile_repository.dart";

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _State();
}

class _State extends State<ProfilePage> {
  late final repo = ProfileRepository(ApiClient(baseUrl: AppConfig.apiBaseUrl));
  Map<String, dynamic>? user;
  bool loading = true;
  String? error;
  final styles = [
    "极简",
    "通勤",
    "休闲",
    "运动",
    "街头",
    "复古",
    "学院",
    "甜美",
    "优雅",
    "正式",
    "户外"
  ];
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final v = await repo.fetch();
      if (mounted) setState(() => user = v);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<String> get selected {
    try {
      return (jsonDecode(user?["stylePreferences"] ?? "[]") as List)
          .cast<String>();
    } catch (_) {
      return [];
    }
  }

  Future<void> edit() async {
    final name = TextEditingController(text: user?["nickname"]),
        city = TextEditingController(text: user?["city"]),
        body = TextEditingController(text: user?["bodyType"]);
    final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text("编辑资料"),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: "昵称")),
                  TextField(
                      controller: city,
                      decoration: const InputDecoration(labelText: "城市")),
                  TextField(
                      controller: body,
                      decoration: const InputDecoration(labelText: "体型"))
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text("取消")),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text("保存"))
                ]));
    if (yes == true) {
      await repo.update(name.text, city.text, body.text);
      await load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return Center(child: Text(error!));
    final picked = selected;
    return ListView(
        key: const ValueKey("profile-page"),
        padding: const EdgeInsets.all(20),
        children: [
          Text("个人中心", style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          Card(
              child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(user?["nickname"]?.toString().isNotEmpty == true
                      ? user!["nickname"]
                      : "未设置昵称"),
                  subtitle: Text(
                      "${user?["city"] ?? "未设置城市"} · ${user?["bodyType"] ?? "未设置体型"}"),
                  trailing: IconButton(
                      onPressed: edit, icon: const Icon(Icons.edit_outlined)))),
          const SizedBox(height: 12),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("风格偏好",
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Wrap(
                            spacing: 8,
                            children: styles
                                .map((s) => FilterChip(
                                    label: Text(s),
                                    selected: picked.contains(s),
                                    onSelected: (v) async {
                                      final next = [...picked];
                                      v ? next.add(s) : next.remove(s);
                                      await repo.preferences(next);
                                      await load();
                                    }))
                                .toList())
                      ]))),
          SwitchListTile(
              title: const Text("允许匿名数据用于模型优化"),
              subtitle: const Text("默认关闭，可随时修改"),
              value: user?["allowModelTraining"] == true,
              onChanged: (v) async {
                await repo.privacy(v);
                await load();
              }),
          const Divider(),
          ListTile(
              leading: const Icon(Icons.delete_forever_outlined),
              title: const Text("注销账号"),
              textColor: Theme.of(context).colorScheme.error,
              iconColor: Theme.of(context).colorScheme.error,
              onTap: () async {
                final yes = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                            title: const Text("确认注销账号？"),
                            content: const Text("衣橱、搭配、穿搭记录和个人资料将被永久删除，且无法恢复。"),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: const Text("取消")),
                              FilledButton(
                                  onPressed: () => Navigator.pop(c, true),
                                  child: const Text("确认注销"))
                            ]));
                if (yes == true) {
                  await repo.deleteAccount();
                  if (mounted) {
                    setState(() {
                      user = null;
                      error = "账号已注销";
                    });
                  }
                }
              })
        ]);
  }
}
