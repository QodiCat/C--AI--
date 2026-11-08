import 'dart:convert';
import 'package:ai_closet_app/core/network/api_client.dart';
import 'package:ai_closet_app/features/wardrobe/data/wardrobe_repository.dart';
import 'package:ai_closet_app/features/wardrobe/models/wardrobe_item.dart';
import 'package:ai_closet_app/features/wardrobe/presentation/item_detail_page.dart';
import 'package:ai_closet_app/features/wardrobe/presentation/item_editor_page.dart';
import 'package:ai_closet_app/features/wardrobe/presentation/wardrobe_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response ok(dynamic data) =>
    http.Response(jsonEncode({'success': true, 'data': data}), 200,
        headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, dynamic> item() => {
      'id': 'shirt',
      'name': '衬衫',
      'categoryLevel1': '上装',
      'categoryLevel2': '衬衫',
      'primaryColor': '白',
      'brand': '原品牌',
      'seasons': '["春","秋"]',
      'styles': '["通勤"]',
      'scenes': '["上班"]',
      'customTags': '["常穿"]',
      'purchasePrice': 99.5,
      'purchaseDate': '2026-10-01',
      'originalImageUrl': '',
      'managementStatus': 'normal',
      'wearableStatus': 'washing',
      'notes': '手洗',
    };

Future<void> enter(WidgetTester tester, String key, String value) async {
  final finder = find.byKey(ValueKey('item-$key'));
  await tester.ensureVisible(finder);
  await tester.enterText(finder, value);
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'detail edit preloads attributes, saves notes and returns updated data',
      (tester) async {
    Map<String, dynamic>? saved;
    final data = item();
    final repo = WardrobeRepository(ApiClient(
        baseUrl: 'http://localhost',
        httpClient: MockClient((req) async {
          expect(req.method, 'PATCH');
          expect(req.url.path, '/items/shirt');
          saved = jsonDecode(req.body) as Map<String, dynamic>;
          return ok({...data, ...saved!});
        })));
    await tester.pumpWidget(MaterialApp(
        home: ItemDetailPage(
      item: WardrobeItem('衬衫', '上装', '白', Icons.checkroom, Colors.white,
          data: data),
      repository: repo,
    )));
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    expect(find.text('原品牌'), findsOneWidget);
    expect(find.text('春、秋'), findsOneWidget);
    await enter(tester, 'name', '新衬衫');
    await enter(tester, 'notes', '轻柔手洗\n勿烘干');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(saved!['notes'], '轻柔手洗\n勿烘干');
    expect(saved!['seasons'], ['春', '秋']);
    expect(saved!['styles'], ['通勤']);
    expect(saved!['customTags'], ['常穿']);
    expect(saved!['purchasePrice'], 99.5);
    expect(saved!['wearableStatus'], 'washing');
    expect(saved!.containsKey('originalImageUrl'), isFalse);
    expect(find.byType(ItemEditorPage), findsNothing);
    await tester.scrollUntilVisible(find.text('轻柔手洗\n勿烘干'), 300);
    expect(find.text('轻柔手洗\n勿烘干'), findsOneWidget);
  });

  testWidgets(
      'validates fields, retains edits after failure and can clear notes',
      (tester) async {
    final requests = <Map<String, dynamic>>[];
    final repo = WardrobeRepository(ApiClient(
        baseUrl: 'http://localhost',
        httpClient: MockClient((req) async {
          requests.add(jsonDecode(req.body) as Map<String, dynamic>);
          return http.Response(
              jsonEncode({
                'success': false,
                'error': {'message': '写入失败'}
              }),
              500,
              headers: {'content-type': 'application/json; charset=utf-8'});
        })));
    await tester.pumpWidget(
        MaterialApp(home: ItemEditorPage(data: item(), repository: repo)));
    await enter(tester, 'name', '');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(requests, isEmpty);
    await enter(tester, 'name', '修改后');
    await enter(tester, 'purchasePrice', '-1');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(requests, isEmpty);
    await enter(tester, 'purchasePrice', '');
    await enter(tester, 'purchaseDate', '2026-02-30');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(requests, isEmpty);
    await enter(tester, 'purchaseDate', '');
    await enter(tester, 'notes', List.filled(2001, '衣').join());
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(requests, isEmpty);
    await enter(tester, 'notes', '');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(requests.single['notes'], '');
    expect(requests.single['name'], '修改后');
    expect(requests.single['purchasePrice'], 0);
    expect(find.textContaining('写入失败'), findsOneWidget);
    expect(find.text('修改后'), findsOneWidget);
    expect(find.byType(ItemEditorPage), findsOneWidget);
  });

  testWidgets(
      'switching to four columns shows more clothes on a narrow screen and opens details',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = ApiClient(
        baseUrl: 'http://localhost',
        httpClient: MockClient((req) async {
          if (req.url.path == '/me') {
            return ok({'wardrobeDisplayPreferences': '{}'});
          }
          return ok(List.generate(
              30, (i) => {...item(), 'id': '$i', 'name': '衬衫$i'}));
        }));
    await tester.pumpWidget(MaterialApp(home: WardrobePage(client: client)));
    await tester.pumpAndSettle();
    final originalSize = tester.getSize(find.text('衬衫0').first);
    final originalVisible =
        find.textContaining(RegExp(r'^衬衫\d+$')).hitTestable().evaluate().length;
    for (final count in [3, 4, 2, 4]) {
      await tester.tap(find.widgetWithText(ChoiceChip, '$count 列'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    final visible =
        find.textContaining(RegExp(r'^衬衫\d+$')).hitTestable().evaluate().length;
    expect(visible, greaterThan(originalVisible));
    expect(tester.getSize(find.text('衬衫0').first).height,
        lessThanOrEqualTo(originalSize.height));
    await tester.tap(find.text('衬衫0'));
    await tester.pumpAndSettle();
    expect(find.text('单品详情'), findsOneWidget);
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(ItemEditorPage), findsNothing);
  });
}
