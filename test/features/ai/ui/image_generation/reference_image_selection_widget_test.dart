import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/state/reference_image_selection_controller.dart';
import 'package:lotti/features/ai/ui/image_generation/reference_image_selection_widget.dart';
import 'package:lotti/features/ai/util/image_processing_utils.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';

import '../../../../test_helper.dart';
import '../../../../widget_test_utils.dart';
import 'test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testTaskId = 'test-task-id';
  late Directory mockDocumentsDirectory;

  // One shared temp directory for the whole file: no test writes real image
  // files, the directory only needs to exist for getDocumentsDirectory().
  setUpAll(() {
    mockDocumentsDirectory = Directory.systemTemp.createTempSync(
      'ref_image_selection_test_',
    );
  });

  tearDownAll(() {
    try {
      mockDocumentsDirectory.deleteSync(recursive: true);
    } catch (_) {
      // Ignore cleanup errors
    }
  });

  setUp(() async {
    await setUpTestGetIt(
      additionalSetup: () {
        // Register temp directory for getDocumentsDirectory()
        getIt.registerSingleton<Directory>(mockDocumentsDirectory);
      },
    );
  });

  tearDown(tearDownTestGetIt);

  group('ReferenceImageSelectionWidget', () {
    testWidgets('shows loading indicator when isLoading is true', (
      tester,
    ) async {
      const loadingState = ReferenceImageSelectionState(isLoading: true);

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            referenceImageSelectionControllerProvider(
              taskId: testTaskId,
            ).overrideWith(
              () => FakeReferenceImageSelectionController(loadingState),
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
            referenceImageSelectionControllerProvider(
              taskId: testTaskId,
            ).overrideWith(
              () => FakeReferenceImageSelectionController(emptyState),
            ),
          ],
          child: ReferenceImageSelectionWidget(
            taskId: testTaskId,
            onContinue: (_) {},
            onSkip: () => skipCalled = true,
          ),
        ),
      );

      // onSkip fires from a single addPostFrameCallback; one extra pump after
      // the initial build is enough to run it (no animations to settle).
      await tester.pump();

      expect(skipCalled, isTrue);
    });

    testWidgets('displays title and subtitle when images available', (
      tester,
    ) async {
      final stateWithImages = ReferenceImageSelectionState(
        availableImages: [buildTestReferenceImage('img-1')],
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            referenceImageSelectionControllerProvider(
              taskId: testTaskId,
            ).overrideWith(
              () => FakeReferenceImageSelectionController(stateWithImages),
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
        find.text("Choose up to 5 images to guide the AI's visual style"),
        findsOneWidget,
      );
    });

    testWidgets('shows selection counter', (tester) async {
      final stateWithSelection = ReferenceImageSelectionState(
        availableImages: [
          buildTestReferenceImage('img-1'),
          buildTestReferenceImage('img-2'),
        ],
        selectedImageIds: const {'img-1'},
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            referenceImageSelectionControllerProvider(
              taskId: testTaskId,
            ).overrideWith(
              () => FakeReferenceImageSelectionController(stateWithSelection),
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
        availableImages: [buildTestReferenceImage('img-1')],
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            referenceImageSelectionControllerProvider(
              taskId: testTaskId,
            ).overrideWith(
              () => FakeReferenceImageSelectionController(stateWithImages),
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

    testWidgets('Continue button shows count when images selected', (
      tester,
    ) async {
      final stateWithSelection = ReferenceImageSelectionState(
        availableImages: [
          buildTestReferenceImage('img-1'),
          buildTestReferenceImage('img-2'),
        ],
        selectedImageIds: const {'img-1', 'img-2'},
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            referenceImageSelectionControllerProvider(
              taskId: testTaskId,
            ).overrideWith(
              () => FakeReferenceImageSelectionController(stateWithSelection),
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
        availableImages: [buildTestReferenceImage('img-1')],
        isProcessing: true,
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            referenceImageSelectionControllerProvider(
              taskId: testTaskId,
            ).overrideWith(
              () => FakeReferenceImageSelectionController(processingState),
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
          buildTestReferenceImage('img-1'),
          buildTestReferenceImage('img-2'),
          buildTestReferenceImage('img-3'),
        ],
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            referenceImageSelectionControllerProvider(
              taskId: testTaskId,
            ).overrideWith(
              () => FakeReferenceImageSelectionController(stateWithImages),
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
          buildTestReferenceImage('img-1'),
          buildTestReferenceImage('img-2'),
          buildTestReferenceImage('img-3'),
        ],
        selectedImageIds: const {'img-1', 'img-2'},
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            referenceImageSelectionControllerProvider(
              taskId: testTaskId,
            ).overrideWith(
              () => FakeReferenceImageSelectionController(stateWithSelection),
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
        availableImages: [buildTestReferenceImage('img-1')],
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            referenceImageSelectionControllerProvider(
              taskId: testTaskId,
            ).overrideWith(
              () => FakeReferenceImageSelectionController(stateWithImages),
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
          buildTestReferenceImage('img-1'),
          buildTestReferenceImage('img-2'),
          buildTestReferenceImage('img-3'),
          buildTestReferenceImage('img-4'),
        ],
        selectedImageIds: const {'img-1', 'img-2', 'img-3'},
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            referenceImageSelectionControllerProvider(
              taskId: testTaskId,
            ).overrideWith(
              () => FakeReferenceImageSelectionController(stateAtMax),
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
            referenceImageSelectionControllerProvider(
              taskId: testTaskId,
            ).overrideWith(
              () => FakeReferenceImageSelectionController(emptyState),
            ),
          ],
          child: ReferenceImageSelectionWidget(
            taskId: testTaskId,
            onContinue: (_) {},
            onSkip: () => skipCallCount++,
          ),
        ),
      );

      // Drive several explicit frames: the _hasAutoSkipped guard must keep
      // onSkip at exactly one call regardless of how many frames are pumped.
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // Skip should only be called once even after multiple frames
      expect(skipCallCount, 1);
    });

    testWidgets('displays correct number of grid items', (tester) async {
      final stateWithImages = ReferenceImageSelectionState(
        availableImages: [
          buildTestReferenceImage('img-1'),
          buildTestReferenceImage('img-2'),
          buildTestReferenceImage('img-3'),
          buildTestReferenceImage('img-4'),
        ],
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            referenceImageSelectionControllerProvider(
              taskId: testTaskId,
            ).overrideWith(
              () => FakeReferenceImageSelectionController(stateWithImages),
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
        availableImages: [buildTestReferenceImage('missing-img')],
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            referenceImageSelectionControllerProvider(
              taskId: testTaskId,
            ).overrideWith(
              () => FakeReferenceImageSelectionController(stateWithImages),
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

    testWidgets(
      'image tile errorBuilder renders broken-image placeholder',
      (tester) async {
        // The image points at a file that does not exist on disk; we exercise
        // the Image.file errorBuilder directly (the real file load completes
        // asynchronously and is unreliable to await in a widget test).
        final stateWithImages = ReferenceImageSelectionState(
          availableImages: [buildTestReferenceImage('missing-img')],
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              referenceImageSelectionControllerProvider(
                taskId: testTaskId,
              ).overrideWith(
                () => FakeReferenceImageSelectionController(stateWithImages),
              ),
            ],
            child: ReferenceImageSelectionWidget(
              taskId: testTaskId,
              onContinue: (_) {},
              onSkip: () {},
            ),
          ),
        );
        await tester.pump();

        // Grab the grid-tile image and invoke its errorBuilder, simulating a
        // decode/IO failure for the missing file.
        final imageWidget = tester.widget<Image>(find.byType(Image));
        final errorBuilder = imageWidget.errorBuilder;
        expect(errorBuilder, isNotNull);

        final imageElement = tester.element(find.byType(Image));
        final placeholder = errorBuilder!(
          imageElement,
          Object(),
          StackTrace.current,
        );

        // The errorBuilder builds a ColoredBox(surfaceContainerHighest)
        // wrapping a broken-image icon tinted with onSurfaceVariant.
        final theme = Theme.of(imageElement);
        expect(placeholder, isA<ColoredBox>());
        final coloredBox = placeholder as ColoredBox;
        expect(coloredBox.color, theme.colorScheme.surfaceContainerHighest);

        final icon = coloredBox.child! as Icon;
        expect(icon.icon, Icons.broken_image_outlined);
        expect(icon.color, theme.colorScheme.onSurfaceVariant);
      },
    );

    testWidgets('shows error UI when errorCode is set', (tester) async {
      const errorState = ReferenceImageSelectionState(
        errorCode: ReferenceImageSelectionError.loadImagesFailed,
        errorDetail: 'Database error',
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            referenceImageSelectionControllerProvider(
              taskId: testTaskId,
            ).overrideWith(
              () => FakeReferenceImageSelectionController(errorState),
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

    testWidgets('tapping image tile calls toggleImageSelection', (
      tester,
    ) async {
      final stateWithImages = ReferenceImageSelectionState(
        availableImages: [
          buildTestReferenceImage('img-1'),
          buildTestReferenceImage('img-2'),
        ],
      );

      final trackingController = FakeReferenceImageSelectionController(
        stateWithImages,
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            referenceImageSelectionControllerProvider(
              taskId: testTaskId,
            ).overrideWith(
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

      // Scope to GestureDetectors within the GridView to avoid picking up
      // unrelated GestureDetectors from surrounding widgets.
      final gridFinder = find.byType(GridView);
      final gestureFinders = find.descendant(
        of: gridFinder,
        matching: find.byType(GestureDetector),
      );
      expect(gestureFinders, findsWidgets);

      // Tap the first GestureDetector in the grid
      await tester.tap(gestureFinders.first);
      await tester.pump();

      expect(trackingController.toggledImageIds, contains('img-1'));
    });

    testWidgets('tapping non-selectable image tile does not toggle', (
      tester,
    ) async {
      // All 5 slots taken, img-6 is not selected and cannot be toggled
      final stateAtMax = ReferenceImageSelectionState(
        availableImages: [
          buildTestReferenceImage('img-1'),
          buildTestReferenceImage('img-2'),
          buildTestReferenceImage('img-3'),
          buildTestReferenceImage('img-4'),
          buildTestReferenceImage('img-5'),
          buildTestReferenceImage('img-6'),
        ],
        selectedImageIds: const {
          'img-1',
          'img-2',
          'img-3',
          'img-4',
          'img-5',
        },
      );

      final trackingController = FakeReferenceImageSelectionController(
        stateAtMax,
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            referenceImageSelectionControllerProvider(
              taskId: testTaskId,
            ).overrideWith(
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

      // Scope to GestureDetectors within the GridView to avoid picking up
      // unrelated GestureDetectors from surrounding widgets.
      final gridFinder = find.byType(GridView);
      final gestureFinders = find.descendant(
        of: gridFinder,
        matching: find.byType(GestureDetector),
      );
      final sixthTile = gestureFinders.at(5);

      // Scroll into view since 6th tile is on the third grid row
      await tester.ensureVisible(sixthTile);
      await tester.pumpAndSettle();

      // Tap the last image tile (img-6, which is not selected and at max)
      await tester.tap(sixthTile);
      await tester.pump();

      // img-6 should NOT have been toggled since it's non-selectable
      expect(trackingController.toggledImageIds, isNot(contains('img-6')));
    });

    testWidgets('tapping already-selected image tile toggles deselection', (
      tester,
    ) async {
      final stateWithSelection = ReferenceImageSelectionState(
        availableImages: [
          buildTestReferenceImage('img-1'),
          buildTestReferenceImage('img-2'),
        ],
        selectedImageIds: const {'img-1'},
      );

      final trackingController = FakeReferenceImageSelectionController(
        stateWithSelection,
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            referenceImageSelectionControllerProvider(
              taskId: testTaskId,
            ).overrideWith(
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

    testWidgets(
      'renders without error in unbounded height context (modal regression)',
      (tester) async {
        final stateWithImages = ReferenceImageSelectionState(
          availableImages: [
            buildTestReferenceImage('img-1'),
            buildTestReferenceImage('img-2'),
            buildTestReferenceImage('img-3'),
          ],
          selectedImageIds: const {'img-1'},
        );

        // Wrap in SingleChildScrollView to simulate the unbounded vertical
        // constraints that WoltModalSheetPage provides.
        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              referenceImageSelectionControllerProvider(
                taskId: testTaskId,
              ).overrideWith(
                () => FakeReferenceImageSelectionController(stateWithImages),
              ),
            ],
            child: SingleChildScrollView(
              child: ReferenceImageSelectionWidget(
                taskId: testTaskId,
                onContinue: (_) {},
                onSkip: () {},
              ),
            ),
          ),
        );

        // Widget should render without layout errors
        expect(find.byType(GridView), findsOneWidget);
        expect(find.text('Select Reference Images'), findsOneWidget);
        expect(find.text('1/$kMaxReferenceImages'), findsOneWidget);
        expect(find.byType(LottiPrimaryButton), findsOneWidget);
      },
    );

    testWidgets('error state skip button calls onSkip', (tester) async {
      var skipCalled = false;
      const errorState = ReferenceImageSelectionState(
        errorCode: ReferenceImageSelectionError.loadImagesFailed,
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            referenceImageSelectionControllerProvider(
              taskId: testTaskId,
            ).overrideWith(
              () => FakeReferenceImageSelectionController(errorState),
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

    testWidgets('shows link icon on linked-task cover art images', (
      tester,
    ) async {
      final stateWithLinkedImage = ReferenceImageSelectionState(
        availableImages: [
          buildTestReferenceImage('direct-img'),
          buildTestReferenceImage('linked-img'),
        ],
        linkedTaskImageIds: const {'linked-img'},
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            referenceImageSelectionControllerProvider(
              taskId: testTaskId,
            ).overrideWith(
              () => FakeReferenceImageSelectionController(
                stateWithLinkedImage,
              ),
            ),
          ],
          child: ReferenceImageSelectionWidget(
            taskId: testTaskId,
            onContinue: (_) {},
            onSkip: () {},
          ),
        ),
      );

      await tester.pump();

      // Should show exactly one link icon (for the linked-task image)
      expect(find.byIcon(Icons.link_rounded), findsOneWidget);
    });

    testWidgets('does not show link icon on direct images', (tester) async {
      final stateWithDirectOnly = ReferenceImageSelectionState(
        availableImages: [
          buildTestReferenceImage('direct-1'),
          buildTestReferenceImage('direct-2'),
        ],
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            referenceImageSelectionControllerProvider(
              taskId: testTaskId,
            ).overrideWith(
              () => FakeReferenceImageSelectionController(stateWithDirectOnly),
            ),
          ],
          child: ReferenceImageSelectionWidget(
            taskId: testTaskId,
            onContinue: (_) {},
            onSkip: () {},
          ),
        ),
      );

      await tester.pump();

      // No link icons should appear for directly linked images
      expect(find.byIcon(Icons.link_rounded), findsNothing);
    });

    group('continue button label', () {
      testWidgets(
        'reflects the selection count: 0 → plain, 1 and 2 → counted',
        (
          tester,
        ) async {
          final images = [
            buildTestReferenceImage('img-1'),
            buildTestReferenceImage('img-2'),
          ];

          for (final (selected, expectedLabel) in [
            (<String>{}, 'Continue'),
            ({'img-1'}, 'Continue (1)'),
            ({'img-1', 'img-2'}, 'Continue (2)'),
          ]) {
            final state = ReferenceImageSelectionState(
              availableImages: images,
              selectedImageIds: selected,
            );

            await tester.pumpWidget(
              RiverpodWidgetTestBench(
                overrides: [
                  referenceImageSelectionControllerProvider(
                    taskId: testTaskId,
                  ).overrideWith(
                    () => FakeReferenceImageSelectionController(state),
                  ),
                ],
                child: ReferenceImageSelectionWidget(
                  taskId: testTaskId,
                  onContinue: (_) {},
                  onSkip: () {},
                ),
              ),
            );
            await tester.pump();

            expect(
              find.text(expectedLabel),
              findsOneWidget,
              reason: 'selected=$selected',
            );

            // Tear the scope down so the next iteration's override builds
            // a fresh controller (overrides are fixed at scope creation).
            await tester.pumpWidget(const SizedBox.shrink());
          }
        },
      );
    });
  });
}
