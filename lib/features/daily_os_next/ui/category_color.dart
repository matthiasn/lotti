import 'package:flutter/material.dart';

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

/// Category-tint alpha for a timeline block fill, encoding the
/// paint-by-numbers contract: planned blocks are a faint sketch waiting
/// to be filled in; recorded ("tracked") blocks are the filled-in paint.
/// Recorded needs more chroma in light mode to keep the filled-in/sketch
/// contrast legible on a white canvas. Composite the result over the
/// canvas color — fills must stay opaque so gridlines never bleed
/// through the cards.
double timelineBlockTintAlpha({required bool tracked, required bool isLight}) {
  if (!tracked) return 0.05;
  return isLight ? 0.30 : 0.18;
}

/// Alpha for a planned block's category-colored accents (left stripe,
/// dashed outline): strong enough to key the category, faint enough to
/// keep the sketch reading provisional. Recorded blocks use the full
/// category color instead.
const double kTimelinePlannedAccentAlpha = 0.45;
