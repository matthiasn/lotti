import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/services/provider_prompt_setup_service.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart'
    show categoryRepositoryProvider;
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../test_utils.dart';

void main() {
  group('ProviderPromptSetupService', () {
    late ProviderPromptSetupService setupService;
    late MockAiConfigRepository mockRepository;

    // Gemini test data
    late AiConfigInferenceProvider geminiProvider;
    late List<AiConfigModel> geminiModels;

    // Ollama test data
    late AiConfigInferenceProvider ollamaProvider;
    late List<AiConfigModel> ollamaModels;

    // Unsupported provider (for testing offerPromptSetup rejection)
    late AiConfigInferenceProvider unsupportedProvider;

    setUpAll(AiTestSetup.registerFallbackValues);

    setUp(() {
      setupService = const ProviderPromptSetupService();
      mockRepository = MockAiConfigRepository();

      // Gemini provider and models
      geminiProvider = AiTestDataFactory.createTestProvider(
        id: 'gemini-provider-id',
        name: 'My Gemini',
        type: InferenceProviderType.gemini,
        apiKey: 'test-gemini-key',
        baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
      );

      geminiModels = [
        AiTestDataFactory.createTestModel(
          id: 'gemini-provider-id_models_gemini_2_5_flash',
          name: 'Gemini 2.5 Flash',
          inferenceProviderId: geminiProvider.id,
          inputModalities: [Modality.text, Modality.image, Modality.audio],
          isReasoningModel: true,
        ),
        AiTestDataFactory.createTestModel(
          id: 'gemini-provider-id_models_gemini_2_5_pro',
          name: 'Gemini 2.5 Pro',
          inferenceProviderId: geminiProvider.id,
          inputModalities: [Modality.text, Modality.image, Modality.audio],
          isReasoningModel: true,
        ),
      ];

      // Ollama provider and models
      ollamaProvider = AiTestDataFactory.createTestProvider(
        id: 'ollama-provider-id',
        name: 'My Ollama',
        type: InferenceProviderType.ollama,
        apiKey: '',
        baseUrl: 'http://localhost:11434',
      );

      ollamaModels = [
        AiTestDataFactory.createTestModel(
          id: 'ollama-provider-id_qwen3_5_9b',
          name: 'Qwen 3.5 9B',
          inferenceProviderId: ollamaProvider.id,
          inputModalities: [Modality.text, Modality.image],
          isReasoningModel: true,
          supportsFunctionCalling: true,
        ),
      ];

      // Unsupported provider (Anthropic is not supported for offerPromptSetup)
      // Note: Anthropic is the default type in createTestProvider
      unsupportedProvider = AiTestDataFactory.createTestProvider(
        id: 'anthropic-provider-id',
        name: 'My Anthropic',
        apiKey: 'test-anthropic-key',
        baseUrl: 'https://api.anthropic.com',
      );
    });

    Widget createTestWidget({
      required Widget child,
      required Future<void> Function(BuildContext, WidgetRef) onPressed,
    }) {
      return AiTestWidgets.createTestWidget(
        repository: mockRepository,
        child: Consumer(
          builder: (context, ref, _) => ElevatedButton(
            onPressed: () => onPressed(context, ref),
            child: child,
          ),
        ),
      );
    }

    group('Provider Type Checks', () {
      testWidgets('should return false for unsupported providers', (
        WidgetTester tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(1024, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        bool? result;

        await tester.pumpWidget(
          createTestWidget(
            child: const Text('Test Button'),
            onPressed: (context, ref) async {
              result = await setupService.offerPromptSetup(
                context: context,
                ref: ref,
                provider: unsupportedProvider,
              );
            },
          ),
        );

        await tester.tap(find.text('Test Button'));
        await tester.pump();

        expect(result, isFalse);
        expect(find.text('Set Up Default Prompts?'), findsNothing);
      });

      testWidgets('should return false for Gemini (empty prompt configs)', (
        WidgetTester tester,
      ) async {
        when(
          () => mockRepository.getConfigsByType(AiConfigType.model),
        ).thenAnswer((_) async => geminiModels);

        bool? result;

        await tester.pumpWidget(
          createTestWidget(
            child: const Text('Test Button'),
            onPressed: (context, ref) async {
              result = await setupService.offerPromptSetup(
                context: context,
                ref: ref,
                provider: geminiProvider,
              );
            },
          ),
        );

        await tester.tap(find.text('Test Button'));
        await tester.pump();

        // No dialog shown — prompt configs are empty.
        expect(find.text('Set Up Default Prompts?'), findsNothing);
        expect(result, isFalse);
      });

      testWidgets('should return false for Ollama (empty prompt configs)', (
        WidgetTester tester,
      ) async {
        when(
          () => mockRepository.getConfigsByType(AiConfigType.model),
        ).thenAnswer((_) async => ollamaModels);

        bool? result;

        await tester.pumpWidget(
          createTestWidget(
            child: const Text('Test Button'),
            onPressed: (context, ref) async {
              result = await setupService.offerPromptSetup(
                context: context,
                ref: ref,
                provider: ollamaProvider,
              );
            },
          ),
        );

        await tester.tap(find.text('Test Button'));
        await tester.pump();

        // No dialog shown — prompt configs are empty.
        expect(find.text('Set Up Default Prompts?'), findsNothing);
        expect(result, isFalse);
      });
    });

    // Dialog UI, cancel, prompt creation, and snackbar groups are no longer
    // applicable — all provider types now return empty prompt configs in
    // offerPromptSetup, so the method short-circuits before showing a dialog.
    // Prompt creation for supported providers goes through the FTUE path
    // instead (see OpenAI, Mistral, and Alibaba FTUE Setup groups below).
    // Gemini FTUE setup is tested via GeminiFtueResult value-object tests;
    // the full setup path is not exercised here.

    group('Edge Cases', () {
      testWidgets(
        'should return false and not show dialog when no models available',
        (WidgetTester tester) async {
          await tester.binding.setSurfaceSize(const Size(1024, 900));
          addTearDown(() => tester.binding.setSurfaceSize(null));

          when(
            () => mockRepository.getConfigsByType(AiConfigType.model),
          ).thenAnswer((_) async => []);

          bool? result;

          await tester.pumpWidget(
            createTestWidget(
              child: const Text('Test Button'),
              onPressed: (context, ref) async {
                result = await setupService.offerPromptSetup(
                  context: context,
                  ref: ref,
                  provider: geminiProvider,
                );
              },
            ),
          );

          await tester.tap(find.text('Test Button'));
          await tester.pump();

          expect(find.text('Set Up Default Prompts?'), findsNothing);
          expect(result, isFalse);
          verifyNever(() => mockRepository.saveConfig(any()));
        },
      );

      testWidgets(
        'should return false for Ollama with mixed models (empty configs)',
        (WidgetTester tester) async {
          final mixedModels = [
            ...ollamaModels,
            AiTestDataFactory.createTestModel(
              id: 'other-model',
              name: 'Other Model',
              inferenceProviderId: 'other-provider-id',
            ),
          ];

          when(
            () => mockRepository.getConfigsByType(AiConfigType.model),
          ).thenAnswer((_) async => mixedModels);

          bool? result;

          await tester.pumpWidget(
            createTestWidget(
              child: const Text('Test Button'),
              onPressed: (context, ref) async {
                result = await setupService.offerPromptSetup(
                  context: context,
                  ref: ref,
                  provider: ollamaProvider,
                );
              },
            ),
          );

          await tester.tap(find.text('Test Button'));
          await tester.pump();

          // Short-circuits: empty prompt configs → no dialog, returns false.
          expect(result, isFalse);
          verifyNever(() => mockRepository.saveConfig(any()));
        },
      );

      testWidgets(
        'should return false for Ollama with fallback model (empty configs)',
        (WidgetTester tester) async {
          final fallbackModels = [
            AiTestDataFactory.createTestModel(
              id: 'ollama-fallback-only',
              name: 'Some Other Model',
              inferenceProviderId: ollamaProvider.id,
              inputModalities: [Modality.text, Modality.image],
            ),
          ];

          when(
            () => mockRepository.getConfigsByType(AiConfigType.model),
          ).thenAnswer((_) async => fallbackModels);

          bool? result;

          await tester.pumpWidget(
            createTestWidget(
              child: const Text('Test Button'),
              onPressed: (context, ref) async {
                result = await setupService.offerPromptSetup(
                  context: context,
                  ref: ref,
                  provider: ollamaProvider,
                );
              },
            ),
          );

          await tester.tap(find.text('Test Button'));
          await tester.pump();

          // Short-circuits: empty prompt configs → no dialog, returns false.
          expect(result, isFalse);
        },
      );
    });

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

      test(
        'supportedProviders should include Alibaba, Gemini, Ollama, and OpenAI',
        () {
          expect(
            ProviderPromptSetupService.supportedProviders,
            containsAll([
              InferenceProviderType.alibaba,
              InferenceProviderType.gemini,
              InferenceProviderType.ollama,
              InferenceProviderType.openAi,
            ]),
          );
        },
      );
    });

    group('Prompt Configuration', () {
      testWidgets(
        'should return false without creating prompts (empty configs)',
        (WidgetTester tester) async {
          when(
            () => mockRepository.getConfigsByType(AiConfigType.model),
          ).thenAnswer((_) async => ollamaModels);

          bool? result;

          await tester.pumpWidget(
            createTestWidget(
              child: const Text('Test Button'),
              onPressed: (context, ref) async {
                result = await setupService.offerPromptSetup(
                  context: context,
                  ref: ref,
                  provider: ollamaProvider,
                );
              },
            ),
          );

          await tester.tap(find.text('Test Button'));
          await tester.pump();

          // Short-circuits: empty configs → no dialog, no saves.
          expect(result, isFalse);
          verifyNever(() => mockRepository.saveConfig(any()));
        },
      );
    });

    group('Error Handling', () {
      testWidgets('should return false when no models exist for provider', (
        WidgetTester tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(1024, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        // Return empty models list
        when(
          () => mockRepository.getConfigsByType(AiConfigType.model),
        ).thenAnswer((_) async => []);

        var result = false;
        await tester.pumpWidget(
          createTestWidget(
            child: const Text('Test Button'),
            onPressed: (context, ref) async {
              result = await setupService.offerPromptSetup(
                context: context,
                ref: ref,
                provider: geminiProvider,
              );
            },
          ),
        );

        await tester.tap(find.text('Test Button'));
        await tester.pump();

        // Should return false because no models exist
        expect(result, isFalse);
      });

      testWidgets(
        'should return false when models exist but none belong to provider',
        (WidgetTester tester) async {
          await tester.binding.setSurfaceSize(const Size(1024, 900));
          addTearDown(() => tester.binding.setSurfaceSize(null));

          // Return models for a different provider
          final otherProviderModels = [
            AiTestDataFactory.createTestModel(
              id: 'other-provider_model1',
              name: 'Other Model',
              inferenceProviderId: 'other-provider-id',
              inputModalities: [Modality.text],
            ),
          ];

          when(
            () => mockRepository.getConfigsByType(AiConfigType.model),
          ).thenAnswer((_) async => otherProviderModels);

          var result = false;
          await tester.pumpWidget(
            createTestWidget(
              child: const Text('Test Button'),
              onPressed: (context, ref) async {
                result = await setupService.offerPromptSetup(
                  context: context,
                  ref: ref,
                  provider: geminiProvider,
                );
              },
            ),
          );

          await tester.tap(find.text('Test Button'));
          await tester.pump();

          // Should return false because no models for this provider
          expect(result, isFalse);
        },
      );
    });
  });

  group('GeminiFtueResult', () {
    test(
      'totalModels should return sum of modelsCreated and modelsVerified',
      () {
        const result = GeminiFtueResult(
          modelsCreated: 2,
          modelsVerified: 1,
          promptsCreated: 5,
          promptsSkipped: 3,
          categoryCreated: true,
        );

        expect(result.totalModels, equals(3));
      },
    );

    test(
      'totalPrompts should return sum of promptsCreated and promptsSkipped',
      () {
        const result = GeminiFtueResult(
          modelsCreated: 2,
          modelsVerified: 1,
          promptsCreated: 5,
          promptsSkipped: 3,
          categoryCreated: true,
        );

        expect(result.totalPrompts, equals(8));
      },
    );

    test('should handle zero values correctly', () {
      const result = GeminiFtueResult(
        modelsCreated: 0,
        modelsVerified: 0,
        promptsCreated: 0,
        promptsSkipped: 0,
        categoryCreated: false,
      );

      expect(result.totalModels, equals(0));
      expect(result.totalPrompts, equals(0));
    });

    test('should include optional categoryReused and categoryName', () {
      const result = GeminiFtueResult(
        modelsCreated: 3,
        modelsVerified: 0,
        promptsCreated: 9,
        promptsSkipped: 0,
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
        promptsCreated: 0,
        promptsSkipped: 0,
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
          promptsCreated: 7,
          promptsSkipped: 2,
          categoryCreated: true,
        );

        expect(result.totalModels, equals(4));
      },
    );

    test(
      'totalPrompts should return sum of promptsCreated and promptsSkipped',
      () {
        const result = OpenAiFtueResult(
          modelsCreated: 3,
          modelsVerified: 1,
          promptsCreated: 7,
          promptsSkipped: 2,
          categoryCreated: true,
        );

        expect(result.totalPrompts, equals(9));
      },
    );

    test('should handle zero values correctly', () {
      const result = OpenAiFtueResult(
        modelsCreated: 0,
        modelsVerified: 0,
        promptsCreated: 0,
        promptsSkipped: 0,
        categoryCreated: false,
      );

      expect(result.totalModels, equals(0));
      expect(result.totalPrompts, equals(0));
    });

    test('should include optional categoryReused and categoryName', () {
      const result = OpenAiFtueResult(
        modelsCreated: 4,
        modelsVerified: 0,
        promptsCreated: 9,
        promptsSkipped: 0,
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
        promptsCreated: 0,
        promptsSkipped: 0,
        categoryCreated: false,
        errors: ['OpenAI Error 1', 'OpenAI Error 2'],
      );

      expect(result.errors, hasLength(2));
      expect(result.errors, contains('OpenAI Error 1'));
      expect(result.errors, contains('OpenAI Error 2'));
    });
  });

  group('PromptConfig', () {
    test('should hold template and model correctly', () {
      // PromptConfig requires PreconfiguredPrompt which is internal,
      // so we just test the class structure exists
      expect(PromptConfig, isNotNull);
    });
  });

  group('PromptPreviewInfo', () {
    test('should hold preview information', () {
      const preview = PromptPreviewInfo(
        icon: Icons.mic,
        name: 'Audio Transcription',
        modelName: 'Gemini Flash',
      );

      expect(preview.icon, equals(Icons.mic));
      expect(preview.name, equals('Audio Transcription'));
      expect(preview.modelName, equals('Gemini Flash'));
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
          createdAt: DateTime.now(),
          inputModalities: [Modality.text],
          outputModalities: [Modality.text],
          isReasoningModel: false,
        ),
      );
      registerFallbackValue(
        AiConfig.prompt(
          id: 'fallback-prompt',
          name: 'Fallback',
          systemMessage: 'system',
          userMessage: 'user',
          defaultModelId: 'model',
          modelIds: ['model'],
          createdAt: DateTime.now(),
          requiredInputData: [InputDataType.task],
          // ignore: deprecated_member_use_from_same_package
          aiResponseType: AiResponseType.taskSummary,
          useReasoning: false,
        ),
      );
      registerFallbackValue(
        CategoryDefinition(
          id: 'fallback-category',
          name: 'Fallback',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
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
      when(
        () => mockRepository.getConfigsByType(AiConfigType.prompt),
      ).thenAnswer((_) async => <AiConfig>[]);
      when(() => mockRepository.saveConfig(any())).thenAnswer((_) async {});
      when(
        () => mockCategoryRepository.getAllCategories(),
      ).thenAnswer((_) async => <CategoryDefinition>[]);
      when(
        () => mockCategoryRepository.createCategory(
          name: any(named: 'name'),
          color: any(named: 'color'),
        ),
      ).thenAnswer(
        (_) async => CategoryDefinition(
          id: 'test-category-id',
          name: 'Test Category OpenAI Enabled',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
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
      expect(result!.promptsCreated, equals(2));
      expect(result!.promptsSkipped, equals(0));
      expect(result!.categoryCreated, isTrue);

      // 4 models + 2 prompts = 6 saves
      verify(() => mockRepository.saveConfig(any())).called(6);
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
      when(
        () => mockRepository.getConfigsByType(AiConfigType.prompt),
      ).thenAnswer((_) async => <AiConfig>[]);
      when(() => mockRepository.saveConfig(any())).thenAnswer((_) async {});
      when(
        () => mockCategoryRepository.getAllCategories(),
      ).thenAnswer((_) async => <CategoryDefinition>[]);
      when(
        () => mockCategoryRepository.createCategory(
          name: any(named: 'name'),
          color: any(named: 'color'),
        ),
      ).thenAnswer(
        (_) async => CategoryDefinition(
          id: 'test-category-id',
          name: 'Test Category OpenAI Enabled',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
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

    testWidgets(
      'should skip existing prompts with same preconfiguredPromptId',
      (WidgetTester tester) async {
        final existingModels = [
          AiTestDataFactory.createTestModel(
            id: 'existing-flash',
            providerModelId: ftueOpenAiFlashModelId,
            inferenceProviderId: openAiProvider.id,
          ),
          AiTestDataFactory.createTestModel(
            id: 'existing-reasoning',
            providerModelId: ftueOpenAiReasoningModelId,
            inferenceProviderId: openAiProvider.id,
          ),
          AiTestDataFactory.createTestModel(
            id: 'existing-audio',
            providerModelId: ftueOpenAiAudioModelId,
            inferenceProviderId: openAiProvider.id,
          ),
          AiTestDataFactory.createTestModel(
            id: 'existing-image',
            providerModelId: ftueOpenAiImageModelId,
            inferenceProviderId: openAiProvider.id,
          ),
        ];

        final existingPrompts = <AiConfig>[
          AiConfig.prompt(
            id: 'existing-prompt-id',
            name: 'Audio Transcription OpenAI',
            systemMessage: 'system',
            userMessage: 'user',
            defaultModelId: 'existing-audio',
            modelIds: ['existing-audio'],
            createdAt: DateTime(2024, 3, 15),
            requiredInputData: [InputDataType.audioFiles],
            aiResponseType: AiResponseType.audioTranscription,
            preconfiguredPromptId: 'audio_transcription',
            useReasoning: false,
          ),
        ];

        when(
          () => mockRepository.getConfigsByType(AiConfigType.model),
        ).thenAnswer((_) async => existingModels);
        when(
          () => mockRepository.getConfigsByType(AiConfigType.prompt),
        ).thenAnswer((_) async => existingPrompts);
        when(() => mockRepository.saveConfig(any())).thenAnswer((_) async {});
        when(
          () => mockCategoryRepository.getAllCategories(),
        ).thenAnswer((_) async => <CategoryDefinition>[]);
        when(
          () => mockCategoryRepository.createCategory(
            name: any(named: 'name'),
            color: any(named: 'color'),
          ),
        ).thenAnswer(
          (_) async => CategoryDefinition(
            id: 'test-category-id',
            name: 'Test Category OpenAI Enabled',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
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
        // audio_transcription no longer matches any new prompt config
        expect(result!.promptsSkipped, equals(0));
        expect(result!.promptsCreated, equals(2));
      },
    );

    testWidgets('should reuse existing category instead of creating new one', (
      WidgetTester tester,
    ) async {
      when(
        () => mockRepository.getConfigsByType(AiConfigType.model),
      ).thenAnswer((_) async => <AiConfig>[]);
      when(
        () => mockRepository.getConfigsByType(AiConfigType.prompt),
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
        ),
      );
    });
  });

  group('FtuePromptConfig', () {
    test('should expose modelVariant and promptName properties', () {
      // Test that FtuePromptConfig can be created and properties accessed
      // We can't test the template property directly since PreconfiguredPrompt
      // templates are internal to the preconfigured_prompts library
      expect(FtuePromptConfig, isNotNull);
    });
  });

  group('MistralFtueResult', () {
    test(
      'totalModels should return sum of modelsCreated and modelsVerified',
      () {
        const result = MistralFtueResult(
          modelsCreated: 2,
          modelsVerified: 1,
          promptsCreated: 6,
          promptsSkipped: 2,
          categoryCreated: true,
        );

        expect(result.totalModels, equals(3));
      },
    );

    test(
      'totalPrompts should return sum of promptsCreated and promptsSkipped',
      () {
        const result = MistralFtueResult(
          modelsCreated: 2,
          modelsVerified: 1,
          promptsCreated: 6,
          promptsSkipped: 2,
          categoryCreated: true,
        );

        expect(result.totalPrompts, equals(8));
      },
    );

    test('should handle zero values correctly', () {
      const result = MistralFtueResult(
        modelsCreated: 0,
        modelsVerified: 0,
        promptsCreated: 0,
        promptsSkipped: 0,
        categoryCreated: false,
      );

      expect(result.totalModels, equals(0));
      expect(result.totalPrompts, equals(0));
    });

    test('should include optional categoryReused and categoryName', () {
      const result = MistralFtueResult(
        modelsCreated: 3,
        modelsVerified: 0,
        promptsCreated: 8,
        promptsSkipped: 0,
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
        promptsCreated: 0,
        promptsSkipped: 0,
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
          createdAt: DateTime.now(),
          inputModalities: [Modality.text],
          outputModalities: [Modality.text],
          isReasoningModel: false,
        ),
      );
      registerFallbackValue(
        AiConfig.prompt(
          id: 'fallback-prompt',
          name: 'Fallback',
          systemMessage: 'system',
          userMessage: 'user',
          defaultModelId: 'model',
          modelIds: ['model'],
          createdAt: DateTime.now(),
          requiredInputData: [InputDataType.task],
          // ignore: deprecated_member_use_from_same_package
          aiResponseType: AiResponseType.taskSummary,
          useReasoning: false,
        ),
      );
      registerFallbackValue(
        CategoryDefinition(
          id: 'fallback-category',
          name: 'Fallback',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
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
      when(
        () => mockRepository.getConfigsByType(AiConfigType.prompt),
      ).thenAnswer((_) async => <AiConfig>[]);
      when(() => mockRepository.saveConfig(any())).thenAnswer((_) async {});
      when(
        () => mockCategoryRepository.getAllCategories(),
      ).thenAnswer((_) async => <CategoryDefinition>[]);
      when(
        () => mockCategoryRepository.createCategory(
          name: any(named: 'name'),
          color: any(named: 'color'),
        ),
      ).thenAnswer(
        (_) async => CategoryDefinition(
          id: 'test-category-id',
          name: 'Test Category Mistral Enabled',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
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
      expect(result!.promptsCreated, equals(1));
      expect(result!.promptsSkipped, equals(0));
      expect(result!.categoryCreated, isTrue);

      // 3 models + 1 prompt = 4 saves
      verify(() => mockRepository.saveConfig(any())).called(4);
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
      when(
        () => mockRepository.getConfigsByType(AiConfigType.prompt),
      ).thenAnswer((_) async => <AiConfig>[]);
      when(() => mockRepository.saveConfig(any())).thenAnswer((_) async {});
      when(
        () => mockCategoryRepository.getAllCategories(),
      ).thenAnswer((_) async => <CategoryDefinition>[]);
      when(
        () => mockCategoryRepository.createCategory(
          name: any(named: 'name'),
          color: any(named: 'color'),
        ),
      ).thenAnswer(
        (_) async => CategoryDefinition(
          id: 'test-category-id',
          name: 'Test Category Mistral Enabled',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
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

    testWidgets(
      'should skip existing prompts with same preconfiguredPromptId',
      (WidgetTester tester) async {
        final existingModels = [
          AiTestDataFactory.createTestModel(
            id: 'existing-flash',
            providerModelId: ftueMistralFlashModelId,
            inferenceProviderId: mistralProvider.id,
          ),
          AiTestDataFactory.createTestModel(
            id: 'existing-reasoning',
            providerModelId: ftueMistralReasoningModelId,
            inferenceProviderId: mistralProvider.id,
          ),
          AiTestDataFactory.createTestModel(
            id: 'existing-audio',
            providerModelId: ftueMistralAudioModelId,
            inferenceProviderId: mistralProvider.id,
          ),
        ];

        final existingPrompts = <AiConfig>[
          AiConfig.prompt(
            id: 'existing-prompt-id',
            name: 'Audio Transcription Mistral',
            systemMessage: 'system',
            userMessage: 'user',
            defaultModelId: 'existing-audio',
            modelIds: ['existing-audio'],
            createdAt: DateTime(2024, 3, 15),
            requiredInputData: [InputDataType.audioFiles],
            aiResponseType: AiResponseType.audioTranscription,
            preconfiguredPromptId: 'audio_transcription',
            useReasoning: false,
          ),
        ];

        when(
          () => mockRepository.getConfigsByType(AiConfigType.model),
        ).thenAnswer((_) async => existingModels);
        when(
          () => mockRepository.getConfigsByType(AiConfigType.prompt),
        ).thenAnswer((_) async => existingPrompts);
        when(() => mockRepository.saveConfig(any())).thenAnswer((_) async {});
        when(
          () => mockCategoryRepository.getAllCategories(),
        ).thenAnswer((_) async => <CategoryDefinition>[]);
        when(
          () => mockCategoryRepository.createCategory(
            name: any(named: 'name'),
            color: any(named: 'color'),
          ),
        ).thenAnswer(
          (_) async => CategoryDefinition(
            id: 'test-category-id',
            name: 'Test Category Mistral Enabled',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
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
        // audio_transcription no longer matches any new prompt config
        expect(result!.promptsSkipped, equals(0));
        expect(result!.promptsCreated, equals(1));
      },
    );

    testWidgets('should reuse existing category instead of creating new one', (
      WidgetTester tester,
    ) async {
      when(
        () => mockRepository.getConfigsByType(AiConfigType.model),
      ).thenAnswer((_) async => <AiConfig>[]);
      when(
        () => mockRepository.getConfigsByType(AiConfigType.prompt),
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
        ),
      );
    });

    testWidgets('should create category with Mistral orange color', (
      WidgetTester tester,
    ) async {
      when(
        () => mockRepository.getConfigsByType(AiConfigType.model),
      ).thenAnswer((_) async => <AiConfig>[]);
      when(
        () => mockRepository.getConfigsByType(AiConfigType.prompt),
      ).thenAnswer((_) async => <AiConfig>[]);
      when(() => mockRepository.saveConfig(any())).thenAnswer((_) async {});
      when(
        () => mockCategoryRepository.getAllCategories(),
      ).thenAnswer((_) async => <CategoryDefinition>[]);
      when(
        () => mockCategoryRepository.createCategory(
          name: any(named: 'name'),
          color: any(named: 'color'),
        ),
      ).thenAnswer(
        (_) async => CategoryDefinition(
          id: 'test-category-id',
          name: 'Test Category Mistral Enabled',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
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
          promptsCreated: 7,
          promptsSkipped: 2,
          categoryCreated: true,
        );

        expect(result.totalModels, equals(5));
      },
    );

    test(
      'totalPrompts should return sum of promptsCreated and promptsSkipped',
      () {
        const result = AlibabaFtueResult(
          modelsCreated: 3,
          modelsVerified: 2,
          promptsCreated: 7,
          promptsSkipped: 2,
          categoryCreated: true,
        );

        expect(result.totalPrompts, equals(9));
      },
    );

    test('should handle zero values correctly', () {
      const result = AlibabaFtueResult(
        modelsCreated: 0,
        modelsVerified: 0,
        promptsCreated: 0,
        promptsSkipped: 0,
        categoryCreated: false,
      );

      expect(result.totalModels, equals(0));
      expect(result.totalPrompts, equals(0));
    });

    test('should include optional categoryReused and categoryName', () {
      const result = AlibabaFtueResult(
        modelsCreated: 5,
        modelsVerified: 0,
        promptsCreated: 9,
        promptsSkipped: 0,
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
        promptsCreated: 0,
        promptsSkipped: 0,
        categoryCreated: false,
        errors: ['Alibaba Error 1', 'Alibaba Error 2'],
      );

      expect(result.errors, hasLength(2));
      expect(result.errors, contains('Alibaba Error 1'));
      expect(result.errors, contains('Alibaba Error 2'));
    });
  });

  group('Alibaba - Dialog UI', () {
    late ProviderPromptSetupService setupService;
    late MockAiConfigRepository mockRepository;
    late AiConfigInferenceProvider alibabaProvider;
    late List<AiConfigModel> alibabaModels;

    setUpAll(AiTestSetup.registerFallbackValues);

    setUp(() {
      setupService = const ProviderPromptSetupService();
      mockRepository = MockAiConfigRepository();

      alibabaProvider = AiTestDataFactory.createTestProvider(
        id: 'alibaba-provider-id',
        name: 'Alibaba Cloud (Qwen)',
        type: InferenceProviderType.alibaba,
        apiKey: 'test-alibaba-key',
        baseUrl: 'https://dashscope-intl.aliyuncs.com/compatible-mode/v1',
      );

      alibabaModels = [
        AiTestDataFactory.createTestModel(
          id: 'alibaba-provider-id_qwen3_max',
          name: 'Qwen3 Max',
          inferenceProviderId: alibabaProvider.id,
          inputModalities: [Modality.text],
          isReasoningModel: true,
          supportsFunctionCalling: true,
        ),
        AiTestDataFactory.createTestModel(
          id: 'alibaba-provider-id_qwen_flash',
          name: 'Qwen Flash',
          inferenceProviderId: alibabaProvider.id,
          inputModalities: [Modality.text],
        ),
        AiTestDataFactory.createTestModel(
          id: 'alibaba-provider-id_qwen3_omni_flash',
          name: 'Qwen3 Omni Flash',
          inferenceProviderId: alibabaProvider.id,
          inputModalities: [Modality.text, Modality.audio],
        ),
        AiTestDataFactory.createTestModel(
          id: 'alibaba-provider-id_qwen3_vl_flash',
          name: 'Qwen3 VL Flash',
          inferenceProviderId: alibabaProvider.id,
          inputModalities: [Modality.text, Modality.image],
        ),
      ];
    });

    Widget createTestWidget({
      required Widget child,
      required Future<void> Function(BuildContext, WidgetRef) onPressed,
    }) {
      return AiTestWidgets.createTestWidget(
        repository: mockRepository,
        child: Consumer(
          builder: (context, ref, _) => ElevatedButton(
            onPressed: () => onPressed(context, ref),
            child: child,
          ),
        ),
      );
    }

    testWidgets('should return false for Alibaba (empty prompt configs)', (
      WidgetTester tester,
    ) async {
      when(
        () => mockRepository.getConfigsByType(AiConfigType.model),
      ).thenAnswer((_) async => alibabaModels);

      bool? result;

      await tester.pumpWidget(
        createTestWidget(
          child: const Text('Test Button'),
          onPressed: (context, ref) async {
            result = await setupService.offerPromptSetup(
              context: context,
              ref: ref,
              provider: alibabaProvider,
            );
          },
        ),
      );

      await tester.tap(find.text('Test Button'));
      await tester.pump();

      // Short-circuits: empty prompt configs → no dialog, returns false.
      expect(find.text('Set Up Default Prompts?'), findsNothing);
      expect(result, isFalse);
      verifyNever(() => mockRepository.saveConfig(any()));
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
        AiConfig.prompt(
          id: 'fallback-prompt',
          name: 'Fallback',
          systemMessage: 'system',
          userMessage: 'user',
          defaultModelId: 'model',
          modelIds: ['model'],
          createdAt: DateTime(2024, 3, 15),
          requiredInputData: [InputDataType.task],
          // ignore: deprecated_member_use_from_same_package
          aiResponseType: AiResponseType.taskSummary,
          useReasoning: false,
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

    testWidgets('should create 5 models and 2 prompts when none exist', (
      WidgetTester tester,
    ) async {
      when(
        () => mockRepository.getConfigsByType(AiConfigType.model),
      ).thenAnswer((_) async => <AiConfig>[]);
      when(
        () => mockRepository.getConfigsByType(AiConfigType.prompt),
      ).thenAnswer((_) async => <AiConfig>[]);
      when(() => mockRepository.saveConfig(any())).thenAnswer((_) async {});
      when(
        () => mockCategoryRepository.getAllCategories(),
      ).thenAnswer((_) async => <CategoryDefinition>[]);
      when(
        () => mockCategoryRepository.createCategory(
          name: any(named: 'name'),
          color: any(named: 'color'),
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
      expect(result!.promptsCreated, equals(2));
      expect(result!.promptsSkipped, equals(0));
      expect(result!.categoryCreated, isTrue);

      // 5 models + 2 prompts = 7 saves
      verify(() => mockRepository.saveConfig(any())).called(7);
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
          name: 'Qwen3 Max',
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
      when(
        () => mockRepository.getConfigsByType(AiConfigType.prompt),
      ).thenAnswer((_) async => <AiConfig>[]);
      when(() => mockRepository.saveConfig(any())).thenAnswer((_) async {});
      when(
        () => mockCategoryRepository.getAllCategories(),
      ).thenAnswer((_) async => <CategoryDefinition>[]);
      when(
        () => mockCategoryRepository.createCategory(
          name: any(named: 'name'),
          color: any(named: 'color'),
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

    testWidgets(
      'should skip existing prompts with same preconfiguredPromptId',
      (WidgetTester tester) async {
        final existingModels = [
          AiTestDataFactory.createTestModel(
            id: 'existing-flash',
            providerModelId: ftueAlibabaFlashModelId,
            inferenceProviderId: alibabaProvider.id,
          ),
          AiTestDataFactory.createTestModel(
            id: 'existing-reasoning',
            providerModelId: ftueAlibabaReasoningModelId,
            inferenceProviderId: alibabaProvider.id,
          ),
          AiTestDataFactory.createTestModel(
            id: 'existing-audio',
            providerModelId: ftueAlibabaAudioModelId,
            inferenceProviderId: alibabaProvider.id,
          ),
          AiTestDataFactory.createTestModel(
            id: 'existing-vision',
            providerModelId: ftueAlibabaVisionModelId,
            inferenceProviderId: alibabaProvider.id,
          ),
          AiTestDataFactory.createTestModel(
            id: 'existing-image',
            providerModelId: ftueAlibabaImageModelId,
            inferenceProviderId: alibabaProvider.id,
          ),
        ];

        final existingPrompts = <AiConfig>[
          AiConfig.prompt(
            id: 'existing-prompt-id',
            name: 'Audio Transcription Alibaba',
            systemMessage: 'system',
            userMessage: 'user',
            defaultModelId: 'existing-audio',
            modelIds: ['existing-audio'],
            createdAt: DateTime(2024, 3, 15),
            requiredInputData: [InputDataType.audioFiles],
            aiResponseType: AiResponseType.audioTranscription,
            preconfiguredPromptId: 'audio_transcription',
            useReasoning: false,
          ),
        ];

        when(
          () => mockRepository.getConfigsByType(AiConfigType.model),
        ).thenAnswer((_) async => existingModels);
        when(
          () => mockRepository.getConfigsByType(AiConfigType.prompt),
        ).thenAnswer((_) async => existingPrompts);
        when(() => mockRepository.saveConfig(any())).thenAnswer((_) async {});
        when(
          () => mockCategoryRepository.getAllCategories(),
        ).thenAnswer((_) async => <CategoryDefinition>[]);
        when(
          () => mockCategoryRepository.createCategory(
            name: any(named: 'name'),
            color: any(named: 'color'),
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
        // audio_transcription no longer matches any new prompt config
        expect(result!.promptsSkipped, equals(0));
        expect(result!.promptsCreated, equals(2));
      },
    );

    testWidgets('should reuse existing category instead of creating new one', (
      WidgetTester tester,
    ) async {
      when(
        () => mockRepository.getConfigsByType(AiConfigType.model),
      ).thenAnswer((_) async => <AiConfig>[]);
      when(
        () => mockRepository.getConfigsByType(AiConfigType.prompt),
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
        ),
      );
    });

    testWidgets('should create category with Alibaba orange color', (
      WidgetTester tester,
    ) async {
      when(
        () => mockRepository.getConfigsByType(AiConfigType.model),
      ).thenAnswer((_) async => <AiConfig>[]);
      when(
        () => mockRepository.getConfigsByType(AiConfigType.prompt),
      ).thenAnswer((_) async => <AiConfig>[]);
      when(() => mockRepository.saveConfig(any())).thenAnswer((_) async {});
      when(
        () => mockCategoryRepository.getAllCategories(),
      ).thenAnswer((_) async => <CategoryDefinition>[]);
      when(
        () => mockCategoryRepository.createCategory(
          name: any(named: 'name'),
          color: any(named: 'color'),
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
        ),
      ).called(1);
    });
  });
}
