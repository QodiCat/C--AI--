import "package:flutter/material.dart";

import "../core/theme/app_theme.dart";
import "../features/app_shell/app_shell_page.dart";
import "../features/auth/presentation/auth_page.dart";
import "../core/network/auth_session.dart";

class AiClosetApp extends StatefulWidget {
  const AiClosetApp({super.key});

  @override
  State<AiClosetApp> createState() => _AiClosetAppState();
}

class _AiClosetAppState extends State<AiClosetApp> {
  late bool _authenticated = AuthSession.token != null;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "AI衣橱",
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: _authenticated
          ? AppShellPage(onLogout: () => setState(() => _authenticated = false))
          : AuthPage(onAuthenticated: () => setState(() => _authenticated = true)),
    );
  }
}
