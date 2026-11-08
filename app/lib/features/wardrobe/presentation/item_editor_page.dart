import 'dart:convert';
import 'package:flutter/material.dart';
import '../data/wardrobe_repository.dart';
import '../models/wardrobe_display_preferences.dart';

class ItemEditorPage extends StatefulWidget {
  const ItemEditorPage(
      {super.key, required this.data, required this.repository});
  final Map<String, dynamic> data;
  final WardrobeRepository repository;

  @override
  State<ItemEditorPage> createState() => _ItemEditorPageState();
}

class _ItemEditorPageState extends State<ItemEditorPage> {
  static const fields = {
    'name': '名称',
    'categoryLevel2': '细分类',
    'primaryColor': '主颜色',
    'secondaryColor': '辅助颜色',
    'brand': '品牌',
    'size': '尺码',
    'material': '材质',
    'pattern': '图案',
    'fit': '版型',
    'seasons': '季节',
    'styles': '风格',
    'scenes': '场景',
    'customTags': '自定义标签',
    'purchasePrice': '购买价格',
    'purchaseDate': '购买日期',
    'notes': '备注',
  };
  static const listFields = ['seasons', 'styles', 'scenes', 'customTags'];
  final form = GlobalKey<FormState>();
  late final controllers = {
    for (final key in fields.keys)
      key: TextEditingController(text: initialText(key)),
  };
  late String category = widget.data['categoryLevel1'] as String;
  bool saving = false;

  String initialText(String key) {
    final raw = widget.data[key];
    if (raw == null) return '';
    if (!listFields.contains(key)) return raw.toString();
    dynamic value = raw;
    if (raw is String) {
      if (raw.isEmpty) return '';
      try {
        value = jsonDecode(raw);
      } on FormatException {
        return raw;
      }
    }
    return (value as List? ?? []).join('、');
  }

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => saving = true);
    final body = <String, dynamic>{
      'categoryLevel1': category,
      'managementStatus': widget.data['managementStatus'],
      'wearableStatus': widget.data['wearableStatus'],
    };
    for (final key in fields.keys) {
      final text = controllers[key]!.text.trim();
      body[key] = listFields.contains(key)
          ? text
              .split(RegExp(r'[,，、\n]'))
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toSet()
              .toList()
          : key == 'purchasePrice'
              ? (text.isEmpty ? 0 : double.parse(text))
              : text;
    }
    try {
      final updated =
          await widget.repository.updateItem(widget.data['id'] as String, body);
      if (mounted) Navigator.pop(context, updated);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存失败：$error')));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String? validate(String key, String? value) {
    final text = value?.trim() ?? '';
    if (['name', 'categoryLevel2'].contains(key) && text.isEmpty) {
      return '请填写${fields[key]}';
    }
    if (key == 'purchasePrice' && text.isNotEmpty) {
      final price = double.tryParse(text);
      if (price == null || !price.isFinite || price < 0) return '请输入有效的非负价格';
    }
    if (key == 'purchaseDate' && text.isNotEmpty) {
      final date = DateTime.tryParse(text);
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text) ||
          date == null ||
          date.toIso8601String().substring(0, 10) != text) {
        return '请输入有效日期，如 2026-11-08';
      }
    }
    if (key == 'notes' && text.runes.length > 2000) return '备注最多 2000 字';
    return null;
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !saving,
        child: Scaffold(
          appBar: AppBar(title: const Text('编辑衣物'), actions: [
            TextButton(
                onPressed: saving ? null : save,
                child: Text(saving ? '保存中…' : '保存')),
          ]),
          body: Form(
              key: form,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  DropdownButtonFormField<String>(
                    key: const ValueKey('item-category'),
                    initialValue: category,
                    decoration: const InputDecoration(labelText: '分类'),
                    items: {
                      ...WardrobeDisplayPreferences.allCategories,
                      category
                    }
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged:
                        saving ? null : (v) => setState(() => category = v!),
                  ),
                  for (final entry in fields.entries)
                    Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: TextFormField(
                          key: ValueKey('item-${entry.key}'),
                          controller: controllers[entry.key],
                          enabled: !saving,
                          minLines: entry.key == 'notes' ? 3 : 1,
                          maxLines: entry.key == 'notes' ? 6 : 1,
                          keyboardType: entry.key == 'purchasePrice'
                              ? const TextInputType.numberWithOptions(
                                  decimal: true)
                              : entry.key == 'notes'
                                  ? TextInputType.multiline
                                  : TextInputType.text,
                          decoration: InputDecoration(
                              labelText: entry.value,
                              helperText: listFields.contains(entry.key)
                                  ? '多个值用顿号或逗号分隔'
                                  : entry.key == 'notes'
                                      ? '可填写洗护、购买信息等，最多 2000 字'
                                      : entry.key == 'purchaseDate'
                                          ? 'YYYY-MM-DD，可留空'
                                          : null),
                          validator: (v) => validate(entry.key, v),
                        )),
                ]),
              )),
        ),
      );
}
