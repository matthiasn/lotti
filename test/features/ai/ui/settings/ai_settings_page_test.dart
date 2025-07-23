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

      // Wait for debounce timer (300ms + buffer)
      await tester.pump(const Duration(milliseconds: 350));

      // Should not see the provider anymore
      expect(find.text('Anthropic Provider'), findsNothing);

      // Clear search
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();

      // Wait for debounce timer (300ms + buffer)
      await tester.pump(const Duration(milliseconds: 350));

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

      // Should see capability filter chips (without the old "Capabilities:" label)
      expect(find.text('Vision'), findsOneWidget);
      expect(find.text('Audio'), findsOneWidget);
      expect(find.text('Text'), findsOneWidget);
      expect(find.text('Reasoning'), findsOneWidget);
    });

    testWidgets('should display floating action button with correct label',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Should see "Add Provider" button on Providers tab
      expect(find.text('Add Provider'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);

      // Switch to Models tab
      await tester.tap(find.text('Models'));
      await tester.pumpAndSettle();

      // Should see "Add Model" button
      expect(find.text('Add Model'), findsOneWidget);

      // Switch to Prompts tab
      await tester.tap(find.text('Prompts'));
      await tester.pumpAndSettle();

      // Should see "Add Prompt" button
      expect(find.text('Add Prompt'), findsOneWidget);
    });

    testWidgets('should have tappable floating action button',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Verify floating action button exists and is tappable
      final fabFinder = find.byType(FloatingActionButton);
      expect(fabFinder, findsOneWidget);

      // Test that it's enabled (can be tapped without throwing)
      final fab = tester.widget<FloatingActionButton>(fabFinder);
      expect(fab.onPressed, isNotNull);

      // Note: We don't actually tap here to avoid navigation issues in test context
      // In a real integration test with proper routing, we would test navigation
    });

    testWidgets('should show loading state', (WidgetTester tester) async {
      // Mock repository to return loading stream
      when(() =>
              mockRepository.watchConfigsByType(AiConfigType.inferenceProvider))
          .thenAnswer((_) => const Stream.empty());

      await tester.pumpWidget(createTestWidget());
      await tester.pump(); // Don't settle to keep loading state

      // Should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should show error state with retry',
        (WidgetTester tester) async {
      // Mock repository to return error
      when(() =>
              mockRepository.watchConfigsByType(AiConfigType.inferenceProvider))
          .thenAnswer((_) => Stream.error('Test error'));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Should show error message
      expect(find.textContaining('Test error'), findsOneWidget);
      expect(find.text('RETRY'), findsOneWidget);
    });

    testWidgets('should clear search when clear button is tapped',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Enter search text
      await tester.enterText(find.byType(TextField), 'test search');
      await tester.pumpAndSettle();

      // Clear button should appear
      expect(find.byIcon(Icons.clear_rounded), findsOneWidget);

      // Tap clear button
      await tester.tap(find.byIcon(Icons.clear_rounded));
      await tester.pumpAndSettle();

      // Search field should be empty
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, '');
    });

    testWidgets('should handle tab controller properly',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Verify we're on the right tab
      expect(find.text('Anthropic Provider'), findsOneWidget);

      // Switch tabs programmatically
      await tester.tap(find.text('Models'));
      await tester.pumpAndSettle();

      // Should be on models tab
      expect(find.text('Claude Sonnet 3.5'), findsOneWidget);
    });

    testWidgets('should show capability indicators on model cards',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Switch to Models tab
      await tester.tap(find.text('Models'));
      await tester.pumpAndSettle();

      // Should show capability icons for the model
      expect(find.byIcon(Icons.text_fields),
          findsAtLeastNWidgets(1)); // Text capability
      expect(find.byIcon(Icons.visibility),
          findsAtLeastNWidgets(1)); // Vision capability
    });

    testWidgets('should handle theme correctly in light mode',
        (WidgetTester tester) async {
      final widget = MaterialApp(
        theme: ThemeData.light(),
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

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      // Should render without errors
      expect(find.text('AI Settings'), findsOneWidget);
    });

    testWidgets('should handle theme correctly in dark mode',
        (WidgetTester tester) async {
      final widget = MaterialApp(
        theme: ThemeData.dark(),
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

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      // Should render without errors
      expect(find.text('AI Settings'), findsOneWidget);
    });

    testWidgets('should properly dispose controllers',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Navigate away to dispose the page
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Text('Different Page')),
      ));
      await tester.pumpAndSettle();

      // Should have disposed without errors
      expect(find.text('Different Page'), findsOneWidget);
    });

    testWidgets('should handle config tap navigation',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap on a config card - this triggers navigation
      await tester.tap(find.text('Anthropic Provider'));

      // Don't use pumpAndSettle as navigation will fail in test context
      // This test verifies that the tap handler is attached and doesn't crash
    });

    testWidgets('should filter models by capability',
        (WidgetTester tester) async {
      // Add another model without vision capability
      final textOnlyModel = AiConfig.model(
        id: 'text-only-model',
        name: 'Text Only Model',
        providerModelId: 'text-model-1',
        inferenceProviderId: 'anthropic-provider',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        inputModalities: [Modality.text],
        outputModalities: [Modality.text],
        isReasoningModel: false,
      );

      when(() => mockRepository.watchConfigsByType(AiConfigType.model))
          .thenAnswer((_) => Stream.value([testConfigs[1], textOnlyModel]));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Switch to Models tab
      await tester.tap(find.text('Models'));
      await tester.pumpAndSettle();

      // Should see both models initially
      expect(find.text('Claude Sonnet 3.5'), findsOneWidget);
      expect(find.text('Text Only Model'), findsOneWidget);

      // Tap Vision filter
      await tester.tap(find.text('Vision'));
      await tester.pumpAndSettle();

      // Should only see model with vision capability
      expect(find.text('Claude Sonnet 3.5'), findsOneWidget);
      expect(find.text('Text Only Model'), findsNothing);
    });

    testWidgets('should filter prompts with search',
        (WidgetTester tester) async {
      // Add another prompt with different response type
      final imagePrompt = AiConfig.prompt(
        id: 'image-prompt',
        name: 'Image Analysis',
        systemMessage: 'Analyze images',
        userMessage: 'Analyze this image',
        defaultModelId: 'claude-model',
        modelIds: ['claude-model'],
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        useReasoning: false,
        requiredInputData: [InputDataType.images],
        aiResponseType: AiResponseType.imageAnalysis,
      );

      when(() => mockRepository.watchConfigsByType(AiConfigType.prompt))
          .thenAnswer((_) => Stream.value([testConfigs[2], imagePrompt]));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Switch to Prompts tab
      await tester.tap(find.text('Prompts'));
      await tester.pumpAndSettle();

      // Should see both prompts initially
      expect(find.text('Task Summary'), findsOneWidget);
      expect(find.text('Image Analysis'), findsOneWidget);

      // Search for "Task"
      await tester.enterText(find.byType(TextField), 'Task');
      await tester.pumpAndSettle();

      // Wait for debounce timer
      await tester.pump(const Duration(milliseconds: 350));

      // Should only see task summary prompt
      expect(find.text('Task Summary'), findsOneWidget);
      expect(find.text('Image Analysis'), findsNothing);
    });

    testWidgets('should filter providers with search',
        (WidgetTester tester) async {
      // Add another provider with different type
      final openAiProvider = AiConfig.inferenceProvider(
        id: 'openai-provider',
        name: 'OpenAI Provider',
        inferenceProviderType: InferenceProviderType.openAi,
        apiKey: 'test-key',
        baseUrl: 'https://api.openai.com',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

      when(() =>
              mockRepository.watchConfigsByType(AiConfigType.inferenceProvider))
          .thenAnswer((_) => Stream.value([testConfigs[0], openAiProvider]));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Should see both providers initially
      expect(find.text('Anthropic Provider'), findsOneWidget);
      expect(find.text('OpenAI Provider'), findsOneWidget);

      // Search for "Anthropic"
      await tester.enterText(find.byType(TextField), 'Anthropic');
      await tester.pumpAndSettle();

      // Wait for debounce timer
      await tester.pump(const Duration(milliseconds: 350));

      // Should only see Anthropic provider
      expect(find.text('Anthropic Provider'), findsOneWidget);
      expect(find.text('OpenAI Provider'), findsNothing);
    });

    testWidgets('should handle back navigation', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Navigation should be triggered (but won't actually navigate in test)
    });

    testWidgets('should show app bar title animation',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Should have SliverAppBar with FlexibleSpaceBar
      expect(find.byType(SliverAppBar), findsOneWidget);
      expect(find.byType(FlexibleSpaceBar), findsOneWidget);

      // Title should be visible
      expect(find.text('AI Settings'), findsOneWidget);
    });
  });
}
