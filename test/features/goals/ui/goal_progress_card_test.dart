import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_bar_line_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_line_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_multiline_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/utils.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/callouts/design_system_inline_callout.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu.dart';
import 'package:lotti/features/design_system/components/ds_dashed_border.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_window.dart';
import 'package:lotti/features/goals/model/goal_assessment.dart';
import 'package:lotti/features/goals/model/goal_health_data_types.dart';
import 'package:lotti/features/goals/state/goal_progress_view.dart';
import 'package:lotti/features/goals/ui/goal_progress_card.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/widgets/misc/linked_scroll_group.dart';

import '../../../widget_test_utils.dart';

void main() {
  final today = DateTime.utc(2026, 8, 11);
  GoalProgressDay day(int offset, num value) => GoalProgressDay(
    day: today.subtract(Duration(days: offset)),
    value: value,
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

    // ONE meta line states what the habit asks for and how its window moves —
    // the card used to carry a title, a caption AND a cadence line, all three
    // restating the same seven days.
    expect(find.text('3× per 7 days · slides at midnight'), findsOneWidget);
    expect(find.text('This rolling week'), findsNothing);
    expect(find.text('Gym'), findsOneWidget);
    expect(find.text('1 day to healthy'), findsOneWidget);
    expect(find.text('4 / 6 weeks'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    expect(find.text('done · target met'), findsOneWidget);
    expect(find.text('done · target not met yet'), findsOneWidget);
    expect(find.text('ages out tonight'), findsOneWidget);
    expect(find.text('today'), findsOneWidget);
  });

  testWidgets('an authored rolling window keeps its actual cadence label', (
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

    expect(find.text('4× · rolling 10 days'), findsOneWidget);
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

  testWidgets('compact strip reports the number of successful days once in '
      'semantics', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const GoalCompactWindowStrip(
          days: [
            GoalCompactDayState.full,
            GoalCompactDayState.none,
            GoalCompactDayState.partial,
            GoalCompactDayState.none,
            GoalCompactDayState.none,
            GoalCompactDayState.full,
            GoalCompactDayState.none,
          ],
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        '3 successful days in the trailing seven-day window',
      ),
      findsOneWidget,
    );
  });

  testWidgets('compact strip outlines the last cell as today when short', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const GoalCompactWindowStrip(
          days: [
            GoalCompactDayState.none,
            GoalCompactDayState.full,
            GoalCompactDayState.none,
          ],
        ),
      ),
    );

    expect(find.byType(DsDashedBorder), findsOneWidget);
  });

  testWidgets('a read-only strip announces its verdicts and marks non-met '
      'days with a shape', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        GoalCompactWindowStrip(
          days: List.filled(3, GoalCompactDayState.none),
          lastDay: today,
          ratingsByDay: {
            today.subtract(const Duration(days: 2)): GoalAssessmentRating.met,
            today.subtract(const Duration(days: 1)):
                GoalAssessmentRating.missed,
          },
        ),
      ),
    );

    // A read-only strip publishes one summary rather than seven nodes, so the
    // verdicts have to reach it there — otherwise the list announced a
    // measured day count while showing four verdict hues.
    final label = tester
        .getSemantics(find.byType(GoalCompactWindowStrip))
        .label;
    expect(label, contains('Met'));
    expect(label, contains('Missed'));

    // Each verdict keeps its OWN shape even on the list's 12px cells.
    // Collapsing the three non-met verdicts into one dot left Improving,
    // Mixed and Missed separable by hue alone, which is the single thing the
    // shapes exist to prevent.
    expect(
      find.byIcon(goalAssessmentRatingGlyph(GoalAssessmentRating.met)),
      findsOneWidget,
    );
    expect(
      find.byIcon(goalAssessmentRatingGlyph(GoalAssessmentRating.missed)),
      findsOneWidget,
    );
  });

  testWidgets('a tappable strip reports the day each cell stands for, '
      'counting back from the last', (tester) async {
    final tapped = <DateTime>[];
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        GoalCompactWindowStrip(
          days: const [
            GoalCompactDayState.full,
            GoalCompactDayState.none,
            GoalCompactDayState.partial,
            GoalCompactDayState.none,
            GoalCompactDayState.none,
            GoalCompactDayState.full,
            GoalCompactDayState.none,
          ],
          lastDay: today,
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
  });

  testWidgets('a recorded verdict outranks the measured state, and each '
      'verdict has its own colour', (tester) async {
    final week = List.filled(7, GoalCompactDayState.none);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        GoalCompactWindowStrip(
          days: week,
          lastDay: today,
          onDaySelected: (_) {},
          ratingsByDay: {
            today.subtract(const Duration(days: 3)): GoalAssessmentRating.met,
            today.subtract(const Duration(days: 2)):
                GoalAssessmentRating.improving,
            today.subtract(const Duration(days: 1)): GoalAssessmentRating.mixed,
            today: GoalAssessmentRating.missed,
          },
        ),
      ),
    );

    final tokens = tester
        .element(find.byType(GoalCompactWindowStrip))
        .designTokens;
    final cells = find.descendant(
      of: find.byType(GoalCompactWindowStrip),
      matching: find.byType(Container),
    );
    Color fillAt(int index) =>
        (tester.widget<Container>(cells.at(index)).decoration! as BoxDecoration)
            .color!;

    // Every measured day here is `none` — grey. The user's own verdict is what
    // decides the colour, because the measurement is evidence about a day and
    // the reflection is their ruling on it.
    expect(fillAt(0), goalDayStateFill(tokens, GoalCompactDayState.none));
    expect(
      fillAt(3),
      goalAssessmentRatingFill(tokens, GoalAssessmentRating.met),
    );
    expect(
      fillAt(4),
      goalAssessmentRatingFill(tokens, GoalAssessmentRating.improving),
    );
    expect(
      fillAt(5),
      goalAssessmentRatingFill(tokens, GoalAssessmentRating.mixed),
    );
    expect(
      fillAt(6),
      goalAssessmentRatingFill(tokens, GoalAssessmentRating.missed),
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
    for (final rating in GoalAssessmentRating.values) {
      expect(
        find.byIcon(goalAssessmentRatingGlyph(rating)),
        findsOneWidget,
        reason: '${rating.name} has no shape of its own',
      );
      // Two inks per verdict, for two backgrounds. On its own saturated fill
      // the glyph takes the on-alert ink; on a plain card — the reflect row —
      // it takes its family's ink, because the on-alert ink is near-invisible
      // there by design.
      expect(
        goalAssessmentRatingSurfaceInk(tokens, rating),
        isNot(goalAssessmentRatingInk(tokens, rating)),
        reason: '${rating.name} uses one ink for both surfaces',
      );
    }
    expect(
      {
        for (final rating in GoalAssessmentRating.values)
          goalAssessmentRatingGlyph(rating),
      },
      hasLength(GoalAssessmentRating.values.length),
      reason: 'two verdicts share a glyph',
    );

    // All four are distinguishable, and none of them is the grey of a day
    // nobody looked at — "I decided this was missed" and "no data" are
    // different facts and the strip has to be able to say which.
    final verdicts = {fillAt(3), fillAt(4), fillAt(5), fillAt(6)};
    expect(verdicts, hasLength(4));
    expect(
      verdicts,
      isNot(contains(goalDayStateFill(tokens, GoalCompactDayState.none))),
    );
  });

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

  testWidgets('the habit streak closes the card under the days it '
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

    // The six-week tail closes the card, under the days it summarises —
    // crammed onto the trailing edge of a heading three rows up it was one of
    // six figures competing for the same band, with nothing saying which
    // qualified which.
    final streak = find.text('4 / 6 weeks');
    expect(streak, findsOneWidget);
    final squares = find.byKey(
      ValueKey('goal-habit-day-visual-gym-${dayKey(0)}'),
    );
    expect(
      tester.getTopLeft(streak).dy,
      greaterThan(tester.getBottomLeft(squares).dy),
      reason: 'the streak must close the card, not ride a heading',
    );
    // ...and it reads left to right on the card's own rail, like every other
    // row, rather than right-ragged in a column of its own.
    expect(
      tester.getTopLeft(streak).dx,
      lessThan(tester.getCenter(find.byType(GoalProgressCard)).dx),
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
    // still the same seven days one card apart — the shared pitch remains
    // the contract.
    final progress = GoalProgressView(
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
      of: find.byType(GoalCompactWindowStrip),
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

  testWidgets('the reflect row sits with the week it closes off, and names '
      'the verdict once recorded', (tester) async {
    final tapped = <DateTime>[];
    Future<void> pump({GoalAssessmentRating? recorded}) => tester.pumpWidget(
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
    // Inside the whole-goal card, under the strip. Stranded at the bottom of
    // the page it was the quietest row on the surface, and nothing connected
    // it to the cells that open the same sheet.
    final strip = tester.getRect(find.byType(GoalCompactWindowStrip));
    final reflect = tester.getRect(find.text('Reflect on today'));
    expect(reflect.top, greaterThan(strip.top));
    expect(
      reflect.top - strip.bottom,
      lessThan(tester.getSize(find.byType(GoalThisWeekCard)).height / 4),
      reason: 'the reflect row drifted away from its strip',
    );

    await tester.tap(find.text('Reflect on today'));
    expect(tapped, [today]);

    // Once the day is judged the row states the verdict instead of inviting
    // an action the user already took.
    await pump(recorded: GoalAssessmentRating.improving);
    expect(find.text('Reflect on today'), findsNothing);
    expect(find.text('Improving'), findsOneWidget);
  });

  testWidgets('the day-cell legend rides inside the first habit card', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        GoalProgressCard(
          progress: GoalProgressView(
            today: today,
            habits: [
              for (final name in ['Gym', 'Read'])
                GoalHabitProgressView(
                  habitId: name,
                  name: name,
                  targetCount: 3,
                  days: [
                    for (var offset = 6; offset >= 0; offset--) day(offset, 0),
                  ],
                  successfulWeeks: 0,
                ),
            ],
          ),
        ),
      ),
    );

    // Once per goal, not once per habit — and inside the FIRST card, where a
    // reader meets the squares it explains. Attached to the last card it was
    // a key printed after everything it keys; on the page background between
    // two cards it read as annotating the chart below, which it does not
    // explain at all.
    expect(find.text('done · target met'), findsOneWidget);
    final legend = tester.getRect(find.text('done · target met'));
    final cards = find.byType(DesignSystemSectionCard);
    final firstHabitCard = tester.getRect(cards.first);
    expect(legend.top, greaterThan(firstHabitCard.top));
    expect(legend.bottom, lessThan(firstHabitCard.bottom));
    // ...and it precedes the second habit's squares rather than following
    // them.
    expect(
      legend.bottom,
      lessThan(tester.getRect(cards.at(1)).top),
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
    expect(find.byType(GoalCompactWindowStrip), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(GoalCompactWindowStrip),
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

  testWidgets('a read-only strip hugs its cells while a tappable one spans '
      'the measure', (tester) async {
    const week = [
      GoalCompactDayState.full,
      GoalCompactDayState.none,
      GoalCompactDayState.partial,
      GoalCompactDayState.none,
      GoalCompactDayState.none,
      GoalCompactDayState.full,
      GoalCompactDayState.none,
    ];
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        SizedBox(
          width: 400,
          child: Column(
            children: [
              const GoalCompactWindowStrip(days: week),
              GoalCompactWindowStrip(
                days: week,
                lastDay: today,
                onDaySelected: (_) {},
              ),
            ],
          ),
        ),
      ),
    );

    final cells = find.descendant(
      of: find.byType(GoalCompactWindowStrip).at(1),
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
      of: find.byType(GoalCompactWindowStrip).at(0),
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
        const GoalCompactWindowStrip(
          days: [
            GoalCompactDayState.none,
            GoalCompactDayState.none,
            GoalCompactDayState.none,
          ],
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
              child: GoalCompactWindowStrip(
                days: List.filled(dayCount, GoalCompactDayState.partial),
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
                  of: find.byType(GoalCompactWindowStrip),
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
      of: find.byType(GoalCompactWindowStrip),
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

    // The square itself matches the habit day squares below it — the whole
    // goal used to render at IconSizes.xs against their iconChipCompact,
    // less than half the size, on the same screen.
    final square = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(GoalCompactWindowStrip),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(
      square.constraints!.maxWidth,
      ControlSizes.iconChipCompact,
    );
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
    expect(find.text('done · target met'), findsNothing);
    expect(find.text('done · target not met yet'), findsNothing);
    expect(find.text('ages out tonight'), findsNothing);
    expect(find.text('today'), findsNothing);
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
    // "94.333 of 88 kg".
    expect(find.text('95 of 88 kg'), findsOneWidget);
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
        expect(
          find.text("Today's latest reading is on target; keep it going."),
          findsOneWidget,
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

        expect(find.text('88 of 88 kg'), findsOneWidget);
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

        expect(find.text('89 of 88 kg'), findsOneWidget);
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
      expect(find.text('Target ≤ 125'), findsOneWidget);
      expect(find.text('Target ≤ 85'), findsOneWidget);
      expect(find.text('Systolic · Target ≤ 125'), findsNothing);
      expect(find.text('Diastolic · Target ≤ 85'), findsNothing);
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
      expect(find.text('Target ≤ 125'), findsOneWidget);
      expect(find.text('Target ≤ 85'), findsOneWidget);
      expect(
        find.text("Today's latest reading is on target; keep it going."),
        findsOneWidget,
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
    expect(find.text('Target'), findsOneWidget);
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
      expect(find.text('Target'), findsOneWidget);
      expect(find.text('≥ 10,000'), findsOneWidget);
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
    final cadence = tester.getRect(
      find.text('7× per 7 days · slides at midnight'),
    );
    final period = tester.getRect(find.text('Jul 29 – Aug 11'));
    final lineChart = tester.getRect(find.byType(TimeSeriesMultiLineChart));

    // The habit card draws no plot, so it owes no y-axis gutter: its span
    // caption and its squares sit on the card's own rail with the cadence
    // line above them. Inset by a chart's axis width they started 52px right
    // of everything else on the card, keyed to a plot that is not there.
    expect(habitPlot.left, cadence.left);
    expect(period.left, cadence.left);
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
    expect(find.text('6 of 3 this window'), findsNothing);
    expect(find.text('6 this window · target 3'), findsOneWidget);
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
    expect(find.text('This dimension is currently on track.'), findsOneWidget);
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
    expect(find.text('This dimension is currently on track.'), findsOneWidget);
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
    expect(find.text('2× · calendar month'), findsOneWidget);
    expect(find.textContaining('/ 6'), findsNothing);
    // A month of days narrows its columns to fit rather than panning, so the
    // first of the month is on screen with the last.
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SingleChildScrollView &&
            widget.scrollDirection == Axis.horizontal,
      ),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('goal-habit-day-walk-2026-08-01')),
      findsOneWidget,
    );

    const todayKey = ValueKey('goal-habit-day-walk-2026-08-11');
    const finalDayKey = ValueKey('goal-habit-day-walk-2026-08-31');
    expect(
      find.descendant(
        of: find.byKey(todayKey),
        matching: find.byType(DsDashedBorder),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(finalDayKey),
        matching: find.byType(DsDashedBorder),
      ),
      findsNothing,
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
              // `targetSatisfied` deliberately contradicts each day's own
              // value: production always populates it with the evaluator's
              // ROLLING verdict, and this test exists to prove a per-day
              // target bar ignores that verdict in favour of the day's own
              // number. Without it, both days took the null-fallback branch
              // and the test passed against either policy.
              days: [
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
      goalDayStateFill(tokens, GoalCompactDayState.full),
      reason:
          '12,400 steps beat the 10,000 target even though the '
          'trailing-week verdict for that day says short',
    );
    // Short, but MEASURED. `background.level03` is what the legend calls
    // absence, so a logged day that fell short wears the muted wash of the
    // success family instead — three states, three fills.
    expect(
      barColor('2026-08-11'),
      goalDayStateFill(tokens, GoalCompactDayState.partial),
      reason:
          '5,262 steps fell short but were still logged — the passing '
          'rolling verdict must not paint the day green',
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
      ControlSizes.iconChipCompact,
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
    expect(find.text('Success'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Missed'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(DesignSystemContextMenu),
        matching: find.text('No entry'),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.byIcon(Icons.remove_rounded), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsOneWidget);
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
    expect(find.byIcon(Icons.remove_rounded), findsOneWidget);
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
    // Day states wear the success family — the interactive teal is
    // reserved for tappable controls.
    expect(
      (partialCell.decoration! as BoxDecoration).color,
      tokens.colors.alert.success.defaultColor.withValues(
        alpha: SurfaceAlphas.muted,
      ),
    );
    expect(
      (fullCell.decoration! as BoxDecoration).color,
      tokens.colors.alert.success.defaultColor,
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
    'the handoff-style weekday header uses full abbreviations and stays '
    'centered over a compact interactive grid',
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

      expect(find.text('Wed'), findsOneWidget);
      expect(find.text('W'), findsNothing);
      final tokens = tester.element(find.byType(GoalProgressCard)).designTokens;
      final expectedPitch = ControlSizes.iconChipCompact + tokens.spacing.step2;
      double? previousCenter;
      for (var offset = 6; offset >= 0; offset--) {
        final date = today
            .subtract(Duration(days: offset))
            .toIso8601String()
            .substring(0, 10);
        final marker = find.byKey(
          ValueKey('goal-habit-weekday-walk-$date'),
        );
        final cell = find.byKey(ValueKey('goal-habit-day-walk-$date'));
        final visualCell = find.byKey(
          ValueKey('goal-habit-day-visual-walk-$date'),
        );
        expect(
          tester.getSize(visualCell),
          const Size.square(ControlSizes.iconChipCompact),
        );
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
          tester.getCenter(marker).dx,
          closeTo(tester.getCenter(cell).dx, 0.01),
          reason: '$date marker must align with its interactive cell',
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
    'weekday labels expand their pitch as soon as scaled text needs it without '
    'losing '
    'cell alignment',
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
      final defaultPitch = ControlSizes.iconChipCompact + tokens.spacing.step2;
      Rect? previousLabelRect;
      double? previousCellCenter;
      for (var offset = 6; offset >= 0; offset--) {
        final date = today
            .subtract(Duration(days: offset))
            .toIso8601String()
            .substring(0, 10);
        final marker = find.byKey(
          ValueKey('goal-habit-weekday-walk-$date'),
        );
        final label = find.descendant(of: marker, matching: find.byType(Text));
        final cell = find.byKey(ValueKey('goal-habit-day-walk-$date'));
        final labelRect = tester.getRect(label);
        final cellCenter = tester.getCenter(cell).dx;
        expect(marker, findsOneWidget);
        expect(cell, findsOneWidget);
        if (previousLabelRect != null) {
          expect(
            previousLabelRect.right,
            lessThanOrEqualTo(labelRect.left),
            reason: 'scaled weekday labels must not overlap',
          );
        }
        if (previousCellCenter != null) {
          expect(
            cellCenter - previousCellCenter,
            greaterThan(defaultPitch),
            reason: 'only accessibility scaling should loosen the handoff grid',
          );
        }
        previousLabelRect = labelRect;
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
    final cadence = find.text('4× per 7 days · slides at midnight');
    final period = find.text('Aug 5 – Aug 11');
    final firstCell = find.byKey(
      const ValueKey('goal-habit-day-visual-gym-2026-08-05'),
    );

    // One meaning per row, top to bottom: what the habit is, what it asks
    // for, the span on screen, the days themselves, then the six-week tail.
    // Every one of these figures used to compete for the same band.
    expect(
      tester.getTopLeft(cadence).dy,
      greaterThan(tester.getBottomLeft(name).dy),
      reason: 'the cadence remains attached to its named dimension',
    );
    expect(
      tester.getTopLeft(period).dy,
      greaterThan(tester.getBottomLeft(cadence).dy),
      reason: 'the span labels the squares, so it sits above them',
    );
    expect(
      tester.getTopLeft(firstCell).dy,
      greaterThan(tester.getBottomLeft(period).dy),
      reason: 'the mobile grid follows the dimension metadata',
    );
    expect(
      tester.getTopLeft(streak).dy,
      greaterThan(tester.getBottomLeft(firstCell).dy),
      reason: 'the six-week tail closes the card',
    );
    // The span and the squares share one rail — the caption used to start a
    // chart gutter to their left, on a card that draws no chart.
    expect(
      tester.getTopLeft(period).dx,
      lessThanOrEqualTo(tester.getTopLeft(firstCell).dx),
    );
    expect(tester.getTopLeft(period).dx, tester.getTopLeft(cadence).dx);
  });

  testWidgets('the sliding-window caption survives a habit with no streak', (
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

    // The window's behaviour is part of the habit's cadence line, so nothing
    // can displace it: it used to compete with the streak for one slot and
    // vanish whenever a streak existed.
    expect(find.text('4× per 7 days · slides at midnight'), findsOneWidget);
    expect(find.textContaining('/ 6 weeks'), findsNothing);
  });

  testWidgets('a narrow authored cadence moves intact below the habit name', (
    tester,
  ) async {
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
                    name: 'A deliberately long habit name',
                    targetCount: 4,
                    window: const GoalWindow.rollingDays(count: 10),
                    days: [
                      for (var offset = 9; offset >= 0; offset--)
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

    final cadenceFinder = find.text('4× · rolling 10 days');
    final cadence = tester.widget<Text>(cadenceFinder);
    expect(cadence.maxLines, isNull);
    expect(cadence.overflow, isNot(TextOverflow.ellipsis));
    expect(
      tester.getTopLeft(cadenceFinder).dy,
      greaterThan(
        tester.getBottomLeft(find.text('A deliberately long habit name')).dy,
      ),
      reason: 'the full authored cadence gets its own row when space is tight',
    );
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
          ControlSizes.iconChipCompact +
              tester
                  .element(find.byType(GoalProgressCard))
                  .designTokens
                  .spacing
                  .step2,
          TapTargets.minimum,
        ),
      );
      expect(
        tester.getCenter(find.text('Walk')).dy,
        lessThan(
          tester.getCenter(find.text('1× per 7 days · slides at midnight')).dy,
        ),
        reason: 'the complete cadence moves below when the row cannot fit it',
      );
      final cadence = tester.widget<Text>(
        find.text('1× per 7 days · slides at midnight'),
      );
      expect(cadence.maxLines, isNull);
      expect(cadence.overflow, isNot(TextOverflow.ellipsis));

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
    },
  );

  testWidgets('a recorded miss is visibly distinct from an empty day', (
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
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
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
                GoalCompactDayState.none,
                GoalCompactDayState.full,
                GoalCompactDayState.none,
                GoalCompactDayState.full,
                GoalCompactDayState.full,
                GoalCompactDayState.none,
                GoalCompactDayState.full,
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
        find.descendant(
          of: measurableCard,
          matching: find.text('This dimension is currently on track.'),
        ),
        findsOneWidget,
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

    expect(find.byIcon(Icons.edit_note_rounded), findsNWidgets(2));
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
    final icon = tester.getRect(find.byIcon(Icons.edit_note_rounded));
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
          if (i.isEven) GoalCompactDayState.full else GoalCompactDayState.none,
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
        of: find.byType(GoalCompactWindowStrip),
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
}
