import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/prompt_form_state.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/prompt_form_controller.dart';
import 'package:lotti/features/ai/ui/settings/enhanced_prompt_form.dart';
import 'package:lotti/features/ai/ui/settings/prompt_form_select_model.dart';
import 'package:lotti/features/ai/ui/settings/prompt_input_type_selection.dart';
import 'package:lotti/features/ai/ui/settings/prompt_response_type_selection.dart';
import 'package:lotti/features/ai/ui/widgets/enhanced_form_field.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

/// Mock repository for testing
class MockAiConfigRepository extends Mock implements AiConfigRepository {}

/// Fake controller for testing prompt form behavior
class FakePromptFormController extends PromptFormController {
  PromptFormState? initialStateForBuild = PromptFormState();

  String get debugLabel => 'FakePromptFormController';

  /// Method to emit a new state for testing
  void emitNewStateForTest(PromptFormState? newState) {
    state = AsyncData<PromptFormState?>(newState);
  }

  @override
  Future<PromptFormState?> build({required String? configId}) async {
    state = AsyncData<PromptFormState?>(initialStateForBuild);
    return initialStateForBuild;
  }

  @override
  void nameChanged(String name) {}
  @override
  void userMessageChanged(String userMessage) {}
  @override
  void systemMessageChanged(String systemMessage) {}
  @override
  void descriptionChanged(String description) {}
  void inputTypeChanged(String inputType) {}
  void responseTypeChanged(String responseType) {}
  @override
  void useReasoningChanged(bool useReasoning) {}
  @override
  void modelIdsChanged(List<String> modelIds) {}
  @override
  void defaultModelIdChanged(String defaultModelId) {}
  @override
  void populateFromPreconfiguredPrompt(Object selectedPrompt) {}
  @override
  Future<void> addConfig(AiConfig config) async {}
  @override
  Future<void> updateConfig(AiConfig config) async {}
  @override
  Future<CascadeDeletionResult> deleteConfig(String id) async {
    return const CascadeDeletionResult(deletedModels: [], providerName: '');
  }

  @override
  void reset() {}
}

/// Test class for enhanced prompt form
void main() {
  late MockAiConfigRepository mockRepository;

  setUpAll(() {
    registerFallbackValue(
      AiConfig.prompt(
        id: 'fallback-id',
        name: 'Fallback Prompt',
        systemMessage: 'Fallback system message',
        userMessage: 'Fallback user message',
        createdAt: DateTime.now(),
        modelIds: const ['model-1'],
        defaultModelId: 'model-1',
        requiredInputData: const [],
        aiResponseType: AiResponseType.taskSummary,
        useReasoning: false,
      ),
    );
  });

  setUp(() {
    mockRepository = MockAiConfigRepository();
    when(() => mockRepository.saveConfig(any())).thenAnswer((_) async {});
  });

  /// Helper function to build the widget under test
  Widget buildTestWidget({
    required FakePromptFormController formController,
    String? configId,
  }) {
    return ProviderScope(
      overrides: [
        aiConfigRepositoryProvider.overrideWithValue(mockRepository),
        promptFormControllerProvider(configId: configId)
            .overrideWith(() => formController),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: EnhancedPromptForm(configId: configId),
        ),
      ),
    );
  }

  /// Helper function to create a valid form state
  PromptFormState createValidFormState({
    String name = 'Test Prompt',
    String userMessage = 'Test user message {{input}}',
    String systemMessage = 'Test system message',
    String description = 'Test description',
    List<InputDataType> requiredInputData = const [],
    AiResponseType aiResponseType = AiResponseType.taskSummary,
    bool useReasoning = false,
    List<String> modelIds = const ['model-1'],
    String defaultModelId = 'model-1',
  }) {
    return PromptFormState(
      name: PromptName.dirty(name),
      userMessage: PromptUserMessage.dirty(userMessage),
      systemMessage: PromptSystemMessage.dirty(systemMessage),
      description: PromptDescription.dirty(description),
      requiredInputData: requiredInputData,
      aiResponseType: PromptAiResponseType.dirty(aiResponseType),
      useReasoning: useReasoning,
      modelIds: modelIds,
      defaultModelId: defaultModelId,
    );
  }

  group('EnhancedPromptForm Tests', () {
    testWidgets('should render form with all required sections',
        (tester) async {
      // Arrange
      final fakeFormController = FakePromptFormController()
        ..initialStateForBuild = PromptFormState();

      // Act
      await tester
          .pumpWidget(buildTestWidget(formController: fakeFormController));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(EnhancedPromptForm), findsOneWidget);
      expect(
          find.text(
              'Create custom prompts that can be used with your AI models to generate specific types of responses'),
          findsOneWidget);

      // Check for form sections
      expect(find.text('Basic Configuration'), findsOneWidget);
      expect(find.text('Prompt Configuration'), findsOneWidget);
      expect(find.text('Configuration Options'), findsOneWidget);
      expect(find.text('Additional Details'), findsOneWidget);
    });

    testWidgets('should show Quick Start section for new prompts',
        (tester) async {
      // Arrange - null configId indicates new prompt
      final fakeFormController = FakePromptFormController()
        ..initialStateForBuild = PromptFormState();

      // Act
      await tester.pumpWidget(buildTestWidget(
        formController: fakeFormController,
      ));
      await tester.pumpAndSettle();

      // Assert - Quick Start section should be visible
      expect(find.text('Quick Start'), findsOneWidget);
      expect(
          find.text('Choose from ready-made prompt templates'), findsOneWidget);
      expect(find.byIcon(Icons.rocket_launch_outlined), findsOneWidget);
    });

    testWidgets('should not show Quick Start section for existing prompts',
        (tester) async {
      // Arrange - non-null configId indicates existing prompt
      final fakeFormController = FakePromptFormController()
        ..initialStateForBuild = PromptFormState();

      // Act
      await tester.pumpWidget(buildTestWidget(
        configId: 'existing-prompt-id',
        formController: fakeFormController,
      ));
      await tester.pumpAndSettle();

      // Assert - Quick Start section should not be visible
      expect(find.text('Quick Start'), findsNothing);
    });

    testWidgets('should display all form fields with proper labels',
        (tester) async {
      // Arrange
      final fakeFormController = FakePromptFormController()
        ..initialStateForBuild = PromptFormState();

      // Act
      await tester
          .pumpWidget(buildTestWidget(formController: fakeFormController));
      await tester.pumpAndSettle();

      // Assert - check for form fields
      expect(
          find.byType(EnhancedFormField),
          findsAtLeastNWidgets(
              2)); // Name, User Message, System Message, Description (actual count varies)

      // Check field labels
      expect(find.text('Display Name'), findsOneWidget);
      expect(find.text('User Message'), findsOneWidget);
      expect(find.text('System Message'), findsOneWidget);
      expect(find.text('Description'), findsOneWidget);

      // Check for model selection
      expect(find.byType(PromptFormSelectModel), findsOneWidget);

      // Check for input/response type selections
      expect(find.byType(PromptInputTypeSelection), findsOneWidget);
      expect(find.byType(PromptResponseTypeSelection), findsOneWidget);

      // Check for reasoning toggle
      expect(find.text('Use Reasoning'), findsAtLeastNWidgets(1));
    });

    testWidgets('should display required field indicators', (tester) async {
      // Arrange
      final fakeFormController = FakePromptFormController()
        ..initialStateForBuild = PromptFormState();

      // Act
      await tester
          .pumpWidget(buildTestWidget(formController: fakeFormController));
      await tester.pumpAndSettle();

      // Assert - check for required asterisks
      expect(find.text(' *'),
          findsAtLeastNWidgets(2)); // Display Name, User Message
    });

    testWidgets('should show helper text for form fields', (tester) async {
      // Arrange
      final fakeFormController = FakePromptFormController()
        ..initialStateForBuild = PromptFormState();

      // Act
      await tester
          .pumpWidget(buildTestWidget(formController: fakeFormController));
      await tester.pumpAndSettle();

      // Assert - check for helper texts
      expect(find.text('A descriptive name for this prompt template'),
          findsOneWidget);
      expect(
          find.text(
              'The main prompt text. Use {{variables}} for dynamic content.'),
          findsOneWidget);
      expect(
          find.text(
              "Instructions that define the AI's behavior and response style"),
          findsOneWidget);
      expect(find.text("Optional notes about this prompt's purpose and usage"),
          findsOneWidget);
    });

    testWidgets(
        'should display preconfigured prompt button with gradient styling',
        (tester) async {
      // Arrange
      final fakeFormController = FakePromptFormController()
        ..initialStateForBuild = PromptFormState();

      // Act
      await tester.pumpWidget(buildTestWidget(
        formController: fakeFormController,
      ));
      await tester.pumpAndSettle();

      // Assert - check for preconfigured prompt button
      final gradientContainer = find.byWidgetPredicate((widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration! as BoxDecoration).gradient != null);
      expect(gradientContainer, findsAtLeastNWidgets(1));

      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
    });

    testWidgets('should display model selection card with proper styling',
        (tester) async {
      // Arrange
      final fakeFormController = FakePromptFormController()
        ..initialStateForBuild = PromptFormState();

      // Act
      await tester
          .pumpWidget(buildTestWidget(formController: fakeFormController));
      await tester.pumpAndSettle();

      // Assert - model selection should be wrapped in styled container
      expect(find.byType(PromptFormSelectModel), findsOneWidget);

      // Check for container styling around model selection
      final styledContainer = find.ancestor(
        of: find.byType(PromptFormSelectModel),
        matching: find.byWidgetPredicate((widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).borderRadius != null),
      );
      expect(styledContainer, findsAtLeastNWidgets(1));
    });

    testWidgets('should display configuration option rows with icons',
        (tester) async {
      // Arrange
      final fakeFormController = FakePromptFormController()
        ..initialStateForBuild = PromptFormState();

      // Act
      await tester
          .pumpWidget(buildTestWidget(formController: fakeFormController));
      await tester.pumpAndSettle();

      // Assert - check for configuration option titles and icons
      expect(find.text('Required Input Data'), findsAtLeastNWidgets(1));
      expect(find.text('AI Response Type'), findsAtLeastNWidgets(1));
      expect(find.text('Type of data this prompt expects'), findsOneWidget);
      expect(find.text('Format of the expected response'), findsOneWidget);

      // Check for icons
      expect(find.byIcon(Icons.input_rounded), findsOneWidget);
      expect(find.byIcon(Icons.output_rounded), findsOneWidget);
    });

    testWidgets('should display reasoning toggle with proper styling',
        (tester) async {
      // Arrange
      final fakeFormController = FakePromptFormController()
        ..initialStateForBuild = createValidFormState();

      // Act
      await tester
          .pumpWidget(buildTestWidget(formController: fakeFormController));
      await tester.pumpAndSettle();

      // Assert - check for reasoning toggle card
      expect(find.byType(Switch), findsOneWidget);
      expect(find.byIcon(Icons.psychology_outlined), findsAtLeastNWidgets(1));

      // Check for styled containers
      final styledContainers = find.byWidgetPredicate((widget) =>
          widget is Container && widget.decoration is BoxDecoration);
      expect(styledContainers,
          findsAtLeastNWidgets(1)); // At least one styled container
    });

    testWidgets('should display modern styling elements', (tester) async {
      // Arrange
      final fakeFormController = FakePromptFormController()
        ..initialStateForBuild = PromptFormState();

      // Act
      await tester
          .pumpWidget(buildTestWidget(formController: fakeFormController));
      await tester.pumpAndSettle();

      // Assert - check for modern styling containers
      final containers = find.byType(Container);
      expect(
          containers, findsAtLeastNWidgets(10)); // Multiple styled containers

      // Check for section icons
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
      expect(find.byIcon(Icons.edit_note_rounded), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
      expect(find.byIcon(Icons.description_outlined), findsOneWidget);
    });

    testWidgets('should show loading indicator when form state is null',
        (tester) async {
      // Arrange
      final fakeFormController = FakePromptFormController()
        ..initialStateForBuild = null; // null state to show loading

      // Act
      await tester
          .pumpWidget(buildTestWidget(formController: fakeFormController));
      await tester.pump(); // Just pump once to start loading

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should maintain scroll behavior for long forms',
        (tester) async {
      // Arrange
      final fakeFormController = FakePromptFormController()
        ..initialStateForBuild = PromptFormState();

      // Act
      await tester
          .pumpWidget(buildTestWidget(formController: fakeFormController));
      await tester.pumpAndSettle();

      // Assert - form should be scrollable
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('should apply Series A quality visual design', (tester) async {
      // Arrange
      final fakeFormController = FakePromptFormController()
        ..initialStateForBuild = PromptFormState();

      // Act
      await tester
          .pumpWidget(buildTestWidget(formController: fakeFormController));
      await tester.pumpAndSettle();

      // Assert - check for professional spacing and layout
      final sizedBoxes = find.byType(SizedBox);
      expect(sizedBoxes, findsAtLeastNWidgets(10)); // Multiple spacing elements

      // Check for proper padding and margins
      final paddedWidgets = find.byWidgetPredicate(
          (widget) => widget is Padding && widget.padding != EdgeInsets.zero);
      expect(paddedWidgets, findsAtLeastNWidgets(5));
    });

    testWidgets('should handle form state updates correctly', (tester) async {
      // Arrange
      final fakeFormController = FakePromptFormController()
        ..initialStateForBuild = PromptFormState();

      await tester
          .pumpWidget(buildTestWidget(formController: fakeFormController));
      await tester.pumpAndSettle();

      // Act - update form state with valid data
      fakeFormController.emitNewStateForTest(createValidFormState());
      await tester.pumpAndSettle();

      // Assert - form should update without errors
      expect(find.byType(EnhancedPromptForm), findsOneWidget);
    });
  });

  group('EnhancedPromptForm Integration Tests', () {
    testWidgets('should integrate with form controller properly',
        (tester) async {
      // Arrange
      final fakeFormController = FakePromptFormController()
        ..initialStateForBuild = createValidFormState();

      // Act
      await tester
          .pumpWidget(buildTestWidget(formController: fakeFormController));
      await tester.pumpAndSettle();

      // Assert - form should display with valid controller state
      expect(find.byType(EnhancedPromptForm), findsOneWidget);
      expect(find.byType(EnhancedFormField), findsAtLeastNWidgets(1));
    });

    testWidgets('should handle configuration editing mode', (tester) async {
      // Arrange
      final fakeFormController = FakePromptFormController()
        ..initialStateForBuild = createValidFormState(
          name: 'Existing Prompt',
          userMessage: 'Existing user message {{variable}}',
          systemMessage: 'Existing system message',
          useReasoning: true,
        );

      // Act
      await tester.pumpWidget(buildTestWidget(
        configId: 'existing-prompt-id',
        formController: fakeFormController,
      ));
      await tester.pumpAndSettle();

      // Assert - form should be in edit mode (no Quick Start section)
      expect(find.byType(EnhancedPromptForm), findsOneWidget);
      expect(find.byType(EnhancedFormField), findsAtLeastNWidgets(1));
      expect(find.text('Quick Start'),
          findsNothing); // Should not show for existing prompts
    });

    testWidgets('should display all form sections in correct order',
        (tester) async {
      // Arrange
      final fakeFormController = FakePromptFormController()
        ..initialStateForBuild = PromptFormState();

      // Act
      await tester.pumpWidget(buildTestWidget(
        formController: fakeFormController,
      ));
      await tester.pumpAndSettle();

      // Assert - check that sections appear in expected order by finding their vertical positions
      final quickStartFinder = find.text('Quick Start');
      final basicConfigFinder = find.text('Basic Configuration');
      final promptConfigFinder = find.text('Prompt Configuration');
      final configOptionsFinder = find.text('Configuration Options');
      final additionalDetailsFinder = find.text('Additional Details');

      expect(quickStartFinder, findsOneWidget);
      expect(basicConfigFinder, findsOneWidget);
      expect(promptConfigFinder, findsOneWidget);
      expect(configOptionsFinder, findsOneWidget);
      expect(additionalDetailsFinder, findsOneWidget);

      // Verify vertical ordering by checking widget positions
      final quickStartPos = tester.getTopLeft(quickStartFinder);
      final basicConfigPos = tester.getTopLeft(basicConfigFinder);
      final promptConfigPos = tester.getTopLeft(promptConfigFinder);
      final configOptionsPos = tester.getTopLeft(configOptionsFinder);
      final additionalDetailsPos = tester.getTopLeft(additionalDetailsFinder);

      expect(quickStartPos.dy < basicConfigPos.dy, isTrue);
      expect(basicConfigPos.dy < promptConfigPos.dy, isTrue);
      expect(promptConfigPos.dy < configOptionsPos.dy, isTrue);
      expect(configOptionsPos.dy < additionalDetailsPos.dy, isTrue);
    });

    testWidgets('should handle multiline text fields properly', (tester) async {
      // Arrange
      final fakeFormController = FakePromptFormController()
        ..initialStateForBuild = createValidFormState();

      // Act
      await tester
          .pumpWidget(buildTestWidget(formController: fakeFormController));
      await tester.pumpAndSettle();

      // Assert - check for multiline text fields (now using minLines instead of maxLines)
      final multilineFields = find.byWidgetPredicate((widget) =>
          widget is EnhancedFormField &&
          widget.minLines != null &&
          widget.minLines! >= 3);
      expect(multilineFields,
          findsAtLeastNWidgets(1)); // User Message, System Message, Description
    });
  });
}
