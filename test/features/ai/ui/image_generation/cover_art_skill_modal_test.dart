import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/reference_image_selection_controller.dart';
import 'package:lotti/features/ai/state/unified_ai_controller.dart';
import 'package:lotti/features/ai/ui/image_generation/cover_art_skill_modal.dart';
import 'package:lotti/features/ai/util/image_processing_utils.dart';
import 'package:lotti/get_it.dart';

import '../../../../test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testEntityId = 'test-entity-id';
  const testSkillId = 'test-skill-id';
  const testLinkedTaskId = 'test-task-id';

  late Directory mockDocumentsDirectory;

  setUp(() async {
    await getIt.reset();
    getIt.allowReassignment = true;

    mockDocumentsDirectory = Directory.systemTemp.createTempSync(
      'cover_art_skill_modal_test_',
    );
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

  group('CoverArtSkillModal', () {
    testWidgets('renders ReferenceImageSelectionWidget with correct taskId', (
      tester,
    ) async {
      const refImageState = ReferenceImageSelectionState(isLoading: true);

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            referenceImageSelectionControllerProvider(
              taskId: testLinkedTaskId,
            ).overrideWith(
              () => _MockReferenceImageSelectionController(refImageState),
            ),
          ],
          child: const _CoverArtSkillModalHost(
            entityId: testEntityId,
            skillId: testSkillId,
            linkedTaskId: testLinkedTaskId,
          ),
        ),
      );

      await tester.pump();

      // Loading state from reference image selection should be visible
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets(
      'auto-skips and triggers provider, shows progress view',
      (tester) async {
        TriggerSkillParams? capturedParams;

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              referenceImageSelectionControllerProvider(
                taskId: testLinkedTaskId,
              ).overrideWith(
                () => _MockReferenceImageSelectionController(
                  const ReferenceImageSelectionState(),
                ),
              ),
              triggerSkillProvider.overrideWith(
                (ref, params) {
                  capturedParams = params;
                  // Simulate running status
                  ref
                      .read(
                        inferenceStatusControllerProvider(
                          id: testLinkedTaskId,
                          aiResponseType: AiResponseType.imageGeneration,
                        ).notifier,
                      )
                      .setStatus(InferenceStatus.running);
                  return Future<void>.value();
                },
              ),
            ],
            child: const _CoverArtSkillModalHost(
              entityId: testEntityId,
              skillId: testSkillId,
              linkedTaskId: testLinkedTaskId,
            ),
          ),
        );

        // First pump renders the widget
        await tester.pump();
        // Second pump triggers the post-frame callback (auto-skip)
        await tester.pump();
        // Third pump renders the progress view
        await tester.pump();

        // Should have triggered with null reference images
        expect(capturedParams, isNotNull);
        expect(capturedParams!.referenceImages, isNull);

        // Should now show the progress view with "Generating image..." text
        expect(find.text('Generating image...'), findsOneWidget);
      },
    );

    testWidgets(
      'continue with images triggers provider and shows progress',
      (tester) async {
        TriggerSkillParams? capturedParams;
        final testDate = DateTime(2025);

        final stateWithImages = ReferenceImageSelectionState(
          availableImages: [
            JournalImage(
              meta: Metadata(
                id: 'img-1',
                createdAt: testDate,
                updatedAt: testDate,
                dateFrom: testDate,
                dateTo: testDate,
              ),
              data: ImageData(
                imageId: 'img-1',
                imageFile: 'test.jpg',
                imageDirectory: mockDocumentsDirectory.path,
                capturedAt: testDate,
              ),
            ),
          ],
          selectedImageIds: const {'img-1'},
        );

        const processedImages = [
          ProcessedReferenceImage(
            base64Data: 'base64data',
            mimeType: 'image/jpeg',
            originalId: 'img-1',
          ),
        ];

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              referenceImageSelectionControllerProvider(
                taskId: testLinkedTaskId,
              ).overrideWith(
                () => _MockReferenceImageSelectionControllerWithProcessing(
                  stateWithImages,
                  processedImages: processedImages,
                ),
              ),
              triggerSkillProvider.overrideWith(
                (ref, params) {
                  capturedParams = params;
                  ref
                      .read(
                        inferenceStatusControllerProvider(
                          id: testLinkedTaskId,
                          aiResponseType: AiResponseType.imageGeneration,
                        ).notifier,
                      )
                      .setStatus(InferenceStatus.running);
                  return Future<void>.value();
                },
              ),
            ],
            child: const _CoverArtSkillModalHost(
              entityId: testEntityId,
              skillId: testSkillId,
              linkedTaskId: testLinkedTaskId,
            ),
          ),
        );

        await tester.pump();

        // Tap the continue button
        await tester.tap(find.text('Continue (1)'));
        await tester.pump();
        await tester.pump();

        expect(capturedParams, isNotNull);
        expect(capturedParams!.referenceImages, hasLength(1));

        // Should show progress view
        expect(find.text('Generating image...'), findsOneWidget);
        // Should show reference image count
        expect(find.text('Using 1 reference image'), findsOneWidget);
      },
    );

    testWidgets('shows error state from reference image controller', (
      tester,
    ) async {
      const errorState = ReferenceImageSelectionState(
        errorCode: ReferenceImageSelectionError.loadImagesFailed,
        errorDetail: 'test error',
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            referenceImageSelectionControllerProvider(
              taskId: testLinkedTaskId,
            ).overrideWith(
              () => _MockReferenceImageSelectionController(errorState),
            ),
          ],
          child: const _CoverArtSkillModalHost(
            entityId: testEntityId,
            skillId: testSkillId,
            linkedTaskId: testLinkedTaskId,
          ),
        ),
      );

      await tester.pump();

      // Error icon should be visible
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });

    testWidgets(
      'skip button triggers provider and shows progress view',
      (tester) async {
        TriggerSkillParams? capturedParams;

        const errorState = ReferenceImageSelectionState(
          errorCode: ReferenceImageSelectionError.loadImagesFailed,
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              referenceImageSelectionControllerProvider(
                taskId: testLinkedTaskId,
              ).overrideWith(
                () => _MockReferenceImageSelectionController(errorState),
              ),
              triggerSkillProvider.overrideWith(
                (ref, params) {
                  capturedParams = params;
                  ref
                      .read(
                        inferenceStatusControllerProvider(
                          id: testLinkedTaskId,
                          aiResponseType: AiResponseType.imageGeneration,
                        ).notifier,
                      )
                      .setStatus(InferenceStatus.running);
                  return Future<void>.value();
                },
              ),
            ],
            child: const _CoverArtSkillModalHost(
              entityId: testEntityId,
              skillId: testSkillId,
              linkedTaskId: testLinkedTaskId,
            ),
          ),
        );

        await tester.pump();

        // Tap the skip button from error state
        await tester.tap(find.text('Skip'));
        await tester.pump();

        expect(capturedParams, isNotNull);
        expect(capturedParams!.referenceImages, isNull);

        // Should show progress view
        expect(find.text('Generating image...'), findsOneWidget);
      },
    );

    testWidgets('passes categoryId through to widget', (tester) async {
      const refImageState = ReferenceImageSelectionState(isLoading: true);

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            referenceImageSelectionControllerProvider(
              taskId: testLinkedTaskId,
            ).overrideWith(
              () => _MockReferenceImageSelectionController(refImageState),
            ),
          ],
          child: const _CoverArtSkillModalHost(
            entityId: testEntityId,
            skillId: testSkillId,
            linkedTaskId: testLinkedTaskId,
            categoryId: 'cat-123',
          ),
        ),
      );

      await tester.pump();

      final modal = tester.widget<CoverArtSkillModal>(
        find.byType(CoverArtSkillModal),
      );
      expect(modal.categoryId, 'cat-123');
      expect(modal.entityId, testEntityId);
      expect(modal.skillId, testSkillId);
      expect(modal.linkedTaskId, testLinkedTaskId);
    });

    testWidgets('progress view shows completion when status becomes idle', (
      tester,
    ) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            referenceImageSelectionControllerProvider(
              taskId: testLinkedTaskId,
            ).overrideWith(
              () => _MockReferenceImageSelectionController(
                const ReferenceImageSelectionState(),
              ),
            ),
            triggerSkillProvider.overrideWith(
              (ref, params) {
                // Set running first so _hasObservedRunning becomes true,
                // then idle to simulate completion.
                ref
                    .read(
                      inferenceStatusControllerProvider(
                        id: testLinkedTaskId,
                        aiResponseType: AiResponseType.imageGeneration,
                      ).notifier,
                    )
                    .setStatus(InferenceStatus.running);
                return Future<void>.value();
              },
            ),
          ],
          child: const _CoverArtSkillModalHost(
            entityId: testEntityId,
            skillId: testSkillId,
            linkedTaskId: testLinkedTaskId,
          ),
        ),
      );

      // Auto-skip flow — trigger generation
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // Now transition to idle (completion)
      final container = ProviderScope.containerOf(
        tester.element(find.byType(_CoverArtSkillModalHost)),
      );
      container
          .read(
            inferenceStatusControllerProvider(
              id: testLinkedTaskId,
              aiResponseType: AiResponseType.imageGeneration,
            ).notifier,
          )
          .setStatus(InferenceStatus.idle);
      await tester.pump();

      // Should show completion state
      expect(find.text('Cover art ready!'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    });

    testWidgets('progress view shows error when status becomes error', (
      tester,
    ) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            referenceImageSelectionControllerProvider(
              taskId: testLinkedTaskId,
            ).overrideWith(
              () => _MockReferenceImageSelectionController(
                const ReferenceImageSelectionState(),
              ),
            ),
            triggerSkillProvider.overrideWith(
              (ref, params) {
                // Set running first so _hasObservedRunning becomes true.
                ref
                    .read(
                      inferenceStatusControllerProvider(
                        id: testLinkedTaskId,
                        aiResponseType: AiResponseType.imageGeneration,
                      ).notifier,
                    )
                    .setStatus(InferenceStatus.running);
                return Future<void>.value();
              },
            ),
          ],
          child: const _CoverArtSkillModalHost(
            entityId: testEntityId,
            skillId: testSkillId,
            linkedTaskId: testLinkedTaskId,
          ),
        ),
      );

      await tester.pump();
      await tester.pump();
      await tester.pump();

      // Now transition to error
      final container = ProviderScope.containerOf(
        tester.element(find.byType(_CoverArtSkillModalHost)),
      );
      container
          .read(
            inferenceStatusControllerProvider(
              id: testLinkedTaskId,
              aiResponseType: AiResponseType.imageGeneration,
            ).notifier,
          )
          .setStatus(InferenceStatus.error);
      await tester.pump();

      // Should show error state
      expect(find.text('Failed to generate image'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });
  });
}

/// Wrapper that provides a [WidgetRef] to [CoverArtSkillModal] via a
/// [Consumer] widget, since [WidgetRef] cannot be instantiated directly
/// in tests.
class _CoverArtSkillModalHost extends ConsumerWidget {
  const _CoverArtSkillModalHost({
    required this.entityId,
    required this.skillId,
    required this.linkedTaskId,
    this.categoryId,
  });

  final String entityId;
  final String skillId;
  final String linkedTaskId;
  final String? categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CoverArtSkillModal(
      entityId: entityId,
      skillId: skillId,
      linkedTaskId: linkedTaskId,
      categoryId: categoryId,
      parentRef: ref,
    );
  }
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

/// Mock controller that returns processed images for testing.
class _MockReferenceImageSelectionControllerWithProcessing
    extends ReferenceImageSelectionController {
  _MockReferenceImageSelectionControllerWithProcessing(
    this._fixedState, {
    this.processedImages = const [],
  });

  final ReferenceImageSelectionState _fixedState;
  final List<ProcessedReferenceImage> processedImages;

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
    return processedImages;
  }
}
