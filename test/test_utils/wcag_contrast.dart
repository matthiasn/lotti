import 'dart:ui';

/// WCAG 2.1 relative-contrast ratio between two opaque colors.
///
/// Defined by SC 1.4.3 as `(L1 + 0.05) / (L2 + 0.05)` where `L1` is the
/// lighter of the two relative luminances. Order-independent, so callers do
/// not have to know which of the pair is the background.
///
/// Both colors must be opaque: `Color.computeLuminance` ignores alpha, so a
/// translucent ink measured directly reports the contrast it would have at
/// full strength — flattering, and wrong. Composite against the surface with
/// [Color.alphaBlend] first.
///
/// Thresholds worth naming, since the call sites all quote them:
/// - `4.5` — SC 1.4.3 AA for body text
/// - `3.0` — SC 1.4.3 AA for large text, and SC 1.4.11 for graphical objects
///   and UI-component state (dots, borders, glyphs that carry meaning alone)
double contrastRatio(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  final brightest = l1 > l2 ? l1 : l2;
  final darkest = l1 > l2 ? l2 : l1;
  return (brightest + 0.05) / (darkest + 0.05);
}
