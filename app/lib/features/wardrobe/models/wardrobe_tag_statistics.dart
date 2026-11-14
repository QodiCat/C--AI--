import 'dart:convert';

Set<String> itemCustomTags(dynamic raw) {
  if (raw == null || raw == '') return {};
  final dynamic tags = raw is String ? jsonDecode(raw) : raw;
  if (tags == null) return {};
  if (tags is! List || tags.any((tag) => tag is! String)) {
    throw const FormatException('衣物自定义标签格式不正确');
  }
  return tags
      .cast<String>()
      .map((tag) => tag.trim())
      .where((tag) => tag.isNotEmpty)
      .toSet();
}

class WardrobeTagStatistics {
  WardrobeTagStatistics(Iterable<Map<String, dynamic>> items) {
    for (final item in items) {
      if (item['managementStatus'] == 'discarded') continue;
      total++;
      final tags = itemCustomTags(item['customTags']);
      if (tags.isEmpty) untagged++;
      for (final tag in tags) {
        counts.update(tag, (count) => count + 1, ifAbsent: () => 1);
      }
    }
  }
  int total = 0, untagged = 0;
  final counts = <String, int>{};
  List<MapEntry<String, int>> get sortedTags => counts.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      return byCount == 0 ? a.key.compareTo(b.key) : byCount;
    });

  // null means all items; empty string means items without custom tags.
  static bool matches(Map<String, dynamic> item, String? tag) {
    if (item['managementStatus'] == 'discarded') return false;
    if (tag == null) return true;
    final tags = itemCustomTags(item['customTags']);
    return tag.isEmpty ? tags.isEmpty : tags.contains(tag);
  }
}
