import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:ai_closet_app/core/network/api_client.dart';
import 'package:ai_closet_app/features/wardrobe/data/wardrobe_repository.dart';
import 'package:ai_closet_app/features/wardrobe/presentation/item_editor_page.dart';
import 'package:ai_closet_app/features/wardrobe/presentation/measurement_fields.dart';
import 'item_editing_test.dart' as fixtures;

void main() {
  testWidgets(
      'pants prefill, invalid values block, failed save retains and clearing removes',
      (tester) async {
    final requests = <Map<String, dynamic>>[];
    final repository = WardrobeRepository(ApiClient(
        baseUrl: 'http://localhost',
        httpClient: MockClient((req) async {
          requests.add(jsonDecode(req.body) as Map<String, dynamic>);
          if (requests.length == 1) {
            return http.Response(
                jsonEncode({
                  'success': false,
                  'error': {'message': '写入失败'}
                }),
                500,
                headers: {'content-type': 'application/json; charset=utf-8'});
          }
          return fixtures.ok({...fixtures.item(), ...requests.last});
        })));
    await tester.pumpWidget(MaterialApp(
        home: ItemEditorPage(data: {
      ...fixtures.item(),
      'categoryLevel1': '下装',
      'categoryLevel2': '裤子',
      'measurements': const {'outseam': 100.5, 'inseam': 72, 'hipPosition': 20}
    }, repository: repository)));
    final field = find.byKey(const ValueKey('measurement-pants-outseam'));
    await tester.ensureVisible(field);
    expect(tester.widget<TextFormField>(field).controller!.text, '100.5');
    await tester.enterText(field, '-1');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(requests, isEmpty);
    // Collapsing the group must not bypass validation.
    await tester.ensureVisible(find.text('裤子尺寸与量法'));
    await tester.tap(find.text('裤子尺寸与量法'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(requests, isEmpty);
    await tester.ensureVisible(find.text('裤子尺寸与量法'));
    await tester.tap(find.text('裤子尺寸与量法'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(field);
    ScaffoldMessenger.of(tester.element(field)).clearSnackBars();
    await tester.pumpAndSettle();
    await tester.enterText(field, '101.5');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(requests.single['measurements']['outseam'], 101.5);
    expect(tester.widget<TextFormField>(field).controller!.text, '101.5');
    expect(find.textContaining('写入失败'), findsOneWidget);
    await tester.ensureVisible(field);
    await tester.enterText(field, '');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(requests.last['measurements'], {'inseam': 72, 'hipPosition': 20});
  });

  testWidgets(
      'details show measured values and guidance only for entered fields',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: MeasurementDetails(values: {'outseam': 102.5}))));
    expect(find.text('裤长／外长：102.5 cm'), findsOneWidget);
    expect(find.textContaining('腰头上缘'), findsOneWidget);
    expect(find.text('胸围'), findsNothing);
  });
}
