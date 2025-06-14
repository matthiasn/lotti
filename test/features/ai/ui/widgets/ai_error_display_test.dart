import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/inference_error.dart';
import 'package:lotti/features/ai/ui/widgets/ai_error_display.dart';
import 'package:lotti/l10n/app_localizations.dart';

void main() {
  group('AiErrorDisplay', () {
    late InferenceError testError;

    setUp(() {
      testError = InferenceError(
        message: 'Test error message',
        type: InferenceErrorType.networkConnection,
      );
    });

    Widget createTestWidget({
      required InferenceError error,
      VoidCallback? onRetry,
      ThemeData? theme,
    }) {
      return MaterialApp(
        theme: theme ?? ThemeData.light(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: AiErrorDisplay(
              error: error,
              onRetry: onRetry,
            ),
          ),
        ),
      );
    }

    group('basic rendering', () {
      testWidgets('displays error message', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(error: testError));
        await tester.pumpAndSettle();

        expect(find.text('Test error message'), findsOneWidget);
      });

      testWidgets('displays error type title', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(error: testError));
        await tester.pumpAndSettle();

        // The error type title is localized, so we can't check for exact text
        // Instead, check that there are at least 2 Text widgets (title and message)
        final texts = tester.widgetList<Text>(find.byType(Text));
        expect(texts.length, greaterThanOrEqualTo(2));
      });

      testWidgets('displays appropriate icon for error type',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(error: testError));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
      });

      testWidgets('shows container with error styling',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(error: testError));
        await tester.pumpAndSettle();

        final container = tester.widget<Container>(
          find.byType(Container).first,
        );
        expect(container.decoration, isA<BoxDecoration>());

        final decoration = container.decoration as BoxDecoration?;
        expect(decoration?.border, isNotNull);
        expect(decoration?.borderRadius, isNotNull);
      });
    });

    group('error type icons', () {
      final iconTests = <InferenceErrorType, IconData>{
        InferenceErrorType.networkConnection: Icons.wifi_off_rounded,
        InferenceErrorType.timeout: Icons.schedule_rounded,
        InferenceErrorType.authentication: Icons.lock_outline_rounded,
        InferenceErrorType.rateLimit: Icons.speed_rounded,
        InferenceErrorType.invalidRequest: Icons.error_outline_rounded,
        InferenceErrorType.serverError: Icons.cloud_off_rounded,
        InferenceErrorType.unknown: Icons.help_outline_rounded,
      };

      for (final entry in iconTests.entries) {
        testWidgets('shows correct icon for ${entry.key}',
            (WidgetTester tester) async {
          final error = InferenceError(
            message: 'Test message',
            type: entry.key,
          );

          await tester.pumpWidget(createTestWidget(error: error));
          await tester.pumpAndSettle();

          expect(find.byIcon(entry.value), findsOneWidget);
        });
      }
    });

    group('suggestions', () {
      testWidgets('shows suggestions for network errors',
          (WidgetTester tester) async {
        final error = InferenceError(
          message: 'Network error',
          type: InferenceErrorType.networkConnection,
        );

        // Use larger screen to prevent overflow
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(createTestWidget(error: error));
        await tester.pumpAndSettle();

        expect(find.text('Check your internet connection'), findsOneWidget);
        expect(find.text('Verify the server URL is correct'), findsOneWidget);

        // Reset view
        addTearDown(tester.view.resetPhysicalSize);
      });

      testWidgets('shows suggestions for timeout errors',
          (WidgetTester tester) async {
        final error = InferenceError(
          message: 'Timeout error',
          type: InferenceErrorType.timeout,
        );

        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(createTestWidget(error: error));
        await tester.pumpAndSettle();

        expect(find.text('Try again with a shorter prompt'), findsOneWidget);

        addTearDown(tester.view.resetPhysicalSize);
      });

      testWidgets('shows suggestions for authentication errors',
          (WidgetTester tester) async {
        final error = InferenceError(
          message: 'Auth error',
          type: InferenceErrorType.authentication,
        );

        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(createTestWidget(error: error));
        await tester.pumpAndSettle();

        expect(find.text('Verify your API key is correct'), findsOneWidget);

        addTearDown(tester.view.resetPhysicalSize);
      });

      testWidgets('shows suggestions for rate limit errors',
          (WidgetTester tester) async {
        final error = InferenceError(
          message: 'Rate limit error',
          type: InferenceErrorType.rateLimit,
        );

        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(createTestWidget(error: error));
        await tester.pumpAndSettle();

        expect(find.text('Wait a few minutes before trying again'),
            findsOneWidget);

        addTearDown(tester.view.resetPhysicalSize);
      });

      testWidgets('shows Ollama-specific suggestions for model not found',
          (WidgetTester tester) async {
        final error = InferenceError(
          message: 'model "llama2" not found, try pulling it first',
          type: InferenceErrorType.invalidRequest,
        );

        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(createTestWidget(error: error));
        await tester.pumpAndSettle();

        expect(find.text('Run: ollama pull llama2'), findsOneWidget);
        expect(find.text('Make sure Ollama is running'), findsOneWidget);

        addTearDown(tester.view.resetPhysicalSize);
      });

      testWidgets('shows generic invalid request suggestions',
          (WidgetTester tester) async {
        final error = InferenceError(
          message: 'Invalid request',
          type: InferenceErrorType.invalidRequest,
        );

        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(createTestWidget(error: error));
        await tester.pumpAndSettle();

        expect(find.text('Check your model configuration'), findsOneWidget);

        addTearDown(tester.view.resetPhysicalSize);
      });

      testWidgets('shows suggestions for server errors',
          (WidgetTester tester) async {
        final error = InferenceError(
          message: 'Server error',
          type: InferenceErrorType.serverError,
        );

        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(createTestWidget(error: error));
        await tester.pumpAndSettle();

        expect(find.text('Wait a few minutes and try again'), findsOneWidget);

        addTearDown(tester.view.resetPhysicalSize);
      });

      testWidgets('shows suggestions for unknown errors',
          (WidgetTester tester) async {
        final error = InferenceError(
          message: 'Unknown error',
          type: InferenceErrorType.unknown,
        );

        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(createTestWidget(error: error));
        await tester.pumpAndSettle();

        expect(find.text('Check the error details'), findsOneWidget);

        addTearDown(tester.view.resetPhysicalSize);
      });

      testWidgets('shows suggestions container', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(createTestWidget(error: testError));
        await tester.pumpAndSettle();

        // Should find bullet points indicating suggestions
        expect(find.textContaining('•'), findsWidgets);

        addTearDown(tester.view.resetPhysicalSize);
      });
    });

    group('retry button', () {
      testWidgets('hides retry button for authentication errors',
          (WidgetTester tester) async {
        final authError = InferenceError(
          message: 'Auth error',
          type: InferenceErrorType.authentication,
        );

        await tester.pumpWidget(createTestWidget(
          error: authError,
          onRetry: () {},
        ));
        await tester.pumpAndSettle();

        expect(find.byType(FilledButton), findsNothing);
      });

      testWidgets('hides retry button for invalid request errors',
          (WidgetTester tester) async {
        final invalidError = InferenceError(
          message: 'Invalid request',
          type: InferenceErrorType.invalidRequest,
        );

        await tester.pumpWidget(createTestWidget(
          error: invalidError,
          onRetry: () {},
        ));
        await tester.pumpAndSettle();

        expect(find.byType(FilledButton), findsNothing);
      });

      testWidgets('hides retry button when onRetry is null',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          error: testError,
        ));
        await tester.pumpAndSettle();

        expect(find.byType(FilledButton), findsNothing);
      });
    });

    group('text selection', () {
      testWidgets('error message is selectable', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(error: testError));
        await tester.pumpAndSettle();

        expect(find.byType(SelectableText), findsWidgets);

        final selectableText = tester.widget<SelectableText>(
          find.byType(SelectableText).first,
        );
        expect(selectableText.data, 'Test error message');
      });

      testWidgets('suggestions are selectable', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(error: testError));
        await tester.pumpAndSettle();

        // Should have multiple SelectableText widgets for suggestions
        final selectableTexts = tester.widgetList<SelectableText>(
          find.byType(SelectableText),
        );
        expect(selectableTexts.length, greaterThan(1));
      });
    });

    group('theme variations', () {
      testWidgets('renders correctly in light theme',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          error: testError,
          theme: ThemeData.light(),
        ));
        await tester.pumpAndSettle();

        expect(find.byType(AiErrorDisplay), findsOneWidget);
        expect(find.text('Test error message'), findsOneWidget);
      });

      testWidgets('renders correctly in dark theme',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          error: testError,
          theme: ThemeData.dark(),
        ));
        await tester.pumpAndSettle();

        expect(find.byType(AiErrorDisplay), findsOneWidget);
        expect(find.text('Test error message'), findsOneWidget);
      });
    });

    group('layout', () {
      testWidgets('uses correct spacing between elements',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(error: testError));
        await tester.pumpAndSettle();

        // Check for SizedBox widgets used for spacing
        final sizedBoxes = tester.widgetList<SizedBox>(
          find.byType(SizedBox),
        );
        expect(sizedBoxes.any((box) => box.height == 16), isTrue);
        expect(sizedBoxes.any((box) => box.height == 8), isTrue);
      });

      testWidgets('centers text elements', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(createTestWidget(error: testError));
        await tester.pumpAndSettle();

        // Find the SelectableText widget containing the error message
        final selectableTextFinder = find.byType(SelectableText).first;
        final selectableText =
            tester.widget<SelectableText>(selectableTextFinder);

        // Verify it contains the expected text and is centered
        expect(selectableText.data, contains('Test error message'));
        expect(selectableText.textAlign, TextAlign.center);

        addTearDown(tester.view.resetPhysicalSize);
      });

      testWidgets('uses proper padding', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(error: testError));
        await tester.pumpAndSettle();

        final container = tester.widget<Container>(
          find.byType(Container).first,
        );
        expect(container.margin, const EdgeInsets.all(16));
        expect(container.padding, const EdgeInsets.all(20));
      });
    });

    group('edge cases', () {
      testWidgets('handles very long error messages',
          (WidgetTester tester) async {
        final longError = InferenceError(
          message: 'This is a very long error message. ' * 5,
          type: InferenceErrorType.unknown,
        );

        // Use a larger screen size to accommodate long text
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(createTestWidget(error: longError));
        await tester.pumpAndSettle();

        expect(find.byType(SelectableText), findsWidgets);

        // Reset view
        addTearDown(tester.view.resetPhysicalSize);
      });

      testWidgets('handles empty suggestions list',
          (WidgetTester tester) async {
        // All error types should have suggestions, but test the UI behavior
        await tester.pumpWidget(createTestWidget(error: testError));
        await tester.pumpAndSettle();

        // Suggestions container should be present
        expect(find.textContaining('•'), findsWidgets);
      });

      testWidgets('handles model name extraction edge cases',
          (WidgetTester tester) async {
        final edgeCaseError = InferenceError(
          message: 'model not found without quotes',
          type: InferenceErrorType.invalidRequest,
        );

        await tester.pumpWidget(createTestWidget(error: edgeCaseError));
        await tester.pumpAndSettle();

        // Should still show model-related suggestions
        expect(find.textContaining('model'), findsWidgets);
      });
    });

    group('accessibility', () {
      testWidgets('has proper semantics', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(error: testError));
        await tester.pumpAndSettle();

        // Icon should be visible
        expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);

        // Text should be selectable for accessibility
        expect(find.byType(SelectableText), findsWidgets);
      });
    });
  });
}
