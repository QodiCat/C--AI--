import "dart:convert";
import "../../wardrobe/presentation/wardrobe_display_settings_page.dart";
import "../../wardrobe/data/wardrobe_display_repository.dart";
import "body_measurements_page.dart";
import "../data/profile_repository.dart";
import "package:flutter/material.dart";
import "../../../core/network/auth_session.dart";
import "../../../core/network/api_client.dart";
import "../../../core/network/app_config.dart";
import "../../auth/presentation/password_page.dart";

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.onLogout});
  final VoidCallback onLogout;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final client = ApiClient(baseUrl: AppConfig.apiBaseUrl);
  Map<String, dynamic>? profile;
  int itemCount = 0, outfitCount = 0, logCount = 0;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final responses = await Future.wait([
        client.get("/me"),
        client.get("/items"),
        client.get("/outfits"),
        client.get("/wear-logs")
      ]);
      if (mounted) {
        setState(() {
          profile = responses[0]["data"] as Map<String, dynamic>;
          itemCount = (responses[1]["data"] as List).length;
          outfitCount = (responses[2]["data"] as List).length;
          logCount = (responses[3]["data"] as List).length;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> edit() async {
    final nickname =
        TextEditingController(text: profile!["nickname"] as String);
    final city = TextEditingController(text: profile!["city"] as String);
    final bodyType =
        TextEditingController(text: profile!["bodyType"] as String);
    String? saveError;
    bool saving = false;
    await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (dialogContext, update) => AlertDialog(
                  title: const Text("编辑基础资料"),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(
                        controller: nickname,
                        decoration: const InputDecoration(labelText: "昵称")),
                    TextField(
                        controller: city,
                        decoration: const InputDecoration(labelText: "所在城市")),
                    TextField(
                        controller: bodyType,
                        decoration: const InputDecoration(labelText: "体型")),
                    if (saveError != null) Text(saveError!),
                  ]),
                  actions: [
                    TextButton(
                        onPressed:
                            saving ? null : () => Navigator.pop(dialogContext),
                        child: const Text("取消")),
                    FilledButton(
                        onPressed: saving
                            ? null
                            : () async {
                                update(() {
                                  saving = true;
                                  saveError = null;
                                });
                                try {
                                  await client.patch("/me/profile", body: {
                                    for (final key in [
                                      "avatarUrl",
                                      "gender",
                                      "ageRange",
                                      "height",
                                      "weight"
                                    ])
                                      key: profile![key],
                                    "nickname": nickname.text.trim(),
                                    "city": city.text.trim(),
                                    "bodyType": bodyType.text.trim()
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
    nickname.dispose();
    city.dispose();
    bodyType.dispose();
    if (mounted) await load();
  }

  List<String> get preferences {
    try {
      return (jsonDecode(profile?["stylePreferences"] as String? ?? "[]")
              as List)
          .cast<String>();
    } catch (_) {
      return [];
    }
  }

  Future<void> editPreferences() async {
    final selected = preferences.toSet();
    String? saveError;
    bool saving = false;
    await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (dialogContext, update) => AlertDialog(
                  title: const Text("风格偏好"),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    Wrap(
                        spacing: 8,
                        children: ["极简", "通勤", "休闲", "运动", "复古", "优雅"]
                            .map((value) => FilterChip(
                                label: Text(value),
                                selected: selected.contains(value),
                                onSelected: saving
                                    ? null
                                    : (enabled) => update(() {
                                          if (enabled) {
                                            selected.add(value);
                                          } else {
                                            selected.remove(value);
                                          }
                                        })))
                            .toList()),
                    if (saveError != null) Text(saveError!),
                  ]),
                  actions: [
                    TextButton(
                        onPressed:
                            saving ? null : () => Navigator.pop(dialogContext),
                        child: const Text("取消")),
                    FilledButton(
                        onPressed: saving
                            ? null
                            : () async {
                                update(() => saving = true);
                                try {
                                  await client.patch("/me/style-preferences",
                                      body: {
                                        "stylePreferences": selected.toList()
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
                        child: const Text("保存"))
                  ],
                )));
    if (mounted) await load();
  }

  Future<void> logout() async {
    try {
      await client.post("/auth/logout");
    } catch (_) {}
    await AuthSession.clear();
    widget.onLogout();
  }

  Future<void> deleteAccount() async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
                title: const Text("注销账号"),
                content: const Text("将永久删除账号、衣橱和穿搭记录，无法恢复。确认注销吗？"),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text("取消")),
                  FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text("确认注销"))
                ]));
    if (confirmed != true) return;
    try {
      await client.delete("/me");
      await AuthSession.clear();
      widget.onLogout();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      body: RefreshIndicator(
          onRefresh: load,
          child: ListView(
              key: const ValueKey("profile-page"),
              padding: const EdgeInsets.all(20),
              children: [
                Text("个人中心", style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 20),
                if (error != null)
                  TextButton(onPressed: load, child: Text(error!)),
                if (profile == null && error == null)
                  const Center(child: CircularProgressIndicator()),
                if (profile != null) ...[
                  Card(
                      child: ListTile(
                          leading: const CircleAvatar(
                              child: Icon(Icons.person_outline)),
                          title: Text(profile!["nickname"] as String),
                          subtitle: Text(profile!["email"] as String),
                          trailing: IconButton(
                              onPressed: edit,
                              icon: const Icon(Icons.edit_outlined)))),
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Text("衣物 $itemCount"),
                                Text("搭配 $outfitCount"),
                                Text("记录 $logCount")
                              ]))),
                  ListTile(
                      leading: const Icon(Icons.straighten),
                      title: const Text("身体数据"),
                      subtitle: const Text("身高、体重与围度"),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final saved = await Navigator.of(context).push<bool>(
                            MaterialPageRoute(
                                builder: (_) => BodyMeasurementsPage(
                                    profile: profile!,
                                    repository: ProfileRepository(client))));
                        if (saved == true && mounted) await load();
                      }),
                  ListTile(
                      leading: const Icon(Icons.settings_outlined),
                      title: const Text("衣橱显示设置"),
                      subtitle: const Text("选择显示的衣物类型和季节"),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await Navigator.of(context).push<bool>(
                            MaterialPageRoute(
                                builder: (_) => WardrobeDisplaySettingsPage(
                                    repository:
                                        WardrobeDisplayRepository(client))));
                      }),
                  ListTile(
                      title: const Text("风格偏好"),
                      subtitle: Text(preferences.join(" · ")),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: editPreferences),
                  ListTile(
                      leading: const Icon(Icons.lock_outline),
                      title: const Text("修改密码"),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final changed = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                              builder: (_) =>
                                  const PasswordPage(changePassword: true)),
                        );
                        if (changed == true && mounted) widget.onLogout();
                      }),
                  SwitchListTile(
                      title: const Text("允许图片用于模型优化"),
                      value: profile!["allowModelTraining"] as bool,
                      onChanged: (enabled) async {
                        try {
                          await client.patch("/me/privacy",
                              body: {"allowModelTraining": enabled});
                          await load();
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString())));
                          }
                        }
                      }),
                ],
                const SizedBox(height: 24),
                OutlinedButton(onPressed: logout, child: const Text("退出登录")),
                const SizedBox(height: 12),
                TextButton(
                    onPressed: deleteAccount,
                    child: const Text("注销账号",
                        style: TextStyle(color: Colors.red))),
              ])));
}
