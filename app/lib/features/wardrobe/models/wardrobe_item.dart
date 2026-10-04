import "dart:typed_data";
import "package:flutter/material.dart";

class WardrobeItem {
  const WardrobeItem(this.name, this.category, this.color, this.icon, this.tint,
      {this.image, this.imageUrl, this.data = const {}});
  final String name, category, color;
  final IconData icon;
  final Color tint;
  final Uint8List? image;
  final String? imageUrl;
  final Map<String, dynamic> data;
}
