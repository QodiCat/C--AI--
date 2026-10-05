import 'dart:convert';

class WardrobeDisplayPreferences {
  const WardrobeDisplayPreferences(
      {this.categories = const [], this.seasons = const []});
  static const allCategories = ['上装', '下装', '外套', '裙装', '鞋履', '包袋', '配饰'];
  static const allSeasons = ['春', '夏', '秋', '冬'];
  final List<String> categories, seasons;

  factory WardrobeDisplayPreferences.fromProfile(Map<String, dynamic> profile) {
    final raw = profile['wardrobeDisplayPreferences'];
    final data = raw == null || raw == ''
        ? <String, dynamic>{}
        : raw is String
            ? jsonDecode(raw)
            : raw;
    if (data is! Map) throw const FormatException('衣橱显示设置格式不正确');
    List<String> selection(String key, List<String> allowed) {
      final value = data[key] ?? <String>[];
      if (value is! List ||
          value.any((item) => item is! String || !allowed.contains(item))) {
        throw const FormatException('衣橱显示设置包含无效选项');
      }
      return value.cast<String>().toSet().toList();
    }

    return WardrobeDisplayPreferences(
        categories: selection('categories', allCategories),
        seasons: selection('seasons', allSeasons));
  }

  Map<String, dynamic> toJson() =>
      {'categories': categories, 'seasons': seasons};
  List<String> get visibleCategories => categories.isEmpty
      ? allCategories
      : allCategories.where(categories.contains).toList();
  String get summary =>
      '${categories.isEmpty ? '全部类型' : categories.join('、')} · ${seasons.isEmpty ? '全部季节' : seasons.join('、')}';

  bool matches(Map<String, dynamic> item) {
    return (categories.isEmpty ||
            categories.contains(item['categoryLevel1'])) &&
        (seasons.isEmpty || seasons.any(itemSeasons(item['seasons']).contains));
  }

  static Set<String> itemSeasons(dynamic raw) {
    dynamic value = raw;
    if (raw is String) {
      try {
        value = jsonDecode(raw);
      } on FormatException {
        value = raw;
      }
    }
    final tags = value is List
        ? value.whereType<String>()
        : value is String
            ? [value]
            : <String>[];
    final result = <String>{};
    for (final tag in tags) {
      if (tag == '四季' || tag == '全年') {
        result.addAll(allSeasons);
      } else if (RegExp(r'^[春夏秋冬]+$').hasMatch(tag)) {
        for (final season in allSeasons) {
          if (tag.contains(season)) result.add(season);
        }
      }
    }
    return result;
  }
}
