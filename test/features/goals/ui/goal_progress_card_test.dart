import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_bar_line_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_line_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_multiline_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/utils.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/callouts/design_system_inline_callout.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu.dart';
import 'package:lotti/features/design_system/components/ds_dashed_border.dart';
import 'package:lotti/features/design_system/components/tooltips/ds_tooltip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_window.dart';
import 'package:lotti/features/goals/model/goal_assessment.dart';
import 'package:lotti/features/goals/model/goal_health_data_types.dart';
import 'package:lotti/features/goals/state/goal_progress_view.dart';
import 'package:lotti/features/goals/ui/goal_progress_card.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/widgets/day_indicators/day_mark.dart';
import 'package:lotti/widgets/day_indicators/day_mark_cell.dart';
import 'package:lotti/widgets/day_indicators/day_mark_strip.dart';
import 'package:lotti/widgets/day_indicators/day_mark_styles.dart';
import 'package:lotti/widgets/day_indicators/day_track.dart';
import 'package:lotti/widgets/misc/linked_scroll_group.dart';

import '../../../widget_test_utils.dart';

void main() {
  final today = DateTime.utc(2026, 8, 11);
  GoalProgressDay day(int offset, num value, {HabitCompletionType? type}) =>
      GoalProgressDay(
        day: today.subtract(Duration(days: offset)),
        value: value,
        habitCompletionType: type,
      );

  /// The `yyyy-MM-dd` fragment the day-cell keys are built from.
  String dayKey(int offset) =>
      today.subtract(Duration(days: offset)).toIso8601String().substring(0, 10);

  testWidgets('habit card renders the rolling-window hierarchy, per-habit '
      'distance and reliability without a percentage', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        GoalProgressCard(
          progress: GoalProgressView(
            today: today,
            habits: [
              GoalHabitProgressView(
                habitId: 'gym',
                name: 'Gym',
                targetCount: 3,
                days: [
                  day(6, 1),
                  day(5, 0),
                  day(4, 0),
                  day(3, 1),
                  day(2, 0),
                  day(1, 0),
                  day(0, 0),
                ],
                successfulWeeks: 4,
              ),
            ],
          ),
        ),
      ),
    );

    // No cadence line at all for the rolling week: the corner block already
    // states "N of M this window", so "3× per 7 days" was the same fact
    // twice on one card. The period line is left with the one thing nothing
    // else states — which dates the squares cover.
    expect(find.textContaining('slides at midnight'), findsNothing);
    expect(find.text('Aug 5 – Aug 11'), findsOneWidget);
    expect(find.text('This rolling week'), findsNothing);
    expect(find.text('Gym'), findsOneWidget);
    expect(
      find.text('1 successful day needed to recover'),
      findsOneWidget,
    );
    expect(find.text('4 / 6 weeks'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('an authored rolling window is named in the corner reading', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        GoalProgressCard(
          progress: GoalProgressView(
            today: today,
            habits: [
              GoalHabitProgressView(
                habitId: 'walk',
                name: 'Walk',
                targetCount: 4,
                window: const GoalWindow.rollingDays(count: 10),
                days: [
                  for (var offset = 9; offset >= 0; offset--) day(offset, 0),
                ],
                successfulWeeks: 0,
              ),
            ],
          ),
        ),
      ),
    );

    // The cadence line is gone entirely — the corner reading carries the
    // count, the target AND the concrete window.
    expect(find.text('4× · rolling 10 days'), findsNothing);
    expect(find.text('0 of 4 · rolling 10 days'), findsOneWidget);
  });

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('weekday labels load for ${locale.toLanguageTag()}', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          GoalProgressCard(
            progress: GoalProgressView(
              today: today,
              habits: [
                GoalHabitProgressView(
                  habitId: 'gym',
                  name: 'Gym',
                  targetCount: 1,
                  days: [
                    for (var offset = 6; offset >= 0; offset--) day(offset, 0),
                  ],
                  successfulWeeks: 0,
                ),
              ],
            ),
          ),
          locale: locale,
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Gym'), findsOneWidget);
    });
  }

  group('formatGoalAggregate', () {
    final number = NumberFormat.decimalPattern('en');

    test('a step average rounds to the hundred it can actually carry', () {
      // The seven-day mean arrives as 7684.428571…. Rendering "7,684.429" —
      // or even "7,684" — invites the reader to believe the trailing digits
      // mean something about a habit average. They do not.
      expect(formatGoalAggregate(number, 7684.428571), '7,700');
      expect(formatGoalAggregate(number, 12449), '12,400');
      expect(formatGoalAggregate(number, 10000), '10,000');
    });

    test('rounding never moves a value onto the wrong side of its target', () {
      // 9,950 against a 10,000 target would read "10,000 of 10,000" directly
      // above a "Needs attention" line. Where the coarse step would erase the
      // difference, the finer one is kept.
      expect(
        formatGoalAggregate(number, 9950, against: 10000),
        isNot(formatGoalAggregate(number, 10000, against: 9950)),
      );
      expect(formatGoalAggregate(number, 9950, against: 10000), '9,950');
      // Equal values still round together — there is no miss to preserve.
      expect(formatGoalAggregate(number, 10000, against: 10000), '10,000');
      // And a difference the coarse step already survives keeps the coarse
      // step: 7,700 vs 10,000 needs no extra digits.
      expect(
        formatGoalAggregate(number, 7684.428571, against: 10000),
        '7,700',
      );
      // Precision steps down until the two genuinely read differently — one
      // step was not enough: 9,999.6 against 10,000 still rounded to 10,000.
      expect(formatGoalAggregate(number, 9999.6, against: 10000), '9,999.6');
      // Below 100 the same rule keeps whatever decimal it takes.
      expect(formatGoalAggregate(number, 87.94, against: 88), '87.9');
      expect(formatGoalAggregate(number, 87.96, against: 88), '87.96');
      // A fixed ladder always has a last rung: [1, 0.1, 0.01] still rendered
      // "88 of 88" here, the exact contradiction the guard exists to stop.
      expect(formatGoalAggregate(number, 87.996, against: 88), '87.996');
    });

    test('blood pressure keeps whole numbers', () {
      expect(formatGoalAggregate(number, 127.3), '127');
      expect(formatGoalAggregate(number, 84.6), '84.6');
    });

    test('weight keeps the one decimal that means something', () {
      // 94.5 kg is a real distinction; 94.53 is not.
      expect(formatGoalAggregate(number, 94.53), '94.5');
      expect(formatGoalAggregate(number, 88), '88');
    });

    test('a target rounds by the same rule as the value it is compared to', () {
      // Rounded differently, a value could appear to miss a target it meets.
      expect(
        formatGoalAggregate(number, 10000),
        formatGoalAggregate(number, 10000.4),
      );
    });
  });

  testWidgets('the habit streak rides the window line above the days it '
      'summarises', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        GoalProgressCard(
          progress: GoalProgressView(
            today: today,
            habits: [
              GoalHabitProgressView(
                habitId: 'gym',
                name: 'Gym',
                targetCount: 3,
                days: [
                  for (var offset = 6; offset >= 0; offset--) day(offset, 0),
                ],
                successfulWeeks: 4,
              ),
            ],
          ),
        ),
      ),
    );

    // The six-week tail shares the window line with the date span: both
    // qualify the same window, and stacked under the squares the tail cost
    // the card a row of its own to say so.
    final streak = find.text('4 / 6 weeks');
    expect(streak, findsOneWidget);
    final period = find.text('Aug 5 – Aug 11');
    expect(period, findsOneWidget);
    final squares = find.byKey(
      ValueKey('goal-habit-day-visual-gym-${dayKey(0)}'),
    );
    expect(
      tester.getBottomLeft(streak).dy,
      lessThanOrEqualTo(tester.getTopLeft(squares).dy),
      reason: 'the tail must ride the window line, not take a row below',
    );
    expect(
      tester.getCenter(streak).dy,
      closeTo(tester.getCenter(period).dy, 1),
      reason: 'the tail and the date span share one caption row',
    );
    // ...pinned to the trailing rail, so the line reads span-then-record.
    expect(
      tester.getTopLeft(streak).dx,
      greaterThan(tester.getCenter(find.byType(GoalProgressCard)).dx),
    );
  });

  testWidgets('a count criterion improves by gaining a day, not by a bigger '
      'number', (tester) async {
    Future<void> pump(num yesterday, num today_) => tester.pumpWidget(
      makeTestableWidgetNoScroll(
        GoalProgressCard(
          progress: GoalProgressView(
            today: today,
            metric: GoalMetricProgressView(
              name: 'Sessions',
              target: 5,
              aggregation: GoalAggregation.count,
              days: [day(1, yesterday), day(0, today_)],
            ),
          ),
        ),
      ),
    );

    // Both days count: the second adds exactly one to the tally whatever its
    // magnitude, so a bigger number is not an improvement.
    await pump(1, 9);
    expect(
      find.text('Not there yet, but the last reading moved toward the target.'),
      findsNothing,
    );

    // And a zero-value day still counts for a plain metric — the evaluator
    // only requires a positive value for CATEGORY TIME — so 0 to 1 is not an
    // improvement in its tally either.
    await pump(0, 1);
    expect(
      find.text('Not there yet, but the last reading moved toward the target.'),
      findsNothing,
    );
  });

  testWidgets('a period-total target draws no per-day threshold line', (
    tester,
  ) async {
    Future<void> pump(GoalAggregation aggregation) => tester.pumpWidget(
      makeTestableWidgetNoScroll(
        GoalProgressCard(
          progress: GoalProgressView(
            today: today,
            metric: GoalMetricProgressView(
              name: 'Focus',
              target: 10,
              aggregation: aggregation,
              days: [day(1, 6), day(0, 6)],
            ),
          ),
        ),
      ),
    );

    int rules() => find
        .descendant(
          of: find.byType(GoalProgressCard),
          matching: find.byKey(const ValueKey('goal-metric-target-rule')),
        )
        .evaluate()
        .length;

    // A per-day target is comparable to a bar, so the line is drawn.
    await pump(GoalAggregation.dailySumThenAverage);
    expect(rules(), 1);

    // A `sum` target belongs to the WINDOW: two six-minute days already clear
    // a ten-minute total, yet a line at 10 would put both bars under it.
    await pump(GoalAggregation.sum);
    expect(rules(), 0);
  });

  testWidgets('the whole-goal week shares the habit squares’ column pitch', (
    tester,
  ) async {
    // The strip and the habit squares now live on two widgets (the page
    // stacks the This-week hero above the evidence sections), but they are
    // still the same days one card apart — the shared pitch remains the
    // contract. Fourteen days, the detail page's smallest span: that is the
    // configuration the page actually renders, and the one where both
    // tracks derive the same width-filling pitch from the same card width.
    final progress = GoalProgressView(
      today: today,
      compositeRule: GoalCompositeRuleKind.all,
      compactWindowDays: 14,
      habits: [
        GoalHabitProgressView(
          habitId: 'gym',
          name: 'Gym',
          targetCount: 3,
          days: [
            for (var offset = 13; offset >= 0; offset--) day(offset, 0),
          ],
          successfulWeeks: 0,
        ),
      ],
    );
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Column(
          children: [
            GoalThisWeekCard(progress: progress, onReflectDay: (_) {}),
            GoalProgressCard(progress: progress),
          ],
        ),
      ),
    );

    // One week, one grid. The whole-goal strip and the habit squares are the
    // same seven days drawn one card apart; on separate pitches the same
    // Wednesday landed in two different columns and a reader could not follow
    // a day down the page.
    final stripCells = find.descendant(
      of: find.byType(DayMarkStrip),
      matching: find.byType(InkWell),
    );
    final firstStrip = tester.getRect(stripCells.at(0));
    final secondStrip = tester.getRect(stripCells.at(1));
    final habitFirst = tester.getRect(
      find.byKey(const ValueKey('goal-habit-day-visual-gym-2026-08-05')),
    );
    final habitSecond = tester.getRect(
      find.byKey(const ValueKey('goal-habit-day-visual-gym-2026-08-06')),
    );

    expect(
      secondStrip.left - firstStrip.left,
      moreOrLessEquals(habitSecond.left - habitFirst.left, epsilon: 0.5),
      reason: 'the two seven-day rows are on different pitches',
    );
  });

  testWidgets('a calendar-window habit track ends on today, on the same '
      'geometry as the Goal-days strip above it', (tester) async {
    // Tuesday: the habit's calendar week runs on to Sunday, five days that
    // have not happened yet. Rendered, they lengthened the track past the
    // whole-goal strip — a period line two days into the future, and squares
    // visibly smaller than the strip's, because the column pitch is the
    // card's width divided by the day count.
    final progress = buildGoalProgressView(
      criteria: const GoalCriterion.habit(
        criterionId: 'walk',
        habitId: 'walk',
        window: GoalWindow.calendarWeek(),
        targetCount: 3,
      ),
      signals: const GoalSignalWindow(),
      reference: today,
      habitNames: const {'walk': 'Evening walk'},
      historyDays: 14,
    );
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Column(
          children: [
            GoalThisWeekCard(progress: progress, onReflectDay: (_) {}),
            GoalProgressCard(progress: progress),
          ],
        ),
      ),
    );

    // The last square is today's, and tomorrow has none at all.
    expect(
      find.byKey(ValueKey('goal-habit-day-visual-walk-${dayKey(0)}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('goal-habit-day-visual-walk-${dayKey(-1)}')),
      findsNothing,
    );

    // One period line, stated twice: the strip and the squares cover exactly
    // the same dates, so they must print the same range.
    expect(find.text('Jul 29 – Aug 11'), findsNWidgets(2));

    // Identical squares — same edge, and the same corner radius from the one
    // shared constant.
    final stripCell = tester
        .widgetList<Container>(
          find.descendant(
            of: find.byType(DayMarkStrip),
            matching: find.byType(Container),
          ),
        )
        .firstWhere((container) => container.decoration is BoxDecoration);
    // Today itself is the dashed open square on both tracks; yesterday is a
    // filled one, so it is the one to compare decorations on.
    final habitCell = tester.widget<Container>(
      find.byKey(ValueKey('goal-habit-day-visual-walk-${dayKey(1)}')),
    );
    final stripRect = tester.getRect(
      find.byWidget(stripCell),
    );
    final habitRect = tester.getRect(
      find.byKey(ValueKey('goal-habit-day-visual-walk-${dayKey(1)}')),
    );
    expect(stripRect.size, habitRect.size);
    expect(
      find.descendant(
        of: find.byKey(ValueKey('goal-habit-day-visual-walk-${dayKey(0)}')),
        matching: find.byType(DsDashedBorder),
      ),
      findsOneWidget,
      reason: 'today, still open, is the dashed square',
    );
    expect(
      (habitCell.decoration! as BoxDecoration).borderRadius,
      (stripCell.decoration! as BoxDecoration).borderRadius,
    );
  });

  testWidgets('the reflect action rides the Goal-days header, and names '
      'the verdict once recorded', (tester) async {
    final tapped = <DateTime>[];
    Future<void> pump({DayVerdict? recorded}) => tester.pumpWidget(
      makeTestableWidgetNoScroll(
        GoalThisWeekCard(
          progress: GoalProgressView(
            today: today,
            compositeRule: GoalCompositeRuleKind.all,
            habits: [
              GoalHabitProgressView(
                habitId: 'gym',
                name: 'Gym',
                targetCount: 3,
                days: [
                  for (var offset = 6; offset >= 0; offset--) day(offset, 0),
                ],
                successfulWeeks: 0,
              ),
            ],
          ),
          onReflectDay: tapped.add,
          ratingsByDay: recorded == null ? const {} : {today: recorded},
        ),
      ),
    );

    await pump();
    // The day's action is the card header's trailing button, on the title's
    // own line: as a full-width row under the strip it cost a touch target's
    // height plus two gaps to say what a corner button says for free.
    final strip = tester.getRect(find.byType(DayMarkStrip));
    final reflect = tester.getRect(find.text('Reflect on today'));
    final title = tester.getRect(
      find.textContaining(RegExp('Goal days|This week')),
    );
    expect(
      reflect.bottom,
      lessThanOrEqualTo(strip.top),
      reason: 'the reflect action must sit above the strip, in the header',
    );
    expect(
      reflect.center.dy,
      closeTo(title.center.dy, 1),
      reason: 'the reflect action shares the title row',
    );
    expect(
      reflect.left,
      greaterThan(title.right),
      reason: 'the reflect action is pinned to the trailing edge',
    );

    await tester.tap(find.text('Reflect on today'));
    expect(tapped, [today]);

    // Once the day is judged the button states the verdict instead of
    // inviting an action the user already took.
    await pump(recorded: DayVerdict.improving);
    expect(find.text('Reflect on today'), findsNothing);
    expect(find.text('Improving'), findsOneWidget);
  });

  testWidgets('no square draws a ring, glyph or letter: today, the window '
      'start and the outcomes are said, not drawn', (tester) async {
    final habit = GoalHabitProgressView(
      habitId: 'gym',
      name: 'Gym',
      // At its rate with the one success on the window's first day, so that
      // success ages out tonight.
      targetCount: 1,
      days: [
        day(6, 1, type: HabitCompletionType.success),
        day(5, 0, type: HabitCompletionType.fail),
        day(4, 0, type: HabitCompletionType.skip),
        for (var offset = 3; offset >= 0; offset--) day(offset, 0),
      ],
      successfulWeeks: 0,
    );
    expect(habit.oldestSuccessAgesOutTonight, isTrue);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        SingleChildScrollView(
          child: Column(
            children: [
              GoalThisWeekCard(
                progress: GoalProgressView(
                  today: today,
                  compositeRule: GoalCompositeRuleKind.all,
                  habits: [habit],
                ),
                onReflectDay: (_) {},
              ),
              GoalProgressCard(
                progress: GoalProgressView(today: today, habits: [habit]),
              ),
            ],
          ),
        ),
      ),
    );
    // The only outline anywhere is today's open square, once per track.
    expect(find.byType(DsDashedBorder), findsNWidgets(2));
    // The tappable whole-goal strip names each day above its square and
    // draws nothing else; the read-only habit track draws the bare squares.
    expect(
      find.descendant(
        of: find.byType(DayMarkStrip),
        matching: find.byType(Icon),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(DayMarkStrip),
        matching: find.byType(Text),
      ),
      findsNWidgets(7),
    );
    final habitTrack = find.descendant(
      of: find.byType(GoalProgressCard),
      matching: find.byType(DayTrack),
    );
    expect(
      find.descendant(of: habitTrack, matching: find.byType(Icon)),
      findsNothing,
    );
    expect(
      find.descendant(of: habitTrack, matching: find.byType(Text)),
      findsNothing,
    );
    final tokens = tester.element(find.byType(GoalProgressCard)).designTokens;
    final visual = tester.widget<Container>(
      find.byKey(ValueKey('goal-habit-day-visual-gym-${dayKey(6)}')),
    );
    final decoration = visual.decoration! as BoxDecoration;
    expect(decoration.border, isNull);
    expect(decoration.borderRadius, BorderRadius.circular(tokens.radii.xs));
    expect(
      tester.getSize(find.byWidget(visual)),
      const Size.square(kDaySquareSize),
    );
    // The ages-out fact rides the tooltip and the semantics instead.
    final tooltip = tester.widget<DsTooltip>(
      find.ancestor(
        of: find.byWidget(visual),
        matching: find.byType(DsTooltip),
      ),
    );
    expect(tooltip.message, 'Success · ages out tonight');
  });

  testWidgets('a card closing on a check-off callout keeps its full foot, '
      'legend or not', (tester) async {
    // The shallow foot pays for the centering slack an interactive day track
    // leaves UNDER its squares. A callout after the track strands that slack
    // above itself, so the callout — a bordered surface — would sit crowded
    // against the card edge.
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        SingleChildScrollView(
          child: GoalProgressCard(
            progress: GoalProgressView(
              today: today,
              habits: [
                for (final name in ['Gym', 'Read'])
                  GoalHabitProgressView(
                    habitId: name,
                    name: name,
                    targetCount: 3,
                    days: [
                      for (var offset = 6; offset >= 0; offset--)
                        day(offset, 0),
                    ],
                    successfulWeeks: 0,
                    suggestedFromDimensionName: name == 'Read'
                        ? 'Weight'
                        : null,
                  ),
              ],
            ),
            onHabitOutcomeSelected:
                ({required day, required habitId, required outcome}) async =>
                    true,
          ),
        ),
      ),
    );

    final tokens = tester.element(find.byType(GoalProgressCard)).designTokens;
    expect(
      find.byKey(const ValueKey('goal-habit-checkoff-callout-Read')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<DesignSystemSectionCard>(
            find.ancestor(
              of: find.text('Read'),
              matching: find.byType(DesignSystemSectionCard),
            ),
          )
          .padding!
          .bottom,
      tokens.spacing.step5,
      reason: 'the callout closes this card, so it keeps the full foot',
    );
  });

  testWidgets('a goal with no composite rule still gets a reflectable week', (
    tester,
  ) async {
    final progress = GoalProgressView(
      today: today,
      habits: [
        GoalHabitProgressView(
          habitId: 'gym',
          name: 'Gym',
          targetCount: 3,
          days: [
            for (var offset = 6; offset >= 0; offset--) day(offset, 0),
          ],
          successfulWeeks: 0,
        ),
      ],
    );

    // Gating the whole-goal card on a composite rule left a single-habit goal
    // unable to reflect on a past day at all, and showing none of the verdict
    // colours — the feature is about goal days, and this goal has those too.
    // The page applies the same gate through [GoalThisWeekCard.shouldShow].
    expect(GoalThisWeekCard.shouldShow(progress, canReflect: true), isTrue);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        GoalThisWeekCard(progress: progress, onReflectDay: (_) {}),
      ),
    );
    expect(find.byType(DayMarkStrip), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(DayMarkStrip),
        matching: find.byType(InkWell),
      ),
      findsNWidgets(7),
    );
    // The composite tally says nothing about a goal with one dimension.
    expect(find.textContaining('dimensions'), findsNothing);

    // Read-only, the card would only put a second, near-identical week above
    // the one the habit row already draws — the page's gate keeps it out.
    expect(GoalThisWeekCard.shouldShow(progress, canReflect: false), isFalse);
  });

  testWidgets('tappable day cells clear the touch floor and match the habit '
      'day squares, while a read-only strip stays compact', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        GoalThisWeekCard(
          progress: GoalProgressView(
            today: today,
            compositeRule: GoalCompositeRuleKind.all,
            habits: [
              GoalHabitProgressView(
                habitId: 'gym',
                name: 'Gym',
                targetCount: 3,
                days: [
                  for (var offset = 6; offset >= 0; offset--) day(offset, 0),
                ],
                successfulWeeks: 0,
              ),
            ],
          ),
          onReflectDay: (_) {},
        ),
      ),
    );

    final cells = find.descendant(
      of: find.byType(DayMarkStrip),
      matching: find.byType(InkWell),
    );
    expect(cells, findsNWidgets(7));
    for (var index = 0; index < 7; index++) {
      expect(
        tester.getSize(cells.at(index)).height,
        greaterThanOrEqualTo(TapTargets.minimum),
        reason: 'cell $index is under the touch floor',
      );
    }
    // The targets tile the strip rather than sitting as islands in it: every
    // pixel that would have gone to a declared gap goes to a target instead.
    var covered = 0.0;
    for (var index = 0; index < 7; index++) {
      covered += tester.getSize(cells.at(index)).width;
    }
    final span =
        tester.getRect(cells.at(6)).right - tester.getRect(cells.at(0)).left;
    // Better than 95% of the span: the small residual is the ink slot inside
    // each cell, not a declared gap between them.
    expect(
      covered,
      greaterThan(span * 0.95),
      reason: 'dead space sits between the day targets',
    );

    // The square itself is the one handover square, the same on the
    // whole-goal strip and on the habit rows below it.
    final square = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(DayMarkStrip),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(square.constraints!.maxWidth, kDaySquareSize);
  });

  testWidgets('metric card renders seven bars in the same rolling frame', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        GoalProgressCard(
          progress: GoalProgressView(
            today: today,
            metric: GoalMetricProgressView(
              name: 'Daily steps',
              target: 8000,
              days: [
                for (var index = 0; index < 7; index++)
                  day(6 - index, index.isEven ? 9000 : 5000),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Daily steps'), findsOneWidget);
    expect(find.byType(FractionallySizedBox), findsNWidgets(7));
    expect(find.text('Done · target met'), findsNothing);
    expect(find.text('Done · target not met yet'), findsNothing);
    expect(find.text('Ages out tonight'), findsNothing);
    expect(find.text('Today'), findsNothing);
  });

  testWidgets('a raised text scale gives the metric bars full weekday '
      'captions on a pitch widened to hold them', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.01)),
          child: SingleChildScrollView(
            child: GoalProgressCard(
              progress: GoalProgressView(
                today: today,
                metric: GoalMetricProgressView(
                  name: 'Daily steps',
                  target: 8000,
                  days: [
                    for (var index = 0; index < 7; index++)
                      day(6 - index, 9000),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // Wide enough for "Tue", so the one-letter fallback is not used.
    expect(find.text('Tue'), findsOneWidget);
    expect(find.text('T'), findsNothing);
  });

  testWidgets('a today recorded as open, not merely empty, is still the '
      'dashed open square', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        GoalProgressCard(
          progress: GoalProgressView(
            today: today,
            habits: [
              GoalHabitProgressView(
                habitId: 'walk',
                name: 'Walk',
                targetCount: 3,
                days: [
                  for (var offset = 6; offset >= 1; offset--) day(offset, 0),
                  day(0, 0, type: HabitCompletionType.open),
                ],
                successfulWeeks: 0,
              ),
            ],
          ),
        ),
      ),
    );
    expect(
      find.descendant(
        of: find.byKey(ValueKey('goal-habit-day-visual-walk-${dayKey(0)}')),
        matching: find.byType(DsDashedBorder),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a point-sample health header quotes the latest reading, not '
      'the period average', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        SingleChildScrollView(
          child: GoalProgressCard(
            progress: GoalProgressView(
              today: today,
              metrics: [
                GoalMetricProgressView(
                  criterionId: 'weight',
                  sourceId: GoalHealthDataTypes.weight,
                  name: 'Weight',
                  target: 88,
                  direction: GoalDirection.atMost,
                  unitName: 'kg',
                  days: [day(2, 92), day(1, 96), day(0, 95)],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Latest observation (95) — the three-day average would render as
    // "94.333 kg". The target is NOT repeated in the corner: a card that
    // plots a seven-day average draws "Goal ≤ 88" as a keyed legend entry.
    expect(find.text('95 kg'), findsOneWidget);
    expect(find.textContaining('of 88'), findsNothing);
  });

  testWidgets('a steps card quotes TODAY over its trailing mean, never the '
      'mean twice', (tester) async {
    // Regression: `_metricDisplayValue` falls through to the evaluator's
    // actual for anything outside the point-sample set, and for an "average
    // steps per day" criterion that actual IS the trailing mean — so the
    // corner printed the average as the current value and the card showed
    // one number twice (10,100 over 10,100).
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        SingleChildScrollView(
          child: GoalProgressCard(
            progress: GoalProgressView(
              today: today,
              metric: GoalMetricProgressView(
                criterionId: 'steps',
                sourceId: GoalHealthDataTypes.steps,
                name: 'Steps',
                target: 10000,
                unitName: '',
                days: [
                  for (var offset = 9; offset >= 1; offset--) day(offset, 6000),
                  day(0, 12000),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Today stands alone as the headline figure...
    expect(find.text('12,000'), findsOneWidget);
    // ...and the mean is a DIFFERENT number, marked as a mean.
    final average = find.textContaining('Ø');
    expect(average, findsOneWidget);
    final averageText = tester.widget<Text>(average).data!;
    expect(averageText, isNot(contains('12,000')));
    expect(averageText, startsWith('Ø'));
    // The old spelled-out label is gone from the corner; the legend still
    // names the series in words.
    expect(
      find.descendant(
        of: find.byType(DashboardChartLegend),
        matching: find.text('7-day average'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the trailing-average legend wears the series colour, so the '
      "corner's Ø resolves to a line on the chart", (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        SingleChildScrollView(
          child: GoalProgressCard(
            progress: GoalProgressView(
              today: today,
              metric: GoalMetricProgressView(
                criterionId: 'steps',
                sourceId: GoalHealthDataTypes.steps,
                name: 'Steps',
                target: 10000,
                unitName: '',
                days: [
                  for (var offset = 9; offset >= 0; offset--)
                    day(offset, 6000 + offset * 100),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final tokens = tester.element(find.byType(GoalProgressCard)).designTokens;
    final entry = tester
        .widget<DashboardChartLegend>(find.byType(DashboardChartLegend))
        .entries
        .firstWhere((e) => e.label == '7-day average');
    expect(entry.labelWearsSeriesColor, isTrue);
    expect(entry.color, tokens.colors.alert.info.defaultColor);
    // The corner's Ø is set in that same hue — colour is the only thing
    // tying the symbol to the mark it stands for.
    expect(
      tester.widget<Text>(find.textContaining('Ø')).style?.color,
      entry.color,
    );
  });

  testWidgets('the blood-pressure header quotes the latest paired reading', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        SingleChildScrollView(
          child: GoalProgressCard(
            progress: GoalProgressView(
              today: today,
              metrics: [
                GoalMetricProgressView(
                  criterionId: 'systolic',
                  sourceId: GoalHealthDataTypes.bloodPressureSystolic,
                  name: 'Systolic blood pressure',
                  target: 125,
                  direction: GoalDirection.atMost,
                  unitName: 'mmHg',
                  days: [day(1, 131), day(0, 127)],
                ),
                GoalMetricProgressView(
                  criterionId: 'diastolic',
                  sourceId: GoalHealthDataTypes.bloodPressureDiastolic,
                  name: 'Diastolic blood pressure',
                  target: 85,
                  direction: GoalDirection.atMost,
                  unitName: 'mmHg',
                  days: [day(1, 91), day(0, 89)],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // The latest measurements (127 / 89), not the averages (129 / 90).
    expect(find.text('127 / 89 mmHg'), findsOneWidget);
  });

  group('latest-today health status', () {
    testWidgets(
      'blood pressure is positive when today is on target despite the average',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            GoalProgressCard(
              progress: GoalProgressView(
                today: today,
                metrics: [
                  GoalMetricProgressView(
                    criterionId: 'systolic',
                    sourceId: GoalHealthDataTypes.bloodPressureSystolic,
                    name: 'Systolic blood pressure',
                    target: 125,
                    direction: GoalDirection.atMost,
                    unitName: 'mmHg',
                    days: [day(1, 129), day(0, 125)],
                  ),
                  GoalMetricProgressView(
                    criterionId: 'diastolic',
                    sourceId: GoalHealthDataTypes.bloodPressureDiastolic,
                    name: 'Diastolic blood pressure',
                    target: 85,
                    direction: GoalDirection.atMost,
                    unitName: 'mmHg',
                    days: [day(1, 94), day(0, 84)],
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.text('125 / 84 mmHg'), findsOneWidget);
        expect(find.text('On target today'), findsOneWidget);
        expect(find.text('Needs attention'), findsNothing);
        // No summary sentence under the chart: the corner's status caption
        // already states the verdict, and the sentence restated it.
        expect(
          find.textContaining("Today's latest reading is on target"),
          findsNothing,
        );
      },
    );

    testWidgets(
      'weight is positive when today is on target despite the average',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            GoalProgressCard(
              progress: GoalProgressView(
                today: today,
                metric: GoalMetricProgressView(
                  criterionId: 'weight',
                  sourceId: GoalHealthDataTypes.weight,
                  name: 'Weight',
                  target: 88,
                  direction: GoalDirection.atMost,
                  unitName: 'kg',
                  days: [day(2, 90), day(1, 89), day(0, 88)],
                ),
              ),
            ),
          ),
        );

        expect(find.text('88 kg'), findsOneWidget);
        expect(find.text('On target today'), findsOneWidget);
        expect(find.text('Needs attention'), findsNothing);
      },
    );

    testWidgets(
      'an over-target average still needs attention before today is measured',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            GoalProgressCard(
              progress: GoalProgressView(
                today: today,
                metric: GoalMetricProgressView(
                  criterionId: 'weight',
                  sourceId: GoalHealthDataTypes.weight,
                  name: 'Weight',
                  target: 88,
                  direction: GoalDirection.atMost,
                  unitName: 'kg',
                  projectedOnTrack: true,
                  days: [
                    day(2, 90),
                    day(1, 89),
                    GoalProgressDay(
                      day: today,
                      value: 0,
                      isObserved: false,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        expect(find.text('89 kg'), findsOneWidget);
        expect(find.text('Needs attention'), findsOneWidget);
        expect(find.text('On track'), findsNothing);
      },
    );
  });

  testWidgets(
    'paired blood-pressure dimensions share one dual-line chart and targets',
    (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          GoalProgressCard(
            progress: GoalProgressView(
              today: today,
              metrics: [
                GoalMetricProgressView(
                  criterionId: 'systolic',
                  sourceId: GoalHealthDataTypes.bloodPressureSystolic,
                  name: 'Systolic blood pressure',
                  target: 125,
                  direction: GoalDirection.atMost,
                  aggregation: GoalAggregation.max,
                  unitName: 'mmHg',
                  days: [day(1, 122), day(0, 129)],
                ),
                GoalMetricProgressView(
                  criterionId: 'diastolic',
                  sourceId: GoalHealthDataTypes.bloodPressureDiastolic,
                  name: 'Diastolic blood pressure',
                  target: 85,
                  direction: GoalDirection.atMost,
                  aggregation: GoalAggregation.max,
                  unitName: 'mmHg',
                  days: [day(1, 81), day(0, 94)],
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(DesignSystemSectionCard), findsOneWidget);
      expect(find.text('Blood Pressure'), findsOneWidget);
      expect(find.text('129 / 94 mmHg'), findsOneWidget);
      expect(find.byType(LineChart), findsOneWidget);
      final chart = tester.widget<LineChart>(find.byType(LineChart));
      expect(chart.data.lineBarsData, hasLength(2));
      expect(chart.data.lineBarsData[0].spots.map((spot) => spot.y), [
        122,
        129,
      ]);
      expect(chart.data.lineBarsData[1].spots.map((spot) => spot.y), [81, 94]);
      expect(
        chart.data.extraLinesData.horizontalLines.map((line) => line.y),
        [125, 85],
      );
      // TWO legend entries for two lines. Each carries its own threshold as
      // a quiet annotation; a second, identically coloured entry per series
      // named no mark on the chart at all.
      expect(find.text('Systolic'), findsOneWidget);
      expect(find.text('Diastolic'), findsOneWidget);
      expect(find.text('Goal ≤ 125'), findsOneWidget);
      expect(find.text('Goal ≤ 85'), findsOneWidget);
      expect(find.text('Systolic · Goal ≤ 125'), findsNothing);
      expect(find.text('Diastolic · Goal ≤ 85'), findsNothing);
      expect(
        tester
            .widget<TimeSeriesMultiLineChart>(
              find.byType(TimeSeriesMultiLineChart),
            )
            .dateOnly,
        isTrue,
      );
    },
  );

  testWidgets(
    'blood-pressure dimensions with different periods stay separate',
    (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          SingleChildScrollView(
            child: GoalProgressCard(
              progress: GoalProgressView(
                today: today,
                metrics: [
                  GoalMetricProgressView(
                    sourceId: GoalHealthDataTypes.bloodPressureSystolic,
                    name: 'Systolic blood pressure',
                    target: 125,
                    direction: GoalDirection.atMost,
                    aggregation: GoalAggregation.max,
                    unitName: 'mmHg',
                    days: [day(1, 122), day(0, 124)],
                  ),
                  GoalMetricProgressView(
                    sourceId: GoalHealthDataTypes.bloodPressureDiastolic,
                    name: 'Diastolic blood pressure',
                    target: 85,
                    direction: GoalDirection.atMost,
                    aggregation: GoalAggregation.max,
                    window: const GoalWindow.rollingDays(count: 10),
                    unitName: 'mmHg',
                    days: [day(2, 82), day(1, 81), day(0, 83)],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Blood Pressure'), findsNothing);
      expect(find.text('Systolic blood pressure'), findsOneWidget);
      expect(find.text('Diastolic blood pressure'), findsOneWidget);
      expect(find.byType(DesignSystemSectionCard), findsNWidgets(2));
      expect(find.byType(LineChart), findsNWidgets(2));
    },
  );

  testWidgets(
    'partial blood-pressure observations stay in separate visible charts',
    (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          SingleChildScrollView(
            child: GoalProgressCard(
              progress: GoalProgressView(
                today: today,
                metrics: [
                  GoalMetricProgressView(
                    sourceId: GoalHealthDataTypes.bloodPressureSystolic,
                    name: 'Systolic blood pressure',
                    target: 125,
                    direction: GoalDirection.atMost,
                    aggregation: GoalAggregation.max,
                    unitName: 'mmHg',
                    days: [day(0, 124)],
                  ),
                  GoalMetricProgressView(
                    sourceId: GoalHealthDataTypes.bloodPressureDiastolic,
                    name: 'Diastolic blood pressure',
                    target: 85,
                    direction: GoalDirection.atMost,
                    aggregation: GoalAggregation.max,
                    unitName: 'mmHg',
                    days: [
                      GoalProgressDay(
                        day: today,
                        value: 0,
                        isObserved: false,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Blood Pressure'), findsNothing);
      expect(find.text('Systolic blood pressure'), findsOneWidget);
      expect(find.text('Diastolic blood pressure'), findsOneWidget);
      // The observed half charts its single sample; the unobserved half says
      // so in words instead of drawing an empty frame — a full-height blank
      // plot reads as a chart that failed, not as a goal with no readings.
      final charts = tester.widgetList<LineChart>(find.byType(LineChart));
      expect(charts, hasLength(1));
      expect(charts.single.data.lineBarsData.single.spots, hasLength(1));
      expect(charts.single.data.lineBarsData.single.dotData.show, isTrue);
      expect(
        find.text('There is not enough data to judge this dimension yet.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('paired blood pressure reports when there is no observed data', (
    tester,
  ) async {
    GoalMetricProgressView metric(String sourceId, String name, num target) =>
        GoalMetricProgressView(
          sourceId: sourceId,
          name: name,
          target: target,
          direction: GoalDirection.atMost,
          aggregation: GoalAggregation.max,
          unitName: 'mmHg',
          days: [
            GoalProgressDay(day: today, value: 0, isObserved: false),
          ],
        );

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        GoalProgressCard(
          progress: GoalProgressView(
            today: today,
            metrics: [
              metric(
                GoalHealthDataTypes.bloodPressureSystolic,
                'Systolic blood pressure',
                125,
              ),
              metric(
                GoalHealthDataTypes.bloodPressureDiastolic,
                'Diastolic blood pressure',
                85,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('—'), findsOneWidget);
    expect(
      find.text('There is not enough data to judge this dimension yet.'),
      findsOneWidget,
    );
    // No readings, no plot: two empty lines in a full-height frame said
    // nothing the note above does not, and looked like a broken chart.
    expect(find.byType(LineChart), findsNothing);
    expect(find.text('Systolic'), findsNothing);
  });

  testWidgets(
    'paired singleton blood pressure stays visible and reports on track',
    (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          GoalProgressCard(
            progress: GoalProgressView(
              today: today,
              metrics: [
                GoalMetricProgressView(
                  sourceId: GoalHealthDataTypes.bloodPressureSystolic,
                  name: 'Systolic blood pressure',
                  target: 125,
                  direction: GoalDirection.atMost,
                  aggregation: GoalAggregation.max,
                  unitName: 'mmHg',
                  days: [day(0, 122)],
                ),
                GoalMetricProgressView(
                  sourceId: GoalHealthDataTypes.bloodPressureDiastolic,
                  name: 'Diastolic blood pressure',
                  target: 85,
                  direction: GoalDirection.atMost,
                  aggregation: GoalAggregation.max,
                  unitName: 'mmHg',
                  days: [day(0, 81)],
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('122 / 81 mmHg'), findsOneWidget);
      expect(find.text('On target today'), findsOneWidget);
      expect(find.text('Goal ≤ 125'), findsOneWidget);
      expect(find.text('Goal ≤ 85'), findsOneWidget);
      // The verdict lives in the corner's status caption; the sentence that
      // restated it under the chart is gone.
      expect(
        find.textContaining("Today's latest reading is on target"),
        findsNothing,
      );
      final chart = tester.widget<LineChart>(find.byType(LineChart));
      expect(
        chart.data.lineBarsData.map((line) => line.dotData.show),
        everyElement(isTrue),
      );
    },
  );

  testWidgets('weight plots actual samples and trailing seven-day averages', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        GoalProgressCard(
          progress: GoalProgressView(
            today: today,
            metric: GoalMetricProgressView(
              criterionId: 'weight',
              sourceId: GoalHealthDataTypes.weight,
              name: 'Weight',
              target: 88,
              direction: GoalDirection.atMost,
              unitName: 'kg',
              days: [
                day(7, 100),
                day(6, 98),
                GoalProgressDay(
                  day: today.subtract(const Duration(days: 5)),
                  value: 0,
                  isObserved: false,
                ),
                day(4, 96),
                day(3, 94),
                day(2, 92),
                day(1, 90),
                day(0, 88),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(LineChart), findsOneWidget);
    expect(find.byType(FractionallySizedBox), findsNothing);
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData, hasLength(2));
    expect(chart.data.lineBarsData.first.belowBarData.show, isTrue);
    expect(chart.data.lineBarsData.last.dashArray, isNotEmpty);
    expect(chart.data.lineBarsData.first.spots.map((spot) => spot.y), [
      100,
      98,
      96,
      94,
      92,
      90,
      88,
    ]);
    expect(chart.data.lineBarsData.last.spots.map((spot) => spot.y), [95, 93]);
    expect(
      tester
          .widget<TimeSeriesMultiLineChart>(
            find.byType(TimeSeriesMultiLineChart),
          )
          .dateOnly,
      isTrue,
    );
    expect(find.text('Weight'), findsNWidgets(2));
    expect(find.text('7-day average'), findsOneWidget);
    expect(find.text('Goal'), findsOneWidget);
    expect(find.text('≤ 88'), findsOneWidget);
    // One legend entry per line drawn, and nothing else: the above/below
    // sentence was a reading of the data wearing a swatch that matched no
    // mark on the chart.
    expect(find.textContaining('7-day average · '), findsNothing);
  });

  testWidgets(
    'rolling average stops at today when the window has future days',
    (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          GoalProgressCard(
            progress: GoalProgressView(
              today: today,
              metric: GoalMetricProgressView(
                sourceId: GoalHealthDataTypes.weight,
                name: 'Weight',
                target: 88,
                direction: GoalDirection.atMost,
                unitName: 'kg',
                days: [
                  for (var offset = 6; offset >= 0; offset--) day(offset, 94),
                  for (var offset = 1; offset <= 3; offset++)
                    GoalProgressDay(
                      day: today.add(Duration(days: offset)),
                      value: 0,
                      isObserved: false,
                    ),
                ],
              ),
            ),
          ),
        ),
      );

      final chart = tester.widget<LineChart>(find.byType(LineChart));
      expect(chart.data.lineBarsData.last.spots, hasLength(1));
      expect(
        chart.data.lineBarsData.last.spots.single.x,
        today.millisecondsSinceEpoch.toDouble(),
      );
    },
  );

  testWidgets('short windows hide the average legend when no line exists', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        GoalProgressCard(
          progress: GoalProgressView(
            today: today,
            metric: GoalMetricProgressView(
              sourceId: GoalHealthDataTypes.weight,
              name: 'Weight',
              target: 88,
              days: [
                for (var offset = 5; offset >= 0; offset--) day(offset, 94),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('7-day average'), findsNothing);
  });

  testWidgets('non-average weight aggregation keeps its aggregation chart', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        GoalProgressCard(
          progress: GoalProgressView(
            today: today,
            metric: GoalMetricProgressView(
              sourceId: GoalHealthDataTypes.weight,
              name: 'Weight total',
              target: 600,
              aggregation: GoalAggregation.sum,
              days: [
                for (var offset = 6; offset >= 0; offset--) day(offset, 90),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(TimeSeriesLineChart), findsOneWidget);
    expect(find.byType(TimeSeriesMultiLineChart), findsNothing);
    expect(find.text('7-day average'), findsNothing);
  });

  testWidgets(
    'steps distinguish daily values from the average and interpret lower as away',
    (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          GoalProgressCard(
            progress: GoalProgressView(
              today: today,
              metric: GoalMetricProgressView(
                criterionId: 'steps',
                sourceId: 'cumulative_step_count',
                name: 'Average steps per day',
                target: 10000,
                unitName: 'steps',
                evaluatedActual: 8400,
                days: [
                  day(7, 12000),
                  day(6, 11000),
                  day(5, 10000),
                  day(4, 9000),
                  GoalProgressDay(
                    day: today.subtract(const Duration(days: 3)),
                    value: 0,
                    isObserved: false,
                  ),
                  day(2, 8000),
                  day(1, 7000),
                  day(0, 6000),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Steps per day'), findsNWidgets(2));
      expect(find.text('Average steps per day'), findsOneWidget);
      expect(find.byType(TimeSeriesBarLineChart), findsOneWidget);
      expect(find.byType(BarChart), findsOneWidget);
      final overlay = tester.widget<LineChart>(find.byType(LineChart));
      expect(overlay.data.lineBarsData, hasLength(2));
      expect(overlay.data.lineBarsData.last.dashArray, isNotEmpty);
      expect(overlay.data.lineBarsData.last.spots.map((spot) => spot.y), [
        9500,
        8500,
      ]);
      expect(find.text('7-day average'), findsOneWidget);
      expect(find.text('Goal'), findsOneWidget);
      // A step target is a round number in the thousands and its direction
      // is never in doubt — nobody caps their steps — so the legend states
      // the figure compactly instead of "≥ 10,000".
      expect(
        find.descendant(
          of: find.byType(DashboardChartLegend),
          matching: find.text('10K'),
        ),
        findsOneWidget,
        reason: 'the chart axis also reads 10K, so scope to the legend',
      );
      expect(find.textContaining('≥'), findsNothing);
      expect(find.textContaining('7-day average · '), findsNothing);
    },
  );

  testWidgets('a habit track starts on the card rail, not a chart gutter', (
    tester,
  ) async {
    final days = [for (var offset = 13; offset >= 0; offset--) day(offset, 90)];
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        SingleChildScrollView(
          child: GoalProgressCard(
            progress: GoalProgressView(
              today: today,
              habits: [
                GoalHabitProgressView(
                  habitId: 'weigh-myself',
                  name: 'Weigh myself',
                  targetCount: 7,
                  successfulWeeks: 2,
                  days: days,
                ),
              ],
              metric: GoalMetricProgressView(
                sourceId: GoalHealthDataTypes.weight,
                name: 'Weight',
                target: 88,
                direction: GoalDirection.atMost,
                unitName: 'kg',
                days: days,
              ),
            ),
          ),
        ),
      ),
    );

    final habitPlot = tester.getRect(
      find.byKey(const ValueKey('goal-habit-plot-weigh-myself')),
    );
    final period = tester.getRect(find.text('Jul 29 – Aug 11'));
    final lineChart = tester.getRect(find.byType(TimeSeriesMultiLineChart));

    // The habit card draws no plot, so it owes no y-axis gutter: its span
    // caption and its squares sit on the card's own rail. Inset by a chart's
    // axis width they started 52px right of everything else on the card,
    // keyed to a plot that is not there.
    expect(period.left, habitPlot.left);
    expect(habitPlot.left, lessThan(lineChart.left + kChartLeftAxisWidth));
  });

  testWidgets('a hand-painted bar series carries an axis, a date row, a key '
      'and a tappable value', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        SingleChildScrollView(
          child: GoalProgressCard(
            progress: GoalProgressView(
              today: today,
              metric: GoalMetricProgressView(
                criterionId: 'content',
                name: 'Content Production',
                kind: GoalDimensionKind.labelTime,
                target: 60,
                unitName: 'min',
                days: [
                  day(2, 0),
                  day(1, 45),
                  GoalProgressDay(day: today, value: 0, isObserved: false),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // A value axis: the card was a wall of bars with no way to read a
    // magnitude off any of them.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('60'), findsOneWidget);
    // A date axis on the bars' own grid.
    expect(
      find.byKey(ValueKey('goal-habit-weekday-metric-content-${dayKey(1)}')),
      findsOneWidget,
    );
    // A key naming the three fills, and the threshold the rule marks.
    expect(find.text('On target'), findsOneWidget);
    expect(find.text('Off target'), findsOneWidget);
    expect(find.text('No entry'), findsOneWidget);
    expect(find.text('≥ 60'), findsOneWidget);

    // ...and the value itself, on tap. A 45-minute afternoon was on screen
    // with no way to find out it was 45.
    await tester.tap(
      find.byKey(ValueKey('goal-metric-bar-${dayKey(1)}')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('45 min'), findsOneWidget);
    expect(find.textContaining('Content Production'), findsWidgets);
  });

  testWidgets('a dimension with no readings shows no plot at all', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        GoalProgressCard(
          progress: GoalProgressView(
            today: today,
            metric: GoalMetricProgressView(
              criterionId: 'words',
              name: 'Content: words written',
              kind: GoalDimensionKind.measurable,
              target: 1000,
              aggregation: GoalAggregation.sum,
              days: [
                for (var offset = 13; offset >= 0; offset--)
                  GoalProgressDay(
                    day: today.subtract(Duration(days: offset)),
                    value: 0,
                    isObserved: false,
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('0 of 1,000'), findsOneWidget);
    expect(find.text('Not enough data'), findsOneWidget);
    // No bars, no axis, no date range: an empty full-height frame under a
    // header that already says "Not enough data" reads as a chart that
    // failed to draw.
    expect(find.byType(FractionallySizedBox), findsNothing);
    expect(find.textContaining(' – '), findsNothing);
    expect(
      find.text('There is not enough data to judge this dimension yet.'),
      findsOneWidget,
    );
  });

  testWidgets('a habit past its target reads as a count, not a broken '
      'fraction', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        GoalProgressCard(
          progress: GoalProgressView(
            today: today,
            habits: [
              GoalHabitProgressView(
                habitId: 'walk',
                name: 'Walk',
                targetCount: 3,
                days: [
                  for (var offset = 5; offset >= 0; offset--) day(offset, 1),
                ],
                successfulWeeks: 3,
              ),
            ],
          ),
        ),
      ),
    );

    // "6 of 3 this window" parses as a broken fraction; the count with its
    // target named beside it does not.
    expect(find.text('6 of 3 · rolling 7 days'), findsNothing);
    expect(find.text('6 · target 3 · rolling 7 days'), findsOneWidget);
  });

  testWidgets('the check-off suggestion reads as the prompt it is', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        GoalProgressCard(
          progress: GoalProgressView(
            today: today,
            habits: [
              GoalHabitProgressView(
                habitId: 'bp',
                name: 'BP meds',
                targetCount: 7,
                days: [
                  for (var offset = 6; offset >= 0; offset--) day(offset, 0),
                ],
                successfulWeeks: 0,
                suggestedFromDimensionName: 'Blood Pressure',
              ),
            ],
          ),
          onHabitOutcomeSelected:
              ({required day, required habitId, required outcome}) async =>
                  true,
        ),
      ),
    );

    // The design system's own inline callout, not a second callout dialect:
    // this is the one thing on the card the app is ASKING the user to do, and
    // as a caption row between two other caption rows it read as fine print.
    final callout = find.byKey(
      const ValueKey('goal-habit-checkoff-callout-bp'),
    );
    expect(callout, findsOneWidget);
    expect(
      tester.widget<DesignSystemInlineCallout>(callout).text,
      'Blood Pressure recorded today — check off this habit?',
    );
    // The action rides the callout's trailing edge, as its primary button.
    final button = tester.widget<DesignSystemButton>(
      find.byKey(const ValueKey('goal-habit-checkoff-bp')),
    );
    expect(button.variant, DesignSystemButtonVariant.primary);
    expect(
      find.descendant(of: callout, matching: find.byWidget(button)),
      findsOneWidget,
    );
  });

  testWidgets('metric bars expose localized date, value, target, and state', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        GoalProgressCard(
          progress: GoalProgressView(
            today: today,
            metric: GoalMetricProgressView(
              name: 'Daily steps',
              target: 8000,
              days: [
                GoalProgressDay(
                  day: DateTime.utc(2026, 8, 10),
                  value: 9000,
                ),
                GoalProgressDay(
                  day: DateTime.utc(2026, 8, 11),
                  value: 0,
                  isObserved: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel('Aug 10: 9,000; target 8,000; met'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Aug 11: no value; target 8,000'),
      findsOneWidget,
    );
  });

  testWidgets('a week that fits renders no scroller and no clipped first day', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        SingleChildScrollView(
          child: GoalProgressCard(
            progress: GoalProgressView(
              today: today,
              habits: [
                GoalHabitProgressView(
                  habitId: 'walk',
                  name: 'Walk',
                  targetCount: 1,
                  days: [
                    for (var offset = 6; offset >= 0; offset--) day(offset, 0),
                  ],
                  successfulWeeks: 0,
                ),
              ],
              metric: GoalMetricProgressView(
                name: 'Meditation',
                sourceId: 'meditation',
                target: 10,
                days: [
                  for (var offset = 6; offset >= 0; offset--) day(offset, 5),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Nothing to pan: a track that fits its card is laid out in place. It
    // used to sit in a horizontal scroller regardless, which is what let a
    // longer span open anchored at its trailing edge with the first days cut
    // in half off the left.
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SingleChildScrollView &&
            widget.scrollDirection == Axis.horizontal,
      ),
      findsNothing,
    );
    // Every day of the week is on screen, first one included.
    for (var offset = 6; offset >= 0; offset--) {
      expect(
        find.byKey(ValueKey('goal-habit-day-visual-walk-${dayKey(offset)}')),
        findsOneWidget,
      );
    }
  });

  testWidgets('mixed composite renders habit and every metric series', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        SingleChildScrollView(
          child: GoalProgressCard(
            progress: GoalProgressView(
              today: today,
              habits: [
                GoalHabitProgressView(
                  habitId: 'walk',
                  name: 'Walk',
                  targetCount: 1,
                  days: [
                    for (var offset = 6; offset >= 0; offset--) day(offset, 0),
                  ],
                  successfulWeeks: 0,
                ),
              ],
              metrics: [
                GoalMetricProgressView(
                  name: 'Steps',
                  target: 50000,
                  days: [
                    for (var offset = 6; offset >= 0; offset--) day(offset, 0),
                  ],
                ),
                GoalMetricProgressView(
                  name: 'Sleep',
                  target: 8,
                  days: [
                    for (var offset = 6; offset >= 0; offset--) day(offset, 0),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Walk'), findsOneWidget);
    expect(find.text('Steps'), findsOneWidget);
    expect(find.text('Sleep'), findsOneWidget);
    expect(find.byType(FractionallySizedBox), findsNWidgets(14));
  });

  testWidgets('a calendar-month metric fits its whole period, and only pans '
      'when even the narrowest column will not', (tester) async {
    Future<void> pump(double width) => tester.pumpWidget(
      makeTestableWidgetNoScroll(
        SingleChildScrollView(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: GoalProgressCard(
                progress: GoalProgressView(
                  today: today,
                  metric: GoalMetricProgressView(
                    name: 'Daily steps',
                    target: 8000,
                    window: const GoalWindow.calendarMonth(),
                    days: [
                      for (var day = 1; day <= 31; day++)
                        GoalProgressDay(
                          day: DateTime.utc(2026, 8, day),
                          value: 5000,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await pump(760);
    expect(find.text('Aug 1 – Aug 31'), findsOneWidget);
    expect(find.byType(FractionallySizedBox), findsNWidgets(31));
    // A month fits a wide card by narrowing its columns — no pan, so no day
    // opens cut off the left edge.
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SingleChildScrollView &&
            widget.scrollDirection == Axis.horizontal,
      ),
      findsNothing,
    );

    // On a phone the columns hit their legibility floor, and only then does
    // the track pan.
    await pump(320);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SingleChildScrollView &&
            widget.scrollDirection == Axis.horizontal,
      ),
      findsOneWidget,
    );
  });

  testWidgets('a calendar metric uses the observed period aggregate', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        GoalProgressCard(
          progress: GoalProgressView(
            today: today,
            metric: GoalMetricProgressView(
              name: 'Meditation minutes',
              target: 10,
              aggregation: GoalAggregation.sum,
              window: const GoalWindow.calendarMonth(),
              days: [
                day(1, 6),
                day(0, 6),
                for (var offset = 1; offset <= 20; offset++)
                  GoalProgressDay(
                    day: today.add(Duration(days: offset)),
                    value: 0,
                    isObserved: false,
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('12 of 10'), findsOneWidget);
    // The header's status caption is the card's only verdict; the sentence
    // that restated it under the plot is gone.
    expect(find.text('This dimension is currently on track.'), findsNothing);
    expect(find.text('On track'), findsOneWidget);
  });

  testWidgets('daily label time flips from in progress to fulfilled green', (
    tester,
  ) async {
    Widget card(num hours) => makeTestableWidgetNoScroll(
      GoalProgressCard(
        progress: GoalProgressView(
          today: today,
          metric: GoalMetricProgressView(
            criterionId: 'daily-content',
            sourceId: 'content',
            name: 'Content',
            target: 1,
            kind: GoalDimensionKind.labelTime,
            aggregation: GoalAggregation.sum,
            window: const GoalWindow.day(),
            days: [day(0, hours)],
          ),
        ),
      ),
    );

    await tester.pumpWidget(card(0.75));

    expect(find.text('Tracked time by label'), findsOneWidget);
    expect(find.text('Needs attention'), findsOneWidget);
    expect(find.text('On track'), findsNothing);

    await tester.pumpWidget(card(65 / 60));
    await tester.pump();

    final status = tester.widget<Text>(find.text('On track'));
    final tokens = tester.element(find.text('On track')).designTokens;
    expect(status.style?.color, tokens.colors.alert.success.ink);
    expect(find.text('This dimension is currently on track.'), findsNothing);
  });

  testWidgets('renders an observed-pattern card for every category dimension', (
    tester,
  ) async {
    GoalMetricProgressView categoryMetric(String name, int hour) =>
        GoalMetricProgressView(
          name: name,
          target: 1,
          kind: GoalDimensionKind.categoryTime,
          days: [day(0, 1)],
          categoryTimeSessions: [
            GoalCategoryTimeSession(
              categoryId: name,
              dateFrom: DateTime(2026, 8, 11, hour),
              dateTo: DateTime(2026, 8, 11, hour + 1),
            ),
          ],
        );
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        SingleChildScrollView(
          child: GoalProgressCard(
            progress: GoalProgressView(
              today: today,
              metrics: [
                categoryMetric('Deep work', 9),
                categoryMetric('Late work', 22),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Timing pattern · Deep work'), findsOneWidget);
    expect(find.text('Timing pattern · Late work'), findsOneWidget);
  });

  testWidgets('a calendar-month habit shows its whole authored period', (
    tester,
  ) async {
    final outcomes = <(DateTime, HabitCompletionType)>[];
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        GoalProgressCard(
          progress: GoalProgressView(
            today: today,
            habits: [
              GoalHabitProgressView(
                habitId: 'walk',
                name: 'Walk',
                targetCount: 2,
                window: const GoalWindow.calendarMonth(),
                days: [
                  for (var date = 1; date <= 31; date++)
                    GoalProgressDay(
                      day: DateTime.utc(2026, 8, date),
                      value: 0,
                    ),
                ],
                successfulWeeks: 0,
              ),
            ],
          ),
          onHabitOutcomeSelected:
              ({required day, required habitId, required outcome}) async {
                outcomes.add((day, outcome));
                return true;
              },
        ),
      ),
    );

    expect(find.text('Aug 1 – Aug 31'), findsOneWidget);
    expect(find.text('2× · calendar month'), findsNothing);
    expect(find.textContaining('· calendar month'), findsOneWidget);
    expect(find.textContaining('/ 6'), findsNothing);
    // Every day of the month is on the track, first to last; the square
    // never shrinks, so a month wider than the card pans, anchored on today.
    expect(
      find.byKey(const ValueKey('goal-habit-day-walk-2026-08-01')),
      findsOneWidget,
    );
    const finalDayKey = ValueKey('goal-habit-day-walk-2026-08-31');
    // Only today's open square is dashed; the month's remaining days are
    // plain empty squares, not "not yet".
    expect(find.byType(DsDashedBorder), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('goal-habit-day-walk-2026-08-11')),
        matching: find.byType(DsDashedBorder),
      ),
      findsOneWidget,
    );
    await tester.ensureVisible(find.byKey(finalDayKey));
    await tester.tap(find.byKey(finalDayKey));
    await tester.pump();
    expect(find.byKey(finalDayKey), findsOneWidget);
    expect(find.byType(DesignSystemContextMenu), findsNothing);
    expect(outcomes, isEmpty);
  });

  testWidgets('an at-most metric highlights the value at its ceiling', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        GoalProgressCard(
          progress: GoalProgressView(
            today: today,
            metric: GoalMetricProgressView(
              name: 'Screen time',
              target: 60,
              direction: GoalDirection.atMost,
              days: [day(1, 61), day(0, 60)],
            ),
          ),
        ),
      ),
    );

    Color barColor(String date) {
      final bar = tester.widget<FractionallySizedBox>(
        find.byKey(ValueKey('goal-metric-bar-$date')),
      );
      return ((bar.child! as DecoratedBox).decoration as BoxDecoration).color!;
    }

    expect(barColor('2026-08-10'), isNot(barColor('2026-08-11')));
  });

  testWidgets('a day at or above an at-least target wears the day-cell '
      'success fill, and a slimmer bar than its share of the row', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        GoalProgressCard(
          progress: GoalProgressView(
            today: today,
            metric: GoalMetricProgressView(
              name: 'Steps',
              target: 10000,
              // `targetSatisfied` is the evaluator's ROLLING verdict as of
              // each day, set here to pin the per-day policy: a bar is met
              // by the day's own number OR by that verdict, and short only
              // when neither holds. Without explicit verdicts every day took
              // the null-fallback branch and the test passed against any
              // policy.
              days: [
                GoalProgressDay(
                  day: today.subtract(const Duration(days: 2)),
                  value: 6100,
                  targetSatisfied: false,
                ),
                GoalProgressDay(
                  day: today.subtract(const Duration(days: 1)),
                  value: 12400,
                  targetSatisfied: false,
                ),
                GoalProgressDay(day: today, value: 5262, targetSatisfied: true),
              ],
            ),
          ),
        ),
      ),
    );

    final tokens = tester.element(find.byType(GoalProgressCard)).designTokens;
    Color barColor(String date) {
      final bar = tester.widget<FractionallySizedBox>(
        find.byKey(ValueKey('goal-metric-bar-$date')),
      );
      return ((bar.child! as DecoratedBox).decoration as BoxDecoration).color!;
    }

    // The bar beating the goal wears exactly the fill a met day cell wears —
    // one meaning, one colour, across every goal surface. It used to be
    // `alert.info`, a blue carrying no threshold meaning, so beating the
    // target looked identical to missing it.
    expect(
      barColor('2026-08-10'),
      dayMarkStateFill(tokens, DayMarkState.full),
      reason:
          '12,400 steps beat the 10,000 target even though the '
          'trailing-week verdict for that day says short',
    );
    // Short, but MEASURED. `background.level03` is what the legend calls
    // absence, so a logged day that fell short wears the muted wash of the
    // success family instead — three states, three fills.
    expect(
      barColor('2026-08-11'),
      dayMarkStateFill(tokens, DayMarkState.full),
      reason:
          '5,262 steps fell short of the day target, but the rolling week '
          'ending that day holds — the other winnable condition',
    );
    expect(
      barColor('2026-08-09'),
      dayMarkStateFill(tokens, DayMarkState.partial),
      reason:
          '6,100 steps fell short on both counts but were still logged — '
          'measured, not absent, so the muted wash rather than the neutral',
    );

    // Seven bars filling a full-width card rendered ~40px slabs. Each one now
    // sits at exactly the width the scrollable variant uses.
    //
    // Asserted as an equality on purpose: `lessThanOrEqualTo` also accepts
    // zero, and zero is precisely what a loose width constraint produces
    // here — `_bar` is a FractionallySizedBox with no widthFactor, so it
    // passes the constraint through to a DecoratedBox with no intrinsic
    // width and the whole chart disappears.
    expect(
      tester
          .getSize(find.byKey(const ValueKey('goal-metric-bar-2026-08-11')))
          .width,
      kDaySquareSize,
    );
  });

  testWidgets('an observed zero keeps a visible success baseline', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        GoalProgressCard(
          progress: GoalProgressView(
            today: today,
            metric: GoalMetricProgressView(
              name: 'Cigarettes',
              target: 0,
              direction: GoalDirection.atMost,
              days: [day(1, 1), day(0, 0)],
            ),
          ),
        ),
      ),
    );

    final zeroBar = tester.widget<FractionallySizedBox>(
      find.byKey(const ValueKey('goal-metric-bar-2026-08-11')),
    );
    expect(zeroBar.heightFactor, greaterThan(0));
  });

  testWidgets('a habit at its rate says nothing where the header already '
      'does, and still fits its week', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Center(
          child: SizedBox(
            width: 260,
            child: GoalProgressCard(
              progress: GoalProgressView(
                today: today,
                habits: [
                  GoalHabitProgressView(
                    habitId: 'walk',
                    name: 'Walk',
                    targetCount: 2,
                    days: [
                      day(6, 1),
                      day(5, 0),
                      day(4, 0),
                      day(3, 0),
                      day(2, 0),
                      day(1, 0),
                      day(0, 1),
                    ],
                    successfulWeeks: 6,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // "at rate" was a cryptic two-word note printed beside the six-week tail,
    // repeating what the header's own status already says in plain words.
    expect(find.text('at rate'), findsNothing);
    expect(find.text('On track'), findsOneWidget);
    // And the week fits a 260px card, so nothing pans and no day is clipped.
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SingleChildScrollView &&
            widget.scrollDirection == Axis.horizontal,
      ),
      findsNothing,
    );
    expect(
      find.byKey(ValueKey('goal-habit-day-visual-walk-${dayKey(6)}')),
      findsOneWidget,
    );
  });

  testWidgets('tapping a previous habit day records the chosen outcome for '
      'that exact date', (tester) async {
    ({DateTime day, String habitId, HabitCompletionType outcome})? selected;
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        GoalProgressCard(
          progress: GoalProgressView(
            today: today,
            habits: [
              GoalHabitProgressView(
                habitId: 'walk',
                name: 'Walk',
                targetCount: 3,
                days: [
                  day(6, 0),
                  day(5, 0),
                  day(4, 0),
                  day(3, 0),
                  day(2, 0),
                  day(1, 0),
                  day(0, 0),
                ],
                successfulWeeks: 2,
              ),
            ],
          ),
          onHabitOutcomeSelected:
              ({
                required day,
                required habitId,
                required outcome,
              }) async {
                selected = (day: day, habitId: habitId, outcome: outcome);
                return true;
              },
        ),
      ),
    );

    final dayFinder = find.byKey(
      const ValueKey('goal-habit-day-walk-2026-08-08'),
    );
    expect(
      find.bySemanticsLabel('Aug 8, 2026: No entry'),
      findsOneWidget,
    );

    await tester.tap(dayFinder);
    await tester.pumpAndSettle();
    expect(find.byType(DesignSystemContextMenu), findsOneWidget);
    // Scoped to the menu.
    final menu = find.byType(DesignSystemContextMenu);
    expect(
      find.descendant(of: menu, matching: find.text('Success')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: menu, matching: find.text('Skip')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: menu, matching: find.text('Missed')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(DesignSystemContextMenu),
        matching: find.text('No entry'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(DesignSystemContextMenu),
        matching: find.byIcon(LottiIcons.confirm),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(DayTrack),
        matching: find.byIcon(LottiIcons.remove),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(DesignSystemContextMenu),
        matching: find.byIcon(LottiIcons.close),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(LottiIcons.radioUnselected), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('goal-habit-day-missed')));
    await tester.pump();

    expect(selected?.habitId, 'walk');
    expect(selected?.day, DateTime.utc(2026, 8, 8));
    expect(selected?.outcome, HabitCompletionType.fail);
  });

  testWidgets('skip and no-entry actions append the intended goal outcomes', (
    tester,
  ) async {
    final outcomes = <HabitCompletionType>[];
    Future<void> pump(HabitCompletionType? currentOutcome) => tester.pumpWidget(
      makeTestableWidgetNoScroll(
        GoalProgressCard(
          progress: GoalProgressView(
            today: today,
            habits: [
              GoalHabitProgressView(
                habitId: 'walk',
                name: 'Walk',
                targetCount: 3,
                days: [
                  for (var offset = 6; offset > 3; offset--) day(offset, 0),
                  GoalProgressDay(
                    day: today.subtract(const Duration(days: 3)),
                    value: currentOutcome == HabitCompletionType.success
                        ? 1
                        : 0,
                    habitCompletionType: currentOutcome,
                  ),
                  for (var offset = 2; offset >= 0; offset--) day(offset, 0),
                ],
                successfulWeeks: 2,
              ),
            ],
          ),
          onHabitOutcomeSelected:
              ({required day, required habitId, required outcome}) async {
                outcomes.add(outcome);
                return true;
              },
        ),
      ),
    );

    await pump(HabitCompletionType.success);

    const dayKey = ValueKey('goal-habit-day-walk-2026-08-08');
    await tester.tap(find.byKey(dayKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('goal-habit-day-skipped')));
    await tester.pump();

    expect(outcomes, [HabitCompletionType.skip]);

    await pump(HabitCompletionType.skip);
    await tester.tap(find.byKey(dayKey));
    await tester.pumpAndSettle();
    final menuRect = tester.getRect(
      find.byKey(const ValueKey('goal-habit-day-menu')),
    );
    final noneRect = tester.getRect(
      find.byKey(const ValueKey('goal-habit-day-none')),
    );
    expect(
      noneRect.bottom,
      menuRect.bottom,
      reason: 'the last hover row reaches the clipped bottom border',
    );
    await tester.tap(find.byKey(const ValueKey('goal-habit-day-none')));
    await tester.pump();

    expect(outcomes, [HabitCompletionType.skip, HabitCompletionType.open]);
  });

  testWidgets('a skipped day uses a neutral fill and skip glyph', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        GoalProgressCard(
          progress: GoalProgressView(
            today: today,
            habits: [
              GoalHabitProgressView(
                habitId: 'walk',
                name: 'Walk',
                targetCount: 3,
                days: [
                  for (var offset = 6; offset > 0; offset--) day(offset, 0),
                  GoalProgressDay(
                    day: today,
                    value: 0,
                    habitCompletionType: HabitCompletionType.skip,
                  ),
                ],
                successfulWeeks: 2,
              ),
            ],
          ),
        ),
      ),
    );

    final tokens = tester.element(find.byType(GoalProgressCard)).designTokens;
    final cell = tester.widget<Container>(
      find.byKey(const ValueKey('goal-habit-day-visual-walk-2026-08-11')),
    );
    expect(
      (cell.decoration! as BoxDecoration).color,
      tokens.colors.background.level03,
    );
    // Nothing is drawn inside the square; the skip is said, not shown.
    expect(
      find.descendant(of: find.byType(DayTrack), matching: find.byType(Icon)),
      findsNothing,
    );
    expect(
      find.bySemanticsLabel('Aug 11, 2026: Skip'),
      findsOneWidget,
    );
  });

  testWidgets('the outcome menu opens with the concrete date of the selected '
      'day', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        GoalProgressCard(
          progress: GoalProgressView(
            today: today,
            habits: [
              GoalHabitProgressView(
                habitId: 'walk',
                name: 'Walk',
                targetCount: 3,
                days: [
                  for (var offset = 6; offset >= 0; offset--) day(offset, 0),
                ],
                successfulWeeks: 2,
              ),
            ],
          ),
          onHabitOutcomeSelected:
              ({required day, required habitId, required outcome}) async =>
                  true,
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('goal-habit-day-walk-2026-08-08')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('goal-habit-day-date-walk-2026-08-08')),
      findsOneWidget,
    );
    expect(find.text('Sat, Aug 8'), findsOneWidget);
  });

  testWidgets('a completed day short of its window target renders as a '
      'partial success, a satisfied day at full strength', (tester) async {
    GoalProgressDay verdictDay(int offset, num value, {bool? satisfied}) =>
        GoalProgressDay(
          day: today.subtract(Duration(days: offset)),
          value: value,
          targetSatisfied: satisfied,
        );
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        GoalProgressCard(
          progress: GoalProgressView(
            today: today,
            habits: [
              GoalHabitProgressView(
                habitId: 'walk',
                name: 'Walk',
                targetCount: 3,
                days: [
                  verdictDay(6, 1, satisfied: false),
                  verdictDay(5, 0, satisfied: false),
                  verdictDay(4, 0, satisfied: false),
                  verdictDay(3, 1, satisfied: true),
                  verdictDay(2, 0, satisfied: true),
                  verdictDay(1, 0, satisfied: true),
                  verdictDay(0, 0, satisfied: true),
                ],
                successfulWeeks: 2,
              ),
            ],
          ),
        ),
      ),
    );

    // The completed-but-short day carries the partial marker...
    expect(
      find.byKey(const ValueKey('goal-day-partial-walk-2026-08-05')),
      findsOneWidget,
    );
    // ...while the completed day whose window verdict held does not.
    expect(
      find.byKey(const ValueKey('goal-day-partial-walk-2026-08-08')),
      findsNothing,
    );
    final tokens = tester.element(find.byType(GoalProgressCard)).designTokens;
    final partialCell = tester.widget<Container>(
      find.byKey(const ValueKey('goal-habit-day-visual-walk-2026-08-05')),
    );
    final fullCell = tester.widget<Container>(
      find.byKey(const ValueKey('goal-habit-day-visual-walk-2026-08-08')),
    );
    // The handover's interactive square for a kept day, a wash of it for
    // a day that was kept while the window target was still building.
    expect(
      (partialCell.decoration! as BoxDecoration).color,
      tokens.colors.interactive.enabled.withValues(alpha: SurfaceAlphas.muted),
    );
    expect(
      (fullCell.decoration! as BoxDecoration).color,
      tokens.colors.interactive.enabled,
    );
  });

  testWidgets('a same-goal observation recorded today offers a one-tap habit '
      'check-off', (tester) async {
    ({DateTime day, String habitId, HabitCompletionType outcome})? selected;
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        SingleChildScrollView(
          child: GoalProgressCard(
            progress: GoalProgressView(
              today: today,
              habits: [
                GoalHabitProgressView(
                  habitId: 'measure',
                  name: 'Measure Blood Pressure',
                  targetCount: 5,
                  days: [
                    for (var offset = 6; offset >= 0; offset--) day(offset, 0),
                  ],
                  successfulWeeks: 0,
                  suggestedFromDimensionName: 'Systolic blood pressure',
                ),
              ],
            ),
            onHabitOutcomeSelected:
                ({required day, required habitId, required outcome}) async {
                  selected = (day: day, habitId: habitId, outcome: outcome);
                  return true;
                },
          ),
        ),
      ),
    );

    expect(
      find.text(
        'Systolic blood pressure recorded today — check off this habit?',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('goal-habit-checkoff-measure')));
    await tester.pump();

    expect(selected?.habitId, 'measure');
    expect(selected?.day, today);
    expect(selected?.outcome, HabitCompletionType.success);
  });

  testWidgets('without a suggestion or callback no check-off affordance '
      'renders', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        GoalProgressCard(
          progress: GoalProgressView(
            today: today,
            habits: [
              GoalHabitProgressView(
                habitId: 'measure',
                name: 'Measure Blood Pressure',
                targetCount: 5,
                days: [
                  for (var offset = 6; offset >= 0; offset--) day(offset, 0),
                ],
                successfulWeeks: 0,
                suggestedFromDimensionName: 'Systolic blood pressure',
              ),
            ],
          ),
        ),
      ),
    );

    // A read-only card (inactive goal) must not offer the write path even
    // when the suggestion is present in the projection.
    expect(
      find.byKey(const ValueKey('goal-habit-checkoff-measure')),
      findsNothing,
    );
  });

  testWidgets(
    'the day squares sit on the shared pitch with no label row and nothing '
    'inside them',
    (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          GoalProgressCard(
            progress: GoalProgressView(
              today: today,
              habits: [
                GoalHabitProgressView(
                  habitId: 'walk',
                  name: 'Walk',
                  targetCount: 3,
                  days: [
                    for (var offset = 6; offset >= 0; offset--) day(offset, 0),
                  ],
                  successfulWeeks: 2,
                ),
              ],
            ),
            onHabitOutcomeSelected:
                ({required day, required habitId, required outcome}) async =>
                    true,
          ),
        ),
      );

      // No full-word label row above the squares; a tappable square carries
      // its weekday initial above it, inside its own slot.
      expect(find.text('Wed'), findsNothing);
      final letterFormat = DateFormat.EEEEE('en');
      final tokens = tester.element(find.byType(GoalProgressCard)).designTokens;
      final expectedPitch = kDaySquareSize + tokens.spacing.step2;
      double? previousCenter;
      for (var offset = 6; offset >= 0; offset--) {
        final date = today.subtract(Duration(days: offset));
        final key = date.toIso8601String().substring(0, 10);
        final cell = find.byKey(ValueKey('goal-habit-day-walk-$key'));
        final visualCell = find.byKey(
          ValueKey('goal-habit-day-visual-walk-$key'),
        );
        expect(tester.getSize(visualCell), const Size.square(kDaySquareSize));
        // The interactive slot fills the track pitch horizontally and
        // meets the design system's touch floor vertically.
        expect(
          tester.getSize(cell),
          Size(
            expectedPitch,
            TapTargets.minimum,
          ),
        );
        expect(
          find.descendant(of: visualCell, matching: find.byType(Text)),
          findsNothing,
          reason: '$key draws nothing inside its square',
        );
        expect(
          find.descendant(
            of: cell,
            matching: find.text(letterFormat.format(date)),
          ),
          findsOneWidget,
          reason: '$key names its weekday above the square',
        );
        final center = tester.getCenter(cell).dx;
        if (previousCenter != null) {
          expect(
            center - previousCenter,
            closeTo(expectedPitch, 0.01),
            reason: 'desktop cells follow the compact handoff rhythm',
          );
        }
        previousCenter = center;
      }
    },
  );

  testWidgets(
    'the day-track pitch expands as soon as scaled text needs it',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.01)),
              child: GoalProgressCard(
                progress: GoalProgressView(
                  today: today,
                  habits: [
                    GoalHabitProgressView(
                      habitId: 'walk',
                      name: 'Walk',
                      targetCount: 3,
                      days: [
                        for (var offset = 6; offset >= 0; offset--)
                          day(offset, 0),
                      ],
                      successfulWeeks: 2,
                    ),
                  ],
                ),
                onHabitOutcomeSelected:
                    ({
                      required day,
                      required habitId,
                      required outcome,
                    }) async => true,
              ),
            ),
          ),
        ),
      );

      final tokens = tester.element(find.byType(GoalProgressCard)).designTokens;
      final defaultPitch = kDaySquareSize + tokens.spacing.step2;
      double? previousCellCenter;
      for (var offset = 6; offset >= 0; offset--) {
        final date = today
            .subtract(Duration(days: offset))
            .toIso8601String()
            .substring(0, 10);
        final cell = find.byKey(ValueKey('goal-habit-day-walk-$date'));
        expect(cell, findsOneWidget);
        final cellCenter = tester.getCenter(cell).dx;
        if (previousCellCenter != null) {
          expect(
            cellCenter - previousCellCenter,
            greaterThan(defaultPitch),
            reason: 'only accessibility scaling should loosen the handoff grid',
          );
        }
        previousCellCenter = cellCenter;
      }
    },
  );

  testWidgets('phone handoff keeps compact habit metadata and cells tight', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Center(
          child: SizedBox(
            width: 358,
            child: GoalProgressCard(
              progress: GoalProgressView(
                today: today,
                habits: [
                  GoalHabitProgressView(
                    habitId: 'gym',
                    name: 'Gym',
                    targetCount: 4,
                    days: [
                      for (var offset = 6; offset >= 0; offset--)
                        day(offset, offset < 4 ? 1 : 0),
                    ],
                    successfulWeeks: 2,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final streak = find.text('2 / 6 weeks');
    final name = find.text('Gym');
    final period = find.text('Aug 5 – Aug 11');
    final firstCell = find.byKey(
      const ValueKey('goal-habit-day-visual-gym-2026-08-05'),
    );

    // One meaning per row, top to bottom: what the habit is, the window —
    // its span leading, its six-week tail trailing — then the days
    // themselves. The cadence line is gone; its target lives in the corner
    // block.
    expect(find.textContaining('4× per 7 days'), findsNothing);
    expect(
      tester.getTopLeft(period).dy,
      greaterThan(tester.getBottomLeft(name).dy),
      reason: 'the span labels the squares, so it sits above them',
    );
    expect(
      tester.getCenter(streak).dy,
      closeTo(tester.getCenter(period).dy, 1),
      reason: 'span and tail share the window line',
    );
    expect(
      tester.getTopLeft(firstCell).dy,
      greaterThan(tester.getBottomLeft(period).dy),
      reason: 'the mobile grid follows the dimension metadata',
    );
    // The span and the squares share one rail — the caption used to start a
    // chart gutter to their left, on a card that draws no chart.
    expect(
      tester.getTopLeft(period).dx,
      lessThanOrEqualTo(tester.getTopLeft(firstCell).dx),
    );
  });

  testWidgets('the window line survives a habit with no reliability tail', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Center(
          child: SizedBox(
            width: 358,
            child: GoalProgressCard(
              progress: GoalProgressView(
                today: today,
                habits: [
                  GoalHabitProgressView(
                    habitId: 'gym',
                    name: 'Gym',
                    targetCount: 4,
                    days: [
                      for (var offset = 6; offset >= 0; offset--)
                        day(offset, 0),
                    ],
                    successfulWeeks: null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // The window line survives without a tail beside it: the two share a
    // row, and a habit with no streak still names the days it covers.
    expect(find.text('Aug 5 – Aug 11'), findsOneWidget);
    expect(find.textContaining('/ 6 weeks'), findsNothing);
  });

  testWidgets(
    'compact habit day follows the mobile handoff and ignores its current outcome',
    (
      tester,
    ) async {
      final outcomes = <HabitCompletionType>[];
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Center(
            child: SizedBox(
              width: 260,
              child: GoalProgressCard(
                progress: GoalProgressView(
                  today: today,
                  habits: [
                    GoalHabitProgressView(
                      habitId: 'walk',
                      name: 'Walk',
                      targetCount: 1,
                      days: [
                        for (var offset = 6; offset > 0; offset--)
                          day(offset, 0),
                        GoalProgressDay(
                          day: today,
                          value: 1,
                          habitCompletionType: HabitCompletionType.success,
                        ),
                      ],
                      successfulWeeks: 1,
                    ),
                  ],
                ),
                onHabitOutcomeSelected:
                    ({
                      required day,
                      required habitId,
                      required outcome,
                    }) async {
                      outcomes.add(outcome);
                      return true;
                    },
              ),
            ),
          ),
        ),
      );

      const dayKey = ValueKey('goal-habit-day-walk-2026-08-11');
      expect(
        tester.getSize(find.byKey(dayKey)),
        Size(
          kDaySquareSize +
              tester
                  .element(find.byType(GoalProgressCard))
                  .designTokens
                  .spacing
                  .step2,
          TapTargets.minimum,
        ),
      );
      // The rolling week renders no cadence line at any width, and the
      // window line names only the days it covers.
      expect(find.textContaining('1× per 7 days'), findsNothing);
      expect(find.textContaining('slides at midnight'), findsNothing);
      expect(find.textContaining(' – '), findsOneWidget);

      await tester.tap(find.byKey(dayKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('goal-habit-day-success')));
      await tester.pumpAndSettle();

      expect(outcomes, isEmpty);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.tap(find.byKey(dayKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('goal-habit-day-missed')));
      await tester.pump();

      expect(outcomes, [HabitCompletionType.fail]);

      // Re-tapping the cell while its menu is open closes it — the cell is
      // a toggle, not just an opener.
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(dayKey));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('goal-habit-day-menu')), findsOneWidget);
      await tester.tap(find.byKey(dayKey), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('goal-habit-day-menu')), findsNothing);
    },
  );

  testWidgets('interactive day cells paint no hover overlay and answer '
      'hover with the styled tooltip naming the day and outcome', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        GoalProgressCard(
          progress: GoalProgressView(
            today: today,
            habits: [
              GoalHabitProgressView(
                habitId: 'walk',
                name: 'Walk',
                targetCount: 3,
                days: [
                  for (var offset = 6; offset >= 0; offset--) day(offset, 0),
                ],
                successfulWeeks: 0,
              ),
            ],
          ),
          onHabitOutcomeSelected:
              ({required day, required habitId, required outcome}) async =>
                  true,
        ),
      ),
    );

    final cell = find.byKey(
      const ValueKey('goal-habit-day-walk-2026-08-11'),
    );
    // The hit slot is far larger than the square it serves, so Material's
    // hover fill drew a phantom button bulging around the cell — the quiet
    // ink keeps the tap and silences every overlay.
    final ink = tester.widget<InkWell>(
      find.descendant(of: cell, matching: find.byType(InkWell)).first,
    );
    expect(ink.hoverColor, Colors.transparent);
    expect(
      ink.overlayColor?.resolve({WidgetState.hovered}),
      Colors.transparent,
    );

    // Hover answers with the design-system tooltip instead: the day names
    // the subject, the outcome describes it, on one floating surface.
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer();
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(cell));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 200));
    // One rich text carrying both lines — matched together because the
    // legend's own "No entry" label is also on this card.
    expect(
      find.textContaining('Tue, Aug 11\nNo entry', findRichText: true),
      findsOneWidget,
    );
    await gesture.moveTo(Offset.zero);
    await tester.pumpAndSettle();
  });

  testWidgets('a habit day the user judged in the reflection wears that '
      'verdict on its square, outranking the measured outcome', (tester) async {
    final handle = tester.ensureSemantics();
    final judged = today.subtract(const Duration(days: 1));
    GoalAssessmentRecord record({
      required String id,
      required String specVersionId,
      required DayVerdict verdict,
      required DateTime createdAt,
    }) => GoalAssessmentRecord(
      id: id,
      day: judged,
      specVersionId: specVersionId,
      rating: DayVerdict.mixed,
      createdAt: createdAt,
      provenance: DayVerdictProvenance.ratedByUser,
      dimensionRatings: {'c-walk': verdict},
    );
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        GoalProgressCard(
          specVersionId: 'spec-2',
          assessments: [
            // Under the retired spec the day was filed as met; under the
            // current one as improving. Only the current one may colour it.
            record(
              id: 'retired',
              specVersionId: 'spec-1',
              verdict: DayVerdict.met,
              createdAt: DateTime(2026, 8, 10, 23),
            ),
            record(
              id: 'current',
              specVersionId: 'spec-2',
              verdict: DayVerdict.improving,
              createdAt: DateTime(2026, 8, 10, 22),
            ),
          ],
          progress: GoalProgressView(
            today: today,
            habits: [
              GoalHabitProgressView(
                habitId: 'walk',
                criterionId: 'c-walk',
                name: 'Walk',
                targetCount: 3,
                days: [
                  day(6, 0),
                  day(5, 0),
                  day(4, 0),
                  day(3, 0),
                  day(2, 0),
                  GoalProgressDay(
                    day: judged,
                    value: 0,
                    habitCompletionType: HabitCompletionType.fail,
                  ),
                  day(0, 0),
                ],
                successfulWeeks: 2,
              ),
            ],
          ),
        ),
      ),
    );
    final tokens = tester.element(find.byType(GoalProgressCard)).designTokens;
    final visual = find.byKey(
      const ValueKey('goal-habit-day-visual-walk-2026-08-10'),
    );
    final decoration =
        tester.widget<Container>(visual).decoration! as BoxDecoration;
    expect(decoration.color, dayVerdictFill(tokens, DayVerdict.improving));
    expect(
      decoration.color,
      isNot(dayMarkStateFill(tokens, DayMarkState.missed)),
      reason: 'the ruling replaced the measured miss',
    );
    expect(
      find.bySemanticsLabel(RegExp('Aug 10, 2026: Improving')),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('a recorded miss is told apart from an empty day', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        GoalProgressCard(
          progress: GoalProgressView(
            today: today,
            habits: [
              GoalHabitProgressView(
                habitId: 'walk',
                name: 'Walk',
                targetCount: 3,
                days: [
                  day(6, 0),
                  day(5, 0),
                  day(4, 0),
                  day(3, 0),
                  day(2, 0),
                  GoalProgressDay(
                    day: today.subtract(const Duration(days: 1)),
                    value: 0,
                    habitCompletionType: HabitCompletionType.fail,
                  ),
                  day(0, 0),
                ],
                successfulWeeks: 2,
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('goal-day-missed-walk-2026-08-10')),
      findsOneWidget,
    );
    // A recorded miss and an empty day share the neutral fill — the strip
    // is a record of what was KEPT — so the difference is said: the missed
    // day names its outcome in the semantics and the tooltip.
    expect(
      find.bySemanticsLabel(RegExp('Aug 10, 2026: Missed')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp('Aug 9, 2026: No entry')),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('a failed completion save clears the busy state and reports it', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: GoalProgressCard(
            progress: GoalProgressView(
              today: today,
              habits: [
                GoalHabitProgressView(
                  habitId: 'walk',
                  name: 'Walk',
                  targetCount: 1,
                  days: [
                    for (var offset = 6; offset >= 0; offset--) day(offset, 0),
                  ],
                  successfulWeeks: 0,
                ),
              ],
            ),
            onHabitOutcomeSelected:
                ({required day, required habitId, required outcome}) async {
                  throw StateError('database write failed');
                },
          ),
        ),
      ),
    );

    const dayKey = ValueKey('goal-habit-day-walk-2026-08-08');
    await tester.tap(find.byKey(dayKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('goal-habit-day-success')));
    await tester.pumpAndSettle();

    expect(find.text("That didn't save — please try again."), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.byKey(dayKey));
    await tester.pumpAndSettle();
    expect(find.byType(DesignSystemContextMenu), findsOneWidget);
  });

  testWidgets('a pending completion disables that day and shows progress', (
    tester,
  ) async {
    final completion = Completer<bool>();
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        GoalProgressCard(
          progress: GoalProgressView(
            today: today,
            habits: [
              GoalHabitProgressView(
                habitId: 'walk',
                name: 'Walk',
                targetCount: 1,
                days: [
                  for (var offset = 6; offset >= 0; offset--) day(offset, 0),
                ],
                successfulWeeks: 0,
              ),
            ],
          ),
          onHabitOutcomeSelected:
              ({required day, required habitId, required outcome}) =>
                  completion.future,
        ),
      ),
    );

    const dayKey = ValueKey('goal-habit-day-walk-2026-08-08');
    await tester.tap(find.byKey(dayKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('goal-habit-day-success')));
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(dayKey),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(dayKey));
    await tester.pump();
    expect(find.byType(DesignSystemContextMenu), findsNothing);

    completion.complete(true);
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('composite summary and reflection preserve the authored rule', (
    tester,
  ) async {
    DateTime? reflectedDay;
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        SingleChildScrollView(
          child: GoalThisWeekCard(
            progress: GoalProgressView(
              today: today,
              compositeRule: GoalCompositeRuleKind.atLeast,
              requiredSuccesses: 2,
              compositeCompactWindow: const [
                DayMarkState.none,
                DayMarkState.full,
                DayMarkState.none,
                DayMarkState.full,
                DayMarkState.full,
                DayMarkState.none,
                DayMarkState.full,
              ],
              habits: [
                GoalHabitProgressView(
                  habitId: 'walk',
                  name: 'Walk',
                  targetCount: 1,
                  days: [day(1, 1), day(0, 0)],
                  successfulWeeks: 2,
                ),
              ],
              metrics: [
                GoalMetricProgressView(
                  name: 'Weight',
                  target: 80,
                  direction: GoalDirection.atMost,
                  days: [day(1, 79), day(0, 81)],
                ),
                GoalMetricProgressView(
                  name: 'Steps',
                  target: 8000,
                  days: [day(1, 7000), day(0, 9000)],
                ),
              ],
            ),
            onReflectDay: (value) => reflectedDay = value,
          ),
        ),
      ),
    );

    expect(find.text('This week'), findsOneWidget);
    expect(
      find.text('Yesterday: 2 of 3 dimensions · 2 required.'),
      findsOneWidget,
    );
    expect(find.text('Reflect on today'), findsOneWidget);

    await tester.ensureVisible(find.text('Reflect on today'));
    await tester.tap(find.text('Reflect on today'));
    expect(reflectedDay, today);
  });

  testWidgets(
    'dimension cards cover health, measurable, projected, and timing states',
    (tester) async {
      final sessions = [
        for (var index = 0; index < 25; index++)
          GoalCategoryTimeSession(
            categoryId: 'focus',
            dateFrom: DateTime(2026, 8, 10, index % 24),
            dateTo: DateTime(2026, 8, 10, index % 24).add(
              const Duration(minutes: 30),
            ),
          ),
      ];
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          SingleChildScrollView(
            child: GoalProgressCard(
              progress: GoalProgressView(
                today: today,
                metrics: [
                  GoalMetricProgressView(
                    criterionId: 'pressure',
                    name: 'Systolic pressure',
                    target: 120,
                    direction: GoalDirection.atMost,
                    aggregation: GoalAggregation.max,
                    unitName: 'mmHg',
                    days: [day(1, 119), day(0, 121)],
                  ),
                  GoalMetricProgressView(
                    criterionId: 'meds',
                    name: 'Medication doses',
                    target: 2,
                    kind: GoalDimensionKind.measurable,
                    unitName: '',
                    days: [day(0, 1)],
                    projectedOnTrack: true,
                  ),
                  GoalMetricProgressView(
                    criterionId: 'weight',
                    name: 'Weight',
                    target: 80,
                    days: [
                      GoalProgressDay(
                        day: today,
                        value: 0,
                        isObserved: false,
                      ),
                    ],
                  ),
                  GoalMetricProgressView(
                    criterionId: 'focus',
                    name: 'Late focus',
                    target: 1,
                    kind: GoalDimensionKind.categoryTime,
                    dailyTimeRange: const GoalDailyTimeRange(
                      startMinute: 22 * 60,
                      endMinute: 7 * 60,
                    ),
                    days: [day(0, 1)],
                    categoryTimeSessions: sessions,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Health data'), findsNWidgets(2));
      expect(find.text('Your measurable'), findsOneWidget);
      expect(find.text('Tracked category time'), findsOneWidget);
      expect(find.text('1 of 2'), findsOneWidget);
      final measurableCard = find.ancestor(
        of: find.text('Medication doses'),
        matching: find.byType(DesignSystemSectionCard),
      );
      expect(
        find.descendant(
          of: measurableCard,
          matching: find.text('On track'),
        ),
        findsOneWidget,
      );
      expect(
        find.text('This dimension is currently on track.'),
        findsNothing,
      );
      expect(find.text('Not enough data'), findsOneWidget);
      expect(find.text('Timing pattern · Late focus'), findsOneWidget);
      expect(
        find.textContaining('Most sessions start around 00:00'),
        findsOneWidget,
      );
      expect(find.text('00'), findsOneWidget);
      expect(find.text('24'), findsOneWidget);
    },
  );

  testWidgets('agent-recorded bars expose provenance and fallback tooltips', (
    tester,
  ) async {
    final firstDay = today.subtract(const Duration(days: 1));
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        GoalProgressCard(
          progress: GoalProgressView(
            today: today,
            metric: GoalMetricProgressView(
              name: 'Medication doses',
              target: 2,
              kind: GoalDimensionKind.measurable,
              days: [
                GoalProgressDay(day: firstDay, value: 1),
                GoalProgressDay(day: today, value: 2),
              ],
              agentRecordedDays: {firstDay, today},
              agentRecordedProvenanceByDay: {
                firstDay: GoalRecordedMeasurementProvenance(
                  agentName: 'Juno',
                  recordedAt: DateTime(2026, 8, 11, 9, 30),
                ),
              },
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(LottiIcons.editNote), findsNWidgets(2));
    final messages = tester
        .widgetList<Tooltip>(find.byType(Tooltip))
        .map((tooltip) => tooltip.message)
        .whereType<String>()
        .toList();
    expect(
      messages,
      contains('Said by you and recorded after your approval.'),
    );
    expect(messages.any((message) => message.contains('Juno')), isTrue);
  });

  testWidgets('the agent-recorded badge stays inside the plot on a short bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        GoalProgressCard(
          progress: GoalProgressView(
            today: today,
            metric: GoalMetricProgressView(
              name: 'Steps',
              target: 10000,
              days: [day(1, 400), day(0, 9000)],
              agentRecordedDays: {today.subtract(const Duration(days: 1))},
            ),
          ),
        ),
      ),
    );

    // A 400-step bar against a 10,000 ceiling is ~2px tall; the badge used
    // to escape above the plot and float over the card header. Clamped, it
    // rests on the baseline inside its own column instead.
    final slot = tester.getRect(
      find.byKey(const ValueKey('goal-metric-bar-2026-08-10')),
    );
    final icon = tester.getRect(find.byIcon(LottiIcons.editNote));
    expect(icon.top, greaterThanOrEqualTo(slot.top));
    expect(icon.bottom, lessThanOrEqualTo(slot.bottom));
  });

  testWidgets('the met-yesterday tally judges a per-day metric by the '
      "day's own value", (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        GoalThisWeekCard(
          progress: GoalProgressView(
            today: today,
            compositeRule: GoalCompositeRuleKind.all,
            metric: GoalMetricProgressView(
              name: 'Steps',
              target: 10000,
              // Yesterday beat the target on its own number while the
              // trailing-week verdict for that day still said short — the
              // tally must agree with the reflection sheet the strip opens,
              // which judges the day by its value.
              days: [
                GoalProgressDay(
                  day: today.subtract(const Duration(days: 1)),
                  value: 12400,
                  targetSatisfied: false,
                ),
                day(0, 2000),
              ],
            ),
          ),
        ),
      ),
    );

    expect(
      find.text('Yesterday: 1 of 1 dimensions · 1 required.'),
      findsOneWidget,
    );
  });

  testWidgets('extended day tracks scroll in unison — goal strip, habit '
      'squares and signal bars — and open at the recent end', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final group = LinkedScrollGroup();
    addTearDown(group.dispose);
    // Sixty days on a phone: far past the point where narrowing the columns
    // could still fit them, which is the only case that pans at all.
    const span = 60;
    final progress = GoalProgressView(
      today: today,
      compactWindowDays: span,
      compositeRule: GoalCompositeRuleKind.all,
      compositeCompactWindow: [
        for (var i = 0; i < span; i++)
          if (i.isEven) DayMarkState.full else DayMarkState.none,
      ],
      habits: [
        GoalHabitProgressView(
          habitId: 'gym',
          name: 'Gym',
          targetCount: 3,
          days: [
            for (var offset = span - 1; offset >= 0; offset--)
              day(offset, offset.isEven ? 1 : 0),
          ],
          successfulWeeks: 0,
        ),
      ],
      metric: GoalMetricProgressView(
        name: 'Steps',
        target: 10000,
        days: [
          for (var offset = span - 1; offset >= 0; offset--) day(offset, 8000),
        ],
      ),
    );
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        SingleChildScrollView(
          child: Column(
            children: [
              GoalThisWeekCard(
                progress: progress,
                onReflectDay: (_) {},
                scrollGroup: group,
              ),
              GoalProgressCard(progress: progress, scrollGroup: group),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The strip renders the WHOLE span, no seven-day cap.
    expect(
      find.descendant(
        of: find.byType(DayMarkStrip),
        matching: find.byType(InkWell),
      ),
      findsNWidgets(span),
    );

    // Every extended track is a trailing-anchored scroller: offset 0 means
    // today is on screen from the first frame.
    final scrollers = find.byWidgetPredicate(
      (widget) => widget is SingleChildScrollView && widget.reverse,
    );
    expect(scrollers, findsNWidgets(3));
    List<ScrollController> controllers() => [
      for (final element in scrollers.evaluate())
        (element.widget as SingleChildScrollView).controller!,
    ];
    for (final controller in controllers()) {
      expect(controller.offset, 0);
    }

    // Dragging ANY track moves every track — one gesture, one shared
    // horizontal position for the same date down the page.
    await tester.drag(scrollers.at(1), const Offset(120, 0));
    await tester.pump();
    final offsets = [for (final c in controllers()) c.offset];
    expect(offsets.first, greaterThan(0));
    for (final offset in offsets) {
      expect(offset, moreOrLessEquals(offsets.first, epsilon: 0.5));
    }
  });

  testWidgets('the trailing reading stacks its verdict beneath it, pinned to '
      'the card corner', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        GoalProgressCard(
          progress: GoalProgressView(
            today: today,
            habits: [
              GoalHabitProgressView(
                habitId: 'gym',
                name: 'Gym',
                targetCount: 3,
                days: [
                  for (var offset = 6; offset >= 0; offset--)
                    day(offset, offset < 3 ? 1 : 0),
                ],
                successfulWeeks: 2,
              ),
            ],
          ),
        ),
      ),
    );

    final tokens = tester.element(find.byType(GoalProgressCard)).designTokens;
    final reading = tester.getRect(find.text('3 of 3 · rolling 7 days'));
    final status = tester.getRect(find.text('On track'));
    final card = tester.getRect(find.byType(DesignSystemSectionCard).first);

    // Stacked typography: the key reading on top, the verdict as a
    // supporting line directly beneath it — never inline beside it.
    expect(status.top, greaterThanOrEqualTo(reading.bottom - 1));
    // One end-aligned corner element, FLUSH against the card's padding edge
    // — a loose Flexible used to park its unused allocation after the block
    // and leave it floating mid-row.
    expect(status.right, closeTo(reading.right, 1));
    expect(
      reading.right,
      closeTo(card.right - tokens.spacing.cardPadding, 1),
    );
  });

  group('the signal corner', () {
    Widget weightCard({String unit = 'kg'}) => SingleChildScrollView(
      child: GoalProgressCard(
        progress: GoalProgressView(
          today: today,
          metric: GoalMetricProgressView(
            criterionId: 'weight',
            sourceId: GoalHealthDataTypes.weight,
            name: 'Weight',
            target: 88,
            direction: GoalDirection.atMost,
            unitName: unit,
            days: [
              for (var offset = 13; offset >= 0; offset--)
                day(offset, 92 + offset * 0.1),
            ],
          ),
        ),
      ),
    );

    /// Pumps the signal card at [width]. The default is roomy — 420 logical
    /// pixels, wider than the old breakpoint and wider than any phone — so a
    /// layout chosen there is chosen because of what the reading MEASURES,
    /// never because the viewport ran out.
    Future<void> pumpCard(
      WidgetTester tester, {
      String unit = 'kg',
      double width = 420,
    }) async {
      tester.view
        ..physicalSize = const Size(1200, 900)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Center(
            child: SizedBox(
              width: width,
              child: weightCard(unit: unit),
            ),
          ),
        ),
      );
      // The signal chart's own date axis — four fixed ticks in a
      // space-between Row, in DashboardChartDateAxis — overflows here below
      // about 380 logical pixels. It is PRE-EXISTING and belongs to a shared
      // charting widget, not to this header: the same file's history shows it
      // untouched, and an in-app capture of this page at phone width renders
      // the axis clean, so it may well be particular to a card pumped bare in
      // a test. Taken so that a narrow pump reports on the header alone, and
      // tolerant of null so that fixing it upstream will not fail these
      // tests.
      tester.takeException();
    }

    // 'Weight' names the signal in the header AND its series in the legend.
    Rect titleRect(WidgetTester tester) =>
        tester.getRect(find.text('Weight').first);

    testWidgets('rides the title row whenever the reading actually fits — a '
        'card with room to spare never drops it to its own line', (
      tester,
    ) async {
      // Regression: the header picked its layout from a FIXED breakpoint
      // (step13 * 2 + step5, about 336 logical pixels), so a card with the
      // reading occupying well under a third of it still stacked the corner
      // block under the title and left-aligned it — losing the corner that
      // holds the one figure a reader looks for first.
      // A 390-wide phone leaves this card about 326 logical pixels — under
      // the old 336 threshold, so EVERY phone stacked the corner away. That
      // is the state that was reported.
      await pumpCard(tester, width: 326);

      final title = titleRect(tester);
      final reading = tester.getRect(find.text('92 kg'));
      final average = tester.getRect(find.textContaining('Ø'));
      final card = tester.getRect(find.byType(DesignSystemSectionCard).first);
      final tokens = tester.element(find.byType(GoalProgressCard)).designTokens;

      expect(
        reading.top,
        lessThan(title.bottom),
        reason: 'the reading shares the title row',
      );
      expect(reading.left, greaterThan(title.right));
      // Flush against the card's trailing padding edge — once the two figures
      // share a line the mean is the block's rightmost element.
      expect(
        average.right,
        closeTo(card.right - tokens.spacing.cardPadding, 1),
      );
      // And the block is genuinely narrow: proof the old breakpoint reserved
      // space nothing ever needed.
      expect(average.right - reading.left, lessThan(card.width / 2));
    });

    testWidgets('sets the mean beside the latest value on one baseline, with '
        'the verdict alone beneath', (tester) async {
      await pumpCard(tester);

      final reading = tester.getRect(find.text('92 kg'));
      final average = tester.getRect(find.textContaining('Ø'));
      final status = tester.getRect(find.text('Needs attention'));

      // One corner line, mean to the right of the value — not a second row.
      expect(average.left, greaterThan(reading.right));
      expect(
        average.bottom,
        closeTo(reading.bottom, reading.height),
        reason: 'the two figures share the corner line',
      );
      // Set on a shared BASELINE rather than a shared box bottom: the mean is
      // a smaller style, so bottom-aligning would sit it low by the
      // difference in descent.
      expect(
        average.bottom,
        lessThan(reading.bottom),
        reason: 'the smaller style ends above the larger one on a baseline',
      );
      // The verdict is the only thing on the second line, ending on the same
      // rail as the figures above it.
      expect(status.top, greaterThanOrEqualTo(reading.bottom - 1));
      expect(status.right, closeTo(average.right, 1));

      // Hierarchy: value largest and in the primary ink, mean a tier down and
      // wearing the average LINE's own hue.
      final tokens = tester.element(find.byType(GoalProgressCard)).designTokens;
      final valueStyle = tester.widget<Text>(find.text('92 kg')).style!;
      final meanStyle = tester.widget<Text>(find.textContaining('Ø')).style!;
      expect(valueStyle.fontSize, greaterThan(meanStyle.fontSize!));
      expect(valueStyle.color, isNot(tokens.colors.alert.info.defaultColor));
      expect(meanStyle.color, tokens.colors.alert.info.defaultColor);
    });

    testWidgets('a long reading folds the mean under the value before it '
        'surrenders the corner, and leaves the title row only when neither '
        'fits', (tester) async {
      // The card width never changes across these three pumps — only the
      // length of the reading does, which is the trigger the layout is meant
      // to answer to.
      await pumpCard(tester, unit: 'kilograms');
      var title = titleRect(tester);
      var reading = tester.getRect(find.text('92 kilograms'));
      var average = tester.getRect(find.textContaining('Ø'));
      expect(
        reading.top,
        lessThan(title.bottom),
        reason: 'too long to share a line, still short enough for a corner',
      );
      expect(
        average.top,
        greaterThanOrEqualTo(reading.bottom - 1),
        reason: 'so the mean folds onto its own line under the value',
      );
      expect(
        average.right,
        closeTo(reading.right, 1),
        reason: 'and the folded block stays end-aligned',
      );

      // Longer still: no corner left worth pinning to, so the block drops
      // below and starts on the card's own rail, left of the glyph-indented
      // identity.
      await pumpCard(tester, unit: 'kilograms per week');
      title = titleRect(tester);
      reading = tester.getRect(find.text('92 kilograms per week'));
      average = tester.getRect(find.textContaining('Ø'));
      expect(
        reading.top,
        greaterThanOrEqualTo(title.bottom - 1),
        reason: 'the block leaves the title row only when it must',
      );
      expect(reading.left, lessThan(title.left));
      // With the full card width back, the two figures fit side by side
      // again — the fall to a second line is never one-way.
      expect(average.left, greaterThan(reading.right));
      expect(
        average.bottom,
        lessThan(reading.bottom),
        reason: 'and they are still set on a shared baseline',
      );
    });
  });

  testWidgets('signal legends and summary lines center under their charts', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        SingleChildScrollView(
          child: GoalProgressCard(
            progress: GoalProgressView(
              today: today,
              habits: [
                GoalHabitProgressView(
                  habitId: 'gym',
                  name: 'Gym',
                  targetCount: 3,
                  days: [
                    for (var offset = 6; offset >= 0; offset--) day(offset, 0),
                  ],
                  successfulWeeks: 0,
                ),
              ],
              metric: GoalMetricProgressView(
                criterionId: 'content',
                name: 'Content Production',
                kind: GoalDimensionKind.labelTime,
                target: 200,
                unitName: 'min',
                days: [
                  day(2, 70),
                  day(1, 45),
                  GoalProgressDay(day: today, value: 0, isObserved: false),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // The chart legend on the signal card centers as card-level annotation.
    final chartLegend = tester.widget<DashboardChartLegend>(
      find.byType(DashboardChartLegend),
    );
    expect(chartLegend.alignment, WrapAlignment.center);
    // The centered legend is now the card's last row: the one-sentence
    // summary that used to close it only restated the header's status.
    expect(find.text('Behind target for this window.'), findsNothing);
    expect(find.text('Needs attention'), findsWidgets);
  });

  testWidgets('a wide card folds the deficit note onto the period line; a '
      'narrow card stacks it', (tester) async {
    tester.view
      ..physicalSize = const Size(1600, 800)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Widget card() => GoalProgressCard(
      progress: GoalProgressView(
        today: today,
        habits: [
          GoalHabitProgressView(
            habitId: 'gym',
            name: 'Gym',
            targetCount: 3,
            days: [
              for (var offset = 6; offset >= 0; offset--)
                day(offset, offset == 3 ? 1 : 0),
            ],
            successfulWeeks: 4,
          ),
        ],
      ),
    );

    await tester.pumpWidget(makeTestableWidgetNoScroll(card()));
    const periodText = 'Aug 5 – Aug 11';
    const noteText = '2 successful days needed to recover';
    final period = tester.getRect(find.text(periodText));
    final note = tester.getRect(find.text(noteText));
    expect(
      note.top,
      moreOrLessEquals(period.top, epsilon: 1),
      reason: 'with room, the note shares the period caption row',
    );
    expect(note.left, greaterThan(period.right));

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Center(child: SizedBox(width: 320, child: card())),
      ),
    );
    final stackedPeriod = tester.getRect(find.text(periodText));
    final stackedNote = tester.getRect(find.text(noteText));
    expect(
      stackedNote.bottom,
      lessThanOrEqualTo(stackedPeriod.top),
      reason: 'a narrow card keeps the note on its own line above the period',
    );
  });

  testWidgets('a reflect label too long to share the title row drops to its '
      'own line rather than overflowing it', (tester) async {
    addTearDown(tester.view.reset);

    Future<void> pump(double scale, double width) async {
      tester.view
        ..physicalSize = Size(width, 900)
        ..devicePixelRatio = 1.0;
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: GoalThisWeekCard(
              progress: GoalProgressView(
                today: today,
                compositeRule: GoalCompositeRuleKind.all,
                habits: [
                  GoalHabitProgressView(
                    habitId: 'gym',
                    name: 'Gym',
                    targetCount: 3,
                    days: [
                      for (var offset = 6; offset >= 0; offset--)
                        day(offset, 0),
                    ],
                    successfulWeeks: 0,
                  ),
                ],
              ),
              onReflectDay: (_) {},
            ),
          ),
          locale: const Locale('de'),
        ),
      );
    }

    // German renders the action as "Über den heutigen Tag nachdenken"; at a
    // raised text scale it is wider than a phone card on its own, and an
    // inflexible trailing child of a Row does not shrink — it overflows.
    await pump(1.6, 358);
    expect(tester.takeException(), isNull);
    final action = find.byKey(const ValueKey('goal-reflect-today'));
    final title = find.text('Zieltage').evaluate().isEmpty
        ? find.textContaining('Woche')
        : find.text('Zieltage');
    expect(
      tester.getTopLeft(action).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(title).dy),
      reason: 'the action moved below the title it could not sit beside',
    );
    // ...and it stays inside the card rather than being clipped by it, which
    // is what the overflow actually did.
    final card = tester.getRect(find.byType(GoalThisWeekCard));
    expect(tester.getTopRight(action).dx, lessThanOrEqualTo(card.right));
    expect(tester.getTopLeft(action).dx, greaterThanOrEqualTo(card.left));

    // Given the width for it, the pair still shares one row: the stack is a
    // fallback, not the new layout. (Same locale, same scale — only the
    // measurement changed, which is the point of measuring.)
    await pump(1.6, 1200);
    expect(tester.takeException(), isNull);
    expect(
      tester.getCenter(action).dy,
      closeTo(tester.getCenter(title).dy, 1),
    );
  });

  testWidgets('the reflect action is a quiet accent button that answers '
      'hover on its own ink', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        GoalThisWeekCard(
          progress: GoalProgressView(
            today: today,
            habits: [
              GoalHabitProgressView(
                habitId: 'gym',
                name: 'Gym',
                targetCount: 3,
                days: [
                  for (var offset = 6; offset >= 0; offset--) day(offset, 0),
                ],
                successfulWeeks: 0,
              ),
            ],
          ),
          onReflectDay: (_) {},
        ),
      ),
    );

    final tokens = tester.element(find.byType(GoalThisWeekCard)).designTokens;
    final button = tester.widget<DesignSystemButton>(
      find.byKey(const ValueKey('goal-reflect-today')),
    );
    // A caption-tier accent action, not a filled control: the card header is
    // a title row, and a solid button there would out-weigh the title.
    expect(button.variant, DesignSystemButtonVariant.tertiary);
    expect(button.size, DesignSystemButtonSize.dense);
    expect(button.leadingIcon, LottiIcons.editNote);
    // The chevron the full-width row wore is gone with the row.
    expect(find.byIcon(LottiIcons.chevronRight), findsNothing);

    // The label inherits its ink from the button's DefaultTextStyle, so the
    // resolved paint is the only honest read of the variant's state colour.
    Color labelColor() => tester
        .renderObject<RenderParagraph>(
          find.descendant(
            of: find.byKey(const ValueKey('goal-reflect-today')),
            matching: find.text('Reflect on today'),
          ),
        )
        .text
        .style!
        .color!;
    expect(labelColor(), tokens.colors.interactive.enabled);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer();
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.text('Reflect on today')));
    await tester.pump();
    expect(labelColor(), tokens.colors.interactive.hover);
    await gesture.moveTo(Offset.zero);
    await tester.pumpAndSettle();
  });

  testWidgets('strip day cells silence the hover overlay and answer hover '
      'with the styled day tooltip', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        GoalThisWeekCard(
          progress: GoalProgressView(
            today: today,
            habits: [
              GoalHabitProgressView(
                habitId: 'gym',
                name: 'Gym',
                targetCount: 3,
                days: [
                  for (var offset = 6; offset >= 0; offset--) day(offset, 0),
                ],
                successfulWeeks: 0,
              ),
            ],
          ),
          onReflectDay: (_) {},
        ),
      ),
    );

    final cells = find.descendant(
      of: find.byType(DayMarkStrip),
      matching: find.byType(InkWell),
    );
    final ink = tester.widget<InkWell>(cells.last);
    expect(ink.hoverColor, Colors.transparent);
    expect(
      ink.overlayColor?.resolve({WidgetState.hovered}),
      Colors.transparent,
    );

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer();
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(cells.last));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      find.textContaining('Tue, Aug 11\nNo entry', findRichText: true),
      findsOneWidget,
    );
    await gesture.moveTo(Offset.zero);
    await tester.pumpAndSettle();
  });
}
