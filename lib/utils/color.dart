import 'package:flutter/material.dart';

// Converts CSS style color string in the form #RRGGBB or #RRGGBBAA, where AA
// represents the alpha channel. Returns substitute color if string is invalid.
Color colorFromCssHex(
  String? input, {
  Color substitute = Colors.pink,
}) {
  final regex = RegExp('#([0-9a-fA-F]{6})([0-9a-fA-F]{2})?');

  if (input == null || !regex.hasMatch(input)) {
    return substitute;
  }

  final withoutHash = input.replaceFirst('#', '');
  final hasAlpha = withoutHash.length == 8;
  final alpha = hasAlpha ? withoutHash.substring(6, 8) : 'FF';
  final rgb = withoutHash.substring(0, 6);
  return Color(int.parse('$alpha$rgb', radix: 16));
}

// Converts Color to CSS style hex color string
String colorToCssHex(Color color, {bool leadingHashSign = true}) {
  final rgb = '${leadingHashSign ? '#' : ''}'
      '${color.red.toRadixString(16).padLeft(2, '0')}'
      '${color.green.toRadixString(16).padLeft(2, '0')}'
      '${color.blue.toRadixString(16).padLeft(2, '0')}';
  final alpha = color.alpha.toRadixString(16).padLeft(2, '0');
  return '$rgb${alpha == 'ff' ? '' : alpha}'.toUpperCase();
}
