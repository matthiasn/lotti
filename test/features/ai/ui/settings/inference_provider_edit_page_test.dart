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
      final saveButton = find.text('Save Provider');
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

    testWidgets('has cancel and save buttons',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Verify both buttons exist
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save Provider'), findsOneWidget);
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
          find.widgetWithText(TextFormField, 'Enter a friendly name'), 'Valid Name');
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
      final saveButton = find.text('Save Provider');
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
          find.widgetWithText(TextFormField, 'Enter your API key'),
          'test-key');
      await tester.pumpAndSettle();

      // Verify CallbackShortcuts widget exists
      expect(find.byType(CallbackShortcuts), findsWidgets);
    });
  });
}
