import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/utils.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/charts/utils.dart';

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
  group('formatAxisValue', () {
    test('keeps one fractional digit below 1000', () {
      expect(formatAxisValue(50.5), '50.5');
      expect(formatAxisValue(99.5), '99.5');
      expect(formatAxisValue(100.5), '100.5');
    });

    test('drops the optional decimal for whole values below 1000', () {
      expect(formatAxisValue(42), '42');
      expect(formatAxisValue(0), '0');
    });

    test('uses compact notation at or above 1000 so labels never clip', () {
      // Compact notation keeps thousands/ten-thousands short enough to fit the
      // reserved gutter at narrow detail-pane widths.
      expect(formatAxisValue(1500), '1.5K');
      expect(formatAxisValue(2405), '2.4K');
      expect(formatAxisValue(14278), '14.3K');
    });
  });

  group('niceAxis', () {
    test('produces rounded, evenly-spaced zero-based ticks for bars', () {
      final axis = niceAxis(0, 14278, zeroBased: true);
      expect(axis.min, 0);
      expect(axis.max, greaterThanOrEqualTo(14278));
      expect(axis.interval, 5000);
      expect(axis.max, 15000);
    });

    test('brackets a non-zero-based range on nice round bounds', () {
      final axis = niceAxis(51, 69);
      expect(axis.interval, 5);
      expect(axis.min, 50);
      expect(axis.max, 70);
      // The data is fully contained.
      expect(axis.min, lessThanOrEqualTo(51));
      expect(axis.max, greaterThanOrEqualTo(69));
    });

    test('never returns a zero interval for a degenerate range', () {
      final axis = niceAxis(5, 5);
      expect(axis.interval, greaterThan(0));
      expect(axis.max, greaterThan(axis.min));
    });
  });

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

    testWidgets('formats the value compactly above 1000', (tester) async {
      expect(await _renderedLabel(tester, 14278), '14.3K');
    });
  });

  group('ChartLabel', () {
    testWidgets('renders centered, legible body-small medium-emphasis text', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const Scaffold(body: ChartLabel('hello')),
        ),
      );
      await tester.pump();

      expect(find.text('hello'), findsOneWidget);
      // No half-opacity overlay anymore — colour comes straight from the
      // medium-emphasis token so axis labels stay readable.
      expect(find.byType(Opacity), findsNothing);

      final tokens = tester.element(find.text('hello')).designTokens;
      final text = tester.widget<Text>(find.text('hello'));
      expect(text.textAlign, TextAlign.center);
      expect(text.style?.color, dsTokensLight.colors.text.mediumEmphasis);
      // Axis labels now use body-small (not the smaller caption) for legibility.
      expect(
        text.style?.fontSize,
        tokens.typography.styles.body.bodySmall.fontSize,
      );
    });
  });

  group('DashboardChartDateAxis', () {
    final rangeStart = DateTime(2024, 3);
    final rangeEnd = DateTime(2024, 3, 31);

    testWidgets(
      'renders four evenly-spaced labels with the range bounds at the ends',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            Scaffold(
              body: DashboardChartDateAxis(
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
              ),
            ),
          ),
        );
        await tester.pump();

        final labels = tester.widgetList<ChartLabel>(find.byType(ChartLabel));
        // Four ticks: start, +1/3, +2/3, end — aligned with the linear axis.
        expect(labels, hasLength(4));

        final texts = labels.map((l) => l.text).toList();
        // First label is the formatted rangeStart, last is the rangeEnd —
        // both bar and line cards now agree on the start/end date at the ends.
        expect(
          texts.first,
          chartDateFormatterMmDd(rangeStart.millisecondsSinceEpoch),
        );
        expect(
          texts.last,
          chartDateFormatterMmDd(rangeEnd.millisecondsSinceEpoch),
        );
      },
    );

    testWidgets('left-pads by the shared value-axis gutter width', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(
            body: DashboardChartDateAxis(
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
            ),
          ),
        ),
      );
      await tester.pump();

      final padding = tester.widget<Padding>(
        find
            .descendant(
              of: find.byType(DashboardChartDateAxis),
              matching: find.byType(Padding),
            )
            .first,
      );
      // The gutter pad lines the labels up under the plot, not under the
      // y-axis numbers, so they match the chart's reserved left-titles width.
      expect(
        (padding.padding as EdgeInsets).left,
        kChartLeftAxisWidth,
      );
    });
  });
}
