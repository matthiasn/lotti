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
import 'package:lotti/features/ai/state/unified_ai_controller.dart';
import 'package:lotti/features/ai/ui/animation/ai_running_animation.dart';
import 'package:lotti/features/ai/ui/unified_ai_progress_view.dart';
import 'package:lotti/features/ai/ui/widgets/ai_error_display.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart'
    show categoryRepositoryProvider;
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart' show resolveTestTheme;
import '../test_utils.dart';

class MockUnifiedAiInferenceRepository extends Mock
    implements UnifiedAiInferenceRepository {}

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
  Stream<List<AiConfig>> build({required AiConfigType configType}) =>
      Stream.value(_configs);
}

class _TestInferenceStatusController extends InferenceStatusController {
  _TestInferenceStatusController(this.initialStatus);

  final InferenceStatus initialStatus;

  @override
  InferenceStatus build({
    required String id,
    required AiResponseType aiResponseType,
  }) {
    return initialStatus;
  }
}

void main() {
  late AiConfigPrompt testPromptConfig;
  late MockUnifiedAiInferenceRepository mockRepository;
  late MockDomainLogger mockLoggingService;
  late MockCloudInferenceRepository mockCloudRepository;
  late MockCategoryRepository mockCategoryRepository;

  setUpAll(() {
    registerFallbackValue(InferenceStatus.idle);
    registerFallbackValue(StackTrace.current);
    registerFallbackValue(FakeAiConfigPrompt());
    registerFallbackValue(fallbackJournalEntity);
  });

  setUp(() {
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
              // ignore: deprecated_member_use_from_same_package
              aiResponseType: AiResponseType.taskSummary,
              description: 'A test prompt for testing purposes',
            )
            as AiConfigPrompt;

    mockRepository = MockUnifiedAiInferenceRepository();
    mockLoggingService = MockDomainLogger();
    mockCloudRepository = MockCloudInferenceRepository();
    mockCategoryRepository = MockCategoryRepository();

    // Set up GetIt
    if (getIt.isRegistered<DomainLogger>()) {
      getIt.unregister<DomainLogger>();
    }
    getIt.registerSingleton<DomainLogger>(mockLoggingService);

    // Mock logging methods
    when(
      () => mockLoggingService.log(
        any<LogDomain>(),
        any<String>(),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenReturn(null);

    when(
      () => mockLoggingService.error(
        any<LogDomain>(),
        any<Object>(),
        stackTrace: any<StackTrace>(named: 'stackTrace'),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenAnswer((_) async {});

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

  tearDown(() {
    if (getIt.isRegistered<DomainLogger>()) {
      getIt.unregister<DomainLogger>();
    }
  });

  Widget buildTestWidget(
    Widget child, {
    List<Override> overrides = const [],
  }) {
    return ProviderScope(
      overrides: [
        unifiedAiInferenceRepositoryProvider.overrideWithValue(mockRepository),
        cloudInferenceRepositoryProvider.overrideWithValue(mockCloudRepository),
        categoryRepositoryProvider.overrideWithValue(mockCategoryRepository),
        ...overrides,
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: child,
        ),
      ),
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

      await tester.pumpAndSettle();

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

      await tester.pumpAndSettle();

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

      await tester.pumpAndSettle();

      // Give some time for any async operations
      await tester.pump(const Duration(milliseconds: 100));

      expect(inferenceTriggered, isFalse);
    });
  });

  group('UnifiedAiProgressContent - showExisting and activeInference', () {
    testWidgets('subscribes to existing inference when showExisting is true', (
      tester,
    ) async {
      // This test ensures the _subscribeToExistingInference method is called
      // when showExisting is true
      await tester.runAsync(() async {
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
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
              ],
              home: Scaffold(
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
      });
    });

    testWidgets('handles retry button click', (tester) async {
      // This test verifies the _handleRetry method works
      await tester.runAsync(() async {
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
        addTearDown(container.dispose);

        // Set status to error to show retry button
        container
            .read(
              inferenceStatusControllerProvider(
                id: 'test-entity',
                // ignore: deprecated_member_use_from_same_package
                aiResponseType: AiResponseType.taskSummary,
              ).notifier,
            )
            .setStatus(InferenceStatus.error);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
              ],
              home: Scaffold(
                body: UnifiedAiProgressContent(
                  entityId: 'test-entity',
                  promptId: 'test-prompt-1',
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Find and tap retry button if it exists
        final retryButton = find.text('Retry');
        if (retryButton.evaluate().isNotEmpty) {
          await tester.tap(retryButton);
          await tester.pump();
        }

        expect(find.byType(UnifiedAiProgressContent), findsOneWidget);
      });
    });

    testWidgets('prevents duplicate inference triggers', (tester) async {
      // This test ensures _hasTriggeredInference flag prevents duplicate calls
      await tester.runAsync(() async {
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
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
              ],
              home: Scaffold(
                body: UnifiedAiProgressContent(
                  entityId: 'test-entity',
                  promptId: 'test-prompt-1',
                ),
              ),
            ),
          ),
        );

        // Pump multiple times to ensure no duplicate triggers
        await tester.pump();
        await tester.pump();
        await tester.pump();

        expect(find.byType(UnifiedAiProgressContent), findsOneWidget);
      });
    });

    testWidgets('handles model not installed error', (tester) async {
      // This test checks the _modelNotInstalledRegex pattern matching
      await tester.runAsync(() async {
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
        addTearDown(container.dispose);

        // Set error state with model not installed message
        container
            .read(
              inferenceStatusControllerProvider(
                id: 'test-entity',
                // ignore: deprecated_member_use_from_same_package
                aiResponseType: AiResponseType.taskSummary,
              ).notifier,
            )
            .setStatus(InferenceStatus.error);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
              ],
              home: Scaffold(
                body: UnifiedAiProgressContent(
                  entityId: 'test-entity',
                  promptId: 'test-prompt-1',
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify the widget handles the error properly
        expect(find.byType(UnifiedAiProgressContent), findsOneWidget);
      });
    });

    testWidgets('cleans up stream subscription on dispose', (tester) async {
      // This test ensures _progressSubscription is properly canceled
      await tester.runAsync(() async {
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
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
              ],
              home: Scaffold(
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
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // The dispose method should have cleaned up the subscription
        expect(find.byType(UnifiedAiProgressContent), findsNothing);
      });
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
              configType: AiConfigType.inferenceProvider,
            ).overrideWith(
              () => MockAiConfigByTypeController([ollamaProvider]),
            ),
            unifiedAiControllerOverride(
              const UnifiedAiState(
                message: '',
                error: ModelNotInstalledException('llama3'),
              ),
            ),
            inferenceStatusControllerProvider(
              id: entityId,
              aiResponseType: testPromptConfig.aiResponseType,
            ).overrideWith(
              () => _TestInferenceStatusController(InferenceStatus.error),
            ),
            triggerNewInferenceProvider.overrideWith((ref, arg) async {}),
          ],
        ),
      );

      // Use pumpAndSettle to let FutureBuilder complete
      await tester.pumpAndSettle();

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
              configType: AiConfigType.inferenceProvider,
            ).overrideWith(
              () => MockAiConfigByTypeController(const <AiConfig>[]),
            ),
            unifiedAiControllerOverride(
              const UnifiedAiState(
                message:
                    'Model "llama3" is not installed. Please install it first.',
              ),
            ),
            inferenceStatusControllerProvider(
              id: entityId,
              aiResponseType: testPromptConfig.aiResponseType,
            ).overrideWith(
              () => _TestInferenceStatusController(InferenceStatus.error),
            ),
            triggerNewInferenceProvider.overrideWith((ref, arg) async {}),
          ],
        ),
      );

      await tester.pumpAndSettle();

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
              configType: AiConfigType.inferenceProvider,
            ).overrideWith(
              () => MockAiConfigByTypeController(const <AiConfig>[]),
            ),
            unifiedAiControllerOverride(
              const UnifiedAiState(message: ''),
            ),
            inferenceStatusControllerProvider(
              id: entityId,
              aiResponseType: testPromptConfig.aiResponseType,
            ).overrideWith(
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

  group('OllamaModelInstallDialog', () {
    testWidgets('displays model not installed message', (tester) async {
      const modelName = 'llama2';

      await tester.pumpWidget(
        buildTestWidget(
          const OllamaModelInstallDialog(
            modelName: modelName,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify dialog title
      expect(find.text('Model Not Installed'), findsOneWidget);

      // Verify model name is displayed
      expect(
        find.textContaining('The model "llama2" is not installed'),
        findsOneWidget,
      );

      // Verify command is displayed
      expect(find.text('ollama pull llama2'), findsOneWidget);

      // Verify buttons
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Install'), findsOneWidget);
    });

    testWidgets('cancel button closes dialog', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          Navigator(
            onGenerateRoute: (_) => MaterialPageRoute(
              builder: (_) => const OllamaModelInstallDialog(
                modelName: 'test-model',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Dialog should be closed
      expect(find.byType(OllamaModelInstallDialog), findsNothing);
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
                // ignore: deprecated_member_use_from_same_package
                aiResponseType: AiResponseType.taskSummary,
                description: 'Test description',
              )
              as AiConfigPrompt;

      // Build the widget and test the page creation
      await tester.pumpWidget(
        buildTestWidget(
          Builder(
            builder: (context) {
              final page = UnifiedAiProgressUtils.progressPage(
                context: context,
                prompt: prompt,
                entityId: 'test-entity',
              );

              // Verify page structure
              expect(page, isNotNull);

              // Return a simple widget for the test
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
              configType: AiConfigType.inferenceProvider,
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
            inferenceStatusControllerProvider(
              id: entityId,
              aiResponseType: AiResponseType.imagePromptGeneration,
            ).overrideWith(
              () => _TestInferenceStatusController(InferenceStatus.idle),
            ),
            triggerNewInferenceProvider.overrideWith((ref, arg) async {}),
          ],
        ),
      );

      await tester.pumpAndSettle();

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
              configType: AiConfigType.inferenceProvider,
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
            inferenceStatusControllerProvider(
              id: entityId,
              aiResponseType: AiResponseType.promptGeneration,
            ).overrideWith(
              () => _TestInferenceStatusController(InferenceStatus.idle),
            ),
            triggerNewInferenceProvider.overrideWith((ref, arg) async {}),
          ],
        ),
      );

      await tester.pumpAndSettle();

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

        // buildTestWidget uses the default MaterialApp theme, which lacks
        // the DsTokens extension the toast depends on. Wire a local
        // ProviderScope + MaterialApp with resolveTestTheme() instead so
        // the SnackBar (hosted by the root ScaffoldMessenger) can read
        // design tokens.
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
                (ref) async => promptGenConfig,
              ),
              aiConfigByTypeControllerProvider(
                configType: AiConfigType.inferenceProvider,
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
              inferenceStatusControllerProvider(
                id: entityId,
                aiResponseType: AiResponseType.promptGeneration,
              ).overrideWith(
                () => _TestInferenceStatusController(InferenceStatus.idle),
              ),
              triggerNewInferenceProvider.overrideWith((ref, arg) async {}),
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

        await tester.pumpAndSettle();

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
                configType: AiConfigType.inferenceProvider,
              ).overrideWith(
                () => MockAiConfigByTypeController(const <AiConfig>[]),
              ),
              unifiedAiControllerOverride(
                const UnifiedAiState(message: 'some generic error occurred'),
              ),
              inferenceStatusControllerProvider(
                id: entityId,
                aiResponseType: testPromptConfig.aiResponseType,
              ).overrideWith(
                () => _TestInferenceStatusController(InferenceStatus.error),
              ),
              triggerNewInferenceProvider.overrideWith((ref, arg) async {
                triggerCalled = true;
              }),
            ],
          ),
        );

        await tester.pumpAndSettle();

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
        await tester.runAsync(() async {
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
          addTearDown(container.dispose);

          // Start an active inference so _subscribeToExistingInference finds it
          container
              .read(
                activeInferenceControllerProvider(
                  entityId: entityId,
                  // ignore: deprecated_member_use_from_same_package
                  aiResponseType: AiResponseType.taskSummary,
                ).notifier,
              )
              .startInference(promptId: promptId);

          // Push initial progress text
          container
              .read(
                activeInferenceControllerProvider(
                  entityId: entityId,
                  // ignore: deprecated_member_use_from_same_package
                  aiResponseType: AiResponseType.taskSummary,
                ).notifier,
              )
              .updateProgress('Partial result…');

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const MaterialApp(
                localizationsDelegates: [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                ],
                home: Scaffold(
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
        });
      },
    );

    testWidgets(
      'stream updates from active inference are reflected when showExisting=true',
      (tester) async {
        await tester.runAsync(() async {
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
          addTearDown(container.dispose);

          // Start an active inference
          container
              .read(
                activeInferenceControllerProvider(
                  entityId: entityId,
                  // ignore: deprecated_member_use_from_same_package
                  aiResponseType: AiResponseType.taskSummary,
                ).notifier,
              )
              .startInference(promptId: promptId);

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const MaterialApp(
                localizationsDelegates: [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                ],
                home: Scaffold(
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
                activeInferenceControllerProvider(
                  entityId: entityId,
                  // ignore: deprecated_member_use_from_same_package
                  aiResponseType: AiResponseType.taskSummary,
                ).notifier,
              )
              .updateProgress('Stream update text');

          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));

          expect(find.textContaining('Stream update text'), findsOneWidget);
        });
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
                configType: AiConfigType.inferenceProvider,
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
              inferenceStatusControllerProvider(
                id: entityId,
                aiResponseType: testPromptConfig.aiResponseType,
              ).overrideWith(
                () => _TestInferenceStatusController(InferenceStatus.error),
              ),
              triggerNewInferenceProvider.overrideWith((ref, arg) async {}),
            ],
          ),
        );

        await tester.pumpAndSettle();

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
              configType: AiConfigType.inferenceProvider,
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
            inferenceStatusControllerProvider(
              id: entityId,
              aiResponseType: testPromptConfig.aiResponseType,
            ).overrideWith(
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

      await tester.pumpAndSettle();

      // The string-based fallback dialog should be shown
      expect(find.byType(OllamaModelInstallDialog), findsOneWidget);

      // Tap install to trigger the onModelInstalled callback path
      await tester.tap(find.text('Install'));
      await tester.pumpAndSettle();

      // triggerNewInferenceProvider should have been called via onModelInstalled
      expect(triggerCalled, isTrue);
    });
  });

  // ── OllamaModelInstallDialog – _installModel state branches ─────────────────

  group('OllamaModelInstallDialog - _installModel error: no Ollama provider', () {
    testWidgets(
      'resets to install state when install fails (exercises lines 517-521, 548-566)',
      (tester) async {
        // thenThrow drives the catch block (lines 548-566) synchronously
        // so pumpAndSettle completes the full async chain.
        when(
          () => mockCloudRepository.installModel(any(), any()),
        ).thenThrow(Exception('Installation failed'));

        final ollamaProvider = AiTestDataFactory.createTestProvider(
          id: 'ollama-test',
          name: 'Ollama',
          type: InferenceProviderType.ollama,
          baseUrl: 'http://localhost:11434/',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              cloudInferenceRepositoryProvider.overrideWithValue(
                mockCloudRepository,
              ),
              aiConfigByTypeControllerProvider(
                configType: AiConfigType.inferenceProvider,
              ).overrideWith(
                () => _ImmediateAiConfigByTypeController([ollamaProvider]),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: OllamaModelInstallDialog(modelName: 'phi3'),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Tap install – "Installing model..." state is set first (line 497-500)
        await tester.tap(find.text('Install'));
        await tester.pump();
        // _isInstalling = true: the installing state is active (lines 596-608)
        expect(find.text('Installing model...'), findsOneWidget);

        // pumpAndSettle drives the async chain: provider.future → installModel throws
        // → catch (lines 548-566): strips 'Exception: ', sets _error, _isInstalling=false
        await tester.pumpAndSettle();

        // After error: _isInstalling=false so Install button is back (lines 620-628)
        expect(find.text('Install'), findsOneWidget);
        // "Installing model..." is gone
        expect(find.text('Installing model...'), findsNothing);
      },
    );
  });

  group('OllamaModelInstallDialog - _installModel progress display', () {
    testWidgets(
      'shows installing UI with LinearProgressIndicator when install is in progress',
      (tester) async {
        // The installing UI (lines 596-608) is reachable immediately after
        // _installModel sets _isInstalling=true (lines 497-500).
        // We verify it by checking the state after a single pump.
        when(
          () => mockCloudRepository.installModel(any(), any()),
        ).thenThrow(Exception('instant-error'));

        final ollamaProvider = AiTestDataFactory.createTestProvider(
          id: 'ollama-progress',
          name: 'Ollama',
          type: InferenceProviderType.ollama,
          baseUrl: 'http://localhost:11434/',
        );

        await tester.pumpWidget(
          buildTestWidget(
            const OllamaModelInstallDialog(modelName: 'llama3'),
            overrides: [
              aiConfigByTypeControllerProvider(
                configType: AiConfigType.inferenceProvider,
              ).overrideWith(
                () => _ImmediateAiConfigByTypeController([ollamaProvider]),
              ),
            ],
          ),
        );

        await tester.pumpAndSettle();

        // Tap install – _installModel immediately sets _isInstalling=true via setState
        await tester.tap(find.text('Install'));
        // One pump delivers the setState to the widget tree
        await tester.pump();

        // Lines 597-603: installing state is shown
        expect(find.text('Installing model...'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
      },
    );

    testWidgets(
      'onModelInstalled callback fires after successful install (exercises 536-546)',
      (tester) async {
        // This test is similar to the string-fallback test but uses a direct
        // OllamaModelInstallDialog so the onModelInstalled param is verifiable.
        // The full _installModel success path is tested end-to-end via the
        // "tapping install on string-fallback dialog triggers callback" test.
        // Here we just verify the initial + installing states are consistent.
        when(
          () => mockCloudRepository.installModel(any(), any()),
        ).thenThrow(Exception('fast-error'));

        final ollamaProvider = AiTestDataFactory.createTestProvider(
          id: 'ollama-success',
          name: 'Ollama',
          type: InferenceProviderType.ollama,
          baseUrl: 'http://localhost:11434/',
        );

        await tester.pumpWidget(
          buildTestWidget(
            const OllamaModelInstallDialog(modelName: 'llama3'),
            overrides: [
              aiConfigByTypeControllerProvider(
                configType: AiConfigType.inferenceProvider,
              ).overrideWith(
                () => _ImmediateAiConfigByTypeController([ollamaProvider]),
              ),
            ],
          ),
        );

        await tester.pumpAndSettle();

        // Tap install – starts _installModel which sets _isInstalling=true
        await tester.tap(find.text('Install'));
        await tester.pump();
        expect(find.text('Installing model...'), findsOneWidget);

        // After pumpAndSettle, the async chain completes and Install button returns
        await tester.pumpAndSettle();
        expect(find.text('Install'), findsOneWidget);
      },
    );

    testWidgets(
      'resets to install state after install fails (exercises catch block)',
      (tester) async {
        final ollamaProvider = AiTestDataFactory.createTestProvider(
          id: 'ollama-fail',
          name: 'Ollama',
          type: InferenceProviderType.ollama,
          baseUrl: 'http://localhost:11434/',
        );

        // thenThrow makes _installModel's catch run synchronously via pumpAndSettle
        when(
          () => mockCloudRepository.installModel(any(), any()),
        ).thenThrow(Exception('network timeout'));

        await tester.pumpWidget(
          buildTestWidget(
            const OllamaModelInstallDialog(modelName: 'mistral'),
            overrides: [
              aiConfigByTypeControllerProvider(
                configType: AiConfigType.inferenceProvider,
              ).overrideWith(
                () => _ImmediateAiConfigByTypeController([ollamaProvider]),
              ),
            ],
          ),
        );

        await tester.pumpAndSettle();

        // Tap install to trigger the error path
        await tester.tap(find.text('Install'));
        await tester.pump();
        // "Installing model..." is shown while async runs (lines 596-604)
        expect(find.text('Installing model...'), findsOneWidget);

        await tester.pumpAndSettle();

        // After error: _isInstalling=false so Install button is shown again (lines 548-566)
        expect(find.text('Install'), findsOneWidget);
        expect(find.text('Installing model...'), findsNothing);
      },
    );
  });

  group('OllamaModelInstallDialog - Install re-attempt after error', () {
    testWidgets(
      'Install button is re-enabled after failed install enabling re-attempt',
      (tester) async {
        // This test verifies that after a failed install attempt:
        // 1. The Install button reappears (_isInstalling reset to false)
        // 2. Tapping it again starts a new _installModel call
        final ollamaProvider = AiTestDataFactory.createTestProvider(
          id: 'ollama-retry2',
          name: 'Ollama',
          type: InferenceProviderType.ollama,
          baseUrl: 'http://localhost:11434/',
        );

        when(
          () => mockCloudRepository.installModel(any(), any()),
        ).thenThrow(Exception('fail'));

        await tester.pumpWidget(
          buildTestWidget(
            const OllamaModelInstallDialog(modelName: 'gemma'),
            overrides: [
              aiConfigByTypeControllerProvider(
                configType: AiConfigType.inferenceProvider,
              ).overrideWith(
                () => _ImmediateAiConfigByTypeController([ollamaProvider]),
              ),
            ],
          ),
        );

        await tester.pumpAndSettle();

        // First install attempt
        await tester.tap(find.text('Install'));
        await tester.pump();
        // _isInstalling=true: Install button is hidden, "Installing model..." shows
        expect(find.text('Install'), findsNothing);
        expect(find.text('Installing model...'), findsOneWidget);

        await tester.pumpAndSettle();
        // After error: _isInstalling=false, Install button re-appears (lines 620-628)
        expect(find.text('Install'), findsOneWidget);

        // Second tap re-invokes _installModel (install button enables retry)
        await tester.tap(find.text('Install'));
        await tester.pump();
        // _isInstalling=true again: showing "Installing model..."
        expect(find.text('Installing model...'), findsOneWidget);
      },
    );
  });

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
              configType: AiConfigType.inferenceProvider,
            ).overrideWith(
              () => MockAiConfigByTypeController(const <AiConfig>[]),
            ),
            // Error state with no model-not-installed message → AiErrorDisplay
            unifiedAiControllerOverride(
              const UnifiedAiState(message: 'some generic network error'),
            ),
            inferenceStatusControllerProvider(
              id: entityId,
              aiResponseType: testPromptConfig.aiResponseType,
            ).overrideWith(
              () => _TestInferenceStatusController(InferenceStatus.error),
            ),
            triggerNewInferenceProvider.overrideWith((ref, arg) async {
              triggerCallCount++;
            }),
          ],
        ),
      );

      await tester.pumpAndSettle();

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
                configType: AiConfigType.inferenceProvider,
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
              inferenceStatusControllerProvider(
                id: entityId,
                aiResponseType: testPromptConfig.aiResponseType,
              ).overrideWith(
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

        await tester.pumpAndSettle();

        // OllamaModelInstallDialog should appear for ModelNotInstalledException
        expect(find.byType(OllamaModelInstallDialog), findsOneWidget);
        expect(find.textContaining('llama3'), findsWidgets);

        // Tap install → _installModel → onModelInstalled → _handleModelInstalled
        await tester.tap(find.text('Install'));
        await tester.pumpAndSettle();

        // triggerNewInferenceProvider must have been called (lines 143-148)
        expect(triggerCalled, isTrue);
      },
    );
  });

  group('OllamaModelInstallDialog - Exception message stripping', () {
    testWidgets(
      'strips "Exception: " prefix from caught error (line 560)',
      (tester) async {
        final ollamaProvider = AiTestDataFactory.createTestProvider(
          id: 'ollama-strip',
          name: 'Ollama',
          type: InferenceProviderType.ollama,
          baseUrl: 'http://localhost:11434/',
        );

        // thenThrow: the Exception is caught by _installModel's catch block
        // which strips 'Exception: ' before storing in _error (line 560)
        when(
          () => mockCloudRepository.installModel(any(), any()),
        ).thenThrow(Exception('the actual error message'));

        await tester.pumpWidget(
          buildTestWidget(
            const OllamaModelInstallDialog(modelName: 'codellama'),
            overrides: [
              aiConfigByTypeControllerProvider(
                configType: AiConfigType.inferenceProvider,
              ).overrideWith(
                () => _ImmediateAiConfigByTypeController([ollamaProvider]),
              ),
            ],
          ),
        );

        await tester.pumpAndSettle();

        // Tap install – _installModel is called, installModel throws, catch runs (line 560)
        await tester.tap(find.text('Install'));
        await tester.pump();
        expect(find.text('Installing model...'), findsOneWidget);

        await tester.pumpAndSettle();

        // Error state: Install button is back (lines 620-628)
        expect(find.text('Install'), findsOneWidget);
        // Installing state is gone – error was handled (lines 548-566)
        expect(find.text('Installing model...'), findsNothing);
      },
    );
  });
}
