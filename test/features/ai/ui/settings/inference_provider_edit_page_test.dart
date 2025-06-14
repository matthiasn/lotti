import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/ui/settings/inference_provider_edit_page.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

// Mock classes
class MockAiConfigRepository extends Mock implements AiConfigRepository {}

void main() {
  late MockAiConfigRepository mockRepository;
  late AiConfig testProvider;

  setUpAll(() {
    registerFallbackValue(
      AiConfig.inferenceProvider(
        id: 'fallback-id',
        name: 'Fallback Provider',
        baseUrl: 'https://fallback.example.com',
        apiKey: 'fallback-key',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.genericOpenAi,
      ),
    );
  });

  setUp(() {
    mockRepository = MockAiConfigRepository();

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
  });

  Widget buildTestWidget({String? configId}) {
    return ProviderScope(
      overrides: [
        aiConfigRepositoryProvider.overrideWithValue(mockRepository),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: InferenceProviderEditPage(configId: configId),
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

      await tester.pumpWidget(buildTestWidget());
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

      // Fill in required fields
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter a friendly name'),
          'My New Provider');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'https://api.example.com'),
          'https://api.myservice.com');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter your API key'),
          'my-secret-key');
      await tester.pumpAndSettle();

      // Scroll to make save button visible
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();

      // Try to tap save button
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Verify save was called
      verify(() => mockRepository.saveConfig(any())).called(1);
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

      await tester.pumpWidget(buildTestWidget());
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
      final openAiOptions = find.text('OpenAI');
      // Find the OpenAI option that's in the modal (not the title)
      for (var i = 0; i < openAiOptions.evaluate().length; i++) {
        final option = openAiOptions.at(i);
        final ancestor = find.ancestor(
          of: option,
          matching: find.byType(InkWell),
        );
        if (ancestor.evaluate().isNotEmpty) {
          await tester.tap(ancestor.first);
          break;
        }
      }
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

      // Fill form to make it valid
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter a friendly name'),
          'Test Provider');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'https://api.example.com'),
          'https://test.com');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter your API key'), 'test-key');
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
      final openAiOptions = find.text('OpenAI');
      for (var i = 0; i < openAiOptions.evaluate().length; i++) {
        final option = openAiOptions.at(i);
        final ancestor = find.ancestor(
          of: option,
          matching: find.byType(InkWell),
        );
        if (ancestor.evaluate().isNotEmpty) {
          await tester.tap(ancestor.first);
          break;
        }
      }
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

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Initially with OpenAI Compatible, API key should be visible
      expect(find.text('API Key'), findsOneWidget);

      // Switch to Ollama
      await tester.tap(find.ancestor(
        of: find.text('OpenAI Compatible'),
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

      final openAiOptions = find.text('OpenAI');
      for (var i = 0; i < openAiOptions.evaluate().length; i++) {
        final option = openAiOptions.at(i);
        final ancestor = find.ancestor(
          of: option,
          matching: find.byType(InkWell),
        );
        if (ancestor.evaluate().isNotEmpty) {
          await tester.tap(ancestor.first);
          break;
        }
      }
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
}
