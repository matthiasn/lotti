import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/unified_ai_inference_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/ui/unified_ai_progress_view.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

class MockUnifiedAiInferenceRepository extends Mock
    implements UnifiedAiInferenceRepository {}

class MockLoggingService extends Mock implements LoggingService {}

class MockCloudInferenceRepository extends Mock
    implements CloudInferenceRepository {}

class MockCategoryRepository extends Mock implements CategoryRepository {}

class FakeAiConfigPrompt extends Fake implements AiConfigPrompt {}

class FakeJournalEntity extends Fake implements JournalEntity {}

void main() {
  late AiConfigPrompt testPromptConfig;
  late MockUnifiedAiInferenceRepository mockRepository;
  late MockLoggingService mockLoggingService;
  late MockCloudInferenceRepository mockCloudRepository;
  late MockCategoryRepository mockCategoryRepository;

  setUpAll(() {
    registerFallbackValue(InferenceStatus.idle);
    registerFallbackValue(StackTrace.current);
    registerFallbackValue(FakeAiConfigPrompt());
    registerFallbackValue(FakeJournalEntity());
  });

  setUp(() {
    final now = DateTime.now();
    testPromptConfig = AiConfig.prompt(
      id: 'test-prompt-1',
      name: 'Test Prompt',
      systemMessage: 'System message',
      userMessage: 'Test prompt text',
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
    mockCloudRepository = MockCloudInferenceRepository();
    mockCategoryRepository = MockCategoryRepository();

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

    // Mock repository getActivePromptsForContext
    when(() => mockRepository.getActivePromptsForContext(
          entity: any(named: 'entity'),
        )).thenAnswer((_) async => [testPromptConfig]);

    // Mock category repository
    when(() => mockCategoryRepository.watchCategory(any()))
        .thenAnswer((_) => Stream.value(null));
  });

  tearDown(() {
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
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

    testWidgets('shows loading indicator when prompt config is loading',
        (tester) async {
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

    testWidgets('shows invalid config message when config is null',
        (tester) async {
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

    testWidgets('shows invalid config message when config is wrong type',
        (tester) async {
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

      expect(find.text('Invalid prompt configuration'), findsOneWidget);
    });
  });

  group('UnifiedAiProgressContent - Inference Behavior', () {
    const testEntityId = 'test-entity-1';
    const testPromptId = 'test-prompt-1';

    testWidgets('does NOT trigger inference when showExisting is true',
        (tester) async {
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

  group('UnifiedAiProgressUtils', () {
    testWidgets('progressPage creates valid modal page', (tester) async {
      final prompt = AiConfig.prompt(
        id: 'test-prompt',
        name: 'Test Prompt Title',
        systemMessage: 'System message',
        userMessage: 'Test prompt text',
        defaultModelId: 'model-1',
        modelIds: ['model-1'],
        createdAt: DateTime.now(),
        useReasoning: false,
        requiredInputData: [InputDataType.task],
        aiResponseType: AiResponseType.taskSummary,
        description: 'Test description',
      ) as AiConfigPrompt;

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
}
