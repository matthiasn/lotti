import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/unified_ai_inference_repository.dart';
import 'package:lotti/features/ai/state/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/ui/unified_ai_progress_view.dart';
import 'package:lotti/get_it.dart';
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
  }) {
    return ProviderScope(
      overrides: [
        unifiedAiInferenceRepositoryProvider.overrideWithValue(mockRepository),
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

  group('UnifiedAiProgressView Tests', () {
    const testEntityId = 'test-entity-1';
    const testPromptId = 'test-prompt-1';

    testWidgets('shows loading indicator when prompt config is loading',
        (tester) async {
      // Arrange
      final completer = Completer<AiConfig?>();

      await tester.pumpWidget(
        buildTestWidget(
          const UnifiedAiProgressView(
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
          const UnifiedAiProgressView(
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
          const UnifiedAiProgressView(
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
          const UnifiedAiProgressView(
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
      await tester.pumpWidget(
        buildTestWidget(
          const UnifiedAiProgressView(
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
        onProgress('Almost done...');
        await Future<void>.delayed(const Duration(milliseconds: 100));
        onProgress('Complete!');
        onStatusChange(InferenceStatus.idle);
      });

      await tester.pumpWidget(
        buildTestWidget(
          const UnifiedAiProgressView(
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

      // Wait for initial build
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Should see starting message
      expect(find.text('Starting inference...'), findsOneWidget);

      // Wait for processing
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('Processing...'), findsOneWidget);

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

      await tester.pumpWidget(
        buildTestWidget(
          const UnifiedAiProgressView(
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

      await tester.pumpWidget(
        buildTestWidget(
          const UnifiedAiProgressView(
            entityId: testEntityId,
            promptId: 'image-prompt',
          ),
          overrides: [
            aiConfigByIdProvider('image-prompt').overrideWith(
              (ref) => Future.value(imageAnalysisPrompt),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Assert - should work the same way regardless of response type
      expect(find.text('Complete!'), findsOneWidget);
    });

    testWidgets('widget can be instantiated with required parameters',
        (tester) async {
      // Test that the widget can be created without errors
      const widget = UnifiedAiProgressView(
        entityId: 'test-entity',
        promptId: 'test-prompt',
      );

      expect(widget.entityId, 'test-entity');
      expect(widget.promptId, 'test-prompt');
      expect(widget, isA<ConsumerWidget>());
    });

    testWidgets('widget can be instantiated with key', (tester) async {
      // Test that the widget can be created with a key
      const testKey = Key('test-key');
      const widget = UnifiedAiProgressView(
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

      await tester.pumpWidget(
        buildTestWidget(
          const UnifiedAiProgressView(
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

      await tester.pumpAndSettle();

      // Assert - user should see the long text content
      expect(
        find.textContaining('This is a very long progress message'),
        findsOneWidget,
      );

      // The content should be in a scrollable view
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });
  });
}
