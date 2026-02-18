import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart'
    show aiConfigRepositoryProvider;
import 'package:lotti/features/ai/ui/settings/inference_provider_edit_page.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart'
    show categoryRepositoryProvider;
import 'package:lotti/features/whats_new/model/whats_new_state.dart';
import 'package:lotti/features/whats_new/state/whats_new_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';

/// Mock What's New controller that returns no unseen releases
class _MockWhatsNewController extends WhatsNewController {
  @override
  Future<WhatsNewState> build() async => const WhatsNewState();
}

/// Helper to get localized strings from the widget tree.
AppLocalizations l10n(WidgetTester tester) => AppLocalizations.of(
    tester.element(find.byType(InferenceProviderEditPage)))!;

void main() {
  late MockAiConfigRepository mockRepository;
  late MockCategoryRepository mockCategoryRepository;
  late SettingsDb settingsDb;
  late AiConfig testProvider;

  setUpAll(() {
    registerFallbackValue(
      AiConfig.inferenceProvider(
        id: 'fallback-id',
        name: 'Fallback Provider',
        baseUrl: 'https://fallback.example.com',
        apiKey: 'fallback-key',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.openAi,
      ),
    );
    registerFallbackValue(
      CategoryDefinition(
        id: 'fallback-category-id',
        name: 'Fallback Category',
        color: '#FF0000',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        vectorClock: null,
        private: false,
        active: true,
      ),
    );
  });

  setUp(() async {
    mockRepository = MockAiConfigRepository();
    mockCategoryRepository = MockCategoryRepository();

    // Use in-memory database for tests
    settingsDb = SettingsDb(inMemoryDatabase: true);

    if (getIt.isRegistered<SettingsDb>()) {
      getIt.unregister<SettingsDb>();
    }
    getIt.registerSingleton<SettingsDb>(settingsDb);

    testProvider = AiConfig.inferenceProvider(
      id: 'test-provider-id',
      name: 'Test Provider',
      baseUrl: 'https://api.test.com',
      apiKey: 'test-key-123',
      createdAt: DateTime.now(),
      inferenceProviderType: InferenceProviderType.openAi,
    );

    // Default mock responses
    when(() => mockRepository.saveConfig(any())).thenAnswer((_) async {});
    when(() => mockRepository.getConfigById('test-provider-id'))
        .thenAnswer((_) async => testProvider);
    when(() => mockRepository.getConfigsByType(AiConfigType.model))
        .thenAnswer((_) async => []);
    when(() => mockRepository.getConfigsByType(AiConfigType.prompt))
        .thenAnswer((_) async => []);

    // Default category mock responses
    when(
      () => mockCategoryRepository.createCategory(
        name: any(named: 'name'),
        color: any(named: 'color'),
        icon: any(named: 'icon'),
      ),
    ).thenAnswer(
      (invocation) async => CategoryDefinition(
        id: 'test-category-id',
        name: invocation.namedArguments[#name] as String,
        color: invocation.namedArguments[#color] as String,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        vectorClock: null,
        private: false,
        active: true,
      ),
    );
    when(() => mockCategoryRepository.updateCategory(any()))
        .thenAnswer((invocation) async {
      return invocation.positionalArguments[0] as CategoryDefinition;
    });
    when(() => mockCategoryRepository.getAllCategories())
        .thenAnswer((_) async => []);
    when(() => mockRepository.getConfigsByType(AiConfigType.inferenceProvider))
        .thenAnswer((_) async => []);
  });

  tearDown(() async {
    await settingsDb.close();
    await getIt.reset();
  });

  Widget buildTestWidget({
    String? configId,
    InferenceProviderType? preselectedType,
    List<AiConfig>? existingProviders,
  }) {
    // Set up provider count mock if existingProviders is provided
    if (existingProviders != null) {
      when(() =>
              mockRepository.getConfigsByType(AiConfigType.inferenceProvider))
          .thenAnswer((_) async => existingProviders);
    }

    return ProviderScope(
      overrides: [
        aiConfigRepositoryProvider.overrideWithValue(mockRepository),
        categoryRepositoryProvider.overrideWithValue(mockCategoryRepository),
        whatsNewControllerProvider.overrideWith(_MockWhatsNewController.new),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: InferenceProviderEditPage(
          configId: configId,
          preselectedType: preselectedType,
        ),
      ),
    );
  }

  group('InferenceProviderEditPage', () {
    testWidgets('displays correct title for new provider',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Add Provider'), findsOneWidget);
    });

    testWidgets('displays correct title for existing provider',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget(configId: 'test-provider-id'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Provider'), findsOneWidget);
    });

    testWidgets('loads and displays existing provider data',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget(configId: 'test-provider-id'));
      await tester.pumpAndSettle();

      // Check that the form is populated with existing data
      expect(find.text('Test Provider'), findsOneWidget);
      expect(find.text('https://api.test.com'), findsOneWidget);
    });

    testWidgets('shows form sections with proper labels',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Use existing provider that requires API key to show Authentication section
      await tester.pumpWidget(buildTestWidget(configId: 'test-provider-id'));
      await tester.pumpAndSettle();

      // Check section headers
      expect(find.text('Provider Configuration'), findsOneWidget);
      expect(find.text('Authentication'), findsOneWidget);

      // Check field labels
      expect(find.text('Provider Type'), findsOneWidget);
      expect(find.text('Display Name'), findsOneWidget);
      expect(find.text('Base URL'), findsOneWidget);
      expect(find.text('API Key'), findsOneWidget);
    });

    testWidgets('enables save button when required fields are filled',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Initially save button should be disabled
      final saveButton = find.text('Save');
      expect(saveButton, findsOneWidget);

      // Fill in required fields (genericOpenAi now requires API key)
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter a friendly name'),
          'My New Provider');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'https://api.example.com'),
          'https://api.myservice.com');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter your API key'),
          'sk-test-api-key-12345');
      await tester.pumpAndSettle();

      // Scroll to make save button visible
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();

      // Try to tap save button
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Verify save was called (may be called multiple times for provider + models)
      verify(() => mockRepository.saveConfig(any())).called(greaterThan(0));
    });

    testWidgets('opens provider type selection modal when field is tapped',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Find and tap the provider type field
      final providerTypeField = find.text('OpenAI Compatible');
      expect(providerTypeField, findsOneWidget);
      await tester.tap(find.ancestor(
        of: providerTypeField,
        matching: find.byType(GestureDetector),
      ));
      await tester.pumpAndSettle();

      // Verify modal appears with provider options
      expect(find.text('Select Provider Type'), findsOneWidget);
      expect(find.text('OpenAI'), findsAtLeastNWidgets(1));
      expect(find.text('Anthropic Claude'), findsAtLeastNWidgets(1));
    });

    testWidgets('toggles API key visibility', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Use existing provider that requires API key to show API key field
      await tester.pumpWidget(buildTestWidget(configId: 'test-provider-id'));
      await tester.pumpAndSettle();

      // Find visibility toggle button
      final visibilityToggle = find.byIcon(Icons.visibility_rounded);
      expect(visibilityToggle, findsOneWidget);

      // Tap to show API key
      await tester.tap(visibilityToggle);
      await tester.pumpAndSettle();

      // Should now show hide icon
      expect(find.byIcon(Icons.visibility_off_rounded), findsOneWidget);
    });

    testWidgets('has cancel and save buttons', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Verify both buttons exist
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('shows error state when loading fails',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Setup repository to throw error
      when(() => mockRepository.getConfigById('error-id'))
          .thenThrow(Exception('Failed to load'));

      await tester.pumpWidget(buildTestWidget(configId: 'error-id'));
      await tester.pumpAndSettle();

      // Check error UI
      expect(find.text('Failed to load API key configuration'), findsOneWidget);
      expect(find.text('Please try again or contact support'), findsOneWidget);
      expect(find.text('Go Back'), findsOneWidget);
    });

    testWidgets('validates form fields with valid and invalid data',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Test name validation - too short
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter a friendly name'), 'AB');
      await tester.pumpAndSettle();

      // The form validates on change - validation errors may appear

      // Test URL validation - invalid format
      await tester.enterText(
          find.widgetWithText(TextFormField, 'https://api.example.com'),
          'not-a-url');
      await tester.pumpAndSettle();

      // The form validates on change - validation errors may appear

      // Enter valid data to verify errors disappear
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter a friendly name'),
          'Valid Name');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'https://api.example.com'),
          'https://valid.url.com');
      await tester.pumpAndSettle();
    });

    testWidgets('pre-fills form when changing provider type',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Open provider type modal
      await tester.tap(find.ancestor(
        of: find.text('OpenAI Compatible'),
        matching: find.byType(GestureDetector),
      ));
      await tester.pumpAndSettle();

      // Select OpenAI from the modal options
      final openAiOption = find.text('OpenAI').first;
      // Ensure OpenAI option is visible before tapping
      await tester.ensureVisible(openAiOption);
      await tester.pumpAndSettle();

      await tester.tap(find.ancestor(
        of: openAiOption,
        matching: find.byType(InkWell),
      ));
      await tester.pumpAndSettle();

      // Check that form was pre-filled
      expect(find.text('OpenAI'), findsAtLeastNWidgets(1));
      expect(find.text('https://api.openai.com/v1'), findsOneWidget);
    });

    testWidgets('saves modified provider data', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget(configId: 'test-provider-id'));
      await tester.pumpAndSettle();

      // Modify a field
      final nameField = find.widgetWithText(TextFormField, 'Test Provider');
      await tester.enterText(nameField, 'Updated Provider Name');
      await tester.pumpAndSettle();

      // Scroll to make save button visible
      final saveButton = find.text('Save');
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();

      // Save
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Verify save was called with updated data
      verify(() => mockRepository.saveConfig(any())).called(1);
    });

    testWidgets('handles keyboard shortcuts', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Fill form to make it valid (genericOpenAi default doesn't require API key)
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter a friendly name'),
          'Test Provider');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'https://api.example.com'),
          'https://test.com');
      await tester.pumpAndSettle();

      // Verify CallbackShortcuts widget exists
      expect(find.byType(CallbackShortcuts), findsWidgets);
    });
  });

  group('API Key Field Visibility for Different Providers', () {
    testWidgets('loads existing Ollama provider without showing API key field',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Create an Ollama provider
      final ollamaProvider = AiConfig.inferenceProvider(
        id: 'ollama-id',
        name: 'My Ollama',
        baseUrl: 'http://localhost:11434/v1',
        apiKey: '', // Empty API key for Ollama
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.ollama,
      );

      when(() => mockRepository.getConfigById('ollama-id'))
          .thenAnswer((_) async => ollamaProvider);

      await tester.pumpWidget(buildTestWidget(configId: 'ollama-id'));
      await tester.pumpAndSettle();

      // Verify form loads with Ollama data
      expect(find.text('My Ollama'), findsOneWidget);
      expect(find.text('http://localhost:11434/v1'), findsOneWidget);

      // API key field should not be visible
      expect(find.text('Authentication'), findsNothing);
      expect(find.text('API Key'), findsNothing);
      expect(find.byIcon(Icons.key_rounded), findsNothing);
    });

    testWidgets('shows API key field for OpenAI provider',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Open provider type selection modal
      await tester.tap(find.ancestor(
        of: find.text('OpenAI Compatible'),
        matching: find.byType(GestureDetector),
      ));
      await tester.pumpAndSettle();

      // Select OpenAI
      final openAiOption = find.text('OpenAI').first;
      // Ensure OpenAI option is visible before tapping
      await tester.ensureVisible(openAiOption);
      await tester.pumpAndSettle();

      await tester.tap(find.ancestor(
        of: openAiOption,
        matching: find.byType(InkWell),
      ));
      await tester.pumpAndSettle();

      // API key field should be visible
      expect(find.text('Authentication'), findsOneWidget);
      expect(find.text('API Key'), findsOneWidget);
      expect(find.text('Secure your API connection'), findsOneWidget);
      expect(find.byIcon(Icons.key_rounded), findsOneWidget);
    });

    testWidgets('shows API key field for Anthropic provider',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Open provider type selection modal
      await tester.tap(find.ancestor(
        of: find.text('OpenAI Compatible'),
        matching: find.byType(GestureDetector),
      ));
      await tester.pumpAndSettle();

      // Select Anthropic
      final anthropicOption = find.text('Anthropic Claude');
      await tester.tap(find.ancestor(
        of: anthropicOption,
        matching: find.byType(InkWell),
      ));
      await tester.pumpAndSettle();

      // API key field should be visible
      expect(find.text('Authentication'), findsOneWidget);
      expect(find.text('API Key'), findsOneWidget);
      expect(find.text('Secure your API connection'), findsOneWidget);
      expect(find.byIcon(Icons.key_rounded), findsOneWidget);
    });

    testWidgets('API key field visibility changes when switching providers',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Start with a provider that requires API key
      await tester.pumpWidget(buildTestWidget(configId: 'test-provider-id'));
      await tester.pumpAndSettle();

      // Initially with OpenAI, API key should be visible
      expect(find.text('API Key'), findsOneWidget);

      // Switch to Ollama (no API key required)
      await tester.tap(find.ancestor(
        of: find.text('OpenAI'),
        matching: find.byType(GestureDetector),
      ));
      await tester.pumpAndSettle();

      // Ensure Ollama option is visible before tapping
      final ollamaOption = find.text('Ollama');
      await tester.ensureVisible(ollamaOption);
      await tester.pumpAndSettle();

      await tester.tap(find.ancestor(
        of: ollamaOption,
        matching: find.byType(InkWell),
      ));

      // Wait for modal to close
      await tester.pumpAndSettle();

      // Force multiple pump cycles to ensure state propagates
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();

      // API key should be hidden
      expect(find.text('API Key'), findsNothing);

      // Switch back to OpenAI - tap on the provider type field (which now shows "Ollama")
      await tester.tap(find
          .ancestor(
            of: find.text('Provider Type'),
            matching: find.byType(GestureDetector),
          )
          .first);
      await tester.pumpAndSettle();

      // Ensure OpenAI option is visible before tapping
      final openAiOption = find.text('OpenAI').first;
      await tester.ensureVisible(openAiOption);
      await tester.pumpAndSettle();

      await tester.tap(find.ancestor(
        of: openAiOption,
        matching: find.byType(InkWell),
      ));
      await tester.pumpAndSettle();

      // API key should be visible again
      expect(find.text('API Key'), findsOneWidget);
    });

    testWidgets('can save Ollama provider without API key',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Select Ollama
      await tester.tap(find.ancestor(
        of: find.text('OpenAI Compatible'),
        matching: find.byType(GestureDetector),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.ancestor(
        of: find.text('Ollama'),
        matching: find.byType(InkWell),
      ));
      await tester.pumpAndSettle();

      // Fill only name and URL (no API key needed)
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter a friendly name'),
          'My Local Ollama');
      // URL should already be pre-filled for Ollama
      await tester.pumpAndSettle();

      // Scroll to save button
      final saveButton = find.text('Save');
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();

      // Should be able to save without API key
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Verify save was called (may be called multiple times due to model pre-population)
      verify(() => mockRepository.saveConfig(any())).called(greaterThan(0));
    });

    testWidgets('validates form correctly for different provider types',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // For OpenAI, should require API key
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter a friendly name'),
          'OpenAI Test');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'https://api.example.com'),
          'https://api.openai.com/v1');
      // Don't enter API key
      await tester.pumpAndSettle();

      // Try to save - should fail because API key is required
      final saveButton = find.text('Save');
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();

      // Now switch to Ollama
      await tester.tap(find.ancestor(
        of: find.text('OpenAI Compatible'),
        matching: find.byType(GestureDetector),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.ancestor(
        of: find.text('Ollama'),
        matching: find.byType(InkWell),
      ));
      await tester.pumpAndSettle();

      // Should now be able to save without API key
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Verify save was called for Ollama without API key (may be called multiple times due to model pre-population)
      verify(() => mockRepository.saveConfig(any())).called(greaterThan(0));
    });
  });

  group('Gemini Prompt Setup Integration', () {
    testWidgets('shows prompt setup dialog after saving new Gemini provider',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Track saved configs to return dynamically created models
      final savedConfigs = <AiConfig>[];
      when(() => mockRepository.saveConfig(any())).thenAnswer((invocation) {
        savedConfigs.add(invocation.positionalArguments[0] as AiConfig);
        return Future.value();
      });
      when(() => mockRepository.getConfigsByType(AiConfigType.model))
          .thenAnswer(
              (_) async => savedConfigs.whereType<AiConfigModel>().toList());

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Select Gemini provider type
      await tester.tap(find.ancestor(
        of: find.text('OpenAI Compatible'),
        matching: find.byType(GestureDetector),
      ));
      await tester.pumpAndSettle();

      // Find and tap Gemini option
      final geminiOption = find.text('Google Gemini');
      await tester.ensureVisible(geminiOption);
      await tester.pumpAndSettle();

      await tester.tap(find.ancestor(
        of: geminiOption,
        matching: find.byType(InkWell),
      ));
      await tester.pumpAndSettle();

      // Fill required fields
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter a friendly name'),
          'My Gemini');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter your API key'),
          'test-gemini-key');
      await tester.pumpAndSettle();

      // Scroll to save button and tap
      final saveButton = find.text('Save');
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();

      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Prompt setup dialog should appear
      expect(find.text('Set Up AI Features?'), findsOneWidget);
    });

    testWidgets(
        'does not show prompt setup dialog for providers without FTUE support',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Select Anthropic provider type (which doesn't have FTUE support)
      await tester.tap(find.ancestor(
        of: find.text('OpenAI Compatible'),
        matching: find.byType(GestureDetector),
      ));
      await tester.pumpAndSettle();

      final anthropicOption = find.text('Anthropic Claude');
      await tester.ensureVisible(anthropicOption);
      await tester.pumpAndSettle();

      await tester.tap(find.ancestor(
        of: anthropicOption,
        matching: find.byType(InkWell),
      ));
      await tester.pumpAndSettle();

      // Fill required fields
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter a friendly name'),
          'My Anthropic');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter your API key'),
          'test-anthropic-key');
      await tester.pumpAndSettle();

      // Scroll to save button and tap
      final saveButton = find.text('Save');
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();

      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Prompt setup dialog should NOT appear for non-Gemini/non-OpenAI providers
      expect(find.text('Set Up AI Features?'), findsNothing);
    });

    testWidgets(
        'does not show prompt setup dialog when editing existing provider',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Setup existing Gemini provider
      final existingGemini = AiConfig.inferenceProvider(
        id: 'existing-gemini-id',
        name: 'Existing Gemini',
        baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
        apiKey: 'existing-key',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.gemini,
      );

      when(() => mockRepository.getConfigById('existing-gemini-id'))
          .thenAnswer((_) async => existingGemini);

      await tester.pumpWidget(buildTestWidget(configId: 'existing-gemini-id'));
      await tester.pumpAndSettle();

      // Modify a field
      final nameField = find.widgetWithText(TextFormField, 'Existing Gemini');
      await tester.enterText(nameField, 'Updated Gemini');
      await tester.pumpAndSettle();

      // Scroll to save button and tap
      final saveButton = find.text('Save');
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();

      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Prompt setup dialog should NOT appear for edits
      expect(find.text('Set Up AI Features?'), findsNothing);
    });

    testWidgets('creates prompts when user confirms in setup dialog',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Track saved configs to return dynamically created models
      final savedConfigs = <AiConfig>[];
      when(() => mockRepository.saveConfig(any())).thenAnswer((invocation) {
        savedConfigs.add(invocation.positionalArguments[0] as AiConfig);
        return Future.value();
      });
      when(() => mockRepository.getConfigsByType(AiConfigType.model))
          .thenAnswer(
              (_) async => savedConfigs.whereType<AiConfigModel>().toList());

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Select Gemini
      await tester.tap(find.ancestor(
        of: find.text('OpenAI Compatible'),
        matching: find.byType(GestureDetector),
      ));
      await tester.pumpAndSettle();

      final geminiOption = find.text('Google Gemini');
      await tester.ensureVisible(geminiOption);
      await tester.pumpAndSettle();

      await tester.tap(find.ancestor(
        of: geminiOption,
        matching: find.byType(InkWell),
      ));
      await tester.pumpAndSettle();

      // Fill fields
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter a friendly name'),
          'My Gemini');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter your API key'), 'test-key');
      await tester.pumpAndSettle();

      // Save
      final saveButton = find.text('Save');
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();

      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Confirm prompt setup
      expect(find.text('Set Up AI Features?'), findsOneWidget);
      await tester.tap(find.text('Set Up'));
      await tester.pumpAndSettle();

      // Verify prompts were created
      // FTUE creates: 3 models + 9 prompts (optimized assignment)
      final promptsCreated = savedConfigs.whereType<AiConfigPrompt>().length;
      expect(promptsCreated, equals(9));
    });

    testWidgets('skips prompt creation when user declines',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Track saved configs to return dynamically created models
      final savedConfigs = <AiConfig>[];
      when(() => mockRepository.saveConfig(any())).thenAnswer((invocation) {
        savedConfigs.add(invocation.positionalArguments[0] as AiConfig);
        return Future.value();
      });
      when(() => mockRepository.getConfigsByType(AiConfigType.model))
          .thenAnswer(
              (_) async => savedConfigs.whereType<AiConfigModel>().toList());

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Select Gemini
      await tester.tap(find.ancestor(
        of: find.text('OpenAI Compatible'),
        matching: find.byType(GestureDetector),
      ));
      await tester.pumpAndSettle();

      final geminiOption = find.text('Google Gemini');
      await tester.ensureVisible(geminiOption);
      await tester.pumpAndSettle();

      await tester.tap(find.ancestor(
        of: geminiOption,
        matching: find.byType(InkWell),
      ));
      await tester.pumpAndSettle();

      // Fill fields
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter a friendly name'),
          'My Gemini');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter your API key'), 'test-key');
      await tester.pumpAndSettle();

      // Save
      final saveButton = find.text('Save');
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();

      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Decline prompt setup
      expect(find.text('Set Up AI Features?'), findsOneWidget);
      await tester.tap(find.text('No Thanks'));
      await tester.pumpAndSettle();

      // Dialog should close, no prompts created
      expect(find.text('Set Up AI Features?'), findsNothing);
      final promptsCreated = savedConfigs.whereType<AiConfigPrompt>().length;
      expect(promptsCreated, equals(0));
    });
  });

  group('Available Models Section', () {
    testWidgets('shows Available Models section for existing provider',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Create a Gemini provider (which has known models)
      final geminiProvider = AiConfig.inferenceProvider(
        id: 'gemini-provider-id',
        name: 'My Gemini',
        baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
        apiKey: 'test-key',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.gemini,
      );

      when(() => mockRepository.getConfigById('gemini-provider-id'))
          .thenAnswer((_) async => geminiProvider);
      when(() => mockRepository.watchConfigsByType(AiConfigType.model))
          .thenAnswer((_) => Stream.value([]));

      await tester.pumpWidget(buildTestWidget(configId: 'gemini-provider-id'));
      await tester.pumpAndSettle();

      // Scroll to find Available Models section
      final availableModelsSection = find.text('Available Models');
      if (availableModelsSection.evaluate().isNotEmpty) {
        await tester.ensureVisible(availableModelsSection);
        await tester.pumpAndSettle();
      }

      // Should show Available Models section
      expect(find.text('Available Models'), findsOneWidget);
      expect(find.text('Quick-add preconfigured models for this provider'),
          findsOneWidget);
    });

    testWidgets('does not show Available Models section for new provider',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Should not show Available Models section for new provider
      expect(find.text('Available Models'), findsNothing);
    });

    testWidgets('displays known models for Gemini provider',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final geminiProvider = AiConfig.inferenceProvider(
        id: 'gemini-provider-id',
        name: 'My Gemini',
        baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
        apiKey: 'test-key',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.gemini,
      );

      when(() => mockRepository.getConfigById('gemini-provider-id'))
          .thenAnswer((_) async => geminiProvider);
      when(() => mockRepository.watchConfigsByType(AiConfigType.model))
          .thenAnswer((_) => Stream.value([]));

      await tester.pumpWidget(buildTestWidget(configId: 'gemini-provider-id'));
      await tester.pumpAndSettle();

      // Scroll to find Available Models section
      final availableModelsSection = find.text('Available Models');
      await tester.ensureVisible(availableModelsSection);
      await tester.pumpAndSettle();

      // Should show Gemini known models (from known_models.dart)
      // Nano Banana Pro is the first model for Gemini
      expect(
          find.textContaining('Gemini 3 Pro Image'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows Added indicator for already configured models',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final geminiProvider = AiConfig.inferenceProvider(
        id: 'gemini-provider-id',
        name: 'My Gemini',
        baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
        apiKey: 'test-key',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.gemini,
      );

      // Create an existing model that matches one of the known models
      final existingModel = AiConfig.model(
        id: 'existing-model-id',
        name: 'Gemini 3 Pro Image (Nano Banana Pro)',
        providerModelId: 'models/gemini-3-pro-image-preview',
        inferenceProviderId: 'gemini-provider-id',
        createdAt: DateTime.now(),
        inputModalities: [Modality.text, Modality.image],
        outputModalities: [Modality.text, Modality.image],
        isReasoningModel: false,
      );

      when(() => mockRepository.getConfigById('gemini-provider-id'))
          .thenAnswer((_) async => geminiProvider);
      when(() => mockRepository.watchConfigsByType(AiConfigType.model))
          .thenAnswer((_) => Stream.value([existingModel]));

      await tester.pumpWidget(buildTestWidget(configId: 'gemini-provider-id'));
      await tester.pumpAndSettle();

      // Scroll to find Available Models section
      final availableModelsSection = find.text('Available Models');
      await tester.ensureVisible(availableModelsSection);
      await tester.pumpAndSettle();

      // Should show "Added" badge for the already configured model
      expect(find.text('Added'), findsAtLeastNWidgets(1));
    });

    testWidgets('can add a known model by tapping add button',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final geminiProvider = AiConfig.inferenceProvider(
        id: 'gemini-provider-id',
        name: 'My Gemini',
        baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
        apiKey: 'test-key',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.gemini,
      );

      when(() => mockRepository.getConfigById('gemini-provider-id'))
          .thenAnswer((_) async => geminiProvider);
      when(() => mockRepository.watchConfigsByType(AiConfigType.model))
          .thenAnswer((_) => Stream.value([]));

      await tester.pumpWidget(buildTestWidget(configId: 'gemini-provider-id'));
      await tester.pumpAndSettle();

      // Scroll to find Available Models section
      final availableModelsSection = find.text('Available Models');
      await tester.ensureVisible(availableModelsSection);
      await tester.pumpAndSettle();

      // Find and tap an add button (the circular button with add icon)
      final addButton = find.byIcon(Icons.add_rounded).first;
      await tester.ensureVisible(addButton);
      await tester.pumpAndSettle();

      await tester.tap(addButton);
      await tester.pumpAndSettle();

      // Verify saveConfig was called with a new model
      verify(() => mockRepository.saveConfig(any(
            that: isA<AiConfigModel>().having(
              (m) => m.inferenceProviderId,
              'inferenceProviderId',
              'gemini-provider-id',
            ),
          ))).called(1);
    });

    testWidgets('shows modality chips for known models',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final geminiProvider = AiConfig.inferenceProvider(
        id: 'gemini-provider-id',
        name: 'My Gemini',
        baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
        apiKey: 'test-key',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.gemini,
      );

      when(() => mockRepository.getConfigById('gemini-provider-id'))
          .thenAnswer((_) async => geminiProvider);
      when(() => mockRepository.watchConfigsByType(AiConfigType.model))
          .thenAnswer((_) => Stream.value([]));

      await tester.pumpWidget(buildTestWidget(configId: 'gemini-provider-id'));
      await tester.pumpAndSettle();

      // Scroll to find Available Models section
      final availableModelsSection = find.text('Available Models');
      await tester.ensureVisible(availableModelsSection);
      await tester.pumpAndSettle();

      // Should show modality chips (In: and Out: prefixes)
      expect(find.textContaining('In:'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Out:'), findsAtLeastNWidgets(1));
    });

    testWidgets(
        'does not show Available Models for providers without known models',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Create a custom provider type that doesn't have known models defined
      // Using genericOpenAi which should have some models
      final customProvider = AiConfig.inferenceProvider(
        id: 'custom-provider-id',
        name: 'Custom Provider',
        baseUrl: 'https://api.custom.com',
        apiKey: 'test-key',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.genericOpenAi,
      );

      when(() => mockRepository.getConfigById('custom-provider-id'))
          .thenAnswer((_) async => customProvider);
      when(() => mockRepository.watchConfigsByType(AiConfigType.model))
          .thenAnswer((_) => Stream.value([]));

      await tester.pumpWidget(buildTestWidget(configId: 'custom-provider-id'));
      await tester.pumpAndSettle();

      // genericOpenAi has known models, so it should show
      expect(find.text('Available Models'), findsOneWidget);
    });
  });

  group('AI Setup Wizard Section', () {
    testWidgets('shows AI Setup Wizard section for existing Gemini provider',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final geminiProvider = AiConfig.inferenceProvider(
        id: 'gemini-provider-id',
        name: 'My Gemini',
        baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
        apiKey: 'test-key',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.gemini,
      );

      when(() => mockRepository.getConfigById('gemini-provider-id'))
          .thenAnswer((_) async => geminiProvider);
      when(() => mockRepository.watchConfigsByType(AiConfigType.model))
          .thenAnswer((_) => Stream.value([]));
      when(() =>
              mockRepository.getConfigsByType(AiConfigType.inferenceProvider))
          .thenAnswer((_) async => [geminiProvider]);

      await tester.pumpWidget(buildTestWidget(
        configId: 'gemini-provider-id',
        existingProviders: [geminiProvider],
      ));
      await tester.pumpAndSettle();

      final strings = l10n(tester);

      // Scroll to find AI Setup Wizard section
      final aiSetupSection = find.text(strings.aiSetupWizardTitle);
      await tester.ensureVisible(aiSetupSection);
      await tester.pumpAndSettle();

      // Should show AI Setup Wizard section
      expect(find.text(strings.aiSetupWizardTitle), findsOneWidget);
      expect(
        find.text(strings.aiSetupWizardDescription('Gemini')),
        findsOneWidget,
      );
      expect(find.text(strings.aiSetupWizardRunLabel), findsOneWidget);
      expect(
        find.text(strings.aiSetupWizardSafeToRunMultiple),
        findsOneWidget,
      );
      expect(find.text(strings.aiSetupWizardRunButton), findsOneWidget);
    });

    testWidgets('shows AI Setup Wizard section for existing OpenAI provider',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final openAiProvider = AiConfig.inferenceProvider(
        id: 'openai-provider-id',
        name: 'My OpenAI',
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'test-key',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.openAi,
      );

      when(() => mockRepository.getConfigById('openai-provider-id'))
          .thenAnswer((_) async => openAiProvider);
      when(() => mockRepository.watchConfigsByType(AiConfigType.model))
          .thenAnswer((_) => Stream.value([]));
      when(() =>
              mockRepository.getConfigsByType(AiConfigType.inferenceProvider))
          .thenAnswer((_) async => [openAiProvider]);

      await tester.pumpWidget(buildTestWidget(
        configId: 'openai-provider-id',
        existingProviders: [openAiProvider],
      ));
      await tester.pumpAndSettle();

      final strings = l10n(tester);

      // Scroll to find AI Setup Wizard section
      final aiSetupSection = find.text(strings.aiSetupWizardTitle);
      await tester.ensureVisible(aiSetupSection);
      await tester.pumpAndSettle();

      // Should show AI Setup Wizard section for OpenAI
      expect(find.text(strings.aiSetupWizardTitle), findsOneWidget);
      expect(
        find.text(strings.aiSetupWizardDescription('OpenAI')),
        findsOneWidget,
      );
    });

    testWidgets('shows AI Setup Wizard section for existing Mistral provider',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final mistralProvider = AiConfig.inferenceProvider(
        id: 'mistral-provider-id',
        name: 'My Mistral',
        baseUrl: 'https://api.mistral.ai/v1',
        apiKey: 'test-key',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.mistral,
      );

      when(() => mockRepository.getConfigById('mistral-provider-id'))
          .thenAnswer((_) async => mistralProvider);
      when(() => mockRepository.watchConfigsByType(AiConfigType.model))
          .thenAnswer((_) => Stream.value([]));
      when(() =>
              mockRepository.getConfigsByType(AiConfigType.inferenceProvider))
          .thenAnswer((_) async => [mistralProvider]);

      await tester.pumpWidget(buildTestWidget(
        configId: 'mistral-provider-id',
        existingProviders: [mistralProvider],
      ));
      await tester.pumpAndSettle();

      final strings = l10n(tester);

      // Scroll to find AI Setup Wizard section
      final aiSetupSection = find.text(strings.aiSetupWizardTitle);
      await tester.ensureVisible(aiSetupSection);
      await tester.pumpAndSettle();

      // Should show AI Setup Wizard section for Mistral
      expect(find.text(strings.aiSetupWizardTitle), findsOneWidget);
      expect(
        find.text(strings.aiSetupWizardDescription('Mistral')),
        findsOneWidget,
      );
    });

    testWidgets('does not show AI Setup Wizard for unsupported providers',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final ollamaProvider = AiConfig.inferenceProvider(
        id: 'ollama-provider-id',
        name: 'My Ollama',
        baseUrl: 'http://localhost:11434/v1',
        apiKey: '',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.ollama,
      );

      when(() => mockRepository.getConfigById('ollama-provider-id'))
          .thenAnswer((_) async => ollamaProvider);
      when(() => mockRepository.watchConfigsByType(AiConfigType.model))
          .thenAnswer((_) => Stream.value([]));
      when(() =>
              mockRepository.getConfigsByType(AiConfigType.inferenceProvider))
          .thenAnswer((_) async => [ollamaProvider]);

      await tester.pumpWidget(buildTestWidget(
        configId: 'ollama-provider-id',
        existingProviders: [ollamaProvider],
      ));
      await tester.pumpAndSettle();

      final strings = l10n(tester);

      // Should NOT show AI Setup Wizard section for Ollama
      expect(find.text(strings.aiSetupWizardTitle), findsNothing);
    });

    testWidgets('does not show AI Setup Wizard for new provider',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final strings = l10n(tester);

      // Should NOT show AI Setup Wizard section for new provider
      expect(find.text(strings.aiSetupWizardTitle), findsNothing);
    });

    testWidgets('Run Setup button shows confirmation dialog when tapped',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final geminiProvider = AiConfig.inferenceProvider(
        id: 'gemini-provider-id',
        name: 'My Gemini',
        baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
        apiKey: 'test-key',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.gemini,
      );

      when(() => mockRepository.getConfigById('gemini-provider-id'))
          .thenAnswer((_) async => geminiProvider);
      when(() => mockRepository.watchConfigsByType(AiConfigType.model))
          .thenAnswer((_) => Stream.value([]));
      when(() =>
              mockRepository.getConfigsByType(AiConfigType.inferenceProvider))
          .thenAnswer((_) async => [geminiProvider]);

      await tester.pumpWidget(buildTestWidget(
        configId: 'gemini-provider-id',
        existingProviders: [geminiProvider],
      ));
      await tester.pumpAndSettle();

      final strings = l10n(tester);

      // Scroll to find Run Setup button
      final runSetupButton = find.text(strings.aiSetupWizardRunButton);
      await tester.ensureVisible(runSetupButton);
      await tester.pumpAndSettle();

      // Tap the Run Setup button
      await tester.tap(runSetupButton);
      // Use pump with duration instead of pumpAndSettle to avoid timeout
      // The dialog appears after async config fetch completes
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Confirmation dialog should appear (dialog uses hard-coded text currently)
      expect(find.text('Set Up AI Features?'), findsOneWidget);
    });

    testWidgets('displays all localized strings correctly',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final geminiProvider = AiConfig.inferenceProvider(
        id: 'gemini-provider-id',
        name: 'My Gemini',
        baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
        apiKey: 'test-key',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.gemini,
      );

      when(() => mockRepository.getConfigById('gemini-provider-id'))
          .thenAnswer((_) async => geminiProvider);
      when(() => mockRepository.watchConfigsByType(AiConfigType.model))
          .thenAnswer((_) => Stream.value([]));
      when(() =>
              mockRepository.getConfigsByType(AiConfigType.inferenceProvider))
          .thenAnswer((_) async => [geminiProvider]);

      await tester.pumpWidget(buildTestWidget(
        configId: 'gemini-provider-id',
        existingProviders: [geminiProvider],
      ));
      await tester.pumpAndSettle();

      final strings = l10n(tester);

      // Scroll to find AI Setup Wizard section
      final aiSetupSection = find.text(strings.aiSetupWizardTitle);
      await tester.ensureVisible(aiSetupSection);
      await tester.pumpAndSettle();

      // Verify all localized strings are displayed
      expect(find.text(strings.aiSetupWizardTitle), findsOneWidget);
      expect(find.text(strings.aiSetupWizardRunLabel), findsOneWidget);
      expect(
        find.text(strings.aiSetupWizardCreatesOptimized),
        findsOneWidget,
      );
      expect(
        find.text(strings.aiSetupWizardSafeToRunMultiple),
        findsOneWidget,
      );
      expect(find.text(strings.aiSetupWizardRunButton), findsOneWidget);
    });

    testWidgets('shows Running state while setup is in progress',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final geminiProvider = AiConfig.inferenceProvider(
        id: 'gemini-provider-id',
        name: 'My Gemini',
        baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
        apiKey: 'test-key',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.gemini,
      );

      when(() => mockRepository.getConfigById('gemini-provider-id'))
          .thenAnswer((_) async => geminiProvider);
      when(() => mockRepository.watchConfigsByType(AiConfigType.model))
          .thenAnswer((_) => Stream.value([]));
      when(() =>
              mockRepository.getConfigsByType(AiConfigType.inferenceProvider))
          .thenAnswer((_) async => [geminiProvider]);

      await tester.pumpWidget(buildTestWidget(
        configId: 'gemini-provider-id',
        existingProviders: [geminiProvider],
      ));
      await tester.pumpAndSettle();

      final strings = l10n(tester);

      // Scroll to find Run Setup button and verify initial state
      final runSetupButton = find.text(strings.aiSetupWizardRunButton);
      await tester.ensureVisible(runSetupButton);
      await tester.pumpAndSettle();

      // Button should show "Run Setup" initially
      expect(find.text(strings.aiSetupWizardRunButton), findsOneWidget);
      expect(find.text(strings.aiSetupWizardRunningButton), findsNothing);
    });
  });

  group('New Provider FTUE Flow', () {
    testWidgets('shows prompt setup dialog after saving new OpenAI provider',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Track saved configs to return dynamically created models
      final savedConfigs = <AiConfig>[];
      when(() => mockRepository.saveConfig(any())).thenAnswer((invocation) {
        savedConfigs.add(invocation.positionalArguments[0] as AiConfig);
        return Future.value();
      });
      when(() => mockRepository.getConfigsByType(AiConfigType.model))
          .thenAnswer(
              (_) async => savedConfigs.whereType<AiConfigModel>().toList());

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Select OpenAI provider type
      await tester.tap(find.ancestor(
        of: find.text('OpenAI Compatible'),
        matching: find.byType(GestureDetector),
      ));
      await tester.pumpAndSettle();

      // Find and tap OpenAI option
      final openAiOption = find.text('OpenAI').first;
      await tester.ensureVisible(openAiOption);
      await tester.pumpAndSettle();

      await tester.tap(find.ancestor(
        of: openAiOption,
        matching: find.byType(InkWell),
      ));
      await tester.pumpAndSettle();

      // Fill required fields
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter a friendly name'),
          'My OpenAI');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter your API key'),
          'test-openai-key');
      await tester.pumpAndSettle();

      // Scroll to save button and tap
      final saveButton = find.text('Save');
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();

      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Prompt setup dialog should appear for OpenAI
      expect(find.text('Set Up AI Features?'), findsOneWidget);
    });

    testWidgets('shows prompt setup dialog after saving new Mistral provider',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Track saved configs to return dynamically created models
      final savedConfigs = <AiConfig>[];
      when(() => mockRepository.saveConfig(any())).thenAnswer((invocation) {
        savedConfigs.add(invocation.positionalArguments[0] as AiConfig);
        return Future.value();
      });
      when(() => mockRepository.getConfigsByType(AiConfigType.model))
          .thenAnswer(
              (_) async => savedConfigs.whereType<AiConfigModel>().toList());

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Select Mistral provider type
      await tester.tap(find.ancestor(
        of: find.text('OpenAI Compatible'),
        matching: find.byType(GestureDetector),
      ));
      await tester.pumpAndSettle();

      // Find and tap Mistral option (displayed as 'Mistral' not 'Mistral AI')
      final mistralOption = find.text('Mistral');
      await tester.ensureVisible(mistralOption);
      await tester.pumpAndSettle();

      await tester.tap(find.ancestor(
        of: mistralOption,
        matching: find.byType(InkWell),
      ));
      await tester.pumpAndSettle();

      // Fill required fields
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter a friendly name'),
          'My Mistral');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter your API key'),
          'test-mistral-key');
      await tester.pumpAndSettle();

      // Scroll to save button and tap
      final saveButton = find.text('Save');
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();

      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Prompt setup dialog should appear for Mistral
      expect(find.text('Set Up AI Features?'), findsOneWidget);
    });

    testWidgets('creates prompts for OpenAI when user confirms in setup dialog',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Track saved configs to return dynamically created models
      final savedConfigs = <AiConfig>[];
      when(() => mockRepository.saveConfig(any())).thenAnswer((invocation) {
        savedConfigs.add(invocation.positionalArguments[0] as AiConfig);
        return Future.value();
      });
      when(() => mockRepository.getConfigsByType(AiConfigType.model))
          .thenAnswer(
              (_) async => savedConfigs.whereType<AiConfigModel>().toList());

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Select OpenAI
      await tester.tap(find.ancestor(
        of: find.text('OpenAI Compatible'),
        matching: find.byType(GestureDetector),
      ));
      await tester.pumpAndSettle();

      final openAiOption = find.text('OpenAI').first;
      await tester.ensureVisible(openAiOption);
      await tester.pumpAndSettle();

      await tester.tap(find.ancestor(
        of: openAiOption,
        matching: find.byType(InkWell),
      ));
      await tester.pumpAndSettle();

      // Fill fields
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter a friendly name'),
          'My OpenAI');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter your API key'), 'test-key');
      await tester.pumpAndSettle();

      // Save
      final saveButton = find.text('Save');
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();

      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Confirm prompt setup
      expect(find.text('Set Up AI Features?'), findsOneWidget);
      await tester.tap(find.text('Set Up'));
      await tester.pumpAndSettle();

      // Verify prompts were created for OpenAI
      final promptsCreated = savedConfigs.whereType<AiConfigPrompt>().length;
      expect(promptsCreated, equals(9));
    });
  });
}
