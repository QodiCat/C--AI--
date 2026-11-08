import "package:flutter/material.dart";
import "../models/wardrobe_item.dart";

class WardrobeCard extends StatelessWidget {
  const WardrobeCard(
      {super.key,
      required this.item,
      required this.onTap,
      this.compact = false});
  final WardrobeItem item;
  final bool compact;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
          onTap: onTap,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: Container(
                    width: double.infinity,
                    color: item.tint.withValues(alpha: .68),
                    child: item.imageUrl != null
                        ? Image.network(item.imageUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.broken_image_outlined))
                        : item.image != null
                            ? Image.memory(item.image!, fit: BoxFit.cover)
                            : Icon(item.icon,
                                size: compact ? 32 : 80,
                                color: const Color(0xFF9F876E)))),
            Padding(
                padding: EdgeInsets.all(compact ? 6 : 12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: compact ? 12 : 14,
                              fontWeight: FontWeight.w700)),
                      if (!compact) const SizedBox(height: 3),
                      if (!compact)
                        Text("${item.category} · ${item.color}",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF8C877F)))
                    ])),
          ])));
}
