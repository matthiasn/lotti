import 'package:flutter/material.dart';

/// A small rounded-square swatch filled with [color] (corner radius `size/4`).
/// Reused wherever a bare color chip is needed.
class ColorIcon extends StatelessWidget {
  const ColorIcon(
    this.color, {
    this.size = 20.0,
    super.key,
  });

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 4),
      child: Container(
        height: size,
        width: size,
        color: color,
      ),
    );
  }
}
