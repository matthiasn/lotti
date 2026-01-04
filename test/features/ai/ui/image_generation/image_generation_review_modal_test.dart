import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/state/image_generation_controller.dart';
import 'package:lotti/features/ai/ui/image_generation/image_generation_review_modal.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';
import 'package:lotti/widgets/buttons/lotti_secondary_button.dart';

import '../../../../test_helper.dart';

/// Minimal 1x1 transparent PNG for testing.
final _testImageBytes = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x08, 0xD7, 0x63, 0x60, 0x60, 0x60, 0x60,
  0x00, 0x00, 0x00, 0x05, 0x00, 0x01, 0x5A, 0xB5, 0x4E, 0xD1, 0x00, 0x00,
  0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82, //
]);

void main() {
  const testEntityId = 'test-entity-id';
  const testLinkedTaskId = 'test-task-id';
  const testPrompt = 'Test image generation prompt';

  group('ImageGenerationReviewModal', () {
    testWidgets('shows loading indicator in initial state', (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            imageGenerationControllerProvider(entityId: testEntityId)
                .overrideWith(
              () => _MockImageGenerationController(
                const ImageGenerationState.initial(),
              ),
            ),
          ],
          child: const ImageGenerationReviewModal(
            entityId: testEntityId,
            linkedTaskId: testLinkedTaskId,
            categoryId: null,
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows generating state with spinner and text', (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            imageGenerationControllerProvider(entityId: testEntityId)
                .overrideWith(
              () => _MockImageGenerationController(
                const ImageGenerationState.generating(prompt: testPrompt),
              ),
            ),
          ],
          child: const ImageGenerationReviewModal(
            entityId: testEntityId,
            linkedTaskId: testLinkedTaskId,
            categoryId: null,
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Generating image...'), findsOneWidget);
    });

    testWidgets('shows success state with image and buttons', (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            imageGenerationControllerProvider(entityId: testEntityId)
                .overrideWith(
              () => _MockImageGenerationController(
                ImageGenerationState.success(
                  prompt: testPrompt,
                  imageBytes: _testImageBytes,
                  mimeType: 'image/png',
                ),
              ),
            ),
          ],
          child: const ImageGenerationReviewModal(
            entityId: testEntityId,
            linkedTaskId: testLinkedTaskId,
            categoryId: null,
          ),
        ),
      );

      await tester.pump();

      // Should show the image
      expect(find.byType(Image), findsOneWidget);

      // Should show action buttons
      expect(find.byType(LottiSecondaryButton), findsOneWidget);
      expect(find.byType(LottiPrimaryButton), findsOneWidget);

      // Check button labels
      expect(find.text('Edit Prompt'), findsOneWidget);
      expect(find.text('Accept as Cover Art'), findsOneWidget);
    });

    testWidgets('shows error state with error message and retry button',
        (tester) async {
      const errorMessage = 'Failed to generate image';

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            imageGenerationControllerProvider(entityId: testEntityId)
                .overrideWith(
              () => _MockImageGenerationController(
                const ImageGenerationState.error(
                  prompt: testPrompt,
                  errorMessage: errorMessage,
                ),
              ),
            ),
          ],
          child: const ImageGenerationReviewModal(
            entityId: testEntityId,
            linkedTaskId: testLinkedTaskId,
            categoryId: null,
          ),
        ),
      );

      await tester.pump();

      // Should show error icon
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);

      // Should show error message (title and detail)
      expect(find.text('Failed to generate image'), findsAtLeastNWidgets(1));
      expect(find.textContaining(errorMessage), findsAtLeastNWidgets(1));

      // Should show retry and edit buttons
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Edit Prompt'), findsOneWidget);
    });

    testWidgets('edit prompt button shows prompt editor', (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            imageGenerationControllerProvider(entityId: testEntityId)
                .overrideWith(
              () => _MockImageGenerationController(
                ImageGenerationState.success(
                  prompt: testPrompt,
                  imageBytes: _testImageBytes,
                  mimeType: 'image/png',
                ),
              ),
            ),
          ],
          child: const ImageGenerationReviewModal(
            entityId: testEntityId,
            linkedTaskId: testLinkedTaskId,
            categoryId: null,
          ),
        ),
      );

      await tester.pump();

      // Tap the edit button
      await tester.tap(find.text('Edit Prompt'));
      await tester.pump();

      // Should show a text field for editing
      expect(find.byType(TextField), findsOneWidget);

      // Should show cancel and generate buttons
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Generate Cover Art'), findsOneWidget);
    });

    testWidgets('cancel edit returns to previous state', (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            imageGenerationControllerProvider(entityId: testEntityId)
                .overrideWith(
              () => _MockImageGenerationController(
                ImageGenerationState.success(
                  prompt: testPrompt,
                  imageBytes: _testImageBytes,
                  mimeType: 'image/png',
                ),
              ),
            ),
          ],
          child: const ImageGenerationReviewModal(
            entityId: testEntityId,
            linkedTaskId: testLinkedTaskId,
            categoryId: null,
          ),
        ),
      );

      await tester.pump();

      // Enter edit mode
      await tester.tap(find.text('Edit Prompt'));
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);

      // Cancel edit
      await tester.tap(find.text('Cancel'));
      await tester.pump();

      // Should be back to success state showing image
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('prompt editor contains prompt from state', (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            imageGenerationControllerProvider(entityId: testEntityId)
                .overrideWith(
              () => _MockImageGenerationController(
                ImageGenerationState.success(
                  prompt: testPrompt,
                  imageBytes: _testImageBytes,
                  mimeType: 'image/png',
                ),
              ),
            ),
          ],
          child: const ImageGenerationReviewModal(
            entityId: testEntityId,
            linkedTaskId: testLinkedTaskId,
            categoryId: null,
          ),
        ),
      );

      await tester.pump();

      // Enter edit mode
      await tester.tap(find.text('Edit Prompt'));
      await tester.pump();

      // TextField should contain the prompt from state
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, testPrompt);
    });

    testWidgets('error state edit button shows prompt editor', (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            imageGenerationControllerProvider(entityId: testEntityId)
                .overrideWith(
              () => _MockImageGenerationController(
                const ImageGenerationState.error(
                  prompt: testPrompt,
                  errorMessage: 'Some error',
                ),
              ),
            ),
          ],
          child: const ImageGenerationReviewModal(
            entityId: testEntityId,
            linkedTaskId: testLinkedTaskId,
            categoryId: null,
          ),
        ),
      );

      await tester.pump();

      // Tap the edit button from error state
      await tester.tap(find.text('Edit Prompt'));
      await tester.pump();

      // Should show the prompt editor
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('ImageGenerationReviewModal widget properties', () {
    test('requires entityId parameter', () {
      // This test verifies the constructor requires all parameters
      const widget = ImageGenerationReviewModal(
        entityId: 'id',
        linkedTaskId: 'task-id',
        categoryId: null,
      );

      expect(widget.entityId, 'id');
      expect(widget.linkedTaskId, 'task-id');
    });

    test('categoryId can be null', () {
      const widget = ImageGenerationReviewModal(
        entityId: 'id',
        linkedTaskId: 'task-id',
        categoryId: null,
      );

      expect(widget.categoryId, isNull);
    });

    test('categoryId can have a value', () {
      const widget = ImageGenerationReviewModal(
        entityId: 'id',
        linkedTaskId: 'task-id',
        categoryId: 'category-123',
      );

      expect(widget.categoryId, 'category-123');
    });
  });

  group('ImageGenerationReviewModal button interactions', () {
    testWidgets('retry button calls retryGeneration on controller',
        (tester) async {
      var retryCallCount = 0;

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            imageGenerationControllerProvider(entityId: testEntityId)
                .overrideWith(
              () => _TrackingMockImageGenerationController(
                const ImageGenerationState.error(
                  prompt: testPrompt,
                  errorMessage: 'Test error',
                ),
                onRetry: () => retryCallCount++,
              ),
            ),
          ],
          child: const ImageGenerationReviewModal(
            entityId: testEntityId,
            linkedTaskId: testLinkedTaskId,
            categoryId: null,
          ),
        ),
      );

      await tester.pump();

      // Tap retry button
      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(retryCallCount, 1);
    });

    testWidgets('generate button calls generateImage with edited prompt',
        (tester) async {
      String? capturedPrompt;

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            imageGenerationControllerProvider(entityId: testEntityId)
                .overrideWith(
              () => _TrackingMockImageGenerationController(
                ImageGenerationState.success(
                  prompt: testPrompt,
                  imageBytes: _testImageBytes,
                  mimeType: 'image/png',
                ),
                onGenerateImage: (prompt) => capturedPrompt = prompt,
              ),
            ),
          ],
          child: const ImageGenerationReviewModal(
            entityId: testEntityId,
            linkedTaskId: testLinkedTaskId,
            categoryId: null,
          ),
        ),
      );

      await tester.pump();

      // Enter edit mode
      await tester.tap(find.text('Edit Prompt'));
      await tester.pump();

      // Clear and enter new prompt
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'New edited prompt');
      await tester.pump();

      // Tap generate button
      await tester.tap(find.text('Generate Cover Art'));
      await tester.pump();

      expect(capturedPrompt, 'New edited prompt');
    });

    testWidgets('generate button does nothing with empty prompt',
        (tester) async {
      var generateCallCount = 0;

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            imageGenerationControllerProvider(entityId: testEntityId)
                .overrideWith(
              () => _TrackingMockImageGenerationController(
                ImageGenerationState.success(
                  prompt: testPrompt,
                  imageBytes: _testImageBytes,
                  mimeType: 'image/png',
                ),
                onGenerateImage: (_) => generateCallCount++,
              ),
            ),
          ],
          child: const ImageGenerationReviewModal(
            entityId: testEntityId,
            linkedTaskId: testLinkedTaskId,
            categoryId: null,
          ),
        ),
      );

      await tester.pump();

      // Enter edit mode
      await tester.tap(find.text('Edit Prompt'));
      await tester.pump();

      // Clear prompt to empty
      final textField = find.byType(TextField);
      await tester.enterText(textField, '   ');
      await tester.pump();

      // Tap generate button - should not call generate with empty prompt
      await tester.tap(find.text('Generate Cover Art'));
      await tester.pump();

      expect(generateCallCount, 0);
    });

    testWidgets('edit prompt from error state works', (tester) async {
      const errorPrompt = 'Error state prompt';

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            imageGenerationControllerProvider(entityId: testEntityId)
                .overrideWith(
              () => _MockImageGenerationController(
                const ImageGenerationState.error(
                  prompt: errorPrompt,
                  errorMessage: 'Some error',
                ),
              ),
            ),
          ],
          child: const ImageGenerationReviewModal(
            entityId: testEntityId,
            linkedTaskId: testLinkedTaskId,
            categoryId: null,
          ),
        ),
      );

      await tester.pump();

      // Tap edit button from error state
      await tester.tap(find.text('Edit Prompt'));
      await tester.pump();

      // Verify text field contains the error state prompt
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, errorPrompt);
    });

    testWidgets('cancel edit resets prompt text to original', (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            imageGenerationControllerProvider(entityId: testEntityId)
                .overrideWith(
              () => _MockImageGenerationController(
                ImageGenerationState.success(
                  prompt: testPrompt,
                  imageBytes: _testImageBytes,
                  mimeType: 'image/png',
                ),
              ),
            ),
          ],
          child: const ImageGenerationReviewModal(
            entityId: testEntityId,
            linkedTaskId: testLinkedTaskId,
            categoryId: null,
          ),
        ),
      );

      await tester.pump();

      // Enter edit mode
      await tester.tap(find.text('Edit Prompt'));
      await tester.pump();

      // Modify the text
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'Modified text');
      await tester.pump();

      // Cancel edit
      await tester.tap(find.text('Cancel'));
      await tester.pump();

      // Enter edit mode again
      await tester.tap(find.text('Edit Prompt'));
      await tester.pump();

      // Verify text was reset to original
      final updatedTextField = tester.widget<TextField>(find.byType(TextField));
      expect(updatedTextField.controller?.text, testPrompt);
    });
  });
}

/// Mock controller that tracks method calls for testing.
class _TrackingMockImageGenerationController extends ImageGenerationController {
  _TrackingMockImageGenerationController(
    this._fixedState, {
    this.onRetry,
    this.onGenerateImage,
  });

  final ImageGenerationState _fixedState;
  final void Function()? onRetry;
  final void Function(String prompt)? onGenerateImage;

  @override
  ImageGenerationState build({required String entityId}) {
    return _fixedState;
  }

  @override
  Future<void> generateImageFromEntity({required String audioEntityId}) {
    return Future.value();
  }

  @override
  Future<void> generateImage({required String prompt, String? systemMessage}) {
    onGenerateImage?.call(prompt);
    return Future.value();
  }

  @override
  Future<void> retryGeneration({String? modifiedPrompt}) {
    onRetry?.call();
    return Future.value();
  }

  @override
  void reset() {}
}

/// Mock controller that returns a fixed state for testing.
class _MockImageGenerationController extends ImageGenerationController {
  _MockImageGenerationController(this._fixedState);

  final ImageGenerationState _fixedState;

  @override
  ImageGenerationState build({required String entityId}) {
    return _fixedState;
  }

  @override
  Future<void> generateImageFromEntity({required String audioEntityId}) {
    // No-op for tests - we control state through constructor
    return Future.value();
  }

  @override
  Future<void> generateImage({required String prompt, String? systemMessage}) {
    // No-op for tests - we control state through constructor
    return Future.value();
  }

  @override
  Future<void> retryGeneration({String? modifiedPrompt}) {
    // No-op for tests
    return Future.value();
  }

  @override
  void reset() {
    // No-op for tests
  }
}
