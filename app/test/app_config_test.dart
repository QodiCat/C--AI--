import 'dart:convert';

import 'package:ai_closet_app/core/network/app_config.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void useEnv(String contents) {
    rootBundle.evict('.env');
    messenger.setMockMessageHandler('flutter/assets', (message) async {
      expect(utf8.decode(message!.buffer.asUint8List()), '.env');
      return ByteData.sublistView(Uint8List.fromList(utf8.encode(contents)));
    });
  }

  tearDown(() {
    messenger.setMockMessageHandler('flutter/assets', null);
    rootBundle.evict('.env');
    AppConfig.apiBaseUrl = 'http://localhost:3000';
  });

  test('loads a quoted API address from the frontend env asset', () async {
    useEnv('# public config\n\nAPI_BASE_URL="http://192.168.1.10:3000"\n');
    await AppConfig.load();
    expect(AppConfig.apiBaseUrl, 'http://192.168.1.10:3000');
  });

  test('accepts a same-origin API path for web deployment', () async {
    useEnv('API_BASE_URL=/api\n');
    await AppConfig.load();
    expect(AppConfig.apiBaseUrl, '/api');
  });

  test('rejects server credentials in frontend config', () async {
    useEnv('API_BASE_URL=/api\nALIYUN_ACCESS_KEY_SECRET=secret\n');
    await expectLater(AppConfig.load(), throwsFormatException);
  });

  test('rejects missing or invalid API addresses', () async {
    for (final contents in [
      '',
      'API_BASE_URL=\n',
      'API_BASE_URL=localhost:3000\n'
    ]) {
      useEnv(contents);
      await expectLater(AppConfig.load(), throwsFormatException);
    }
  });
}
