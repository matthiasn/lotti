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

  group('AnthropicFtueResult', () {
    test('totalModels sums modelsCreated and modelsVerified', () {
      const result = AnthropicFtueResult(
        modelsCreated: 1,
        modelsVerified: 1,
        categoryCreated: true,
      );
      expect(result.totalModels, equals(2));
    });

    test('zero values yield zero totalModels', () {
      const result = AnthropicFtueResult(
        modelsCreated: 0,
        modelsVerified: 0,
        categoryCreated: false,
      );
      expect(result.totalModels, equals(0));
    });

    test('optional categoryReused / categoryName / errors carry through', () {
      const result = AnthropicFtueResult(
        modelsCreated: 0,
        modelsVerified: 2,
        categoryCreated: false,
        categoryReused: true,
        categoryName: 'Test Category Anthropic Enabled',
        errors: ['boom'],
      );
      expect(result.categoryReused, isTrue);
      expect(result.categoryName, equals('Test Category Anthropic Enabled'));
      expect(result.errors, equals(['boom']));
    });
  });

  group('Anthropic FTUE Setup - performAnthropicFtueSetup', () {
    late ProviderPromptSetupService setupService;
    late MockAiConfigRepository mockRepository;
    late MockCategoryRepository mockCategoryRepository;
    late AiConfigInferenceProvider anthropicProvider;

    setUp(() {
      setupService = const ProviderPromptSetupService();
      mockRepository = MockAiConfigRepository();
      mockCategoryRepository = MockCategoryRepository();

      anthropicProvider = AiTestDataFactory.createTestProvider(
        id: 'anthropic-provider-id',
        name: 'Anthropic',
        // ignore: avoid_redundant_argument_values
        type: InferenceProviderType.anthropic,
        apiKey: 'sk-ant-test-key',
        baseUrl: 'https://api.anthropic.com',
      );
      when(
        () => mockRepository.getConfigsByType(AiConfigType.inferenceProvider),
      ).thenAnswer((_) async => [anthropicProvider]);
    });

    testWidgets('returns null for non-Anthropic provider', (tester) async {
      final geminiProvider = AiTestDataFactory.createTestProvider(
        id: 'gemini-id',
        name: 'Gemini',
        type: InferenceProviderType.gemini,
      );

      AnthropicFtueResult? result;
      await tester.pumpWidget(
        buildFtueHarness(
          repository: mockRepository,
          categoryRepository: mockCategoryRepository,
          onPressed: (context, ref) async {
            return result = await setupService.performAnthropicFtueSetup(
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

    testWidgets('creates 2 models when none exist and a fresh category', (
      tester,
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
          id: 'cat-anthropic',
          name: ftueAnthropicCategoryName,
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
          private: false,
          active: true,
        ),
      );

      AnthropicFtueResult? result;
      await tester.pumpWidget(
        buildFtueHarness(
          repository: mockRepository,
          categoryRepository: mockCategoryRepository,
          onPressed: (context, ref) async {
            return result = await setupService.performAnthropicFtueSetup(
              context: context,
              ref: ref,
              provider: anthropicProvider,
            );
          },
        ),
      );

      await tester.tap(find.text('Test'));
      await tester.pump();

      expect(result, isNotNull);
      expect(result!.modelsCreated, equals(2));
      expect(result!.modelsVerified, equals(0));
      expect(result!.categoryCreated, isTrue);
      verify(() => mockRepository.saveConfig(any())).called(2);
    });

    testWidgets(
      'verifies existing models instead of recreating them, reuses category',
      (tester) async {
        final existingModels = [
          AiTestDataFactory.createTestModel(
            id: 'existing-sonnet',
            name: 'Claude Sonnet 4',
            providerModelId: ftueAnthropicReasoningModelId,
            inferenceProviderId: anthropicProvider.id,
          ),
          AiTestDataFactory.createTestModel(
            id: 'existing-haiku',
            name: 'Claude Haiku 3.5',
            providerModelId: ftueAnthropicFlashModelId,
            inferenceProviderId: anthropicProvider.id,
          ),
        ];

        when(
          () => mockRepository.getConfigsByType(AiConfigType.model),
        ).thenAnswer((_) async => existingModels);
        when(
          () => mockCategoryRepository.getAllCategories(),
        ).thenAnswer(
          (_) async => [
            CategoryDefinition(
              id: 'cat-anthropic',
              name: ftueAnthropicCategoryName,
              createdAt: DateTime(2024, 3, 15),
              updatedAt: DateTime(2024, 3, 15),
              vectorClock: null,
              private: false,
              active: true,
            ),
          ],
        );

        AnthropicFtueResult? result;
        await tester.pumpWidget(
          buildFtueHarness(
            repository: mockRepository,
            categoryRepository: mockCategoryRepository,
            onPressed: (context, ref) async {
              return result = await setupService.performAnthropicFtueSetup(
                context: context,
                ref: ref,
                provider: anthropicProvider,
              );
            },
          ),
        );

        await tester.tap(find.text('Test'));
        await tester.pump();

        expect(result!.modelsCreated, equals(0));
        expect(result!.modelsVerified, equals(2));
        expect(result!.categoryCreated, isFalse);
        expect(result!.categoryReused, isTrue);
        verifyNever(() => mockRepository.saveConfig(any()));
        verifyNever(
          () => mockCategoryRepository.createCategory(
            name: any(named: 'name'),
            color: any(named: 'color'),
            defaultProfileId: any(named: 'defaultProfileId'),
          ),
        );
      },
    );

    testWidgets(
      'category is created with the Anthropic FTUE name + color + profile',
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
          ),
        ).thenAnswer(
          (_) async => CategoryDefinition(
            id: 'cat-anthropic',
            name: ftueAnthropicCategoryName,
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
              return setupService.performAnthropicFtueSetup(
                context: context,
                ref: ref,
                provider: anthropicProvider,
              );
            },
          ),
        );

        await tester.tap(find.text('Test'));
        await tester.pump();

        verify(
          () => mockCategoryRepository.createCategory(
            name: ftueAnthropicCategoryName,
            color: ftueAnthropicCategoryColor,
            defaultProfileId: profileAnthropicId,
            // ignore: avoid_redundant_argument_values
            defaultTemplateId: null,
          ),
        ).called(1);
      },
    );
  });
}
