import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:ai_closet_app/core/network/api_client.dart';
import 'package:ai_closet_app/features/wardrobe/data/wardrobe_repository.dart';
import 'package:ai_closet_app/features/wardrobe/presentation/item_editor_page.dart';
import 'item_editing_test.dart' as fixtures;

void main() {
  testWidgets(
      'old backend success without saved measurements keeps editor and input',
      (tester) async {
    final repository = WardrobeRepository(ApiClient(
        baseUrl: 'http://localhost',
        httpClient: MockClient((req) async => fixtures.ok(fixtures.item()))));
    await tester.pumpWidget(MaterialApp(
        home: ItemEditorPage(data: fixtures.item(), repository: repository)));
    final field = find.byKey(const ValueKey('measurement-top-length'));
    await tester.ensureVisible(field);
    await tester.enterText(field, '70.5');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.byType(ItemEditorPage), findsOneWidget);
    expect(tester.widget<TextFormField>(field).controller!.text, '70.5');
    expect(find.textContaining('服务器未保存实测尺寸'), findsOneWidget);
  });

  test(
      'rejects missing, different, malformed or uncleared measurements; accepts saved numbers',
      () async {
    for (final actual in [
      null,
      {'length': 69},
      {'length': '70.5'},
      {'length': 70.5, 'chest': 100}
    ]) {
      final repository = WardrobeRepository(ApiClient(
          baseUrl: 'http://localhost',
          httpClient: MockClient(
              (req) async => fixtures.ok({'measurements': actual}))));
      await expectLater(
          repository.updateItem('shirt', {
            'measurements': {'length': 70.5}
          }),
          throwsA(isA<ApiException>()));
    }
    var stored = <String, dynamic>{'length': 70};
    final repository = WardrobeRepository(ApiClient(
        baseUrl: 'http://localhost',
        httpClient:
            MockClient((req) async => fixtures.ok({'measurements': stored}))));
    await repository.updateItem('shirt', {
      'measurements': {'length': 70.0}
    });
    await expectLater(repository.updateItem('shirt', {'measurements': {}}),
        throwsA(isA<ApiException>()));
    stored = {};
    await repository.updateItem('shirt', {'measurements': {}});
    // Clients omitting measurements retain the existing compatibility contract.
    await repository.updateItem('shirt', {'name': '衬衫'});
  });

  testWidgets(
      'successful save displays returned dimensions and reopens with saved values',
      (tester) async {
    final repository = WardrobeRepository(ApiClient(
        baseUrl: 'http://localhost',
        httpClient: MockClient((req) async => fixtures.ok({
              ...fixtures.item(),
              ...jsonDecode(req.body) as Map<String, dynamic>
            }))));
    Map<String, dynamic>? saved;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async {
                      saved = await Navigator.push<Map<String, dynamic>>(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ItemEditorPage(
                                  data: saved ?? fixtures.item(),
                                  repository: repository)));
                    },
                    child: const Text('编辑'))))));
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('measurement-top-length'));
    await tester.ensureVisible(field);
    await tester.enterText(field, '70.5');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.byType(ItemEditorPage), findsNothing);
    expect(saved!['measurements'], {'length': 70.5});
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(field);
    expect(tester.widget<TextFormField>(field).controller!.text, '70.5');
  });
}
