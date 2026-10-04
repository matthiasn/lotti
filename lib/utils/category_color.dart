import 'package:material_ui/material_ui.dart';

/// Normalizes a CSS-style category color to an uppercase `RRGGBB` value.
///
/// Three-digit `RGB` shorthand is expanded and longer values (such as
/// `RRGGBBAA`) are truncated to their RGB channels. Malformed or incomplete
/// values return null so each caller can retain its own semantic fallback.
String? normalizeCategoryColorHex(String? colorHex) {
  final raw = colorHex?.trim().replaceFirst('#', '');
  if (raw == null) return null;
  final rgb = raw.length == 3
      ? raw.split('').map((channel) => '$channel$channel').join()
      : (raw.length > 6 ? raw.substring(0, 6) : raw);
  if (rgb.length != 6 || int.tryParse(rgb, radix: 16) == null) return null;
  return rgb.toUpperCase();
}

/// Resolves an opaque [Color] from a category `colorHex` string.
///
/// Malformed input falls back to `Colors.grey` instead of crashing.
Color categoryColorFromHex(String hex) {
  final rgb = normalizeCategoryColorHex(hex);
  if (rgb == null) return Colors.grey;
  final value = int.parse(rgb, radix: 16);
  return Color(value | 0xFF000000);
}
