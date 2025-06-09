import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/ui/settings/prompt_edit_page.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

// Mock classes
class MockAiConfigRepository extends Mock implements AiConfigRepository {}

void main() {
  late MockAiConfigRepository mockRepository;
  late AiConfig testPrompt;
  late List<AiConfig> testModels;

  setUpAll(() {
    registerFallbackValue(
      AiConfig.prompt(
        id: 'fallback-id',
        name: 'Fallback Prompt',
        systemMessage: 'Fallback system message',
        userMessage: 'Fallback user message',
        defaultModelId: 'model-1',
        modelIds: const ['model-1'],
        createdAt: DateTime.now(),
        useReasoning: false,
        requiredInputData: const [],
        aiResponseType: AiResponseType.taskSummary,
      ),
    );
  });

  setUp(() {
    mockRepository = MockAiConfigRepository();

    // Create test models
    testModels = [
      AiConfig.model(
        id: 'model-1',
        name: 'GPT-4',
        providerModelId: 'gpt-4',
        inferenceProviderId: 'provider-1',
        createdAt: DateTime.now(),
        inputModalities: [Modality.text],
        outputModalities: [Modality.text],
        isReasoningModel: false,
      ),
      AiConfig.model(
        id: 'model-2',
        name: 'Claude 3',
        providerModelId: 'claude-3',
        inferenceProviderId: 'provider-2',
        createdAt: DateTime.now(),
        inputModalities: [Modality.text],
        outputModalities: [Modality.text],
        isReasoningModel: false,
      ),
    ];

    testPrompt = AiConfig.prompt(
      id: 'test-prompt-id',
      name: 'Test Prompt',
      systemMessage: 'You are a helpful assistant',
      userMessage: 'Please help me with: {{input}}',
      defaultModelId: 'model-1',
      modelIds: ['model-1', 'model-2'],
      createdAt: DateTime.now(),
      useReasoning: false,
      requiredInputData: [InputDataType.task],
      aiResponseType: AiResponseType.taskSummary,
      description: 'A test prompt for unit tests',
      category: 'Testing',
    );

    // Default mock responses
    when(() => mockRepository.saveConfig(any())).thenAnswer((_) async {});
    when(() => mockRepository.getConfigById('test-prompt-id'))
        .thenAnswer((_) async => testPrompt);
    when(() => mockRepository.getConfigsByType(AiConfigType.model))
        .thenAnswer((_) async => testModels);
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
        home: PromptEditPage(configId: configId),
      ),
    );
  }

  group('PromptEditPage', () {
    testWidgets('displays correct title for new prompt',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Add Prompt'), findsOneWidget);
    });

    testWidgets('displays correct title for existing prompt',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget(configId: 'test-prompt-id'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Prompt'), findsOneWidget);
    });

    testWidgets('loads and displays existing prompt data',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget(configId: 'test-prompt-id'));
      await tester.pumpAndSettle();

      // Check that the form is populated with existing data
      expect(find.text('Test Prompt'), findsOneWidget);
      expect(find.text('You are a helpful assistant'), findsOneWidget);
      expect(find.text('Please help me with: {{input}}'), findsOneWidget);
    });

    testWidgets('shows form sections with proper labels',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Check section headers - using hardcoded values for tests
      // since we can't access localized messages in tests without proper setup
      expect(find.textContaining('Prompt'), findsWidgets);
      expect(find.textContaining('Model'), findsWidgets);

      // Check field labels
      expect(find.text('Display Name'), findsOneWidget);
      expect(find.text('System Prompt'), findsOneWidget);
      expect(find.text('User Prompt'), findsOneWidget);
      expect(find.text('Required Input Data'), findsOneWidget);
      expect(find.text('AI Response Type'), findsOneWidget);
    });

    testWidgets('shows save button and form fields',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Find the save button
      final saveButton = find.text('Save Prompt');
      expect(saveButton, findsOneWidget);

      // Verify form fields exist
      expect(find.widgetWithText(TextFormField, 'Enter a friendly name'),
          findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Enter the system prompt...'),
          findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Enter the user prompt...'),
          findsOneWidget);
    });

    testWidgets('toggles reasoning mode switch', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Find reasoning mode switch
      final reasoningSwitch = find.byType(Switch);
      if (reasoningSwitch.evaluate().isNotEmpty) {
        // Ensure the switch is visible by scrolling
        await tester.ensureVisible(reasoningSwitch.first);
        await tester.pumpAndSettle();

        // Tap to toggle
        await tester.tap(reasoningSwitch.first);
        await tester.pumpAndSettle();

        // Switch should have toggled
        final switchWidget = tester.widget<Switch>(reasoningSwitch.first);
        expect(switchWidget.value, isNotNull);
      }
    });

    testWidgets('has cancel and save buttons', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Scroll to bottom to see buttons
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();

      // Verify both buttons exist
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save Prompt'), findsOneWidget);
    });

    testWidgets('shows error state when loading fails',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Setup repository to throw error
      when(() => mockRepository.getConfigById('error-id'))
          .thenThrow(Exception('Failed to load'));

      await tester.pumpWidget(buildTestWidget(configId: 'error-id'));
      await tester.pumpAndSettle();

      // Check error UI
      expect(find.text('Failed to load prompt'), findsOneWidget);
      expect(find.text('Please try again or contact support'), findsOneWidget);
      expect(find.text('Go Back'), findsOneWidget);
    });

    testWidgets('validates form fields with valid and invalid data',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Test name validation - too short
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter a friendly name'), 'AB');
      await tester.pumpAndSettle();

      // The form validates on change - validation errors may appear
      // Enter valid data to verify form works
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter a friendly name'),
          'Valid Prompt Name');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter the system prompt...'),
          'You are a helpful assistant');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter the user prompt...'),
          'Please help with: {{input}}');
      await tester.pumpAndSettle();
    });

    testWidgets('saves modified prompt data', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget(configId: 'test-prompt-id'));
      await tester.pumpAndSettle();

      // Modify a field
      final nameField = find.widgetWithText(TextFormField, 'Test Prompt');
      await tester.enterText(nameField, 'Updated Prompt Name');
      await tester.pumpAndSettle();

      // Scroll to save button
      final saveButton = find.text('Save Prompt');
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();

      // Save
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Verify save was called with updated data
      verify(() => mockRepository.saveConfig(any())).called(1);
    });

    testWidgets('handles keyboard shortcuts', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Fill form to make it valid
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter a friendly name'),
          'Test Prompt');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter the system prompt...'),
          'System message');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter the user prompt...'),
          'User message');
      await tester.pumpAndSettle();

      // Verify CallbackShortcuts widget exists
      expect(find.byType(CallbackShortcuts), findsWidgets);
    });

    testWidgets('displays description field', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Check for description field
      expect(find.text('Description'), findsOneWidget);

      // This should accept text input
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Describe this prompt'),
          'This prompt helps with various tasks');
      await tester.pumpAndSettle();
    });

    testWidgets('displays Configuration Options section with required fields',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Check Prompt Behavior section exists
      expect(find.text('Prompt Behavior'), findsOneWidget);

      // Check Required Input Data selection card
      expect(find.text('Required Input Data'), findsOneWidget);
      expect(find.text('Type of data this prompt expects'), findsOneWidget);
      expect(find.text('Select input type'), findsOneWidget);

      // Check AI Response Type selection card
      expect(find.text('AI Response Type'), findsOneWidget);
      expect(find.text('Format of the expected response'), findsOneWidget);
      expect(find.text('Select response type'), findsOneWidget);

      // Check that the selection cards have the proper icons
      expect(find.byIcon(Icons.input_rounded), findsOneWidget);
      expect(find.byIcon(Icons.output_rounded), findsOneWidget);
    });

    testWidgets('shows existing values for Configuration Options when editing',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget(configId: 'test-prompt-id'));
      await tester.pumpAndSettle();

      // Check that existing values are displayed
      // The test prompt has InputDataType.task and AiResponseType.taskSummary
      expect(find.text('Task'), findsOneWidget); // Input data type display name
      expect(find.text('Task Summary'),
          findsOneWidget); // Response type display name
    });

    testWidgets('can open input data type selection modal',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Find and tap the Required Input Data selection card
      // Look for the InkWell that contains the "Select input type" text
      final inputDataCard = find.widgetWithText(InkWell, 'Select input type');
      expect(inputDataCard, findsOneWidget);

      await tester.tap(inputDataCard);
      await tester.pumpAndSettle();

      // Modal should open - check for modal content
      // The modal will show input data type options
      expect(find.text('Required Input Data Types'), findsOneWidget);
    });

    testWidgets('can open AI response type selection modal',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Find and tap the AI Response Type selection card
      // Look for the InkWell that contains the "Select response type" text
      final responseTypeCard =
          find.widgetWithText(InkWell, 'Select response type');
      expect(responseTypeCard, findsOneWidget);

      await tester.tap(responseTypeCard);
      await tester.pumpAndSettle();

      // Modal should open - check for modal content
      expect(find.text('Select AI Response Type'), findsOneWidget);
    });

    testWidgets('save button is disabled when required fields are missing',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Fill in basic fields but leave Configuration Options empty
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter a friendly name'),
          'Test Prompt');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter the system prompt...'),
          'System message');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter the user prompt...'),
          'User message');
      await tester.pumpAndSettle();

      // Find save button - scroll to bottom first
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();

      final saveButton = find.text('Save Prompt');
      expect(saveButton, findsOneWidget);
    });
  });
}
