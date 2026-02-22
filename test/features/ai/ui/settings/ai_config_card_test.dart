import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart'
    show aiConfigRepositoryProvider;
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/ui/settings/ai_config_card.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';

void main() {
  group('AiConfigCard', () {
    late AiConfig testProvider;
    late AiConfig testModel;
    late AiConfig testPrompt;
    late MockAiConfigRepository mockRepository;

    setUpAll(() {
      registerFallbackValue(
        AiConfig.inferenceProvider(
          id: 'fallback-id',
          name: 'Fallback Provider',
          inferenceProviderType: InferenceProviderType.genericOpenAi,
          apiKey: 'test-key',
          baseUrl: 'https://api.example.com',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
      );
    });

    setUp(() {
      mockRepository = MockAiConfigRepository();

      testProvider = AiConfig.inferenceProvider(
        id: 'test-provider-id',
        name: 'Test Anthropic Provider',
        description: 'Test provider for AI inference',
        inferenceProviderType: InferenceProviderType.anthropic,
        apiKey: 'test-api-key',
        baseUrl: 'https://api.anthropic.com',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

      testModel = AiConfig.model(
        id: 'test-model-id',
        name: 'Test Claude Model',
        description: 'Test model for AI inference',
        providerModelId: 'claude-3-5-sonnet-20241022',
        inferenceProviderId: 'test-provider-id',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        inputModalities: [Modality.text],
        outputModalities: [Modality.text],
        isReasoningModel: false,
      );

      testPrompt = AiConfig.prompt(
        id: 'test-prompt-id',
        name: 'Test AI Prompt',
        description: 'Test prompt for AI tasks',
        systemMessage: 'You are a helpful assistant.',
        userMessage: 'Please help with the following task.',
        defaultModelId: 'test-model-id',
        modelIds: ['test-model-id'],
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        useReasoning: false,
        requiredInputData: [InputDataType.task],
        aiResponseType: AiResponseType.taskSummary,
      );

      // Set up repository mock to return the test provider when requested
      when(() => mockRepository.getConfigById('test-provider-id'))
          .thenAnswer((_) async => testProvider as AiConfigInferenceProvider);

      // Set up repository mock to return the test model when requested
      when(() => mockRepository.getConfigById('test-model-id'))
          .thenAnswer((_) async => testModel as AiConfigModel);
    });

    Widget createTestWidget(AiConfig config, {bool showCapabilities = false}) {
      return MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ProviderScope(
            overrides: [
              aiConfigRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: AiConfigCard(
              config: config,
              onTap: () {},
              showCapabilities: showCapabilities,
            ),
          ),
        ),
      );
    }

    group('Provider configuration', () {
      testWidgets('displays provider name and icon',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(testProvider));

        expect(find.text(testProvider.name), findsOneWidget);
        expect(
            find.byIcon(Icons.auto_awesome), findsOneWidget); // Anthropic icon
      });

      testWidgets('displays provider description when available',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(testProvider));
        expect(find.text(testProvider.description!), findsOneWidget);
      });
    });

    group('Model configuration', () {
      testWidgets('displays model name and description',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(testModel));

        expect(find.text(testModel.name), findsOneWidget);
        expect(find.text(testModel.description!), findsOneWidget);
      });

      testWidgets('displays capabilities when showCapabilities is true',
          (WidgetTester tester) async {
        await tester
            .pumpWidget(createTestWidget(testModel, showCapabilities: true));

        // Should show capability indicators
        expect(
            find.byIcon(Icons.text_fields), findsOneWidget); // Text capability
      });
    });

    group('Prompt configuration', () {
      testWidgets('displays prompt name and description',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(testPrompt));

        expect(find.text(testPrompt.name), findsOneWidget);
        expect(find.text(testPrompt.description!), findsOneWidget);
      });
    });

    group('Prompt provider badge', () {
      testWidgets('displays provider name via default model lookup',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(testPrompt));
        await tester.pumpAndSettle();

        // Should show the provider name from the model's provider
        expect(find.text('Test Anthropic Provider'), findsOneWidget);
      });

      testWidgets('shows loading state while model loads',
          (WidgetTester tester) async {
        // Use a completer to control when the model lookup completes
        final modelCompleter = Completer<AiConfigModel?>();

        when(() => mockRepository.getConfigById('test-model-id'))
            .thenAnswer((_) => modelCompleter.future);

        await tester.pumpWidget(createTestWidget(testPrompt));
        await tester.pump();

        // Should show loading state
        expect(find.text('Loading...'), findsOneWidget);

        // Complete to clean up
        modelCompleter.complete(testModel as AiConfigModel);
        await tester.pumpAndSettle();
      });

      testWidgets('shows nothing when model lookup fails',
          (WidgetTester tester) async {
        when(() => mockRepository.getConfigById('test-model-id'))
            .thenThrow(Exception('Failed to load model'));

        await tester.pumpWidget(createTestWidget(testPrompt));
        await tester.pumpAndSettle();

        // Should not show provider name (graceful handling)
        expect(find.text('Test Anthropic Provider'), findsNothing);
      });

      testWidgets('shows nothing when model is not found',
          (WidgetTester tester) async {
        when(() => mockRepository.getConfigById('test-model-id'))
            .thenAnswer((_) async => null);

        await tester.pumpWidget(createTestWidget(testPrompt));
        await tester.pumpAndSettle();

        // Should not show provider badge when model not found
        expect(find.text('Test Anthropic Provider'), findsNothing);
      });

      testWidgets('shows provider badge with correct styling',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(testPrompt));
        await tester.pumpAndSettle();

        // Find the provider name text widget
        final providerText = find.text('Test Anthropic Provider');
        expect(providerText, findsOneWidget);

        // Verify it's inside a styled container with gradient decoration
        final containerFinder = find.ancestor(
          of: providerText,
          matching: find.byType(Container),
        );
        expect(containerFinder, findsWidgets);

        // Verify the container has a gradient decoration
        final containers = tester.widgetList<Container>(containerFinder);
        final hasGradientDecoration = containers.any((container) {
          final decoration = container.decoration;
          if (decoration is BoxDecoration) {
            return decoration.gradient is LinearGradient;
          }
          return false;
        });
        expect(hasGradientDecoration, isTrue,
            reason: 'Provider badge should have a LinearGradient decoration');
      });
    });

    group('Interaction', () {
      testWidgets('calls onTap when card is tapped',
          (WidgetTester tester) async {
        var tapped = false;

        final widget = MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ProviderScope(
              overrides: [
                aiConfigRepositoryProvider.overrideWithValue(mockRepository),
              ],
              child: AiConfigCard(
                config: testProvider,
                onTap: () => tapped = true,
              ),
            ),
          ),
        );

        await tester.pumpWidget(widget);
        await tester.tap(find.byType(AiConfigCard));

        expect(tapped, isTrue);
      });

      // Chevron presence covered in compact mode group tests
    });

    group('Compact mode', () {
      Widget createCompactWidget({
        required AiConfig config,
        bool compact = false,
      }) {
        return MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ProviderScope(
              overrides: [
                aiConfigRepositoryProvider.overrideWithValue(mockRepository),
              ],
              child: AiConfigCard(
                config: config,
                onTap: () {},
                compact: compact,
              ),
            ),
          ),
        );
      }

      testWidgets('shows chevron in normal mode', (WidgetTester tester) async {
        await tester.pumpWidget(createCompactWidget(
          config: testProvider,
        ));

        expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      });

      testWidgets('hides chevron in compact mode', (WidgetTester tester) async {
        await tester.pumpWidget(createCompactWidget(
          config: testProvider,
          compact: true,
        ));

        expect(find.byIcon(Icons.chevron_right), findsNothing);
      });

      testWidgets('shows name, description, and icon in both modes',
          (WidgetTester tester) async {
        for (final compact in [false, true]) {
          await tester.pumpWidget(createCompactWidget(
            config: testProvider,
            compact: compact,
          ));
          expect(find.text(testProvider.name), findsOneWidget);
          expect(find.text(testProvider.description!), findsOneWidget);
          expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
        }
      });

      testWidgets(
          'uses AnimatedContainer in normal mode but not in compact mode',
          (WidgetTester tester) async {
        // Normal mode has AnimatedContainer
        await tester.pumpWidget(createCompactWidget(config: testProvider));
        expect(find.byType(AnimatedContainer), findsOneWidget);

        // Compact mode does not
        await tester.pumpWidget(
          createCompactWidget(config: testProvider, compact: true),
        );
        expect(find.byType(AnimatedContainer), findsNothing);
      });

      testWidgets('onTap still works in compact mode',
          (WidgetTester tester) async {
        var cardTapped = false;

        final widget = MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ProviderScope(
              overrides: [
                aiConfigRepositoryProvider.overrideWithValue(mockRepository),
              ],
              child: AiConfigCard(
                config: testProvider,
                onTap: () => cardTapped = true,
                compact: true,
              ),
            ),
          ),
        );

        await tester.pumpWidget(widget);
        await tester.tap(find.text(testProvider.name));
        await tester.pump();

        // In compact mode, AiConfigCard's onTap callback should be invoked
        expect(cardTapped, isTrue);
        expect(find.text(testProvider.name), findsOneWidget);
      });

      testWidgets('capabilities still show in compact mode when enabled',
          (WidgetTester tester) async {
        final widget = MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ProviderScope(
              overrides: [
                aiConfigRepositoryProvider.overrideWithValue(mockRepository),
              ],
              child: AiConfigCard(
                config: testModel,
                onTap: () {},
                compact: true,
                showCapabilities: true,
              ),
            ),
          ),
        );

        await tester.pumpWidget(widget);

        // Capabilities should still display in compact mode
        expect(find.byIcon(Icons.text_fields), findsOneWidget);
      });
    });

    group('Provider type icons', () {
      testWidgets('displays correct icon for each provider type',
          (WidgetTester tester) async {
        final providerTypes = {
          InferenceProviderType.alibaba: Icons.cloud_queue,
          InferenceProviderType.anthropic: Icons.auto_awesome,
          InferenceProviderType.openAi: Icons.psychology,
          InferenceProviderType.gemini: Icons.diamond,
          InferenceProviderType.openRouter: Icons.hub,
          InferenceProviderType.ollama: Icons.computer,
          InferenceProviderType.genericOpenAi: Icons.cloud,
          InferenceProviderType.nebiusAiStudio: Icons.rocket_launch,
          InferenceProviderType.voxtral: Icons.graphic_eq,
        };

        for (final entry in providerTypes.entries) {
          final provider = AiConfig.inferenceProvider(
            id: 'test-${entry.key.name}',
            name: 'Test ${entry.key.name} Provider',
            inferenceProviderType: entry.key,
            apiKey: 'test-key',
            baseUrl: 'https://api.example.com',
            createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          );

          await tester.pumpWidget(createTestWidget(provider));
          expect(find.byIcon(entry.value), findsOneWidget);
        }
      });
    });

    group('Model family detection', () {
      testWidgets('correctly identifies model families from provider model ID',
          (WidgetTester tester) async {
        final modelTests = [
          ('gpt-4', Icons.psychology),
          ('claude-3-opus', Icons.auto_awesome), // matches 'claude' first
          ('claude-3-sonnet', Icons.auto_awesome), // matches 'claude' first
          ('claude-3-haiku', Icons.auto_awesome), // matches 'claude' first
          ('opus-model', Icons.workspace_premium), // only 'opus' pattern
          ('sonnet-only', Icons.edit_note), // only 'sonnet' pattern
          ('haiku-pure', Icons.flash_on), // only 'haiku' pattern
          ('gemini-pro', Icons.diamond),
          ('llama-2', Icons.smart_toy), // generic
        ];

        for (final test in modelTests) {
          final model = AiConfig.model(
            id: 'test-model-${test.$1}',
            name: 'Test Model',
            providerModelId: test.$1,
            inferenceProviderId: 'test-provider-id',
            createdAt: DateTime.fromMillisecondsSinceEpoch(0),
            inputModalities: [Modality.text],
            outputModalities: [Modality.text],
            isReasoningModel: false,
          );

          await tester.pumpWidget(createTestWidget(model));
          expect(find.byIcon(test.$2), findsOneWidget);
        }
      });

      testWidgets('correctly identifies model families from display name',
          (WidgetTester tester) async {
        final model = AiConfig.model(
          id: 'test-model',
          name: 'Claude Pro Model', // Family in name, not in provider ID
          providerModelId: 'custom-model-id',
          inferenceProviderId: 'test-provider-id',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          inputModalities: [Modality.text],
          outputModalities: [Modality.text],
          isReasoningModel: false,
        );

        await tester.pumpWidget(createTestWidget(model));
        expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
      });
    });

    group('Prompt type icons', () {
      testWidgets('displays correct icon based on input data type',
          (WidgetTester tester) async {
        final promptTests = <(List<InputDataType>, IconData)>[
          ([InputDataType.images], Icons.image),
          ([InputDataType.audioFiles], Icons.audiotrack),
          ([InputDataType.task], Icons.text_snippet),
          ([InputDataType.tasksList], Icons.text_snippet),
        ];

        for (final test in promptTests) {
          final prompt = AiConfig.prompt(
            id: 'test-prompt-${test.$1.first.name}',
            name: 'Test Prompt',
            systemMessage: 'System',
            userMessage: 'User',
            defaultModelId: 'model-id',
            modelIds: ['model-id'],
            createdAt: DateTime.fromMillisecondsSinceEpoch(0),
            useReasoning: false,
            requiredInputData: test.$1,
            aiResponseType: AiResponseType.taskSummary,
          );

          await tester.pumpWidget(createTestWidget(prompt));
          expect(find.byIcon(test.$2), findsOneWidget);
        }
      });
    });

    group('Capability indicators', () {
      testWidgets('shows all capability icons for multimodal model',
          (WidgetTester tester) async {
        final multimodalModel = AiConfig.model(
          id: 'multimodal-model',
          name: 'Multimodal Model',
          providerModelId: 'multimodal-1',
          inferenceProviderId: 'test-provider-id',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          inputModalities: [Modality.text, Modality.image, Modality.audio],
          outputModalities: [Modality.text],
          isReasoningModel: true,
        );

        await tester.pumpWidget(
            createTestWidget(multimodalModel, showCapabilities: true));

        // Check that all capability icons exist
        // Note: There will be other icons (main icon, chevron) so we just check existence
        expect(find.byIcon(Icons.text_fields), findsOneWidget);
        expect(find.byIcon(Icons.visibility), findsOneWidget);
        expect(find.byIcon(Icons.hearing), findsOneWidget);
        expect(find.byIcon(Icons.psychology), findsOneWidget); // reasoning
      });

      testWidgets('shows greyed out icons for unsupported capabilities',
          (WidgetTester tester) async {
        final textOnlyModel = AiConfig.model(
          id: 'text-only-model',
          name: 'Text Only Model',
          providerModelId: 'text-only-1',
          inferenceProviderId: 'test-provider-id',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          inputModalities: [Modality.text],
          outputModalities: [Modality.text],
          isReasoningModel: false,
        );

        await tester.pumpWidget(
            createTestWidget(textOnlyModel, showCapabilities: true));

        // Should show all capability icons but some are disabled
        expect(find.byIcon(Icons.text_fields), findsOneWidget);
        expect(find.byIcon(Icons.visibility), findsOneWidget);
        expect(find.byIcon(Icons.hearing), findsOneWidget);
      });
    });

    group('Provider name display', () {
      testWidgets('shows loading state while provider loads',
          (WidgetTester tester) async {
        // Use a completer to control when the future completes
        final completer = Completer<AiConfigInferenceProvider?>();

        // Mock repository to return the completer's future
        when(() => mockRepository.getConfigById('test-provider-id'))
            .thenAnswer((_) => completer.future);

        await tester.pumpWidget(createTestWidget(testModel));
        await tester.pump();

        expect(find.text('Loading...'), findsOneWidget);

        // Complete the future to clean up
        completer.complete(testProvider as AiConfigInferenceProvider);
        await tester.pumpAndSettle();
      });

      testWidgets('shows error state when provider fails to load',
          (WidgetTester tester) async {
        // Mock repository to throw error
        when(() => mockRepository.getConfigById('test-provider-id'))
            .thenThrow(Exception('Failed to load'));

        await tester.pumpWidget(createTestWidget(testModel));
        await tester.pumpAndSettle();

        expect(find.text('Error'), findsOneWidget);
      });

      testWidgets('shows Unknown when provider is null',
          (WidgetTester tester) async {
        // Mock repository to return null
        when(() => mockRepository.getConfigById('test-provider-id'))
            .thenAnswer((_) async => null);

        await tester.pumpWidget(createTestWidget(testModel));
        await tester.pumpAndSettle();

        expect(find.text('Unknown'), findsOneWidget);
      });
    });

    group('Theme variations', () {
      testWidgets('renders correctly in both light and dark themes',
          (WidgetTester tester) async {
        for (final theme in [ThemeData.light(), ThemeData.dark()]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: ProviderScope(
                  overrides: [
                    aiConfigRepositoryProvider
                        .overrideWithValue(mockRepository),
                  ],
                  child: AiConfigCard(
                    config: testProvider,
                    onTap: () {},
                  ),
                ),
              ),
            ),
          );
          expect(find.text(testProvider.name), findsOneWidget);
        }
      });
    });

    group('Edge cases', () {
      testWidgets('handles configs with no description and long text',
          (WidgetTester tester) async {
        // No description
        final configNoDesc = AiConfig.inferenceProvider(
          id: 'no-desc',
          name: 'No Description Provider',
          inferenceProviderType: InferenceProviderType.genericOpenAi,
          apiKey: 'test-key',
          baseUrl: 'https://api.example.com',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        );
        await tester.pumpWidget(createTestWidget(configNoDesc));
        expect(find.text(configNoDesc.name), findsOneWidget);

        // Long name
        const longName =
            'This is a very long provider name that should be truncated with ellipsis when displayed in the card';
        final longNameConfig = AiConfig.inferenceProvider(
          id: 'long-name',
          name: longName,
          inferenceProviderType: InferenceProviderType.genericOpenAi,
          apiKey: 'test-key',
          baseUrl: 'https://api.example.com',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        );
        await tester.pumpWidget(createTestWidget(longNameConfig));
        expect(find.text(longName), findsOneWidget);

        // Long description
        const longDesc =
            'This is a very long description that should be truncated with ellipsis when displayed in the card. It contains multiple sentences and should be limited to two lines maximum in normal mode.';
        final longDescConfig = AiConfig.inferenceProvider(
          id: 'long-desc',
          name: 'Provider',
          description: longDesc,
          inferenceProviderType: InferenceProviderType.genericOpenAi,
          apiKey: 'test-key',
          baseUrl: 'https://api.example.com',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        );
        await tester.pumpWidget(createTestWidget(longDescConfig));
        expect(find.text(longDesc), findsOneWidget);
      });
    });

    group('Animation', () {
      testWidgets('has animated container', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(testProvider));

        expect(find.byType(AnimatedContainer), findsOneWidget);

        final animatedContainer = tester.widget<AnimatedContainer>(
          find.byType(AnimatedContainer),
        );
        expect(animatedContainer.duration, const Duration(milliseconds: 300));
        expect(animatedContainer.curve, Curves.easeOutQuart);
      });
    });
  });
}
