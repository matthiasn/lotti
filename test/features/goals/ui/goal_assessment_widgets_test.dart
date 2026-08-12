import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
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
  testWidgets('a failed assessment remains editable and can be retried', (
    tester,
  ) async {
    final service = _MockGoalAssessmentService();
    final day = DateTime(2026, 8, 11);
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
}
