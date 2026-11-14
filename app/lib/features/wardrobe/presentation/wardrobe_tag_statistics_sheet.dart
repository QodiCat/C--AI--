import 'package:flutter/material.dart';
import '../models/wardrobe_tag_statistics.dart';

class WardrobeTagSelection {
  const WardrobeTagSelection(this.tag);
  final String? tag;
}

class WardrobeTagStatisticsSheet extends StatelessWidget {
  const WardrobeTagStatisticsSheet(
      {super.key, required this.statistics, this.selectedTag});
  final WardrobeTagStatistics statistics;
  final String? selectedTag;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
              child: Row(children: [
                Expanded(
                    child: Text('自定义标签统计',
                        style: Theme.of(context).textTheme.titleLarge)),
                IconButton(
                    tooltip: '关闭标签统计',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close)),
              ])),
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('按当前类型、季节、搜索及显示设置统计，不受标签筛选影响。同一件衣物可计入多个标签。')),
          Expanded(
              child: ListView(children: [
            _row(context, '全部衣物', statistics.total, null, 'tag-stat-all'),
            _row(
                context, '未设置标签', statistics.untagged, '', 'tag-stat-untagged'),
            const Divider(),
            if (statistics.counts.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(20), child: Text('当前范围内暂无自定义标签')),
            for (final entry in statistics.sortedTags)
              _row(context, entry.key, entry.value, entry.key,
                  'tag-stat-value-${entry.key}'),
          ])),
        ]),
      );

  Widget _row(BuildContext context, String label, int count, String? tag,
          String key) =>
      ListTile(
        key: ValueKey(key),
        title: Text(label),
        trailing: Text('$count 件'),
        selected: selectedTag == tag,
        onTap: () => Navigator.pop(context, WardrobeTagSelection(tag)),
      );
}
