import 'dart:ui' show Brightness, Color, clampDouble;

import 'package:flutter/painting.dart' show HSLColor;
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:lotti/utils/color.dart';

/// Chart color derivation for the Insights dashboard.
///
/// Users pick fully saturated category colors with a free color picker, so
/// raw category colors painted across large chart areas would be garish,
/// potentially invisible against the background (yellow on white), and
/// indistinguishable from each other. Following Stephen Few's guidance,
/// chart fills are a *muted* derivation of the category color — hue is
/// preserved for identity, saturation and lightness are clamped into a
/// band that reads against the active theme background. The original
/// saturated color remains in small swatches (legend dots, table chips).

/// Muted fill color for chart series, derived from [base].
Color mutedChartColor(Color base, Brightness brightness) {
  final hsl = HSLColor.fromColor(base);
  final saturation = clampDouble(hsl.saturation * 0.65, 0.18, 0.52);
  final lightness = brightness == Brightness.dark
      ? clampDouble(hsl.lightness, 0.42, 0.62)
      : clampDouble(hsl.lightness, 0.36, 0.56);
  return hsl
      .withSaturation(saturation)
      .withLightness(lightness)
      .withAlpha(1)
      .toColor();
}

/// Neutral fill for uncategorized time: a true gray that never competes
/// with category hues.
Color neutralChartColor(Brightness brightness) => brightness == Brightness.dark
    ? const HSLColor.fromAHSL(1, 0, 0, 0.45).toColor()
    : const HSLColor.fromAHSL(1, 0, 0, 0.62).toColor();

/// Fill for the "Other" rollup: a cool slate clearly distinct from the
/// warm-neutral uncategorized gray, so the two never read as the same
/// series.
Color otherChartColor(Brightness brightness) => brightness == Brightness.dark
    ? const HSLColor.fromAHSL(1, 220, 0.22, 0.52).toColor()
    : const HSLColor.fromAHSL(1, 220, 0.22, 0.66).toColor();

/// Edge stroke for stacked-area bands: a lightened (dark theme) or
/// darkened (light theme) variant of the fill so adjacent muted bands stay
/// separable instead of smearing together.
Color bandEdgeColor(Color fill, Brightness brightness) {
  final hsl = HSLColor.fromColor(fill);
  final lightness = brightness == Brightness.dark
      ? clampDouble(hsl.lightness + 0.14, 0, 1)
      : clampDouble(hsl.lightness - 0.14, 0, 1);
  return hsl.withLightness(lightness).toColor();
}

/// Resolves the chart fill for a series key.
///
/// [categoryColorHex] is the raw CSS hex from `CategoryDefinition.color`.
/// The "Other" sentinel gets the cool slate; `null` (uncategorized or a
/// deleted definition) the neutral gray.
Color chartColorFor(
  String? categoryColorHex,
  Brightness brightness, {
  String? seriesKey,
}) {
  if (seriesKey == kInsightsOtherCategoryKey) {
    return otherChartColor(brightness);
  }
  final neutral = neutralChartColor(brightness);
  if (categoryColorHex == null) return neutral;
  return mutedChartColor(
    colorFromCssHex(categoryColorHex, substitute: neutral),
    brightness,
  );
}

/// Saturated swatch color for legends and table chips — the category's own
/// identity color, used only at small sizes.
Color swatchColorFor(
  String? categoryColorHex,
  Brightness brightness, {
  String? seriesKey,
}) {
  if (seriesKey == kInsightsOtherCategoryKey) {
    return otherChartColor(brightness);
  }
  final neutral = neutralChartColor(brightness);
  if (categoryColorHex == null) return neutral;
  return colorFromCssHex(categoryColorHex, substitute: neutral);
}
