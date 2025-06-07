import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_page.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockAiConfigRepository extends Mock implements AiConfigRepository {}

void main() {
  group('AiSettingsPage', () {
    late MockAiConfigRepository mockRepository;
    late List<AiConfig> testConfigs;

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

      testConfigs = [
        AiConfig.inferenceProvider(
          id: 'anthropic-provider',
          name: 'Anthropic Provider',
          description: 'Claude models provider',
          inferenceProviderType: InferenceProviderType.anthropic,
          apiKey: 'test-key',
          baseUrl: 'https://api.anthropic.com',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
        AiConfig.model(
          id: 'claude-model',
          name: 'Claude Sonnet 3.5',
          description: 'Fast and capable model',
          providerModelId: 'claude-3-5-sonnet-20241022',
          inferenceProviderId: 'anthropic-provider',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          inputModalities: [Modality.text, Modality.image],
          outputModalities: [Modality.text],
          isReasoningModel: false,
        ),
        AiConfig.prompt(
          id: 'test-prompt',
          name: 'Task Summary',
          description: 'Generate task summaries',
          systemMessage: 'You are a helpful assistant.',
          userMessage: 'Summarize this task: {{task}}',
          defaultModelId: 'claude-model',
          modelIds: ['claude-model'],
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          useReasoning: false,
          requiredInputData: [InputDataType.task],
          aiResponseType: AiResponseType.taskSummary,
        ),
      ];

      when(() =>
              mockRepository.watchConfigsByType(AiConfigType.inferenceProvider))
          .thenAnswer((_) => Stream.value([testConfigs[0]]));
      when(() => mockRepository.watchConfigsByType(AiConfigType.model))
          .thenAnswer((_) => Stream.value([testConfigs[1]]));
      when(() => mockRepository.watchConfigsByType(AiConfigType.prompt))
          .thenAnswer((_) => Stream.value([testConfigs[2]]));
      when(() => mockRepository.getConfigById('anthropic-provider'))
          .thenAnswer((_) async => testConfigs[0] as AiConfigInferenceProvider);
    });

    Widget createTestWidget() {
      return MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: ProviderScope(
          overrides: [
            aiConfigRepositoryProvider.overrideWithValue(mockRepository),
          ],
          child: const AiSettingsPage(),
        ),
      );
    }

    testWidgets('should display title and search bar',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('AI Settings'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search AI configurations...'), findsOneWidget);
    });

    testWidgets('should display tab bar with three tabs',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Providers'), findsOneWidget);
      expect(find.text('Models'), findsOneWidget);
      expect(find.text('Prompts'), findsOneWidget);
    });

    testWidgets('should switch between tabs', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Start on Providers tab - should see the test provider
      expect(find.text('Anthropic Provider'), findsOneWidget);

      // Tap Models tab
      await tester.tap(find.text('Models'));
      await tester.pumpAndSettle();

      // Should see the test model
      expect(find.text('Claude Sonnet 3.5'), findsOneWidget);

      // Tap Prompts tab
      await tester.tap(find.text('Prompts'));
      await tester.pumpAndSettle();

      // Should see the test prompt
      expect(find.text('Task Summary'), findsOneWidget);
    });

    testWidgets('should filter configs with search',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Initially should see the provider
      expect(find.text('Anthropic Provider'), findsOneWidget);

      // Enter search text that doesn't match
      await tester.enterText(find.byType(TextField), 'nonexistent');
      await tester.pumpAndSettle();

      // Should not see the provider anymore
      expect(find.text('Anthropic Provider'), findsNothing);

      // Clear search
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();

      // Should see the provider again
      expect(find.text('Anthropic Provider'), findsOneWidget);
    });

    testWidgets('should display capability filters on Models tab',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Switch to Models tab
      await tester.tap(find.text('Models'));
      await tester.pumpAndSettle();

      // Should see capability filter options
      expect(find.text('Capabilities:'), findsOneWidget);
      expect(find.text('Vision'), findsOneWidget);
      expect(find.text('Audio'), findsOneWidget);
    });
  });
}
