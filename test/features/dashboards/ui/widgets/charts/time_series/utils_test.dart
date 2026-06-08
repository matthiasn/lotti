import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/utils.dart';

import '../../../../../../widget_test_utils.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a minimal, valid `TitleMeta`. The `leftTitleWidgets` callback never
/// reads any field of `TitleMeta`; it only formats `value`, so the concrete
/// field values here are irrelevant to the assertions and exist solely to
/// satisfy fl_chart's required constructor parameters.
TitleMeta _titleMeta() => TitleMeta(
  min: 0,
  max: 100,
  parentAxisSize: 100,
  axisPosition: 0,
  appliedInterval: 1,
  sideTitles: const SideTitles(),
  formattedValue: '',
  axisSide: AxisSide.left,
  rotationQuarterTurns: 0,
);

/// Pumps the [leftTitleWidgets] output for [value] and returns the rendered
/// label string.
Future<String> _renderedLabel(WidgetTester tester, double value) async {
  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      Scaffold(body: Center(child: leftTitleWidgets(value, _titleMeta()))),
    ),
  );
  await tester.pump();

  final textWidget = tester.widget<Text>(find.byType(Text));
  return textWidget.data!;
}

void main() {
  group('leftTitleWidgets', () {
    testWidgets('renders a ChartLabel widget', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(body: leftTitleWidgets(42, _titleMeta())),
        ),
      );
      await tester.pump();

      expect(find.byType(ChartLabel), findsOneWidget);
    });

    testWidgets(
      'values at or below 100 keep one fractional digit (####.# branch)',
      (tester) async {
        // 50.5 → "50.5": the .# placeholder is filled by the non-zero fraction.
        expect(await _renderedLabel(tester, 50.5), '50.5');
      },
    );

    testWidgets(
      'a whole value <= 100 drops the optional decimal (####.# branch)',
      (tester) async {
        // 42 → "42": the trailing .# is optional and omitted for a zero
        // fraction, so no ".0" is appended.
        expect(await _renderedLabel(tester, 42), '42');
      },
    );

    testWidgets(
      'a fractional value just below the boundary keeps its decimal',
      (tester) async {
        // 99.5 <= 100, so value > 100 is false and the ####.# format runs.
        expect(await _renderedLabel(tester, 99.5), '99.5');
      },
    );

    testWidgets(
      'crossing above 100 switches to the no-decimal #### branch',
      (tester) async {
        // 100.5 > 100 is true, so the #### format rounds to "101" — proving
        // the branch flips at exactly 100.
        expect(await _renderedLabel(tester, 100.5), '101');
      },
    );

    testWidgets(
      'values above 100 are rendered without decimals (#### branch)',
      (tester) async {
        // 150.5 → "151": the #### format rounds to the nearest integer and
        // drops the fractional part entirely.
        expect(await _renderedLabel(tester, 150.5), '151');
      },
    );

    testWidgets(
      'a large whole value above 100 has no decimal point (#### branch)',
      (tester) async {
        expect(await _renderedLabel(tester, 1234), '1234');
      },
    );
  });

  group('ChartLabel', () {
    testWidgets('dims the text via the labelOpacity constant', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const Scaffold(body: ChartLabel('hello')),
        ),
      );
      await tester.pump();

      expect(find.text('hello'), findsOneWidget);

      final opacity = tester.widget<Opacity>(
        find.ancestor(
          of: find.text('hello'),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, labelOpacity);

      final text = tester.widget<Text>(find.text('hello'));
      expect(text.textAlign, TextAlign.center);
    });
  });
}
