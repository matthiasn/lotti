import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/habits/state/heatmap/habit_heatmap_data.dart';
import 'package:lotti/features/habits/ui/widgets/heatmap/habit_heatmap_grid.dart';
import 'package:lotti/themes/colors.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  // A single Monday-first week (2024-06-10 is a Monday) with a spread of
  // intensities, a 0-success in-range day, a pre-existence day and today.
  final week = <HeatmapDay>[
    const HeatmapDay(
      ymd: '2024-06-10',
      successCount: 2,
      activeCount: 2,
      isToday: false,
    ), // full
    const HeatmapDay(
      ymd: '2024-06-11',
      successCount: 1,
      activeCount: 2,
      isToday: false,
    ), // half
    const HeatmapDay(
      ymd: '2024-06-12',
      successCount: 0,
      activeCount: 2,
      isToday: false,
    ), // in range, nothing done
    const HeatmapDay(
      ymd: '2024-06-13',
      successCount: 0,
      activeCount: 0,
      isToday: false,
    ), // before any habit existed
    const HeatmapDay(
      ymd: '2024-06-14',
      successCount: 1,
      activeCount: 1,
      isToday: true,
    ), // today
  ];

  List<List<HeatmapDay?>> columns({int firstDay = 1}) =>
      groupIntoWeekColumns(week, firstDayOfWeekIndex: firstDay);

  Future<void> pump(
    WidgetTester tester, {
    int firstDay = 1,
    List<List<HeatmapDay?>>? cols,
  }) async {
    await tester.pumpWidget(
      makeTestableWidget(
        HabitHeatmapGrid(
          columns: cols ?? columns(firstDay: firstDay),
          firstDayOfWeekIndex: firstDay,
        ),
      ),
    );
    await tester.pump();
  }

  Finder cell(String ymd) => find.byKey(ValueKey('habit-heatmap-cell-$ymd'));

  BoxDecoration decoFor(WidgetTester tester, String ymd) {
    final container = tester.widget<Container>(cell(ymd));
    return container.decoration! as BoxDecoration;
  }

  testWidgets('renders a horizontal, reverse list with one item per column', (
    tester,
  ) async {
    await pump(tester);
    final list = tester.widget<ListView>(find.byType(ListView));
    expect(list.scrollDirection, Axis.horizontal);
    expect(list.reverse, isTrue);
    expect(find.byType(HabitHeatmapGrid), findsOneWidget);
  });

  testWidgets('in-range days expose a date + count semantics label', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester);
    // Cells merge into the column's semantics node; the merged label is the
    // meaningful cells in order, with pre-existence days (Jun 13) excluded.
    final merged = tester.getSemantics(cell('2024-06-10')).label;
    expect(merged, contains('Jun 10, 2 of 2 done'));
    expect(merged, contains('Jun 12, 0 of 2 done'));
    expect(merged, contains('Jun 14, 1 of 1 done'));
    expect(merged, isNot(contains('Jun 13')));
    handle.dispose();
  });

  testWidgets('pre-existence days carry no tooltip', (tester) async {
    await pump(tester);
    expect(find.byTooltip('Jun 13 · 0/0'), findsNothing);
  });

  testWidgets('each in-range cell has a date · count tooltip', (tester) async {
    await pump(tester);
    expect(find.byTooltip('Jun 10 · 2/2'), findsOneWidget);
    expect(find.byTooltip('Jun 14 · 1/1'), findsOneWidget);
  });

  testWidgets('only today carries the ring border', (tester) async {
    await pump(tester);
    expect(decoFor(tester, '2024-06-14').border, isNotNull);
    expect(decoFor(tester, '2024-06-10').border, isNull);
  });

  testWidgets('intensity drives a success-coloured alpha ramp', (tester) async {
    await pump(tester);
    final full = decoFor(tester, '2024-06-10').color!;
    final half = decoFor(tester, '2024-06-11').color!;
    // More completion → more opaque.
    expect(full.a, greaterThan(half.a));
    // The shaded fill is the green success colour, not red.
    expect(full.g, greaterThan(full.r));
    expect(full.g, greaterThan(full.b));
  });

  testWidgets('a day with nothing done is neutral, never red', (tester) async {
    await pump(tester);
    final empty = decoFor(tester, '2024-06-12').color!;
    expect(empty, isNot(alarm));
    expect(empty, isNot(successColor));
    // Neutral = roughly equal channels (translucent black/white overlay).
    expect((empty.r - empty.g).abs(), lessThan(0.05));
    expect((empty.g - empty.b).abs(), lessThan(0.05));
  });

  for (final firstDay in [0, 1, 6]) {
    testWidgets('weekday gutter labels M/W/F (first day $firstDay)', (
      tester,
    ) async {
      // Distinct initials Mon/Wed/Fri are labelled at their rows for any
      // first-day-of-week — never the ambiguous Tue/Thu "T" pair.
      await pump(tester, firstDay: firstDay);
      expect(find.text('M'), findsOneWidget);
      expect(find.text('W'), findsOneWidget);
      expect(find.text('F'), findsOneWidget);
    });
  }

  testWidgets('labels the month above the first column of each month', (
    tester,
  ) async {
    // The sample week is in June → a single "Jun" month label anchors it.
    await pump(tester);
    expect(find.text('Jun'), findsOneWidget);
  });

  testWidgets('empty columns render the gutter and no cells', (tester) async {
    await pump(tester, cols: const []);
    expect(find.bySemanticsLabel('Jun 14, 1 of 1 done'), findsNothing);
    // Gutter still present (Mon/Wed/Fri labels), no month labels without cells.
    expect(find.text('M'), findsOneWidget);
    expect(find.text('Jun'), findsNothing);
  });
}
