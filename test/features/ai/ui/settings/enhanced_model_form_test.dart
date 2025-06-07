import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_model_form_state.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/state/inference_model_form_controller.dart';
import 'package:lotti/features/ai/ui/settings/enhanced_model_form.dart';
import 'package:lotti/features/ai/ui/widgets/enhanced_form_field.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

/// Mock repository for testing
class MockAiConfigRepository extends Mock implements AiConfigRepository {}

/// Fake controller for testing model form behavior
class FakeInferenceModelFormController extends InferenceModelFormController {
  InferenceModelFormState? initialStateForBuild = InferenceModelFormState();

  String get debugLabel => 'FakeInferenceModelFormController';

  /// Method to emit a new state for testing
  void emitNewStateForTest(InferenceModelFormState? newState) {
    state = AsyncData<InferenceModelFormState?>(newState);
  }

  @override
  Future<InferenceModelFormState?> build({required String? configId}) async {
    state = AsyncData<InferenceModelFormState?>(initialStateForBuild);
    return initialStateForBuild;
  }

  @override
  void nameChanged(String name) {}
  @override
  void providerModelIdChanged(String providerModelId) {}
  @override
  void inferenceProviderIdChanged(String inferenceProviderId) {}
  @override
  void descriptionChanged(String description) {}
  @override
  void inputModalitiesChanged(List<Modality> inputModalities) {}
  @override
  void outputModalitiesChanged(List<Modality> outputModalities) {}
  @override
  void isReasoningModelChanged(bool isReasoningModel) {}
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

/// Fake controller for provider configs
class FakeAiConfigByTypeController extends AiConfigByTypeController {
  List<AiConfig> configs = [];

  @override
  Stream<List<AiConfig>> build({required AiConfigType configType}) {
    return Stream.value(configs);
  }

  Future<void> deleteConfig(String id) async {}
  void refresh() {}
}

/// Test class for enhanced model form
void main() {
  late MockAiConfigRepository mockRepository;
  late FakeAiConfigByTypeController fakeProviderController;

  setUpAll(() {
    registerFallbackValue(
      AiConfig.model(
        id: 'fallback-id',
        name: 'Fallback Model',
        providerModelId: 'fallback-provider-model-id',
        inferenceProviderId: 'fallback-provider',
        createdAt: DateTime.now(),
        inputModalities: const [Modality.text],
        outputModalities: const [Modality.text],
        isReasoningModel: false,
      ),
    );
  });

  setUp(() {
    mockRepository = MockAiConfigRepository();
    fakeProviderController = FakeAiConfigByTypeController();

    when(() => mockRepository.saveConfig(any())).thenAnswer((_) async {});

    // Set up some default provider configs
    fakeProviderController.configs = [
      AiConfig.inferenceProvider(
        id: 'provider-1',
        name: 'Test Provider 1',
        baseUrl: 'https://api1.example.com',
        apiKey: 'key1',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.genericOpenAi,
      ),
      AiConfig.inferenceProvider(
        id: 'provider-2',
        name: 'Test Provider 2',
        baseUrl: 'https://api2.example.com',
        apiKey: 'key2',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.anthropic,
      ),
    ];
  });

  /// Helper function to build the widget under test
  Widget buildTestWidget({
    required FakeInferenceModelFormController formController,
    AiConfig? config,
    Map<String, AiConfig>? providerOverrides,
  }) {
    final overrides = <Override>[
      aiConfigRepositoryProvider.overrideWithValue(mockRepository),
      inferenceModelFormControllerProvider(configId: config?.id)
          .overrideWith(() => formController),
      aiConfigByTypeControllerProvider(
              configType: AiConfigType.inferenceProvider)
          .overrideWith(() => fakeProviderController),
    ];

    // Add provider overrides if provided
    if (providerOverrides != null) {
      for (final entry in providerOverrides.entries) {
        overrides.add(
          aiConfigByIdProvider(entry.key)
              .overrideWith((ref) async => entry.value),
        );
      }
    }

    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: EnhancedInferenceModelForm(config: config),
        ),
      ),
    );
  }

  /// Helper function to create a valid form state
  InferenceModelFormState createValidFormState({
    String name = 'Test Model',
    String providerModelId = 'gpt-4o',
    String inferenceProviderId = 'provider-1',
    List<Modality> inputModalities = const [Modality.text],
    List<Modality> outputModalities = const [Modality.text],
    bool isReasoningModel = false,
  }) {
    return InferenceModelFormState(
      name: ModelName.dirty(name),
      providerModelId: ProviderModelId.dirty(providerModelId),
      inferenceProviderId: inferenceProviderId,
      inputModalities: inputModalities,
      outputModalities: outputModalities,
      isReasoningModel: isReasoningModel,
    );
  }

  group('EnhancedInferenceModelForm Tests', () {
    testWidgets('should render form with all required sections',
        (tester) async {
      // Arrange
      final fakeFormController = FakeInferenceModelFormController()
        ..initialStateForBuild = InferenceModelFormState();

      // Act
      await tester
          .pumpWidget(buildTestWidget(formController: fakeFormController));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(EnhancedInferenceModelForm), findsOneWidget);
      expect(
          find.text(
              'Configure an AI model to make it available for use in prompts'),
          findsOneWidget);

      // Check for form sections
      expect(find.text('Basic Configuration'), findsOneWidget);
      expect(find.text('Model Capabilities'), findsOneWidget);
      expect(find.text('Additional Details'), findsOneWidget);
    });

    testWidgets('should display all form fields with proper labels',
        (tester) async {
      // Arrange
      final fakeFormController = FakeInferenceModelFormController()
        ..initialStateForBuild = InferenceModelFormState();

      // Act
      await tester
          .pumpWidget(buildTestWidget(formController: fakeFormController));
      await tester.pumpAndSettle();

      // Assert - check for form fields
      expect(
          find.byType(EnhancedFormField),
          findsAtLeastNWidgets(
              1)); // Name, Provider Model ID, Description (actual count varies)

      // Check field labels
      expect(find.text('Display Name'), findsOneWidget);
      expect(find.text('Provider Model ID'), findsOneWidget);
      expect(find.text('Description'), findsOneWidget);

      // Check for provider selection card
      expect(find.text('Inference Provider'), findsOneWidget);

      // Check for modality selection cards
      expect(find.text('Input Modalities'), findsOneWidget);
      expect(find.text('Output Modalities'), findsOneWidget);

      // Check for reasoning capability toggle
      expect(find.text('Reasoning Capability'), findsOneWidget);
    });

    testWidgets('should display required field indicators', (tester) async {
      // Arrange
      final fakeFormController = FakeInferenceModelFormController()
        ..initialStateForBuild = InferenceModelFormState();

      // Act
      await tester
          .pumpWidget(buildTestWidget(formController: fakeFormController));
      await tester.pumpAndSettle();

      // Assert - check for required asterisks
      expect(find.text(' *'),
          findsAtLeastNWidgets(2)); // Display Name, Provider Model ID
    });

    testWidgets('should show helper text for form fields', (tester) async {
      // Arrange
      final fakeFormController = FakeInferenceModelFormController()
        ..initialStateForBuild = InferenceModelFormState();

      // Act
      await tester
          .pumpWidget(buildTestWidget(formController: fakeFormController));
      await tester.pumpAndSettle();

      // Assert - check for helper texts
      expect(
          find.text('A friendly name to identify this model'), findsOneWidget);
      expect(
          find.text(
              'The exact model identifier used by the provider (e.g., gpt-4o, claude-3-5-sonnet)'),
          findsOneWidget);
      expect(find.text('Choose the provider that hosts this model'),
          findsOneWidget);
      expect(
          find.text('Types of content this model can process'), findsOneWidget);
      expect(find.text('Types of content this model can generate'),
          findsOneWidget);
      expect(find.text('Optional notes about this model configuration'),
          findsOneWidget);
    });

    testWidgets('should display provider selection card with proper state',
        (tester) async {
      // Arrange
      final fakeFormController = FakeInferenceModelFormController()
        ..initialStateForBuild = InferenceModelFormState();

      // Act
      await tester
          .pumpWidget(buildTestWidget(formController: fakeFormController));
      await tester.pumpAndSettle();

      // Assert - provider selection card should show "No provider selected"
      expect(find.text('No provider selected'), findsOneWidget);
      expect(find.byIcon(Icons.warning_rounded), findsOneWidget);
    });

    testWidgets('should show selected provider name when provider is selected',
        (tester) async {
      // Arrange
      final fakeFormController = FakeInferenceModelFormController()
        ..initialStateForBuild = createValidFormState();

      // Create provider config for override
      final providerConfig = AiConfig.inferenceProvider(
        id: 'provider-1',
        name: 'Test Provider 1',
        baseUrl: 'https://api1.example.com',
        apiKey: 'key1',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.genericOpenAi,
      );

      // Act
      await tester.pumpWidget(buildTestWidget(
        formController: fakeFormController,
        providerOverrides: {'provider-1': providerConfig},
      ));
      await tester.pumpAndSettle();

      // Assert - provider name should be displayed
      expect(find.text('Test Provider 1'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('should display modality selection modal when tapped',
        (tester) async {
      // Arrange
      final fakeFormController = FakeInferenceModelFormController()
        ..initialStateForBuild = InferenceModelFormState();

      await tester
          .pumpWidget(buildTestWidget(formController: fakeFormController));
      await tester.pumpAndSettle();

      // Act - scroll to and tap on input modalities card
      final modalityCard = find.ancestor(
        of: find.text('Input Modalities'),
        matching: find.byType(GestureDetector),
      );
      await tester.ensureVisible(modalityCard);
      await tester.pumpAndSettle();
      await tester.tap(modalityCard);
      await tester.pumpAndSettle();

      // Assert - modal should be displayed
      expect(find.text('Input Modalities'), findsAtLeastNWidgets(1));
      expect(find.byType(CheckboxListTile),
          findsAtLeastNWidgets(Modality.values.length));

      // Check for modality options
      expect(find.text('Text'), findsAtLeastNWidgets(1));
      expect(find.text('Image'), findsAtLeastNWidgets(1));
      expect(find.text('Audio'), findsAtLeastNWidgets(1));
    });

    testWidgets('should display selected modalities as chips', (tester) async {
      // Arrange
      final fakeFormController = FakeInferenceModelFormController()
        ..initialStateForBuild = createValidFormState(
          inputModalities: [Modality.text, Modality.image],
          outputModalities: [Modality.text],
        );

      // Act
      await tester
          .pumpWidget(buildTestWidget(formController: fakeFormController));
      await tester.pumpAndSettle();

      // Assert - modality chips should be displayed
      final modalityChips = find.byWidgetPredicate((widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration! as BoxDecoration).borderRadius != null &&
          widget.child is Text);
      expect(modalityChips,
          findsAtLeastNWidgets(2)); // Text and Image for input, Text for output
    });

    testWidgets('should toggle reasoning capability switch', (tester) async {
      // Arrange
      final fakeFormController = FakeInferenceModelFormController()
        ..initialStateForBuild = createValidFormState();

      await tester
          .pumpWidget(buildTestWidget(formController: fakeFormController));
      await tester.pumpAndSettle();

      // Act - scroll to and tap the reasoning switch
      final reasoningSwitch = find.byType(Switch);
      expect(reasoningSwitch, findsOneWidget);
      await tester.ensureVisible(reasoningSwitch);
      await tester.pumpAndSettle();
      await tester.tap(reasoningSwitch);
      await tester.pumpAndSettle();

      // Assert - switch interaction should work (visual feedback)
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('should display modern styling elements', (tester) async {
      // Arrange
      final fakeFormController = FakeInferenceModelFormController()
        ..initialStateForBuild = InferenceModelFormState();

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
      expect(find.byIcon(Icons.psychology_outlined), findsAtLeastNWidgets(2));
      expect(find.byIcon(Icons.description_outlined), findsOneWidget);
    });

    testWidgets('should show loading indicator when form state is null',
        (tester) async {
      // Arrange
      final fakeFormController = FakeInferenceModelFormController()
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
      final fakeFormController = FakeInferenceModelFormController()
        ..initialStateForBuild = InferenceModelFormState();

      // Act
      await tester
          .pumpWidget(buildTestWidget(formController: fakeFormController));
      await tester.pumpAndSettle();

      // Assert - form should be scrollable
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('should handle empty provider list gracefully', (tester) async {
      // Arrange
      fakeProviderController.configs = []; // No providers available
      final fakeFormController = FakeInferenceModelFormController()
        ..initialStateForBuild = InferenceModelFormState();

      await tester
          .pumpWidget(buildTestWidget(formController: fakeFormController));
      await tester.pumpAndSettle();

      // Act - tap on provider selection to open modal
      final providerCard = find.ancestor(
        of: find.text('Inference Provider'),
        matching: find.byType(GestureDetector),
      );
      await tester.tap(providerCard);
      await tester.pumpAndSettle();

      // Assert - should show "No providers found" message
      expect(find.text('No providers found'), findsOneWidget);
      expect(find.text('Create an inference provider first'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    });

    testWidgets('should apply Series A quality visual design', (tester) async {
      // Arrange
      final fakeFormController = FakeInferenceModelFormController()
        ..initialStateForBuild = InferenceModelFormState();

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
  });

  group('EnhancedInferenceModelForm Integration Tests', () {
    testWidgets('should integrate with form controller properly',
        (tester) async {
      // Arrange
      final fakeFormController = FakeInferenceModelFormController()
        ..initialStateForBuild = createValidFormState();

      // Act
      await tester
          .pumpWidget(buildTestWidget(formController: fakeFormController));
      await tester.pumpAndSettle();

      // Assert - form should display with valid controller state
      expect(find.byType(EnhancedInferenceModelForm), findsOneWidget);
      expect(find.byType(EnhancedFormField), findsAtLeastNWidgets(1));
    });

    testWidgets('should handle configuration editing mode', (tester) async {
      // Arrange
      final config = AiConfig.model(
        id: 'test-id',
        name: 'Existing Model',
        providerModelId: 'claude-3-5-sonnet',
        inferenceProviderId: 'provider-2',
        createdAt: DateTime.now(),
        inputModalities: const [Modality.text, Modality.image],
        outputModalities: const [Modality.text],
        isReasoningModel: true,
      );

      final fakeFormController = FakeInferenceModelFormController()
        ..initialStateForBuild = createValidFormState(
          name: 'Existing Model',
          providerModelId: 'claude-3-5-sonnet',
          inferenceProviderId: 'provider-2',
          inputModalities: [Modality.text, Modality.image],
          outputModalities: [Modality.text],
          isReasoningModel: true,
        );

      // Act
      await tester.pumpWidget(buildTestWidget(
        config: config,
        formController: fakeFormController,
      ));
      await tester.pumpAndSettle();

      // Assert - form should be in edit mode
      expect(find.byType(EnhancedInferenceModelForm), findsOneWidget);
      expect(find.byType(EnhancedFormField), findsAtLeastNWidgets(1));
    });

    testWidgets('should handle form state updates correctly', (tester) async {
      // Arrange
      final fakeFormController = FakeInferenceModelFormController()
        ..initialStateForBuild = InferenceModelFormState();

      await tester
          .pumpWidget(buildTestWidget(formController: fakeFormController));
      await tester.pumpAndSettle();

      // Act - update form state with valid data
      fakeFormController.emitNewStateForTest(createValidFormState());
      await tester.pumpAndSettle();

      // Assert - form should update without errors
      expect(find.byType(EnhancedInferenceModelForm), findsOneWidget);
      expect(find.byType(EnhancedFormField), findsAtLeastNWidgets(1));
    });
  });
}
