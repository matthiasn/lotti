import 'package:flutter/material.dart';

/// Square initial-tile avatar keyed by hue. Used at 20–32px in the
/// instances list (per design spec).
///
/// Picks foreground / background / border from a single hue using the
/// HSL space so we don't need OKLCH support; close enough visually for
/// the tile tones the design called for.
class SoulAvatar extends StatelessWidget {
  const SoulAvatar({
    required this.label,
    required this.hue,
    this.size = 22,
    super.key,
  });

  final String label;
  final int hue;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = label.isEmpty ? '?' : label.characters.first.toUpperCase();
    final h = hue.toDouble();
    final bg = HSLColor.fromAHSL(1, h, 0.30, 0.22).toColor();
    final fg = HSLColor.fromAHSL(1, h, 0.55, 0.85).toColor();
    final border = HSLColor.fromAHSL(0.6, h, 0.40, 0.42).toColor();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(size <= 24 ? 6 : 8),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: fg,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}
