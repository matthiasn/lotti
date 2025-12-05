import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/services/provider_prompt_setup_service.dart';
import 'package:mocktail/mocktail.dart';

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

    // Unsupported provider
    late AiConfigInferenceProvider openAiProvider;

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
          id: 'ollama-provider-id_deepseek_r1_8b',
          name: 'DeepSeek R1 8B',
          inferenceProviderId: ollamaProvider.id,
          inputModalities: [Modality.text],
          isReasoningModel: true,
          supportsFunctionCalling: true,
        ),
        AiTestDataFactory.createTestModel(
          id: 'ollama-provider-id_gemma3_12b',
          name: 'Gemma 3 12B',
          inferenceProviderId: ollamaProvider.id,
          inputModalities: [Modality.text, Modality.image],
        ),
      ];

      // Unsupported provider
      openAiProvider = AiTestDataFactory.createTestProvider(
        id: 'openai-provider-id',
        name: 'My OpenAI',
        type: InferenceProviderType.openAi,
        apiKey: 'test-openai-key',
        baseUrl: 'https://api.openai.com/v1',
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
      testWidgets('should return false for unsupported providers',
          (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1024, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        bool? result;

        await tester.pumpWidget(createTestWidget(
          child: const Text('Test Button'),
          onPressed: (context, ref) async {
            result = await setupService.offerPromptSetup(
              context: context,
              ref: ref,
              provider: openAiProvider,
            );
          },
        ));

        await tester.tap(find.text('Test Button'));
        await tester.pumpAndSettle();

        expect(result, isFalse);
        expect(find.text('Set Up Default Prompts?'), findsNothing);
      });

      testWidgets('should show dialog for Gemini provider',
          (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1024, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        when(() => mockRepository.getConfigsByType(AiConfigType.model))
            .thenAnswer((_) async => geminiModels);

        await tester.pumpWidget(createTestWidget(
          child: const Text('Test Button'),
          onPressed: (context, ref) async {
            await setupService.offerPromptSetup(
              context: context,
              ref: ref,
              provider: geminiProvider,
            );
          },
        ));

        await tester.tap(find.text('Test Button'));
        await tester.pumpAndSettle();

        expect(find.text('Set Up Default Prompts?'), findsOneWidget);
      });

      testWidgets('should show dialog for Ollama provider',
          (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1024, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        when(() => mockRepository.getConfigsByType(AiConfigType.model))
            .thenAnswer((_) async => ollamaModels);

        await tester.pumpWidget(createTestWidget(
          child: const Text('Test Button'),
          onPressed: (context, ref) async {
            await setupService.offerPromptSetup(
              context: context,
              ref: ref,
              provider: ollamaProvider,
            );
          },
        ));

        await tester.tap(find.text('Test Button'));
        await tester.pumpAndSettle();

        expect(find.text('Set Up Default Prompts?'), findsOneWidget);
      });
    });

    group('Gemini - Dialog UI', () {
      testWidgets('should display correct prompts for Gemini',
          (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1024, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        when(() => mockRepository.getConfigsByType(AiConfigType.model))
            .thenAnswer((_) async => geminiModels);

        await tester.pumpWidget(createTestWidget(
          child: const Text('Test Button'),
          onPressed: (context, ref) async {
            await setupService.offerPromptSetup(
              context: context,
              ref: ref,
              provider: geminiProvider,
            );
          },
        ));

        await tester.tap(find.text('Test Button'));
        await tester.pumpAndSettle();

        expect(find.text('Set Up Default Prompts?'), findsOneWidget);
        expect(find.text('Get started quickly with Gemini'), findsOneWidget);
        expect(find.text('Prompts to create:'), findsOneWidget);

        // Gemini should have 4 prompts including Audio
        expect(find.text('Audio Transcript'), findsOneWidget);
        expect(find.text('Image Analysis'), findsOneWidget);
        expect(find.text('Checklist Updates'), findsOneWidget);
        expect(find.text('Task Summary'), findsOneWidget);

        // Model assignments
        expect(find.text('Uses Gemini 2.5 Flash'), findsOneWidget);
        expect(find.text('Uses Gemini 2.5 Pro'), findsNWidgets(3));
      });

      testWidgets('should display correct icons for Gemini prompts',
          (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1024, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        when(() => mockRepository.getConfigsByType(AiConfigType.model))
            .thenAnswer((_) async => geminiModels);

        await tester.pumpWidget(createTestWidget(
          child: const Text('Test Button'),
          onPressed: (context, ref) async {
            await setupService.offerPromptSetup(
              context: context,
              ref: ref,
              provider: geminiProvider,
            );
          },
        ));

        await tester.tap(find.text('Test Button'));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.mic), findsOneWidget);
        expect(find.byIcon(Icons.image), findsOneWidget);
        expect(find.byIcon(Icons.checklist), findsOneWidget);
        expect(find.byIcon(Icons.summarize), findsOneWidget);
      });
    });

    group('Ollama - Dialog UI', () {
      testWidgets('should display correct prompts for Ollama (no audio)',
          (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1024, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        when(() => mockRepository.getConfigsByType(AiConfigType.model))
            .thenAnswer((_) async => ollamaModels);

        await tester.pumpWidget(createTestWidget(
          child: const Text('Test Button'),
          onPressed: (context, ref) async {
            await setupService.offerPromptSetup(
              context: context,
              ref: ref,
              provider: ollamaProvider,
            );
          },
        ));

        await tester.tap(find.text('Test Button'));
        await tester.pumpAndSettle();

        expect(find.text('Set Up Default Prompts?'), findsOneWidget);
        expect(find.text('Get started quickly with Ollama'), findsOneWidget);
        expect(find.text('Prompts to create:'), findsOneWidget);

        // Ollama should have 3 prompts (no Audio)
        expect(find.text('Audio Transcript'), findsNothing);
        expect(find.text('Image Analysis'), findsOneWidget);
        expect(find.text('Checklist Updates'), findsOneWidget);
        expect(find.text('Task Summary'), findsOneWidget);

        // Model assignments - DeepSeek for reasoning, Gemma for images
        expect(find.text('Uses DeepSeek R1 8B'), findsNWidgets(2));
        expect(find.text('Uses Gemma 3 12B'), findsOneWidget);
      });

      testWidgets('should display correct icons for Ollama prompts',
          (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1024, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        when(() => mockRepository.getConfigsByType(AiConfigType.model))
            .thenAnswer((_) async => ollamaModels);

        await tester.pumpWidget(createTestWidget(
          child: const Text('Test Button'),
          onPressed: (context, ref) async {
            await setupService.offerPromptSetup(
              context: context,
              ref: ref,
              provider: ollamaProvider,
            );
          },
        ));

        await tester.tap(find.text('Test Button'));
        await tester.pumpAndSettle();

        // No mic icon for Ollama
        expect(find.byIcon(Icons.mic), findsNothing);
        expect(find.byIcon(Icons.image), findsOneWidget);
        expect(find.byIcon(Icons.checklist), findsOneWidget);
        expect(find.byIcon(Icons.summarize), findsOneWidget);
      });
    });

    group('User Interaction - Cancel', () {
      testWidgets('should return false when user taps "No Thanks"',
          (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1024, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        when(() => mockRepository.getConfigsByType(AiConfigType.model))
            .thenAnswer((_) async => geminiModels);

        bool? result;

        await tester.pumpWidget(createTestWidget(
          child: const Text('Test Button'),
          onPressed: (context, ref) async {
            result = await setupService.offerPromptSetup(
              context: context,
              ref: ref,
              provider: geminiProvider,
            );
          },
        ));

        await tester.tap(find.text('Test Button'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('No Thanks'));
        await tester.pumpAndSettle();

        expect(result, isFalse);
        expect(find.text('Set Up Default Prompts?'), findsNothing);
        verifyNever(() => mockRepository.saveConfig(any()));
      });
    });

    group('Gemini - Prompt Creation', () {
      testWidgets('should create 4 prompts for Gemini when user confirms',
          (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1024, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        when(() => mockRepository.getConfigsByType(AiConfigType.model))
            .thenAnswer((_) async => geminiModels);
        when(() => mockRepository.saveConfig(any())).thenAnswer((_) async {});

        bool? result;

        await tester.pumpWidget(createTestWidget(
          child: const Text('Test Button'),
          onPressed: (context, ref) async {
            result = await setupService.offerPromptSetup(
              context: context,
              ref: ref,
              provider: geminiProvider,
            );
          },
        ));

        await tester.tap(find.text('Test Button'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Set Up Prompts'));
        await tester.pumpAndSettle();

        expect(result, isTrue);
        verify(() => mockRepository.saveConfig(any())).called(4);
      });

      testWidgets('should create prompts with correct names for Gemini',
          (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1024, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        when(() => mockRepository.getConfigsByType(AiConfigType.model))
            .thenAnswer((_) async => geminiModels);

        final savedConfigs = <AiConfig>[];
        when(() => mockRepository.saveConfig(any())).thenAnswer((invocation) {
          savedConfigs.add(invocation.positionalArguments[0] as AiConfig);
          return Future.value();
        });

        await tester.pumpWidget(createTestWidget(
          child: const Text('Test Button'),
          onPressed: (context, ref) async {
            await setupService.offerPromptSetup(
              context: context,
              ref: ref,
              provider: geminiProvider,
            );
          },
        ));

        await tester.tap(find.text('Test Button'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Set Up Prompts'));
        await tester.pumpAndSettle();

        final promptNames = savedConfigs
            .whereType<AiConfigPrompt>()
            .map((p) => p.name)
            .toList();

        expect(promptNames, contains('Audio Transcription - Gemini 2.5 Flash'));
        expect(promptNames,
            contains('Image Analysis in Task Context - Gemini 2.5 Pro'));
        expect(promptNames, contains('Checklist Updates - Gemini 2.5 Pro'));
        expect(promptNames, contains('Task Summary - Gemini 2.5 Pro'));
      });
    });

    group('Ollama - Prompt Creation', () {
      testWidgets('should create 3 prompts for Ollama when user confirms',
          (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1024, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        when(() => mockRepository.getConfigsByType(AiConfigType.model))
            .thenAnswer((_) async => ollamaModels);
        when(() => mockRepository.saveConfig(any())).thenAnswer((_) async {});

        bool? result;

        await tester.pumpWidget(createTestWidget(
          child: const Text('Test Button'),
          onPressed: (context, ref) async {
            result = await setupService.offerPromptSetup(
              context: context,
              ref: ref,
              provider: ollamaProvider,
            );
          },
        ));

        await tester.tap(find.text('Test Button'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Set Up Prompts'));
        await tester.pumpAndSettle();

        expect(result, isTrue);
        verify(() => mockRepository.saveConfig(any())).called(3);
      });

      testWidgets('should create prompts with correct names for Ollama',
          (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1024, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        when(() => mockRepository.getConfigsByType(AiConfigType.model))
            .thenAnswer((_) async => ollamaModels);

        final savedConfigs = <AiConfig>[];
        when(() => mockRepository.saveConfig(any())).thenAnswer((invocation) {
          savedConfigs.add(invocation.positionalArguments[0] as AiConfig);
          return Future.value();
        });

        await tester.pumpWidget(createTestWidget(
          child: const Text('Test Button'),
          onPressed: (context, ref) async {
            await setupService.offerPromptSetup(
              context: context,
              ref: ref,
              provider: ollamaProvider,
            );
          },
        ));

        await tester.tap(find.text('Test Button'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Set Up Prompts'));
        await tester.pumpAndSettle();

        final promptNames = savedConfigs
            .whereType<AiConfigPrompt>()
            .map((p) => p.name)
            .toList();

        // No audio prompt for Ollama
        expect(promptNames.any((n) => n.contains('Audio')), isFalse);
        expect(promptNames,
            contains('Image Analysis in Task Context - Gemma 3 12B'));
        expect(promptNames, contains('Checklist Updates - DeepSeek R1 8B'));
        expect(promptNames, contains('Task Summary - DeepSeek R1 8B'));
      });

      testWidgets('should assign DeepSeek to reasoning prompts',
          (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1024, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        when(() => mockRepository.getConfigsByType(AiConfigType.model))
            .thenAnswer((_) async => ollamaModels);

        final savedConfigs = <AiConfig>[];
        when(() => mockRepository.saveConfig(any())).thenAnswer((invocation) {
          savedConfigs.add(invocation.positionalArguments[0] as AiConfig);
          return Future.value();
        });

        await tester.pumpWidget(createTestWidget(
          child: const Text('Test Button'),
          onPressed: (context, ref) async {
            await setupService.offerPromptSetup(
              context: context,
              ref: ref,
              provider: ollamaProvider,
            );
          },
        ));

        await tester.tap(find.text('Test Button'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Set Up Prompts'));
        await tester.pumpAndSettle();

        final deepSeekModelId =
            ollamaModels.firstWhere((m) => m.name.contains('DeepSeek')).id;

        final checklistPrompt = savedConfigs
            .whereType<AiConfigPrompt>()
            .firstWhere((p) => p.name.contains('Checklist'));
        expect(checklistPrompt.defaultModelId, deepSeekModelId);

        final summaryPrompt = savedConfigs
            .whereType<AiConfigPrompt>()
            .firstWhere((p) => p.name.contains('Task Summary'));
        expect(summaryPrompt.defaultModelId, deepSeekModelId);
      });

      testWidgets('should assign Gemma to image analysis prompt',
          (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1024, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        when(() => mockRepository.getConfigsByType(AiConfigType.model))
            .thenAnswer((_) async => ollamaModels);

        final savedConfigs = <AiConfig>[];
        when(() => mockRepository.saveConfig(any())).thenAnswer((invocation) {
          savedConfigs.add(invocation.positionalArguments[0] as AiConfig);
          return Future.value();
        });

        await tester.pumpWidget(createTestWidget(
          child: const Text('Test Button'),
          onPressed: (context, ref) async {
            await setupService.offerPromptSetup(
              context: context,
              ref: ref,
              provider: ollamaProvider,
            );
          },
        ));

        await tester.tap(find.text('Test Button'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Set Up Prompts'));
        await tester.pumpAndSettle();

        final gemmaModelId =
            ollamaModels.firstWhere((m) => m.name.contains('Gemma')).id;

        final imagePrompt = savedConfigs
            .whereType<AiConfigPrompt>()
            .firstWhere((p) => p.name.contains('Image Analysis'));
        expect(imagePrompt.defaultModelId, gemmaModelId);
      });
    });

    group('Snackbar Feedback', () {
      testWidgets('should show correct count for Gemini (4 prompts)',
          (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1024, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        when(() => mockRepository.getConfigsByType(AiConfigType.model))
            .thenAnswer((_) async => geminiModels);
        when(() => mockRepository.saveConfig(any())).thenAnswer((_) async {});

        await tester.pumpWidget(createTestWidget(
          child: const Text('Test Button'),
          onPressed: (context, ref) async {
            await setupService.offerPromptSetup(
              context: context,
              ref: ref,
              provider: geminiProvider,
            );
          },
        ));

        await tester.tap(find.text('Test Button'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Set Up Prompts'));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.check_circle), findsOneWidget);
        expect(find.text('4 prompts created successfully!'), findsOneWidget);
      });

      testWidgets('should show correct count for Ollama (3 prompts)',
          (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1024, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        when(() => mockRepository.getConfigsByType(AiConfigType.model))
            .thenAnswer((_) async => ollamaModels);
        when(() => mockRepository.saveConfig(any())).thenAnswer((_) async {});

        await tester.pumpWidget(createTestWidget(
          child: const Text('Test Button'),
          onPressed: (context, ref) async {
            await setupService.offerPromptSetup(
              context: context,
              ref: ref,
              provider: ollamaProvider,
            );
          },
        ));

        await tester.tap(find.text('Test Button'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Set Up Prompts'));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.check_circle), findsOneWidget);
        expect(find.text('3 prompts created successfully!'), findsOneWidget);
      });
    });

    group('Edge Cases', () {
      testWidgets(
          'should return false and not show dialog when no models available',
          (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1024, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        when(() => mockRepository.getConfigsByType(AiConfigType.model))
            .thenAnswer((_) async => []);

        bool? result;

        await tester.pumpWidget(createTestWidget(
          child: const Text('Test Button'),
          onPressed: (context, ref) async {
            result = await setupService.offerPromptSetup(
              context: context,
              ref: ref,
              provider: geminiProvider,
            );
          },
        ));

        await tester.tap(find.text('Test Button'));
        await tester.pumpAndSettle();

        expect(find.text('Set Up Default Prompts?'), findsNothing);
        expect(result, isFalse);
        verifyNever(() => mockRepository.saveConfig(any()));
      });

      testWidgets('should handle models from different providers',
          (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1024, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final mixedModels = [
          ...ollamaModels,
          AiTestDataFactory.createTestModel(
            id: 'other-model',
            name: 'Other Model',
            inferenceProviderId: 'other-provider-id',
          ),
        ];

        when(() => mockRepository.getConfigsByType(AiConfigType.model))
            .thenAnswer((_) async => mixedModels);

        final savedConfigs = <AiConfig>[];
        when(() => mockRepository.saveConfig(any())).thenAnswer((invocation) {
          savedConfigs.add(invocation.positionalArguments[0] as AiConfig);
          return Future.value();
        });

        await tester.pumpWidget(createTestWidget(
          child: const Text('Test Button'),
          onPressed: (context, ref) async {
            await setupService.offerPromptSetup(
              context: context,
              ref: ref,
              provider: ollamaProvider,
            );
          },
        ));

        await tester.tap(find.text('Test Button'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Set Up Prompts'));
        await tester.pumpAndSettle();

        final ollamaModelIds = ollamaModels.map((m) => m.id).toSet();
        for (final config in savedConfigs.whereType<AiConfigPrompt>()) {
          expect(config.defaultModelId, isNot('other-model'));
          expect(ollamaModelIds.contains(config.defaultModelId), isTrue);
        }
      });

      testWidgets('should fallback to first model when DeepSeek not found',
          (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1024, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final gemmaOnlyModels = [
          AiTestDataFactory.createTestModel(
            id: 'ollama-gemma-only',
            name: 'Gemma 3 12B',
            inferenceProviderId: ollamaProvider.id,
            inputModalities: [Modality.text, Modality.image],
          ),
        ];

        when(() => mockRepository.getConfigsByType(AiConfigType.model))
            .thenAnswer((_) async => gemmaOnlyModels);

        final savedConfigs = <AiConfig>[];
        when(() => mockRepository.saveConfig(any())).thenAnswer((invocation) {
          savedConfigs.add(invocation.positionalArguments[0] as AiConfig);
          return Future.value();
        });

        await tester.pumpWidget(createTestWidget(
          child: const Text('Test Button'),
          onPressed: (context, ref) async {
            await setupService.offerPromptSetup(
              context: context,
              ref: ref,
              provider: ollamaProvider,
            );
          },
        ));

        await tester.tap(find.text('Test Button'));
        await tester.pumpAndSettle();

        // All prompts should use the only available model
        expect(find.text('Uses Gemma 3 12B'), findsNWidgets(3));

        await tester.tap(find.text('Set Up Prompts'));
        await tester.pumpAndSettle();

        for (final config in savedConfigs.whereType<AiConfigPrompt>()) {
          expect(config.defaultModelId, 'ollama-gemma-only');
        }
      });
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

      test('supportedProviders should include Gemini and Ollama', () {
        expect(
          ProviderPromptSetupService.supportedProviders,
          containsAll([
            InferenceProviderType.gemini,
            InferenceProviderType.ollama,
          ]),
        );
      });
    });

    group('Prompt Configuration', () {
      testWidgets('should set trackPreconfigured to true for all prompts',
          (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1024, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        when(() => mockRepository.getConfigsByType(AiConfigType.model))
            .thenAnswer((_) async => ollamaModels);

        final savedConfigs = <AiConfig>[];
        when(() => mockRepository.saveConfig(any())).thenAnswer((invocation) {
          savedConfigs.add(invocation.positionalArguments[0] as AiConfig);
          return Future.value();
        });

        await tester.pumpWidget(createTestWidget(
          child: const Text('Test Button'),
          onPressed: (context, ref) async {
            await setupService.offerPromptSetup(
              context: context,
              ref: ref,
              provider: ollamaProvider,
            );
          },
        ));

        await tester.tap(find.text('Test Button'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Set Up Prompts'));
        await tester.pumpAndSettle();

        for (final config in savedConfigs.whereType<AiConfigPrompt>()) {
          expect(config.trackPreconfigured, isTrue);
        }
      });

      testWidgets('should set correct aiResponseType for each prompt type',
          (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1024, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        when(() => mockRepository.getConfigsByType(AiConfigType.model))
            .thenAnswer((_) async => ollamaModels);

        final savedConfigs = <AiConfig>[];
        when(() => mockRepository.saveConfig(any())).thenAnswer((invocation) {
          savedConfigs.add(invocation.positionalArguments[0] as AiConfig);
          return Future.value();
        });

        await tester.pumpWidget(createTestWidget(
          child: const Text('Test Button'),
          onPressed: (context, ref) async {
            await setupService.offerPromptSetup(
              context: context,
              ref: ref,
              provider: ollamaProvider,
            );
          },
        ));

        await tester.tap(find.text('Test Button'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Set Up Prompts'));
        await tester.pumpAndSettle();

        final prompts = savedConfigs.whereType<AiConfigPrompt>().toList();

        final imagePrompt = prompts.firstWhere((p) => p.name.contains('Image'));
        expect(imagePrompt.aiResponseType, AiResponseType.imageAnalysis);

        final checklistPrompt =
            prompts.firstWhere((p) => p.name.contains('Checklist'));
        expect(checklistPrompt.aiResponseType, AiResponseType.checklistUpdates);

        final summaryPrompt =
            prompts.firstWhere((p) => p.name.contains('Summary'));
        expect(summaryPrompt.aiResponseType, AiResponseType.taskSummary);
      });
    });
  });
}
