import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/api_key_form_controller.dart';
import 'package:lotti/features/ai/ui/settings/api_key_form.dart';
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
          child: ApiKeyForm(
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
      expect(find.text('Name'), findsOneWidget);
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
      final formFinder = find.byType(ApiKeyForm);

      // Check that we found the form
      expect(formFinder, findsOneWidget);

      final providerContainer = ProviderScope.containerOf(
        tester.element(formFinder),
      );

      // Manually enter values into the controller
      final controller = providerContainer
          .read(apiKeyFormControllerProvider(configId: null).notifier)

        // Update the form values through the controller
        ..nameChanged('Test Name')
        ..baseUrlChanged('https://test.example.com')
        ..apiKeyChanged('test-api-key')
        ..commentChanged('Test comment')
        ..inferenceProviderTypeChanged(InferenceProviderType.anthropic);

      // Verify the controller has the correct values
      final formState = controller.state.valueOrNull;
      expect(formState, isNotNull);
      expect(formState!.name.value, 'Test Name');
      expect(formState.baseUrl.value, 'https://test.example.com');
      expect(formState.apiKey.value, 'test-api-key');
      expect(formState.comment.value, 'Test comment');
      expect(formState.inferenceProviderType, InferenceProviderType.anthropic);

      // Convert to AiConfig and check values
      final config = formState.toAiConfig();
      expect(config.name, 'Test Name');

      // Use maybeMap to access implementation-specific fields
      expect(
        config.maybeMap(
          apiKey: (c) => c.baseUrl,
          orElse: () => '',
        ),
        'https://test.example.com',
      );

      expect(
        config.maybeMap(
          apiKey: (c) => c.comment,
          orElse: () => null,
        ),
        'Test comment',
      );

      expect(
        config.maybeMap(
          apiKey: (c) => c.inferenceProviderType,
          orElse: () => null,
        ),
        InferenceProviderType.anthropic,
      );
    });
  });
}
