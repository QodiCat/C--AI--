import 'dart:convert';
import 'package:ai_closet_app/core/network/api_client.dart';
import 'package:ai_closet_app/features/today_recommendation/data/current_location.dart';
import 'package:ai_closet_app/features/today_recommendation/presentation/today_recommendation_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets(
      'uses location, displays actual weather, records matching local date',
      (tester) async {
    final requests = <http.Request>[];
    var locations = 0;
    final client = ApiClient(
        baseUrl: 'http://localhost',
        httpClient: MockClient((request) async {
          requests.add(request);
          dynamic data = <String, dynamic>{};
          if (request.url.path == '/ai/today-recommendation/generate') {
            expect(jsonDecode(request.body),
                {'latitude': 31.23, 'longitude': 121.47, 'scene': '通勤'});
            data = {
              'candidates': [
                {
                  'name': '雨天通勤',
                  'reason': '下雨要防水',
                  'itemIds': <String>[],
                  'scene': '通勤',
                  'style': '休闲',
                  'season': '秋'
                }
              ],
              'weather': {
                'latitude': 31.23,
                'longitude': 121.47,
                'date': '2026-10-05',
                'time': '2026-10-05T12:00',
                'timezone': 'Asia/Shanghai',
                'weather': '雨',
                'temperature': 18,
                'feelsLike': 17,
                'minimum': 15,
                'maximum': 20,
                'wind': 12
              }
            };
          } else if (request.url.path == '/ai/outfits/save') {
            data = {'id': 'look'};
          } else if (request.url.path == '/items') {
            data = <dynamic>[];
          }
          return http.Response(jsonEncode({'success': true, 'data': data}), 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }));
    await tester.pumpWidget(MaterialApp(
        home: TodayRecommendationPage(
            client: client,
            locate: () async {
              locations++;
              return const Coordinates(31.23, 121.47);
            })));
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('当前天气'), findsNothing);
    await tester.tap(find.text('获取天气并生成今日搭配'));
    await tester.pumpAndSettle();
    expect(locations, 1);
    expect(find.textContaining('当前 18°C'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('今天穿这套'), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('今天穿这套'));
    await tester.pumpAndSettle();
    final log = jsonDecode(requests.last.body);
    expect(requests.last.url.path, '/wear-logs');
    expect(log, {
      'outfitId': 'look',
      'wearDate': '2026-10-05',
      'weather': '雨',
      'temperature': '18',
      'scene': '通勤'
    });
  });
  testWidgets('location failure prevents requests and allows retry',
      (tester) async {
    var calls = 0, locations = 0;
    final client = ApiClient(
        baseUrl: 'http://localhost',
        httpClient: MockClient((request) async {
          calls++;
          return http.Response('{}', 500);
        }));
    await tester.pumpWidget(MaterialApp(
        home: TodayRecommendationPage(
            client: client,
            locate: () async {
              locations++;
              throw Exception('请允许定位');
            })));
    await tester.tap(find.text('获取天气并生成今日搭配'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.textContaining('请允许定位'), findsOneWidget);
    await tester.tap(find.text('获取天气并生成今日搭配'));
    await tester.pumpAndSettle();
    expect(locations, 2);
  });
  testWidgets('weather failure has a retry and shows no stale recommendation',
      (tester) async {
    var calls = 0;
    final client = ApiClient(
        baseUrl: 'http://localhost',
        httpClient: MockClient((request) async {
          calls++;
          return http.Response(
              jsonEncode({
                'success': false,
                'error': {'message': '天气获取失败，请重试'}
              }),
              502,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }));
    await tester.pumpWidget(MaterialApp(
        home: TodayRecommendationPage(
            client: client,
            locate: () async => const Coordinates(31.23, 121.47))));
    await tester.tap(find.text('获取天气并生成今日搭配'));
    await tester.pumpAndSettle();
    expect(find.textContaining('天气获取失败'), findsOneWidget);
    expect(find.text('今天穿这套'), findsNothing);
    await tester.tap(find.text('获取天气并生成今日搭配'));
    await tester.pumpAndSettle();
    expect(calls, 2);
  });
}
