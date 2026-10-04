import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "app/app.dart";
import "core/network/auth_session.dart";
import "core/network/app_config.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.load();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await AuthSession.restore();
  runApp(const AiClosetApp());
}
