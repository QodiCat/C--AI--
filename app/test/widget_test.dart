// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:ai_closet_app/app/app.dart';

void main() {
  testWidgets('renders the main navigation', (WidgetTester tester) async {
    await tester.pumpWidget(const AiClosetApp());
    expect(find.text('衣橱'), findsOneWidget);
    expect(find.text('AI搭配'), findsOneWidget);
    expect(find.text('今日推荐'), findsOneWidget);
    expect(find.text('记录'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
  });
}
