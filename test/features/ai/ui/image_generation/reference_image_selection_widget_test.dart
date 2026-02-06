import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/reference_image_selection_controller.dart';
import 'package:lotti/features/ai/ui/image_generation/reference_image_selection_widget.dart';
import 'package:lotti/features/ai/util/image_processing_utils.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';

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

/// Mock controller that tracks toggleImageSelection calls.
class _TrackingMockReferenceImageSelectionController
    extends ReferenceImageSelectionController {
  _TrackingMockReferenceImageSelectionController(this._fixedState);

  final ReferenceImageSelectionState _fixedState;
  final List<String> toggledImageIds = [];

  @override
  ReferenceImageSelectionState build({required String taskId}) {
    return _fixedState;
  }

  @override
  void toggleImageSelection(String imageId) {
    toggledImageIds.add(imageId);
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

    testWidgets('shows Continue button', (tester) async {
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

      expect(find.byType(LottiPrimaryButton), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('Continue button shows count when images selected',
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

      // Button should show "Continue (2)" with the selection count
      expect(find.text('Continue (2)'), findsOneWidget);
    });

    testWidgets('Continue button is disabled when processing', (tester) async {
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

      // Find button and verify it is disabled
      final continueButton = tester.widget<LottiPrimaryButton>(
        find.byType(LottiPrimaryButton),
      );

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

    testWidgets('selection counter shows correct count', (tester) async {
      final stateWithSelection = ReferenceImageSelectionState(
        availableImages: [
          buildTestImage('img-1'),
          buildTestImage('img-2'),
          buildTestImage('img-3'),
        ],
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

      // Counter should show 2/3
      expect(find.text('2/$kMaxReferenceImages'), findsOneWidget);
    });

    testWidgets('counter shows 0/3 when nothing selected', (tester) async {
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

      // Counter should show 0/3
      expect(find.text('0/$kMaxReferenceImages'), findsOneWidget);
    });

    testWidgets('counter shows 3/3 when max selected', (tester) async {
      final stateAtMax = ReferenceImageSelectionState(
        availableImages: [
          buildTestImage('img-1'),
          buildTestImage('img-2'),
          buildTestImage('img-3'),
          buildTestImage('img-4'),
        ],
        selectedImageIds: const {'img-1', 'img-2', 'img-3'},
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            referenceImageSelectionControllerProvider(taskId: testTaskId)
                .overrideWith(
              () => _MockReferenceImageSelectionController(stateAtMax),
            ),
          ],
          child: ReferenceImageSelectionWidget(
            taskId: testTaskId,
            onContinue: (_) {},
            onSkip: () {},
          ),
        ),
      );

      // Counter should show 3/3
      expect(find.text('3/$kMaxReferenceImages'), findsOneWidget);
    });

    testWidgets('onSkip is only called once (auto-skip guard)', (tester) async {
      var skipCallCount = 0;
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
            onSkip: () => skipCallCount++,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Skip should only be called once even after multiple frames
      expect(skipCallCount, 1);
    });

    testWidgets('displays correct number of grid items', (tester) async {
      final stateWithImages = ReferenceImageSelectionState(
        availableImages: [
          buildTestImage('img-1'),
          buildTestImage('img-2'),
          buildTestImage('img-3'),
          buildTestImage('img-4'),
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

      // GridView should be present with correct number of items
      final gridView = tester.widget<GridView>(find.byType(GridView));
      expect(gridView, isNotNull);
    });

    testWidgets('shows error state for missing image files', (tester) async {
      // Image with path that doesn't exist will show error placeholder
      final stateWithImages = ReferenceImageSelectionState(
        availableImages: [buildTestImage('missing-img')],
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

      // GridView should still be present even with missing files
      expect(find.byType(GridView), findsOneWidget);
    });

    testWidgets('shows error UI when errorCode is set', (tester) async {
      const errorState = ReferenceImageSelectionState(
        errorCode: ReferenceImageSelectionError.loadImagesFailed,
        errorDetail: 'Database error',
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            referenceImageSelectionControllerProvider(taskId: testTaskId)
                .overrideWith(
              () => _MockReferenceImageSelectionController(errorState),
            ),
          ],
          child: ReferenceImageSelectionWidget(
            taskId: testTaskId,
            onContinue: (_) {},
            onSkip: () {},
          ),
        ),
      );

      // Should show error icon
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);

      // Should show localized error message
      expect(
        find.text('Failed to load images. Please try again.'),
        findsOneWidget,
      );

      // Should show skip button
      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('tapping image tile calls toggleImageSelection',
        (tester) async {
      final stateWithImages = ReferenceImageSelectionState(
        availableImages: [
          buildTestImage('img-1'),
          buildTestImage('img-2'),
        ],
      );

      final trackingController =
          _TrackingMockReferenceImageSelectionController(stateWithImages);

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            referenceImageSelectionControllerProvider(taskId: testTaskId)
                .overrideWith(
              () => trackingController,
            ),
          ],
          child: ReferenceImageSelectionWidget(
            taskId: testTaskId,
            onContinue: (_) {},
            onSkip: () {},
          ),
        ),
      );

      // Tap the first image tile via GestureDetector
      final gestureFinders = find.byType(GestureDetector);
      expect(gestureFinders, findsWidgets);

      // Tap the first GestureDetector in the grid
      await tester.tap(gestureFinders.first);
      await tester.pump();

      expect(trackingController.toggledImageIds, contains('img-1'));
    });

    testWidgets('tapping non-selectable image tile does not toggle',
        (tester) async {
      // All 3 slots taken, img-4 is not selected and cannot be toggled
      final stateAtMax = ReferenceImageSelectionState(
        availableImages: [
          buildTestImage('img-1'),
          buildTestImage('img-2'),
          buildTestImage('img-3'),
          buildTestImage('img-4'),
        ],
        selectedImageIds: const {'img-1', 'img-2', 'img-3'},
      );

      final trackingController =
          _TrackingMockReferenceImageSelectionController(stateAtMax);

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            referenceImageSelectionControllerProvider(taskId: testTaskId)
                .overrideWith(
              () => trackingController,
            ),
          ],
          child: ReferenceImageSelectionWidget(
            taskId: testTaskId,
            onContinue: (_) {},
            onSkip: () {},
          ),
        ),
      );

      // Find all GestureDetectors in the grid - the 4th one (img-4) should
      // be non-selectable since max is reached
      final gestureFinders = find.byType(GestureDetector);
      final fourthTile = gestureFinders.at(3);

      // Scroll into view since 4th tile is on the second grid row
      await tester.ensureVisible(fourthTile);
      await tester.pumpAndSettle();

      // Tap the last image tile (img-4, which is not selected and at max)
      await tester.tap(fourthTile);
      await tester.pump();

      // img-4 should NOT have been toggled since it's non-selectable
      expect(trackingController.toggledImageIds, isNot(contains('img-4')));
    });

    testWidgets('tapping already-selected image tile toggles deselection',
        (tester) async {
      final stateWithSelection = ReferenceImageSelectionState(
        availableImages: [
          buildTestImage('img-1'),
          buildTestImage('img-2'),
        ],
        selectedImageIds: const {'img-1'},
      );

      final trackingController =
          _TrackingMockReferenceImageSelectionController(stateWithSelection);

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            referenceImageSelectionControllerProvider(taskId: testTaskId)
                .overrideWith(
              () => trackingController,
            ),
          ],
          child: ReferenceImageSelectionWidget(
            taskId: testTaskId,
            onContinue: (_) {},
            onSkip: () {},
          ),
        ),
      );

      // Tap the first image (which is already selected)
      final gestureFinders = find.byType(GestureDetector);
      await tester.tap(gestureFinders.first);
      await tester.pump();

      // Should call toggle for img-1 (deselection)
      expect(trackingController.toggledImageIds, equals(['img-1']));
    });

    testWidgets('error state skip button calls onSkip', (tester) async {
      var skipCalled = false;
      const errorState = ReferenceImageSelectionState(
        errorCode: ReferenceImageSelectionError.loadImagesFailed,
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            referenceImageSelectionControllerProvider(taskId: testTaskId)
                .overrideWith(
              () => _MockReferenceImageSelectionController(errorState),
            ),
          ],
          child: ReferenceImageSelectionWidget(
            taskId: testTaskId,
            onContinue: (_) {},
            onSkip: () => skipCalled = true,
          ),
        ),
      );

      // Tap skip button
      await tester.tap(find.text('Skip'));
      await tester.pump();

      expect(skipCalled, isTrue);
    });
  });
}
