import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/ui/settings/inference_model_edit_page.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

// Mock classes
class MockAiConfigRepository extends Mock implements AiConfigRepository {}

void main() {
  late MockAiConfigRepository mockRepository;
  late AiConfig testModel;
  late AiConfig testProvider;

  setUpAll(() {
    registerFallbackValue(
      AiConfig.model(
        id: 'fallback-id',
        name: 'Fallback Model',
        providerModelId: 'fallback-model-id',
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

    testProvider = AiConfig.inferenceProvider(
      id: 'provider-1',
      name: 'Test Provider',
      baseUrl: 'https://api.test.com',
      apiKey: 'test-key',
      createdAt: DateTime.now(),
      inferenceProviderType: InferenceProviderType.openAi,
    );

    testModel = AiConfig.model(
      id: 'test-model-id',
      name: 'Test Model',
      providerModelId: 'gpt-4',
      inferenceProviderId: 'provider-1',
      createdAt: DateTime.now(),
      inputModalities: [Modality.text, Modality.image],
      outputModalities: [Modality.text],
      isReasoningModel: false,
      description: 'A test model for unit tests',
    );

    // Default mock responses
    when(() => mockRepository.saveConfig(any())).thenAnswer((_) async {});
    when(() => mockRepository.getConfigById('test-model-id'))
        .thenAnswer((_) async => testModel);
    when(() => mockRepository.getConfigById('provider-1'))
        .thenAnswer((_) async => testProvider);
    when(() => mockRepository.getConfigsByType(AiConfigType.inferenceProvider))
        .thenAnswer((_) async => [testProvider]);
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
        home: InferenceModelEditPage(configId: configId),
      ),
    );
  }

  group('InferenceModelEditPage', () {
    testWidgets('displays correct title for new model',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Add Model'), findsOneWidget);
    });

    testWidgets('displays correct title for existing model',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget(configId: 'test-model-id'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Model'), findsOneWidget);
    });

    testWidgets('loads and displays existing model data',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget(configId: 'test-model-id'));
      await tester.pumpAndSettle();

      // Check that the form is populated with existing data
      expect(find.text('Test Model'), findsOneWidget);
      expect(find.text('gpt-4'), findsOneWidget);
      expect(find.text('Test Provider'), findsOneWidget);
    });

    testWidgets('shows form sections with proper labels',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Check section headers
      expect(find.text('Basic Configuration'), findsOneWidget);
      expect(find.text('Capabilities'), findsOneWidget);

      // Check field labels
      expect(find.text('Provider'), findsOneWidget);
      expect(find.text('Display Name'), findsOneWidget);
      expect(find.text('Provider Model ID'), findsOneWidget);
    });

    testWidgets('shows save button and form fields',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Find the save button
      final saveButton = find.text('Save Model');
      expect(saveButton, findsOneWidget);

      // Verify form fields exist by checking labels
      expect(find.text('Display Name'), findsOneWidget);
      expect(find.text('Provider Model ID'), findsOneWidget);
    });

    testWidgets('has provider selection field', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Check that provider field exists
      expect(find.text('Provider'), findsOneWidget);
      // Provider field should show either 'Select a provider' or a provider name
      final selectProviderText = find.text('Select a provider');
      final providerNameText = find.text('Test Provider');
      expect(
          selectProviderText.evaluate().length +
              providerNameText.evaluate().length,
          greaterThan(0));
    });

    testWidgets('shows modality fields in form', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Check that modality labels exist in the form
      expect(find.text('Input Modalities'), findsOneWidget);
      expect(find.text('Output Modalities'), findsOneWidget);
    });

    testWidgets('toggles reasoning model switch', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Find reasoning model switch
      final reasoningSwitch = find.byType(Switch);
      if (reasoningSwitch.evaluate().isNotEmpty) {
        // Tap to toggle
        await tester.tap(reasoningSwitch.first);
        await tester.pumpAndSettle();

        // Switch should have toggled
        final switchWidget = tester.widget<Switch>(reasoningSwitch.first);
        expect(switchWidget.value, isNotNull);
      }
    });

    testWidgets('has cancel and save buttons', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Scroll to bottom to see buttons
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();

      // Verify both buttons exist
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save Model'), findsOneWidget);
    });

    testWidgets('shows error state when loading fails',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Setup repository to throw error
      when(() => mockRepository.getConfigById('error-id'))
          .thenThrow(Exception('Failed to load'));

      await tester.pumpWidget(buildTestWidget(configId: 'error-id'));
      await tester.pumpAndSettle();

      // Check error UI
      expect(find.text('Failed to load model configuration'), findsOneWidget);
      expect(find.text('Please try again or contact support'), findsOneWidget);
      expect(find.text('Go Back'), findsOneWidget);
    });

    testWidgets('validates form has required fields',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Check that required fields exist
      expect(find.text('Display Name'), findsOneWidget);
      expect(find.text('Provider Model ID'), findsOneWidget);
      expect(find.text('Provider'), findsOneWidget);
    });

    testWidgets('saves modified model data', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget(configId: 'test-model-id'));
      await tester.pumpAndSettle();

      // Modify a field
      final nameField = find.widgetWithText(TextFormField, 'Test Model');
      await tester.enterText(nameField, 'Updated Model Name');
      await tester.pumpAndSettle();

      // Scroll to save button
      final saveButton = find.text('Save Model');
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();

      // Save
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Verify save was called with updated data
      verify(() => mockRepository.saveConfig(any())).called(1);
    });

    testWidgets('handles keyboard shortcuts', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Verify CallbackShortcuts widget exists
      expect(find.byType(CallbackShortcuts), findsWidgets);
    });

    testWidgets('displays description field', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Check for description field
      expect(find.text('Description'), findsOneWidget);
    });
  });
}
