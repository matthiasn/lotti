import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/prompt_form_controller.dart';
import 'package:lotti/features/ai/ui/settings/prompt_form.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:mocktail/mocktail.dart';

// Mock repositories
class MockAiConfigRepository extends Mock implements AiConfigRepository {}

// Fake class for fallback value registration
class FakeAiConfig extends Fake implements AiConfig {}

// Helper to build a testable widget for create mode
Widget buildTestWidget({
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
            configId: config?.id,
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
    aiResponseType: AiResponseType.taskSummary,
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
    aiResponseType: AiResponseType.taskSummary,
  );
}

void main() {
  late MockAiConfigRepository mockRepository;

  setUpAll(() {
    registerFallbackValue(FakeAiConfig());
  });

  setUp(() {
    mockRepository = MockAiConfigRepository();
    getIt.registerSingleton<AiConfigRepository>(mockRepository);
  });

  tearDown(getIt.reset);

  group('PromptForm ValidationErrors Tests', () {
    // Test name field validation error
    testWidgets('should display localized error when name is too short',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          config: null,
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
          config: null,
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
          config: null,
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
          config: null,
        ),
      );

      await tester.pump(); // Initial pump
      await tester
          .pump(const Duration(milliseconds: 500)); // Allow controller to build

      final context = tester.element(find.byType(PromptForm));

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
      // Removed Category and Comment label checks for now as their UI isn't standard TextFields

      // Save button is now in the app bar, not in the form
      // expect(find.byType(FilledButton), findsOneWidget);
      // expect(
      //   find.text(context.messages.aiConfigCreateButtonLabel),
      //   findsOneWidget,
      // );
    });

    testWidgets(
        'should be able to toggle Use Reasoning switch and reflect in state',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          config: null,
        ),
      );

      await tester.pump(); // Initial pump
      await tester
          .pump(const Duration(milliseconds: 500)); // Allow controller to build

      // Find the switch
      final switchFinder = find.byType(SwitchListTile);
      expect(switchFinder, findsOneWidget);

      // Initial state is off
      var switchWidget = tester.widget<SwitchListTile>(switchFinder);
      expect(switchWidget.value, isFalse);

      // Ensure the switch is visible before tapping
      await tester.ensureVisible(switchFinder);
      await tester.pumpAndSettle();

      // Tap the switch
      await tester.tap(switchFinder);
      await tester
          .pumpAndSettle(); // Use pumpAndSettle for state changes to propagate

      switchWidget = tester.widget<SwitchListTile>(switchFinder);
      expect(switchWidget.value, isTrue);

      // Ensure the switch is visible before tapping again
      await tester.ensureVisible(switchFinder);
      await tester.pumpAndSettle();

      // Tap again to turn off
      await tester.tap(switchFinder);
      await tester.pumpAndSettle(); // Use pumpAndSettle

      switchWidget = tester.widget<SwitchListTile>(switchFinder);
      expect(switchWidget.value, isFalse);
    });
  });

  group('PromptForm Edit Mode Tests', () {
    testWidgets(
        'should load form in edit mode with fields pre-filled and correct button label',
        (WidgetTester tester) async {
      final testTime = DateTime.now();
      final config = createTestPrompt(
        id: 'edit-id-123',
        name: 'Edit Name',
        systemMessage: 'Edit System Message',
        userMessage: 'Edit User Message {{var}}',
        defaultModelId: 'edit-model-id',
        modelIds: ['edit-model-id', 'another-model'],
        useReasoning: true,
        requiredInputData: [InputDataType.task, InputDataType.images],
        comment: 'Edit Comment',
        description: 'Edit Description',
        category: 'Edit Category',
        defaultVariables: {'var': 'editValue'},
        createdAt: testTime,
      );
      final configId = config.id;

      when(() => mockRepository.getConfigById(configId))
          .thenAnswer((_) async => config as AiConfigPrompt);

      await tester.pumpWidget(
        MaterialApp(
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
              child: SingleChildScrollView(
                child: PromptForm(
                  configId: config.id,
                ),
              ),
            ),
          ),
        ),
      );

      // Allow controller to build and load config
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final context = tester.element(find.byType(PromptForm));
      final formController = ProviderScope.containerOf(context)
          .read(promptFormControllerProvider(configId: configId).notifier);

      // Save button is now in the app bar, not in the form
      // expect(
      //   find.widgetWithText(
      //     FilledButton,
      //     context.messages.aiConfigUpdateButtonLabel,
      //   ),
      //   findsOneWidget,
      // );
      // expect(
      //   find.text(context.messages.aiConfigCreateButtonLabel),
      //   findsNothing,
      // );

      // Verify fields are pre-filled by checking controller text
      expect(formController.nameController.text, 'Edit Name');
      expect(
        formController.systemMessageController.text,
        'Edit System Message',
      );
      expect(
        formController.userMessageController.text,
        'Edit User Message {{var}}',
      );
      expect(formController.descriptionController.text, 'Edit Description');
      // Category and Comment checks removed

      // Verify switch state from controller's state
      final formState = ProviderScope.containerOf(context)
          .read(promptFormControllerProvider(configId: configId))
          .value;
      expect(formState?.useReasoning, isTrue);
    });
  });

  group('PromptForm - Preconfigured Prompts', () {
    testWidgets(
        'should show preconfigured prompt button when creating new prompt',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        buildTestWidget(
          config: null,
        ),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Use Preconfigured Prompt'), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome_outlined), findsOneWidget);
    });

    testWidgets(
        'should not show preconfigured prompt button when editing existing prompt',
        (WidgetTester tester) async {
      // Arrange
      final existingPrompt = AiConfigPrompt(
        id: 'existing-id',
        name: 'Existing Prompt',
        systemMessage: 'System',
        userMessage: 'User',
        defaultModelId: 'model-id',
        modelIds: ['model-id'],
        createdAt: DateTime.now(),
        useReasoning: false,
        requiredInputData: [],
        aiResponseType: AiResponseType.taskSummary,
      );

      when(() => mockRepository.getConfigById('existing-id'))
          .thenAnswer((_) async => existingPrompt);

      await tester.pumpWidget(
        buildTestWidget(
          config: existingPrompt,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Assert
      expect(find.text('Use Preconfigured Prompt'), findsNothing);
      expect(find.byIcon(Icons.auto_awesome_outlined), findsNothing);
    });

    testWidgets('should open modal when preconfigured prompt button is tapped',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        buildTestWidget(
          config: null,
        ),
      );
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.text('Use Preconfigured Prompt'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Select Preconfigured Prompt'), findsOneWidget);
      expect(find.text('Task Summary'), findsOneWidget);
      expect(find.text('Action Item Suggestions'), findsOneWidget);
      expect(find.text('Image Analysis'), findsOneWidget);
      expect(find.text('Audio Transcription'), findsOneWidget);
    });

    testWidgets('should populate form fields when task summary is selected',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        buildTestWidget(
          config: null,
        ),
      );
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.text('Use Preconfigured Prompt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Task Summary'));
      await tester.pumpAndSettle();

      // Assert
      final nameField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            (widget.decoration?.labelText?.contains('Name') ?? false),
      );
      expect(tester.widget<TextField>(nameField).controller?.text,
          equals('Task Summary'));

      final systemMessageField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            (widget.decoration?.labelText?.contains('System Message') ?? false),
      );
      expect(
        tester.widget<TextField>(systemMessageField).controller?.text,
        contains('helpful AI assistant'),
      );

      final userMessageField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            (widget.decoration?.labelText?.contains('User Message') ?? false),
      );
      expect(
        tester.widget<TextField>(userMessageField).controller?.text,
        contains('Create a task summary'),
      );
    });

    testWidgets(
        'should populate form fields when action item suggestions is selected',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        buildTestWidget(
          config: null,
        ),
      );
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.text('Use Preconfigured Prompt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Action Item Suggestions'));
      await tester.pumpAndSettle();

      // Assert
      final nameField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            (widget.decoration?.labelText?.contains('Name') ?? false),
      );
      expect(tester.widget<TextField>(nameField).controller?.text,
          equals('Action Item Suggestions'));

      final userMessageField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            (widget.decoration?.labelText?.contains('User Message') ?? false),
      );
      expect(
        tester.widget<TextField>(userMessageField).controller?.text,
        contains('identify potential action items'),
      );
    });

    testWidgets('should populate form fields when image analysis is selected',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        buildTestWidget(
          config: null,
        ),
      );
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.text('Use Preconfigured Prompt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Image Analysis'));
      await tester.pumpAndSettle();

      // Assert
      final nameField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            (widget.decoration?.labelText?.contains('Name') ?? false),
      );
      expect(tester.widget<TextField>(nameField).controller?.text,
          equals('Image Analysis'));

      final userMessageField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            (widget.decoration?.labelText?.contains('User Message') ?? false),
      );
      expect(
        tester.widget<TextField>(userMessageField).controller?.text,
        contains('analyze the provided image'),
      );
    });

    testWidgets(
        'should populate form fields when audio transcription is selected',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        buildTestWidget(
          config: null,
        ),
      );
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.text('Use Preconfigured Prompt'));
      await tester.pumpAndSettle();

      // Ensure the Audio Transcription option is visible
      await tester.ensureVisible(find.text('Audio Transcription'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Audio Transcription'));
      await tester.pumpAndSettle();

      // Assert
      final nameField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            (widget.decoration?.labelText?.contains('Name') ?? false),
      );
      expect(tester.widget<TextField>(nameField).controller?.text,
          equals('Audio Transcription'));

      final userMessageField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            (widget.decoration?.labelText?.contains('User Message') ?? false),
      );
      expect(
        tester.widget<TextField>(userMessageField).controller?.text,
        contains('transcribe the provided audio'),
      );
    });

    testWidgets('should allow editing populated fields after selection',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        buildTestWidget(
          config: null,
        ),
      );
      await tester.pumpAndSettle();

      // Act - Select a preconfigured prompt
      await tester.tap(find.text('Use Preconfigured Prompt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Task Summary'));
      await tester.pumpAndSettle();

      // Act - Edit the name field
      final nameField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            (widget.decoration?.labelText?.contains('Name') ?? false),
      );
      await tester.enterText(nameField, 'Custom Task Summary');
      await tester.pumpAndSettle();

      // Assert
      expect(tester.widget<TextField>(nameField).controller?.text,
          equals('Custom Task Summary'));
    });

    testWidgets('should cancel modal when tapped outside',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        buildTestWidget(
          config: null,
        ),
      );
      await tester.pumpAndSettle();

      // Act - Open modal
      await tester.tap(find.text('Use Preconfigured Prompt'));
      await tester.pumpAndSettle();

      // Verify modal is open
      expect(find.text('Select Preconfigured Prompt'), findsOneWidget);

      // Act - Tap outside modal (on the barrier)
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // Assert - Modal should be closed
      expect(find.text('Select Preconfigured Prompt'), findsNothing);

      // Verify form fields are not populated
      final nameField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            (widget.decoration?.labelText?.contains('Name') ?? false),
      );
      expect(tester.widget<TextField>(nameField).controller?.text, isEmpty);
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
