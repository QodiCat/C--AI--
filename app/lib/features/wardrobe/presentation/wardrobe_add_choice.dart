import "package:flutter/material.dart";

class WardrobeAddChoice extends StatelessWidget {
  const WardrobeAddChoice(
      {super.key,
      required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 8),
              child: Column(children: [
                Icon(icon, size: 42, color: const Color(0xFF625E58)),
                const SizedBox(height: 15),
                Text(title,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 12, height: 1.5, color: Color(0xFF969088)))
              ]))));
}
