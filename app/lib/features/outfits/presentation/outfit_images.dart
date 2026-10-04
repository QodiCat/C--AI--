import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../wardrobe/data/wardrobe_repository.dart';

List<String> outfitItemIds(dynamic value) {
  if (value is String) {
    try {
      value = jsonDecode(value);
    } catch (_) {
      return [];
    }
  }
  return value is List ? value.map((id) => id.toString()).toList() : [];
}

class OutfitCatalog {
  OutfitCatalog(this.client);
  final ApiClient client;
  Future<List<Map<String, dynamic>>>? _items;
  final _images = <String, Future<String?>>{};

  Future<List<Map<String, dynamic>>> items() => _items ??= client
      .get('/items')
      .then((response) => (response['data'] as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList());

  Future<String?> image(Map<String, dynamic> item) {
    final cutout = item['cutoutImageUrl'] as String?;
    final uri = cutout?.isNotEmpty == true
        ? cutout!
        : item['originalImageUrl'] as String? ?? '';
    return _images.putIfAbsent(
        uri, () => WardrobeRepository(client).resolveImage(uri));
  }
}

class OutfitImages extends StatefulWidget {
  const OutfitImages({super.key, required this.ids, required this.catalog});
  final List<String> ids;
  final OutfitCatalog catalog;
  @override
  State<OutfitImages> createState() => _OutfitImagesState();
}

class _OutfitImagesState extends State<OutfitImages> {
  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, dynamic>>>(
        future: widget.catalog.items(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Text('衣物图片加载失败，请重新进入页面');
          if (!snapshot.hasData) return const LinearProgressIndicator();
          final items = {
            for (final item in snapshot.data!) item['id'] as String: item
          };
          return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: widget.ids.map((id) {
                final item = items[id];
                return SizedBox(
                    width: 100,
                    child: Column(children: [
                      if (item == null)
                        const SizedBox(
                            height: 100,
                            child: Center(
                                child:
                                    Icon(Icons.image_not_supported_outlined)))
                      else
                        GarmentImage(item: item, catalog: widget.catalog),
                      const SizedBox(height: 4),
                      Text(item?['name'] as String? ?? '单品已删除',
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis),
                    ]));
              }).toList());
        },
      );
}

class GarmentImage extends StatelessWidget {
  const GarmentImage({super.key, required this.item, required this.catalog});
  final Map<String, dynamic> item;
  final OutfitCatalog catalog;
  @override
  Widget build(BuildContext context) => SizedBox(
      height: 100,
      width: 100,
      child: FutureBuilder<String?>(
        future: catalog.image(item),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return const Center(
                child: Icon(Icons.image_not_supported_outlined));
          }
          return Image.network(snapshot.data!,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Center(child: Icon(Icons.broken_image_outlined)));
        },
      ));
}
