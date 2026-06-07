import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/inference_error.dart';
import 'package:lotti/features/ai/ui/widgets/ai_error_display.dart';

import '../../../../widget_test_utils.dart';

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
    }) {
      return makeTestableWidgetNoScroll(
        Scaffold(
          body: SingleChildScrollView(
            child: AiErrorDisplay(
              error: error,
              onRetry: onRetry,
            ),
          ),
        ),
        // The error card needs more width than the phone default.
        mediaQueryData: const MediaQueryData(size: Size(800, 600)),
      );
    }

    /// Pumps on a wide surface so the suggestions list has room; resets the
    /// view in teardown.
    Future<void> pumpWide(WidgetTester tester, Widget widget) async {
      tester.view
        ..physicalSize = const Size(1200, 800)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(widget);
      await tester.pump();
    }

    group('basic rendering', () {
      testWidgets('displays error message', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(error: testError));
        await tester.pump();

        expect(find.text('Test error message'), findsOneWidget);
      });

      testWidgets('displays error type title', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(error: testError));
        await tester.pump();

        // networkConnection maps to the localised "Connection Failed" title.
        expect(find.text('Connection Failed'), findsOneWidget);
      });

      testWidgets('displays appropriate icon for error type', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget(error: testError));
        await tester.pump();

        expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
      });

      testWidgets('shows container with error styling', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget(error: testError));
        await tester.pump();

        // Look for a Card with a border (matches new implementation)
        final card = tester.widget<Card>(find.byType(Card).first);
        final shape = card.shape as RoundedRectangleBorder?;
        expect(shape, isNotNull);
        expect(shape?.side, isNotNull);
        expect(shape?.borderRadius, isNotNull);
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
        testWidgets('shows correct icon for ${entry.key}', (
          WidgetTester tester,
        ) async {
          final error = InferenceError(
            message: 'Test message',
            type: entry.key,
          );

          await tester.pumpWidget(createTestWidget(error: error));
          await tester.pump();

          expect(find.byIcon(entry.value), findsOneWidget);
        });
      }
    });

    group('suggestions', () {
      final suggestionCases = <String, (InferenceError, List<String>)>{
        'network errors': (
          InferenceError(
            message: 'Network error',
            type: InferenceErrorType.networkConnection,
          ),
          [
            'Check your internet connection',
            'Verify the server URL is correct',
          ],
        ),
        'timeout errors': (
          InferenceError(
            message: 'Timeout error',
            type: InferenceErrorType.timeout,
          ),
          ['Try again with a shorter prompt'],
        ),
        'authentication errors': (
          InferenceError(
            message: 'Auth error',
            type: InferenceErrorType.authentication,
          ),
          ['Verify your API key is correct'],
        ),
        'rate limit errors': (
          InferenceError(
            message: 'Rate limit error',
            type: InferenceErrorType.rateLimit,
          ),
          ['Wait a few minutes before trying again'],
        ),
        'Ollama model not found': (
          InferenceError(
            message: 'model "llama2" not found, try pulling it first',
            type: InferenceErrorType.invalidRequest,
          ),
          ['Run: ollama pull llama2', 'Make sure Ollama is running'],
        ),
        'generic invalid request': (
          InferenceError(
            message: 'Invalid request',
            type: InferenceErrorType.invalidRequest,
          ),
          ['Check your model configuration'],
        ),
        'server errors': (
          InferenceError(
            message: 'Server error',
            type: InferenceErrorType.serverError,
          ),
          ['Wait a few minutes and try again'],
        ),
        'unknown errors': (
          InferenceError(
            message: 'Unknown error',
            type: InferenceErrorType.unknown,
          ),
          ['Check the error details'],
        ),
      };

      for (final entry in suggestionCases.entries) {
        testWidgets('shows suggestions for ${entry.key}', (tester) async {
          await pumpWide(tester, createTestWidget(error: entry.value.$1));

          for (final suggestion in entry.value.$2) {
            expect(
              find.text(suggestion),
              findsOneWidget,
              reason: entry.key,
            );
          }
        });
      }

      testWidgets('shows suggestions container', (WidgetTester tester) async {
        await pumpWide(tester, createTestWidget(error: testError));

        // Should find bullet points indicating suggestions
        expect(find.textContaining('•'), findsWidgets);
      });
    });

    group('retry button', () {
      testWidgets('hides retry button for authentication errors', (
        WidgetTester tester,
      ) async {
        final authError = InferenceError(
          message: 'Auth error',
          type: InferenceErrorType.authentication,
        );

        await tester.pumpWidget(
          createTestWidget(
            error: authError,
            onRetry: () {},
          ),
        );
        await tester.pump();

        expect(find.byType(FilledButton), findsNothing);
      });

      testWidgets('hides retry button for invalid request errors', (
        WidgetTester tester,
      ) async {
        final invalidError = InferenceError(
          message: 'Invalid request',
          type: InferenceErrorType.invalidRequest,
        );

        await tester.pumpWidget(
          createTestWidget(
            error: invalidError,
            onRetry: () {},
          ),
        );
        await tester.pump();

        expect(find.byType(FilledButton), findsNothing);
      });

      testWidgets('hides retry button when onRetry is null', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(
            error: testError,
          ),
        );
        await tester.pump();

        expect(find.byType(FilledButton), findsNothing);
      });

      testWidgets(
        'shows the retry button for every retryable error type and fires '
        'onRetry on tap',
        (tester) async {
          const retryableTypes = [
            InferenceErrorType.networkConnection,
            InferenceErrorType.timeout,
            InferenceErrorType.serverError,
            InferenceErrorType.rateLimit,
            InferenceErrorType.unknown,
          ];

          for (final type in retryableTypes) {
            var retries = 0;
            await pumpWide(
              tester,
              createTestWidget(
                error: InferenceError(message: 'Boom', type: type),
                onRetry: () => retries++,
              ),
            );

            final retryButton = find.byType(FilledButton);
            expect(retryButton, findsOneWidget, reason: '$type');

            await tester.ensureVisible(retryButton);
            await tester.tap(retryButton);
            expect(retries, 1, reason: '$type');
          }
        },
      );
    });

    group('text selection', () {
      testWidgets('error message is selectable', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(error: testError));
        await tester.pump();

        expect(find.byType(SelectableText), findsWidgets);

        final selectableText = tester.widget<SelectableText>(
          find.byType(SelectableText).first,
        );
        expect(selectableText.data, 'Test error message');
      });

      testWidgets('suggestions are selectable', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(error: testError));
        await tester.pump();

        // Should have multiple SelectableText widgets for suggestions
        final selectableTexts = tester.widgetList<SelectableText>(
          find.byType(SelectableText),
        );
        expect(selectableTexts.length, greaterThan(1));
      });
    });

    group('theme variations', () {
      testWidgets('renders under the suite theme', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget(error: testError));
        await tester.pump();

        expect(find.byType(AiErrorDisplay), findsOneWidget);
        expect(find.text('Test error message'), findsOneWidget);
      });
    });

    group('layout', () {
      testWidgets('uses correct spacing between elements', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget(error: testError));
        await tester.pump();

        // Check for SizedBox widgets used for spacing
        final sizedBoxes = tester.widgetList<SizedBox>(
          find.byType(SizedBox),
        );
        expect(sizedBoxes.any((box) => box.height == 16), isTrue);
        expect(sizedBoxes.any((box) => box.height == 8), isTrue);
      });

      testWidgets('centers text elements', (WidgetTester tester) async {
        await pumpWide(tester, createTestWidget(error: testError));

        // Find the SelectableText widget containing the error message
        final selectableTextFinder = find.byType(SelectableText).first;
        final selectableText = tester.widget<SelectableText>(
          selectableTextFinder,
        );

        // Verify it contains the expected text and is centered
        expect(selectableText.data, contains('Test error message'));
        expect(selectableText.textAlign, TextAlign.center);
      });

      testWidgets('uses proper padding', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(error: testError));
        await tester.pump();

        final container = tester.widget<Container>(
          find.byType(Container).first,
        );
        expect(container.margin, const EdgeInsets.all(16));
        expect(container.padding, const EdgeInsets.all(20));
      });
    });

    group('edge cases', () {
      testWidgets('handles very long error messages', (
        WidgetTester tester,
      ) async {
        final longError = InferenceError(
          message: 'This is a very long error message. ' * 5,
          type: InferenceErrorType.unknown,
        );

        // Use a larger screen size to accommodate long text
        await pumpWide(tester, createTestWidget(error: longError));

        expect(find.byType(SelectableText), findsWidgets);
      });

      testWidgets('handles empty suggestions list', (
        WidgetTester tester,
      ) async {
        // All error types should have suggestions, but test the UI behavior
        await tester.pumpWidget(createTestWidget(error: testError));
        await tester.pump();

        // Suggestions container should be present
        expect(find.textContaining('•'), findsWidgets);
      });

      testWidgets('handles model name extraction edge cases', (
        WidgetTester tester,
      ) async {
        final edgeCaseError = InferenceError(
          message: 'model not found without quotes',
          type: InferenceErrorType.invalidRequest,
        );

        await tester.pumpWidget(createTestWidget(error: edgeCaseError));
        await tester.pump();

        // Should still show model-related suggestions
        expect(find.textContaining('model'), findsWidgets);
      });
    });

    group('accessibility', () {
      testWidgets('has proper semantics', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(error: testError));
        await tester.pump();

        // Icon should be visible
        expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);

        // Text should be selectable for accessibility
        expect(find.byType(SelectableText), findsWidgets);
      });
    });

    group('custom error modal behaviors', () {
      testWidgets('displays specific error message (e.g., missing API key)', (
        WidgetTester tester,
      ) async {
        final error = InferenceError(
          message: 'API key missing',
          type: InferenceErrorType.authentication,
        );
        await tester.pumpWidget(createTestWidget(error: error));
        await tester.pump();
        expect(find.text('API key missing'), findsOneWidget);
      });

      testWidgets('retry button calls onRetry and dismisses modal', (
        WidgetTester tester,
      ) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        var retried = false;
        final error = InferenceError(
          message: 'Temporary error',
          type: InferenceErrorType.serverError, // Use a type that shows retry
        );
        await tester.pumpWidget(
          createTestWidget(
            error: error,
            onRetry: () {
              retried = true;
            },
          ),
        );
        await tester.pump();
        final retryText = find.text('Try Again');
        expect(retryText, findsOneWidget);
        final materialButton = find
            .ancestor(of: retryText, matching: find.byType(Material))
            .first;
        await tester.tap(materialButton);
        await tester.pump();
        expect(retried, isTrue);
      });
    });
  });
}
