import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/task_summary_controller.dart';
import 'package:lotti/features/ai/ui/animation/ai_running_animation.dart';
import 'package:lotti/features/ai/ui/task_summary/ai_task_summary_view.dart';
import 'package:lotti/themes/theme.dart';

// Mock controller for TaskSummaryController
class MockTaskSummaryController extends TaskSummaryController {
  MockTaskSummaryController(this.mockState);
  final String mockState;

  @override
  String build({required String id}) {
    return mockState;
  }

  @override
  Future<void> getTaskSummary() async {
    // Do nothing in mock
  }
}

// Mock controller for InferenceStatusController (can be reused or defined locally if preferred)
class MockInferenceStatusController extends InferenceStatusController {
  MockInferenceStatusController(this.mockStatus);
  final InferenceStatus mockStatus;

  @override
  InferenceStatus build({
    required String id,
    required AiResponseType aiResponseType,
  }) {
    return mockStatus;
  }

  @override
  void setStatus(InferenceStatus newStatus) {
    // Do nothing in mock
  }
}

void main() {
  group('AiTaskSummaryView', () {
    const testId = 'test-task-id';

    testWidgets(
        'displays normal summary with standard style when not in error state',
        (tester) async {
      // Arrange
      final container = ProviderContainer(
        overrides: [
          taskSummaryControllerProvider(id: testId).overrideWith(
            () => MockTaskSummaryController('This is a normal summary.'),
          ),
          inferenceStatusControllerProvider(
            id: testId,
            aiResponseType: AiResponseType.taskSummary,
          ).overrideWith(
            () => MockInferenceStatusController(InferenceStatus.idle),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: AiTaskSummaryView(id: testId),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.text('This is a normal summary.'), findsOneWidget);
      final textWidget =
          tester.widget<Text>(find.text('This is a normal summary.'));
      expect(textWidget.style?.color, isNot(Colors.red));
      expect(textWidget.style?.fontSize, monospaceTextStyleSmall.fontSize);
      expect(find.byType(AiRunningAnimationWrapper), findsNothing);
    });

    testWidgets('displays error message with error style when in error state',
        (tester) async {
      // Arrange
      const errorMessage = 'Summary Error: Budget low.';
      final container = ProviderContainer(
        overrides: [
          taskSummaryControllerProvider(id: testId)
              .overrideWith(() => MockTaskSummaryController(errorMessage)),
          inferenceStatusControllerProvider(
            id: testId,
            aiResponseType: AiResponseType.taskSummary,
          ).overrideWith(
            () => MockInferenceStatusController(InferenceStatus.error),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: AiTaskSummaryView(id: testId),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.text(errorMessage), findsOneWidget);
      final textWidget = tester.widget<Text>(find.text(errorMessage));
      expect(textWidget.style?.color, Colors.red);
      expect(textWidget.style?.fontSize, fontSizeMediumLarge);
      expect(find.byType(AiRunningAnimationWrapper), findsNothing);
    });

    testWidgets('displays running animation when in running state',
        (tester) async {
      // Arrange
      final container = ProviderContainer(
        overrides: [
          taskSummaryControllerProvider(id: testId)
              .overrideWith(() => MockTaskSummaryController('Summarizing...')),
          inferenceStatusControllerProvider(
            id: testId,
            aiResponseType: AiResponseType.taskSummary,
          ).overrideWith(
            () => MockInferenceStatusController(InferenceStatus.running),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: AiTaskSummaryView(id: testId),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert
      expect(find.text('Summarizing...'), findsOneWidget);
      expect(find.byType(AiRunningAnimationWrapper), findsOneWidget);
    });
  });
}
