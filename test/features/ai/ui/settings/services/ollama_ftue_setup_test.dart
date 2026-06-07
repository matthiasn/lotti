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

  group('OllamaFtueResult', () {
    test('modelsCreated/Verified are always zero in PR-1', () {
      const result = OllamaFtueResult(categoryCreated: true);
      expect(result.modelsCreated, equals(0));
      expect(result.modelsVerified, equals(0));
      expect(result.totalModels, equals(0));
    });

    test('carries category metadata and errors through', () {
      const result = OllamaFtueResult(
        categoryCreated: false,
        categoryReused: true,
        categoryName: ftueOllamaCategoryName,
        errors: ['could not reach localhost:11434'],
      );
      expect(result.categoryReused, isTrue);
      expect(result.categoryName, equals(ftueOllamaCategoryName));
      expect(result.errors, isNotEmpty);
    });
  });

  group('Ollama FTUE Setup - performOllamaFtueSetup', () {
    late ProviderPromptSetupService setupService;
    late MockAiConfigRepository mockRepository;
    late MockCategoryRepository mockCategoryRepository;
    late AiConfigInferenceProvider ollamaProvider;

    setUp(() {
      setupService = const ProviderPromptSetupService();
      mockRepository = MockAiConfigRepository();
      mockCategoryRepository = MockCategoryRepository();

      ollamaProvider = AiTestDataFactory.createTestProvider(
        id: 'ollama-provider-id',
        name: 'Ollama',
        type: InferenceProviderType.ollama,
        apiKey: '',
        baseUrl: 'http://localhost:11434',
      );
    });

    testWidgets('returns null for non-Ollama provider', (tester) async {
      final geminiProvider = AiTestDataFactory.createTestProvider(
        id: 'gemini-id',
        name: 'Gemini',
        type: InferenceProviderType.gemini,
      );

      OllamaFtueResult? result;
      await tester.pumpWidget(
        buildFtueHarness(
          repository: mockRepository,
          categoryRepository: mockCategoryRepository,
          onPressed: (context, ref) async {
            return result = await setupService.performOllamaFtueSetup(
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

    testWidgets(
      'creates the Ollama test category bound to the local profile and '
      'touches no model repository — Ollama serves whatever the user has '
      'pulled locally, so PR-1 does not auto-create any model rows',
      (tester) async {
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
            id: 'cat-ollama',
            name: ftueOllamaCategoryName,
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
            private: false,
            active: true,
          ),
        );

        OllamaFtueResult? result;
        await tester.pumpWidget(
          buildFtueHarness(
            repository: mockRepository,
            categoryRepository: mockCategoryRepository,
            onPressed: (context, ref) async {
              return result = await setupService.performOllamaFtueSetup(
                context: context,
                ref: ref,
                provider: ollamaProvider,
              );
            },
          ),
        );

        await tester.tap(find.text('Test'));
        await tester.pump();

        expect(result, isNotNull);
        expect(result!.categoryCreated, isTrue);
        expect(result!.modelsCreated, equals(0));
        expect(result!.modelsVerified, equals(0));
        verifyNever(() => mockRepository.saveConfig(any()));
        verify(
          () => mockCategoryRepository.createCategory(
            name: ftueOllamaCategoryName,
            color: ftueOllamaCategoryColor,
            defaultProfileId: profileLocalId,
            // ignore: avoid_redundant_argument_values
            defaultTemplateId: null,
          ),
        ).called(1);
      },
    );

    testWidgets('reuses an existing Ollama category instead of recreating it', (
      tester,
    ) async {
      when(
        () => mockCategoryRepository.getAllCategories(),
      ).thenAnswer(
        (_) async => [
          CategoryDefinition(
            id: 'cat-ollama',
            name: ftueOllamaCategoryName,
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
            private: false,
            active: true,
          ),
        ],
      );

      OllamaFtueResult? result;
      await tester.pumpWidget(
        buildFtueHarness(
          repository: mockRepository,
          categoryRepository: mockCategoryRepository,
          onPressed: (context, ref) async {
            return result = await setupService.performOllamaFtueSetup(
              context: context,
              ref: ref,
              provider: ollamaProvider,
            );
          },
        ),
      );

      await tester.tap(find.text('Test'));
      await tester.pump();

      expect(result!.categoryCreated, isFalse);
      expect(result!.categoryReused, isTrue);
      verifyNever(
        () => mockCategoryRepository.createCategory(
          name: any(named: 'name'),
          color: any(named: 'color'),
          defaultProfileId: any(named: 'defaultProfileId'),
          defaultTemplateId: any(named: 'defaultTemplateId'),
        ),
      );
    });
  });
}
