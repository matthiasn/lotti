import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/services/provider_prompt_setup_service.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/ai/util/profile_seeding_service.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart'
    show categoryRepositoryProvider;
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../test_utils.dart';

void main() {
  group('Service Construction', () {
    test('should be const constructible', () {
      const service1 = ProviderPromptSetupService();
      const service2 = ProviderPromptSetupService();
      expect(service1, isA<ProviderPromptSetupService>());
      expect(service2, isA<ProviderPromptSetupService>());
    });

    test('should maintain consistent behavior across instances', () {
      const service1 = ProviderPromptSetupService();
      const service2 = ProviderPromptSetupService();
      expect(identical(service1, service2), isTrue);
    });
  });

  group('GeminiFtueResult', () {
    test(
      'totalModels should return sum of modelsCreated and modelsVerified',
      () {
        const result = GeminiFtueResult(
          modelsCreated: 2,
          modelsVerified: 1,
          categoryCreated: true,
        );

        expect(result.totalModels, equals(3));
      },
    );

    test('should handle zero values correctly', () {
      const result = GeminiFtueResult(
        modelsCreated: 0,
        modelsVerified: 0,
        categoryCreated: false,
      );

      expect(result.totalModels, equals(0));
    });

    test('should include optional categoryReused and categoryName', () {
      const result = GeminiFtueResult(
        modelsCreated: 3,
        modelsVerified: 0,
        categoryCreated: false,
        categoryReused: true,
        categoryName: 'Test Category',
      );

      expect(result.categoryReused, isTrue);
      expect(result.categoryName, equals('Test Category'));
    });

    test('should handle errors list', () {
      const result = GeminiFtueResult(
        modelsCreated: 0,
        modelsVerified: 0,
        categoryCreated: false,
        errors: ['Error 1', 'Error 2'],
      );

      expect(result.errors, hasLength(2));
      expect(result.errors, contains('Error 1'));
      expect(result.errors, contains('Error 2'));
    });
  });

  group('OpenAiFtueResult', () {
    test(
      'totalModels should return sum of modelsCreated and modelsVerified',
      () {
        const result = OpenAiFtueResult(
          modelsCreated: 3,
          modelsVerified: 1,
          categoryCreated: true,
        );

        expect(result.totalModels, equals(4));
      },
    );

    test('should handle zero values correctly', () {
      const result = OpenAiFtueResult(
        modelsCreated: 0,
        modelsVerified: 0,
        categoryCreated: false,
      );

      expect(result.totalModels, equals(0));
    });

    test('should include optional categoryReused and categoryName', () {
      const result = OpenAiFtueResult(
        modelsCreated: 4,
        modelsVerified: 0,
        categoryCreated: false,
        categoryReused: true,
        categoryName: 'Test Category OpenAI',
      );

      expect(result.categoryReused, isTrue);
      expect(result.categoryName, equals('Test Category OpenAI'));
    });

    test('should handle errors list', () {
      const result = OpenAiFtueResult(
        modelsCreated: 0,
        modelsVerified: 0,
        categoryCreated: false,
        errors: ['OpenAI Error 1', 'OpenAI Error 2'],
      );

      expect(result.errors, hasLength(2));
      expect(result.errors, contains('OpenAI Error 1'));
      expect(result.errors, contains('OpenAI Error 2'));
    });
  });

  group('OpenAI FTUE Setup - performOpenAiFtueSetup', () {
    late ProviderPromptSetupService setupService;
    late MockAiConfigRepository mockRepository;
    late MockCategoryRepository mockCategoryRepository;
    late AiConfigInferenceProvider openAiProvider;

    setUpAll(() {
      registerFallbackValue(
        AiConfig.model(
          id: 'fallback-model',
          name: 'Fallback',
          providerModelId: 'fallback',
          inferenceProviderId: 'fallback',
          createdAt: DateTime(2024, 3, 15),
          inputModalities: [Modality.text],
          outputModalities: [Modality.text],
          isReasoningModel: false,
        ),
      );
      registerFallbackValue(
        CategoryDefinition(
          id: 'fallback-category',
          name: 'Fallback',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
          private: false,
          active: true,
        ),
      );
    });

    setUp(() {
      setupService = const ProviderPromptSetupService();
      mockRepository = MockAiConfigRepository();
      mockCategoryRepository = MockCategoryRepository();

      openAiProvider = AiTestDataFactory.createTestProvider(
        id: 'openai-provider-id',
        name: 'OpenAI',
        type: InferenceProviderType.openAi,
        apiKey: 'test-openai-key',
        baseUrl: 'https://api.openai.com/v1',
      );
    });

    Widget createOpenAiFtueTestWidget({
      required Future<OpenAiFtueResult?> Function(BuildContext, WidgetRef)
      onPressed,
    }) {
      return ProviderScope(
        overrides: [
          aiConfigRepositoryProvider.overrideWithValue(mockRepository),
          categoryRepositoryProvider.overrideWithValue(mockCategoryRepository),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                return ElevatedButton(
                  onPressed: () async {
                    await onPressed(context, ref);
                  },
                  child: const Text('Test'),
                );
              },
            ),
          ),
        ),
      );
    }

    testWidgets('should return null for non-OpenAI provider', (
      WidgetTester tester,
    ) async {
      final geminiProvider = AiTestDataFactory.createTestProvider(
        id: 'gemini-id',
        name: 'Gemini',
        type: InferenceProviderType.gemini,
      );

      OpenAiFtueResult? result;
      await tester.pumpWidget(
        createOpenAiFtueTestWidget(
          onPressed: (context, ref) async {
            return result = await setupService.performOpenAiFtueSetup(
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

    testWidgets('should create models when they do not exist', (
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
        ),
      ).thenAnswer(
        (_) async => CategoryDefinition(
          id: 'test-category-id',
          name: 'Test Category OpenAI Enabled',
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

      OpenAiFtueResult? result;
      await tester.pumpWidget(
        createOpenAiFtueTestWidget(
          onPressed: (context, ref) async {
            return result = await setupService.performOpenAiFtueSetup(
              context: context,
              ref: ref,
              provider: openAiProvider,
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

      // 4 models saved
      verify(() => mockRepository.saveConfig(any())).called(4);
    });

    testWidgets('should verify existing models and skip creation', (
      WidgetTester tester,
    ) async {
      final existingModels = [
        AiTestDataFactory.createTestModel(
          id: 'existing-flash',
          name: 'o4-mini',
          providerModelId: ftueOpenAiFlashModelId,
          inferenceProviderId: openAiProvider.id,
        ),
        AiTestDataFactory.createTestModel(
          id: 'existing-reasoning',
          name: 'o3',
          providerModelId: ftueOpenAiReasoningModelId,
          inferenceProviderId: openAiProvider.id,
        ),
        AiTestDataFactory.createTestModel(
          id: 'existing-audio',
          name: 'GPT-4o Audio',
          providerModelId: ftueOpenAiAudioModelId,
          inferenceProviderId: openAiProvider.id,
        ),
        AiTestDataFactory.createTestModel(
          id: 'existing-image',
          name: 'GPT Image 1',
          providerModelId: ftueOpenAiImageModelId,
          inferenceProviderId: openAiProvider.id,
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
        ),
      ).thenAnswer(
        (_) async => CategoryDefinition(
          id: 'test-category-id',
          name: 'Test Category OpenAI Enabled',
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

      OpenAiFtueResult? result;
      await tester.pumpWidget(
        createOpenAiFtueTestWidget(
          onPressed: (context, ref) async {
            return result = await setupService.performOpenAiFtueSetup(
              context: context,
              ref: ref,
              provider: openAiProvider,
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
        name: 'Test Category OpenAI Enabled',
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
        private: false,
        active: true,
      );
      when(
        () => mockCategoryRepository.getAllCategories(),
      ).thenAnswer((_) async => [existingCategory]);

      OpenAiFtueResult? result;
      await tester.pumpWidget(
        createOpenAiFtueTestWidget(
          onPressed: (context, ref) async {
            return result = await setupService.performOpenAiFtueSetup(
              context: context,
              ref: ref,
              provider: openAiProvider,
            );
          },
        ),
      );

      await tester.tap(find.text('Test'));
      await tester.pump();

      expect(result, isNotNull);
      expect(result!.categoryCreated, isFalse);
      expect(result!.categoryReused, isTrue);
      expect(result!.categoryName, equals('Test Category OpenAI Enabled'));

      verifyNever(() => mockCategoryRepository.updateCategory(any()));
      verifyNever(
        () => mockCategoryRepository.createCategory(
          name: any(named: 'name'),
          color: any(named: 'color'),
          defaultProfileId: any(named: 'defaultProfileId'),
        ),
      );
    });
  });

  group('MistralFtueResult', () {
    test(
      'totalModels should return sum of modelsCreated and modelsVerified',
      () {
        const result = MistralFtueResult(
          modelsCreated: 2,
          modelsVerified: 1,
          categoryCreated: true,
        );

        expect(result.totalModels, equals(3));
      },
    );

    test('should handle zero values correctly', () {
      const result = MistralFtueResult(
        modelsCreated: 0,
        modelsVerified: 0,
        categoryCreated: false,
      );

      expect(result.totalModels, equals(0));
    });

    test('should include optional categoryReused and categoryName', () {
      const result = MistralFtueResult(
        modelsCreated: 3,
        modelsVerified: 0,
        categoryCreated: false,
        categoryReused: true,
        categoryName: 'Test Category Mistral',
      );

      expect(result.categoryReused, isTrue);
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

    setUpAll(() {
      registerFallbackValue(
        AiConfig.model(
          id: 'fallback-model',
          name: 'Fallback',
          providerModelId: 'fallback',
          inferenceProviderId: 'fallback',
          createdAt: DateTime(2024, 3, 15),
          inputModalities: [Modality.text],
          outputModalities: [Modality.text],
          isReasoningModel: false,
        ),
      );
      registerFallbackValue(
        CategoryDefinition(
          id: 'fallback-category',
          name: 'Fallback',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
          private: false,
          active: true,
        ),
      );
    });

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
    });

    Widget createMistralFtueTestWidget({
      required Future<MistralFtueResult?> Function(BuildContext, WidgetRef)
      onPressed,
    }) {
      return ProviderScope(
        overrides: [
          aiConfigRepositoryProvider.overrideWithValue(mockRepository),
          categoryRepositoryProvider.overrideWithValue(mockCategoryRepository),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                return ElevatedButton(
                  onPressed: () async {
                    await onPressed(context, ref);
                  },
                  child: const Text('Test'),
                );
              },
            ),
          ),
        ),
      );
    }

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
        createMistralFtueTestWidget(
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
        createMistralFtueTestWidget(
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
      expect(result!.modelsCreated, equals(3));
      expect(result!.modelsVerified, equals(0));
      expect(result!.categoryCreated, isTrue);

      // 3 models saved
      verify(() => mockRepository.saveConfig(any())).called(3);
    });

    testWidgets('should verify existing models and skip creation', (
      WidgetTester tester,
    ) async {
      final existingModels = [
        AiTestDataFactory.createTestModel(
          id: 'existing-flash',
          name: 'Mistral Small',
          providerModelId: ftueMistralFlashModelId,
          inferenceProviderId: mistralProvider.id,
        ),
        AiTestDataFactory.createTestModel(
          id: 'existing-reasoning',
          name: 'Magistral Medium',
          providerModelId: ftueMistralReasoningModelId,
          inferenceProviderId: mistralProvider.id,
        ),
        AiTestDataFactory.createTestModel(
          id: 'existing-audio',
          name: 'Voxtral Small',
          providerModelId: ftueMistralAudioModelId,
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
        createMistralFtueTestWidget(
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
      expect(result!.modelsVerified, equals(3));
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
        createMistralFtueTestWidget(
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
      expect(result!.categoryReused, isTrue);
      expect(result!.categoryName, equals('Test Category Mistral Enabled'));

      verifyNever(() => mockCategoryRepository.updateCategory(any()));
      verifyNever(
        () => mockCategoryRepository.createCategory(
          name: any(named: 'name'),
          color: any(named: 'color'),
          defaultProfileId: any(named: 'defaultProfileId'),
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
        createMistralFtueTestWidget(
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
        ),
      ).called(1);
    });
  });

  group('AlibabaFtueResult', () {
    test(
      'totalModels should return sum of modelsCreated and modelsVerified',
      () {
        const result = AlibabaFtueResult(
          modelsCreated: 3,
          modelsVerified: 2,
          categoryCreated: true,
        );

        expect(result.totalModels, equals(5));
      },
    );

    test('should handle zero values correctly', () {
      const result = AlibabaFtueResult(
        modelsCreated: 0,
        modelsVerified: 0,
        categoryCreated: false,
      );

      expect(result.totalModels, equals(0));
    });

    test('should include optional categoryReused and categoryName', () {
      const result = AlibabaFtueResult(
        modelsCreated: 5,
        modelsVerified: 0,
        categoryCreated: false,
        categoryReused: true,
        categoryName: 'Test Category Alibaba',
      );

      expect(result.categoryReused, isTrue);
      expect(result.categoryName, equals('Test Category Alibaba'));
    });

    test('should handle errors list', () {
      const result = AlibabaFtueResult(
        modelsCreated: 0,
        modelsVerified: 0,
        categoryCreated: false,
        errors: ['Alibaba Error 1', 'Alibaba Error 2'],
      );

      expect(result.errors, hasLength(2));
      expect(result.errors, contains('Alibaba Error 1'));
      expect(result.errors, contains('Alibaba Error 2'));
    });
  });

  group('Alibaba FTUE Setup - performAlibabaFtueSetup', () {
    late ProviderPromptSetupService setupService;
    late MockAiConfigRepository mockRepository;
    late MockCategoryRepository mockCategoryRepository;
    late AiConfigInferenceProvider alibabaProvider;

    setUpAll(() {
      registerFallbackValue(
        AiConfig.model(
          id: 'fallback-model',
          name: 'Fallback',
          providerModelId: 'fallback',
          inferenceProviderId: 'fallback',
          createdAt: DateTime(2024, 3, 15),
          inputModalities: [Modality.text],
          outputModalities: [Modality.text],
          isReasoningModel: false,
        ),
      );
      registerFallbackValue(
        CategoryDefinition(
          id: 'fallback-category',
          name: 'Fallback',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
          private: false,
          active: true,
        ),
      );
    });

    setUp(() {
      setupService = const ProviderPromptSetupService();
      mockRepository = MockAiConfigRepository();
      mockCategoryRepository = MockCategoryRepository();

      alibabaProvider = AiTestDataFactory.createTestProvider(
        id: 'alibaba-provider-id',
        name: 'Alibaba Cloud (Qwen)',
        type: InferenceProviderType.alibaba,
        apiKey: 'test-alibaba-key',
        baseUrl: 'https://dashscope-intl.aliyuncs.com/compatible-mode/v1',
      );
    });

    Widget createAlibabaFtueTestWidget({
      required Future<AlibabaFtueResult?> Function(BuildContext, WidgetRef)
      onPressed,
    }) {
      return ProviderScope(
        overrides: [
          aiConfigRepositoryProvider.overrideWithValue(mockRepository),
          categoryRepositoryProvider.overrideWithValue(mockCategoryRepository),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                return ElevatedButton(
                  onPressed: () async {
                    await onPressed(context, ref);
                  },
                  child: const Text('Test'),
                );
              },
            ),
          ),
        ),
      );
    }

    testWidgets('should return null for non-Alibaba provider', (
      WidgetTester tester,
    ) async {
      final geminiProvider = AiTestDataFactory.createTestProvider(
        id: 'gemini-id',
        name: 'Gemini',
        type: InferenceProviderType.gemini,
      );

      AlibabaFtueResult? result;
      await tester.pumpWidget(
        createAlibabaFtueTestWidget(
          onPressed: (context, ref) async {
            return result = await setupService.performAlibabaFtueSetup(
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

    testWidgets('should create 5 models when none exist', (
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
        ),
      ).thenAnswer(
        (_) async => CategoryDefinition(
          id: 'test-category-id',
          name: ftueAlibabaCategoryName,
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

      AlibabaFtueResult? result;
      await tester.pumpWidget(
        createAlibabaFtueTestWidget(
          onPressed: (context, ref) async {
            return result = await setupService.performAlibabaFtueSetup(
              context: context,
              ref: ref,
              provider: alibabaProvider,
            );
          },
        ),
      );

      await tester.tap(find.text('Test'));
      await tester.pump();

      expect(result, isNotNull);
      expect(result!.modelsCreated, equals(5));
      expect(result!.modelsVerified, equals(0));
      expect(result!.categoryCreated, isTrue);

      // 5 models saved
      verify(() => mockRepository.saveConfig(any())).called(5);
    });

    testWidgets('should verify existing models and skip creation', (
      WidgetTester tester,
    ) async {
      final existingModels = [
        AiTestDataFactory.createTestModel(
          id: 'existing-flash',
          name: 'Qwen Flash',
          providerModelId: ftueAlibabaFlashModelId,
          inferenceProviderId: alibabaProvider.id,
        ),
        AiTestDataFactory.createTestModel(
          id: 'existing-reasoning',
          name: 'Qwen3.5 Plus',
          providerModelId: ftueAlibabaReasoningModelId,
          inferenceProviderId: alibabaProvider.id,
        ),
        AiTestDataFactory.createTestModel(
          id: 'existing-audio',
          name: 'Qwen3 Omni Flash',
          providerModelId: ftueAlibabaAudioModelId,
          inferenceProviderId: alibabaProvider.id,
        ),
        AiTestDataFactory.createTestModel(
          id: 'existing-vision',
          name: 'Qwen3 VL Flash',
          providerModelId: ftueAlibabaVisionModelId,
          inferenceProviderId: alibabaProvider.id,
        ),
        AiTestDataFactory.createTestModel(
          id: 'existing-image',
          name: 'Wan 2.6 Image',
          providerModelId: ftueAlibabaImageModelId,
          inferenceProviderId: alibabaProvider.id,
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
        ),
      ).thenAnswer(
        (_) async => CategoryDefinition(
          id: 'test-category-id',
          name: ftueAlibabaCategoryName,
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

      AlibabaFtueResult? result;
      await tester.pumpWidget(
        createAlibabaFtueTestWidget(
          onPressed: (context, ref) async {
            return result = await setupService.performAlibabaFtueSetup(
              context: context,
              ref: ref,
              provider: alibabaProvider,
            );
          },
        ),
      );

      await tester.tap(find.text('Test'));
      await tester.pump();

      expect(result, isNotNull);
      expect(result!.modelsCreated, equals(0));
      expect(result!.modelsVerified, equals(5));
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
        name: ftueAlibabaCategoryName,
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
        private: false,
        active: true,
      );
      when(
        () => mockCategoryRepository.getAllCategories(),
      ).thenAnswer((_) async => [existingCategory]);

      AlibabaFtueResult? result;
      await tester.pumpWidget(
        createAlibabaFtueTestWidget(
          onPressed: (context, ref) async {
            return result = await setupService.performAlibabaFtueSetup(
              context: context,
              ref: ref,
              provider: alibabaProvider,
            );
          },
        ),
      );

      await tester.tap(find.text('Test'));
      await tester.pump();

      expect(result, isNotNull);
      expect(result!.categoryCreated, isFalse);
      expect(result!.categoryReused, isTrue);
      expect(result!.categoryName, equals(ftueAlibabaCategoryName));

      verifyNever(() => mockCategoryRepository.updateCategory(any()));
      verifyNever(
        () => mockCategoryRepository.createCategory(
          name: any(named: 'name'),
          color: any(named: 'color'),
          defaultProfileId: any(named: 'defaultProfileId'),
        ),
      );
    });

    testWidgets('should create category with Alibaba orange color', (
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
        ),
      ).thenAnswer(
        (_) async => CategoryDefinition(
          id: 'test-category-id',
          name: ftueAlibabaCategoryName,
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
        createAlibabaFtueTestWidget(
          onPressed: (context, ref) async {
            return setupService.performAlibabaFtueSetup(
              context: context,
              ref: ref,
              provider: alibabaProvider,
            );
          },
        ),
      );

      await tester.tap(find.text('Test'));
      await tester.pump();

      verify(
        () => mockCategoryRepository.createCategory(
          name: ftueAlibabaCategoryName,
          color: '#FF6D00', // Alibaba Orange
          defaultProfileId: profileAlibabaId,
        ),
      ).called(1);
    });
  });
}
