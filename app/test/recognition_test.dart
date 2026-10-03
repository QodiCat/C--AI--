import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ai_closet_app/core/network/api_client.dart';
import 'package:ai_closet_app/features/wardrobe/data/wardrobe_repository.dart';
import 'package:ai_closet_app/features/wardrobe/presentation/wardrobe_page.dart';

void main() {
  testWidgets(
      'confirmation saves recognized shoe attributes and stable cutout URI',
      (tester) async {
    Map<String, dynamic>? saved;
    final repo = WardrobeRepository(ApiClient(
        baseUrl: 'http://test',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/items');
          saved = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response('{"success":true,"data":{}}', 200);
        })));
    final candidate = <String, dynamic>{
      'candidateId': 'candidate-shoe',
      'name': '白色运动鞋',
      'categoryLevel1': '鞋履',
      'categoryLevel2': '运动鞋',
      'primaryColor': '白色',
      'material': '',
      'brand': '',
      'pattern': '纯色',
      'fit': '',
      'seasons': ['春', '秋'],
      'styles': ['运动'],
      'scenes': ['日常'],
      'confidence': 0.8,
      'uncertainFields': ['material', 'brand'],
      'cutoutImageUrl': 'oss://bucket/users/u/cutouts/shoe.png',
    };
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                    body: FilledButton(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<WardrobeItem>(
                          builder: (_) => RecognitionResultPage(
                                image: base64Decode(
                                    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII='),
                                originalImageUri:
                                    'oss://bucket/users/u/originals/shoe.jpg',
                                candidate: candidate,
                                repository: repo,
                              ))),
                  child: const Text('open'),
                )))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('白色运动鞋'), findsOneWidget);
    expect(find.text('鞋履'), findsOneWidget);
    expect(find.text('米白色棉质衬衫'), findsNothing);
    await tester.scrollUntilVisible(find.text('保存并加入衣橱'), 250, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('保存并加入衣橱'));
    await tester.pumpAndSettle();
    expect(saved?['categoryLevel1'], '鞋履');
    expect(saved?['categoryLevel2'], '运动鞋');
    expect(saved?['cutoutImageUrl'], candidate['cutoutImageUrl']);
    expect(saved?['material'], '');
    expect(saved?['seasons'], ['春', '秋']);
    expect(saved?.containsKey('candidateId'), isFalse);
  });
}
