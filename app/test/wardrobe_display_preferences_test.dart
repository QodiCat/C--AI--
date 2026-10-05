import 'dart:convert';
import 'package:ai_closet_app/core/network/api_client.dart';
import 'package:ai_closet_app/features/wardrobe/data/wardrobe_display_repository.dart';
import 'package:ai_closet_app/features/wardrobe/models/wardrobe_display_preferences.dart';
import 'package:ai_closet_app/features/wardrobe/presentation/wardrobe_display_settings_page.dart';
import 'package:ai_closet_app/features/wardrobe/presentation/wardrobe_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response response(dynamic data) =>
    http.Response(jsonEncode({'success': true, 'data': data}), 200,
        headers: {'content-type': 'application/json; charset=utf-8'});
void main() {
  test(
      'combines type selection with season OR, accepts four-season and legacy tags',
      () {
    const preferences = WardrobeDisplayPreferences(
        categories: ['上装', '下装', '鞋履'], seasons: ['秋', '冬']);
    for (final tag in [
      '["秋"]',
      '["春","冬"]',
      '["四季"]',
      '秋冬',
      ['冬']
    ]) {
      expect(preferences.matches({'categoryLevel1': '上装', 'seasons': tag}),
          isTrue);
    }
    for (final item in [
      {'categoryLevel1': '外套', 'seasons': '["冬"]'},
      {'categoryLevel1': '上装', 'seasons': '["夏"]'},
      {'categoryLevel1': '上装', 'seasons': '[]'},
      {'categoryLevel1': '上装', 'seasons': '不适合冬'},
    ]) {
      expect(preferences.matches(item), isFalse);
    }
    expect(
        const WardrobeDisplayPreferences()
            .matches({'categoryLevel1': '未知', 'seasons': null}),
        isTrue);
    expect(
        WardrobeDisplayPreferences.fromProfile(
            {'wardrobeDisplayPreferences': '{}'}).visibleCategories.length,
        7);
    expect(
        () => WardrobeDisplayPreferences.fromProfile(
            {'wardrobeDisplayPreferences': '{"seasons":["未知"]}'}),
        throwsFormatException);
  });
  testWidgets(
      'settings save multiple types/seasons and wardrobe respects them after reopening',
      (tester) async {
    var preferences = <String, dynamic>{};
    final items = [
      {
        'id': 'shirt',
        'name': '秋季衬衫',
        'categoryLevel1': '上装',
        'primaryColor': '白',
        'originalImageUrl': '',
        'seasons': '["秋"]'
      },
      {
        'id': 'pants',
        'name': '冬季长裤',
        'categoryLevel1': '下装',
        'primaryColor': '黑',
        'originalImageUrl': '',
        'seasons': '["冬"]'
      },
      {
        'id': 'coat',
        'name': '冬季外套',
        'categoryLevel1': '外套',
        'primaryColor': '灰',
        'originalImageUrl': '',
        'seasons': '["冬"]'
      },
      {
        'id': 'summer',
        'name': '夏季短袖',
        'categoryLevel1': '上装',
        'primaryColor': '蓝',
        'originalImageUrl': '',
        'seasons': '["夏"]'
      },
    ];
    final client = ApiClient(
        baseUrl: 'http://localhost',
        httpClient: MockClient((request) async {
          if (request.method == 'PATCH') {
            expect(request.url.path, '/me/wardrobe-display');
            preferences = jsonDecode(request.body) as Map<String, dynamic>;
            return response({});
          }
          if (request.url.path == '/me') {
            return response(
                {'wardrobeDisplayPreferences': jsonEncode(preferences)});
          }
          return response(items);
        }));
    await tester.pumpWidget(MaterialApp(home: WardrobePage(client: client)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('衣橱显示设置'));
    await tester.pumpAndSettle();
    for (final text in ['外套', '裙装', '包袋', '配饰', '春', '夏']) {
      await tester.tap(find.widgetWithText(FilterChip, text));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.text('保存'));
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(preferences, {
      'categories': ['上装', '下装', '鞋履'],
      'seasons': ['秋', '冬']
    });
    expect(find.text('共 2 件单品'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '外套'), findsNothing);
    expect(find.text('秋季衬衫'), findsOneWidget);
    expect(find.text('冬季长裤'), findsOneWidget);
    expect(find.text('冬季外套'), findsNothing);
    expect(find.text('夏季短袖'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(MaterialApp(home: WardrobePage(client: client)));
    await tester.pumpAndSettle();
    expect(find.text('共 2 件单品'), findsOneWidget);
  });
  testWidgets(
      'failed save retains selection and reset saves unrestricted defaults',
      (tester) async {
    var fail = true;
    Map<String, dynamic>? saved;
    final repo = WardrobeDisplayRepository(ApiClient(
        baseUrl: 'http://localhost',
        httpClient: MockClient((request) async {
          if (request.method == 'GET') {
            return response({
              'wardrobeDisplayPreferences':
                  '{"categories":["上装"],"seasons":["秋","冬"]}'
            });
          }
          saved = jsonDecode(request.body) as Map<String, dynamic>;
          if (fail) {
            return http.Response(
                jsonEncode({
                  'success': false,
                  'error': {'message': '保存失败'}
                }),
                500,
                headers: {'content-type': 'application/json; charset=utf-8'});
          }
          return response({});
        })));
    await tester.pumpWidget(
        MaterialApp(home: WardrobeDisplaySettingsPage(repository: repo)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.textContaining('保存失败'), findsOneWidget);
    expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, '秋'))
            .selected,
        isTrue);
    await tester.tap(find.text('恢复显示全部（保存后生效）'));
    await tester.pumpAndSettle();
    fail = false;
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(saved, {'categories': [], 'seasons': []});
  });
  testWidgets('load failure disables edits and provides a working retry',
      (tester) async {
    var calls = 0;
    final repo = WardrobeDisplayRepository(ApiClient(
        baseUrl: 'http://localhost',
        httpClient: MockClient((request) async {
          calls++;
          if (calls == 1) {
            return http.Response(
                jsonEncode({
                  'success': false,
                  'error': {'message': '加载失败'}
                }),
                500);
          }
          return response({'wardrobeDisplayPreferences': '{}'});
        })));
    await tester.pumpWidget(
        MaterialApp(home: WardrobeDisplaySettingsPage(repository: repo)));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '保存'))
            .onPressed,
        isNull);
    await tester.tap(find.text('重新加载'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, '上装'))
            .selected,
        isTrue);
  });
}
