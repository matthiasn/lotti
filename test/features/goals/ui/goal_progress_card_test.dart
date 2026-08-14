import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_line_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_multiline_chart.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/components/ds_dashed_border.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_window.dart';
import 'package:lotti/features/goals/model/goal_health_data_types.dart';
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
    await tester.tap(
      find.bySemanticsLabel(
        'Record for ${DateFormat.MMMEd().format(
          today.subtract(const Duration(days: 6)),
        )}',
      ),
    );
    await tester.tap(
      find.bySemanticsLabel(
        'Record for ${DateFormat.MMMEd().format(today)}',
      ),
    );

    expect(tapped, [today.subtract(const Duration(days: 6)), today]);
  });

  testWidgets('tappable day cells clear the touch floor and match the habit '
      'day squares, while a read-only strip stays compact', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        GoalProgressCard(
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
      expect(find.text('Systolic ≤ 125'), findsOneWidget);
      expect(find.text('Diastolic ≤ 85'), findsOneWidget);
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
      final charts = tester.widgetList<LineChart>(find.byType(LineChart));
      expect(charts, hasLength(2));
      expect(charts.first.data.lineBarsData.single.spots, hasLength(1));
      expect(charts.first.data.lineBarsData.single.dotData.show, isTrue);
      expect(charts.last.data.lineBarsData.single.spots, isEmpty);
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
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData, hasLength(2));
    expect(
      chart.data.lineBarsData.map((line) => line.spots),
      everyElement(isEmpty),
    );
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

  testWidgets('weight uses a line chart and omits missing samples', (
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
                day(2, 94.2),
                GoalProgressDay(
                  day: today.subtract(const Duration(days: 1)),
                  value: 0,
                  isObserved: false,
                ),
                day(0, 95),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(LineChart), findsOneWidget);
    expect(find.byType(FractionallySizedBox), findsNothing);
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData, hasLength(1));
    expect(chart.data.lineBarsData.single.spots.map((spot) => spot.y), [
      94.2,
      95,
    ]);
    expect(
      tester
          .widget<TimeSeriesLineChart>(find.byType(TimeSeriesLineChart))
          .dateOnly,
      isTrue,
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
              days: [day(1, 12400), day(0, 5262)],
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
      reason: '12,400 steps beat the 10,000 target',
    );
    expect(
      barColor('2026-08-11'),
      goalDayStateFill(tokens, GoalCompactDayState.none),
      reason: '5,262 steps fell short',
    );

    // Seven bars filling a full-width card rendered ~40px slabs. Each one is
    // now capped at the same width the scrollable variant uses.
    expect(
      tester
          .getSize(find.byKey(const ValueKey('goal-metric-bar-2026-08-11')))
          .width,
      lessThanOrEqualTo(ControlSizes.iconChipCompact),
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
    // Weekday labels and day cells share ONE horizontal scroller so they
    // cannot drift apart when the narrow grid scrolls.
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
    expect(menuButton.tooltip, 'Aug 8, 2026: No entry');
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
      tester.getTopLeft(cadence).dy,
      greaterThan(tester.getBottomLeft(name).dy),
      reason: 'the cadence remains attached to its named dimension',
    );
    expect(
      tester.getTopLeft(firstCell).dy,
      greaterThan(tester.getBottomLeft(cadence).dy),
      reason: 'the mobile grid follows the dimension metadata',
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

  testWidgets('composite summary and reflection preserve the authored rule', (
    tester,
  ) async {
    DateTime? reflectedDay;
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        SingleChildScrollView(
          child: GoalProgressCard(
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

    expect(find.text('The whole goal'), findsOneWidget);
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
}
