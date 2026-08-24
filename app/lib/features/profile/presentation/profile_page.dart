import "package:flutter/material.dart";

import "../../../core/widgets/section_card.dart";

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey("profile-page"),
      padding: const EdgeInsets.all(20),
      children: [
        Text("个人中心", style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text("后续在这里承接账户、风格偏好、隐私授权与注销流程。"),
        const SizedBox(height: 18),
        const SectionCard(
          title: "当前状态",
          subtitle: "本轮先把主流程工程骨架搭好，资料编辑与上传交互下一轮补齐。",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("• 账户接口：已在后端预留"),
              Text("• 风格偏好接口：已在后端预留"),
              Text("• 阿里云 OSS 上传签名：已在后端预留"),
            ],
          ),
        ),
      ],
    );
  }
}
