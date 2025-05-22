import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/ui/settings/inference_model_edit_page.dart';
import 'package:lotti/features/ai/ui/settings/inference_model_form.dart';
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

    // Note: Testing form submission would be better handled in integration tests
    // since it's challenging to mock the form controller properly in widget tests.
  });
}
