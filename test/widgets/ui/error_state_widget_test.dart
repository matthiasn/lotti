import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/ui/error_state_widget.dart';

import '../../widget_test_utils.dart';

void main() {
  group('ErrorStateWidget Tests', () {
    testWidgets('displays error message in full mode', (tester) async {
      const errorMessage = 'Test error message';

      await _pumpErrorState(
        tester,
        error: errorMessage,
      );

      // Should display error icon
      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      // Should display default title
      expect(
        find.text(
          tester.element(find.byType(ErrorStateWidget)).messages.commonError,
        ),
        findsOneWidget,
      );

      // Should display error message
      expect(find.text(errorMessage), findsOneWidget);
    });

    testWidgets('announces full and inline errors as live regions', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pumpErrorState(tester, error: 'Connection failed');
      expect(
        tester.getSemantics(
          find.bySemanticsLabel('Error\nConnection failed'),
        ),
        matchesSemantics(isLiveRegion: true),
      );

      await _pumpErrorState(
        tester,
        error: 'Connection failed',
        mode: ErrorDisplayMode.inline,
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Connection failed')),
        matchesSemantics(label: 'Connection failed', isLiveRegion: true),
      );
      semantics.dispose();
    });

    testWidgets('displays custom title in full mode', (tester) async {
      const errorMessage = 'Test error message';
      const customTitle = 'Custom Error Title';

      await _pumpErrorState(
        tester,
        error: errorMessage,
        title: customTitle,
      );

      // Should display custom title
      expect(find.text(customTitle), findsOneWidget);

      // Should not display default title
      expect(
        find.text(
          tester.element(find.byType(ErrorStateWidget)).messages.commonError,
        ),
        findsNothing,
      );

      // Should display error message
      expect(find.text(errorMessage), findsOneWidget);
    });

    testWidgets('displays error message in inline mode', (tester) async {
      const errorMessage = 'Test inline error';

      await _pumpErrorState(
        tester,
        error: errorMessage,
        mode: ErrorDisplayMode.inline,
      );

      // Should not display error icon in inline mode
      expect(find.byIcon(Icons.error_outline), findsNothing);

      // Should display error message
      expect(find.text(errorMessage), findsOneWidget);

      // Should not display title in inline mode
      expect(
        find.text(
          tester.element(find.byType(ErrorStateWidget)).messages.commonError,
        ),
        findsNothing,
      );
    });

    testWidgets('inline mode has proper styling', (tester) async {
      const errorMessage = 'Test error';

      await _pumpErrorState(
        tester,
        error: errorMessage,
        mode: ErrorDisplayMode.inline,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
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

      await _pumpErrorState(
        tester,
        error: errorMessage,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
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
      await _pumpErrorState(tester, error: 'Test error');

      final icon = tester.widget<Icon>(find.byIcon(Icons.error_outline));
      expect(icon.size, 48);
    });

    testWidgets('text alignment is centered in full mode', (tester) async {
      await _pumpErrorState(
        tester,
        error: 'Test error',
        title: 'Error Title',
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
      const longError =
          'This is a very long error message that should '
          'wrap properly when displayed in the error widget. It contains '
          'multiple lines of text to test the wrapping behavior.';

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: ErrorStateWidget(error: longError),
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

      await _pumpErrorState(
        tester,
        error: 'Test error',
        theme: theme,
      );

      // Icon should use error color
      final icon = tester.widget<Icon>(find.byIcon(Icons.error_outline));
      expect(icon.color, theme.colorScheme.error);
    });
  });
}

Future<void> _pumpErrorState(
  WidgetTester tester, {
  required String error,
  String? title,
  ErrorDisplayMode mode = ErrorDisplayMode.full,
  ThemeData? theme,
}) {
  return tester.pumpWidget(
    makeTestableWidgetNoScroll(
      Scaffold(
        body: ErrorStateWidget(
          error: error,
          title: title,
          mode: mode,
        ),
      ),
      theme: theme,
    ),
  );
}
