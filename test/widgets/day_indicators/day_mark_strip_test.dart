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

  testWidgets('compact strip reports the number of successful days once in '
      'semantics', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        DayMarkStrip(
          marks: goalDayMarks(
            states: const [
              DayMarkState.full,
              DayMarkState.none,
              DayMarkState.partial,
              DayMarkState.none,
              DayMarkState.none,
              DayMarkState.full,
              DayMarkState.none,
            ],
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        '3 successful days in the trailing seven-day window',
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('compact strip outlines the last cell as today when short', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        DayMarkStrip(
          marks: goalDayMarks(
            states: const [
              DayMarkState.none,
              DayMarkState.full,
              DayMarkState.none,
            ],
          ),
        ),
      ),
    );

    expect(find.byType(DsDashedBorder), findsOneWidget);
  });

  testWidgets('a read-only strip announces its verdicts and marks non-met '
      'days with a shape', (tester) async {
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
    final label = tester.getSemantics(find.byType(DayMarkStrip)).label;
    expect(label, contains('Met'));
    expect(label, contains('Missed'));

    // Each verdict keeps its OWN shape even on the list's 12px cells.
    // Collapsing the three non-met verdicts into one dot left Improving,
    // Mixed and Missed separable by hue alone, which is the single thing the
    // shapes exist to prevent.
    expect(
      find.byIcon(dayVerdictGlyph(DayVerdict.met)),
      findsOneWidget,
    );
    expect(
      find.byIcon(dayVerdictGlyph(DayVerdict.missed)),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('a tappable strip reports the day each cell stands for, '
      'counting back from the last', (tester) async {
    final handle = tester.ensureSemantics();
    final tapped = <DateTime>[];
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        DayMarkStrip(
          marks: goalDayMarks(
            states: const [
              DayMarkState.full,
              DayMarkState.none,
              DayMarkState.partial,
              DayMarkState.none,
              DayMarkState.none,
              DayMarkState.full,
              DayMarkState.none,
            ],
            lastDay: today,
          ),
          onDaySelected: tapped.add,
        ),
      ),
    );

    // The oldest cell is six days back and the last one is today. Tapping a
    // *past* day is the point: before this, the only way to reflect on a day
    // was the "Reflect on today" row, so a day could never be closed off
    // once it had passed.
    String cell(int daysBack, String outcome) =>
        '${DateFormat.MMMEd().format(today.subtract(Duration(days: daysBack)))}'
        ': $outcome';

    await tester.tap(find.bySemanticsLabel(cell(6, 'done · target met')));
    await tester.tap(find.bySemanticsLabel(cell(0, 'No entry')));

    expect(tapped, [today.subtract(const Duration(days: 6)), today]);

    // Colour and an inner dot are the only visual difference between these
    // cells, and neither reaches a screen reader. Each day names its own
    // state; the strip's summary only gives a count and cannot say which
    // days went well.
    expect(
      find.bySemanticsLabel(cell(4, 'done · target not met yet')),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('a recorded verdict outranks the measured state, and each '
      'verdict has its own colour', (tester) async {
    final handle = tester.ensureSemantics();
    final week = List.filled(7, DayMarkState.none);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        DayMarkStrip(
          marks: goalDayMarks(
            states: week,
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
    final cells = find.descendant(
      of: find.byType(DayMarkStrip),
      matching: find.byType(Container),
    );
    Color fillAt(int index) =>
        (tester.widget<Container>(cells.at(index)).decoration! as BoxDecoration)
            .color!;

    // Every measured day here is `none` — grey. The user's own verdict is what
    // decides the colour, because the measurement is evidence about a day and
    // the reflection is their ruling on it.
    expect(fillAt(0), dayMarkStateFill(tokens, DayMarkState.none));
    expect(
      fillAt(3),
      dayVerdictFill(tokens, DayVerdict.met),
    );
    expect(
      fillAt(4),
      dayVerdictFill(tokens, DayVerdict.improving),
    );
    expect(
      fillAt(5),
      dayVerdictFill(tokens, DayVerdict.mixed),
    );
    expect(
      fillAt(6),
      dayVerdictFill(tokens, DayVerdict.missed),
    );

    // The verdict is what a screen reader hears too, not just what the eye
    // sees — the colour is the only visual difference between these cells.
    expect(
      find.bySemanticsLabel(
        '${DateFormat.MMMEd().format(
          today.subtract(const Duration(days: 2)),
        )}: Improving',
      ),
      findsOneWidget,
    );

    // Colour alone is not enough: four fills that differ only by hue are four
    // fills a red-green deficiency cannot separate, and reading the week at a
    // glance is the strip's entire job. Each verdict wears a shape too.
    for (final rating in DayVerdict.values) {
      expect(
        find.byIcon(dayVerdictGlyph(rating)),
        findsOneWidget,
        reason: '${rating.name} has no shape of its own',
      );
      // Two inks per verdict, for two backgrounds. On its own saturated fill
      // the glyph takes the on-alert ink; on a plain card — the reflect row —
      // it takes its family's ink, because the on-alert ink is near-invisible
      // there by design.
      expect(
        dayVerdictSurfaceInk(tokens, rating),
        isNot(dayVerdictInk(tokens, rating)),
        reason: '${rating.name} uses one ink for both surfaces',
      );
    }
    expect(
      {
        for (final rating in DayVerdict.values) dayVerdictGlyph(rating),
      },
      hasLength(DayVerdict.values.length),
      reason: 'two verdicts share a glyph',
    );

    // All four are distinguishable, and none of them is the grey of a day
    // nobody looked at — "I decided this was missed" and "no data" are
    // different facts and the strip has to be able to say which.
    final verdicts = {fillAt(3), fillAt(4), fillAt(5), fillAt(6)};
    expect(verdicts, hasLength(4));
    expect(
      verdicts,
      isNot(contains(dayMarkStateFill(tokens, DayMarkState.none))),
    );
    handle.dispose();
  });

  testWidgets('a read-only strip hugs its cells while a tappable one spans '
      'the measure', (tester) async {
    const week = [
      DayMarkState.full,
      DayMarkState.none,
      DayMarkState.partial,
      DayMarkState.none,
      DayMarkState.none,
      DayMarkState.full,
      DayMarkState.none,
    ];
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        SizedBox(
          width: 400,
          child: Column(
            children: [
              DayMarkStrip(
                marks: goalDayMarks(states: week),
              ),
              DayMarkStrip(
                marks: goalDayMarks(states: week, lastDay: today),
                onDaySelected: (_) {},
              ),
            ],
          ),
        ),
      ),
    );

    final cells = find.descendant(
      of: find.byType(DayMarkStrip).at(1),
      matching: find.byType(InkWell),
    );
    var covered = 0.0;
    for (var index = 0; index < 7; index++) {
      covered += tester.getSize(cells.at(index)).width;
    }
    // Both strips sit on the page's shared seven-column track now, so the
    // week lines up with the habit squares and the metric bars rather than
    // being a third grid. Tapping does not change the pitch: the cells are
    // the same width either way, and the span is seven of them.
    final readOnlyCells = find.descendant(
      of: find.byType(DayMarkStrip).at(0),
      matching: find.byType(Padding),
    );
    expect(
      tester.getSize(cells.at(0)).width,
      moreOrLessEquals(covered / 7, epsilon: 1),
      reason: 'the tappable cells do not sit on an even pitch',
    );
    expect(readOnlyCells, findsWidgets);
  });

  testWidgets('a placeholder strip keeps the silhouette without borrowing the '
      'empty-week fill', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        DayMarkStrip(
          marks: goalDayMarks(
            states: const [
              DayMarkState.none,
              DayMarkState.none,
              DayMarkState.none,
            ],
          ),
          placeholder: true,
        ),
      ),
    );

    // Dashed outlines, never the filled grey a genuinely-empty week wears:
    // "no data yet" and "nothing happened" must not share an encoding.
    expect(find.byType(DsDashedBorder), findsNWidgets(3));
    final outlined = tester.getSize(
      find
          .descendant(
            of: find.byType(DsDashedBorder).first,
            matching: find.byType(SizedBox),
          )
          .first,
    );
    expect(outlined.width, ControlSizes.iconChipCompact);
    expect(outlined.height, ControlSizes.iconChipCompact);
  });

  testWidgets('the partial-day dot scales with the square it marks', (
    tester,
  ) async {
    // The square's size is derived from the width the track has to fit into,
    // so a squeezed strip is how a small cell is produced.
    Future<double> dotWidth({
      required double width,
      required int dayCount,
    }) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: DayMarkStrip(
                marks: goalDayMarks(
                  states: List.filled(dayCount, DayMarkState.partial),
                ),
              ),
            ),
          ),
        ),
      );
      // The dot is the innermost Container inside the cell.
      return tester
          .getSize(
            find
                .descendant(
                  of: find.byType(DayMarkStrip),
                  matching: find.byType(Container),
                )
                .last,
          )
          .width;
    }

    final compact = await dotWidth(width: 200, dayCount: 30);
    final large = await dotWidth(width: 760, dayCount: 8);
    // A dot fixed at the compact size vanishes inside the 28px square the
    // detail page uses, and the partial state is the one that has no colour
    // of its own to fall back on.
    expect(large, greaterThan(compact));
  });

  testWidgets('a habit-outcome strip draws the skip dash and missed cross, '
      'names each state, and counts only the kept days', (tester) async {
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
            DayMark(day: today, state: DayMarkState.none, isToday: true),
          ],
          onDaySelected: (_) {},
        ),
      ),
    );

    expect(find.byIcon(LottiIcons.remove), findsOneWidget);
    expect(find.byIcon(LottiIcons.close), findsOneWidget);
    String cell(int daysBack, String outcome) =>
        '${DateFormat.MMMEd().format(today.subtract(Duration(days: daysBack)))}'
        ': $outcome';
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
    final yesterday = DateFormat.MMMEd().format(
      today.subtract(const Duration(days: 1)),
    );
    expect(tooltips, [
      '$yesterday: done · target met',
      '${DateFormat.MMMEd().format(today)}: Skip',
    ]);
  });

  testWidgets('an explicit today flag places the ring, not the last slot', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        DayMarkStrip(
          marks: [
            DayMark(
              day: today.subtract(const Duration(days: 1)),
              state: DayMarkState.full,
              isToday: true,
            ),
            DayMark(day: today, state: DayMarkState.none),
          ],
        ),
      ),
    );
    final ringed = find.ancestor(
      of: find.byType(DayMarkCell).first,
      matching: find.byType(DsDashedBorder),
    );
    expect(find.byType(DsDashedBorder), findsOneWidget);
    expect(ringed, findsNothing, reason: 'the ring is inside the cell');
    expect(
      tester.widget<DayMarkCell>(find.byType(DayMarkCell).first).mark.isToday,
      isTrue,
    );
    expect(
      tester.widget<DayMarkCell>(find.byType(DayMarkCell).last).mark.isToday,
      isFalse,
    );
  });

  testWidgets('a span longer than a week fits its width and shrinks the '
      'cells rather than scrolling', (tester) async {
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
    expect(find.byType(DayTrack), findsOneWidget);
    expect(tester.getSize(find.byType(DayTrack)).width, lessThanOrEqualTo(320));
    expect(find.byType(DayMarkCell), findsNWidgets(14));
  });

  testWidgets('a span that cannot fit even at the narrowest pitch pans, '
      'anchored on today', (tester) async {
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
  });

  testWidgets('a dateless span longer than a week is measured with its gaps, '
      'so a fit never overflows the card', (tester) async {
    // 12 undated cells: on the Row branch each cell is padded and the cells
    // are gapped, so `pitch * count` underestimates the row; at this width
    // that underestimate used to declare a fit and overflow by ~11 gaps.
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            child: DayMarkStrip(
              marks: goalDayMarks(states: List.filled(12, DayMarkState.none)),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(DayTrack), findsNothing, reason: 'undated → Row');
    // The honest measure says it does not fit, so the row pans instead of
    // being handed back unwrapped to overflow the card.
    expect(find.byType(LinkedDayTrackScroller), findsOneWidget);
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
