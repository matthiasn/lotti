import 'package:flutter/material.dart';

/// Resolves an opaque [Color] from a category `colorHex` string.
///
/// The hex string upstream is normalised to ≤6 hex characters by
/// `RealDayAgent._projectCategory`, but we still trim to the first 6
/// chars defensively so a future change to the boundary contract
/// (e.g. raw `RRGGBBAA` slipping through) can't shift colour channels.
/// Malformed input falls back to `Colors.grey` instead of crashing.
Color categoryColorFromHex(String hex) {
  final raw = hex.replaceFirst('#', '');
  final rgb = raw.length > 6 ? raw.substring(0, 6) : raw;
  final value = int.tryParse(rgb, radix: 16);
  if (value == null) return Colors.grey;
  return Color(value | 0xFF000000);
}
