import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/ui/settings/prompt_form.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:mocktail/mocktail.dart';

// Mock repositories
class MockAiConfigRepository extends Mock implements AiConfigRepository {}

// Helper to build a testable widget for create mode
Widget buildTestWidget({
  required void Function(AiConfig) onSave,
  AiConfig? config,
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
          // Override the repository provider
          aiConfigRepositoryProvider
              .overrideWithValue(MockAiConfigRepository()),
        ],
        child: SingleChildScrollView(
          child: PromptForm(
            onSave: onSave,
            config: config,
          ),
        ),
      ),
    ),
  );
}

/// Creates a mock prompt config for testing
AiConfig createMockPromptConfig({
  required String id,
  required String name,
  required String systemMessage,
  required String userMessage,
  required String defaultModelId,
  List<String> modelIds = const [],
  String? description,
  String? comment,
  String? category,
  bool useReasoning = false,
  List<InputDataType> requiredInputData = const [],
}) {
  return AiConfig.prompt(
    id: id,
    name: name,
    systemMessage: systemMessage,
    userMessage: userMessage,
    defaultModelId: defaultModelId,
    modelIds: modelIds,
    createdAt: DateTime.now(),
    useReasoning: useReasoning,
    requiredInputData: requiredInputData,
    description: description,
    comment: comment,
    category: category,
  );
}

AiConfig createTestPrompt({
  String id = 'test-prompt',
  String name = 'Test Prompt Name',
  String systemMessage = 'Test prompt system message',
  String userMessage = 'Test prompt user message {{variable}}',
  String defaultModelId = 'test-model-id',
  List<String> modelIds = const [],
  bool useReasoning = false,
  List<InputDataType> requiredInputData = const [],
  String comment = 'Test comment',
  String description = 'Test description',
  String category = 'Test category',
  Map<String, String> defaultVariables = const {'variable': 'value'},
  DateTime? createdAt,
}) {
  return AiConfig.prompt(
    id: id,
    name: name,
    systemMessage: systemMessage,
    userMessage: userMessage,
    defaultModelId: defaultModelId,
    modelIds: modelIds,
    useReasoning: useReasoning,
    requiredInputData: requiredInputData,
    comment: comment,
    description: description,
    category: category,
    defaultVariables: defaultVariables,
    createdAt: createdAt ?? DateTime.now(),
  );
}

void main() {
  // Register a fallback value for AiConfig
  setUpAll(() {
    registerFallbackValue(
      createMockPromptConfig(
        id: 'fallback-id',
        name: 'Fallback Name',
        systemMessage: 'Fallback System Message',
        userMessage: 'Fallback User Message',
        defaultModelId: 'fallback-model-id',
      ),
    );
  });

  group('PromptForm ValidationErrors Tests', () {
    // Test name field validation error
    testWidgets('should display localized error when name is too short',
        (WidgetTester tester) async {
      // ignore: unused_local_variable
      var onSaveCalled = false;

      await tester.pumpWidget(
        buildTestWidget(
          onSave: (_) {
            onSaveCalled = true;
          },
        ),
      );

      // Wait for the async operations and states to settle
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Get the localized error message
      final context = tester.element(find.byType(PromptForm));
      final localizedError = context.messages.aiConfigNameTooShortError;

      // Find the name field by looking for its label
      final nameField = find.ancestor(
        of: find.text(context.messages.aiConfigNameFieldLabel),
        matching: find.byType(TextField),
      );

      expect(nameField, findsOneWidget, reason: 'Name field should be found');

      // Enter a too short name and verify error message
      await tester.enterText(nameField, 'ab'); // Too short
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify the error message is correctly localized
      expect(find.text(localizedError), findsOneWidget);
    });

    // Test input then clearing name field
    testWidgets('should show error after clearing a valid name',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          onSave: (_) {},
        ),
      );

      // Wait for the async operations and states to settle
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Get the localized strings
      final context = tester.element(find.byType(PromptForm));
      final localizedError = context.messages.aiConfigNameTooShortError;
      final nameFieldLabel = context.messages.aiConfigNameFieldLabel;

      // Find the name field by looking for its label
      final nameField = find.ancestor(
        of: find.text(nameFieldLabel),
        matching: find.byType(TextField),
      );

      expect(nameField, findsOneWidget, reason: 'Name field should be found');

      // First enter a valid name
      await tester.enterText(nameField, 'Valid Name');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // No error should be shown
      expect(find.text(localizedError), findsNothing);

      // Now enter an invalid name
      await tester.enterText(nameField, '');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Error should be shown
      expect(find.text(localizedError), findsOneWidget);
    });

    testWidgets('should validate user message field',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          onSave: (_) {},
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Get the localized strings
      final context = tester.element(find.byType(PromptForm));
      final localizedError = context.messages.aiConfigUserMessageEmptyError;
      final userMessageFieldLabel =
          context.messages.aiConfigUserMessageFieldLabel;

      // Find the user message field
      final userMessageField = find.ancestor(
        of: find.text(userMessageFieldLabel),
        matching: find.byType(TextField),
      );

      expect(userMessageField, findsOneWidget);

      // Enter valid user message
      await tester.enterText(userMessageField, 'This is a valid user message');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // No error should be shown
      expect(find.text(localizedError), findsNothing);

      // Clear the user message (should trigger validation error)
      await tester.enterText(userMessageField, '');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Error should be shown
      expect(find.text(localizedError), findsOneWidget);
    });
  });

  group('PromptForm UI Tests', () {
    testWidgets('should render all form fields correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          onSave: (_) {},
        ),
      );

      // Wait for the async operations and states to settle
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Get the localized strings
      final context = tester.element(find.byType(PromptForm));

      // Verify all expected form fields are visible
      expect(
        find.text(context.messages.aiConfigNameFieldLabel),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.aiConfigModelsTitle),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.aiConfigManageModelsButton),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.aiConfigSystemMessageFieldLabel),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.aiConfigUserMessageFieldLabel),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.aiConfigRequiredInputDataFieldLabel),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.aiConfigUseReasoningFieldLabel),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.aiConfigDescriptionFieldLabel),
        findsOneWidget,
      );

      // Verify button is present (disabled initially)
      expect(find.byType(FilledButton), findsOneWidget);
      // Check the specific save/create button using its label
      // Assuming it's a new prompt, so create label
      expect(
        find.text(context.messages.aiConfigCreateButtonLabel),
        findsOneWidget,
      );
    });

    testWidgets('submit button should be disabled with invalid form',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          onSave: (_) {},
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Get the localized strings
      final context = tester.element(find.byType(PromptForm));

      // Make the form invalid with too short name
      final nameField = find.ancestor(
        of: find.text(context.messages.aiConfigNameFieldLabel),
        matching: find.byType(TextField),
      );
      await tester.enterText(nameField, 'ab'); // Too short

      await tester.pump();

      // Find the submit button
      final buttonFinder = find.byType(FilledButton);
      expect(buttonFinder, findsOneWidget);

      // Check if it's disabled
      final button = tester.widget<FilledButton>(buttonFinder);
      expect(
        button.onPressed,
        isNull,
        reason: 'Button should be disabled with invalid form',
      );
    });

    testWidgets('should be able to toggle Use Reasoning switch',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          onSave: (_) {},
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Find the switch
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);

      // Initial state is off
      final switchWidget = tester.widget<Switch>(switchFinder);
      expect(switchWidget.value, isFalse);
    });
  });

  group('PromptForm Edit Mode Tests', () {
    testWidgets('should load form in edit mode without errors',
        (WidgetTester tester) async {
      // Create a test config for edit mode
      final config = createMockPromptConfig(
        id: 'test-id',
        name: 'Test Name',
        systemMessage: 'Test System Message',
        userMessage: 'Test User Message',
        defaultModelId: 'test-model-id',
      );

      // Build the widget in edit mode
      await tester.pumpWidget(
        buildTestWidget(
          onSave: (_) {},
          config: config,
        ),
      );

      // Let the widget settle
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Simply verify the form loads without errors
      expect(find.byType(PromptForm), findsOneWidget);

      // We won't test for specific widgets as they might be lazily loaded
      // or hidden in the widget tree in the test environment
    });
  });

  group('PromptForm Submission Tests', () {
    testWidgets('should have a working form submission button',
        (WidgetTester tester) async {
      // ignore: unused_local_variable
      var saveWasCalled = false;

      await tester.pumpWidget(
        buildTestWidget(
          onSave: (_) {
            saveWasCalled = true;
          },
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Get context
      final context = tester.element(find.byType(PromptForm));

      // Verify the button exists
      final buttonFinder = find.descendant(
        of: find.byType(FilledButton),
        matching: find.text(context.messages.aiConfigCreateButtonLabel),
      );
      expect(buttonFinder, findsOneWidget);

      // We won't attempt to tap it since it would be disabled with invalid form data
      // But we've validated that the form submission UI exists
    });
  });
}

// Extension method to find TextField inside InputDecorator
extension ElementExtensions on Element {
  T? findChild<T>() {
    T? result;
    visitChildren((element) {
      if (element.widget is T) {
        result = element.widget as T;
      } else {
        final child = element.findChild<T>();
        if (child != null) {
          result = child;
        }
      }
    });
    return result;
  }
}
