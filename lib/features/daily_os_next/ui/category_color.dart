import 'package:flutter/material.dart';

/// Resolves an opaque [Color] from a category `colorHex` string.
///
/// The hex string upstream is normalised to ≤6 hex characters by
/// `RealDayAgent._projectCategory`, but we still trim to the first 6
/// chars defensively so a future change to the boundary contract
/// (e.g. raw `RRGGBBAA` slipping through) can't shift colour channels.
/// Malformed input falls back to `Colors.grey` instead of crashing.
Color categoryColorFromHex(String hex) {
  final raw = hex.trim().replaceFirst('#', '');
  final rgb = raw.length > 6 ? raw.substring(0, 6) : raw;
  final value = int.tryParse(rgb, radix: 16);
  if (value == null) return Colors.grey;
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
