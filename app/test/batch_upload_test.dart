import 'dart:convert';
import 'dart:typed_data';

import 'package:ai_closet_app/core/network/api_client.dart';
import 'package:ai_closet_app/features/wardrobe/data/wardrobe_repository.dart';
import 'package:ai_closet_app/features/wardrobe/presentation/batch_upload_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class BatchRepository extends WardrobeRepository {
  BatchRepository() : super(ApiClient(baseUrl: 'http://localhost'));
  int uploads = 0;
  int retries = 0;
  @override
  Future<String> uploadImage(Uint8List bytes, String name, String type) async {
    uploads++;
    return 'oss://bucket/users/test/originals/$name';
  }

  @override
  Future<Map<String, dynamic>> recognizeImage(String uri) async {
    if (uri.endsWith('second.png') && retries++ == 0) {
      throw const ApiException('第二张处理失败');
    }
    return {
      'name': uri.endsWith('first.png') ? '上衣' : '鞋子',
      'cutoutImageUrl': 'oss://bucket/cutout.png'
    };
  }

  @override
  Future<String?> resolveImage(String uri) async => null;
}

void main() {
  testWidgets(
      'batch retains successful results and retries only failed recognition',
      (tester) async {
    final bytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=');
    final repository = BatchRepository();
    await tester.pumpWidget(MaterialApp(
        home: BatchUploadPage(photos: [
      BatchPhoto(bytes, 'first.png', 'image/png'),
      BatchPhoto(bytes, 'second.png', 'image/png')
    ], repository: repository)));
    await tester.pumpAndSettle();
    expect(find.text('上衣'), findsOneWidget);
    expect(find.text('第二张处理失败'), findsOneWidget);
    expect(find.text('确认并保存'), findsOneWidget);
    await tester.tap(find.text('重试此图片'));
    await tester.pumpAndSettle();
    expect(find.text('鞋子'), findsOneWidget);
    expect(find.text('确认并保存'), findsNWidgets(2));
    expect(repository.uploads, 2);
  });
}
