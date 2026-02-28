import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart'
    show aiConfigRepositoryProvider;
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_page.dart';
import 'package:lotti/features/ai/ui/widgets/profile_card.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../agents/test_utils.dart';

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
      when(() => mockRepository.watchProfiles())
          .thenAnswer((_) => Stream.value([]));
    });

    Widget createTestWidget() {
      return MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          padding: EdgeInsets.only(top: 47),
        ),
        child: MaterialApp(
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

    testWidgets('should display tab bar with four tabs',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Providers'), findsOneWidget);
      expect(find.text('Models'), findsOneWidget);
      expect(find.text('Prompts'), findsOneWidget);
      expect(find.text('Profiles'), findsOneWidget);
    });

    testWidgets('should switch between tabs', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Start on Providers tab - should see the test provider (only in config list, not in filter chips)
      expect(find.text('Anthropic Provider'), findsOneWidget);

      // Tap Models tab
      await tester.tap(find.text('Models'));
      await tester.pumpAndSettle();

      // Should see the test model
      expect(find.text('Claude Sonnet 3.5'), findsOneWidget);

      // Tap Prompts tab
      await tester.tap(find.text('Prompts'));
      await tester.pumpAndSettle();

      // Should see the test prompt (appears twice: once as filter chip, once as card)
      expect(find.text('Task Summary'), findsAtLeastNWidgets(1));
    });

    testWidgets('should filter configs with search',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Initially should see the provider (only in config list on Providers tab)
      expect(find.text('Anthropic Provider'), findsOneWidget);

      // Enter search text that doesn't match
      await tester.enterText(find.byType(TextField), 'nonexistent');
      await tester.pump();

      // Wait for debounce timer (300ms + buffer)
      await tester.pump(const Duration(milliseconds: 350));

      // Should not see the provider anymore
      expect(find.text('Anthropic Provider'), findsNothing);

      // Clear search
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();

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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

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
      await tester.pump();

      // Clear button should appear
      expect(find.byIcon(Icons.clear_rounded), findsOneWidget);

      // Tap clear button
      await tester.tap(find.byIcon(Icons.clear_rounded));
      await tester.pump();

      // Search field should be empty
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, '');
    });

    testWidgets('should handle tab controller properly',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Verify we're on the right tab (Providers tab - only in config list)
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
      final widget = MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          padding: EdgeInsets.only(top: 47),
        ),
        child: MaterialApp(
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
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      // Should render without errors
      expect(find.text('AI Settings'), findsOneWidget);
    });

    testWidgets('should handle theme correctly in dark mode',
        (WidgetTester tester) async {
      final widget = MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          padding: EdgeInsets.only(top: 47),
        ),
        child: MaterialApp(
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
      await tester.pump();

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

      // Should see both prompts initially (response type chips also show these names)
      expect(find.text('Task Summary'), findsAtLeastNWidgets(1));
      expect(find.text('Image Analysis'), findsAtLeastNWidgets(1));

      // Search for "Task"
      await tester.enterText(find.byType(TextField), 'Task');
      await tester.pump();

      // Wait for debounce timer
      await tester.pump(const Duration(milliseconds: 350));

      // Task Summary appears in filter chip, Image Analysis prompt card should be filtered out
      // but Image Analysis filter chip still appears
      expect(find.text('Task Summary'), findsAtLeastNWidgets(1));
      // Image Analysis filter chip still visible, but prompt card should be gone
      expect(
          find.text('Image Analysis'), findsOneWidget); // Just the filter chip
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

      // Should see both providers initially (only in config list on Providers tab)
      expect(find.text('Anthropic Provider'), findsOneWidget);
      expect(find.text('OpenAI Provider'), findsOneWidget);

      // Search for "Anthropic"
      await tester.enterText(find.byType(TextField), 'Anthropic');
      await tester.pump();

      // Wait for debounce timer
      await tester.pump(const Duration(milliseconds: 350));

      // Should only see Anthropic provider
      expect(find.text('Anthropic Provider'), findsOneWidget);
      expect(find.text('OpenAI Provider'), findsNothing);
    });

    testWidgets('should handle back navigation', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Verify back button exists (SettingsPageHeader uses chevron_left)
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);

      // Note: Cannot tap back button in test without mocking NavService in GetIt
      // The back button functionality is tested in integration tests
    });

    testWidgets('should show app bar title animation',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Should have SettingsPageHeader (which contains a SliverAppBar)
      expect(find.byType(SliverAppBar), findsWidgets);

      // Title should be visible
      expect(find.text('AI Settings'), findsOneWidget);
    });

    group('selection mode', () {
      testWidgets('should show Select chip on Prompts tab',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Switch to Prompts tab
        await tester.tap(find.text('Prompts'));
        await tester.pumpAndSettle();

        // Should see the Select chip
        expect(find.text('Select'), findsOneWidget);
      });

      testWidgets('should not show Select chip on Models tab',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Switch to Models tab
        await tester.tap(find.text('Models'));
        await tester.pumpAndSettle();

        // Should NOT see the Select chip
        expect(find.text('Select'), findsNothing);
      });

      testWidgets('should not show Select chip on Providers tab',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Stay on Providers tab (default)
        // Should NOT see the Select chip
        expect(find.text('Select'), findsNothing);
      });

      testWidgets('should enable selection mode when Select chip is tapped',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Switch to Prompts tab
        await tester.tap(find.text('Prompts'));
        await tester.pumpAndSettle();

        // Tap Select chip
        final selectChip = find.ancestor(
          of: find.text('Select'),
          matching: find.byType(FilterChip),
        );
        await tester.tap(selectChip);
        await tester.pump();

        // Select chip should now show selected state (checkbox icon)
        expect(find.byIcon(Icons.check_box), findsOneWidget);
      });

      testWidgets(
          'should show checkbox indicators when selection mode is active',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Switch to Prompts tab
        await tester.tap(find.text('Prompts'));
        await tester.pumpAndSettle();

        // Enable selection mode
        final selectChip = find.ancestor(
          of: find.text('Select'),
          matching: find.byType(FilterChip),
        );
        await tester.tap(selectChip);
        await tester.pump();

        // The sliver uses AnimatedContainer as custom checkbox (not standard icon)
        // When selection mode is on, the Select chip shows checked icon
        expect(find.byIcon(Icons.check_box), findsOneWidget);

        // And the prompt card should still be visible in compact mode
        expect(find.text('Task Summary'), findsAtLeastNWidgets(1));
      });

      testWidgets('should show Add Prompt FAB when no items are selected',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Switch to Prompts tab
        await tester.tap(find.text('Prompts'));
        await tester.pumpAndSettle();

        // Enable selection mode
        final selectChip = find.ancestor(
          of: find.text('Select'),
          matching: find.byType(FilterChip),
        );
        await tester.tap(selectChip);
        await tester.pump();

        // FAB should still show "Add Prompt" when selection mode is on but nothing selected
        expect(find.text('Add Prompt'), findsOneWidget);
      });

      testWidgets('should show delete FAB when items are selected',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Switch to Prompts tab
        await tester.tap(find.text('Prompts'));
        await tester.pumpAndSettle();

        // Enable selection mode
        final selectChip = find.ancestor(
          of: find.text('Select'),
          matching: find.byType(FilterChip),
        );
        await tester.tap(selectChip);
        await tester.pump();

        // In selection mode, tap on the prompt card text to select it
        // (the sliver wraps cards and handles tap for selection)
        // Find the prompt card - in selection mode it's rendered inside compact AiConfigCard
        final promptCardFinders = find.text('Task Summary');
        // The first one is the filter chip, the card is rendered later
        // Assert the card exists before attempting to tap
        expect(
          promptCardFinders.evaluate().length,
          greaterThan(1),
          reason: 'Task Summary prompt card should be present',
        );
        await tester.tap(promptCardFinders.last);
        await tester.pump();

        // FAB should now show delete icon
        expect(find.byIcon(Icons.delete_rounded), findsOneWidget);
        // And the prompt should show check icon (selected)
        expect(find.byIcon(Icons.check), findsOneWidget);
      });

      testWidgets(
          'should show delete confirmation dialog when delete FAB is tapped',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Switch to Prompts tab
        await tester.tap(find.text('Prompts'));
        await tester.pumpAndSettle();

        // Enable selection mode
        final selectChip = find.ancestor(
          of: find.text('Select'),
          matching: find.byType(FilterChip),
        );
        await tester.tap(selectChip);
        await tester.pump();

        // Select a prompt by tapping on the card text
        final promptCardFinders = find.text('Task Summary');
        // Assert the card exists before attempting to tap
        expect(
          promptCardFinders.evaluate().length,
          greaterThan(1),
          reason: 'Task Summary prompt card should be present',
        );
        await tester.tap(promptCardFinders.last);
        await tester.pump();

        // Tap delete FAB
        final deleteFab = find.byType(FloatingActionButton);
        await tester.tap(deleteFab);
        await tester.pump();

        // Should show confirmation dialog with correct title
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('Delete Selected Prompts'), findsOneWidget);
      });

      testWidgets('should dismiss dialog and not delete when Cancel is tapped',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Switch to Prompts tab
        await tester.tap(find.text('Prompts'));
        await tester.pumpAndSettle();

        // Enable selection mode and select a prompt
        final selectChip = find.ancestor(
          of: find.text('Select'),
          matching: find.byType(FilterChip),
        );
        await tester.tap(selectChip);
        await tester.pump();

        final promptCardFinders = find.text('Task Summary');
        // Assert the card exists before attempting to tap
        expect(
          promptCardFinders.evaluate().length,
          greaterThan(1),
          reason: 'Task Summary prompt card should be present',
        );
        await tester.tap(promptCardFinders.last);
        await tester.pump();

        // Tap delete FAB
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pump();

        // Tap Cancel button
        await tester.tap(find.text('Cancel'));
        await tester.pump();

        // Dialog should be dismissed
        expect(find.byType(AlertDialog), findsNothing);

        // Selection should still be active
        expect(find.byIcon(Icons.delete_rounded), findsOneWidget);
      });

      testWidgets('should delete selected prompts when Delete is confirmed',
          (WidgetTester tester) async {
        // Set up mock to handle delete
        when(() => mockRepository.deleteConfig('test-prompt'))
            .thenAnswer((_) async {});

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Switch to Prompts tab
        await tester.tap(find.text('Prompts'));
        await tester.pumpAndSettle();

        // Enable selection mode and select a prompt
        final selectChip = find.ancestor(
          of: find.text('Select'),
          matching: find.byType(FilterChip),
        );
        await tester.tap(selectChip);
        await tester.pump();

        final promptCardFinders = find.text('Task Summary');
        // Assert the card exists before attempting to tap
        expect(
          promptCardFinders.evaluate().length,
          greaterThan(1),
          reason: 'Task Summary prompt card should be present',
        );
        await tester.tap(promptCardFinders.last);
        await tester.pump();

        // Tap delete FAB
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pump();

        // Tap Delete button to confirm
        await tester.tap(find.text('Delete'));
        await tester.pump();

        // Dialog should be dismissed
        expect(find.byType(AlertDialog), findsNothing);

        // Selection mode should be exited (Add Prompt FAB should return)
        expect(find.text('Add Prompt'), findsOneWidget);
      });

      testWidgets('should exit selection mode when Select chip is toggled off',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Switch to Prompts tab
        await tester.tap(find.text('Prompts'));
        await tester.pumpAndSettle();

        // Enable selection mode
        final selectChip = find.ancestor(
          of: find.text('Select'),
          matching: find.byType(FilterChip),
        );
        await tester.tap(selectChip);
        await tester.pump();

        // Select a prompt
        final promptCardFinders = find.text('Task Summary');
        // Assert the card exists before attempting to tap
        expect(
          promptCardFinders.evaluate().length,
          greaterThan(1),
          reason: 'Task Summary prompt card should be present',
        );
        await tester.tap(promptCardFinders.last);
        await tester.pump();

        // Should be in selection mode with items selected
        expect(find.byIcon(Icons.delete_rounded), findsOneWidget);

        // Toggle off selection mode
        await tester.tap(selectChip);
        await tester.pump();

        // Should exit selection mode and show Add Prompt FAB
        expect(find.text('Add Prompt'), findsOneWidget);
      });

      testWidgets('should maintain selection when switching tabs and back',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Switch to Prompts tab and enable selection
        await tester.tap(find.text('Prompts'));
        await tester.pumpAndSettle();

        final selectChip = find.ancestor(
          of: find.text('Select'),
          matching: find.byType(FilterChip),
        );
        await tester.tap(selectChip);
        await tester.pump();

        // Select a prompt
        final promptCardFinders = find.text('Task Summary');
        // Assert the card exists before attempting to tap
        expect(
          promptCardFinders.evaluate().length,
          greaterThan(1),
          reason: 'Task Summary prompt card should be present',
        );
        await tester.tap(promptCardFinders.last);
        await tester.pump();

        // Should have delete FAB with selected item
        expect(find.byIcon(Icons.delete_rounded), findsOneWidget);
        expect(find.byIcon(Icons.check), findsOneWidget); // Selected indicator

        // Switch to Models tab (use Tab widget which is more reliable)
        final modelsTab = find.text('Models');
        await tester.tap(modelsTab);
        await tester.pumpAndSettle();

        // Verify we're on Models tab by checking for model content
        expect(find.text('Claude Sonnet 3.5'), findsOneWidget);

        // Switch back to Prompts tab
        final promptsTab = find.text('Prompts');
        await tester.tap(promptsTab);
        await tester.pumpAndSettle();

        // Selection state should be maintained (delete FAB and check icon)
        expect(find.byIcon(Icons.delete_rounded), findsOneWidget);
        expect(find.byIcon(Icons.check), findsOneWidget);
      });
    });

    group('profiles tab', () {
      testWidgets('should show profile cards when profiles exist',
          (WidgetTester tester) async {
        final profiles = [
          testInferenceProfile(id: 'p1', name: 'Gemini Flash'),
          testInferenceProfile(id: 'p2', name: 'Local Ollama'),
        ];
        when(() => mockRepository.watchProfiles())
            .thenAnswer((_) => Stream.value(profiles));

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Switch to Profiles tab
        await tester.tap(find.text('Profiles'));
        await tester.pumpAndSettle();

        expect(find.text('Gemini Flash'), findsOneWidget);
        expect(find.text('Local Ollama'), findsOneWidget);
        expect(find.byType(ProfileCard), findsNWidgets(2));
      });

      testWidgets('should show empty state when no profiles exist',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Switch to Profiles tab (watchProfiles returns [] from setUp)
        await tester.tap(find.text('Profiles'));
        await tester.pumpAndSettle();

        expect(find.text('No inference profiles yet'), findsOneWidget);
        expect(find.byIcon(Icons.tune), findsOneWidget);
      });

      testWidgets('should filter profiles by search query',
          (WidgetTester tester) async {
        final profiles = [
          testInferenceProfile(id: 'p1', name: 'Gemini Flash'),
          testInferenceProfile(id: 'p2', name: 'Local Ollama'),
        ];
        when(() => mockRepository.watchProfiles())
            .thenAnswer((_) => Stream.value(profiles));

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Switch to Profiles tab
        await tester.tap(find.text('Profiles'));
        await tester.pumpAndSettle();

        // Both visible initially
        expect(find.text('Gemini Flash'), findsOneWidget);
        expect(find.text('Local Ollama'), findsOneWidget);

        // Search for "Gemini"
        await tester.enterText(find.byType(TextField), 'Gemini');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Only Gemini should be visible
        expect(find.text('Gemini Flash'), findsOneWidget);
        expect(find.text('Local Ollama'), findsNothing);
      });

      testWidgets(
          'should show no-items-found message when search has no results',
          (WidgetTester tester) async {
        final profiles = [
          testInferenceProfile(id: 'p1', name: 'Gemini Flash'),
        ];
        when(() => mockRepository.watchProfiles())
            .thenAnswer((_) => Stream.value(profiles));

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Switch to Profiles tab
        await tester.tap(find.text('Profiles'));
        await tester.pumpAndSettle();

        // Search for something that doesn't match
        await tester.enterText(find.byType(TextField), 'zzzznonexistent');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Should show "No items found" (not "No inference profiles yet")
        expect(find.text('No items found'), findsOneWidget);
      });

      testWidgets('should show Add Profile FAB on profiles tab',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Switch to Profiles tab
        await tester.tap(find.text('Profiles'));
        await tester.pumpAndSettle();

        expect(find.text('Add Profile'), findsOneWidget);
        expect(find.byType(FloatingActionButton), findsOneWidget);
      });

      testWidgets('should show loading state for profiles',
          (WidgetTester tester) async {
        when(() => mockRepository.watchProfiles())
            .thenAnswer((_) => const Stream.empty());

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Switch to Profiles tab
        await tester.tap(find.text('Profiles'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('should show error state for profiles',
          (WidgetTester tester) async {
        when(() => mockRepository.watchProfiles())
            .thenAnswer((_) => Stream.error('Profile error'));

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Switch to Profiles tab
        await tester.tap(find.text('Profiles'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Profile error'), findsOneWidget);
        expect(find.text('RETRY'), findsOneWidget);
      });

      testWidgets('should show desktop-only chip in profile card',
          (WidgetTester tester) async {
        final profiles = [
          testInferenceProfile(
            id: 'p1',
            name: 'Local Profile',
            desktopOnly: true,
          ),
        ];
        when(() => mockRepository.watchProfiles())
            .thenAnswer((_) => Stream.value(profiles));

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Switch to Profiles tab
        await tester.tap(find.text('Profiles'));
        await tester.pumpAndSettle();

        expect(find.text('Desktop Only'), findsOneWidget);
      });

      testWidgets('should not show Select chip on Profiles tab',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Switch to Profiles tab
        await tester.tap(find.text('Profiles'));
        await tester.pumpAndSettle();

        expect(find.text('Select'), findsNothing);
      });
    });
  });
}
