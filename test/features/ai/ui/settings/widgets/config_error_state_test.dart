import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/ui/settings/widgets/config_error_state.dart';

void main() {
  group('ConfigErrorState', () {
    Widget createWidget({
      required Object error,
      VoidCallback? onRetry,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: ConfigErrorState(
            error: error,
            onRetry: onRetry,
          ),
        ),
      );
    }

    testWidgets('displays error icon and message', (WidgetTester tester) async {
      const errorMessage = 'Network connection failed';

      await tester.pumpWidget(createWidget(error: errorMessage));

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Error loading configurations'), findsOneWidget);
      expect(find.text(errorMessage), findsOneWidget);
    });

    testWidgets('shows retry button when onRetry is provided',
        (WidgetTester tester) async {
      var retryPressed = false;

      await tester.pumpWidget(createWidget(
        error: 'Test error',
        onRetry: () {
          retryPressed = true;
        },
      ));

      expect(find.text('Retry'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(retryPressed, isTrue);
    });

    testWidgets('hides retry button when onRetry is null',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget(
        error: 'Test error',
      ));

      expect(find.text('Retry'), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('displays error icon with correct size and color',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget(error: 'Error'));

      final icon = tester.widget<Icon>(find.byIcon(Icons.error_outline));
      expect(icon.size, 64);
      // Color is theme-dependent, so we just verify it's set
      expect(icon.color, isNotNull);
    });

    testWidgets('centers content properly', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget(error: 'Centered error'));

      // ConfigErrorState itself contains a Center widget
      // Find the column inside the center
      final columnFinder = find.descendant(
        of: find.byType(ConfigErrorState),
        matching: find.byType(Column),
      );
      expect(columnFinder, findsOneWidget);

      final column = tester.widget<Column>(columnFinder);
      expect(column.mainAxisAlignment, MainAxisAlignment.center);
    });

    testWidgets('handles exception objects as errors',
        (WidgetTester tester) async {
      final exception = Exception('Custom exception');

      await tester.pumpWidget(createWidget(error: exception));

      expect(find.text(exception.toString()), findsOneWidget);
    });

    testWidgets('maintains proper spacing between elements',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget(
        error: 'Error with retry',
        onRetry: () {},
      ));

      // Find only the spacing SizedBox widgets by their height
      final spacing16 = find.byWidgetPredicate(
        (widget) => widget is SizedBox && widget.height == 16.0,
      );
      final spacing8 = find.byWidgetPredicate(
        (widget) => widget is SizedBox && widget.height == 8.0,
      );

      // Should have 2 SizedBox widgets with height 16 and 1 with height 8
      expect(spacing16, findsNWidgets(2));
      expect(spacing8, findsOneWidget);
    });

    testWidgets('error message has proper padding',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget(
        error: 'This is a padded error message',
      ));

      final padding = tester.widget<Padding>(
        find.ancestor(
          of: find.text('This is a padded error message'),
          matching: find.byType(Padding),
        ),
      );

      expect(
        padding.padding,
        const EdgeInsets.symmetric(horizontal: 32),
      );
    });

    testWidgets('uses centered text alignment for error message',
        (WidgetTester tester) async {
      const longError = 'This is a very long error message that should '
          'be centered when displayed';

      await tester.pumpWidget(createWidget(error: longError));

      final errorText = tester.widget<Text>(find.text(longError));
      expect(errorText.textAlign, TextAlign.center);
    });

    testWidgets('retry button is properly styled as FilledButton',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget(
        error: 'Error',
        onRetry: () {},
      ));

      // Find any button that extends FilledButton (including FilledButton.icon)
      final filledButton = find.byWidgetPredicate(
        (widget) => widget is FilledButton,
      );
      expect(filledButton, findsOneWidget);

      // The button should have a retry icon
      expect(find.byIcon(Icons.refresh), findsOneWidget);

      // The button should have a retry label
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
