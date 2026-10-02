import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "app/app.dart";
import "core/network/auth_session.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await AuthSession.restore();
  runApp(const AiClosetApp());
}
