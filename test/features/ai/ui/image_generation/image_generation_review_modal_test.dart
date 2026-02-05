import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/image_generation_controller.dart';
import 'package:lotti/features/ai/state/reference_image_selection_controller.dart';
import 'package:lotti/features/ai/ui/image_generation/image_generation_review_modal.dart';
import 'package:lotti/features/ai/util/image_processing_utils.dart';
import 'package:lotti/get_it.dart';
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
  TestWidgetsFlutterBinding.ensureInitialized();

  const testEntityId = 'test-entity-id';
  const testLinkedTaskId = 'test-task-id';
  const testPrompt = 'Test image generation prompt';

  late Directory mockDocumentsDirectory;

  setUp(() async {
    await getIt.reset();
    getIt.allowReassignment = true;

    // Create a temp directory to simulate the documents directory
    mockDocumentsDirectory = Directory.systemTemp.createTempSync('modal_test_');

    // Register temp directory for getDocumentsDirectory()
    getIt.registerSingleton<Directory>(mockDocumentsDirectory);
  });

  tearDown(() async {
    await getIt.reset();
    try {
      mockDocumentsDirectory.deleteSync(recursive: true);
    } catch (_) {
      // Ignore cleanup errors
    }
  });

  // Helper to create overrides that skip reference image selection
  List<Override> createOverrides({
    required ImageGenerationState imageGenState,
  }) {
    // Empty availableImages triggers onSkip which advances to generation step
    const refImageState = ReferenceImageSelectionState();

    return [
      imageGenerationControllerProvider(entityId: testEntityId).overrideWith(
        () => _MockImageGenerationController(imageGenState),
      ),
      referenceImageSelectionControllerProvider(taskId: testLinkedTaskId)
          .overrideWith(
        () => _MockReferenceImageSelectionController(refImageState),
      ),
    ];
  }

  group('ImageGenerationReviewModal', () {
    testWidgets('shows loading indicator in initial state', (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: createOverrides(
            imageGenState: const ImageGenerationState.initial(),
          ),
          child: const ImageGenerationReviewModal(
            entityId: testEntityId,
            linkedTaskId: testLinkedTaskId,
            categoryId: null,
          ),
        ),
      );

      // Pump several frames to let onSkip callback trigger the step change
      // but don't use pumpAndSettle as CircularProgressIndicator animates indefinitely
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows generating state with spinner and text', (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: createOverrides(
            imageGenState:
                const ImageGenerationState.generating(prompt: testPrompt),
          ),
          child: const ImageGenerationReviewModal(
            entityId: testEntityId,
            linkedTaskId: testLinkedTaskId,
            categoryId: null,
          ),
        ),
      );

      // Pump several frames to let onSkip callback trigger the step change
      // but don't use pumpAndSettle as CircularProgressIndicator animates indefinitely
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Generating image...'), findsOneWidget);
    });

    testWidgets('shows success state with image and buttons', (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: createOverrides(
            imageGenState: ImageGenerationState.success(
              prompt: testPrompt,
              imageBytes: _testImageBytes,
              mimeType: 'image/png',
            ),
          ),
          child: const ImageGenerationReviewModal(
            entityId: testEntityId,
            linkedTaskId: testLinkedTaskId,
            categoryId: null,
          ),
        ),
      );

      await tester.pumpAndSettle();

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
          overrides: createOverrides(
            imageGenState: const ImageGenerationState.error(
              prompt: testPrompt,
              errorMessage: errorMessage,
            ),
          ),
          child: const ImageGenerationReviewModal(
            entityId: testEntityId,
            linkedTaskId: testLinkedTaskId,
            categoryId: null,
          ),
        ),
      );

      await tester.pumpAndSettle();

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
          overrides: createOverrides(
            imageGenState: ImageGenerationState.success(
              prompt: testPrompt,
              imageBytes: _testImageBytes,
              mimeType: 'image/png',
            ),
          ),
          child: const ImageGenerationReviewModal(
            entityId: testEntityId,
            linkedTaskId: testLinkedTaskId,
            categoryId: null,
          ),
        ),
      );

      await tester.pumpAndSettle();

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
          overrides: createOverrides(
            imageGenState: ImageGenerationState.success(
              prompt: testPrompt,
              imageBytes: _testImageBytes,
              mimeType: 'image/png',
            ),
          ),
          child: const ImageGenerationReviewModal(
            entityId: testEntityId,
            linkedTaskId: testLinkedTaskId,
            categoryId: null,
          ),
        ),
      );

      await tester.pumpAndSettle();

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
          overrides: createOverrides(
            imageGenState: ImageGenerationState.success(
              prompt: testPrompt,
              imageBytes: _testImageBytes,
              mimeType: 'image/png',
            ),
          ),
          child: const ImageGenerationReviewModal(
            entityId: testEntityId,
            linkedTaskId: testLinkedTaskId,
            categoryId: null,
          ),
        ),
      );

      await tester.pumpAndSettle();

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
          overrides: createOverrides(
            imageGenState: const ImageGenerationState.error(
              prompt: testPrompt,
              errorMessage: 'Some error',
            ),
          ),
          child: const ImageGenerationReviewModal(
            entityId: testEntityId,
            linkedTaskId: testLinkedTaskId,
            categoryId: null,
          ),
        ),
      );

      await tester.pumpAndSettle();

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
    testWidgets('retry button calls generateImage with current prompt',
        (tester) async {
      String? capturedPrompt;
      const refImageState = ReferenceImageSelectionState();

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
                onGenerateImage: (prompt) => capturedPrompt = prompt,
              ),
            ),
            referenceImageSelectionControllerProvider(taskId: testLinkedTaskId)
                .overrideWith(
              () => _MockReferenceImageSelectionController(refImageState),
            ),
          ],
          child: const ImageGenerationReviewModal(
            entityId: testEntityId,
            linkedTaskId: testLinkedTaskId,
            categoryId: null,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap retry button
      await tester.tap(find.text('Retry'));
      await tester.pump();

      // Retry should call generateImage with the current prompt
      expect(capturedPrompt, testPrompt);
    });

    testWidgets('generate button calls generateImage with edited prompt',
        (tester) async {
      String? capturedPrompt;
      const refImageState = ReferenceImageSelectionState();

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
            referenceImageSelectionControllerProvider(taskId: testLinkedTaskId)
                .overrideWith(
              () => _MockReferenceImageSelectionController(refImageState),
            ),
          ],
          child: const ImageGenerationReviewModal(
            entityId: testEntityId,
            linkedTaskId: testLinkedTaskId,
            categoryId: null,
          ),
        ),
      );

      await tester.pumpAndSettle();

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
      const refImageState = ReferenceImageSelectionState();

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
            referenceImageSelectionControllerProvider(taskId: testLinkedTaskId)
                .overrideWith(
              () => _MockReferenceImageSelectionController(refImageState),
            ),
          ],
          child: const ImageGenerationReviewModal(
            entityId: testEntityId,
            linkedTaskId: testLinkedTaskId,
            categoryId: null,
          ),
        ),
      );

      await tester.pumpAndSettle();

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
          overrides: createOverrides(
            imageGenState: const ImageGenerationState.error(
              prompt: errorPrompt,
              errorMessage: 'Some error',
            ),
          ),
          child: const ImageGenerationReviewModal(
            entityId: testEntityId,
            linkedTaskId: testLinkedTaskId,
            categoryId: null,
          ),
        ),
      );

      await tester.pumpAndSettle();

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
          overrides: createOverrides(
            imageGenState: ImageGenerationState.success(
              prompt: testPrompt,
              imageBytes: _testImageBytes,
              mimeType: 'image/png',
            ),
          ),
          child: const ImageGenerationReviewModal(
            entityId: testEntityId,
            linkedTaskId: testLinkedTaskId,
            categoryId: null,
          ),
        ),
      );

      await tester.pumpAndSettle();

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

  group('ImageGenerationReviewModal reference image flow', () {
    testWidgets('retry includes reference images when present', (tester) async {
      List<ProcessedReferenceImage>? capturedReferenceImages;
      const refImageState = ReferenceImageSelectionState();

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            imageGenerationControllerProvider(entityId: testEntityId)
                .overrideWith(
              () => _TrackingMockImageGenerationControllerWithRefs(
                const ImageGenerationState.error(
                  prompt: testPrompt,
                  errorMessage: 'Test error',
                ),
                onGenerateImageWithRefs: (prompt, refs) {
                  capturedReferenceImages = refs;
                },
              ),
            ),
            referenceImageSelectionControllerProvider(taskId: testLinkedTaskId)
                .overrideWith(
              () => _MockReferenceImageSelectionController(refImageState),
            ),
          ],
          child: const ImageGenerationReviewModal(
            entityId: testEntityId,
            linkedTaskId: testLinkedTaskId,
            categoryId: null,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap retry button
      await tester.tap(find.text('Retry'));
      await tester.pump();

      // Reference images should be null when none selected
      expect(capturedReferenceImages, isNull);
    });

    testWidgets('modal step starts at selectImages', (tester) async {
      // Create state that will show the selection widget
      final stateWithImages = ReferenceImageSelectionState(
        availableImages: [
          JournalImage(
            meta: Metadata(
              id: 'img-1',
              createdAt: DateTime(2025),
              updatedAt: DateTime(2025),
              dateFrom: DateTime(2025),
              dateTo: DateTime(2025),
            ),
            data: ImageData(
              imageId: 'img-1',
              imageFile: 'test.jpg',
              imageDirectory: mockDocumentsDirectory.path,
              capturedAt: DateTime(2025),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            imageGenerationControllerProvider(entityId: testEntityId)
                .overrideWith(
              () => _MockImageGenerationController(
                const ImageGenerationState.initial(),
              ),
            ),
            referenceImageSelectionControllerProvider(taskId: testLinkedTaskId)
                .overrideWith(
              () => _MockReferenceImageSelectionController(stateWithImages),
            ),
          ],
          child: const ImageGenerationReviewModal(
            entityId: testEntityId,
            linkedTaskId: testLinkedTaskId,
            categoryId: null,
          ),
        ),
      );

      // Don't settle - just pump once
      await tester.pump();

      // Should show reference image selection widget
      expect(find.text('Select Reference Images'), findsOneWidget);
    });

    testWidgets('handles null prompt gracefully in error state', (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: createOverrides(
            imageGenState: const ImageGenerationState.error(
              prompt: kFailedPromptPlaceholder,
              errorMessage: 'Prompt generation failed',
            ),
          ),
          child: const ImageGenerationReviewModal(
            entityId: testEntityId,
            linkedTaskId: testLinkedTaskId,
            categoryId: null,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Error state should be shown
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);

      // Retry button should be disabled for failed prompt
      final retryButton = find.widgetWithText(LottiPrimaryButton, 'Retry');
      expect(retryButton, findsOneWidget);
      final button = tester.widget<LottiPrimaryButton>(retryButton);
      expect(button.onPressed, isNull);
    });
  });
}

/// Mock reference image selection controller that returns a fixed state.
class _MockReferenceImageSelectionController
    extends ReferenceImageSelectionController {
  _MockReferenceImageSelectionController(this._fixedState);

  final ReferenceImageSelectionState _fixedState;

  @override
  ReferenceImageSelectionState build({required String taskId}) {
    return _fixedState;
  }

  @override
  void toggleImageSelection(String imageId) {}

  @override
  void clearSelection() {}

  @override
  Future<List<ProcessedReferenceImage>> processSelectedImages() async {
    return [];
  }
}

/// Mock controller that tracks method calls for testing.
class _TrackingMockImageGenerationController extends ImageGenerationController {
  _TrackingMockImageGenerationController(
    this._fixedState, {
    this.onGenerateImage,
  });

  final ImageGenerationState _fixedState;
  final void Function(String prompt)? onGenerateImage;

  @override
  ImageGenerationState build({required String entityId}) {
    return _fixedState;
  }

  @override
  Future<void> generateImageFromEntity({
    required String audioEntityId,
    List<ProcessedReferenceImage>? referenceImages,
  }) {
    return Future.value();
  }

  @override
  Future<void> generateImage({
    required String prompt,
    String? systemMessage,
    List<ProcessedReferenceImage>? referenceImages,
  }) {
    onGenerateImage?.call(prompt);
    return Future.value();
  }

  @override
  Future<void> retryGeneration({String? modifiedPrompt}) {
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
  Future<void> generateImageFromEntity({
    required String audioEntityId,
    List<ProcessedReferenceImage>? referenceImages,
  }) {
    // No-op for tests - we control state through constructor
    return Future.value();
  }

  @override
  Future<void> generateImage({
    required String prompt,
    String? systemMessage,
    List<ProcessedReferenceImage>? referenceImages,
  }) {
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

/// Mock controller that tracks reference images in generateImage calls.
class _TrackingMockImageGenerationControllerWithRefs
    extends ImageGenerationController {
  _TrackingMockImageGenerationControllerWithRefs(
    this._fixedState, {
    this.onGenerateImageWithRefs,
  });

  final ImageGenerationState _fixedState;
  final void Function(String prompt, List<ProcessedReferenceImage>? refs)?
      onGenerateImageWithRefs;

  @override
  ImageGenerationState build({required String entityId}) {
    return _fixedState;
  }

  @override
  Future<void> generateImageFromEntity({
    required String audioEntityId,
    List<ProcessedReferenceImage>? referenceImages,
  }) {
    return Future.value();
  }

  @override
  Future<void> generateImage({
    required String prompt,
    String? systemMessage,
    List<ProcessedReferenceImage>? referenceImages,
  }) {
    onGenerateImageWithRefs?.call(prompt, referenceImages);
    return Future.value();
  }

  @override
  Future<void> retryGeneration({String? modifiedPrompt}) {
    return Future.value();
  }

  @override
  void reset() {}
}
