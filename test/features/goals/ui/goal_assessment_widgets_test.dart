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
}
