import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/insights/logic/period_navigation.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:lotti/features/insights/ui/widgets/insights_period_stepper.dart';
import 'package:lotti/features/insights/ui/widgets/insights_pill_button.dart';

import '../../../../widget_test_utils.dart';

void main() {
  // A Sunday afternoon; its Monday-start week is Jun 1 – Jun 7 2026.
  final now = DateTime(2026, 6, 7, 16);

  InsightsPeriodSelection weekOf(DateTime date) => InsightsPeriodSelection(
    unit: InsightsPeriodUnit.week,
    range: periodContaining(InsightsPeriodUnit.week, date),
  );

  Future<void> pump(
    WidgetTester tester, {
    required InsightsPeriodSelection selection,
    ValueChanged<InsightsPeriodUnit>? onSelectUnit,
    ValueChanged<int>? onStep,
    VoidCallback? onOpenCalendar,
    VoidCallback? onToggleCompare,
    ValueChanged<InsightsPeriodUnit>? onSelectToDate,
  }) {
    return withClock(
      Clock.fixed(now),
      () => tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          InsightsPeriodStepper(
            selection: selection,
            onSelectUnit: onSelectUnit ?? (_) {},
            onStep: onStep ?? (_) {},
            onOpenCalendar: onOpenCalendar,
            onToggleCompare: onToggleCompare,
            onSelectToDate: onSelectToDate,
          ),
        ),
      ),
    );
  }

  testWidgets('shows the granularity and the current period label', (
    tester,
  ) async {
    await pump(tester, selection: weekOf(now));
    expect(find.text('Week'), findsOneWidget);
    expect(find.text('Jun 1 – 7 (so far)'), findsOneWidget);
  });

  testWidgets('the quarter label is localized via DateFormat', (tester) async {
    final q2 = InsightsPeriodSelection(
      unit: InsightsPeriodUnit.quarter,
      range: periodContaining(InsightsPeriodUnit.quarter, now),
    );
    await pump(tester, selection: q2);
    // yQQQ renders the quarter marker and year in locale order (en: Q2 2026),
    // rather than a hardcoded 'Q2 2026' string.
    expect(find.text('Q2 2026 (so far)'), findsOneWidget);
  });

  testWidgets('the back chevron steps one period back', (tester) async {
    var delta = 0;
    await pump(tester, selection: weekOf(now), onStep: (d) => delta = d);
    await tester.tap(find.byTooltip('Previous period'));
    expect(delta, -1);
  });

  testWidgets('the forward chevron is disabled on the current period', (
    tester,
  ) async {
    var delta = 0;
    await pump(tester, selection: weekOf(now), onStep: (d) => delta = d);
    await tester.tap(find.byTooltip('Next period'));
    expect(delta, 0); // disabled: no future period to step into
  });

  testWidgets('the forward chevron steps forward on a past period', (
    tester,
  ) async {
    var delta = 0;
    final lastWeek = InsightsPeriodSelection(
      unit: InsightsPeriodUnit.week,
      range: previousPeriod(
        periodContaining(InsightsPeriodUnit.week, now),
        InsightsPeriodUnit.week,
      ),
    );
    await pump(tester, selection: lastWeek, onStep: (d) => delta = d);
    await tester.tap(find.byTooltip('Next period'));
    expect(delta, 1);
  });

  testWidgets('tapping the period label opens the calendar', (tester) async {
    var opened = false;
    await pump(
      tester,
      selection: weekOf(now),
      onOpenCalendar: () => opened = true,
    );
    await tester.tap(find.text('Jun 1 – 7 (so far)'));
    expect(opened, isTrue);
  });

  testWidgets('the Compare pill toggles comparison', (tester) async {
    var toggled = 0;
    await pump(
      tester,
      selection: weekOf(now),
      onToggleCompare: () => toggled++,
    );
    await tester.tap(find.text('Compare'));
    expect(toggled, 1);
  });

  testWidgets('without onSelectToDate the MTD/YTD pills are hidden', (
    tester,
  ) async {
    await pump(tester, selection: weekOf(now));
    expect(find.text('This month'), findsNothing);
    expect(find.text('This year'), findsNothing);
  });

  testWidgets('tapping MTD requests month-to-date', (tester) async {
    InsightsPeriodUnit? requested;
    await pump(
      tester,
      selection: weekOf(now),
      onSelectToDate: (unit) => requested = unit,
    );
    await tester.tap(find.text('This month'));
    expect(requested, InsightsPeriodUnit.month);
  });

  testWidgets('tapping YTD requests year-to-date', (tester) async {
    InsightsPeriodUnit? requested;
    await pump(
      tester,
      selection: weekOf(now),
      onSelectToDate: (unit) => requested = unit,
    );
    await tester.tap(find.text('This year'));
    expect(requested, InsightsPeriodUnit.year);
  });

  testWidgets(
    'a month-to-date selection lights MTD and labels it to date',
    (tester) async {
      final mtd = InsightsPeriodSelection(
        unit: InsightsPeriodUnit.month,
        range: periodToDate(InsightsPeriodUnit.month, now),
      );
      await pump(tester, selection: mtd, onSelectToDate: (_) {});

      bool pillActive(String label) => tester
          .widget<InsightsPillButton>(
            find.widgetWithText(InsightsPillButton, label),
          )
          .active;
      expect(pillActive('This month'), isTrue);
      expect(pillActive('This year'), isFalse);
      // The partial period keeps the month name with a "(so far)" qualifier,
      // so it agrees with the granularity dropdown — never a bare "June 2026".
      expect(find.text('June 2026 (so far)'), findsOneWidget);
      expect(find.text('June 2026'), findsNothing);
    },
  );

  testWidgets(
    'a year-to-date selection lights YTD and labels it to date',
    (tester) async {
      final ytd = InsightsPeriodSelection(
        unit: InsightsPeriodUnit.year,
        range: periodToDate(InsightsPeriodUnit.year, now),
      );
      await pump(tester, selection: ytd, onSelectToDate: (_) {});
      expect(
        tester
            .widget<InsightsPillButton>(
              find.widgetWithText(InsightsPillButton, 'This year'),
            )
            .active,
        isTrue,
      );
      expect(find.text('2026 (so far)'), findsOneWidget);
    },
  );

  testWidgets('a full-month selection leaves MTD inactive', (tester) async {
    final fullMonth = InsightsPeriodSelection(
      unit: InsightsPeriodUnit.month,
      range: periodContaining(InsightsPeriodUnit.month, now),
    );
    await pump(tester, selection: fullMonth, onSelectToDate: (_) {});
    expect(
      tester
          .widget<InsightsPillButton>(
            find.widgetWithText(InsightsPillButton, 'This month'),
          )
          .active,
      isFalse,
    );
    // The current month is in progress, so it reads "(so far)" too; MTD is
    // inactive because the range is the full month, not the to-date slice.
    expect(find.text('June 2026 (so far)'), findsOneWidget);
  });

  testWidgets('selecting a granularity from the dropdown reports it', (
    tester,
  ) async {
    InsightsPeriodUnit? selected;
    await pump(
      tester,
      selection: weekOf(now),
      onSelectUnit: (unit) => selected = unit,
    );
    await tester.tap(find.text('Week')); // opens the dropdown
    await tester.pump(); // open the menu route
    await tester.pump(const Duration(milliseconds: 300)); // settle its anim
    await tester.tap(find.text('Month'));
    await tester.pump();
    expect(selected, InsightsPeriodUnit.month);
  });
}
