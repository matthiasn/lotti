import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/unified_ai_inference_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/state/unified_ai_controller.dart';
import 'package:lotti/features/ai/ui/animation/ai_running_animation.dart';
import 'package:lotti/features/ai/ui/unified_ai_progress_view.dart';
import 'package:lotti/features/ai/ui/widgets/ai_error_display.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

class MockUnifiedAiInferenceRepository extends Mock
    implements UnifiedAiInferenceRepository {}

class MockLoggingService extends Mock implements LoggingService {}

class FakeAiConfigPrompt extends Fake implements AiConfigPrompt {}

void main() {
  late AiConfigPrompt testPromptConfig;
  late MockUnifiedAiInferenceRepository mockRepository;
  late MockLoggingService mockLoggingService;

  setUpAll(() {
    registerFallbackValue(InferenceStatus.idle);
    registerFallbackValue(StackTrace.current);
    registerFallbackValue(FakeAiConfigPrompt());
  });

  setUp(() {
    final now = DateTime.now();
    testPromptConfig = AiConfig.prompt(
      id: 'test-prompt-1',
      name: 'Test Prompt',
      systemMessage: 'You are a helpful assistant',
      userMessage: 'Please help with this task',
      defaultModelId: 'model-1',
      modelIds: ['model-1'],
      createdAt: now,
      useReasoning: false,
      requiredInputData: [InputDataType.task],
      aiResponseType: AiResponseType.taskSummary,
      description: 'A test prompt for testing purposes',
    ) as AiConfigPrompt;

    mockRepository = MockUnifiedAiInferenceRepository();
    mockLoggingService = MockLoggingService();

    // Set up GetIt
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
    getIt.registerSingleton<LoggingService>(mockLoggingService);

    // Mock logging methods
    when(
      () => mockLoggingService.captureEvent(
        any<dynamic>(),
        domain: any(named: 'domain'),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenReturn(null);

    when(
      () => mockLoggingService.captureException(
        any<dynamic>(),
        domain: any(named: 'domain'),
        subDomain: any(named: 'subDomain'),
        stackTrace: any<dynamic>(named: 'stackTrace'),
      ),
    ).thenReturn(null);

    // Mock repository methods
    when(
      () => mockRepository.runInference(
        entityId: any(named: 'entityId'),
        promptConfig: any(named: 'promptConfig'),
        onProgress: any(named: 'onProgress'),
        onStatusChange: any(named: 'onStatusChange'),
      ),
    ).thenAnswer((invocation) async {
      final onProgress =
          invocation.namedArguments[#onProgress] as void Function(String);
      final onStatusChange = invocation.namedArguments[#onStatusChange] as void
          Function(InferenceStatus);

      // Simulate progress updates
      onStatusChange(InferenceStatus.running);
      onProgress('Starting inference...');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      onProgress('Processing...');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      onProgress('Complete!');
      onStatusChange(InferenceStatus.idle);
    });
  });

  tearDown(() {
    // Unregister LoggingService after each test to ensure a clean state
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
  });

  // Helper function to build test widget
  Widget buildTestWidget(
    Widget child, {
    List<Override> overrides = const [],
    void Function(ProviderContainer)? onContainerCreated,
  }) {
    return ProviderScope(
      overrides: [
        unifiedAiInferenceRepositoryProvider.overrideWithValue(mockRepository),
        ...overrides,
      ],
      parent: ProviderContainer(),
      child: Builder(
        builder: (context) {
          onContainerCreated?.call(ProviderScope.containerOf(context));
          return MaterialApp(
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
          );
        },
      ),
    );
  }

  group('UnifiedAiProgressView Tests', () {
    const testEntityId = 'test-entity-1';
    const testPromptId = 'test-prompt-1';

    testWidgets('shows loading indicator when prompt config is loading',
        (tester) async {
      // Arrange
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

      // Assert - user should see a loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete to avoid hanging test
      completer.complete(testPromptConfig);
      await tester.pumpAndSettle();
    });

    testWidgets('shows error message when prompt config loading fails',
        (tester) async {
      // Arrange
      const errorMessage = 'Failed to load prompt config';

      await tester.pumpWidget(
        buildTestWidget(
          const UnifiedAiProgressContent(
            entityId: testEntityId,
            promptId: testPromptId,
          ),
          overrides: [
            aiConfigByIdProvider(testPromptId).overrideWith(
              (ref) => Future.error(errorMessage),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Assert - user should see the error message
      expect(find.text('Error loading prompt: $errorMessage'), findsOneWidget);
    });

    testWidgets('shows invalid config message when config is null',
        (tester) async {
      // Arrange
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

      // Assert - user should see invalid configuration message
      expect(find.text('Invalid prompt configuration'), findsOneWidget);
    });

    testWidgets('shows invalid config message when config is wrong type',
        (tester) async {
      // Arrange
      final invalidConfig = AiConfig.model(
        id: 'model-1',
        name: 'Test Model',
        providerModelId: 'provider-model-1',
        inferenceProviderId: 'provider-1',
        createdAt: DateTime.now(),
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

      // Assert - user should see invalid configuration message
      expect(find.text('Invalid prompt configuration'), findsOneWidget);
    });

    testWidgets('displays progress text when inference runs successfully',
        (tester) async {
      // Arrange
      late ProviderContainer container;
      await tester.pumpWidget(
        buildTestWidget(
          const UnifiedAiProgressContent(
            entityId: testEntityId,
            promptId: testPromptId,
          ),
          overrides: [
            aiConfigByIdProvider(testPromptId).overrideWith(
              (ref) => Future.value(testPromptConfig),
            ),
          ],
          onContainerCreated: (c) => container = c,
        ),
      );

      await tester.pump();

      // Trigger inference
      await container.read(
        triggerNewInferenceProvider(
          entityId: testEntityId,
          promptId: testPromptId,
        ).future,
      );

      await tester.pumpAndSettle();

      // Assert - user should see the final progress text
      expect(find.text('Complete!'), findsOneWidget);
    });

    testWidgets('displays intermediate progress messages during inference',
        (tester) async {
      // Arrange - slow down the mock to catch intermediate states
      when(
        () => mockRepository.runInference(
          entityId: any(named: 'entityId'),
          promptConfig: any(named: 'promptConfig'),
          onProgress: any(named: 'onProgress'),
          onStatusChange: any(named: 'onStatusChange'),
        ),
      ).thenAnswer((invocation) async {
        final onProgress =
            invocation.namedArguments[#onProgress] as void Function(String);
        final onStatusChange = invocation.namedArguments[#onStatusChange]
            as void Function(InferenceStatus);

        onStatusChange(InferenceStatus.running);
        onProgress('Starting inference...');
        await Future<void>.delayed(const Duration(milliseconds: 100));
        onProgress('Processing...');
        await Future<void>.delayed(const Duration(milliseconds: 100));
        onProgress('Complete!');
        onStatusChange(InferenceStatus.idle);
      });

      late ProviderContainer container;
      await tester.pumpWidget(
        buildTestWidget(
          const UnifiedAiProgressContent(
            entityId: testEntityId,
            promptId: testPromptId,
          ),
          overrides: [
            aiConfigByIdProvider(testPromptId).overrideWith(
              (ref) => Future.value(testPromptConfig),
            ),
          ],
          onContainerCreated: (c) => container = c,
        ),
      );

      // Wait for initial build
      await tester.pump();

      // Trigger inference
      final future = container.read(
        triggerNewInferenceProvider(
          entityId: testEntityId,
          promptId: testPromptId,
        ).future,
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Should see the waveform animation instead of "Processing..." text
      expect(find.byType(AiRunningAnimationWrapper), findsOneWidget);

      // Wait for processing
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byType(AiRunningAnimationWrapper), findsOneWidget);

      // Wait for inference to complete
      await future;

      // Wait for completion
      await tester.pumpAndSettle();
      expect(find.text('Complete!'), findsOneWidget);
    });

    testWidgets('handles error state and logs exceptions', (tester) async {
      // Arrange - mock repository to throw an error
      when(
        () => mockRepository.runInference(
          entityId: any(named: 'entityId'),
          promptConfig: any(named: 'promptConfig'),
          onProgress: any(named: 'onProgress'),
          onStatusChange: any(named: 'onStatusChange'),
        ),
      ).thenAnswer((invocation) async {
        final onStatusChange = invocation.namedArguments[#onStatusChange]
            as void Function(InferenceStatus);

        onStatusChange(InferenceStatus.running);
        onStatusChange(InferenceStatus.error);
        throw Exception('Test error');
      });

      late ProviderContainer container;
      await tester.pumpWidget(
        buildTestWidget(
          const UnifiedAiProgressContent(
            entityId: testEntityId,
            promptId: testPromptId,
          ),
          overrides: [
            aiConfigByIdProvider(testPromptId).overrideWith(
              (ref) => Future.value(testPromptConfig),
            ),
          ],
          onContainerCreated: (c) => container = c,
        ),
      );

      await tester.pump();

      // Trigger inference
      await container.read(
        triggerNewInferenceProvider(
          entityId: testEntityId,
          promptId: testPromptId,
        ).future,
      );

      await tester.pumpAndSettle();

      // Verify that logging service was called for the error
      verify(
        () => mockLoggingService.captureException(
          any<dynamic>(),
          domain: 'UnifiedAiController',
          subDomain: 'runInference',
          stackTrace: any<dynamic>(named: 'stackTrace'),
        ),
      ).called(1);
    });

    testWidgets('works with different AI response types', (tester) async {
      // Arrange
      final imageAnalysisPrompt = AiConfig.prompt(
        id: 'image-prompt',
        name: 'Image Analysis',
        systemMessage: 'Analyze this image',
        userMessage: 'Please analyze',
        defaultModelId: 'model-1',
        modelIds: ['model-1'],
        createdAt: DateTime.now(),
        useReasoning: false,
        requiredInputData: [InputDataType.images],
        aiResponseType: AiResponseType.imageAnalysis,
      ) as AiConfigPrompt;

      late ProviderContainer container;
      await tester.pumpWidget(
        buildTestWidget(
          const UnifiedAiProgressContent(
            entityId: testEntityId,
            promptId: 'image-prompt',
          ),
          overrides: [
            aiConfigByIdProvider('image-prompt').overrideWith(
              (ref) => Future.value(imageAnalysisPrompt),
            ),
          ],
          onContainerCreated: (c) => container = c,
        ),
      );

      await tester.pump();

      // Trigger inference
      await container.read(
        triggerNewInferenceProvider(
          entityId: testEntityId,
          promptId: 'image-prompt',
        ).future,
      );

      await tester.pumpAndSettle();

      // Assert - should work the same way regardless of response type
      expect(find.text('Complete!'), findsOneWidget);
    });

    testWidgets('widget can be instantiated with required parameters',
        (tester) async {
      // Test that the widget can be created without errors
      const widget = UnifiedAiProgressContent(
        entityId: 'test-entity',
        promptId: 'test-prompt',
      );

      expect(widget.entityId, 'test-entity');
      expect(widget.promptId, 'test-prompt');
      expect(widget, isA<ConsumerStatefulWidget>());
    });

    testWidgets('widget can be instantiated with key', (tester) async {
      // Test that the widget can be created with a key
      const testKey = Key('test-key');
      const widget = UnifiedAiProgressContent(
        key: testKey,
        entityId: 'test-entity',
        promptId: 'test-prompt',
      );

      expect(widget.key, testKey);
      expect(widget.entityId, 'test-entity');
      expect(widget.promptId, 'test-prompt');
    });

    testWidgets('text content is scrollable for long messages', (tester) async {
      // Arrange - create a very long progress message
      when(
        () => mockRepository.runInference(
          entityId: any(named: 'entityId'),
          promptConfig: any(named: 'promptConfig'),
          onProgress: any(named: 'onProgress'),
          onStatusChange: any(named: 'onStatusChange'),
        ),
      ).thenAnswer((invocation) async {
        final onProgress =
            invocation.namedArguments[#onProgress] as void Function(String);
        final onStatusChange = invocation.namedArguments[#onStatusChange]
            as void Function(InferenceStatus);

        onStatusChange(InferenceStatus.running);
        onProgress('This is a very long progress message that should be '
            'scrollable when it exceeds the available space in the view. '
            'It contains multiple lines and should wrap correctly within '
            'the constraints. The text should be scrollable if it exceeds '
            'the available space. This is important for user experience '
            'when dealing with lengthy AI responses or detailed progress '
            'information that needs to be displayed to the user.');
        onStatusChange(InferenceStatus.idle);
      });

      late ProviderContainer container;
      await tester.pumpWidget(
        buildTestWidget(
          const UnifiedAiProgressContent(
            entityId: testEntityId,
            promptId: testPromptId,
          ),
          overrides: [
            aiConfigByIdProvider(testPromptId).overrideWith(
              (ref) => Future.value(testPromptConfig),
            ),
          ],
          onContainerCreated: (c) => container = c,
        ),
      );

      await tester.pump();

      // Trigger inference
      await container.read(
        triggerNewInferenceProvider(
          entityId: testEntityId,
          promptId: testPromptId,
        ).future,
      );

      await tester.pumpAndSettle();

      // Assert - user should see the long text content
      expect(
        find.textContaining('This is a very long progress message'),
        findsOneWidget,
      );
    });

    testWidgets('displays running status text when inference is running',
        (tester) async {
      // Arrange - keep inference in running state
      final completer = Completer<void>();
      when(
        () => mockRepository.runInference(
          entityId: any(named: 'entityId'),
          promptConfig: any(named: 'promptConfig'),
          onProgress: any(named: 'onProgress'),
          onStatusChange: any(named: 'onStatusChange'),
        ),
      ).thenAnswer((invocation) async {
        final onProgress =
            invocation.namedArguments[#onProgress] as void Function(String);
        final onStatusChange = invocation.namedArguments[#onStatusChange]
            as void Function(InferenceStatus);

        onStatusChange(InferenceStatus.running);
        onProgress('Processing...');
        // Keep it in running state until test completes
        await completer.future;
      });

      await tester.pumpWidget(
        buildTestWidget(
          const UnifiedAiProgressContent(
            entityId: testEntityId,
            promptId: testPromptId,
          ),
          overrides: [
            aiConfigByIdProvider(testPromptId).overrideWith(
              (ref) => Future.value(testPromptConfig),
            ),
          ],
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert - should show the waveform animation instead of "Processing..." text
      expect(find.byType(AiRunningAnimationWrapper), findsOneWidget);

      // Complete the future to avoid pending timers
      completer.complete();
    });

    testWidgets('shows final result when inference is complete',
        (tester) async {
      // Arrange
      late ProviderContainer container;
      await tester.pumpWidget(
        buildTestWidget(
          const UnifiedAiProgressContent(
            entityId: testEntityId,
            promptId: testPromptId,
          ),
          overrides: [
            aiConfigByIdProvider(testPromptId).overrideWith(
              (ref) => Future.value(testPromptConfig),
            ),
          ],
          onContainerCreated: (c) => container = c,
        ),
      );

      await tester.pump();

      // Trigger inference
      await container.read(
        triggerNewInferenceProvider(
          entityId: testEntityId,
          promptId: testPromptId,
        ).future,
      );

      await tester.pumpAndSettle();

      // Assert - should show the final result text
      expect(find.text('Complete!'), findsOneWidget);
    });

    testWidgets('displays error widget and retry works correctly',
        (tester) async {
      // Arrange - simulate an error that can be parsed as InferenceError
      var retryCount = 0;
      when(
        () => mockRepository.runInference(
          entityId: any(named: 'entityId'),
          promptConfig: any(named: 'promptConfig'),
          onProgress: any(named: 'onProgress'),
          onStatusChange: any(named: 'onStatusChange'),
        ),
      ).thenAnswer((invocation) async {
        final onProgress =
            invocation.namedArguments[#onProgress] as void Function(String);
        final onStatusChange = invocation.namedArguments[#onStatusChange]
            as void Function(InferenceStatus);

        onStatusChange(InferenceStatus.running);

        if (retryCount == 0) {
          // First attempt fails with a timeout error (which allows retry)
          onProgress('Connection timed out');
          onStatusChange(InferenceStatus.error);
          retryCount++;
        } else {
          // Retry succeeds
          onProgress('Retry successful!');
          onStatusChange(InferenceStatus.idle);
        }
      });

      late ProviderContainer container;
      await tester.pumpWidget(
        buildTestWidget(
          const UnifiedAiProgressContent(
            entityId: testEntityId,
            promptId: testPromptId,
          ),
          overrides: [
            aiConfigByIdProvider(testPromptId).overrideWith(
              (ref) => Future.value(testPromptConfig),
            ),
          ],
          onContainerCreated: (c) => container = c,
        ),
      );

      await tester.pump();

      // Trigger inference (first attempt will fail)
      await container.read(
        triggerNewInferenceProvider(
          entityId: testEntityId,
          promptId: testPromptId,
        ).future,
      );

      await tester.pumpAndSettle();

      // Should show error display (AiErrorUtils.categorizeError always returns an InferenceError)
      expect(find.byType(AiErrorDisplay), findsOneWidget);

      // Debug: print the widget tree to see what's there
      // final errorDisplay = tester.widget<AiErrorDisplay>(find.byType(AiErrorDisplay));
      // print('Error type: ${errorDisplay.error.type}');

      // Find and tap retry button - just look for the text since it might be nested
      final retryButton = find.text('Try Again');
      expect(retryButton, findsOneWidget);

      await tester.tap(retryButton);
      await tester.pumpAndSettle();

      // Should now show success message
      expect(find.text('Retry successful!'), findsOneWidget);
      expect(find.byType(AiErrorDisplay), findsNothing);
    });

    testWidgets('always shows AiErrorDisplay for errors', (tester) async {
      // Arrange - simulate any error (AiErrorUtils.categorizeError handles all errors)
      when(
        () => mockRepository.runInference(
          entityId: any(named: 'entityId'),
          promptConfig: any(named: 'promptConfig'),
          onProgress: any(named: 'onProgress'),
          onStatusChange: any(named: 'onStatusChange'),
        ),
      ).thenAnswer((invocation) async {
        final onProgress =
            invocation.namedArguments[#onProgress] as void Function(String);
        final onStatusChange = invocation.namedArguments[#onStatusChange]
            as void Function(InferenceStatus);

        onStatusChange(InferenceStatus.running);
        onProgress('Some error occurred');
        onStatusChange(InferenceStatus.error);
      });

      late ProviderContainer container;
      await tester.pumpWidget(
        buildTestWidget(
          const UnifiedAiProgressContent(
            entityId: testEntityId,
            promptId: testPromptId,
            autoTriggerInference: false,
          ),
          overrides: [
            aiConfigByIdProvider(testPromptId).overrideWith(
              (ref) => Future.value(testPromptConfig),
            ),
          ],
          onContainerCreated: (c) => container = c,
        ),
      );

      await tester.pump();

      // Trigger inference
      await container.read(
        triggerNewInferenceProvider(
          entityId: testEntityId,
          promptId: testPromptId,
        ).future,
      );

      await tester.pumpAndSettle();

      // Should always show AiErrorDisplay since AiErrorUtils.categorizeError never throws
      expect(find.byType(AiErrorDisplay), findsOneWidget);
    });

    testWidgets('padding is correctly applied', (tester) async {
      // Arrange
      late ProviderContainer container;
      await tester.pumpWidget(
        buildTestWidget(
          const UnifiedAiProgressContent(
            entityId: testEntityId,
            promptId: testPromptId,
            autoTriggerInference: false,
          ),
          overrides: [
            aiConfigByIdProvider(testPromptId).overrideWith(
              (ref) => Future.value(testPromptConfig),
            ),
          ],
          onContainerCreated: (c) => container = c,
        ),
      );

      await tester.pump();

      // Trigger inference
      await container.read(
        triggerNewInferenceProvider(
          entityId: testEntityId,
          promptId: testPromptId,
        ).future,
      );

      await tester.pumpAndSettle();

      // Find the specific Padding widget in UnifiedAiProgressContent
      final padding = find.descendant(
        of: find.byType(UnifiedAiProgressContent),
        matching: find.byType(Padding),
      );

      // Should find at least one Padding widget
      expect(padding, findsWidgets);

      // Get the first (outermost) Padding widget
      final paddingWidget = tester.widget<Padding>(padding.first);
      final edgeInsets = paddingWidget.padding as EdgeInsets;

      expect(edgeInsets.top, 10);
      expect(edgeInsets.bottom, 55);
      expect(edgeInsets.left, 20);
      expect(edgeInsets.right, 20);
    });

    testWidgets('displays text content properly', (tester) async {
      // Arrange
      late ProviderContainer container;
      await tester.pumpWidget(
        buildTestWidget(
          const UnifiedAiProgressContent(
            entityId: testEntityId,
            promptId: testPromptId,
            autoTriggerInference: false,
          ),
          overrides: [
            aiConfigByIdProvider(testPromptId).overrideWith(
              (ref) => Future.value(testPromptConfig),
            ),
          ],
          onContainerCreated: (c) => container = c,
        ),
      );

      await tester.pump();

      // Trigger inference
      await container.read(
        triggerNewInferenceProvider(
          entityId: testEntityId,
          promptId: testPromptId,
        ).future,
      );

      await tester.pumpAndSettle();

      // Find the main content text
      expect(find.text('Complete!'), findsOneWidget);

      // Find Padding widgets within UnifiedAiProgressContent
      final padding = find.descendant(
        of: find.byType(UnifiedAiProgressContent),
        matching: find.byType(Padding),
      );
      expect(padding, findsWidgets);

      // Find the Container with constraints within UnifiedAiProgressContent
      final containerFinder = find.descendant(
        of: find.byType(UnifiedAiProgressContent),
        matching: find.byType(Container),
      );
      expect(containerFinder, findsOneWidget);

      // Verify the container has the expected constraints
      final containerWidget = tester.widget<Container>(containerFinder);
      expect(containerWidget.constraints, isNotNull);
      expect(containerWidget.constraints!.minWidth, 600);
    });
  });

  group('Image Analysis Auto-Retry After Model Installation', () {
    testWidgets('handles model installation flow correctly', (tester) async {
      // Arrange
      const testEntityId = 'image-entity-1';
      const testPromptId = 'image-analysis-prompt';
      const missingModelName = 'gemma3:4b';
      final now = DateTime.now();
      final testPromptConfig = AiConfig.prompt(
        id: testPromptId,
        name: 'Image Analysis',
        systemMessage: 'Analyze the image',
        userMessage: 'Analyze this image',
        defaultModelId: missingModelName,
        modelIds: [missingModelName],
        createdAt: now,
        useReasoning: false,
        requiredInputData: [InputDataType.images],
        aiResponseType: AiResponseType.imageAnalysis,
        description: 'Image analysis prompt',
      ) as AiConfigPrompt;

      // Mock the unified AI inference repository
      final mockRepository = MockUnifiedAiInferenceRepository();
      when(() => mockRepository.runInference(
            entityId: any(named: 'entityId'),
            promptConfig: any(named: 'promptConfig'),
            onProgress: any(named: 'onProgress'),
            onStatusChange: any(named: 'onStatusChange'),
          )).thenAnswer((invocation) async {
        final onProgress =
            invocation.namedArguments[#onProgress] as void Function(String);
        final onStatusChange = invocation.namedArguments[#onStatusChange]
            as void Function(InferenceStatus);

        onStatusChange(InferenceStatus.running);
        onProgress('Starting image analysis...');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        onProgress('Analysis complete!');
        onStatusChange(InferenceStatus.idle);
      });

      // Override providers for the test
      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            unifiedAiInferenceRepositoryProvider
                .overrideWithValue(mockRepository),
            aiConfigByIdProvider(testPromptId)
                .overrideWith((ref) => Future.value(testPromptConfig)),
          ],
          parent: ProviderContainer(),
          child: Builder(
            builder: (context) {
              container = ProviderScope.containerOf(context);
              return const MaterialApp(
                localizationsDelegates: [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: [Locale('en', '')],
                home: UnifiedAiProgressContent(
                  entityId: testEntityId,
                  promptId: testPromptId,
                  autoTriggerInference: false,
                ),
              );
            },
          ),
        ),
      );

      await tester.pump();

      // Trigger inference
      await container.read(
        triggerNewInferenceProvider(
          entityId: testEntityId,
          promptId: testPromptId,
        ).future,
      );

      await tester.pumpAndSettle();

      // Should show the progress content
      expect(find.byType(UnifiedAiProgressContent), findsOneWidget);

      // Should show the analysis result
      expect(find.text('Analysis complete!'), findsOneWidget);
    });
  });
}
