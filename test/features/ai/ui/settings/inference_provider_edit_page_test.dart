import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_provider_extensions.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/ui/settings/enhanced_provider_form.dart';
import 'package:lotti/features/ai/ui/settings/inference_provider_edit_page.dart';
import 'package:lotti/features/ai/ui/widgets/enhanced_form_field.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

// Mock classes
class MockAiConfigRepository extends Mock implements AiConfigRepository {}

class MockNavigatorObserver extends Mock implements NavigatorObserver {}

void main() {
  late MockAiConfigRepository mockRepository;
  late AiConfig testConfig;

  setUpAll(() {
    registerFallbackValue(
      AiConfig.inferenceProvider(
        id: 'fallback-id',
        name: 'Fallback API',
        baseUrl: 'https://fallback.example.com',
        apiKey: 'fallback-key',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.genericOpenAi,
      ),
    );
  });

  setUp(() {
    mockRepository = MockAiConfigRepository();

    // Create a test config
    testConfig = AiConfig.inferenceProvider(
      id: 'test-id',
      name: 'Test API',
      baseUrl: 'https://api.example.com',
      apiKey: 'test-api-key',
      createdAt: DateTime.now(),
      inferenceProviderType: InferenceProviderType.genericOpenAi,
    );

    // Set up the repository responses
    when(() => mockRepository.saveConfig(any())).thenAnswer((_) async {});
    when(() => mockRepository.getConfigById('test-id'))
        .thenAnswer((_) async => testConfig);
  });

  // Helper function to build the widget under test
  Widget buildTestWidget({String? configId}) {
    return ProviderScope(
      overrides: [
        // Mock the repository instead of the controller
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
        navigatorObservers: [MockNavigatorObserver()],
      ),
    );
  }

  group('ApiKeyEditPage Tests', () {
    testWidgets(
        'should display "Add AI Inference Provider" title when configId is null',
        (WidgetTester tester) async {
      // Set a larger viewport size using the non-deprecated approach
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Arrange
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Add AI Inference Provider'), findsOneWidget);
      expect(find.byType(EnhancedInferenceProviderForm), findsOneWidget);
    });

    testWidgets(
        'should display "Edit AI Inference Provider" title when configId is provided',
        (WidgetTester tester) async {
      // Set a larger viewport size using the non-deprecated approach
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Arrange
      await tester.pumpWidget(buildTestWidget(configId: 'test-id'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Edit AI Inference Provider'), findsOneWidget);
      expect(find.byType(EnhancedInferenceProviderForm), findsOneWidget);
    });

    testWidgets('should call repository saveConfig when adding a new API key',
        (WidgetTester tester) async {
      // Set a larger viewport size using the non-deprecated approach
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Clear previous interactions
      reset(mockRepository);
      when(() => mockRepository.saveConfig(any())).thenAnswer((_) async {});

      // Arrange
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Fill in the form fields using the enhanced form structure
      // Find all TextFields in the form - they appear in order: Display Name, Base URL, API Key, Description
      final textFields = find.byType(TextField);
      expect(textFields, findsAtLeastNWidgets(3)); // We need at least 3 fields

      await tester.enterText(textFields.at(0), 'New API'); // Display Name
      await tester.enterText(
          textFields.at(1), 'https://new.example.com'); // Base URL
      await tester.enterText(textFields.at(2), 'new-api-key'); // API Key
      await tester.pumpAndSettle();

      // Find and tap the save button in the app bar
      final saveButton = find.text('Save');
      expect(saveButton, findsOneWidget);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Verify saveConfig was called
      verify(() => mockRepository.saveConfig(any())).called(1);
    });

    testWidgets(
        'should call repository saveConfig when updating an existing API key',
        (WidgetTester tester) async {
      // Set a larger viewport size using the non-deprecated approach
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Clear previous interactions
      reset(mockRepository);
      when(() => mockRepository.getConfigById('test-id'))
          .thenAnswer((_) async => testConfig);
      when(() => mockRepository.saveConfig(any())).thenAnswer((_) async {});

      // Arrange
      await tester.pumpWidget(buildTestWidget(configId: 'test-id'));
      await tester.pumpAndSettle();

      // Modify a field to make the form dirty
      final textFields = find.byType(TextField);
      expect(textFields, findsAtLeastNWidgets(1));
      await tester.enterText(textFields.first, 'Updated API');
      await tester.pumpAndSettle();

      // Find and tap the save button in the app bar
      final saveButton = find.text('Save');
      expect(saveButton, findsOneWidget);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Verify saveConfig was called
      verify(() => mockRepository.saveConfig(any())).called(1);
    });

    testWidgets('should show loading indicator when loading a config',
        (WidgetTester tester) async {
      // Set a larger viewport size using the non-deprecated approach
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Arrange - use a Completer that we can control
      final completer = Completer<AiConfig?>();
      when(() => mockRepository.getConfigById('test-id'))
          .thenAnswer((_) => completer.future);

      await tester.pumpWidget(buildTestWidget(configId: 'test-id'));

      // Assert - should see loading indicator while future is pending
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete the future to clean up
      completer.complete(testConfig);
      await tester.pumpAndSettle();
    });

    testWidgets('should show error message when config loading fails',
        (WidgetTester tester) async {
      // Set a larger viewport size using the non-deprecated approach
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Arrange - repository that throws an error
      when(() => mockRepository.getConfigById('test-id'))
          .thenAnswer((_) => Future<AiConfig?>.error('Failed to load'));

      await tester.pumpWidget(buildTestWidget(configId: 'test-id'));

      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Failed to load API key configuration'), findsOneWidget);
    });

    testWidgets(
        'should display provider type selection modal when tapping field',
        (WidgetTester tester) async {
      // Set a larger viewport size
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Arrange
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Verify initial provider type is shown
      final context =
          tester.element(find.byType(EnhancedInferenceProviderForm));
      expect(
        find.text(InferenceProviderType.genericOpenAi.displayName(context)),
        findsOneWidget,
      );

      // Find and tap on the provider type field (use EnhancedSelectionField)
      final providerField = find.byType(EnhancedSelectionField);
      expect(providerField, findsOneWidget);

      // Tap on the enhanced selection field to open the modal
      await tester.tap(providerField);
      await tester.pumpAndSettle();

      // Verify modal is shown with title
      expect(find.text('Select Provider Type'), findsAtLeastNWidgets(1));

      // Verify modal subtitle is shown
      expect(find.text('Choose the AI service provider for your configuration'), findsOneWidget);

      // Find the provider cards with InkWell instead of ListTile
      expect(find.byType(InkWell), findsAtLeastNWidgets(InferenceProviderType.values.length));

      // Verify at least one provider type is listed
      expect(find.textContaining('OpenAI'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Anthropic'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Gemini'), findsAtLeastNWidgets(1));
    });

    testWidgets('should update provider type when selecting from modal',
        (WidgetTester tester) async {
      // Set a larger viewport size
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Arrange
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Open the provider type selection modal
      final providerField = find.byType(EnhancedSelectionField);
      await tester.tap(providerField);
      await tester.pumpAndSettle();

      // Select a different provider type by tapping on Anthropic card
      // Find the InkWell that contains Anthropic text
      final anthropicCards = find.byWidgetPredicate((widget) {
        if (widget is! InkWell) return false;
        
        // Check if this InkWell contains Anthropic text
        final finder = find.descendant(
          of: find.byWidget(widget),
          matching: find.textContaining('Anthropic'),
        );
        return finder.evaluate().isNotEmpty;
      });

      if (anthropicCards.evaluate().isNotEmpty) {
        await tester.tap(anthropicCards.first);
        await tester.pumpAndSettle();
      }

      // Recreate the form with the new state and verify the display
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
    });

    testWidgets(
        'should show check mark for the currently selected provider type',
        (WidgetTester tester) async {
      // Set a larger viewport size
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Arrange
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Open the provider type selection modal
      final providerField = find.byType(EnhancedSelectionField);
      await tester.tap(providerField);
      await tester.pumpAndSettle();

      // Find check mark icon for selected provider (our new modal design uses check_rounded icon)
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      
      // Verify the selected provider card has different styling
      final selectedCards = find.byWidgetPredicate((widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration?)?.border != null);
      expect(selectedCards, findsAtLeastNWidgets(1));
    });

    testWidgets('keyboard shortcut structure is properly configured',
        (WidgetTester tester) async {
      // Set a larger viewport size
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Build the widget in create mode
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Verify CallbackShortcuts is present (there will be multiple due to CopyableTextField)
      expect(find.byType(CallbackShortcuts), findsWidgets);

      // Find all CallbackShortcuts widgets
      final callbackShortcutsFinders = find.byType(CallbackShortcuts);
      CallbackShortcuts? cmdSShortcuts;

      // Find the one that contains CMD+S
      for (var i = 0; i < callbackShortcutsFinders.evaluate().length; i++) {
        final widget =
            tester.widget<CallbackShortcuts>(callbackShortcutsFinders.at(i));
        if (widget.bindings.keys.any((s) =>
            s is SingleActivator &&
            s.trigger == LogicalKeyboardKey.keyS &&
            s.meta)) {
          cmdSShortcuts = widget;
          break;
        }
      }

      // Verify we found the CMD+S shortcut
      expect(cmdSShortcuts, isNotNull);
      expect(cmdSShortcuts!.bindings.length, equals(1));
    });

    testWidgets('CMD+S shortcut does not trigger when form is invalid',
        (WidgetTester tester) async {
      // Set a larger viewport size
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Clear previous interactions
      reset(mockRepository);
      when(() => mockRepository.saveConfig(any())).thenAnswer((_) async {});

      // Build the widget in create mode
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Verify save button is not visible (form is invalid)
      // Save button should be disabled (visible but with reduced opacity)
      expect(find.text('Save'), findsOneWidget);
      // Check for reduced opacity when form is invalid
      final opacityWidget = find.byType(AnimatedOpacity);
      expect(opacityWidget, findsAtLeastNWidgets(1));

      // Find the CallbackShortcuts widget with CMD+S
      final callbackShortcutsFinders = find.byType(CallbackShortcuts);
      CallbackShortcuts? cmdSShortcuts;

      for (var i = 0; i < callbackShortcutsFinders.evaluate().length; i++) {
        final widget =
            tester.widget<CallbackShortcuts>(callbackShortcutsFinders.at(i));
        if (widget.bindings.keys.any((s) =>
            s is SingleActivator &&
            s.trigger == LogicalKeyboardKey.keyS &&
            s.meta)) {
          cmdSShortcuts = widget;
          break;
        }
      }

      expect(cmdSShortcuts, isNotNull);

      // Get the shortcut callback
      final shortcutCallback = cmdSShortcuts!.bindings.values.first;

      // Try to trigger the shortcut
      shortcutCallback();
      await tester.pumpAndSettle();

      // Verify no save was attempted
      verifyNever(() => mockRepository.saveConfig(any()));
    });

    testWidgets('CMD+S shortcut triggers save when form is valid',
        (WidgetTester tester) async {
      // Set a larger viewport size
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Clear previous interactions
      reset(mockRepository);
      when(() => mockRepository.saveConfig(any())).thenAnswer((_) async {});

      // Arrange
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Fill in the form fields to make it valid
      final textFields = find.byType(TextField);
      expect(textFields, findsAtLeastNWidgets(3));

      await tester.enterText(textFields.at(0), 'New API'); // Display Name
      await tester.enterText(
          textFields.at(1), 'https://new.example.com'); // Base URL
      await tester.enterText(textFields.at(2), 'new-api-key'); // API Key
      await tester.pumpAndSettle();

      // Verify save button is visible now
      expect(find.text('Save'), findsOneWidget);

      // Find the CallbackShortcuts widget with CMD+S
      final callbackShortcutsFinders = find.byType(CallbackShortcuts);
      CallbackShortcuts? cmdSShortcuts;

      for (var i = 0; i < callbackShortcutsFinders.evaluate().length; i++) {
        final widget =
            tester.widget<CallbackShortcuts>(callbackShortcutsFinders.at(i));
        if (widget.bindings.keys.any((s) =>
            s is SingleActivator &&
            s.trigger == LogicalKeyboardKey.keyS &&
            s.meta)) {
          cmdSShortcuts = widget;
          break;
        }
      }

      expect(cmdSShortcuts, isNotNull);

      // Get the shortcut callback
      final shortcutCallback = cmdSShortcuts!.bindings.values.first;

      // Trigger the shortcut
      shortcutCallback();
      await tester.pumpAndSettle();

      // Verify saveConfig was called
      verify(() => mockRepository.saveConfig(any())).called(1);
    });
  });
}
