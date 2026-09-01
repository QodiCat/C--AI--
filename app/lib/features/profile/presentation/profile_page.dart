import "package:flutter/material.dart";

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
          body: ListView(
              key: const ValueKey("profile-page"),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
              children: [
            Text("个人中心", style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 22),
            Row(children: [
              const CircleAvatar(
                  radius: 34,
                  backgroundColor: Color(0xFFE4D6C8),
                  child:
                      Icon(Icons.person, size: 40, color: Color(0xFF987B60))),
              const SizedBox(width: 14),
              const Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      Text("小衣橱",
                          style: TextStyle(
                              fontSize: 19, fontWeight: FontWeight.w800)),
                      SizedBox(width: 7),
                      _Vip()
                    ]),
                    SizedBox(height: 5),
                    Text("发现更美的自己", style: TextStyle(color: Color(0xFF8A857E)))
                  ])),
              IconButton(
                  onPressed: () => _edit(context),
                  icon: const Icon(Icons.chevron_right))
            ]),
            const SizedBox(height: 24),
            const Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _Stat(number: "128", label: "穿搭记录"),
                  _Stat(number: "36", label: "收藏搭配"),
                  _Stat(number: "12", label: "关注品牌")
                ]),
            const SizedBox(height: 22),
            _MenuGroup(children: [
              _Menu(
                  icon: Icons.person_outline,
                  title: "基础资料",
                  onTap: () => _edit(context)),
              _Menu(
                  icon: Icons.favorite_border,
                  title: "风格偏好",
                  onTap: () => _message(context, "极简 · 通勤 · 优雅")),
              _Menu(
                  icon: Icons.image_outlined,
                  title: "图片是否用于模型优化",
                  value: "仅自己可见",
                  onTap: () => _message(context, "隐私设置已开启")),
              _Menu(
                  icon: Icons.lock_outline,
                  title: "隐私设置",
                  onTap: () => _message(context, "隐私设置"))
            ]),
            const SizedBox(height: 14),
            _MenuGroup(children: [
              _Menu(
                  icon: Icons.help_outline,
                  title: "帮助与反馈",
                  onTap: () => _message(context, "帮助与反馈")),
              _Menu(
                  icon: Icons.info_outline,
                  title: "关于我们",
                  onTap: () => _message(context, "AI衣橱 v0.1.0"))
            ]),
            const SizedBox(height: 28),
            OutlinedButton(
                onPressed: () => _message(context, "已退出登录"),
                style: _buttonStyle(
                    const Color(0xFF4F4B46), const Color(0xFFD9D3CB)),
                child: const Text("退出登录")),
            const SizedBox(height: 12),
            OutlinedButton(
                onPressed: () => _message(context, "演示版本不会实际注销账号"),
                style: _buttonStyle(
                    const Color(0xFFD36B6B), const Color(0xFFE7B4B4)),
                child: const Text("注销账号")),
          ]));
  ButtonStyle _buttonStyle(
          Color color, Color border) =>
      OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          foregroundColor: color,
          side: BorderSide(color: border),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)));
  void _message(BuildContext c, String s) =>
      ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(s)));
  void _edit(BuildContext c) => showDialog(
      context: c,
      builder: (_) => AlertDialog(
              title: const Text("编辑基础资料"),
              content: const Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(decoration: InputDecoration(labelText: "昵称")),
                TextField(decoration: InputDecoration(labelText: "所在城市")),
                TextField(decoration: InputDecoration(labelText: "体型"))
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c), child: const Text("取消")),
                FilledButton(
                    onPressed: () => Navigator.pop(c), child: const Text("保存"))
              ]));
}

class _Vip extends StatelessWidget {
  const _Vip();
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: const Color(0xFFF4DEAD),
          borderRadius: BorderRadius.circular(8)),
      child: const Text("VIP",
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xFF8E681C))));
}

class _Stat extends StatelessWidget {
  final String number, label;
  const _Stat({required this.number, required this.label});
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(number,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF8A857E)))
      ]);
}

class _MenuGroup extends StatelessWidget {
  final List<Widget> children;
  const _MenuGroup({required this.children});
  @override
  Widget build(BuildContext context) => Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
          side: const BorderSide(color: Color(0xFFECE7DF)),
          borderRadius: BorderRadius.circular(17)),
      child: Column(children: children));
}

class _Menu extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback onTap;
  const _Menu(
      {required this.icon,
      required this.title,
      this.value,
      required this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
      onTap: onTap,
      leading: Icon(icon, color: const Color(0xFF625F59)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (value != null)
          Text(value!,
              style: const TextStyle(fontSize: 12, color: Color(0xFF96918A))),
        const SizedBox(width: 4),
        const Icon(Icons.chevron_right, color: Color(0xFFAAA59E))
      ]));
}
