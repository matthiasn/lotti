// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/ollama_inference_repository.dart';
import 'package:lotti/features/ai/repository/unified_ai_inference_repository.dart';
import 'package:lotti/features/ai/state/active_inference_controller.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart'
    show
        AiConfigByTypeController,
        aiConfigByIdProvider,
        aiConfigByTypeControllerProvider;
import 'package:lotti/features/ai/state/skill_trigger_providers.dart';
import 'package:lotti/features/ai/state/unified_ai_controller.dart';
import 'package:lotti/features/ai/ui/animation/ai_running_animation.dart';
import 'package:lotti/features/ai/ui/unified_ai_progress_view.dart';
import 'package:lotti/features/ai/ui/widgets/ai_error_display.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart'
    show categoryRepositoryProvider;
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart'
    show
        makeTestableWidgetNoScroll,
        resolveTestTheme,
        setUpTestGetIt,
        tearDownTestGetIt;
import '../test_utils.dart';

/// Helper to create override for UnifiedAiController with a specific state.
Override unifiedAiControllerOverride(UnifiedAiState initialState) {
  return unifiedAiControllerProvider.overrideWithBuild(
    (ref, params) => initialState,
  );
}

/// A single-shot stream override for AiConfigByTypeController that uses
/// Stream.value so that provider.future resolves immediately. Needed when
/// testing code that calls ref.read(provider.future) inside an async method
/// driven by widget interaction (e.g. _installModel).
class _ImmediateAiConfigByTypeController extends AiConfigByTypeController {
  _ImmediateAiConfigByTypeController(this._configs);
  final List<AiConfig> _configs;

  @override
  Stream<List<AiConfig>> build() => Stream.value(_configs);
}

class _TestInferenceStatusController extends InferenceStatusController {
  _TestInferenceStatusController(this.initialStatus);

  final InferenceStatus initialStatus;

  @override
  InferenceStatus build() {
    return initialStatus;
  }
}

void main() {
  late AiConfigPrompt testPromptConfig;
  late MockUnifiedAiInferenceRepository mockRepository;
  late MockCloudInferenceRepository mockCloudRepository;
  late MockCategoryRepository mockCategoryRepository;

  setUpAll(() {
    registerFallbackValue(InferenceStatus.idle);
    registerFallbackValue(StackTrace.current);
    registerFallbackValue(FakeAiConfigPrompt());
    registerFallbackValue(fallbackJournalEntity);
  });

  setUp(() async {
    final testDate = DateTime(2024, 3, 15, 10, 30);
    testPromptConfig =
        AiConfig.prompt(
              id: 'test-prompt-1',
              name: 'Test Prompt',
              systemMessage: 'System message',
              userMessage: 'Test prompt text',
              defaultModelId: 'model-1',
              modelIds: ['model-1'],
              createdAt: testDate,
              useReasoning: false,
              requiredInputData: [InputDataType.task],
              aiResponseType: AiResponseType.taskSummary,
              description: 'A test prompt for testing purposes',
            )
            as AiConfigPrompt;

    mockRepository = MockUnifiedAiInferenceRepository();
    mockCloudRepository = MockCloudInferenceRepository();
    mockCategoryRepository = MockCategoryRepository();

    // Registers core services (including a test-env DomainLogger) in GetIt.
    await setUpTestGetIt();

    // Mock repository getActivePromptsForContext
    when(
      () => mockRepository.getActivePromptsForContext(
        entity: any(named: 'entity'),
      ),
    ).thenAnswer((_) async => [testPromptConfig]);

    // Mock category repository
    when(
      () => mockCategoryRepository.watchCategory(any()),
    ).thenAnswer((_) => Stream.value(null));
  });

  tearDown(tearDownTestGetIt);

  /// Thin wrapper over the central [makeTestableWidgetNoScroll] (DS theme,
  /// localizations, phone media query) that adds the shared repository
  /// overrides and a host Scaffold.
  Widget buildTestWidget(
    Widget child, {
    List<Override> overrides = const [],
  }) {
    return makeTestableWidgetNoScroll(
      Scaffold(body: child),
      overrides: [
        unifiedAiInferenceRepositoryProvider.overrideWithValue(mockRepository),
        cloudInferenceRepositoryProvider.overrideWithValue(mockCloudRepository),
        categoryRepositoryProvider.overrideWithValue(mockCategoryRepository),
        ...overrides,
      ],
    );
  }

  group('UnifiedAiProgressContent - Basic UI States', () {
    const testEntityId = 'test-entity-1';
    const testPromptId = 'test-prompt-1';

    testWidgets('shows loading indicator when prompt config is loading', (
      tester,
    ) async {
      final completer = Completer<AiConfig?>();

      await tester.pumpWidget(
        buildTestWidget(
          const UnifiedAiProgressContent(
            entityId: testEntityId,
            promptId: testPromptId,
          ),
          overrides: [
            aiConfigByIdProvider(testPromptId).overrideWith(
              (ref) => completer.future,
            ),
          ],
        ),
      );

      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete to avoid hanging test
      completer.complete(testPromptConfig);
    });

    testWidgets('shows error when prompt config fails to load', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const UnifiedAiProgressContent(
            entityId: testEntityId,
            promptId: testPromptId,
          ),
          overrides: [
            aiConfigByIdProvider(testPromptId).overrideWith(
              (ref) => Future.error('Failed to load config'),
            ),
          ],
        ),
      );

      // Bounded pumps were tried here and fail — the async error needs the
      // full settle before the error branch renders.
      await tester.pumpAndSettle();

      expect(find.textContaining('Error loading prompt'), findsOneWidget);
    });

    testWidgets('shows invalid config message when config is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          const UnifiedAiProgressContent(
            entityId: testEntityId,
            promptId: testPromptId,
          ),
          overrides: [
            aiConfigByIdProvider(testPromptId).overrideWith(
              (ref) => Future.value(),
            ),
          ],
        ),
      );

      await tester.pump();

      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Invalid prompt configuration'), findsOneWidget);
    });

    testWidgets('shows invalid config message when config is wrong type', (
      tester,
    ) async {
      final invalidConfig = AiConfig.model(
        id: 'model-1',
        name: 'Test Model',
        providerModelId: 'provider-model-1',
        inferenceProviderId: 'provider-1',
        createdAt: DateTime(2024, 3, 15, 10, 30),
        inputModalities: [Modality.text],
        outputModalities: [Modality.text],
        isReasoningModel: false,
      );

      await tester.pumpWidget(
        buildTestWidget(
          const UnifiedAiProgressContent(
            entityId: testEntityId,
            promptId: testPromptId,
          ),
          overrides: [
            aiConfigByIdProvider(testPromptId).overrideWith(
              (ref) => Future.value(invalidConfig),
            ),
          ],
        ),
      );

      await tester.pump();

      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Invalid prompt configuration'), findsOneWidget);
    });
  });

  group('UnifiedAiProgressContent - Inference Behavior', () {
    const testEntityId = 'test-entity-1';
    const testPromptId = 'test-prompt-1';

    testWidgets('does NOT trigger inference when showExisting is true', (
      tester,
    ) async {
      var inferenceTriggered = false;

      when(
        () => mockRepository.runInference(
          entityId: any(named: 'entityId'),
          promptConfig: any(named: 'promptConfig'),
          onProgress: any(named: 'onProgress'),
          onStatusChange: any(named: 'onStatusChange'),
        ),
      ).thenAnswer((invocation) async {
        inferenceTriggered = true;
      });

      await tester.pumpWidget(
        buildTestWidget(
          const UnifiedAiProgressContent(
            entityId: testEntityId,
            promptId: testPromptId,
            showExisting: true,
          ),
          overrides: [
            aiConfigByIdProvider(testPromptId).overrideWith(
              (ref) => Future.value(testPromptConfig),
            ),
          ],
        ),
      );

      await tester.pump();

      await tester.pump(const Duration(milliseconds: 300));

      // Give some time for any async operations
      await tester.pump(const Duration(milliseconds: 100));

      expect(inferenceTriggered, isFalse);
    });

    testWidgets(
      'shouldTriggerOnInit=false suppresses the trigger but still subscribes '
      'to an existing inference',
      (tester) async {
        // shouldTriggerOnInit=false with showExisting=false takes initState's
        // else branch: no triggerNewInference call, but it DOES run
        // _subscribeToExistingInference. Rendering still uses the controller
        // state (not _streamProgress), unlike showExisting=true.
        var triggerCount = 0;

        final container = ProviderContainer(
          overrides: [
            unifiedAiInferenceRepositoryProvider.overrideWithValue(
              mockRepository,
            ),
            aiConfigByIdProvider(testPromptId).overrideWith(
              (ref) async => testPromptConfig,
            ),
            categoryRepositoryProvider.overrideWithValue(
              mockCategoryRepository,
            ),
            triggerNewInferenceProvider.overrideWith((ref, arg) async {
              triggerCount++;
            }),
          ],
        );

        // Start an active inference so _subscribeToExistingInference finds
        // a progress stream to attach to.
        final activeNotifier = container.read(
          activeInferenceControllerProvider((
            entityId: testEntityId,
            aiResponseType: AiResponseType.taskSummary,
          )).notifier,
        )..startInference(promptId: testPromptId);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: resolveTestTheme(),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
              ],
              home: const Scaffold(
                body: UnifiedAiProgressContent(
                  entityId: testEntityId,
                  promptId: testPromptId,
                  shouldTriggerOnInit: false,
                ),
              ),
            ),
          ),
        );

        // Post-frame callback + async subscribe.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // No inference was triggered despite showExisting being false.
        expect(triggerCount, 0);

        // The else branch subscribed to the active inference's broadcast
        // progress stream.
        final activeData = container.read(
          activeInferenceControllerProvider((
            entityId: testEntityId,
            aiResponseType: AiResponseType.taskSummary,
          )),
        );
        expect(activeData!.progressStreamController.hasListener, isTrue);

        // Streamed progress is NOT rendered: with showExisting=false the
        // build uses controllerState.message, not _streamProgress.
        activeNotifier.updateProgress('Streamed but hidden');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.textContaining('Streamed but hidden'), findsNothing);

        // Unmount and dispose in-body so cacheFor timers are cancelled
        // before the pending-timer check.
        await tester.pumpWidget(const SizedBox());
        container.dispose();
      },
    );
  });

  group('UnifiedAiProgressContent - showExisting and activeInference', () {
    testWidgets('subscribes to existing inference when showExisting is true', (
      tester,
    ) async {
      // This test ensures the _subscribeToExistingInference method is called
      // when showExisting is true
      final container = ProviderContainer(
        overrides: [
          unifiedAiInferenceRepositoryProvider.overrideWithValue(
            mockRepository,
          ),
          aiConfigByIdProvider('test-prompt-1').overrideWith(
            (ref) async => testPromptConfig,
          ),
          categoryRepositoryProvider.overrideWithValue(
            mockCategoryRepository,
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: resolveTestTheme(),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
            ],
            home: const Scaffold(
              body: UnifiedAiProgressContent(
                entityId: 'test-entity',
                promptId: 'test-prompt-1',
                showExisting: true,
              ),
            ),
          ),
        ),
      );

      // Wait for post frame callback
      await tester.pump();

      // Verify the subscription logic was triggered
      expect(find.byType(UnifiedAiProgressContent), findsOneWidget);

      // Unmount the tree and dispose the container inside the test body so
      // the cacheFor keep-alive timers are cancelled before the binding's
      // pending-timer check.
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });

    testWidgets(
      'retry button re-triggers inference through triggerNewInferenceProvider',
      (tester) async {
        // Wide surface so AiErrorDisplay's card fits without overflowing.
        tester.view
          ..physicalSize = const Size(1200, 900)
          ..devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        var retriggerCount = 0;

        await tester.pumpWidget(
          buildTestWidget(
            const UnifiedAiProgressContent(
              entityId: 'test-entity',
              promptId: 'test-prompt-1',
              shouldTriggerOnInit: false,
            ),
            overrides: [
              aiConfigByIdProvider('test-prompt-1').overrideWith(
                (ref) async => testPromptConfig,
              ),
              unifiedAiControllerOverride(
                const UnifiedAiState(message: 'Upstream server exploded'),
              ),
              inferenceStatusControllerProvider((
                id: 'test-entity',
                aiResponseType: AiResponseType.taskSummary,
              )).overrideWith(
                () => _TestInferenceStatusController(InferenceStatus.error),
              ),
              triggerNewInferenceProvider.overrideWith((ref, arg) async {
                retriggerCount++;
              }),
            ],
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // The error state renders AiErrorDisplay with its retry button.
        final retryButton = find.text('Try Again');
        expect(retryButton, findsOneWidget);

        await tester.ensureVisible(retryButton);
        await tester.tap(retryButton);
        await tester.pump();

        expect(retriggerCount, 1);
      },
    );

    testWidgets('prevents duplicate inference triggers', (tester) async {
      // The _hasTriggeredInference flag must hold the post-frame trigger to
      // exactly one provider invocation no matter how many frames pass.
      var triggerCount = 0;

      await tester.pumpWidget(
        buildTestWidget(
          const UnifiedAiProgressContent(
            entityId: 'test-entity',
            promptId: 'test-prompt-1',
          ),
          overrides: [
            aiConfigByIdProvider('test-prompt-1').overrideWith(
              (ref) async => testPromptConfig,
            ),
            triggerNewInferenceProvider.overrideWith((ref, arg) async {
              triggerCount++;
            }),
          ],
        ),
      );

      // Pump multiple times to ensure no duplicate triggers
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(UnifiedAiProgressContent), findsOneWidget);
      expect(triggerCount, 1);
    });

    testWidgets('handles model not installed error', (tester) async {
      // This test checks the _modelNotInstalledRegex pattern matching
      final container = ProviderContainer(
        overrides: [
          unifiedAiInferenceRepositoryProvider.overrideWithValue(
            mockRepository,
          ),
          aiConfigByIdProvider('test-prompt-1').overrideWith(
            (ref) async => testPromptConfig,
          ),
          categoryRepositoryProvider.overrideWithValue(
            mockCategoryRepository,
          ),
        ],
      );

      // Set error state with model not installed message
      container
          .read(
            inferenceStatusControllerProvider((
              id: 'test-entity',
              aiResponseType: AiResponseType.taskSummary,
            )).notifier,
          )
          .setStatus(InferenceStatus.error);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: resolveTestTheme(),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
            ],
            home: const Scaffold(
              body: UnifiedAiProgressContent(
                entityId: 'test-entity',
                promptId: 'test-prompt-1',
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      await tester.pump(const Duration(milliseconds: 300));

      // Verify the widget handles the error properly
      expect(find.byType(UnifiedAiProgressContent), findsOneWidget);

      // Unmount and dispose in-body so cacheFor timers are cancelled before
      // the pending-timer check.
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });

    testWidgets('cleans up stream subscription on dispose', (tester) async {
      // This test ensures _progressSubscription is properly canceled
      final container = ProviderContainer(
        overrides: [
          unifiedAiInferenceRepositoryProvider.overrideWithValue(
            mockRepository,
          ),
          aiConfigByIdProvider('test-prompt-1').overrideWith(
            (ref) async => testPromptConfig,
          ),
          categoryRepositoryProvider.overrideWithValue(
            mockCategoryRepository,
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: resolveTestTheme(),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
            ],
            home: const Scaffold(
              body: UnifiedAiProgressContent(
                entityId: 'test-entity',
                promptId: 'test-prompt-1',
                showExisting: true,
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Remove the widget to trigger dispose
      await tester.pumpWidget(
        MaterialApp(
          theme: resolveTestTheme(),
          home: const Scaffold(
            body: SizedBox(),
          ),
        ),
      );

      await tester.pump();

      await tester.pump(const Duration(milliseconds: 300));

      // The dispose method should have cleaned up the subscription
      expect(find.byType(UnifiedAiProgressContent), findsNothing);

      // Dispose the container in-body so cacheFor timers are cancelled
      // before the pending-timer check.
      container.dispose();
    });
  });

  group('UnifiedAiProgressContent - Error dialogs', () {
    const entityId = 'dialog-entity';
    const promptId = 'dialog-prompt';

    testWidgets('shows Ollama install dialog for model not installed error', (
      tester,
    ) async {
      final ollamaProvider = AiTestDataFactory.createTestProvider(
        id: 'ollama-provider',
        name: 'Ollama Provider',
        type: InferenceProviderType.ollama,
        baseUrl: 'http://localhost:11435/',
      );

      await tester.pumpWidget(
        buildTestWidget(
          const UnifiedAiProgressContent(
            entityId: entityId,
            promptId: promptId,
          ),
          overrides: [
            aiConfigByIdProvider(promptId).overrideWith(
              (ref) async => testPromptConfig,
            ),
            aiConfigByTypeControllerProvider(
              AiConfigType.inferenceProvider,
            ).overrideWith(
              () => MockAiConfigByTypeController([ollamaProvider]),
            ),
            unifiedAiControllerOverride(
              const UnifiedAiState(
                message: '',
                error: ModelNotInstalledException('llama3'),
              ),
            ),
            inferenceStatusControllerProvider((
              id: entityId,
              aiResponseType: testPromptConfig.aiResponseType,
            )).overrideWith(
              () => _TestInferenceStatusController(InferenceStatus.error),
            ),
            triggerNewInferenceProvider.overrideWith((ref, arg) async {}),
          ],
        ),
      );

      // Bounded pumps let the FutureBuilder complete deterministically.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(OllamaModelInstallDialog), findsOneWidget);
    });

    testWidgets('uses string fallback to show Ollama install dialog', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          const UnifiedAiProgressContent(
            entityId: entityId,
            promptId: promptId,
          ),
          overrides: [
            aiConfigByIdProvider(promptId).overrideWith(
              (ref) async => testPromptConfig,
            ),
            aiConfigByTypeControllerProvider(
              AiConfigType.inferenceProvider,
            ).overrideWith(
              () => MockAiConfigByTypeController(const <AiConfig>[]),
            ),
            unifiedAiControllerOverride(
              const UnifiedAiState(
                message:
                    'Model "llama3" is not installed. Please install it first.',
              ),
            ),
            inferenceStatusControllerProvider((
              id: entityId,
              aiResponseType: testPromptConfig.aiResponseType,
            )).overrideWith(
              () => _TestInferenceStatusController(InferenceStatus.error),
            ),
            triggerNewInferenceProvider.overrideWith((ref, arg) async {}),
          ],
        ),
      );

      await tester.pump();

      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(OllamaModelInstallDialog), findsOneWidget);
    });

    testWidgets('shows running animation when inference is in progress', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          const UnifiedAiProgressContent(
            entityId: entityId,
            promptId: promptId,
          ),
          overrides: [
            aiConfigByIdProvider(promptId).overrideWith(
              (ref) async => testPromptConfig,
            ),
            aiConfigByTypeControllerProvider(
              AiConfigType.inferenceProvider,
            ).overrideWith(
              () => MockAiConfigByTypeController(const <AiConfig>[]),
            ),
            unifiedAiControllerOverride(
              const UnifiedAiState(message: ''),
            ),
            inferenceStatusControllerProvider((
              id: entityId,
              aiResponseType: testPromptConfig.aiResponseType,
            )).overrideWith(
              () => _TestInferenceStatusController(InferenceStatus.running),
            ),
            triggerNewInferenceProvider.overrideWith((ref, arg) async {}),
          ],
        ),
      );

      await tester.pump();

      expect(find.byType(AiRunningAnimationWrapper), findsOneWidget);
    });
  });

  group('UnifiedAiProgressUtils', () {
    testWidgets('progressPage creates valid modal page', (tester) async {
      final prompt =
          AiConfig.prompt(
                id: 'test-prompt',
                name: 'Test Prompt Title',
                systemMessage: 'System message',
                userMessage: 'Test prompt text',
                defaultModelId: 'model-1',
                modelIds: ['model-1'],
                createdAt: DateTime(2024, 3, 15, 10, 30),
                useReasoning: false,
                requiredInputData: [InputDataType.task],
                aiResponseType: AiResponseType.taskSummary,
                description: 'Test description',
              )
              as AiConfigPrompt;

      // Build the widget and inspect the returned page wiring.
      await tester.pumpWidget(
        buildTestWidget(
          Builder(
            builder: (context) {
              final page = UnifiedAiProgressUtils.progressPage(
                context: context,
                prompt: prompt,
                entityId: 'test-entity',
              );

              // Top-bar title carries the prompt name.
              final titlePadding = page.topBarTitle! as Padding;
              expect((titlePadding.child! as Text).data, 'Test Prompt Title');

              // Sticky action bar hosts the running animation keyed to this
              // entity and the prompt's response type.
              final align = page.stickyActionBar! as Align;
              final animation = align.child! as AiRunningAnimationWrapper;
              expect(animation.entryId, 'test-entity');
              expect(
                animation.responseTypes,
                {AiResponseType.taskSummary},
              );

              // The single content sliver wraps UnifiedAiProgressContent
              // wired to the entity + prompt, triggering on open.
              final slivers = page.mainContentSliversBuilder(context);
              final adapter = slivers.single as SliverToBoxAdapter;
              final content = adapter.child! as UnifiedAiProgressContent;
              expect(content.entityId, 'test-entity');
              expect(content.promptId, 'test-prompt');
              expect(content.shouldTriggerOnInit, isTrue);
              expect(content.showExisting, isFalse);

              return const Center(child: Text('Test'));
            },
          ),
        ),
      );

      // Verify the builder ran successfully
      expect(find.text('Test'), findsOneWidget);
    });
  });

  group('UnifiedAiProgressContent - Image Prompt Generation Copy Button', () {
    const entityId = 'image-prompt-entity';
    const promptId = 'image-prompt-id';

    testWidgets('shows copy button for image prompt generation with result', (
      tester,
    ) async {
      final imagePromptConfig =
          AiConfig.prompt(
                id: promptId,
                name: 'Image Prompt',
                systemMessage: 'System message',
                userMessage: 'Generate image prompt',
                defaultModelId: 'model-1',
                modelIds: ['model-1'],
                createdAt: DateTime(2024, 3, 15, 10, 30),
                useReasoning: false,
                requiredInputData: [InputDataType.task],
                aiResponseType: AiResponseType.imagePromptGeneration,
                description: 'Generate image prompts',
              )
              as AiConfigPrompt;

      await tester.pumpWidget(
        buildTestWidget(
          const UnifiedAiProgressContent(
            entityId: entityId,
            promptId: promptId,
          ),
          overrides: [
            aiConfigByIdProvider(promptId).overrideWith(
              (ref) async => imagePromptConfig,
            ),
            aiConfigByTypeControllerProvider(
              AiConfigType.inferenceProvider,
            ).overrideWith(
              () => MockAiConfigByTypeController(const <AiConfig>[]),
            ),
            unifiedAiControllerOverride(
              const UnifiedAiState(
                message: '''
## Summary
A beautiful sunset over mountains.

## Prompt
Digital painting of a vibrant sunset over misty mountains, warm orange and purple tones, atmospheric, cinematic lighting, 4K --ar 16:9''',
              ),
            ),
            inferenceStatusControllerProvider((
              id: entityId,
              aiResponseType: AiResponseType.imagePromptGeneration,
            )).overrideWith(
              () => _TestInferenceStatusController(InferenceStatus.idle),
            ),
            triggerNewInferenceProvider.overrideWith((ref, arg) async {}),
          ],
        ),
      );

      await tester.pump();

      await tester.pump(const Duration(milliseconds: 300));

      // Should show copy button for image prompt generation
      expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
    });

    testWidgets('shows copy button for regular prompt generation with result', (
      tester,
    ) async {
      final promptGenConfig =
          AiConfig.prompt(
                id: promptId,
                name: 'Coding Prompt',
                systemMessage: 'System message',
                userMessage: 'Generate coding prompt',
                defaultModelId: 'model-1',
                modelIds: ['model-1'],
                createdAt: DateTime(2024, 3, 15, 10, 30),
                useReasoning: false,
                requiredInputData: [InputDataType.task],
                aiResponseType: AiResponseType.promptGeneration,
                description: 'Generate coding prompts',
              )
              as AiConfigPrompt;

      await tester.pumpWidget(
        buildTestWidget(
          const UnifiedAiProgressContent(
            entityId: entityId,
            promptId: promptId,
          ),
          overrides: [
            aiConfigByIdProvider(promptId).overrideWith(
              (ref) async => promptGenConfig,
            ),
            aiConfigByTypeControllerProvider(
              AiConfigType.inferenceProvider,
            ).overrideWith(
              () => MockAiConfigByTypeController(const <AiConfig>[]),
            ),
            unifiedAiControllerOverride(
              const UnifiedAiState(
                message: '''
## Summary
Help implement OAuth.

## Prompt
Implement OAuth 2.0 authentication flow in Flutter using the oauth2 package.''',
              ),
            ),
            inferenceStatusControllerProvider((
              id: entityId,
              aiResponseType: AiResponseType.promptGeneration,
            )).overrideWith(
              () => _TestInferenceStatusController(InferenceStatus.idle),
            ),
            triggerNewInferenceProvider.overrideWith((ref, arg) async {}),
          ],
        ),
      );

      await tester.pump();

      await tester.pump(const Duration(milliseconds: 300));

      // Should show copy button for prompt generation
      expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
    });

    testWidgets(
      'tapping the prompt-generation copy button writes to the clipboard '
      'and shows a success toast',
      (tester) async {
        final promptGenConfig =
            AiConfig.prompt(
                  id: promptId,
                  name: 'Coding Prompt',
                  systemMessage: 'System message',
                  userMessage: 'Generate coding prompt',
                  defaultModelId: 'model-1',
                  modelIds: ['model-1'],
                  createdAt: DateTime(2024, 3, 15, 10, 30),
                  useReasoning: false,
                  requiredInputData: [InputDataType.task],
                  aiResponseType: AiResponseType.promptGeneration,
                  description: 'Generate coding prompts',
                )
                as AiConfigPrompt;

        String? clipboardText;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (MethodCall call) async {
            if (call.method == 'Clipboard.setData') {
              final args = call.arguments as Map<dynamic, dynamic>;
              clipboardText = args['text'] as String?;
            }
            return null;
          },
        );
        addTearDown(() {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          );
        });

        // buildTestWidget resolves the DS theme, so the success SnackBar
        // (hosted by the root ScaffoldMessenger) can read design tokens.
        await tester.pumpWidget(
          buildTestWidget(
            const UnifiedAiProgressContent(
              entityId: entityId,
              promptId: promptId,
            ),
            overrides: [
              aiConfigByIdProvider(promptId).overrideWith(
                (ref) async => promptGenConfig,
              ),
              aiConfigByTypeControllerProvider(
                AiConfigType.inferenceProvider,
              ).overrideWith(
                () => MockAiConfigByTypeController(const <AiConfig>[]),
              ),
              unifiedAiControllerOverride(
                const UnifiedAiState(
                  message: '''
## Prompt
Generate a widget that renders a login form.''',
                ),
              ),
              inferenceStatusControllerProvider((
                id: entityId,
                aiResponseType: AiResponseType.promptGeneration,
              )).overrideWith(
                () => _TestInferenceStatusController(InferenceStatus.idle),
              ),
              triggerNewInferenceProvider.overrideWith((ref, arg) async {}),
            ],
          ),
        );

        await tester.pump();

        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.byIcon(Icons.copy_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Prompt body (not the surrounding markdown header) lands on the
        // clipboard.
        expect(clipboardText, isNotNull);
        expect(
          clipboardText,
          contains('Generate a widget that renders a login form.'),
        );

        // Success toast is surfaced on the parent scaffold.
        final toast = tester.widget<DesignSystemToast>(
          find.byType(DesignSystemToast),
        );
        expect(toast.tone, DesignSystemToastTone.success);
      },
    );
  });

  group('UnifiedAiProgressContent - handleRetry', () {
    const entityId = 'retry-entity';
    const promptId = 'retry-prompt';

    testWidgets(
      'tapping retry in AiErrorDisplay triggers triggerNewInference',
      (tester) async {
        var triggerCalled = false;

        await tester.pumpWidget(
          buildTestWidget(
            const UnifiedAiProgressContent(
              entityId: entityId,
              promptId: promptId,
            ),
            overrides: [
              aiConfigByIdProvider(promptId).overrideWith(
                (ref) async => testPromptConfig,
              ),
              aiConfigByTypeControllerProvider(
                AiConfigType.inferenceProvider,
              ).overrideWith(
                () => MockAiConfigByTypeController(const <AiConfig>[]),
              ),
              unifiedAiControllerOverride(
                const UnifiedAiState(message: 'some generic error occurred'),
              ),
              inferenceStatusControllerProvider((
                id: entityId,
                aiResponseType: testPromptConfig.aiResponseType,
              )).overrideWith(
                () => _TestInferenceStatusController(InferenceStatus.error),
              ),
              triggerNewInferenceProvider.overrideWith((ref, arg) async {
                triggerCalled = true;
              }),
            ],
          ),
        );

        await tester.pump();

        await tester.pump(const Duration(milliseconds: 300));

        // Should show AiErrorDisplay with a retry button
        expect(find.byType(AiErrorDisplay), findsOneWidget);

        // The generic error categorises as InferenceErrorType.unknown, which is
        // retryable, so AiErrorDisplay renders its retry button labelled
        // "Try Again" (the localized aiInferenceErrorRetryButton). Tapping it
        // calls _handleRetry → triggerNewInferenceProvider. Assert the button
        // exists rather than guarding the tap, so a missing/unwired button
        // fails the test instead of silently passing.
        final retryBtn = find.text('Try Again');
        expect(retryBtn, findsOneWidget);
        await tester.tap(retryBtn);
        await tester.pump();
        expect(triggerCalled, isTrue);
      },
    );
  });

  group('UnifiedAiProgressContent - subscribeToExistingInference', () {
    const entityId = 'existing-entity';
    const promptId = 'existing-prompt';

    testWidgets(
      'shows streamed progress when showExisting=true and active inference exists',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            unifiedAiInferenceRepositoryProvider.overrideWithValue(
              mockRepository,
            ),
            cloudInferenceRepositoryProvider.overrideWithValue(
              mockCloudRepository,
            ),
            categoryRepositoryProvider.overrideWithValue(
              mockCategoryRepository,
            ),
            aiConfigByIdProvider(promptId).overrideWith(
              (ref) async => testPromptConfig,
            ),
            triggerNewInferenceProvider.overrideWith((ref, arg) async {}),
          ],
        );

        // Start an active inference so _subscribeToExistingInference finds it
        container
            .read(
              activeInferenceControllerProvider((
                entityId: entityId,
                aiResponseType: AiResponseType.taskSummary,
              )).notifier,
            )
            .startInference(promptId: promptId);

        // Push initial progress text
        container
            .read(
              activeInferenceControllerProvider((
                entityId: entityId,
                aiResponseType: AiResponseType.taskSummary,
              )).notifier,
            )
            .updateProgress('Partial result…');

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: resolveTestTheme(),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
              ],
              home: const Scaffold(
                body: UnifiedAiProgressContent(
                  entityId: entityId,
                  promptId: promptId,
                  showExisting: true,
                ),
              ),
            ),
          ),
        );

        // Allow the post-frame callback and async subscribe to run
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // The initial progress text should now be displayed
        expect(find.textContaining('Partial result'), findsOneWidget);

        // Unmount and dispose in-body so cacheFor timers are cancelled
        // before the pending-timer check.
        await tester.pumpWidget(const SizedBox());
        container.dispose();
      },
    );

    testWidgets(
      'stream updates from active inference are reflected when showExisting=true',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            unifiedAiInferenceRepositoryProvider.overrideWithValue(
              mockRepository,
            ),
            cloudInferenceRepositoryProvider.overrideWithValue(
              mockCloudRepository,
            ),
            categoryRepositoryProvider.overrideWithValue(
              mockCategoryRepository,
            ),
            aiConfigByIdProvider(promptId).overrideWith(
              (ref) async => testPromptConfig,
            ),
            triggerNewInferenceProvider.overrideWith((ref, arg) async {}),
          ],
        );

        // Start an active inference
        container
            .read(
              activeInferenceControllerProvider((
                entityId: entityId,
                aiResponseType: AiResponseType.taskSummary,
              )).notifier,
            )
            .startInference(promptId: promptId);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: resolveTestTheme(),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
              ],
              home: const Scaffold(
                body: UnifiedAiProgressContent(
                  entityId: entityId,
                  promptId: promptId,
                  showExisting: true,
                ),
              ),
            ),
          ),
        );

        // Allow subscription to attach
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Push a stream update
        container
            .read(
              activeInferenceControllerProvider((
                entityId: entityId,
                aiResponseType: AiResponseType.taskSummary,
              )).notifier,
            )
            .updateProgress('Stream update text');

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.textContaining('Stream update text'), findsOneWidget);

        // Unmount and dispose in-body so cacheFor timers are cancelled
        // before the pending-timer check.
        await tester.pumpWidget(const SizedBox());
        container.dispose();
      },
    );
  });

  group('UnifiedAiProgressContent - showExisting error path', () {
    const entityId = 'showexisting-error-entity';
    const promptId = 'showexisting-error-prompt';

    testWidgets(
      'reads unifiedAiController state explicitly in showExisting=true error path',
      (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            const UnifiedAiProgressContent(
              entityId: entityId,
              promptId: promptId,
              showExisting: true,
            ),
            overrides: [
              aiConfigByIdProvider(promptId).overrideWith(
                (ref) async => testPromptConfig,
              ),
              aiConfigByTypeControllerProvider(
                AiConfigType.inferenceProvider,
              ).overrideWith(
                () => MockAiConfigByTypeController(const <AiConfig>[]),
              ),
              // In showExisting mode the widget reads (not watches) the controller
              unifiedAiControllerOverride(
                const UnifiedAiState(
                  message: '',
                  error: ModelNotInstalledException('phi3'),
                ),
              ),
              inferenceStatusControllerProvider((
                id: entityId,
                aiResponseType: testPromptConfig.aiResponseType,
              )).overrideWith(
                () => _TestInferenceStatusController(InferenceStatus.error),
              ),
              triggerNewInferenceProvider.overrideWith((ref, arg) async {}),
            ],
          ),
        );

        await tester.pump();

        await tester.pump(const Duration(milliseconds: 300));

        // showExisting mode with ModelNotInstalledException → OllamaModelInstallDialog
        expect(find.byType(OllamaModelInstallDialog), findsOneWidget);
        // The model name appears in both the dialog title and body.
        expect(find.textContaining('phi3'), findsWidgets);
      },
    );
  });

  group('UnifiedAiProgressContent - string fallback onModelInstalled callback', () {
    const entityId = 'cb-entity';
    const promptId = 'cb-prompt';

    testWidgets('tapping install on string-fallback dialog triggers callback', (
      tester,
    ) async {
      final ollamaProvider = AiTestDataFactory.createTestProvider(
        id: 'ollama-cb',
        name: 'Ollama CB',
        type: InferenceProviderType.ollama,
        baseUrl: 'http://localhost:11434/',
      );

      when(
        () => mockCloudRepository.installModel(any(), any()),
      ).thenAnswer(
        (_) => Stream.fromIterable([
          // ignore: prefer_int_literals
          const OllamaPullProgress(status: 'success', progress: 1.0),
        ]),
      );

      var triggerCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            unifiedAiInferenceRepositoryProvider.overrideWithValue(
              mockRepository,
            ),
            cloudInferenceRepositoryProvider.overrideWithValue(
              mockCloudRepository,
            ),
            categoryRepositoryProvider.overrideWithValue(
              mockCategoryRepository,
            ),
            aiConfigByIdProvider(promptId).overrideWith(
              (ref) async => testPromptConfig,
            ),
            aiConfigByTypeControllerProvider(
              AiConfigType.inferenceProvider,
            ).overrideWith(
              () => MockAiConfigByTypeController([ollamaProvider]),
            ),
            // Use string-based error (not typed exception) to hit the fallback path
            unifiedAiControllerOverride(
              const UnifiedAiState(
                message:
                    'Model "llama3" is not installed. Please install it first.',
              ),
            ),
            inferenceStatusControllerProvider((
              id: entityId,
              aiResponseType: testPromptConfig.aiResponseType,
            )).overrideWith(
              () => _TestInferenceStatusController(InferenceStatus.error),
            ),
            triggerNewInferenceProvider.overrideWith((ref, arg) async {
              triggerCalled = true;
            }),
          ],
          child: MaterialApp(
            theme: resolveTestTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: UnifiedAiProgressContent(
                entityId: entityId,
                promptId: promptId,
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      await tester.pump(const Duration(milliseconds: 300));

      // The string-based fallback dialog should be shown
      expect(find.byType(OllamaModelInstallDialog), findsOneWidget);

      // Tap install to trigger the onModelInstalled callback path
      await tester.tap(find.text('Install'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // triggerNewInferenceProvider should have been called via onModelInstalled
      expect(triggerCalled, isTrue);
    });
  });

  // ── OllamaModelInstallDialog – _installModel state branches ─────────────────

  group('UnifiedAiProgressContent - _handleRetry directly triggered', () {
    const entityId = 'direct-retry-entity';
    const promptId = 'direct-retry-prompt';

    testWidgets('AiErrorDisplay "Try Again" button fires triggerNewInference', (
      tester,
    ) async {
      var triggerCallCount = 0;

      await tester.pumpWidget(
        buildTestWidget(
          const UnifiedAiProgressContent(
            entityId: entityId,
            promptId: promptId,
            // Prevent initState from triggering inference so the count starts at 0
            shouldTriggerOnInit: false,
          ),
          overrides: [
            aiConfigByIdProvider(promptId).overrideWith(
              (ref) async => testPromptConfig,
            ),
            aiConfigByTypeControllerProvider(
              AiConfigType.inferenceProvider,
            ).overrideWith(
              () => MockAiConfigByTypeController(const <AiConfig>[]),
            ),
            // Error state with no model-not-installed message → AiErrorDisplay
            unifiedAiControllerOverride(
              const UnifiedAiState(message: 'some generic network error'),
            ),
            inferenceStatusControllerProvider((
              id: entityId,
              aiResponseType: testPromptConfig.aiResponseType,
            )).overrideWith(
              () => _TestInferenceStatusController(InferenceStatus.error),
            ),
            triggerNewInferenceProvider.overrideWith((ref, arg) async {
              triggerCallCount++;
            }),
          ],
        ),
      );

      await tester.pump();

      await tester.pump(const Duration(milliseconds: 300));

      // AiErrorDisplay must be shown
      expect(find.byType(AiErrorDisplay), findsOneWidget);

      // AiErrorDisplay shows 'Try Again' (from aiInferenceErrorRetryButton l10n key)
      final retryFinder = find.text('Try Again');
      expect(retryFinder, findsOneWidget);
      await tester.ensureVisible(retryFinder);
      await tester.tap(retryFinder);
      await tester.pump();

      // _handleRetry reads triggerNewInferenceProvider (lines 54-63)
      expect(triggerCallCount, 1);
    });
  });

  group('UnifiedAiProgressContent - _handleModelInstalled typed exception', () {
    const entityId = 'typed-installed-entity';
    const promptId = 'typed-installed-prompt';

    testWidgets(
      'tapping install when ModelNotInstalledException triggers _handleModelInstalled',
      (tester) async {
        final ollamaProvider = AiTestDataFactory.createTestProvider(
          id: 'ollama-typed',
          name: 'Ollama',
          type: InferenceProviderType.ollama,
          baseUrl: 'http://localhost:11434/',
        );

        when(
          () => mockCloudRepository.installModel(any(), any()),
        ).thenAnswer(
          (_) => Stream.fromIterable([
            // ignore: prefer_int_literals
            const OllamaPullProgress(status: 'success', progress: 1.0),
          ]),
        );

        var triggerCalled = false;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              unifiedAiInferenceRepositoryProvider.overrideWithValue(
                mockRepository,
              ),
              cloudInferenceRepositoryProvider.overrideWithValue(
                mockCloudRepository,
              ),
              categoryRepositoryProvider.overrideWithValue(
                mockCategoryRepository,
              ),
              aiConfigByIdProvider(promptId).overrideWith(
                (ref) async => testPromptConfig,
              ),
              // Use _ImmediateAiConfigByTypeController so provider.future resolves
              aiConfigByTypeControllerProvider(
                AiConfigType.inferenceProvider,
              ).overrideWith(
                () => _ImmediateAiConfigByTypeController([ollamaProvider]),
              ),
              // Typed exception → _handleModelInstalled('Ollama') path (lines 137-173)
              unifiedAiControllerOverride(
                const UnifiedAiState(
                  message: '',
                  error: ModelNotInstalledException('llama3'),
                ),
              ),
              inferenceStatusControllerProvider((
                id: entityId,
                aiResponseType: testPromptConfig.aiResponseType,
              )).overrideWith(
                () => _TestInferenceStatusController(InferenceStatus.error),
              ),
              triggerNewInferenceProvider.overrideWith((ref, arg) async {
                triggerCalled = true;
              }),
            ],
            child: MaterialApp(
              theme: resolveTestTheme(),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(
                body: UnifiedAiProgressContent(
                  entityId: entityId,
                  promptId: promptId,
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        await tester.pump(const Duration(milliseconds: 300));

        // OllamaModelInstallDialog should appear for ModelNotInstalledException
        expect(find.byType(OllamaModelInstallDialog), findsOneWidget);
        expect(find.textContaining('llama3'), findsWidgets);

        // Tap install → _installModel → onModelInstalled → _handleModelInstalled
        await tester.tap(find.text('Install'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // triggerNewInferenceProvider must have been called (lines 143-148)
        expect(triggerCalled, isTrue);
      },
    );
  });

  // ── onModelInstalled callbacks fire after a successful install ──────────────
  // When a model-not-installed error renders the install dialog inline inside a
  // UnifiedAiProgressContent and the install succeeds, the dialog's
  // onModelInstalled callback runs. For the typed-exception error that callback
  // is _handleModelInstalled('Ollama') (lines 137-148+) and for the
  // string-fallback error it is the inline closure (lines 302-313+); both first
  // call triggerNewInferenceProvider. We assert that trigger fires, which proves
  // the callback was invoked end-to-end.
  //
  // NOTE: the subsequent "re-show progress modal" branches
  // (_handleModelInstalled lines 159-170 and the inline callback lines 324-335)
  // are unreachable here: _installModel calls Navigator.of(context).pop(), which
  // tears down the route hosting the content that owns the callback, so the
  // `if (!mounted || !context.mounted) return` guards (lines 157 / 322)
  // short-circuit before showSingleSliverPageModal is reached. They are only
  // reachable when the dialog is hosted as a nested route the pop can close
  // without unmounting the owner, which the inline rendering never produces.
  group('UnifiedAiProgressContent - onModelInstalled callback fires', () {
    const entityId = 'reshow-entity';
    // Must equal testPromptConfig.id so the re-read aiConfigByIdProvider inside
    // the callback resolves to an AiConfigPrompt via the same override.
    const promptId = 'test-prompt-1';

    AiConfigInferenceProvider makeOllama() =>
        AiTestDataFactory.createTestProvider(
          id: 'ollama-reshow',
          name: 'Ollama',
          type: InferenceProviderType.ollama,
          baseUrl: 'http://localhost:11434/',
        );

    Future<void> pumpErrorView(
      WidgetTester tester, {
      required UnifiedAiState controllerState,
      required void Function() onTrigger,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            unifiedAiInferenceRepositoryProvider.overrideWithValue(
              mockRepository,
            ),
            cloudInferenceRepositoryProvider.overrideWithValue(
              mockCloudRepository,
            ),
            categoryRepositoryProvider.overrideWithValue(
              mockCategoryRepository,
            ),
            aiConfigByIdProvider(promptId).overrideWith(
              (ref) async => testPromptConfig,
            ),
            aiConfigByTypeControllerProvider(
              AiConfigType.inferenceProvider,
            ).overrideWith(
              () => MockAiConfigByTypeController([makeOllama()]),
            ),
            unifiedAiControllerOverride(controllerState),
            inferenceStatusControllerProvider((
              id: entityId,
              aiResponseType: testPromptConfig.aiResponseType,
            )).overrideWith(
              () => _TestInferenceStatusController(InferenceStatus.error),
            ),
            triggerNewInferenceProvider.overrideWith((ref, arg) async {
              onTrigger();
            }),
          ],
          child: MaterialApp(
            theme: resolveTestTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              // Keep aiConfigByTypeControllerProvider alive (autoDispose) so the
              // install dialog's _installModel can read its .future without the
              // provider being torn down mid-load.
              body: Consumer(
                builder: (context, ref, child) {
                  ref.watch(
                    aiConfigByTypeControllerProvider(
                      AiConfigType.inferenceProvider,
                    ),
                  );
                  return child!;
                },
                child: const UnifiedAiProgressContent(
                  entityId: entityId,
                  promptId: promptId,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    // Each error shape routes install completion through a different callback;
    // both call triggerNewInferenceProvider first. triggerCallCount starts at 1
    // because shouldTriggerOnInit defaults to true and fires once on init.
    final cases = <String, UnifiedAiState>{
      'typed ModelNotInstalledException (_handleModelInstalled 137-148)':
          const UnifiedAiState(
            message: '',
            error: ModelNotInstalledException('llama3'),
          ),
      'string fallback message (inline callback 302-313)': const UnifiedAiState(
        message: 'Model "llama3" is not installed. Please install it first.',
      ),
    };

    for (final entry in cases.entries) {
      final description = entry.key;
      final state = entry.value;
      testWidgets('$description re-triggers inference after install', (
        tester,
      ) async {
        var triggerCount = 0;

        // Finite success stream so _installModel completes, pops the dialog and
        // invokes the onModelInstalled callback.
        when(() => mockCloudRepository.installModel(any(), any())).thenAnswer(
          (_) => Stream.fromIterable(const [
            OllamaPullProgress(status: 'success', progress: 1),
          ]),
        );

        await pumpErrorView(
          tester,
          controllerState: state,
          onTrigger: () => triggerCount++,
        );

        // The install dialog is rendered inline for the model-not-installed
        // error and the initial inference trigger has already fired once.
        expect(find.byType(OllamaModelInstallDialog), findsOneWidget);
        expect(triggerCount, 1);

        await tester.tap(find.text('Install'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // The successful install invoked onModelInstalled, which called
        // triggerNewInferenceProvider a second time.
        expect(triggerCount, 2);
      });
    }
  });
}
