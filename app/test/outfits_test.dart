import 'dart:convert';

import 'package:ai_closet_app/core/network/api_client.dart';
import 'package:ai_closet_app/features/outfits/presentation/my_outfits_page.dart';
import 'package:ai_closet_app/features/outfits/presentation/outfit_images.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final items = [
    {
      'id': 'shirt',
      'name': '白衬衫',
      'managementStatus': 'normal',
      'wearableStatus': 'wearable',
      'originalImageUrl': ''
    },
    {
      'id': 'pants',
      'name': '黑裤子',
      'managementStatus': 'normal',
      'wearableStatus': 'wearable',
      'originalImageUrl': ''
    },
    {
      'id': 'shoes',
      'name': '运动鞋',
      'managementStatus': 'normal',
      'wearableStatus': 'wearable',
      'originalImageUrl': ''
    },
  ];
  http.Response response(dynamic data) =>
      http.Response(jsonEncode({'success': true, 'data': data}), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});

  testWidgets(
      'saved outfits show every garment and missing garment placeholders',
      (tester) async {
    final client = ApiClient(
        baseUrl: 'http://localhost',
        httpClient: MockClient((request) async {
          if (request.url.path == '/items') return response(items);
          return response([
            {
              'id': 'outfit',
              'name': '通勤组合',
              'source': 'manual',
              'itemIds': '["shirt","pants","shoes","removed"]'
            }
          ]);
        }));
    await tester.pumpWidget(MaterialApp(home: MyOutfitsPage(client: client)));
    await tester.pumpAndSettle();
    expect(find.text('通勤组合'), findsOneWidget);
    for (final name in ['白衬衫', '黑裤子', '运动鞋', '单品已删除']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.byType(GarmentImage), findsNWidgets(3));
  });

  testWidgets('manual outfit saves precisely the selected garments',
      (tester) async {
    Map<String, dynamic>? saved;
    final client = ApiClient(
        baseUrl: 'http://localhost',
        httpClient: MockClient((request) async {
          if (request.method == 'GET') return response(items);
          expect(request.url.path, '/outfits');
          saved = jsonDecode(request.body) as Map<String, dynamic>;
          return response({'id': 'new-outfit'});
        }));
    await tester
        .pumpWidget(MaterialApp(home: ManualOutfitPage(client: client)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '我的通勤搭配');
    await tester.tap(find.byKey(const ValueKey('outfit-item-shirt')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('outfit-item-pants')));
    await tester.tap(find.byKey(const ValueKey('outfit-item-pants')));
    await tester.pumpAndSettle();
    expect(find.text('已选择 2 件'), findsOneWidget);
    await tester.ensureVisible(find.text('保存搭配'));
    await tester.tap(find.text('保存搭配'));
    await tester.pumpAndSettle();
    expect(saved?['name'], '我的通勤搭配');
    expect(saved?['itemIds'], ['shirt', 'pants']);
  });
}
