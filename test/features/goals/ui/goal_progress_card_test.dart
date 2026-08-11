import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/design_system/components/ds_dashed_border.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
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

  testWidgets('compact strip outlines the last cell as today when short', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const GoalCompactWindowStrip(days: [false, true, false]),
      ),
    );

    expect(find.byType(DsDashedBorder), findsOneWidget);
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

    expect(find.text('This rolling week'), findsNothing);
    expect(find.text('Aug 1 – Aug 31'), findsOneWidget);
    expect(find.text('2× · calendar month'), findsOneWidget);
    expect(find.textContaining('/ 6'), findsNothing);
    expect(find.byType(SingleChildScrollView), findsOneWidget);

    const todayKey = ValueKey('goal-habit-day-walk-2026-08-11');
    const finalDayKey = ValueKey('goal-habit-day-walk-2026-08-31');
    expect(
      find.descendant(
        of: find.byKey(todayKey),
        matching: find.byType(DsDashedBorder),
      ),
      findsOneWidget,
    );
    final futureButton = tester.widget<PopupMenuButton<HabitCompletionType>>(
      find.descendant(
        of: find.byKey(finalDayKey),
        matching: find.byType(PopupMenuButton<HabitCompletionType>),
      ),
    );
    expect(futureButton.enabled, isFalse);
    expect(
      find.descendant(
        of: find.byKey(finalDayKey),
        matching: find.byType(DsDashedBorder),
      ),
      findsNothing,
    );
    await tester.ensureVisible(find.byKey(finalDayKey));
    await tester.pumpAndSettle();
    expect(find.byKey(finalDayKey), findsOneWidget);
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

    final dayFinder = find.byKey(
      const ValueKey('goal-habit-day-walk-2026-08-08'),
    );
    final menuButton = tester.widget<PopupMenuButton<HabitCompletionType>>(
      find.descendant(
        of: dayFinder,
        matching: find.byType(PopupMenuButton<HabitCompletionType>),
      ),
    );
    expect(menuButton.position, PopupMenuPosition.under);
    expect(menuButton.menuPadding, EdgeInsets.zero);
    expect(menuButton.tooltip, isEmpty);
    expect(
      find.bySemanticsLabel('Aug 8, 2026: No entry'),
      findsOneWidget,
    );
    expect(menuButton.shape, isA<RoundedRectangleBorder>());
    expect(menuButton.constraints?.hasTightWidth, isTrue);

    await tester.tap(dayFinder);
    await tester.pumpAndSettle();
    expect(find.text('Success'), findsOneWidget);
    expect(find.text('Missed'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('goal-habit-day-missed')));
    await tester.pump();

    expect(selected?.habitId, 'walk');
    expect(selected?.day, DateTime.utc(2026, 8, 8));
    expect(selected?.outcome, HabitCompletionType.fail);
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
        expect(
          tester.getSize(cell),
          const Size.square(ControlSizes.iconChipCompact),
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
        expect(tester.getCenter(marker).dx, closeTo(cellCenter, 0.01));
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

    final context = tester.element(find.byType(GoalProgressCard));
    final spacing = context.designTokens.spacing;
    final title = find.text('This rolling week');
    final caption = find.text('slides at midnight');
    final name = find.text('Gym');
    final cadence = find.text('4× per 7 days');
    final firstCell = find.byKey(
      const ValueKey('goal-habit-day-visual-gym-2026-08-05'),
    );

    expect(
      tester.getCenter(title).dy,
      closeTo(tester.getCenter(caption).dy, 0.01),
      reason: 'the compact handoff keeps its card heading on one line',
    );
    expect(
      tester.getTopLeft(cadence).dx - tester.getTopRight(name).dx,
      closeTo(spacing.step2, 0.01),
      reason: 'cadence belongs to the habit name, not the status column',
    );
    expect(
      tester.getTopLeft(firstCell).dy - tester.getBottomLeft(name).dy,
      closeTo(spacing.step1, 0.01),
      reason: 'the mobile grid follows the handoff compact vertical rhythm',
    );
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
        const Size.square(ControlSizes.iconChipCompact),
      );
      expect(
        tester.getCenter(find.text('Walk')).dy,
        lessThan(tester.getCenter(find.text('1× per 7 days')).dy),
        reason: 'the complete cadence moves below when the row cannot fit it',
      );
      final cadence = tester.widget<Text>(find.text('1× per 7 days'));
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
    expect(
      tester
          .widget<PopupMenuButton<HabitCompletionType>>(
            find.descendant(
              of: find.byKey(dayKey),
              matching: find.byType(PopupMenuButton<HabitCompletionType>),
            ),
          )
          .enabled,
      isFalse,
    );

    completion.complete(true);
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
