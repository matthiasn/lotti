import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/ui/error_state_widget.dart';

void main() {
  group('ErrorStateWidget Tests', () {
    testWidgets('displays error message in full mode', (tester) async {
      const errorMessage = 'Test error message';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ErrorStateWidget(
              error: errorMessage,
            ),
          ),
        ),
      );

      // Should display error icon
      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      // Should display default title
      expect(find.text('Error'), findsOneWidget);

      // Should display error message
      expect(find.text(errorMessage), findsOneWidget);
    });

    testWidgets('displays custom title in full mode', (tester) async {
      const errorMessage = 'Test error message';
      const customTitle = 'Custom Error Title';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ErrorStateWidget(
              error: errorMessage,
              title: customTitle,
            ),
          ),
        ),
      );

      // Should display custom title
      expect(find.text(customTitle), findsOneWidget);

      // Should not display default title
      expect(find.text('Error'), findsNothing);

      // Should display error message
      expect(find.text(errorMessage), findsOneWidget);
    });

    testWidgets('displays error message in inline mode', (tester) async {
      const errorMessage = 'Test inline error';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ErrorStateWidget(
              error: errorMessage,
              mode: ErrorDisplayMode.inline,
            ),
          ),
        ),
      );

      // Should not display error icon in inline mode
      expect(find.byIcon(Icons.error_outline), findsNothing);

      // Should display error message
      expect(find.text(errorMessage), findsOneWidget);

      // Should not display title in inline mode
      expect(find.text('Error'), findsNothing);
    });

    testWidgets('inline mode has proper styling', (tester) async {
      const errorMessage = 'Test error';

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
            ),
          ),
          home: const Scaffold(
            body: ErrorStateWidget(
              error: errorMessage,
              mode: ErrorDisplayMode.inline,
            ),
          ),
        ),
      );

      // Find the container
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(ErrorStateWidget),
              matching: find.byType(Container),
            )
            .first,
      );

      // Verify it has proper decoration
      expect(container.decoration, isA<BoxDecoration>());
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(8));
    });

    testWidgets('full mode has proper container styling', (tester) async {
      const errorMessage = 'Test error';

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
            ),
          ),
          home: const Scaffold(
            body: ErrorStateWidget(
              error: errorMessage,
            ),
          ),
        ),
      );

      // Find the container
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(ErrorStateWidget),
              matching: find.byType(Container),
            )
            .first,
      );

      // Verify it has proper decoration
      expect(container.decoration, isA<BoxDecoration>());
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(12));
      expect(decoration.border, isNotNull);
    });

    testWidgets('icon has correct size in full mode', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ErrorStateWidget(
              error: 'Test error',
            ),
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.error_outline));
      expect(icon.size, 48);
    });

    testWidgets('text alignment is centered in full mode', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ErrorStateWidget(
              error: 'Test error',
              title: 'Error Title',
            ),
          ),
        ),
      );

      // Find all text widgets
      final texts = find.byType(Text);

      // Both title and error text should be center aligned
      for (var i = 0; i < texts.evaluate().length; i++) {
        final text = tester.widget<Text>(texts.at(i));
        expect(text.textAlign, TextAlign.center);
      }
    });

    testWidgets('handles long error messages gracefully', (tester) async {
      const longError = 'This is a very long error message that should '
          'wrap properly when displayed in the error widget. It contains '
          'multiple lines of text to test the wrapping behavior.';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: ErrorStateWidget(
                  error: longError,
                ),
              ),
            ),
          ),
        ),
      );

      // Should display the full error message
      expect(find.text(longError), findsOneWidget);
    });

    testWidgets('respects theme colors', (tester) async {
      final theme = ThemeData(
        colorScheme: const ColorScheme.light(
          error: Colors.red,
          errorContainer: Colors.redAccent,
          onErrorContainer: Colors.white,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: ErrorStateWidget(
              error: 'Test error',
            ),
          ),
        ),
      );

      // Icon should use error color
      final icon = tester.widget<Icon>(find.byIcon(Icons.error_outline));
      expect(icon.color, theme.colorScheme.error);
    });
  });
}
