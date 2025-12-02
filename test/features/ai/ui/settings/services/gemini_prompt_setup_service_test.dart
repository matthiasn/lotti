import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/services/gemini_prompt_setup_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../test_utils.dart';

void main() {
  group('GeminiPromptSetupService', () {
    late GeminiPromptSetupService setupService;
    late MockAiConfigRepository mockRepository;
    late AiConfigInferenceProvider geminiProvider;
    late AiConfigInferenceProvider openAiProvider;
    late List<AiConfigModel> geminiModels;

    setUpAll(AiTestSetup.registerFallbackValues);

    setUp(() {
      setupService = const GeminiPromptSetupService();
      mockRepository = MockAiConfigRepository();

      geminiProvider = AiTestDataFactory.createTestProvider(
        id: 'gemini-provider-id',
        name: 'My Gemini',
        type: InferenceProviderType.gemini,
        apiKey: 'test-gemini-key',
        baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
      );

      openAiProvider = AiTestDataFactory.createTestProvider(
        id: 'openai-provider-id',
        name: 'My OpenAI',
        type: InferenceProviderType.openAi,
        apiKey: 'test-openai-key',
        baseUrl: 'https://api.openai.com/v1',
      );

      // Create Gemini models - Flash for audio, Pro for reasoning
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

    group('offerPromptSetup() - Provider Type Checks', () {
      testWidgets('should return false for non-Gemini providers',
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
    });

    group('Dialog UI', () {
      testWidgets('should display dialog with correct title and content',
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
        expect(find.byIcon(Icons.auto_awesome), findsAtLeastNWidgets(1));
        expect(find.text('Get started quickly'), findsOneWidget);
        expect(find.textContaining('ready-to-use prompts'), findsOneWidget);
        expect(find.text('Prompts to create:'), findsOneWidget);
        expect(find.text('Audio Transcript'), findsOneWidget);
        expect(find.text('Image Analysis'), findsOneWidget);
        expect(find.text('Checklist Updates'), findsOneWidget);
        expect(find.text('Task Summary'), findsOneWidget);
        // Dynamic model names from actual available models
        expect(find.text('Uses Gemini 2.5 Flash'), findsOneWidget);
        expect(find.text('Uses Gemini 2.5 Pro'), findsNWidgets(3));
        expect(find.text('No Thanks'), findsOneWidget);
        expect(find.text('Set Up Prompts'), findsOneWidget);
      });

      testWidgets('should display correct icons for each prompt type',
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

    group('User Interaction - Confirm', () {
      testWidgets('should create prompts when user confirms',
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

      testWidgets('should create prompts with correct dynamic names',
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

        // Prompt names now use actual model names
        expect(promptNames, contains('Audio Transcription - Gemini 2.5 Flash'));
        expect(promptNames,
            contains('Image Analysis in Task Context - Gemini 2.5 Pro'));
        expect(promptNames, contains('Checklist Updates - Gemini 2.5 Pro'));
        expect(promptNames, contains('Task Summary - Gemini 2.5 Pro'));
      });

      testWidgets('should assign Flash model to audio transcription',
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

        final audioPrompt = savedConfigs
            .whereType<AiConfigPrompt>()
            .firstWhere((p) => p.name.contains('Audio Transcription'));

        expect(audioPrompt.defaultModelId,
            geminiModels.firstWhere((m) => m.name.contains('Flash')).id);
      });

      testWidgets('should assign Pro model to reasoning prompts',
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

        final proModelId =
            geminiModels.firstWhere((m) => m.name.contains('Pro')).id;

        final imagePrompt = savedConfigs
            .whereType<AiConfigPrompt>()
            .firstWhere((p) => p.name.contains('Image Analysis'));
        expect(imagePrompt.defaultModelId, proModelId);

        final checklistPrompt = savedConfigs
            .whereType<AiConfigPrompt>()
            .firstWhere((p) => p.name.contains('Checklist'));
        expect(checklistPrompt.defaultModelId, proModelId);

        final summaryPrompt = savedConfigs
            .whereType<AiConfigPrompt>()
            .firstWhere((p) => p.name.contains('Task Summary'));
        expect(summaryPrompt.defaultModelId, proModelId);
      });

      testWidgets('should set trackPreconfigured to true',
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

        for (final config in savedConfigs.whereType<AiConfigPrompt>()) {
          expect(config.trackPreconfigured, isTrue);
        }
      });

      testWidgets('should set correct aiResponseType for each prompt',
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

        final prompts = savedConfigs.whereType<AiConfigPrompt>().toList();

        final audioPrompt = prompts.firstWhere((p) => p.name.contains('Audio'));
        expect(audioPrompt.aiResponseType, AiResponseType.audioTranscription);

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

    group('Snackbar Feedback', () {
      testWidgets('should show success snackbar after creating prompts',
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

        // Dialog should not appear when no models are available
        expect(find.text('Set Up Default Prompts?'), findsNothing);
        expect(result, isFalse);
        verifyNever(() => mockRepository.saveConfig(any()));
      });

      testWidgets('should handle models from different providers',
          (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1024, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final mixedModels = [
          ...geminiModels,
          AiTestDataFactory.createTestModel(
            id: 'openai-model',
            name: 'GPT-4',
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
              provider: geminiProvider,
            );
          },
        ));

        await tester.tap(find.text('Test Button'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Set Up Prompts'));
        await tester.pumpAndSettle();

        final geminiModelIds = geminiModels.map((m) => m.id).toSet();
        for (final config in savedConfigs.whereType<AiConfigPrompt>()) {
          expect(config.defaultModelId, isNot('openai-model'));
          expect(geminiModelIds.contains(config.defaultModelId), isTrue);
        }
      });

      testWidgets('should use first available model when no Flash found',
          (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1024, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final proOnlyModels = [
          AiTestDataFactory.createTestModel(
            id: 'gemini-pro-only',
            name: 'Gemini 2.5 Pro',
            inferenceProviderId: geminiProvider.id,
            inputModalities: [Modality.text, Modality.image, Modality.audio],
            isReasoningModel: true,
          ),
        ];

        when(() => mockRepository.getConfigsByType(AiConfigType.model))
            .thenAnswer((_) async => proOnlyModels);

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

        // Dialog should show the only available model for both Flash and Pro
        expect(find.text('Uses Gemini 2.5 Pro'), findsNWidgets(4));

        await tester.tap(find.text('Set Up Prompts'));
        await tester.pumpAndSettle();

        final audioPrompt = savedConfigs
            .whereType<AiConfigPrompt>()
            .firstWhere((p) => p.name.contains('Audio'));
        expect(audioPrompt.defaultModelId, 'gemini-pro-only');
        // Audio prompt should use the fallback model name
        expect(audioPrompt.name, 'Audio Transcription - Gemini 2.5 Pro');
      });
    });

    group('Service Construction', () {
      test('should be const constructible', () {
        const service1 = GeminiPromptSetupService();
        const service2 = GeminiPromptSetupService();
        expect(service1, isA<GeminiPromptSetupService>());
        expect(service2, isA<GeminiPromptSetupService>());
      });

      test('should maintain consistent behavior across instances', () {
        const service1 = GeminiPromptSetupService();
        const service2 = GeminiPromptSetupService();
        expect(identical(service1, service2), isTrue);
      });
    });
  });
}
