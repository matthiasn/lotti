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

  group('MeliousFtueResult', () {
    test('totalModels returns sum of created and verified rows', () {
      const result = MeliousFtueResult(
        modelsCreated: 3,
        modelsVerified: 1,
        categoryCreated: true,
      );

      expect(result.totalModels, 4);
    });
  });

  group('Melious FTUE Setup - performMeliousFtueSetup', () {
    late ProviderPromptSetupService setupService;
    late MockAiConfigRepository mockRepository;
    late MockCategoryRepository mockCategoryRepository;
    late AiConfigInferenceProvider meliousProvider;

    setUp(() {
      setupService = const ProviderPromptSetupService();
      mockRepository = MockAiConfigRepository();
      mockCategoryRepository = MockCategoryRepository();

      meliousProvider = AiTestDataFactory.createTestProvider(
        id: 'melious-provider-id',
        name: 'Melious.ai',
        type: InferenceProviderType.melious,
        apiKey: 'sk-mel-test',
        baseUrl: 'https://api.melious.ai/v1',
      );
      when(
        () => mockRepository.getConfigsByType(AiConfigType.inferenceProvider),
      ).thenAnswer((_) async => [meliousProvider]);
    });

    testWidgets('returns null for non-Melious provider', (tester) async {
      final openAiProvider = AiTestDataFactory.createTestProvider(
        id: 'openai-provider-id',
        name: 'OpenAI',
        type: InferenceProviderType.openAi,
      );

      MeliousFtueResult? result;
      await tester.pumpWidget(
        buildFtueHarness(
          repository: mockRepository,
          categoryRepository: mockCategoryRepository,
          onPressed: (context, ref) async {
            return result = await setupService.performMeliousFtueSetup(
              context: context,
              ref: ref,
              provider: openAiProvider,
            );
          },
        ),
      );

      await tester.tap(find.text('Test'));
      await tester.pump();

      expect(result, isNull);
    });

    testWidgets('creates default thinking and Whisper models', (tester) async {
      final saved = <AiConfig>[];
      when(
        () => mockRepository.getConfigsByType(AiConfigType.model),
      ).thenAnswer((_) async => <AiConfig>[]);
      when(() => mockRepository.saveConfig(any())).thenAnswer((invocation) {
        saved.add(invocation.positionalArguments.first as AiConfig);
        return Future<void>.value();
      });
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
          id: 'melious-category-id',
          name: ftueMeliousCategoryName,
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
          private: false,
          active: true,
          defaultProfileId: profileMeliousId,
        ),
      );

      MeliousFtueResult? result;
      await tester.pumpWidget(
        buildFtueHarness(
          repository: mockRepository,
          categoryRepository: mockCategoryRepository,
          onPressed: (context, ref) async {
            return result = await setupService.performMeliousFtueSetup(
              context: context,
              ref: ref,
              provider: meliousProvider,
            );
          },
        ),
      );

      await tester.tap(find.text('Test'));
      await tester.pump();

      expect(result, isNotNull);
      expect(result!.modelsCreated, 4);
      expect(result!.modelsVerified, 0);
      expect(result!.categoryCreated, isTrue);
      expect(
        saved.whereType<AiConfigModel>().map((model) => model.providerModelId),
        containsAll([
          meliousMistralSmall4119BInstructModelId,
          meliousDeepseekV4ProModelId,
          meliousWhisperLargeV3ModelId,
          meliousWhisperLargeV3TurboModelId,
        ]),
      );
      verify(
        () => mockCategoryRepository.createCategory(
          name: ftueMeliousCategoryName,
          color: ftueMeliousCategoryColor,
          defaultProfileId: profileMeliousId,
        ),
      ).called(1);
    });

    testWidgets('verifies existing Melious defaults without duplicating', (
      tester,
    ) async {
      final existingModels = [
        AiTestDataFactory.createTestModel(
          id: 'thinking',
          name: 'Mistral Small 4 119B Instruct',
          providerModelId: meliousMistralSmall4119BInstructModelId,
          inferenceProviderId: meliousProvider.id,
        ),
        AiTestDataFactory.createTestModel(
          id: 'advanced',
          name: 'DeepSeek V4 Pro',
          providerModelId: meliousDeepseekV4ProModelId,
          inferenceProviderId: meliousProvider.id,
        ),
        AiTestDataFactory.createTestModel(
          id: 'whisper',
          name: 'Whisper Large v3',
          providerModelId: meliousWhisperLargeV3ModelId,
          inferenceProviderId: meliousProvider.id,
        ),
        AiTestDataFactory.createTestModel(
          id: 'whisper-turbo',
          name: 'Whisper Large v3 Turbo',
          providerModelId: meliousWhisperLargeV3TurboModelId,
          inferenceProviderId: meliousProvider.id,
        ),
      ];
      when(
        () => mockRepository.getConfigsByType(AiConfigType.model),
      ).thenAnswer((_) async => existingModels);
      when(() => mockRepository.saveConfig(any())).thenAnswer((_) async {});
      when(
        () => mockCategoryRepository.getAllCategories(),
      ).thenAnswer(
        (_) async => [
          CategoryDefinition(
            id: 'existing-category-id',
            name: ftueMeliousCategoryName,
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
            private: false,
            active: true,
            defaultProfileId: profileMeliousId,
          ),
        ],
      );

      MeliousFtueResult? result;
      await tester.pumpWidget(
        buildFtueHarness(
          repository: mockRepository,
          categoryRepository: mockCategoryRepository,
          onPressed: (context, ref) async {
            return result = await setupService.performMeliousFtueSetup(
              context: context,
              ref: ref,
              provider: meliousProvider,
            );
          },
        ),
      );

      await tester.tap(find.text('Test'));
      await tester.pump();

      expect(result, isNotNull);
      expect(result!.modelsCreated, 0);
      expect(result!.modelsVerified, 4);
      expect(result!.categoryCreated, isFalse);
      expect(result!.categoryReused, isTrue);
      verifyNever(() => mockRepository.saveConfig(any()));
    });
  });
}
