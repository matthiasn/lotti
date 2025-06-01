import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/ui/settings/inference_model_edit_page.dart';
import 'package:lotti/features/ai/ui/settings/inference_model_form.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

/// Mock repository implementation
class MockAiConfigRepository extends Mock implements AiConfigRepository {}

/// Mock controller for saving/updating
class MockInferenceModelFormController extends Mock {
  void addConfig(AiConfig config) {}
  void updateConfig(AiConfig config) {}
}

void main() {
  late MockAiConfigRepository mockRepository;

  setUpAll(() {
    // Register fallback value for mocktail
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
  });

  /// Helper function to build a testable widget with the correct localizations
  /// and provider overrides
  Widget buildTestWidget({
    required String? configId,
    required MockAiConfigRepository repository,
  }) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: ProviderScope(
        overrides: [
          aiConfigRepositoryProvider.overrideWithValue(repository),
        ],
        child: InferenceModelEditPage(configId: configId),
      ),
    );
  }

  /// Creates a mock model config for testing
  AiConfig createMockModelConfig({
    required String id,
    required String name,
    String? description,
  }) {
    return AiConfig.model(
      id: id,
      name: name,
      providerModelId: 'test-provider-model-id',
      inferenceProviderId: 'provider-1',
      createdAt: DateTime.now(),
      inputModalities: const [Modality.text],
      outputModalities: const [Modality.text],
      isReasoningModel: true,
      description: description,
    );
  }

  group('InferenceModelEditPage', () {
    testWidgets('displays create form when configId is null',
        (WidgetTester tester) async {
      // Build the widget in create mode
      await tester.pumpWidget(
        buildTestWidget(
          configId: null,
          repository: mockRepository,
        ),
      );

      // Allow async operations to complete
      await tester.pumpAndSettle();

      // Verify the title shows "Add Model" or equivalent
      expect(find.textContaining('Add Model'), findsOneWidget);

      // Verify the form is displayed - look for the form widget itself
      expect(find.byType(InferenceModelForm), findsOneWidget);
    });

    testWidgets(
        'displays edit form when configId is provided and config exists',
        (WidgetTester tester) async {
      // Create a mock config
      final mockConfig = createMockModelConfig(
        id: 'model-1',
        name: 'Test Model',
        description: 'Test Description',
      );

      // Set up mock repository to return the config
      when(() => mockRepository.getConfigById('model-1'))
          .thenAnswer((_) async => mockConfig);

      // Build the widget in edit mode
      await tester.pumpWidget(
        buildTestWidget(
          configId: 'model-1',
          repository: mockRepository,
        ),
      );

      // Allow async operations to complete
      await tester.pumpAndSettle();

      // Verify the title shows "Edit Model" or equivalent
      expect(find.textContaining('Edit Model'), findsOneWidget);
    });

    testWidgets('displays loading indicator when config is loading',
        (WidgetTester tester) async {
      // Use a Completer that we can complete at the end of the test
      final completer = Completer<AiConfig?>();

      // Set up mock repository to return the completer's future
      when(() => mockRepository.getConfigById('model-1'))
          .thenAnswer((_) => completer.future);

      // Build the widget in edit mode
      await tester.pumpWidget(
        buildTestWidget(
          configId: 'model-1',
          repository: mockRepository,
        ),
      );

      // Verify loading indicator is shown
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete the future to clean up
      completer.complete(null);
      await tester.pump();
    });

    testWidgets('displays error when config fails to load',
        (WidgetTester tester) async {
      // Set up mock repository to throw error
      when(() => mockRepository.getConfigById('model-1'))
          .thenThrow(Exception('Test error'));

      // Build the widget in edit mode
      await tester.pumpWidget(
        buildTestWidget(
          configId: 'model-1',
          repository: mockRepository,
        ),
      );

      // Allow async operations to complete
      await tester.pumpAndSettle();

      // Verify error message is shown
      expect(find.textContaining('Failed to load'), findsOneWidget);
    });

    testWidgets('keyboard shortcut structure is properly configured',
        (WidgetTester tester) async {
      // Build the widget in create mode
      await tester.pumpWidget(
        buildTestWidget(
          configId: null,
          repository: mockRepository,
        ),
      );

      // Allow async operations to complete
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
      // Build the widget in create mode
      await tester.pumpWidget(
        buildTestWidget(
          configId: null,
          repository: mockRepository,
        ),
      );

      // Allow async operations to complete
      await tester.pumpAndSettle();

      // Verify save button is not visible (form is invalid)
      expect(find.widgetWithText(TextButton, 'Save'), findsNothing);

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

      // Verify no save was attempted (since we didn't mock saveConfig,
      // if it was called it would throw)
      verifyNever(() => mockRepository.saveConfig(any()));
    });

    // Note: Testing form submission would be better handled in integration tests
    // since it's challenging to mock the form controller properly in widget tests.
  });
}
