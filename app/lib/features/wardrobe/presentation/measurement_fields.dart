import 'package:flutter/material.dart';
import '../models/garment_measurement.dart';

String? measurementError(Map<String, dynamic> values) {
  for (final value in values.values) {
    if (value is! num || !value.isFinite || value <= 0 || value > 500) {
      return '尺寸请输入大于 0 且不超过 500 的厘米数';
    }
  }
  return null;
}

class MeasurementFields extends StatefulWidget {
  const MeasurementFields(
      {super.key,
      required this.values,
      required this.category,
      this.enabled = true});
  final Map<String, dynamic> values;
  final String category;
  final bool enabled;

  @override
  State<MeasurementFields> createState() => _MeasurementFieldsState();
}

class _MeasurementFieldsState extends State<MeasurementFields> {
  late final controllers = {
    for (final field in garmentMeasurements)
      field.key: TextEditingController(
          text: widget.values[field.key]?.toString() ?? '')
  };

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = ['上装', '外套'].contains(widget.category);
    final pants = widget.category == '下装';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 20),
      const Text('实测尺寸（cm，可选）', style: TextStyle(fontSize: 18)),
      const Text('记录衣物平铺尺寸，不是身体围度。围度输入横量宽度 × 2 后的数值；留空可清除。'),
      if (top)
        const Text(
            'T 恤优先：衣长、胸围、肩宽、袖长、下摆围。衬衫加领围、背宽；西装和外套加上臂围、袖窿深。落肩和插肩款优先量连肩袖长。'),
      if (pants)
        const Text('以下为裤子尺寸。先量腰围、臀围、前裆长、后裆长、大腿围、外长、内长、脚口围；修身裤再加膝围、小腿围。'),
      for (final group in ['top', 'pants'])
        Material(
            color: Colors.transparent,
            child: ExpansionTile(
              title: Text(group == 'top' ? '上衣尺寸与量法' : '裤子尺寸与量法'),
              initiallyExpanded: group == 'top' ? top : pants,
              children: [
                for (final field in garmentMeasurements
                    .where((f) => f.group == group || f.group == 'both'))
                  Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        key: ValueKey('measurement-$group-${field.key}'),
                        controller: controllers[field.key],
                        enabled: widget.enabled,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                            labelText: field.label,
                            suffixText: 'cm',
                            helperText: '${field.method}\n${field.purpose}',
                            helperMaxLines: 6),
                        validator: (text) {
                          if (text == null || text.trim().isEmpty) return null;
                          final value = double.tryParse(text.trim());
                          return value == null ||
                                  !value.isFinite ||
                                  value <= 0 ||
                                  value > 500
                              ? '请输入大于 0 且不超过 500 的厘米数'
                              : null;
                        },
                        onChanged: (text) {
                          if (text.trim().isEmpty) {
                            widget.values.remove(field.key);
                          } else {
                            widget.values[field.key] =
                                double.tryParse(text.trim()) ?? text;
                          }
                        },
                      )),
              ],
            )),
    ]);
  }
}

class MeasurementDetails extends StatelessWidget {
  const MeasurementDetails({super.key, required this.values});
  final dynamic values;
  @override
  Widget build(BuildContext context) {
    final data = values is Map ? values as Map : const {};
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const ListTile(title: Text('实测尺寸（cm）')),
      if (data.isEmpty) const ListTile(subtitle: Text('尚未填写，可在编辑中添加')),
      for (final field
          in garmentMeasurements.where((f) => data.containsKey(f.key)))
        ListTile(
            title: Text('${field.label}：${data[field.key]} cm'),
            subtitle: Text('${field.method}\n${field.purpose}')),
    ]);
  }
}
