import 'package:flutter/material.dart';
import '../data/wardrobe_display_repository.dart';
import '../models/wardrobe_display_preferences.dart';

class WardrobeDisplaySettingsPage extends StatefulWidget {
  const WardrobeDisplaySettingsPage({super.key, required this.repository});
  final WardrobeDisplayRepository repository;
  @override
  State<WardrobeDisplaySettingsPage> createState() =>
      _WardrobeDisplaySettingsPageState();
}

class _WardrobeDisplaySettingsPageState
    extends State<WardrobeDisplaySettingsPage> {
  final categories = <String>{}, seasons = <String>{};
  bool loading = true, saving = false, loaded = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final preferences = await widget.repository.fetch();
      if (mounted) {
        setState(() {
          categories
            ..clear()
            ..addAll(preferences.categories.isEmpty
                ? WardrobeDisplayPreferences.allCategories
                : preferences.categories);
          seasons
            ..clear()
            ..addAll(preferences.seasons.isEmpty
                ? WardrobeDisplayPreferences.allSeasons
                : preferences.seasons);
          loading = false;
          loaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = e.toString();
        });
      }
    }
  }

  Future<void> save() async {
    if (categories.isEmpty || seasons.isEmpty) {
      setState(() => error = '请至少选择一种衣物类型和一个季节');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.repository.save(WardrobeDisplayPreferences(
        categories:
            categories.length == WardrobeDisplayPreferences.allCategories.length
                ? []
                : WardrobeDisplayPreferences.allCategories
                    .where(categories.contains)
                    .toList(),
        seasons: seasons.length == WardrobeDisplayPreferences.allSeasons.length
            ? []
            : WardrobeDisplayPreferences.allSeasons
                .where(seasons.contains)
                .toList(),
      ));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          saving = false;
          error = e.toString();
        });
      }
    }
  }

  Widget options(String heading, List<String> values, Set<String> selected) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
                child: Text(heading,
                    style: Theme.of(context).textTheme.titleMedium)),
            TextButton(
                onPressed: saving || !loaded
                    ? null
                    : () => setState(() {
                          selected
                            ..clear()
                            ..addAll(values);
                        }),
                child: const Text('全选'))
          ]),
          Wrap(
              spacing: 8,
              children: values
                  .map((value) => FilterChip(
                      label: Text(value),
                      selected: selected.contains(value),
                      onSelected: saving || !loaded
                          ? null
                          : (enabled) => setState(() {
                                if (enabled) {
                                  selected.add(value);
                                } else {
                                  selected.remove(value);
                                }
                              })))
                  .toList()),
        ],
      );
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('衣橱显示设置')),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(20), children: [
                const Text('多选你希望在衣橱中显示的类型和季节。设置随账号保存，仅影响衣橱列表展示。'),
                const SizedBox(height: 16),
                options('显示的衣物类型', WardrobeDisplayPreferences.allCategories,
                    categories),
                const SizedBox(height: 20),
                options(
                    '显示的季节', WardrobeDisplayPreferences.allSeasons, seasons),
                const SizedBox(height: 12),
                const Text(
                    '例如：选择秋、冬，会显示适合秋季或冬季的衣物；四季衣物也会显示。未标注季节的衣物只在选择全部季节时显示。'),
                if (error != null)
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(error!)),
                if (error != null && !loaded)
                  TextButton(onPressed: load, child: const Text('重新加载')),
                const SizedBox(height: 20),
                FilledButton(
                    onPressed: saving || !loaded ? null : save,
                    child: Text(saving ? '保存中…' : '保存')),
                TextButton(
                    onPressed: saving || !loaded
                        ? null
                        : () => setState(() {
                              categories
                                ..clear()
                                ..addAll(
                                    WardrobeDisplayPreferences.allCategories);
                              seasons
                                ..clear()
                                ..addAll(WardrobeDisplayPreferences.allSeasons);
                              error = null;
                            }),
                    child: const Text('恢复显示全部（保存后生效）')),
              ]),
      );
}
