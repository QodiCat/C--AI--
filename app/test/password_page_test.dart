import 'dart:convert';

import 'package:ai_closet_app/core/network/api_client.dart';
import 'package:ai_closet_app/features/auth/data/auth_repository.dart';
import 'package:ai_closet_app/features/auth/presentation/password_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('reset requires matching passwords and sends the verified email',
      (tester) async {
    final requests = <http.Request>[];
    final repository = AuthRepository(ApiClient(
        baseUrl: 'http://localhost',
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
        })));
    await tester.pumpWidget(MaterialApp(
        home: PasswordPage(
            initialEmail: 'person@example.com', repository: repository)));
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(1), '123456');
    await tester.enterText(fields.at(2), 'newpassword');
    await tester.enterText(fields.at(3), 'differentpassword');
    await tester.ensureVisible(find.text('重置密码'));
    await tester.tap(find.text('重置密码'));
    await tester.pumpAndSettle();
    expect(find.text('两次密码不一致'), findsOneWidget);
    expect(requests, isEmpty);
    await tester.enterText(fields.at(3), 'newpassword');
    await tester.ensureVisible(find.text('重置密码'));
    await tester.tap(find.text('重置密码'));
    await tester.pumpAndSettle();
    expect(requests.single.url.path, '/auth/password/reset');
    expect(jsonDecode(requests.single.body), {
      'email': 'person@example.com',
      'code': '123456',
      'newPassword': 'newpassword'
    });
  });

  testWidgets('change shows old-password errors and preserves the form',
      (tester) async {
    final repository = AuthRepository(ApiClient(
        baseUrl: 'http://localhost',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/auth/password/change');
          expect(jsonDecode(request.body),
              {'currentPassword': 'oldpassword', 'newPassword': 'newpassword'});
          return http.Response(
              jsonEncode({
                'success': false,
                'error': {'message': '当前密码错误'}
              }),
              400,
              headers: {'content-type': 'application/json; charset=utf-8'});
        })));
    await tester.pumpWidget(MaterialApp(
        home: PasswordPage(changePassword: true, repository: repository)));
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'oldpassword');
    await tester.enterText(fields.at(1), 'newpassword');
    await tester.enterText(fields.at(2), 'newpassword');
    await tester.ensureVisible(find.text('确认修改'));
    await tester.tap(find.text('确认修改'));
    await tester.pumpAndSettle();
    expect(find.text('当前密码错误'), findsOneWidget);
    expect(find.text('确认修改'), findsOneWidget);
  });
}
