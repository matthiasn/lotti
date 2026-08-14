import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/ds_segmented_toggle.dart';
import 'package:lotti/features/goals/model/goal_assessment.dart';
import 'package:lotti/features/goals/service/goal_assessment_service.dart';
import 'package:lotti/features/goals/state/goal_assessment_state.dart';
import 'package:lotti/features/goals/state/goal_progress_view.dart';
import 'package:lotti/features/goals/ui/goal_assessment_widgets.dart';
import 'package:mocktail/mocktail.dart';

import '../../../widget_test_utils.dart';

class _MockGoalAssessmentService extends Mock
    implements GoalAssessmentService {}

void main() {
  setUpAll(() {
    registerFallbackValue(GoalAssessmentRating.met);
    registerFallbackValue(GoalAssessmentProvenance.ratedByUser);
    registerFallbackValue(DateTime(2026));
  });

  final day = DateTime(2026, 8, 11);

  testWidgets('a failed assessment remains editable and can be retried', (
    tester,
  ) async {
    final service = _MockGoalAssessmentService();
    when(
      () => service.record(
        agentId: 'goal-1',
        day: day,
        specVersionId: 'goal-1:spec-v1',
        rating: GoalAssessmentRating.met,
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
        rating: GoalAssessmentRating.met,
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
          rating: GoalAssessmentRating.mixed,
          dimensionRatings: const {
            'walk': GoalAssessmentRating.missed,
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
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.byIcon(Icons.cancel_rounded), findsNWidgets(2));
      expect(find.byIcon(Icons.circle_outlined), findsOneWidget);

      tester
          .widget<DsSegmentedToggle<GoalAssessmentRating>>(
            find.byType(DsSegmentedToggle<GoalAssessmentRating>).first,
          )
          .onChanged(GoalAssessmentRating.mixed);
      await tester.pump();
      await tester.tap(find.text('Rate individual dimensions (optional)'));
      await tester.pumpAndSettle();
      final toggles = tester
          .widgetList<DsSegmentedToggle<GoalAssessmentRating>>(
            find.byType(DsSegmentedToggle<GoalAssessmentRating>),
          )
          .toList();
      toggles[1].onChanged(GoalAssessmentRating.missed);
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
          rating: GoalAssessmentRating.mixed,
          dimensionRatings: const {
            'walk': GoalAssessmentRating.missed,
          },
          note: 'Hard weather',
        ),
      ).called(1);
      expect(find.byType(GoalDayAssessmentSheet), findsNothing);
    },
  );

  testWidgets('history distinguishes every rating and provenance source', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        GoalAssessmentHistoryCard(
          progress: GoalProgressView(today: day),
          records: [
            GoalAssessmentRecord(
              id: 'met',
              day: day,
              specVersionId: 'spec-v2',
              rating: GoalAssessmentRating.met,
              createdAt: day,
              provenance: GoalAssessmentProvenance.ratedByUser,
            ),
            GoalAssessmentRecord(
              id: 'mixed',
              day: day.subtract(const Duration(days: 1)),
              specVersionId: 'spec-v2',
              rating: GoalAssessmentRating.mixed,
              createdAt: day,
              provenance: GoalAssessmentProvenance.suggestedAndAccepted,
              suggestedBy: 'Juno',
            ),
            GoalAssessmentRecord(
              id: 'missed',
              day: day.subtract(const Duration(days: 2)),
              specVersionId: 'spec-v2',
              rating: GoalAssessmentRating.missed,
              createdAt: day,
              provenance: GoalAssessmentProvenance.suggestedAndAccepted,
              suggestedBy: '   ',
            ),
          ],
        ),
      ),
    );

    expect(find.text('Daily reflections'), findsOneWidget);
    expect(find.text('Met'), findsOneWidget);
    expect(find.text('Mixed'), findsOneWidget);
    expect(find.text('Missed'), findsOneWidget);
    expect(find.text('Rated by you'), findsOneWidget);
    expect(find.textContaining('Juno suggested, you accepted'), findsOneWidget);
    expect(
      find.text('Your goal agent suggested, you accepted'),
      findsOneWidget,
    );
    expect(find.byType(Divider), findsNWidgets(2));
  });

  testWidgets('generic provenance wraps at large text on a phone', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: SingleChildScrollView(
            child: GoalAssessmentHistoryCard(
              progress: GoalProgressView(today: day),
              records: [
                GoalAssessmentRecord(
                  id: 'suggested',
                  day: day,
                  specVersionId: 'spec-v2',
                  rating: GoalAssessmentRating.met,
                  createdAt: day,
                  provenance: GoalAssessmentProvenance.suggestedAndAccepted,
                ),
              ],
            ),
          ),
        ),
        locale: const Locale('de'),
        mediaQueryData: const MediaQueryData(
          size: Size(390, 844),
          textScaler: TextScaler.linear(2),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final provenance = find.text(
      'Von deinem Ziel-Agenten vorgeschlagen, von dir angenommen',
    );
    expect(provenance, findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(provenance).height,
      // "Erreicht", not "Getroffen": the German label used to be the past
      // tense of meeting a *person*, which is not what a met goal criterion
      // is.
      greaterThan(tester.getSize(find.text('Erreicht')).height),
      reason: 'the long provenance copy must wrap instead of overflowing',
    );
  });

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
              rating: GoalAssessmentRating.missed,
              note: 'Travelled all day.',
              createdAt: DateTime.utc(2026, 8, 11, 21),
              provenance: GoalAssessmentProvenance.ratedByUser,
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
    final toggle = tester.widget<DsSegmentedToggle<GoalAssessmentRating>>(
      find.byType(DsSegmentedToggle<GoalAssessmentRating>).first,
    );
    expect(toggle.selected, GoalAssessmentRating.missed);
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

    final toggle = tester.widget<DsSegmentedToggle<GoalAssessmentRating>>(
      find.byType(DsSegmentedToggle<GoalAssessmentRating>).first,
    );
    expect(toggle.selected, GoalAssessmentRating.met);
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
    final toggle = tester.widget<DsSegmentedToggle<GoalAssessmentRating>>(
      find.byType(DsSegmentedToggle<GoalAssessmentRating>).first,
    );
    expect(toggle.selected, GoalAssessmentRating.missed);
    expect(
      find.text(
        'Suggested from what was measured — change it if you disagree.',
      ),
      findsOneWidget,
    );

    // Saving an untouched suggestion is an acceptance, and is recorded as one
    // — a provenance the history could already render but nothing produced.
    await tester.tap(
      find.widgetWithText(DesignSystemButton, 'Record for Tuesday'),
    );
    await tester.pumpAndSettle();
    verify(
      () => service.record(
        agentId: 'goal-1',
        day: day,
        specVersionId: 'goal-1:spec-v1',
        rating: GoalAssessmentRating.missed,
        dimensionRatings: any(named: 'dimensionRatings'),
        // ignore: avoid_redundant_argument_values
        note: null,
        provenance: GoalAssessmentProvenance.suggestedAndAccepted,
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
}
