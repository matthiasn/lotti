import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/inference_provider_form_controller.dart';
import 'package:lotti/features/ai/ui/settings/inference_provider_form.dart';
import 'package:mocktail/mocktail.dart';

// Mock implementations
class MockNavigatorObserver extends Mock implements NavigatorObserver {}

void main() {
  Widget buildTestWidget({
    required void Function(AiConfig) onSave,
    AiConfig? initialConfig,
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
          child: InferenceProviderForm(
            config: initialConfig,
            onSave: onSave,
          ),
        ),
      ),
    );
  }

  group('ApiKeyForm', () {
    testWidgets('should render all form fields including provider type field',
        (WidgetTester tester) async {
      // Arrange
      // ignore: unused_local_variable
      var onSaveCalled = false;
      await tester.pumpWidget(
        buildTestWidget(
          onSave: (_) {
            onSaveCalled = true;
          },
        ),
      );

      // Wait for animation to complete
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Assert - verify form fields are present
      expect(find.text('Display Name'), findsOneWidget);
      expect(find.text('Base URL'), findsOneWidget);
      expect(find.text('API Key'), findsOneWidget);
      expect(find.text('Provider Type'), findsOneWidget);
      expect(find.text('Comment (Optional)'), findsOneWidget);
      expect(find.text('Create'), findsOneWidget);
    });

    testWidgets('should have provider type field and validate form structure',
        (WidgetTester tester) async {
      // Simpler test that just validates the form structure
      await tester.pumpWidget(
        buildTestWidget(
          onSave: (_) {},
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify form structure
      expect(
        find.byType(TextField),
        findsNWidgets(4),
      ); // Name, URL, API Key, Comment

      // Find the provider type field using the InputDecorator
      final providerTypeFieldFinder =
          find.widgetWithText(InputDecorator, 'Provider Type');
      expect(providerTypeFieldFinder, findsOneWidget);

      expect(find.byType(FilledButton), findsOneWidget); // Create button
    });

    // Test error text for short name input
    testWidgets('should show correct error text when name is too short',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          onSave: (_) {},
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Find the name field (first TextField)
      final nameTextField = find.byType(TextField).first;

      // Enter valid name, then clear and enter invalid short name
      await tester.enterText(nameTextField, 'Valid Name');
      await tester.pump();

      // No error should be shown for valid input
      expect(find.text('Name must be at least 3 characters'), findsNothing);

      // Enter an invalid short name (less than 3 characters)
      await tester.enterText(nameTextField, 'ab');
      await tester.pump();

      // Error message should appear
      expect(find.text('Name must be at least 3 characters'), findsOneWidget);

      // Enter a single character
      await tester.enterText(nameTextField, 'a');
      await tester.pump();

      // Error should still be shown
      expect(find.text('Name must be at least 3 characters'), findsOneWidget);

      // Enter empty string
      await tester.enterText(nameTextField, '');
      await tester.pump();

      // Error should still be shown
      expect(find.text('Name must be at least 3 characters'), findsOneWidget);
    });

    // Test error text for empty API key
    testWidgets('should show correct error text when API key is empty',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          onSave: (_) {},
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Find the API key field (third TextField)
      final apiKeyField = find.byType(TextField).at(2);

      // Enter valid API key, then clear
      await tester.enterText(apiKeyField, 'valid-api-key');
      await tester.pump();

      // No error should be shown for valid input
      expect(find.text('API key cannot be empty'), findsNothing);

      // Enter empty API key
      await tester.enterText(apiKeyField, '');
      await tester.pump();

      // Error message should appear
      expect(find.text('API key cannot be empty'), findsOneWidget);
    });

    // Test error text for invalid URL
    testWidgets('should show correct error text for invalid URL',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          onSave: (_) {},
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Find the base URL field (second TextField)
      final baseUrlField = find.byType(TextField).at(1);

      // Enter valid URL
      await tester.enterText(baseUrlField, 'https://example.com');
      await tester.pump();

      // No error should be shown for valid input
      expect(find.text('Please enter a valid URL'), findsNothing);

      // Enter an invalid URL without protocol
      await tester.enterText(baseUrlField, 'example.com');
      await tester.pump();

      // Error message should appear
      expect(find.text('Please enter a valid URL'), findsOneWidget);

      // Enter another invalid URL
      await tester.enterText(baseUrlField, 'not-a-url');
      await tester.pump();

      // Error should still be shown
      expect(find.text('Please enter a valid URL'), findsOneWidget);

      // Enter empty string - for base URL, empty is valid since it's optional
      await tester.enterText(baseUrlField, '');
      await tester.pump();

      // For an empty URL, no validation message should appear
      expect(find.text('Please enter a valid URL'), findsNothing);
    });

    testWidgets('tapping provider type field opens modal sheet',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          onSave: (_) {},
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Find and tap the provider type field using the InputDecorator label
      final providerTypeField = find.ancestor(
        of: find.text('Provider Type'),
        matching: find.byType(InputDecorator),
      );
      expect(providerTypeField, findsOneWidget);

      // Cannot fully test the modal in widget tests as it uses a Navigator
      // This just verifies the field's parent InkWell is tappable
      final inkWell = find.ancestor(
        of: providerTypeField,
        matching: find.byType(InkWell),
      );
      expect(inkWell, findsOneWidget);
      expect(tester.widget<InkWell>(inkWell).onTap, isNotNull);
    });

    testWidgets('new form should properly initialize controller',
        (WidgetTester tester) async {
      // Create a controller to track the form state
      // ignore: unused_local_variable
      AiConfig? savedConfig;

      await tester.pumpWidget(
        buildTestWidget(
          onSave: (config) {
            savedConfig = config;
          },
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Directly test the controller without relying on UI interactions
      final formFinder = find.byType(InferenceProviderForm);

      // Check that we found the form
      expect(formFinder, findsOneWidget);

      final providerContainer = ProviderScope.containerOf(
        tester.element(formFinder),
      );

      // Manually enter values into the controller
      final controller = providerContainer.read(
        inferenceProviderFormControllerProvider(configId: null).notifier,
      )

        // Update the form values through the controller
        ..nameChanged('Test Name')
        ..baseUrlChanged('https://test.example.com')
        ..apiKeyChanged('test-api-key')
        ..descriptionChanged('Test description')
        ..inferenceProviderTypeChanged(InferenceProviderType.anthropic);

      // Verify the controller has the correct values
      final formState = controller.state.valueOrNull;
      expect(formState, isNotNull);
      expect(formState!.name.value, 'Test Name');
      expect(formState.baseUrl.value, 'https://test.example.com');
      expect(formState.apiKey.value, 'test-api-key');
      expect(formState.description.value, 'Test description');
      expect(formState.inferenceProviderType, InferenceProviderType.anthropic);

      // Convert to AiConfig and check values
      final config = formState.toAiConfig();
      expect(config.name, 'Test Name');

      // Use maybeMap to access implementation-specific fields
      expect(
        config.maybeMap(
          inferenceProvider: (c) => c.baseUrl,
          orElse: () => '',
        ),
        'https://test.example.com',
      );

      expect(
        config.maybeMap(
          inferenceProvider: (c) => c.description,
          orElse: () => null,
        ),
        'Test description',
      );

      expect(
        config.maybeMap(
          inferenceProvider: (c) => c.inferenceProviderType,
          orElse: () => null,
        ),
        InferenceProviderType.anthropic,
      );
    });
  });
}
