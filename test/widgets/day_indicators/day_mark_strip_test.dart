import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/design_system/components/ds_dashed_border.dart';
import 'package:lotti/features/design_system/components/tooltips/ds_tooltip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/ui/goal_day_marks.dart';
import 'package:lotti/widgets/day_indicators/day_mark.dart';
import 'package:lotti/widgets/day_indicators/day_mark_cell.dart';
import 'package:lotti/widgets/day_indicators/day_mark_strip.dart';
import 'package:lotti/widgets/day_indicators/day_mark_styles.dart';
import 'package:lotti/widgets/day_indicators/day_track.dart';

import '../../widget_test_utils.dart';

void main() {
  final today = DateTime.utc(2026, 8, 11);
  const week = [
    DayMarkState.full,
    DayMarkState.none,
    DayMarkState.partial,
    DayMarkState.none,
    DayMarkState.none,
    DayMarkState.full,
    DayMarkState.none,
  ];

  String cell(int daysBack, String outcome) =>
      '${DateFormat.MMMEd().format(today.subtract(Duration(days: daysBack)))}'
      ': $outcome';

  Finder squares() => find.descendant(
    of: find.byType(DayMarkCell),
    matching: find.byType(Container),
  );

  Color fillAt(WidgetTester tester, int index) =>
      (tester.widget<Container>(squares().at(index)).decoration!
              as BoxDecoration)
          .color!;

  testWidgets('a read-only strip reports the number of successful days once '
      'in semantics and draws the squares with their kept ticks', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        DayMarkStrip(marks: goalDayMarks(states: week)),
      ),
    );
    expect(
      find.bySemanticsLabel(
        '3 successful days in the trailing seven-day window',
      ),
      findsOneWidget,
    );
    expect(find.byType(DayMarkCell), findsNWidgets(7));
    // Undated marks carry no weekday letter; the kept days — the partial
    // one included — carry the tick.
    expect(find.byType(Text), findsNothing);
    expect(find.byType(Icon), findsNWidgets(3));
    expect(
      find.descendant(
        of: find.byType(DayMarkCell).first,
        matching: find.byIcon(dayVerdictGlyph(DayVerdict.met)),
      ),
      findsOneWidget,
    );
    // The last mark is today and it is empty: "not yet", the dashed
    // unresolved outline, never a past day's grey.
    expect(find.byType(DsDashedBorder), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(DayMarkCell).last,
        matching: find.byType(DsDashedBorder),
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('today is dashed only while it is still open', (tester) async {
    for (final (state, verdict, dashed) in [
      (DayMarkState.none, null, true),
      (DayMarkState.full, null, false),
      (DayMarkState.skipped, null, false),
      (DayMarkState.none, DayVerdict.missed, false),
    ]) {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          DayMarkStrip(
            marks: [
              DayMark(
                day: today,
                state: state,
                verdict: verdict,
                isToday: true,
              ),
            ],
          ),
        ),
      );
      expect(
        find.byType(DsDashedBorder),
        dashed ? findsOneWidget : findsNothing,
        reason: '$state / $verdict',
      );
    }
  });

  testWidgets('the squares sit on the shared column pitch with one step of '
      'air between them', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Align(
          alignment: Alignment.topLeft,
          child: DayMarkStrip(marks: goalDayMarks(states: week)),
        ),
      ),
    );
    final tokens = tester.element(find.byType(DayMarkStrip)).designTokens;
    final pitch = kDaySquareSize + tokens.spacing.step2;
    for (var index = 0; index < 7; index++) {
      final rect = tester.getRect(find.byType(DayMarkCell).at(index));
      expect(rect.size, const Size.square(kDaySquareSize), reason: '$index');
      expect(rect.center.dx, pitch * index + pitch / 2, reason: '$index');
    }
    expect(
      tester.getSize(find.byType(DayTrack)),
      Size(pitch * 7, kDaySquareSize),
    );
  });

  testWidgets('a read-only strip announces its verdicts in the summary', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        DayMarkStrip(
          marks: goalDayMarks(
            states: List.filled(3, DayMarkState.none),
            lastDay: today,
            verdictsByDay: {
              today.subtract(const Duration(days: 2)): DayVerdict.met,
              today.subtract(const Duration(days: 1)): DayVerdict.missed,
            },
          ),
        ),
      ),
    );
    // A read-only strip publishes one summary rather than seven nodes, so the
    // verdicts have to reach it there — otherwise the list announced a
    // measured day count while showing four verdict hues.
    final label = tester
        .getSemantics(
          find
              .descendant(
                of: find.byType(DayMarkStrip),
                matching: find.byType(Semantics),
              )
              .first,
        )
        .label;
    expect(label, startsWith('1 successful day'));
    expect(label, contains(cell(2, 'Met')));
    expect(label, contains(cell(1, 'Missed')));
    handle.dispose();
  });

  testWidgets('a tappable strip reports the day each cell stands for, '
      'counting back from the last', (tester) async {
    final handle = tester.ensureSemantics();
    final tapped = <DateTime>[];
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        DayMarkStrip(
          marks: goalDayMarks(states: week, lastDay: today),
          onDaySelected: tapped.add,
        ),
      ),
    );
    // The oldest cell is six days back and the last one is today. Tapping a
    // *past* day is the point: before this, the only way to reflect on a day
    // was the "Reflect on today" row.
    await tester.tap(find.bySemanticsLabel(cell(6, 'done · target met')));
    await tester.tap(find.bySemanticsLabel(cell(0, 'No entry')));
    expect(tapped, [today.subtract(const Duration(days: 6)), today]);
    // Colour is the only visual difference between these cells, and it does
    // not reach a screen reader. Each day names its own state.
    expect(
      find.bySemanticsLabel(cell(4, 'done · target not met yet')),
      findsOneWidget,
    );
    // An action says which day it acts on: every square that has no
    // outcome yet carries its weekday initial inside itself; the kept
    // days (six, four and one back — four is the partial one) carry the
    // tick instead.
    for (var daysBack = 6; daysBack >= 0; daysBack--) {
      final day = today.subtract(Duration(days: daysBack));
      final letter = dayMarkWeekdayLabel('en', day);
      final cell = find.byWidgetPredicate(
        (widget) => widget is DayMarkCell && widget.mark.day == day,
      );
      final kept = daysBack == 6 || daysBack == 4 || daysBack == 1;
      expect(
        find.descendant(of: cell, matching: find.text(letter)),
        kept ? findsNothing : findsOneWidget,
        reason: letter,
      );
      expect(
        find.descendant(of: cell, matching: find.byType(Icon)),
        kept ? findsOneWidget : findsNothing,
        reason: letter,
      );
    }
    expect(find.byType(Text), findsNWidgets(4));
    handle.dispose();
  });

  testWidgets('a recorded verdict outranks the measured state, and each '
      'verdict has its own colour', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        DayMarkStrip(
          marks: goalDayMarks(
            states: List.filled(7, DayMarkState.none),
            lastDay: today,
            verdictsByDay: {
              today.subtract(const Duration(days: 3)): DayVerdict.met,
              today.subtract(const Duration(days: 2)): DayVerdict.improving,
              today.subtract(const Duration(days: 1)): DayVerdict.mixed,
              today: DayVerdict.missed,
            },
          ),
          onDaySelected: (_) {},
        ),
      ),
    );
    final tokens = tester.element(find.byType(DayMarkStrip)).designTokens;
    expect(fillAt(tester, 0), dayMarkStateFill(tokens, DayMarkState.none));
    expect(fillAt(tester, 3), dayVerdictFill(tokens, DayVerdict.met));
    expect(fillAt(tester, 4), dayVerdictFill(tokens, DayVerdict.improving));
    expect(fillAt(tester, 5), dayVerdictFill(tokens, DayVerdict.mixed));
    expect(fillAt(tester, 6), dayVerdictFill(tokens, DayVerdict.missed));
    // All four are distinguishable, and none of them is the grey of a day
    // nobody looked at.
    final verdicts = {for (var i = 3; i < 7; i++) fillAt(tester, i)};
    expect(verdicts, hasLength(4));
    expect(verdicts, isNot(contains(fillAt(tester, 0))));
  });

  testWidgets('a day the caller declines is drawn read-only inside a '
      'tappable strip', (tester) async {
    final handle = tester.ensureSemantics();
    final tapped = <DateTime>[];
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        DayMarkStrip(
          marks: goalDayMarks(states: week, lastDay: today),
          onDaySelected: tapped.add,
          isDaySelectable: (day) => day != today,
        ),
      ),
    );
    expect(find.bySemanticsLabel(cell(0, 'No entry')), findsNothing);
    expect(find.bySemanticsLabel(cell(1, 'done · target met')), findsOneWidget);
    final todayCell = find.byWidgetPredicate(
      (widget) => widget is DayMarkCell && widget.mark.day == today,
    );
    expect(tester.widget<DayMarkCell>(todayCell).onTap, isNull);
    expect(
      tester
          .widget<DsTooltip>(
            find.descendant(of: todayCell, matching: find.byType(DsTooltip)),
          )
          .title,
      DateFormat.MMMEd().format(today),
      reason: 'hover still names the day',
    );
    await tester.tap(todayCell, warnIfMissed: false);
    await tester.tap(find.bySemanticsLabel(cell(1, 'done · target met')));
    expect(tapped, [today.subtract(const Duration(days: 1))]);
    handle.dispose();
  });

  testWidgets('tapping does not change the pitch, only the slot height', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        SizedBox(
          width: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DayMarkStrip(marks: goalDayMarks(states: week)),
              DayMarkStrip(
                marks: goalDayMarks(states: week, lastDay: today),
                onDaySelected: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    final tracks = tester.widgetList<DayTrack>(find.byType(DayTrack)).toList();
    expect(tracks[0].pitch, tracks[1].pitch);
    expect(tracks[0].height, kDaySquareSize);
    expect(tracks[1].height, TapTargets.minimum);
    final slots = find.descendant(
      of: find.byType(DayMarkStrip).at(1),
      matching: find.byType(InkWell),
    );
    expect(tester.getSize(slots.first).width, tracks[1].pitch);
    expect(
      tester.getSize(slots.first).height,
      greaterThanOrEqualTo(TapTargets.minimum),
    );
  });

  testWidgets('a placeholder strip keeps the silhouette without borrowing the '
      'empty-week fill', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        DayMarkStrip(
          marks: goalDayMarks(states: List.filled(3, DayMarkState.none)),
          placeholder: true,
        ),
      ),
    );
    expect(find.byType(DsDashedBorder), findsNWidgets(3));
    expect(find.byType(DayMarkCell), findsNothing);
    expect(
      tester.getSize(find.byType(PlaceholderDayCell).first),
      const Size.square(kDaySquareSize),
    );
  });

  testWidgets('a habit-outcome strip names each state and counts only the '
      'kept days', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        DayMarkStrip(
          marks: [
            DayMark(
              day: today.subtract(const Duration(days: 3)),
              state: DayMarkState.full,
            ),
            DayMark(
              day: today.subtract(const Duration(days: 2)),
              state: DayMarkState.skipped,
            ),
            DayMark(
              day: today.subtract(const Duration(days: 1)),
              state: DayMarkState.missed,
            ),
            DayMark(day: today, state: DayMarkState.none),
          ],
          onDaySelected: (_) {},
        ),
      ),
    );
    expect(find.bySemanticsLabel(cell(2, 'Skip')), findsOneWidget);
    expect(find.bySemanticsLabel(cell(1, 'Missed')), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('^1 successful day')),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('a read-only dated strip names each day on hover', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        DayMarkStrip(
          marks: goalDayMarks(
            states: const [DayMarkState.full, DayMarkState.skipped],
            lastDay: today,
          ),
        ),
      ),
    );
    final tooltips = tester
        .widgetList<DsTooltip>(find.byType(DsTooltip))
        .map((t) => '${t.title}: ${t.message}')
        .toList();
    expect(tooltips, [cell(1, 'done · target met'), cell(0, 'Skip')]);
  });

  testWidgets('a streak draws the flame and the exact count after the '
      'squares, and is announced as a streak', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Align(
          alignment: Alignment.topLeft,
          child: DayMarkStrip(
            marks: List.filled(5, const DayMark(state: DayMarkState.full)),
            streak: 12,
          ),
        ),
      ),
    );
    final tokens = tester.element(find.byType(DayMarkStrip)).designTokens;
    expect(find.byIcon(LottiIcons.streak), findsOneWidget);
    // Flame and count in the handover's medium-emphasis ink: a flame in
    // the kept hue read as one more kept day.
    expect(
      tester.widget<Icon>(find.byIcon(LottiIcons.streak)).color,
      tokens.colors.text.mediumEmphasis,
    );
    expect(find.text('12'), findsOneWidget);
    final count = tester.widget<Text>(find.text('12')).style;
    expect(count?.color, tokens.colors.text.mediumEmphasis);
    expect(
      count?.fontSize,
      tokens.typography.styles.body.bodySmall.fontSize,
      reason: 'the count is text, not fine print',
    );
    // Tail after the last square, in reading order.
    expect(
      tester.getTopLeft(find.byIcon(LottiIcons.streak)).dx,
      greaterThan(tester.getTopRight(find.byType(DayMarkCell).last).dx),
    );
    expect(
      tester.getTopLeft(find.text('12')).dx,
      greaterThan(tester.getTopRight(find.byIcon(LottiIcons.streak)).dx),
    );
    // step2 after the last column, which itself ends in half the pitch's
    // air — text-grade separation from the chain, not one more cell gap.
    final pitch = dayTrackMetrics(
      tester.element(find.byType(DayMarkStrip)),
    ).pitch;
    expect(
      tester.getTopLeft(find.byIcon(LottiIcons.streak)).dx -
          tester.getTopRight(find.byType(DayMarkCell).last).dx,
      tokens.spacing.step2 + (pitch - kDaySquareSize) / 2,
    );
    expect(
      tester.widget<Icon>(find.byIcon(LottiIcons.streak)).size,
      kDaySquareSize,
    );
    expect(find.bySemanticsLabel('12-day streak'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('successful day')), findsNothing);
    handle.dispose();
  });

  testWidgets('a zero streak draws no tail', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        DayMarkStrip(marks: goalDayMarks(states: week), streak: 0),
      ),
    );
    expect(find.byIcon(LottiIcons.streak), findsNothing);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('a fortnight fits a phone card without scrolling', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 320,
            child: DayMarkStrip(
              marks: goalDayMarks(
                states: List.filled(14, DayMarkState.full),
                lastDay: today,
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(LinkedDayTrackScroller), findsNothing);
    expect(tester.getSize(find.byType(DayTrack)).width, lessThanOrEqualTo(320));
    expect(find.byType(DayMarkCell), findsNWidgets(14));
  });

  testWidgets('a span wider than its measure pans, anchored on today', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 200,
            child: DayMarkStrip(
              marks: goalDayMarks(
                states: List.filled(60, DayMarkState.none),
                lastDay: today,
              ),
            ),
          ),
        ),
      ),
    );
    final scroller = tester.widget<SingleChildScrollView>(
      find.descendant(
        of: find.byType(LinkedDayTrackScroller),
        matching: find.byType(SingleChildScrollView),
      ),
    );
    expect(scroller.reverse, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty strip renders nothing', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const Align(
          alignment: Alignment.topLeft,
          child: DayMarkStrip(marks: []),
        ),
      ),
    );
    expect(find.byType(DayMarkCell), findsNothing);
    expect(tester.getSize(find.byType(DayMarkStrip)), Size.zero);
  });
}
