import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/ai/ui/settings/services/provider_prompt_setup_service.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/fallbacks.dart';
import '../../../../../mocks/mocks.dart';
import '../../../test_utils.dart';
import 'ftue_test_harness.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  group('MistralFtueResult', () {
    test('should include optional categoryName', () {
      const result = MistralFtueResult(
        modelsCreated: 3,
        modelsVerified: 0,
        categoryCreated: false,
        categoryName: 'Test Category Mistral',
      );

      expect(result.categoryName, equals('Test Category Mistral'));
    });

    test('should handle errors list', () {
      const result = MistralFtueResult(
        modelsCreated: 0,
        modelsVerified: 0,
        categoryCreated: false,
        errors: ['Mistral Error 1', 'Mistral Error 2'],
      );

      expect(result.errors, hasLength(2));
      expect(result.errors, contains('Mistral Error 1'));
      expect(result.errors, contains('Mistral Error 2'));
    });
  });

  group('Mistral FTUE Setup - performMistralFtueSetup', () {
    late ProviderPromptSetupService setupService;
    late MockAiConfigRepository mockRepository;
    late MockCategoryRepository mockCategoryRepository;
    late AiConfigInferenceProvider mistralProvider;

    setUp(() {
      setupService = const ProviderPromptSetupService();
      mockRepository = MockAiConfigRepository();
      mockCategoryRepository = MockCategoryRepository();

      mistralProvider = AiTestDataFactory.createTestProvider(
        id: 'mistral-provider-id',
        name: 'Mistral',
        type: InferenceProviderType.mistral,
        apiKey: 'test-mistral-key',
        baseUrl: 'https://api.mistral.ai/v1',
      );
      when(
        () => mockRepository.getConfigsByType(AiConfigType.inferenceProvider),
      ).thenAnswer((_) async => [mistralProvider]);
    });

    testWidgets('should return null for non-Mistral provider', (
      WidgetTester tester,
    ) async {
      final geminiProvider = AiTestDataFactory.createTestProvider(
        id: 'gemini-id',
        name: 'Gemini',
        type: InferenceProviderType.gemini,
      );

      MistralFtueResult? result;
      await tester.pumpWidget(
        buildFtueHarness(
          repository: mockRepository,
          categoryRepository: mockCategoryRepository,
          onPressed: (context, ref) async {
            return result = await setupService.performMistralFtueSetup(
              context: context,
              ref: ref,
              provider: geminiProvider,
            );
          },
        ),
      );

      await tester.tap(find.text('Test'));
      await tester.pump();

      expect(result, isNull);
    });

    testWidgets('should create 3 models when they do not exist', (
      WidgetTester tester,
    ) async {
      when(
        () => mockRepository.getConfigsByType(AiConfigType.model),
      ).thenAnswer((_) async => <AiConfig>[]);
      when(() => mockRepository.saveConfig(any())).thenAnswer((_) async {});
      when(
        () => mockCategoryRepository.getAllCategories(),
      ).thenAnswer((_) async => <CategoryDefinition>[]);
      when(
        () => mockCategoryRepository.createCategory(
          name: any(named: 'name'),
          color: any(named: 'color'),
          defaultProfileId: any(named: 'defaultProfileId'),
          defaultTemplateId: any(named: 'defaultTemplateId'),
        ),
      ).thenAnswer(
        (_) async => CategoryDefinition(
          id: 'test-category-id',
          name: 'Test Category Mistral Enabled',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
          private: false,
          active: true,
        ),
      );
      when(() => mockCategoryRepository.updateCategory(any())).thenAnswer(
        (invocation) async =>
            invocation.positionalArguments[0] as CategoryDefinition,
      );

      MistralFtueResult? result;
      await tester.pumpWidget(
        buildFtueHarness(
          repository: mockRepository,
          categoryRepository: mockCategoryRepository,
          onPressed: (context, ref) async {
            return result = await setupService.performMistralFtueSetup(
              context: context,
              ref: ref,
              provider: mistralProvider,
            );
          },
        ),
      );

      await tester.tap(find.text('Test'));
      await tester.pump();

      expect(result, isNotNull);
      expect(result!.modelsCreated, equals(4));
      expect(result!.modelsVerified, equals(0));
      expect(result!.categoryCreated, isTrue);

      // One model row per Mistral (EU) profile slot, read aloud included.
      final saved = verify(
        () => mockRepository.saveConfig(captureAny()),
      ).captured.cast<AiConfigModel>();
      expect(saved.map((m) => m.providerModelId), [
        'deepseek-v4-1-flash-1017',
        'mistral-large-4-0',
        'voxtral-mini-transcribe-3-0',
        'voxtral-mini-tts-3-0',
      ]);
      expect(
        saved.map((m) => m.inferenceProviderId).toSet(),
        {mistralProvider.id},
      );
    });

    testWidgets('should verify existing models and skip creation', (
      WidgetTester tester,
    ) async {
      final existingModels = [
        AiTestDataFactory.createTestModel(
          id: 'existing-thinking',
          name: 'DeepSeek V4.1 Flash',
          providerModelId: ftueMistralThinkingModelId,
          inferenceProviderId: mistralProvider.id,
        ),
        AiTestDataFactory.createTestModel(
          id: 'existing-high-end',
          name: 'Mistral Large 4',
          providerModelId: ftueMistralHighEndThinkingModelId,
          inferenceProviderId: mistralProvider.id,
        ),
        AiTestDataFactory.createTestModel(
          id: 'existing-transcription',
          name: 'Voxtral Mini Transcribe 3',
          providerModelId: ftueMistralTranscriptionModelId,
          inferenceProviderId: mistralProvider.id,
        ),
        AiTestDataFactory.createTestModel(
          id: 'existing-speech',
          name: 'Voxtral TTS 3',
          providerModelId: ftueMistralSpeechModelId,
          inferenceProviderId: mistralProvider.id,
        ),
      ];

      when(
        () => mockRepository.getConfigsByType(AiConfigType.model),
      ).thenAnswer((_) async => existingModels);
      when(() => mockRepository.saveConfig(any())).thenAnswer((_) async {});
      when(
        () => mockCategoryRepository.getAllCategories(),
      ).thenAnswer((_) async => <CategoryDefinition>[]);
      when(
        () => mockCategoryRepository.createCategory(
          name: any(named: 'name'),
          color: any(named: 'color'),
          defaultProfileId: any(named: 'defaultProfileId'),
          defaultTemplateId: any(named: 'defaultTemplateId'),
        ),
      ).thenAnswer(
        (_) async => CategoryDefinition(
          id: 'test-category-id',
          name: 'Test Category Mistral Enabled',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
          private: false,
          active: true,
        ),
      );
      when(() => mockCategoryRepository.updateCategory(any())).thenAnswer(
        (invocation) async =>
            invocation.positionalArguments[0] as CategoryDefinition,
      );

      MistralFtueResult? result;
      await tester.pumpWidget(
        buildFtueHarness(
          repository: mockRepository,
          categoryRepository: mockCategoryRepository,
          onPressed: (context, ref) async {
            return result = await setupService.performMistralFtueSetup(
              context: context,
              ref: ref,
              provider: mistralProvider,
            );
          },
        ),
      );

      await tester.tap(find.text('Test'));
      await tester.pump();

      expect(result, isNotNull);
      expect(result!.modelsCreated, equals(0));
      expect(result!.modelsVerified, equals(4));
    });

    testWidgets('should reuse existing category instead of creating new one', (
      WidgetTester tester,
    ) async {
      when(
        () => mockRepository.getConfigsByType(AiConfigType.model),
      ).thenAnswer((_) async => <AiConfig>[]);
      when(() => mockRepository.saveConfig(any())).thenAnswer((_) async {});

      final existingCategory = CategoryDefinition(
        id: 'existing-category-id',
        name: 'Test Category Mistral Enabled',
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
        private: false,
        active: true,
      );
      when(
        () => mockCategoryRepository.getAllCategories(),
      ).thenAnswer((_) async => [existingCategory]);

      MistralFtueResult? result;
      await tester.pumpWidget(
        buildFtueHarness(
          repository: mockRepository,
          categoryRepository: mockCategoryRepository,
          onPressed: (context, ref) async {
            return result = await setupService.performMistralFtueSetup(
              context: context,
              ref: ref,
              provider: mistralProvider,
            );
          },
        ),
      );

      await tester.tap(find.text('Test'));
      await tester.pump();

      expect(result, isNotNull);
      expect(result!.categoryCreated, isFalse);
      expect(result!.categoryName, equals('Test Category Mistral Enabled'));

      verifyNever(() => mockCategoryRepository.updateCategory(any()));
      verifyNever(
        () => mockCategoryRepository.createCategory(
          name: any(named: 'name'),
          color: any(named: 'color'),
          defaultProfileId: any(named: 'defaultProfileId'),
          defaultTemplateId: any(named: 'defaultTemplateId'),
        ),
      );
    });

    testWidgets('should create category with Mistral orange color', (
      WidgetTester tester,
    ) async {
      when(
        () => mockRepository.getConfigsByType(AiConfigType.model),
      ).thenAnswer((_) async => <AiConfig>[]);
      when(() => mockRepository.saveConfig(any())).thenAnswer((_) async {});
      when(
        () => mockCategoryRepository.getAllCategories(),
      ).thenAnswer((_) async => <CategoryDefinition>[]);
      when(
        () => mockCategoryRepository.createCategory(
          name: any(named: 'name'),
          color: any(named: 'color'),
          defaultProfileId: any(named: 'defaultProfileId'),
          defaultTemplateId: any(named: 'defaultTemplateId'),
        ),
      ).thenAnswer(
        (_) async => CategoryDefinition(
          id: 'test-category-id',
          name: 'Test Category Mistral Enabled',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
          private: false,
          active: true,
        ),
      );
      when(() => mockCategoryRepository.updateCategory(any())).thenAnswer(
        (invocation) async =>
            invocation.positionalArguments[0] as CategoryDefinition,
      );

      await tester.pumpWidget(
        buildFtueHarness(
          repository: mockRepository,
          categoryRepository: mockCategoryRepository,
          onPressed: (context, ref) async {
            return setupService.performMistralFtueSetup(
              context: context,
              ref: ref,
              provider: mistralProvider,
            );
          },
        ),
      );

      await tester.tap(find.text('Test'));
      await tester.pump();

      verify(
        () => mockCategoryRepository.createCategory(
          name: 'Test Category Mistral Enabled',
          color: '#FF7000', // Mistral Orange
          defaultProfileId: any(named: 'defaultProfileId'),
          defaultTemplateId: any(named: 'defaultTemplateId'),
        ),
      ).called(1);
    });
  });
}
