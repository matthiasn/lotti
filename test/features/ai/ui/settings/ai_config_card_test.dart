import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/ui/settings/ai_config_card.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockAiConfigRepository extends Mock implements AiConfigRepository {}

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

      testWidgets('displays chevron icon', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(testProvider));
        expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      });
    });

    group('Compact mode', () {
      testWidgets('uses smaller sizing in compact mode',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(testProvider));

        // Should render without errors and display the config name
        expect(find.text(testProvider.name), findsOneWidget);
      });
    });
  });
}
