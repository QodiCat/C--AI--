import 'dart:convert';

import 'package:ai_closet_app/core/network/api_client.dart';
import 'package:ai_closet_app/features/outfits/presentation/my_outfits_page.dart';
import 'package:ai_closet_app/features/outfits/presentation/outfit_editor_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response response(dynamic data) =>
    http.Response(jsonEncode({'success': true, 'data': data}), 200,
        headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  testWidgets(
      'categories filter outfits and deletion needs explicit confirmation',
      (tester) async {
    bool deleted = false;
    int deletes = 0;
    final client = ApiClient(
        baseUrl: 'http://localhost',
        httpClient: MockClient((request) async {
          if (request.method == 'DELETE') {
            deletes++;
            deleted = true;
            expect(request.url.path, '/outfits/weekend');
            return response({'deleted': true});
          }
          if (request.url.path == '/items') return response([]);
          return response([
            {'id': 'work', 'name': '上班搭配', 'category': '通勤', 'itemIds': '[]'},
            if (!deleted)
              {
                'id': 'weekend',
                'name': '周末搭配',
                'category': '休闲',
                'itemIds': '[]'
              },
          ]);
        }));
    await tester.pumpWidget(MaterialApp(home: MyOutfitsPage(client: client)));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '休闲'));
    await tester.pumpAndSettle();
    expect(find.text('上班搭配'), findsNothing);
    expect(find.text('周末搭配'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('delete-weekend')));
    await tester.tap(find.byKey(const ValueKey('delete-weekend')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(deletes, 0);
    await tester.tap(find.byKey(const ValueKey('delete-weekend')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认删除'));
    await tester.pumpAndSettle();
    expect(deletes, 1);
    expect(find.text('周末搭配'), findsNothing);
  });

  testWidgets(
      'editing initializes existing selections and updates classification',
      (tester) async {
    Map<String, dynamic>? saved;
    final client = ApiClient(
        baseUrl: 'http://localhost',
        httpClient: MockClient((request) async {
          if (request.method == 'GET') {
            return response([
              for (final id in ['shirt', 'pants', 'shoes'])
                {
                  'id': id,
                  'name': id,
                  'managementStatus': 'normal',
                  'wearableStatus': 'wearable',
                  'originalImageUrl': ''
                },
            ]);
          }
          expect(request.method, 'PATCH');
          expect(request.url.path, '/outfits/existing');
          saved = jsonDecode(request.body) as Map<String, dynamic>;
          return response({'id': 'existing'});
        }));
    await tester.pumpWidget(MaterialApp(
        home: OutfitEditorPage(client: client, outfit: const {
      'id': 'existing',
      'name': '旧搭配',
      'category': '上班',
      'season': '秋',
      'itemIds': '["shirt","pants"]',
    })));
    await tester.pumpAndSettle();
    expect(find.text('已选择 2 件'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), '新搭配');
    await tester.enterText(find.byType(TextField).at(4), '周末');
    tester.testTextInput.hide();
    await tester.pump();
    await Scrollable.ensureVisible(
        tester.element(find.byKey(const ValueKey('outfit-item-pants'))),
        alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('outfit-item-pants')));
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(
        tester.element(find.byKey(const ValueKey('outfit-item-shoes'))),
        alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('outfit-item-shoes')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('保存搭配'));
    await tester.tap(find.text('保存搭配'));
    await tester.pumpAndSettle();
    expect(saved?['name'], '新搭配');
    expect(saved?['category'], '周末');
    expect(saved?['season'], '秋');
    expect(saved?['itemIds'], ['shirt', 'shoes']);
  });
}
