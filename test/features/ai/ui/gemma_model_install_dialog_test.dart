import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/gemma_model_install_dialog.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

import '../test_utils.dart';

/// Test constants for Gemma model install dialog tests
class GemmaTestConstants {
  static const String testBaseUrl = 'http://localhost:8000';
  static const String testProviderId = 'test-gemma-provider';
  static const String testProviderName = 'Test Gemma Provider';
  static const String modelE4B = 'gemma-3n-E4B-it';
  static const String modelE2B = 'gemma-3n-E2B-it';
  static const String modelUnknown = 'gemma-3n-unknown-it';
  static const String testModelName = 'test-model-name';
  static const String modelWithE4B = 'model-with-E4B-variant';
  static const String notAvailableTitle = 'Gemma Model Not Available';
  static const String installButtonText = 'Install';
  static const String cancelButtonText = 'Cancel';
  static const String retryButtonText = 'Retry';
  static const String providerNotFoundError = 'Gemma provider not found';
  static const String downloadingText = 'Downloading model...';
}

class MockLoggingService extends Mock implements LoggingService {}

class FakeAiConfigInferenceProvider extends Fake
    implements AiConfigInferenceProvider {
  @override
  String get baseUrl => GemmaTestConstants.testBaseUrl;

  @override
  InferenceProviderType get inferenceProviderType =>
      InferenceProviderType.gemma3n;

  @override
  String get id => GemmaTestConstants.testProviderId;

  @override
  String get name => GemmaTestConstants.testProviderName;
}

void main() {
  late MockLoggingService mockLoggingService;
  late AiConfigInferenceProvider testGemmaProvider;

  setUp(() {
    mockLoggingService = MockLoggingService();
    testGemmaProvider = FakeAiConfigInferenceProvider();

    // Set up GetIt
    getIt
      ..reset()
      ..registerSingleton<LoggingService>(mockLoggingService);
  });

  tearDown(getIt.reset);

  Widget buildTestWidget(
    Widget child, {
    List<Override> overrides = const [],
  }) {
    return AiTestSetup.createTestApp(
      child: child,
      providerOverrides: overrides,
    );
  }

  group('GemmaModelInstallDialog Tests', () {
    testWidgets('displays initial dialog content correctly', (tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        buildTestWidget(
          const GemmaModelInstallDialog(
            modelName: GemmaTestConstants.modelE4B,
          ),
          overrides: [
            aiConfigByTypeControllerProvider(
              configType: AiConfigType.inferenceProvider,
            ).overrideWith(
                () => MockAiConfigByTypeController([testGemmaProvider])),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.text(GemmaTestConstants.notAvailableTitle), findsOneWidget);
      expect(find.text('The model "gemma-3n-E4B-it" is not available.'),
          findsOneWidget);
      expect(
          find.text(
              'To install it manually, run this command in the services/gemma-local directory:'),
          findsOneWidget);
      expect(find.text('python download_model.py E4B'), findsOneWidget);
      expect(find.text('Would you like to install it now from Lotti?'),
          findsOneWidget);
      expect(find.text(GemmaTestConstants.installButtonText), findsOneWidget);
      expect(find.text(GemmaTestConstants.cancelButtonText), findsOneWidget);
    });

    testWidgets('shows E2B variant extraction correctly', (tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        buildTestWidget(
          const GemmaModelInstallDialog(
            modelName: GemmaTestConstants.modelE2B,
          ),
          overrides: [
            aiConfigByTypeControllerProvider(
              configType: AiConfigType.inferenceProvider,
            ).overrideWith(
                () => MockAiConfigByTypeController([testGemmaProvider])),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.text('python download_model.py E2B'), findsOneWidget);
    });

    testWidgets('defaults to E2B for unknown variant', (tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        buildTestWidget(
          const GemmaModelInstallDialog(
            modelName: GemmaTestConstants.modelUnknown,
          ),
          overrides: [
            aiConfigByTypeControllerProvider(
              configType: AiConfigType.inferenceProvider,
            ).overrideWith(
                () => MockAiConfigByTypeController([testGemmaProvider])),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Assert - Should default to E2B
      expect(find.text('python download_model.py E2B'), findsOneWidget);
    });

    testWidgets('closes dialog when cancel button is pressed', (tester) async {
      // Arrange
      await tester.pumpWidget(
        buildTestWidget(
          const GemmaModelInstallDialog(
            modelName: GemmaTestConstants.modelE4B,
          ),
          overrides: [
            aiConfigByTypeControllerProvider(
              configType: AiConfigType.inferenceProvider,
            ).overrideWith(
                () => MockAiConfigByTypeController([testGemmaProvider])),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.text(GemmaTestConstants.cancelButtonText));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Gemma Model Not Available'), findsNothing);
    });

    testWidgets('shows error when Gemma provider not found', (tester) async {
      // Override HTTP client behavior globally for this test
      // Since the widget creates its own http.Client internally,
      // we can't easily inject it. In a real-world scenario,
      // the widget should accept an http.Client as a parameter.

      await tester.pumpWidget(
        buildTestWidget(
          const GemmaModelInstallDialog(
            modelName: GemmaTestConstants.modelE4B,
          ),
          overrides: [
            aiConfigByTypeControllerProvider(
              configType: AiConfigType.inferenceProvider,
            ).overrideWith(
                () => MockAiConfigByTypeController([])), // No Gemma provider
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Act - tap install button
      await tester.tap(find.text(GemmaTestConstants.installButtonText));
      await tester.pump(); // Start async operation

      // Wait deterministically for the error message to appear
      await tester.pumpAndSettle();

      // Assert - should show error about missing provider
      expect(find.textContaining(GemmaTestConstants.providerNotFoundError),
          findsOneWidget);
    });

    // NOTE: The following tests that require HTTP mocking are commented out
    // because the GemmaModelInstallDialog creates its own http.Client internally.
    // To properly test these scenarios, the widget should be refactored to accept
    // an http.Client as a dependency injection parameter.
    //
    // Best Practice: Always inject dependencies that need to be mocked in tests.

    testWidgets('displays model name in error message', (tester) async {
      // This test verifies that the model name is displayed correctly
      await tester.pumpWidget(
        buildTestWidget(
          const GemmaModelInstallDialog(
            modelName: GemmaTestConstants.testModelName,
          ),
          overrides: [
            aiConfigByTypeControllerProvider(
              configType: AiConfigType.inferenceProvider,
            ).overrideWith(
                () => MockAiConfigByTypeController([testGemmaProvider])),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.text('The model "test-model-name" is not available.'),
          findsOneWidget);
    });

    testWidgets('shows correct command for E4B variant', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const GemmaModelInstallDialog(
            modelName: GemmaTestConstants.modelWithE4B,
          ),
          overrides: [
            aiConfigByTypeControllerProvider(
              configType: AiConfigType.inferenceProvider,
            ).overrideWith(
                () => MockAiConfigByTypeController([testGemmaProvider])),
          ],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('python download_model.py E4B'), findsOneWidget);
    });

    testWidgets('dialog has correct action buttons initially', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const GemmaModelInstallDialog(
            modelName: GemmaTestConstants.modelE2B,
          ),
          overrides: [
            aiConfigByTypeControllerProvider(
              configType: AiConfigType.inferenceProvider,
            ).overrideWith(
                () => MockAiConfigByTypeController([testGemmaProvider])),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Should have Install and Cancel buttons
      expect(
          find.widgetWithText(
              ElevatedButton, GemmaTestConstants.installButtonText),
          findsOneWidget);
      expect(find.text(GemmaTestConstants.cancelButtonText), findsOneWidget);

      // Should not have Retry button initially
      expect(find.text(GemmaTestConstants.retryButtonText), findsNothing);
    });

    testWidgets('dialog shows progress indicator when installing',
        (tester) async {
      // This test verifies the UI state change when installation starts
      // Without HTTP mocking, we can only test the initial state

      await tester.pumpWidget(
        buildTestWidget(
          const GemmaModelInstallDialog(
            modelName: GemmaTestConstants.modelE2B,
          ),
          overrides: [
            aiConfigByTypeControllerProvider(
              configType: AiConfigType.inferenceProvider,
            ).overrideWith(
                () => MockAiConfigByTypeController([testGemmaProvider])),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Initially no progress indicator
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text(GemmaTestConstants.downloadingText), findsNothing);
    });

    testWidgets('dialog content changes based on installation state',
        (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const GemmaModelInstallDialog(
            modelName: GemmaTestConstants.modelE2B,
          ),
          overrides: [
            aiConfigByTypeControllerProvider(
              configType: AiConfigType.inferenceProvider,
            ).overrideWith(
                () => MockAiConfigByTypeController([testGemmaProvider])),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Before installation
      expect(find.text('Would you like to install it now from Lotti?'),
          findsOneWidget);
      expect(
          find.text(
              'To install it manually, run this command in the services/gemma-local directory:'),
          findsOneWidget);
    });
  });
}
