import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/design_system/theme/sizing_tokens.dart';
import 'package:lotti/features/goals/state/goal_progress_view.dart';
import 'package:lotti/features/goals/ui/goal_progress_card.dart';
import 'package:lotti/l10n/app_localizations.dart';

import '../../../widget_test_utils.dart';

void main() {
  final today = DateTime.utc(2026, 8, 11);
  GoalProgressDay day(int offset, num value) => GoalProgressDay(
    day: today.subtract(Duration(days: offset)),
    value: value,
  );

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

    expect(find.text('This rolling week'), findsOneWidget);
    expect(find.text('trailing 7 days · slides at midnight'), findsOneWidget);
    expect(find.text('Gym'), findsOneWidget);
    expect(find.text('3× per 7 days'), findsOneWidget);
    expect(find.text('1 day to healthy'), findsOneWidget);
    expect(find.text('4 / 6'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    expect(find.text('done'), findsOneWidget);
    expect(find.text('ages out tonight'), findsOneWidget);
    expect(find.text('today'), findsOneWidget);
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
          days: [true, false, true, false, false, true, false],
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
    expect(find.text('done'), findsNothing);
    expect(find.text('ages out tonight'), findsNothing);
    expect(find.text('today'), findsNothing);
  });

  testWidgets('mixed composite renders habit and every metric series', (
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
    );

    expect(find.text('Walk'), findsOneWidget);
    expect(find.text('Steps'), findsOneWidget);
    expect(find.text('Sleep'), findsOneWidget);
    expect(find.byType(FractionallySizedBox), findsNWidgets(14));
  });

  testWidgets('a calendar-month metric shows its actual period and scrolls '
      'all daily bars', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        GoalProgressCard(
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
    );

    expect(find.text('This rolling week'), findsNothing);
    expect(find.text('Aug 1 – Aug 31'), findsOneWidget);
    expect(find.byType(FractionallySizedBox), findsNWidgets(31));
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });

  testWidgets('a calendar-month habit shows and scrolls its authored period', (
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
        ),
      ),
    );

    expect(find.text('This rolling week'), findsNothing);
    expect(find.text('Aug 1 – Aug 31'), findsOneWidget);
    expect(find.text('2× · calendar month'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
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

  testWidgets('a narrow at-rate habit keeps the grid scrollable and marks both '
      'the aging success and today', (tester) async {
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

    expect(find.text('at rate'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
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

    await tester.tap(
      find.byKey(const ValueKey('goal-habit-day-walk-2026-08-08')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Success'), findsOneWidget);
    expect(find.text('Missed'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('goal-habit-day-missed')));
    await tester.pump();

    expect(selected?.habitId, 'walk');
    expect(selected?.day, DateTime.utc(2026, 8, 8));
    expect(selected?.outcome, HabitCompletionType.fail);
  });

  testWidgets(
    'habit day has a full tap target and ignores its current outcome',
    (
      tester,
    ) async {
      final outcomes = <HabitCompletionType>[];
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
                    for (var offset = 6; offset > 0; offset--) day(offset, 0),
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
                ({required day, required habitId, required outcome}) async {
                  outcomes.add(outcome);
                  return true;
                },
          ),
        ),
      );

      const dayKey = ValueKey('goal-habit-day-walk-2026-08-11');
      expect(tester.getSize(find.byKey(dayKey)).width, TapTargets.minimum);
      expect(tester.getSize(find.byKey(dayKey)).height, TapTargets.minimum);

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
    expect(
      tester
          .widget<PopupMenuButton<HabitCompletionType>>(
            find.descendant(
              of: find.byKey(dayKey),
              matching: find.byType(PopupMenuButton<HabitCompletionType>),
            ),
          )
          .enabled,
      isTrue,
    );
  });
}
