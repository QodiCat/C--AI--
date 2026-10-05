import 'package:flutter/material.dart';
import '../data/profile_repository.dart';

class BodyMeasurementsPage extends StatefulWidget {
  const BodyMeasurementsPage(
      {super.key, required this.profile, required this.repository});
  final Map<String, dynamic> profile;
  final ProfileRepository repository;

  @override
  State<BodyMeasurementsPage> createState() => _BodyMeasurementsPageState();
}

class _BodyMeasurementsPageState extends State<BodyMeasurementsPage> {
  static const labels = {
    'height': '身高',
    'weight': '体重',
    'bust': '胸围',
    'hip': '臀围',
    'waist': '腰围',
    'shoulderWidth': '肩宽',
    'thighCircumference': '大腿围',
    'legLength': '腿长',
    'torsoLength': '上身长',
  };
  final form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> controllers;
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    controllers = {
      for (final key in labels.keys)
        key: TextEditingController(
            text: (widget.profile[key] as num? ?? 0) > 0
                ? widget.profile[key].toString()
                : ''),
    };
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
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.repository.updateBodyMeasurements({
        for (final entry in controllers.entries)
          entry.key: entry.value.text.trim().isEmpty
              ? 0
              : double.parse(entry.value.text.trim()),
      });
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          saving = false;
          error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('身体数据')),
        body: Form(
            key: form,
            child: ListView(padding: const EdgeInsets.all(20), children: [
              const Text('选填，可输入小数；留空并保存可清除。长度单位为厘米，体重单位为公斤。'),
              const SizedBox(height: 12),
              const Text(
                  '围度用软尺水平绕一圈；大腿围取最粗处。肩宽取两侧肩点间距，腿长从胯部量至地面，上身长从肩部量至腰线。请保持每次测量方式一致。'),
              for (final entry in labels.entries)
                Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: TextFormField(
                      key: ValueKey(entry.key),
                      controller: controllers[entry.key],
                      enabled: !saving,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                          labelText: entry.value,
                          suffixText: entry.key == 'weight' ? 'kg' : 'cm'),
                      validator: (text) {
                        if (text == null || text.trim().isEmpty) {
                          return null;
                        }
                        final value = double.tryParse(text.trim());
                        if (value == null ||
                            !value.isFinite ||
                            value <= 0 ||
                            value > 300) {
                          return '请输入大于 0 且不超过 300 的数字';
                        }
                        return null;
                      },
                    )),
              if (error != null)
                Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(error!)),
              const SizedBox(height: 24),
              FilledButton(
                  onPressed: saving ? null : save,
                  child: Text(saving ? '保存中…' : '保存')),
            ])),
      );
}
