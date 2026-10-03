// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:ai_closet_app/app/app.dart';

void main() {
  testWidgets('renders the authentication page', (WidgetTester tester) async {
    await tester.pumpWidget(const AiClosetApp());
    expect(find.text('AI衣橱'), findsOneWidget);
    expect(find.text('登录'), findsOneWidget);
    expect(find.text('没有账号？立即注册'), findsOneWidget);
  });
  testWidgets('registration requires a six digit email code', (tester) async {
    await tester.pumpWidget(const AiClosetApp());
    await tester.tap(find.text('没有账号？立即注册'));
    await tester.pumpAndSettle();
    expect(find.text('发送验证码'), findsOneWidget);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(1), 'new@example.com');
    await tester.enterText(fields.at(2), 'strongpass');
    await tester.ensureVisible(find.text('注册并登录'));
    await tester.tap(find.text('注册并登录'));
    await tester.pumpAndSettle();
    expect(find.text('请输入 6 位验证码'), findsOneWidget);
  });
}
