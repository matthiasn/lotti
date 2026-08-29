import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/ds_segmented_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/model/goal_assessment.dart';
import 'package:lotti/features/goals/model/goal_health_data_types.dart';
import 'package:lotti/features/goals/service/goal_assessment_service.dart';
import 'package:lotti/features/goals/state/goal_assessment_state.dart';
import 'package:lotti/features/goals/state/goal_progress_view.dart';
import 'package:lotti/features/goals/ui/goal_assessment_widgets.dart';
import 'package:lotti/widgets/day_indicators/day_mark.dart';
import 'package:mocktail/mocktail.dart';

import '../../../widget_test_utils.dart';

class _MockGoalAssessmentService extends Mock
    implements GoalAssessmentService {}

void main() {
  setUpAll(() {
    registerFallbackValue(DayVerdict.met);
    registerFallbackValue(DayVerdictProvenance.ratedByUser);
    registerFallbackValue(DateTime(2026));
  });

  final day = DateTime(2026, 8, 11);

  testWidgets('a step count is named as one day, beside the average the goal '
      'is judged on', (tester) async {
    final today = DateTime(2026, 8, 15);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: SingleChildScrollView(
            child: GoalDayAssessmentSheet(
              agentId: 'goal-1',
              specVersionId: 'goal-1:spec-v1',
              specVersion: 1,
              day: today,
              progress: GoalProgressView(
                today: today,
                metric: GoalMetricProgressView(
                  criterionId: 'steps',
                  sourceId: GoalHealthDataTypes.steps,
                  // The criterion is authored as an average because that is
                  // what it evaluates over a week.
                  name: 'Average steps per day',
                  target: 10000,
                  days: [
                    for (var offset = 7; offset >= 1; offset--)
                      GoalProgressDay(
                        day: today.subtract(Duration(days: offset)),
                        value: 10000,
                      ),
                    GoalProgressDay(day: today, value: 9950),
                  ],
                ),
              ),
            ),
          ),
        ),
        overrides: [
          goalAssessmentServiceProvider.overrideWithValue(
            _MockGoalAssessmentService(),
          ),
        ],
      ),
    );

    // 9,950 is what the user WALKED that day. Printing it under "Average
    // steps per day" stated something false about the number beside it.
    expect(find.text('Steps'), findsOneWidget);
    expect(find.text('Average steps per day'), findsNothing);
    expect(find.text('9,950'), findsOneWidget);
    // ...and the average the target is actually compared against, ending that
    // day, on its own correctly named line.
    expect(find.text('Steps · 7-day average'), findsOneWidget);
    // Quantized the way every other goal aggregate is — but never across the
    // target it is compared against: 9,992.86 must not print as the 10,000 it
    // has not reached.
    expect(find.text('9,993'), findsOneWidget);
  });

  testWidgets('a derived average is evidence, not a criterion to rate', (
    tester,
  ) async {
    final today = DateTime(2026, 8, 15);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: SingleChildScrollView(
            child: GoalDayAssessmentSheet(
              agentId: 'goal-1',
              specVersionId: 'goal-1:spec-v1',
              specVersion: 1,
              day: today,
              progress: GoalProgressView(
                today: today,
                metric: GoalMetricProgressView(
                  criterionId: 'steps',
                  sourceId: GoalHealthDataTypes.steps,
                  name: 'Average steps per day',
                  target: 10000,
                  days: [
                    for (var offset = 7; offset >= 0; offset--)
                      GoalProgressDay(
                        day: today.subtract(Duration(days: offset)),
                        value: 10000,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        overrides: [
          goalAssessmentServiceProvider.overrideWithValue(
            _MockGoalAssessmentService(),
          ),
        ],
      ),
    );

    await tester.tap(find.text('Rate individual dimensions (optional)'));
    await tester.pumpAndSettle();

    // One verdict control, for the one criterion. A toggle against the
    // derived average would file a judgement under a criterion id the row
    // above it already owns.
    expect(find.text('Steps · 7-day average'), findsOneWidget);
    expect(
      find.byType(DsSegmentedToggle<DayVerdict>),
      // The day's own verdict plus exactly one per-dimension control.
      findsNWidgets(2),
    );
  });

  testWidgets('an expanded dimension row gives its label the full measure', (
    tester,
  ) async {
    final today = DateTime(2026, 8, 15);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Center(
          child: SizedBox(
            width: 390,
            child: Scaffold(
              body: SingleChildScrollView(
                child: GoalDayAssessmentSheet(
                  agentId: 'goal-1',
                  specVersionId: 'goal-1:spec-v1',
                  specVersion: 1,
                  day: today,
                  progress: GoalProgressView(
                    today: today,
                    habits: [
                      GoalHabitProgressView(
                        habitId: 'bp',
                        criterionId: 'bp',
                        name: 'Measure Blood Pressure 🫀',
                        targetCount: 1,
                        days: [GoalProgressDay(day: today, value: 1)],
                        successfulWeeks: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        overrides: [
          goalAssessmentServiceProvider.overrideWithValue(
            _MockGoalAssessmentService(),
          ),
        ],
      ),
    );

    await tester.tap(find.text('Rate individual dimensions (optional)'));
    await tester.pumpAndSettle();

    final label = find.text('Measure Blood Pressure 🫀').last;
    final toggle = find.byType(DsSegmentedToggle<DayVerdict>).last;
    final labelRect = tester.getRect(label);
    final toggleRect = tester.getRect(toggle);

    // The toggle used to claim a fixed 480px — wider than the sheet — which
    // starved the label's Expanded to zero width and rendered the name as a
    // vertical column of single letters with the control painted across it.
    expect(labelRect.width, greaterThan(100));
    expect(labelRect.height, lessThan(40), reason: 'one line, not one column');
    expect(
      toggleRect.top,
      greaterThanOrEqualTo(labelRect.bottom),
      reason: 'the control sits below its label, never over it',
    );
    expect(toggleRect.width, lessThanOrEqualTo(390));
  });

  testWidgets('a failed assessment remains editable and can be retried', (
    tester,
  ) async {
    final service = _MockGoalAssessmentService();
    when(
      () => service.record(
        agentId: 'goal-1',
        day: day,
        specVersionId: 'goal-1:spec-v1',
        rating: DayVerdict.met,
        dimensionRatings: const {},
        note: 'Felt manageable',
      ),
    ).thenThrow(StateError('offline'));
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: GoalDayAssessmentSheet(
            agentId: 'goal-1',
            specVersionId: 'goal-1:spec-v1',
            specVersion: 1,
            day: day,
            progress: GoalProgressView(today: day),
          ),
        ),
        overrides: [
          goalAssessmentServiceProvider.overrideWithValue(service),
        ],
      ),
    );
    await tester.enterText(find.byType(EditableText), 'Felt manageable');

    await tester.tap(
      find.widgetWithText(DesignSystemButton, 'Record for Tuesday'),
    );
    await tester.pump();

    expect(find.text("That didn't save — please try again."), findsOneWidget);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'Felt manageable',
    );
    final retry = tester.widget<DesignSystemButton>(
      find.widgetWithText(DesignSystemButton, 'Record for Tuesday'),
    );
    expect(retry.isLoading, isFalse);
    expect(retry.onPressed, isNotNull);
    verify(
      () => service.record(
        agentId: 'goal-1',
        day: day,
        specVersionId: 'goal-1:spec-v1',
        rating: DayVerdict.met,
        dimensionRatings: const {},
        note: 'Felt manageable',
      ),
    ).called(1);
  });

  testWidgets(
    'records the overall rating, per-dimension overrides, and measured facts',
    (tester) async {
      final service = _MockGoalAssessmentService();
      when(
        () => service.record(
          agentId: 'goal-1',
          day: day,
          specVersionId: 'goal-1:spec-v2',
          rating: DayVerdict.mixed,
          dimensionRatings: const {
            'walk': DayVerdict.missed,
          },
          note: 'Hard weather',
        ),
      ).thenAnswer((_) async => 'assessment-1');
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(
            body: GoalDayAssessmentSheet(
              agentId: 'goal-1',
              specVersionId: 'goal-1:spec-v2',
              specVersion: 2,
              day: day,
              progress: GoalProgressView(
                today: day,
                habits: [
                  GoalHabitProgressView(
                    habitId: 'walk',
                    criterionId: 'walk',
                    name: 'Morning walk',
                    targetCount: 1,
                    days: [GoalProgressDay(day: day, value: 1)],
                    successfulWeeks: 1,
                  ),
                  GoalHabitProgressView(
                    habitId: 'journal',
                    criterionId: 'journal',
                    name: 'Journal',
                    targetCount: 1,
                    days: [GoalProgressDay(day: day, value: 0)],
                    successfulWeeks: 0,
                  ),
                ],
                metrics: [
                  GoalMetricProgressView(
                    criterionId: 'weight',
                    name: 'Weight',
                    target: 80,
                    days: [GoalProgressDay(day: day, value: 79.5)],
                  ),
                  GoalMetricProgressView(
                    criterionId: 'pressure',
                    name: 'Systolic pressure',
                    target: 120,
                    direction: GoalDirection.atMost,
                    days: [
                      GoalProgressDay(
                        day: day,
                        value: 0,
                        isObserved: false,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          overrides: [
            goalAssessmentServiceProvider.overrideWithValue(service),
          ],
        ),
      );

      expect(find.text('Morning walk'), findsOneWidget);
      expect(find.text('Recorded'), findsOneWidget);
      expect(find.text('Journal'), findsOneWidget);
      expect(find.text('Not recorded'), findsOneWidget);
      expect(find.text('Weight'), findsOneWidget);
      expect(find.text('79.5'), findsOneWidget);
      expect(find.text('Systolic pressure'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
      expect(find.byIcon(LottiIcons.confirmCircled), findsOneWidget);
      expect(find.byIcon(LottiIcons.closeCircled), findsNWidgets(2));
      expect(find.byIcon(LottiIcons.radioUnselected), findsOneWidget);

      tester
          .widget<DsSegmentedToggle<DayVerdict>>(
            find.byType(DsSegmentedToggle<DayVerdict>).first,
          )
          .onChanged(DayVerdict.mixed);
      await tester.pump();
      await tester.tap(find.text('Rate individual dimensions (optional)'));
      await tester.pumpAndSettle();
      final toggles = tester
          .widgetList<DsSegmentedToggle<DayVerdict>>(
            find.byType(DsSegmentedToggle<DayVerdict>),
          )
          .toList();
      toggles[1].onChanged(DayVerdict.missed);
      await tester.enterText(find.byType(EditableText), '  Hard weather  ');
      final recordButton = find.widgetWithText(
        DesignSystemButton,
        'Record for Tuesday',
      );
      await tester.ensureVisible(recordButton);
      await tester.tap(recordButton);
      await tester.pumpAndSettle();

      verify(
        () => service.record(
          agentId: 'goal-1',
          day: day,
          specVersionId: 'goal-1:spec-v2',
          rating: DayVerdict.mixed,
          dimensionRatings: const {
            'walk': DayVerdict.missed,
          },
          note: 'Hard weather',
        ),
      ).called(1);
      expect(find.byType(GoalDayAssessmentSheet), findsNothing);
    },
  );

  // The reflection-history card is gone: reflections render as tight single
  // rows in the check-ins rail (covered by goal_checkin_timeline_test.dart),
  // and the "Rated by you" / "suggested, you accepted" attribution went with
  // it — provenance stays on the record, it is not day-to-day reading.

  testWidgets('reopening a judged day arrives showing what was recorded', (
    tester,
  ) async {
    final day = DateTime.utc(2026, 8, 11);
    final service = _MockGoalAssessmentService();
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: GoalDayAssessmentSheet(
            agentId: 'goal-1',
            specVersionId: 'goal-1:spec-v1',
            specVersion: 1,
            day: day,
            progress: GoalProgressView(today: day),
            existing: GoalAssessmentRecord(
              id: 'record-1',
              day: day,
              specVersionId: 'goal-1:spec-v1',
              rating: DayVerdict.missed,
              note: 'Travelled all day.',
              createdAt: DateTime.utc(2026, 8, 11, 21),
              provenance: DayVerdictProvenance.ratedByUser,
            ),
          ),
        ),
        overrides: [
          goalAssessmentServiceProvider.overrideWithValue(service),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // Every day in the strip can be reopened. Arriving blank offered Met with
    // an empty note, and saving replaced the real reflection with that
    // default — losing the note and the per-dimension verdicts with it.
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'Travelled all day.',
    );
    final toggle = tester.widget<DsSegmentedToggle<DayVerdict>>(
      find.byType(DsSegmentedToggle<DayVerdict>).first,
    );
    expect(toggle.selected, DayVerdict.missed);
  });

  testWidgets('a day with no reflection yet still opens on Met', (
    tester,
  ) async {
    final day = DateTime.utc(2026, 8, 11);
    final service = _MockGoalAssessmentService();
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: GoalDayAssessmentSheet(
            agentId: 'goal-1',
            specVersionId: 'goal-1:spec-v1',
            specVersion: 1,
            day: day,
            progress: GoalProgressView(today: day),
          ),
        ),
        overrides: [
          goalAssessmentServiceProvider.overrideWithValue(service),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final toggle = tester.widget<DsSegmentedToggle<DayVerdict>>(
      find.byType(DsSegmentedToggle<DayVerdict>).first,
    );
    expect(toggle.selected, DayVerdict.met);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      isEmpty,
    );
  });

  testWidgets('every verdict is offered, derived from the enum', (
    tester,
  ) async {
    final day = DateTime.utc(2026, 8, 11);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: GoalDayAssessmentSheet(
            agentId: 'goal-1',
            specVersionId: 'goal-1:spec-v1',
            specVersion: 1,
            day: day,
            progress: GoalProgressView(today: day),
          ),
        ),
        overrides: [
          goalAssessmentServiceProvider.overrideWithValue(
            _MockGoalAssessmentService(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // Hand-listing the segments is how a fourth verdict ends up offered on
    // one toggle and missing from the other.
    for (final verdict in ['Met', 'Improving', 'Mixed', 'Missed']) {
      expect(find.text(verdict), findsWidgets, reason: verdict);
    }
  });

  testWidgets('a fresh reflection opens on what the evidence suggests', (
    tester,
  ) async {
    final day = DateTime.utc(2026, 8, 11);
    final service = _MockGoalAssessmentService();
    when(
      () => service.record(
        agentId: any(named: 'agentId'),
        day: any(named: 'day'),
        specVersionId: any(named: 'specVersionId'),
        rating: any(named: 'rating'),
        dimensionRatings: any(named: 'dimensionRatings'),
        note: any(named: 'note'),
        provenance: any(named: 'provenance'),
      ),
    ).thenAnswer((_) async => 'record-1');

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: GoalDayAssessmentSheet(
            agentId: 'goal-1',
            specVersionId: 'goal-1:spec-v1',
            specVersion: 1,
            day: day,
            progress: GoalProgressView(
              today: day,
              habits: [
                GoalHabitProgressView(
                  habitId: 'gym',
                  name: 'Gym',
                  targetCount: 7,
                  days: [GoalProgressDay(day: day, value: 0)],
                  successfulWeeks: 0,
                ),
              ],
              metrics: [
                GoalMetricProgressView(
                  name: 'Steps',
                  target: 10000,
                  days: [GoalProgressDay(day: day, value: 3000)],
                ),
              ],
            ),
          ),
        ),
        overrides: [
          goalAssessmentServiceProvider.overrideWithValue(service),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // Everything was logged and nothing met its target. Opening on Met — as
    // it always did — contradicted the numbers printed directly above.
    final toggle = tester.widget<DsSegmentedToggle<DayVerdict>>(
      find.byType(DsSegmentedToggle<DayVerdict>).first,
    );
    expect(toggle.selected, DayVerdict.missed);
    expect(
      find.text(
        'Suggested from what was measured — change it if you disagree.',
      ),
      findsOneWidget,
    );

    // Saving an untouched suggestion is an acceptance, and is recorded as one
    // — a provenance the history could already render but nothing produced.
    final record = find.widgetWithText(
      DesignSystemButton,
      'Record for Tuesday',
    );
    await tester.ensureVisible(record);
    await tester.pumpAndSettle();
    await tester.tap(record);
    await tester.pumpAndSettle();
    verify(
      () => service.record(
        agentId: 'goal-1',
        day: day,
        specVersionId: 'goal-1:spec-v1',
        rating: DayVerdict.missed,
        dimensionRatings: any(named: 'dimensionRatings'),
        // ignore: avoid_redundant_argument_values
        note: null,
        provenance: DayVerdictProvenance.suggestedAndAccepted,
      ),
    ).called(1);
  });

  testWidgets('changing the verdict drops the suggestion hint and its '
      'provenance', (tester) async {
    final day = DateTime.utc(2026, 8, 11);
    final service = _MockGoalAssessmentService();
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: GoalDayAssessmentSheet(
            agentId: 'goal-1',
            specVersionId: 'goal-1:spec-v1',
            specVersion: 1,
            day: day,
            progress: GoalProgressView(
              today: day,
              metrics: [
                GoalMetricProgressView(
                  name: 'Steps',
                  target: 10000,
                  days: [GoalProgressDay(day: day, value: 3000)],
                ),
              ],
            ),
          ),
        ),
        overrides: [
          goalAssessmentServiceProvider.overrideWithValue(service),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Suggested from what was measured — change it if you disagree.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Met').first);
    await tester.pumpAndSettle();

    // Once the user has moved off it, saying where the old value came from is
    // noise — and the save is no longer an acceptance of anything.
    expect(
      find.text(
        'Suggested from what was measured — change it if you disagree.',
      ),
      findsNothing,
    );
  });

  testWidgets('choosing the suggested verdict deliberately is not an '
      'acceptance', (tester) async {
    final day = DateTime.utc(2026, 8, 11);
    final service = _MockGoalAssessmentService();
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: GoalDayAssessmentSheet(
            agentId: 'goal-1',
            specVersionId: 'goal-1:spec-v1',
            specVersion: 1,
            day: day,
            progress: GoalProgressView(
              today: day,
              metrics: [
                GoalMetricProgressView(
                  name: 'Steps',
                  target: 10000,
                  days: [GoalProgressDay(day: day, value: 3000)],
                ),
              ],
            ),
          ),
        ),
        overrides: [
          goalAssessmentServiceProvider.overrideWithValue(service),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // The same verdict the app suggested — but chosen, not left standing.
    // Comparing values alone cannot tell those apart, and filing an active
    // choice as "suggested and accepted" credits the agent for the user's
    // own call.
    tester
        .widget<DsSegmentedToggle<DayVerdict>>(
          find.byType(DsSegmentedToggle<DayVerdict>).first,
        )
        .onChanged(DayVerdict.missed);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Suggested from what was measured — change it if you disagree.',
      ),
      findsNothing,
    );
  });
}
