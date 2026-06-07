import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
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

  /// Regression coverage for the FTUE category bindings. The "Test
  /// Category Gemini Enabled" sample category must land in the database
  /// with BOTH the default inference profile and the default agent
  /// template bound — without those, tasks created in the category
  /// can't auto-route to the seeded profile or auto-spawn the Laura
  /// task agent, which is the whole point of the FTUE flow.
  group('Gemini FTUE Setup - performGeminiFtueSetup', () {
    late ProviderPromptSetupService setupService;
    late MockAiConfigRepository mockRepository;
    late MockCategoryRepository mockCategoryRepository;
    late AiConfigInferenceProvider geminiProvider;

    setUp(() {
      setupService = const ProviderPromptSetupService();
      mockRepository = MockAiConfigRepository();
      mockCategoryRepository = MockCategoryRepository();

      geminiProvider = AiTestDataFactory.createTestProvider(
        id: 'gemini-provider-id',
        name: 'Gemini',
        type: InferenceProviderType.gemini,
        apiKey: 'test-gemini-key',
        baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
      );
      when(
        () => mockRepository.getConfigsByType(AiConfigType.inferenceProvider),
      ).thenAnswer((_) async => [geminiProvider]);
    });

    testWidgets(
      'creates the sample category bound to the seeded Gemini Flash '
      'profile AND the Laura task agent template — both bindings are '
      'what make new tasks in the category route to AI handlers and '
      'auto-spawn an agent without any extra setup',
      (tester) async {
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
            name: ftueGeminiCategoryName,
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
            private: false,
            active: true,
          ),
        );

        await tester.pumpWidget(
          buildFtueHarness(
            repository: mockRepository,
            categoryRepository: mockCategoryRepository,
            onPressed: (context, ref) async {
              return setupService.performGeminiFtueSetup(
                context: context,
                ref: ref,
                provider: geminiProvider,
              );
            },
          ),
        );

        await tester.tap(find.text('Test'));
        await tester.pump();

        verify(
          () => mockCategoryRepository.createCategory(
            name: ftueGeminiCategoryName,
            color: ftueGeminiCategoryColor,
            defaultProfileId: profileGeminiFlashId,
            defaultTemplateId: lauraTemplateId,
          ),
        ).called(1);
      },
    );

    testWidgets(
      'verifies globally existing Gemini providerModelIds instead of '
      'seeding duplicate rows under a second provider',
      (tester) async {
        final existingModels = [
          AiTestDataFactory.createTestModel(
            id: 'other-gemini-flash',
            name: 'Gemini Flash',
            providerModelId: ftueFlashModelId,
            inferenceProviderId: 'other-gemini-provider',
          ),
          AiTestDataFactory.createTestModel(
            id: 'other-gemini-pro',
            name: 'Gemini Pro',
            providerModelId: ftueProModelId,
            inferenceProviderId: 'other-gemini-provider',
          ),
          AiTestDataFactory.createTestModel(
            id: 'other-gemini-image',
            name: 'Gemini Image',
            providerModelId: ftueImageModelId,
            inferenceProviderId: 'other-gemini-provider',
          ),
        ];
        final otherGeminiProvider = AiTestDataFactory.createTestProvider(
          id: 'other-gemini-provider',
          name: 'Other Gemini',
          type: InferenceProviderType.gemini,
          apiKey: 'other-gemini-key',
          baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
        );

        when(
          () => mockRepository.getConfigsByType(AiConfigType.model),
        ).thenAnswer((_) async => existingModels);
        when(
          () => mockRepository.getConfigsByType(AiConfigType.inferenceProvider),
        ).thenAnswer((_) async => [geminiProvider, otherGeminiProvider]);
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
            name: ftueGeminiCategoryName,
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
            private: false,
            active: true,
          ),
        );

        GeminiFtueResult? result;
        await tester.pumpWidget(
          buildFtueHarness(
            repository: mockRepository,
            categoryRepository: mockCategoryRepository,
            onPressed: (context, ref) async {
              return result = await setupService.performGeminiFtueSetup(
                context: context,
                ref: ref,
                provider: geminiProvider,
              );
            },
          ),
        );

        await tester.tap(find.text('Test'));
        await tester.pump();

        expect(result, isNotNull);
        expect(result!.modelsCreated, equals(0));
        expect(result!.modelsVerified, equals(3));
        verifyNever(() => mockRepository.saveConfig(any()));
      },
    );

    testWidgets(
      'creates fresh Gemini rows when matching providerModelIds only point at '
      'deleted providers',
      (tester) async {
        final orphanedModels = [
          AiTestDataFactory.createTestModel(
            id: 'orphaned-gemini-flash',
            name: 'Gemini Flash',
            providerModelId: ftueFlashModelId,
            inferenceProviderId: 'deleted-gemini-provider',
          ),
          AiTestDataFactory.createTestModel(
            id: 'orphaned-gemini-pro',
            name: 'Gemini Pro',
            providerModelId: ftueProModelId,
            inferenceProviderId: 'deleted-gemini-provider',
          ),
          AiTestDataFactory.createTestModel(
            id: 'orphaned-gemini-image',
            name: 'Gemini Image',
            providerModelId: ftueImageModelId,
            inferenceProviderId: 'deleted-gemini-provider',
          ),
        ];

        when(
          () => mockRepository.getConfigsByType(AiConfigType.model),
        ).thenAnswer((_) async => orphanedModels);
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
            name: ftueGeminiCategoryName,
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
            private: false,
            active: true,
          ),
        );

        GeminiFtueResult? result;
        await tester.pumpWidget(
          buildFtueHarness(
            repository: mockRepository,
            categoryRepository: mockCategoryRepository,
            onPressed: (context, ref) async {
              return result = await setupService.performGeminiFtueSetup(
                context: context,
                ref: ref,
                provider: geminiProvider,
              );
            },
          ),
        );

        await tester.tap(find.text('Test'));
        await tester.pump();

        expect(result, isNotNull);
        expect(result!.modelsCreated, equals(3));
        expect(result!.modelsVerified, equals(0));
        verify(
          () => mockRepository.saveConfig(
            any(
              that: isA<AiConfigModel>().having(
                (model) => model.inferenceProviderId,
                'inferenceProviderId',
                geminiProvider.id,
              ),
            ),
          ),
        ).called(3);
      },
    );
  });
}
