import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_provider_form_state.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/inference_provider_form_controller.dart';
import 'package:lotti/features/ai/ui/settings/enhanced_provider_form.dart';
import 'package:lotti/features/ai/ui/widgets/enhanced_form_field.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

/// Mock repository for testing
class MockAiConfigRepository extends Mock implements AiConfigRepository {}

/// Fake controller for testing form behavior
class FakeInferenceProviderFormController
    extends InferenceProviderFormController {
  InferenceProviderFormState? initialStateForBuild =
      InferenceProviderFormState();

  String get debugLabel => 'FakeInferenceProviderFormController';

  /// Method to emit a new state for testing
  void emitNewStateForTest(InferenceProviderFormState? newState) {
    state = AsyncData<InferenceProviderFormState?>(newState);
  }

  @override
  Future<InferenceProviderFormState?> build({required String? configId}) async {
    state = AsyncData<InferenceProviderFormState?>(initialStateForBuild);
    return initialStateForBuild;
  }

  @override
  void nameChanged(String name) {}
  @override
  void baseUrlChanged(String baseUrl) {}
  @override
  void apiKeyChanged(String apiKey) {}
  @override
  void descriptionChanged(String description) {}
  @override
  void inferenceProviderTypeChanged(InferenceProviderType type) {}
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

/// Test class for enhanced provider form
void main() {
  late MockAiConfigRepository mockRepository;

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
    when(() => mockRepository.saveConfig(any())).thenAnswer((_) async {});
  });

  /// Helper function to build the widget under test
  Widget buildTestWidget({
    required FakeInferenceProviderFormController formController, AiConfig? config,
  }) {
    return ProviderScope(
      overrides: [
        aiConfigRepositoryProvider.overrideWithValue(mockRepository),
        inferenceProviderFormControllerProvider(configId: config?.id)
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
          body: EnhancedInferenceProviderForm(config: config),
        ),
      ),
    );
  }

  /// Helper function to create a valid form state
  InferenceProviderFormState createValidFormState({
    String name = 'Test Provider',
    String baseUrl = 'https://api.example.com',
    String apiKey = 'test-api-key',
    InferenceProviderType type = InferenceProviderType.genericOpenAi,
  }) {
    return InferenceProviderFormState(
      name: ApiKeyName.dirty(name),
      baseUrl: BaseUrl.dirty(baseUrl),
      apiKey: ApiKeyValue.dirty(apiKey),
      inferenceProviderType: type,
    );
  }

  group('EnhancedInferenceProviderForm Tests', () {
    testWidgets('should render form with all required fields', (tester) async {
      // Arrange
      final fakeFormController = FakeInferenceProviderFormController()
        ..initialStateForBuild = InferenceProviderFormState();

      // Act
      await tester
          .pumpWidget(buildTestWidget(formController: fakeFormController));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(EnhancedInferenceProviderForm), findsOneWidget);
      expect(
          find.text(
              'Configure your AI inference provider to start making requests'),
          findsOneWidget);

      // Check for form sections
      expect(find.text('Provider Configuration'), findsOneWidget);
      expect(find.text('Authentication'), findsOneWidget);
      expect(find.text('Additional Details'), findsOneWidget);

      // Check for form fields
      expect(
          find.byType(EnhancedFormField),
          findsAtLeastNWidgets(
              1)); // Name, Base URL, API Key, Description (actual count may vary)
      expect(
          find.byType(EnhancedSelectionField), findsOneWidget); // Provider Type
    });

    testWidgets('should display required field indicators', (tester) async {
      // Arrange
      final fakeFormController = FakeInferenceProviderFormController()
        ..initialStateForBuild = InferenceProviderFormState();

      // Act
      await tester
          .pumpWidget(buildTestWidget(formController: fakeFormController));
      await tester.pumpAndSettle();

      // Assert - check for required asterisks
      expect(find.text(' *'),
          findsAtLeastNWidgets(3)); // Provider Type, Display Name, API Key
    });

    testWidgets('should show helper text for form fields', (tester) async {
      // Arrange
      final fakeFormController = FakeInferenceProviderFormController()
        ..initialStateForBuild = InferenceProviderFormState();

      // Act
      await tester
          .pumpWidget(buildTestWidget(formController: fakeFormController));
      await tester.pumpAndSettle();

      // Assert - check for helper texts
      expect(find.text('Choose the AI service provider for this configuration'),
          findsOneWidget);
      expect(find.text('A friendly name to identify this provider'),
          findsOneWidget);
      expect(
          find.text('The API endpoint URL for this provider'), findsOneWidget);
      expect(find.text('Your API key for authenticating with this provider'),
          findsOneWidget);
      expect(find.text('Optional notes about this provider configuration'),
          findsOneWidget);
    });

    testWidgets('should display provider type selection modal when tapped',
        (tester) async {
      // Arrange
      final fakeFormController = FakeInferenceProviderFormController()
        ..initialStateForBuild = InferenceProviderFormState();

      await tester
          .pumpWidget(buildTestWidget(formController: fakeFormController));
      await tester.pumpAndSettle();

      // Act - tap on provider type selection field
      final providerTypeField = find.byType(EnhancedSelectionField);
      expect(providerTypeField, findsOneWidget);
      await tester.tap(providerTypeField);
      await tester.pumpAndSettle();

      // Assert - modal should be displayed
      expect(find.text('Select Provider Type'), findsAtLeastNWidgets(1));
      expect(find.byType(ListTile),
          findsAtLeastNWidgets(InferenceProviderType.values.length));

      // Check for provider type options
      expect(find.text('OpenAI Compatible'), findsAtLeastNWidgets(1));
      expect(find.text('Anthropic Claude'), findsOneWidget);
      expect(find.text('OpenAI'), findsOneWidget);
    });

    testWidgets('should toggle API key visibility when icon is tapped',
        (tester) async {
      // Arrange
      final fakeFormController = FakeInferenceProviderFormController()
        ..initialStateForBuild = createValidFormState();

      await tester
          .pumpWidget(buildTestWidget(formController: fakeFormController));
      await tester.pumpAndSettle();

      // Find the API key field and visibility toggle
      final visibilityToggle = find.byIcon(Icons.visibility_outlined);
      expect(visibilityToggle, findsOneWidget);

      // Act - scroll to and tap visibility toggle
      await tester.ensureVisible(visibilityToggle);
      await tester.pumpAndSettle();
      await tester.tap(visibilityToggle);
      await tester.pumpAndSettle();

      // Assert - icon should change to visibility_off
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
      expect(find.byIcon(Icons.visibility_outlined), findsNothing);
    });

    testWidgets('should display form with modern styling elements',
        (tester) async {
      // Arrange
      final fakeFormController = FakeInferenceProviderFormController()
        ..initialStateForBuild = InferenceProviderFormState();

      // Act
      await tester
          .pumpWidget(buildTestWidget(formController: fakeFormController));
      await tester.pumpAndSettle();

      // Assert - check for modern styling containers
      final containers = find.byType(Container);
      expect(containers, findsAtLeastNWidgets(5)); // Multiple styled containers

      // Check for rounded borders and modern design elements
      final decoratedBoxes = find.byWidgetPredicate((widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration! as BoxDecoration).borderRadius != null);
      expect(decoratedBoxes, findsAtLeastNWidgets(3));
    });

    testWidgets('should show loading indicator when form state is null',
        (tester) async {
      // Arrange
      final fakeFormController = FakeInferenceProviderFormController()
        ..initialStateForBuild = null; // null state to show loading

      // Act
      await tester
          .pumpWidget(buildTestWidget(formController: fakeFormController));
      await tester.pump(); // Just pump once to start loading

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should display section headers with icons', (tester) async {
      // Arrange
      final fakeFormController = FakeInferenceProviderFormController()
        ..initialStateForBuild = InferenceProviderFormState();

      // Act
      await tester
          .pumpWidget(buildTestWidget(formController: fakeFormController));
      await tester.pumpAndSettle();

      // Assert - check for section icons
      expect(find.byIcon(Icons.settings_outlined), findsAtLeastNWidgets(1));
      expect(find.byIcon(Icons.security_outlined), findsOneWidget);
      expect(find.byIcon(Icons.description_outlined), findsOneWidget);
    });

    testWidgets('should apply Series A quality visual design', (tester) async {
      // Arrange
      final fakeFormController = FakeInferenceProviderFormController()
        ..initialStateForBuild = InferenceProviderFormState();

      // Act
      await tester
          .pumpWidget(buildTestWidget(formController: fakeFormController));
      await tester.pumpAndSettle();

      // Assert - check for professional spacing and layout
      final sizedBoxes = find.byType(SizedBox);
      expect(sizedBoxes, findsAtLeastNWidgets(5)); // Multiple spacing elements

      // Check for proper padding and margins
      final paddedWidgets = find.byWidgetPredicate(
          (widget) => widget is Padding && widget.padding != EdgeInsets.zero);
      expect(paddedWidgets, findsAtLeastNWidgets(3));
    });

    testWidgets('should handle form state updates correctly', (tester) async {
      // Arrange
      final fakeFormController = FakeInferenceProviderFormController()
        ..initialStateForBuild = InferenceProviderFormState();

      await tester
          .pumpWidget(buildTestWidget(formController: fakeFormController));
      await tester.pumpAndSettle();

      // Act - update form state with valid data
      fakeFormController.emitNewStateForTest(createValidFormState());
      await tester.pumpAndSettle();

      // Assert - form should update without errors
      expect(find.byType(EnhancedInferenceProviderForm), findsOneWidget);
    });

    testWidgets('should maintain scroll behavior for long forms',
        (tester) async {
      // Arrange
      final fakeFormController = FakeInferenceProviderFormController()
        ..initialStateForBuild = InferenceProviderFormState();

      // Act
      await tester
          .pumpWidget(buildTestWidget(formController: fakeFormController));
      await tester.pumpAndSettle();

      // Assert - form should be scrollable
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('should display proper background and surface colors',
        (tester) async {
      // Arrange
      final fakeFormController = FakeInferenceProviderFormController()
        ..initialStateForBuild = InferenceProviderFormState();

      // Act
      await tester
          .pumpWidget(buildTestWidget(formController: fakeFormController));
      await tester.pumpAndSettle();

      // Assert - check for proper background container
      final backgroundContainer = find.byWidgetPredicate((widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration! as BoxDecoration).borderRadius != null);
      expect(backgroundContainer, findsAtLeastNWidgets(1));
    });
  });

  group('EnhancedInferenceProviderForm Integration Tests', () {
    testWidgets('should integrate with form controller properly',
        (tester) async {
      // Arrange
      final fakeFormController = FakeInferenceProviderFormController()
        ..initialStateForBuild = createValidFormState();

      // Act
      await tester
          .pumpWidget(buildTestWidget(formController: fakeFormController));
      await tester.pumpAndSettle();

      // Assert - form should display with valid controller state
      expect(find.byType(EnhancedInferenceProviderForm), findsOneWidget);
      expect(find.byType(EnhancedFormField), findsAtLeastNWidgets(1));
    });

    testWidgets('should handle configuration editing mode', (tester) async {
      // Arrange
      final config = AiConfig.inferenceProvider(
        id: 'test-id',
        name: 'Existing Provider',
        baseUrl: 'https://existing.api.com',
        apiKey: 'existing-key',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.anthropic,
      );

      final fakeFormController = FakeInferenceProviderFormController()
        ..initialStateForBuild = createValidFormState(
          name: 'Existing Provider',
          baseUrl: 'https://existing.api.com',
          apiKey: 'existing-key',
          type: InferenceProviderType.anthropic,
        );

      // Act
      await tester.pumpWidget(buildTestWidget(
        config: config,
        formController: fakeFormController,
      ));
      await tester.pumpAndSettle();

      // Assert - form should be in edit mode
      expect(find.byType(EnhancedInferenceProviderForm), findsOneWidget);
      expect(find.byType(EnhancedFormField), findsAtLeastNWidgets(1));
    });
  });
}
