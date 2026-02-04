import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/reference_image_selection_controller.dart';
import 'package:lotti/features/ai/ui/image_generation/reference_image_selection_widget.dart';
import 'package:lotti/features/ai/util/image_processing_utils.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';
import 'package:lotti/widgets/buttons/lotti_secondary_button.dart';

import '../../../../test_helper.dart';

/// Mock controller that returns a fixed state for testing.
class _MockReferenceImageSelectionController
    extends ReferenceImageSelectionController {
  _MockReferenceImageSelectionController(this._fixedState);

  final ReferenceImageSelectionState _fixedState;

  @override
  ReferenceImageSelectionState build({required String taskId}) {
    return _fixedState;
  }

  @override
  void toggleImageSelection(String imageId) {
    // No-op for tests
  }

  @override
  void clearSelection() {
    // No-op for tests
  }

  @override
  Future<List<ProcessedReferenceImage>> processSelectedImages() async {
    return [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testTaskId = 'test-task-id';
  final testDate = DateTime(2025);
  late Directory mockDocumentsDirectory;

  JournalImage buildTestImage(String id) {
    return JournalImage(
      meta: Metadata(
        id: id,
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate,
        dateTo: testDate,
      ),
      data: ImageData(
        imageId: id,
        imageFile: 'test_$id.jpg',
        imageDirectory: '/test/images',
        capturedAt: testDate,
      ),
    );
  }

  setUp(() async {
    await getIt.reset();
    getIt.allowReassignment = true;

    // Create a temp directory to simulate the documents directory
    mockDocumentsDirectory =
        Directory.systemTemp.createTempSync('ref_image_selection_test_');

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

  group('ReferenceImageSelectionWidget', () {
    testWidgets('shows loading indicator when isLoading is true',
        (tester) async {
      const loadingState = ReferenceImageSelectionState(isLoading: true);

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            referenceImageSelectionControllerProvider(taskId: testTaskId)
                .overrideWith(
              () => _MockReferenceImageSelectionController(loadingState),
            ),
          ],
          child: ReferenceImageSelectionWidget(
            taskId: testTaskId,
            onContinue: (_) {},
            onSkip: () {},
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('calls onSkip when no images are available', (tester) async {
      var skipCalled = false;
      const emptyState = ReferenceImageSelectionState();

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            referenceImageSelectionControllerProvider(taskId: testTaskId)
                .overrideWith(
              () => _MockReferenceImageSelectionController(emptyState),
            ),
          ],
          child: ReferenceImageSelectionWidget(
            taskId: testTaskId,
            onContinue: (_) {},
            onSkip: () => skipCalled = true,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(skipCalled, isTrue);
    });

    testWidgets('displays title and subtitle when images available',
        (tester) async {
      final stateWithImages = ReferenceImageSelectionState(
        availableImages: [buildTestImage('img-1')],
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            referenceImageSelectionControllerProvider(taskId: testTaskId)
                .overrideWith(
              () => _MockReferenceImageSelectionController(stateWithImages),
            ),
          ],
          child: ReferenceImageSelectionWidget(
            taskId: testTaskId,
            onContinue: (_) {},
            onSkip: () {},
          ),
        ),
      );

      // Title should be visible
      expect(find.text('Select Reference Images'), findsOneWidget);

      // Subtitle should be visible
      expect(
        find.text("Choose up to 3 images to guide the AI's visual style"),
        findsOneWidget,
      );
    });

    testWidgets('shows selection counter', (tester) async {
      final stateWithSelection = ReferenceImageSelectionState(
        availableImages: [buildTestImage('img-1'), buildTestImage('img-2')],
        selectedImageIds: const {'img-1'},
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            referenceImageSelectionControllerProvider(taskId: testTaskId)
                .overrideWith(
              () => _MockReferenceImageSelectionController(stateWithSelection),
            ),
          ],
          child: ReferenceImageSelectionWidget(
            taskId: testTaskId,
            onContinue: (_) {},
            onSkip: () {},
          ),
        ),
      );

      // Counter should show 1/3
      expect(find.text('1/$kMaxReferenceImages'), findsOneWidget);
    });

    testWidgets('shows Skip and Continue buttons', (tester) async {
      final stateWithImages = ReferenceImageSelectionState(
        availableImages: [buildTestImage('img-1')],
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            referenceImageSelectionControllerProvider(taskId: testTaskId)
                .overrideWith(
              () => _MockReferenceImageSelectionController(stateWithImages),
            ),
          ],
          child: ReferenceImageSelectionWidget(
            taskId: testTaskId,
            onContinue: (_) {},
            onSkip: () {},
          ),
        ),
      );

      expect(find.byType(LottiSecondaryButton), findsOneWidget);
      expect(find.byType(LottiPrimaryButton), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('shows Continue with count when images selected',
        (tester) async {
      final stateWithSelection = ReferenceImageSelectionState(
        availableImages: [buildTestImage('img-1'), buildTestImage('img-2')],
        selectedImageIds: const {'img-1', 'img-2'},
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            referenceImageSelectionControllerProvider(taskId: testTaskId)
                .overrideWith(
              () => _MockReferenceImageSelectionController(stateWithSelection),
            ),
          ],
          child: ReferenceImageSelectionWidget(
            taskId: testTaskId,
            onContinue: (_) {},
            onSkip: () {},
          ),
        ),
      );

      expect(find.text('Continue (2)'), findsOneWidget);
    });

    testWidgets('Skip button calls onSkip', (tester) async {
      var skipCalled = false;
      final stateWithImages = ReferenceImageSelectionState(
        availableImages: [buildTestImage('img-1')],
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            referenceImageSelectionControllerProvider(taskId: testTaskId)
                .overrideWith(
              () => _MockReferenceImageSelectionController(stateWithImages),
            ),
          ],
          child: ReferenceImageSelectionWidget(
            taskId: testTaskId,
            onContinue: (_) {},
            onSkip: () => skipCalled = true,
          ),
        ),
      );

      await tester.tap(find.text('Skip'));
      await tester.pump();

      expect(skipCalled, isTrue);
    });

    testWidgets('buttons are disabled when processing', (tester) async {
      final processingState = ReferenceImageSelectionState(
        availableImages: [buildTestImage('img-1')],
        isProcessing: true,
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            referenceImageSelectionControllerProvider(taskId: testTaskId)
                .overrideWith(
              () => _MockReferenceImageSelectionController(processingState),
            ),
          ],
          child: ReferenceImageSelectionWidget(
            taskId: testTaskId,
            onContinue: (_) {},
            onSkip: () {},
          ),
        ),
      );

      // Find buttons and verify they are disabled
      final skipButton = tester.widget<LottiSecondaryButton>(
        find.byType(LottiSecondaryButton),
      );
      final continueButton = tester.widget<LottiPrimaryButton>(
        find.byType(LottiPrimaryButton),
      );

      expect(skipButton.onPressed, isNull);
      expect(continueButton.onPressed, isNull);
    });

    testWidgets('displays grid of images', (tester) async {
      final stateWithImages = ReferenceImageSelectionState(
        availableImages: [
          buildTestImage('img-1'),
          buildTestImage('img-2'),
          buildTestImage('img-3'),
        ],
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            referenceImageSelectionControllerProvider(taskId: testTaskId)
                .overrideWith(
              () => _MockReferenceImageSelectionController(stateWithImages),
            ),
          ],
          child: ReferenceImageSelectionWidget(
            taskId: testTaskId,
            onContinue: (_) {},
            onSkip: () {},
          ),
        ),
      );

      // GridView should be present
      expect(find.byType(GridView), findsOneWidget);
    });
  });
}
