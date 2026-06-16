import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/image_generation_error_controller.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/reference_image_selection_controller.dart';
import 'package:lotti/features/ai/state/skill_trigger_providers.dart';
import 'package:lotti/features/ai/ui/image_generation/cover_art_skill_modal.dart';
import 'package:lotti/features/ai/util/image_processing_utils.dart';
import 'package:lotti/get_it.dart';

import '../../../../test_helper.dart';
import '../../../../widget_test_utils.dart';
import 'test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testEntityId = 'test-entity-id';
  const testSkillId = 'test-skill-id';
  const testLinkedTaskId = 'test-task-id';

  late Directory mockDocumentsDirectory;

  setUp(() async {
    await setUpTestGetIt();

    mockDocumentsDirectory = Directory.systemTemp.createTempSync(
      'cover_art_skill_modal_test_',
    );
    getIt.registerSingleton<Directory>(mockDocumentsDirectory);
  });

  tearDown(() async {
    await tearDownTestGetIt();
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
      final controller = FakeReferenceImageSelectionController(refImageState);

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            referenceImageSelectionControllerProvider(
              taskId: testLinkedTaskId,
            ).overrideWith(
              () => controller,
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

      // The modal must wire the *linkedTaskId* (not entityId) through to the
      // reference-image controller, so the controller is built for the task
      // whose images we want to load.
      expect(controller.builtWithTaskId, testLinkedTaskId);

      // Loading state from reference image selection should be visible.
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
                () => FakeReferenceImageSelectionController(
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

        // pump 1: build (registers the auto-skip post-frame callback);
        // pump 2: post-frame fires → onSkip → setState(_isGenerating);
        // pump 3: rebuild renders the progress view.
        await tester.pump();
        await tester.pump();
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
                () => FakeReferenceImageSelectionController(
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
              () => FakeReferenceImageSelectionController(errorState),
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
                () => FakeReferenceImageSelectionController(errorState),
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

    // The former 'passes categoryId through to widget' test asserted a
    // widget property that nothing ever read — the parameter was dead
    // plumbing and has been removed from CoverArtSkillModal entirely.

    testWidgets('progress view shows completion when status becomes idle', (
      tester,
    ) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            referenceImageSelectionControllerProvider(
              taskId: testLinkedTaskId,
            ).overrideWith(
              () => FakeReferenceImageSelectionController(
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

    testWidgets(
      'progress view watches linkedTaskId status, not entityId',
      (tester) async {
        // entityId and linkedTaskId are deliberately distinct so that watching
        // the wrong one would change the asserted outcome.
        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              referenceImageSelectionControllerProvider(
                taskId: testLinkedTaskId,
              ).overrideWith(
                () => FakeReferenceImageSelectionController(
                  const ReferenceImageSelectionState(),
                ),
              ),
              triggerSkillProvider.overrideWith(
                (ref, params) {
                  // Generation runs under linkedTaskId.
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

        // Auto-skip flow — trigger generation (running observed on
        // linkedTaskId).
        await tester.pump();
        await tester.pump();
        await tester.pump();
        expect(find.text('Generating image...'), findsOneWidget);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(_CoverArtSkillModalHost)),
        );

        // Drive the *entityId* status to idle. If the progress view watched
        // entityId it would now show completion — it must NOT, because the
        // generation it tracks runs under linkedTaskId.
        container
            .read(
              inferenceStatusControllerProvider(
                id: testEntityId,
                aiResponseType: AiResponseType.imageGeneration,
              ).notifier,
            )
            .setStatus(InferenceStatus.idle);
        await tester.pump();

        expect(find.text('Cover art ready!'), findsNothing);
        expect(find.text('Generating image...'), findsOneWidget);

        // Driving the linkedTaskId status to idle DOES surface completion.
        container
            .read(
              inferenceStatusControllerProvider(
                id: testLinkedTaskId,
                aiResponseType: AiResponseType.imageGeneration,
              ).notifier,
            )
            .setStatus(InferenceStatus.idle);
        await tester.pump();

        expect(find.text('Cover art ready!'), findsOneWidget);
      },
    );

    testWidgets('progress view shows error when status becomes error', (
      tester,
    ) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            referenceImageSelectionControllerProvider(
              taskId: testLinkedTaskId,
            ).overrideWith(
              () => FakeReferenceImageSelectionController(
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

    testWidgets(
      'shows the provider reason verbatim under a localized rejected title',
      (tester) async {
        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              referenceImageSelectionControllerProvider(
                taskId: testLinkedTaskId,
              ).overrideWith(
                () => FakeReferenceImageSelectionController(
                  const ReferenceImageSelectionState(),
                ),
              ),
              triggerSkillProvider.overrideWith((ref, params) {
                ref
                    .read(
                      inferenceStatusControllerProvider(
                        id: testLinkedTaskId,
                        aiResponseType: AiResponseType.imageGeneration,
                      ).notifier,
                    )
                    .setStatus(InferenceStatus.running);
                return Future<void>.value();
              }),
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

        final container = ProviderScope.containerOf(
          tester.element(find.byType(_CoverArtSkillModalHost)),
        );
        // Provider rejection: error status + a verbatim provider reason.
        container
            .read(
              imageGenerationErrorControllerProvider(
                id: testLinkedTaskId,
              ).notifier,
            )
            .setError('PROHIBITED_CONTENT');
        container
            .read(
              inferenceStatusControllerProvider(
                id: testLinkedTaskId,
                aiResponseType: AiResponseType.imageGeneration,
              ).notifier,
            )
            .setStatus(InferenceStatus.error);
        await tester.pump();

        // Localized frame attributing the block to the provider...
        expect(
          find.text('The image provider rejected this request'),
          findsOneWidget,
        );
        // ...plus the provider's verbatim reason, not an invented description.
        expect(find.text('PROHIBITED_CONTENT'), findsOneWidget);
        expect(find.text('Failed to generate image'), findsNothing);
        expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      },
    );
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
  });

  final String entityId;
  final String skillId;
  final String linkedTaskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CoverArtSkillModal(
      entityId: entityId,
      skillId: skillId,
      linkedTaskId: linkedTaskId,
      parentRef: ref,
    );
  }
}
