import 'dart:convert';
import 'package:ai_closet_app/core/network/api_client.dart';
import 'package:ai_closet_app/features/wardrobe/models/wardrobe_tag_statistics.dart';
import 'package:ai_closet_app/features/wardrobe/presentation/wardrobe_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> garment(String id, dynamic tags,
        {String category = '上装',
        String season = '秋',
        String status = 'normal'}) =>
    {
      'id': id,
      'name': id,
      'categoryLevel1': category,
      'categoryLevel2': '其他',
      'primaryColor': '白',
      'originalImageUrl': '',
      'seasons': [season],
      'customTags': tags,
      'managementStatus': status,
      'wearableStatus': 'wearable'
    };

http.Response ok(dynamic data) =>
    http.Response(jsonEncode({'success': true, 'data': data}), 200,
        headers: {'content-type': 'application/json; charset=utf-8'});

Future<void> openStatistics(WidgetTester tester) async {
  await tester.tap(find.byTooltip('衣橱显示设置'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('自定义标签统计'));
  await tester.pumpAndSettle();
}

Finder row(String name) =>
    find.byKey(ValueKey(name == 'all' || name == 'untagged'
        ? 'tag-stat-$name'
        : 'tag-stat-value-$name'));
void expectCount(String name, int count) {
  expect(find.descendant(of: row(name), matching: find.text('$count 件')),
      findsOneWidget);
}

void main() {
  test(
      'counts garments once per normalized tag, excludes discarded, sorts by count then name',
      () {
    expect(WardrobeTagStatistics([]).total, 0);
    expect(WardrobeTagStatistics([]).counts, isEmpty);
    final stats = WardrobeTagStatistics([
      garment('a', '[" 常穿 ","常穿","通勤",""]'),
      garment('b', ['常穿', '运动']),
      garment('c', ['运动'], status: 'archived'),
      garment('d', null),
      garment('e', '[]'),
      garment('f', [' ', '']),
      garment('g', ['常穿'], status: 'discarded'),
    ]);
    expect(stats.total, 6);
    expect(stats.untagged, 3);
    expect(stats.counts, {'常穿': 2, '通勤': 1, '运动': 2});
    expect(stats.sortedTags.map((entry) => entry.key), ['常穿', '运动', '通勤']);
    expect(WardrobeTagStatistics.matches(garment('a', ['不常穿']), '常穿'), isFalse);
    expect(WardrobeTagStatistics.matches(garment('a', [' 常穿 ']), '常穿'), isTrue);
    expect(WardrobeTagStatistics.matches(garment('a', []), ''), isTrue);
    expect(
        WardrobeTagStatistics.matches(
            garment('a', [], status: 'discarded'), null),
        isFalse);
    for (final invalid in [
      'not json',
      '{}',
      [1]
    ]) {
      expect(() => itemCustomTags(invalid), throwsFormatException);
    }
  });

  testWidgets(
      'statistics match list filters, labels select exact tags, untagged and clear work',
      (tester) async {
    final items = [
      garment('衬衫甲', '["常穿","常穿","通勤"]'),
      garment('衬衫乙', ['常穿']),
      garment('衬衫丙', []),
      garment('外套', ['通勤'], category: '外套'),
      garment('夏衫', ['夏日'], season: '夏'),
      garment('已丢弃', ['丢弃'], status: 'discarded')
    ];
    final client = ApiClient(
        baseUrl: 'http://localhost',
        httpClient: MockClient((req) async => req.url.path == '/me'
            ? ok({'wardrobeDisplayPreferences': '{"seasons":["秋"]}'})
            : ok(items)));
    await tester.pumpWidget(MaterialApp(home: WardrobePage(client: client)));
    await tester.pumpAndSettle();
    await openStatistics(tester);
    expectCount('all', 4);
    expectCount('常穿', 2);
    expectCount('通勤', 2);
    expectCount('untagged', 1);
    expect(row('夏日'), findsNothing);
    expect(row('丢弃'), findsNothing);
    await tester.tap(row('常穿'));
    await tester.pumpAndSettle();
    expect(find.text('共 2 件单品'), findsOneWidget);
    expect(find.text('标签：常穿'), findsOneWidget);
    await openStatistics(tester);
    expectCount('all', 4);
    expectCount('通勤', 2);
    await tester.tap(row('untagged'));
    await tester.pumpAndSettle();
    expect(find.text('共 1 件单品'), findsOneWidget);
    expect(find.text('衬衫丙'), findsOneWidget);
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('共 4 件单品'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, '上装'));
    await tester.enterText(find.byType(TextField), '衬衫甲');
    await tester.pumpAndSettle();
    await openStatistics(tester);
    expectCount('all', 1);
    expectCount('常穿', 1);
    expectCount('通勤', 1);
    await tester.tap(row('all'));
    await tester.pumpAndSettle();
    expect(find.text('共 1 件单品'), findsOneWidget);
    expect(find.byType(InputChip), findsNothing);
  });

  testWidgets('editing tags refreshes statistics when returning from details',
      (tester) async {
    var item = garment('衬衫', ['旧标签']);
    final client = ApiClient(
        baseUrl: 'http://localhost',
        httpClient: MockClient((req) async {
          if (req.url.path == '/me') return ok({});
          if (req.method == 'PATCH') {
            item = {...item, ...jsonDecode(req.body) as Map<String, dynamic>};
            return ok(item);
          }
          return ok([item]);
        }));
    await tester.pumpWidget(MaterialApp(home: WardrobePage(client: client)));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.checkroom).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    final tags = find.byKey(const ValueKey('item-customTags'));
    await tester.ensureVisible(tags);
    await tester.enterText(tags, '新标签、常穿');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await openStatistics(tester);
    expect(row('旧标签'), findsNothing);
    expectCount('新标签', 1);
    expectCount('常穿', 1);
  });

  testWidgets(
      'failed or malformed loads cannot show misleading zero counts and retry recovers',
      (tester) async {
    var fail = true;
    var malformed = false;
    final client = ApiClient(
        baseUrl: 'http://localhost',
        httpClient: MockClient((req) async {
          if (req.url.path == '/me') return ok({});
          if (fail) return http.Response('failed', 500);
          return ok([garment('衬衫', malformed ? '{invalid' : [])]);
        }));
    await tester.pumpWidget(MaterialApp(home: WardrobePage(client: client)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('衣橱显示设置'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<ListTile>(find.widgetWithText(ListTile, '自定义标签统计'))
            .enabled,
        isFalse);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    fail = false;
    malformed = true;
    await tester.tap(find.text('衣橱加载失败，请检查网络后重试'));
    await tester.pumpAndSettle();
    expect(find.text('衣橱加载失败，请检查网络后重试'), findsOneWidget);
    malformed = false;
    await tester.tap(find.text('衣橱加载失败，请检查网络后重试'));
    await tester.pumpAndSettle();
    await openStatistics(tester);
    expectCount('all', 1);
    expectCount('untagged', 1);
    expect(find.text('当前范围内暂无自定义标签'), findsOneWidget);
  });
  testWidgets(
      'many labels scroll on a narrow screen, including labels named all and untagged',
      (tester) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = ApiClient(
        baseUrl: 'http://localhost',
        httpClient: MockClient((req) async => req.url.path == '/me'
            ? ok({})
            : ok([
                garment('衬衫', [
                  'all',
                  'untagged',
                  ...List.generate(
                      50, (i) => '标签${i.toString().padLeft(2, '0')}')
                ])
              ])));
    await tester.pumpWidget(MaterialApp(home: WardrobePage(client: client)));
    await tester.pumpAndSettle();
    await openStatistics(tester);
    expectCount('all', 1);
    expect(find.byKey(const ValueKey('tag-stat-value-all')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('tag-stat-value-untagged')), findsOneWidget);
    await tester.scrollUntilVisible(row('标签49'), 300,
        scrollable: find.byType(Scrollable).last);
    expectCount('标签49', 1);
    await tester.tap(row('标签49'));
    await tester.pumpAndSettle();
    expect(find.text('标签：标签49'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
