import 'dart:convert';
import 'package:ai_closet_app/core/network/api_client.dart';
import 'package:ai_closet_app/features/profile/data/profile_repository.dart';
import 'package:ai_closet_app/features/profile/presentation/body_measurements_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('prefills, validates, clears and preserves input on save failure',
      (tester) async {
    final requests = <http.Request>[];
    final repository = ProfileRepository(ApiClient(
        baseUrl: 'http://localhost',
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
              jsonEncode({
                'success': false,
                'error': {'message': 'save failed'}
              }),
              500);
        })));
    await tester.pumpWidget(MaterialApp(
        home: BodyMeasurementsPage(
            profile: const {'height': 170.5, 'bust': 90},
            repository: repository)));
    expect(find.text('170.5'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('height')), '-1');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('保存'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(requests, isEmpty);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('height')), -300,
        scrollable: find.byType(Scrollable).first);
    await tester.enterText(find.byKey(const ValueKey('height')), '175.5');
    await tester.enterText(find.byKey(const ValueKey('bust')), '');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('保存'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(requests.single.url.path, '/me/body-measurements');
    final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
    expect(body.length, 9);
    expect(body['height'], 175.5);
    expect(body['bust'], 0);
    expect(find.textContaining('save failed'), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('height')), -300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('175.5'), findsOneWidget);
  });
}
