import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/state/action_item_suggestions.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/ui/animation/ai_running_animation.dart';
import 'package:lotti/features/ai/ui/task_summary/action_item_suggestions_view.dart';
import 'package:lotti/themes/theme.dart'; // For fontSizeMediumLarge

// import '../../../../test_helper.dart'; // For WidgetTestBench if needed, or other test helpers

// Mock controller for ActionItemSuggestionsController
class MockActionItemSuggestionsController
    extends ActionItemSuggestionsController {
  MockActionItemSuggestionsController(this.mockState);
  final String mockState;

  @override
  String build({required String id}) {
    return mockState;
  }

  @override
  Future<void> getActionItemSuggestion() async {
    // Do nothing in mock
  }
}

// Mock controller for InferenceStatusController
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
  group('ActionItemSuggestionsView', () {
    const testId = 'test-item-id';

    testWidgets(
        'displays normal message with standard style when not in error state',
        (tester) async {
      // Arrange
      final container = ProviderContainer(
        overrides: [
          actionItemSuggestionsControllerProvider(id: testId).overrideWith(
            () => MockActionItemSuggestionsController(
              'This is a normal suggestion.',
            ),
          ),
          inferenceStatusControllerProvider(
            id: testId,
            aiResponseType: AiResponseType.actionItemSuggestions,
          ).overrideWith(
            () => MockInferenceStatusController(InferenceStatus.idle),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            // MaterialApp is needed for text styles and directionality
            home: Scaffold(
              body: ActionItemSuggestionsView(id: testId),
            ),
          ),
        ),
      );

      // Act
      await tester.pumpAndSettle(); // Allow time for UI to build

      // Assert
      expect(find.text('This is a normal suggestion.'), findsOneWidget);
      final textWidget =
          tester.widget<Text>(find.text('This is a normal suggestion.'));
      expect(textWidget.style?.color, isNot(Colors.red));
      // For normal style, we check against the default monospaceTextStyleSmall's font size
      // and ensure it's not the error font size.
      // The actual font size for monospaceTextStyleSmall is 11.0
      expect(textWidget.style?.fontSize, monospaceTextStyleSmall.fontSize);
      expect(find.byType(AiRunningAnimationWrapper), findsNothing);
    });

    testWidgets('displays error message with error style when in error state',
        (tester) async {
      // Arrange
      const errorMessage = 'Payment Required: Budget exhausted.';
      final container = ProviderContainer(
        overrides: [
          actionItemSuggestionsControllerProvider(id: testId).overrideWith(
            () => MockActionItemSuggestionsController(errorMessage),
          ),
          inferenceStatusControllerProvider(
            id: testId,
            aiResponseType: AiResponseType.actionItemSuggestions,
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
              body: ActionItemSuggestionsView(id: testId),
            ),
          ),
        ),
      );

      // Act
      await tester.pumpAndSettle();

      // Assert
      expect(find.text(errorMessage), findsOneWidget);
      final textWidget = tester.widget<Text>(find.text(errorMessage));
      expect(textWidget.style?.color, Colors.red);
      expect(textWidget.style?.fontSize, fontSizeMediumLarge); // Should be 20.0
      expect(find.byType(AiRunningAnimationWrapper), findsNothing);
    });

    testWidgets('displays running animation when in running state',
        (tester) async {
      // Arrange
      final container = ProviderContainer(
        overrides: [
          actionItemSuggestionsControllerProvider(id: testId).overrideWith(
            () => MockActionItemSuggestionsController('Processing...'),
          ),
          inferenceStatusControllerProvider(
            id: testId,
            aiResponseType: AiResponseType.actionItemSuggestions,
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
              body: ActionItemSuggestionsView(id: testId),
            ),
          ),
        ),
      );

      // Act
      // Pump once to build the widget, then another short pump to let animations potentially start
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert
      expect(find.text('Processing...'), findsOneWidget);
      expect(find.byType(AiRunningAnimationWrapper), findsOneWidget);
    });
  });
}
