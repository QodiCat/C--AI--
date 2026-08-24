import "package:flutter/material.dart";

import "../core/theme/app_theme.dart";
import "../features/app_shell/app_shell_page.dart";

class AiClosetApp extends StatelessWidget {
  const AiClosetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "AI衣橱",
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const AppShellPage(),
    );
  }
}
