import 'dart:ui' show Brightness;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/series_resolver.dart';
import 'package:lotti/features/insights/logic/chart_colors.dart';
import 'package:lotti/features/insights/model/insights_models.dart'
    show kInsightsOtherCategoryKey;
import 'package:lotti/features/insights/ui/widgets/insights_category_resolver.dart';

import '../../../categories/test_utils.dart';

void main() {
  const dark = Brightness.dark;

  group('CategorySeriesResolver', () {
    final inner = InsightsCategoryResolver(
      categoriesById: {
        'cat-a': CategoryTestUtils.createTestCategory(
          id: 'cat-a',
          name: 'Agents',
          color: '#3B82F6',
        ),
      },
      uncategorizedLabel: 'Uncategorized',
      otherLabel: 'Other',
      deletedLabel: 'Deleted',
    );
    final resolver = CategorySeriesResolver(inner);

    test('delegates labels to the inner resolver', () {
      expect(resolver.labelFor('cat-a'), 'Agents');
      expect(resolver.labelFor(null), 'Uncategorized');
      expect(resolver.labelFor(kInsightsOtherCategoryKey), 'Other');
    });

    test('reproduces the exact chartColorFor / swatchColorFor output', () {
      // Behaviour must be pixel-identical to the pre-abstraction path so the
      // category chart never regresses.
      expect(
        resolver.fillColor('cat-a', dark),
        chartColorFor('#3B82F6', dark, seriesKey: 'cat-a'),
      );
      expect(
        resolver.swatchColor('cat-a', dark),
        swatchColorFor('#3B82F6', dark, seriesKey: 'cat-a'),
      );
      // Uncategorized → neutral gray; Other → slate — via the same helpers.
      expect(resolver.fillColor(null, dark), neutralChartColor(dark));
      expect(
        resolver.fillColor(kInsightsOtherCategoryKey, dark),
        otherChartColor(dark),
      );
    });
  });

  group('PaletteSeriesResolver', () {
    final resolver = PaletteSeriesResolver(
      orderedKeys: const ['glm-4.6', 'claude-opus-4', 'gpt-5'],
      unknownLabel: 'Unknown model',
      otherLabel: 'Other models',
    );

    test('shows the raw key as its own label', () {
      expect(resolver.labelFor('claude-opus-4'), 'claude-opus-4');
      expect(resolver.labelFor(null), 'Unknown model');
      expect(resolver.labelFor(kInsightsOtherCategoryKey), 'Other models');
    });

    test('gives each ordered key a distinct palette color', () {
      final fills = [
        resolver.fillColor('glm-4.6', dark),
        resolver.fillColor('claude-opus-4', dark),
        resolver.fillColor('gpt-5', dark),
      ];
      expect(
        fills.toSet(),
        hasLength(3),
        reason: 'no two visible models share a hue',
      );
      // Fill comes from the palette by the key's slot (its ordered index).
      expect(
        resolver.fillColor('glm-4.6', dark),
        seriesPaletteChartColor(0, dark),
      );
      expect(
        resolver.fillColor('gpt-5', dark),
        seriesPaletteChartColor(2, dark),
      );
      expect(
        resolver.swatchColor('claude-opus-4', dark),
        seriesPaletteSwatchColor(1, dark),
      );
    });

    test(
      'a key keeps its color regardless of query order (stable identity)',
      () {
        // Same ordered set → same slot → same color, so a model reads the same
        // in the chart, the legend, and the table.
        final again = PaletteSeriesResolver(
          orderedKeys: const ['glm-4.6', 'claude-opus-4', 'gpt-5'],
          unknownLabel: 'Unknown model',
          otherLabel: 'Other models',
        );
        expect(
          again.fillColor('claude-opus-4', dark),
          resolver.fillColor('claude-opus-4', dark),
        );
      },
    );

    test('routes the sentinels to slate / neutral, not the palette', () {
      expect(
        resolver.fillColor(kInsightsOtherCategoryKey, dark),
        otherChartColor(dark),
      );
      expect(resolver.fillColor(null, dark), neutralChartColor(dark));
    });

    test('an unordered key still resolves to some palette slot', () {
      final color = resolver.fillColor('mystery-model', dark);
      expect(color, isA<Color>());
    });
  });
}
