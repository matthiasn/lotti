import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Lightweight wrapper around google_fonts to make font usage
/// safe and deterministic in tests and constrained environments.
///
/// If `GoogleFonts.config.allowRuntimeFetching` is false (as in many test
/// environments), these helpers return a plain TextStyle with the requested
/// attributes so no network fetch or asset lookup is required. When runtime
/// fetching is allowed, they delegate to google_fonts normally.
class AppFonts {
  const AppFonts._();

  static TextStyle inconsolata({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
  }) {
    if (GoogleFonts.config.allowRuntimeFetching) {
      return GoogleFonts.inconsolata(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
      );
    }
    // Fallback style: use requested attributes without triggering font loads.
    return TextStyle(
      fontFamily: 'Inconsolata',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }
}
// End of file
