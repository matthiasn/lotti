import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/services/provider_prompt_setup_service.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/ai/util/profile_seeding_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/fallbacks.dart';
import '../../../../../mocks/mocks.dart';
import '../../../test_utils.dart';
import 'ftue_test_harness.dart';

void main() {
  setUpAll(registerAllFallbackValues);

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
      when(
        () => mockRepository.getConfigsByType(AiConfigType.inferenceProvider),
      ).thenAnswer((_) async => [alibabaProvider]);
    });

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
        buildFtueHarness(
          repository: mockRepository,
          categoryRepository: mockCategoryRepository,
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
          defaultTemplateId: any(named: 'defaultTemplateId'),
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
        buildFtueHarness(
          repository: mockRepository,
          categoryRepository: mockCategoryRepository,
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
          defaultTemplateId: any(named: 'defaultTemplateId'),
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
        buildFtueHarness(
          repository: mockRepository,
          categoryRepository: mockCategoryRepository,
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
        buildFtueHarness(
          repository: mockRepository,
          categoryRepository: mockCategoryRepository,
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
          defaultTemplateId: any(named: 'defaultTemplateId'),
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
          defaultTemplateId: any(named: 'defaultTemplateId'),
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
        buildFtueHarness(
          repository: mockRepository,
          categoryRepository: mockCategoryRepository,
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
          // ignore: avoid_redundant_argument_values
          defaultTemplateId: null,
        ),
      ).called(1);
    });
  });
}
