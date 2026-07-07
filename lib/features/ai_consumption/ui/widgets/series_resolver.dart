import 'dart:ui' show Brightness, Color;

import 'package:lotti/features/insights/logic/chart_colors.dart';
import 'package:lotti/features/insights/model/insights_models.dart'
    show kInsightsOtherCategoryKey;
import 'package:lotti/features/insights/ui/widgets/insights_category_resolver.dart';

/// Resolves a stacked-series key to a display label and its chart fill /
/// legend swatch colors, so the impact chart can render any breakdown
/// dimension (category, model, serving location) through one dumb widget.
///
/// The two `null`/`kInsightsOtherCategoryKey` sentinels are handled by every
/// implementation: the "Other" rollup gets the cool slate
/// ([otherChartColor]), an unattributed key the neutral gray
/// ([neutralChartColor]).
abstract class SeriesResolver {
  /// Human label for [key] (never a raw UUID).
  String labelFor(String? key);

  /// Muted fill color for the series band.
  Color fillColor(String? key, Brightness brightness);

  /// Saturated identity color for a legend dot / table chip (small sizes).
  Color swatchColor(String? key, Brightness brightness);
}

/// Category dimension: delegates to the existing [InsightsCategoryResolver] +
/// `chartColorFor`/`swatchColorFor` so category charts stay pixel-identical
/// to before the [SeriesResolver] abstraction existed (each category keeps
/// its user-picked color).
class CategorySeriesResolver implements SeriesResolver {
  const CategorySeriesResolver(this.inner);

  final InsightsCategoryResolver inner;

  @override
  String labelFor(String? key) => inner.labelFor(key);

  @override
  Color fillColor(String? key, Brightness brightness) =>
      chartColorFor(inner.colorHexFor(key), brightness, seriesKey: key);

  @override
  Color swatchColor(String? key, Brightness brightness) =>
      swatchColorFor(inner.colorHexFor(key), brightness, seriesKey: key);
}

/// Model / serving-location dimension: keys carry no user-chosen color, so
/// colors come from the derived categorical [seriesPaletteChartColor] palette.
///
/// Each key is assigned a palette slot from `orderedKeys` — the caller passes
/// the keys in a **stable order** (e.g. sorted by id), so a given key keeps
/// its color across chart / legend / table and across periods as long as the
/// set of keys is stable, and no two keys shown together collide on a hue
/// (up to [kSeriesPaletteSize] keys). Keys not in `orderedKeys` fall back to a
/// deterministic hash slot.
class PaletteSeriesResolver implements SeriesResolver {
  PaletteSeriesResolver({
    required List<String> orderedKeys,
    required this.unknownLabel,
    required this.otherLabel,
  }) : _slotOf = {
         for (var i = 0; i < orderedKeys.length; i++) orderedKeys[i]: i,
       };

  /// Label for a `null` key — the dimension's "unknown" bucket (e.g. a call
  /// with no reported model id).
  final String unknownLabel;

  /// Label for the [kInsightsOtherCategoryKey] rollup.
  final String otherLabel;

  final Map<String, int> _slotOf;

  int _slot(String key) =>
      (_slotOf[key] ?? (key.hashCode & 0x7fffffff)) % kSeriesPaletteSize;

  @override
  String labelFor(String? key) {
    if (key == null) return unknownLabel;
    if (key == kInsightsOtherCategoryKey) return otherLabel;
    return key;
  }

  @override
  Color fillColor(String? key, Brightness brightness) {
    if (key == kInsightsOtherCategoryKey) return otherChartColor(brightness);
    if (key == null) return neutralChartColor(brightness);
    return seriesPaletteChartColor(_slot(key), brightness);
  }

  @override
  Color swatchColor(String? key, Brightness brightness) {
    if (key == kInsightsOtherCategoryKey) return otherChartColor(brightness);
    if (key == null) return neutralChartColor(brightness);
    return seriesPaletteSwatchColor(_slot(key), brightness);
  }
}
