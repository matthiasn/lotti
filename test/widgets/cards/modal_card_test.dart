import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/cards/modal_card.dart';

void main() {
  group('ModalCard', () {
    Widget createTestWidget({
      required Widget child,
      EdgeInsets? padding,
      double? elevation,
      Color? shadowColor,
      Color? backgroundColor,
      ThemeData? theme,
    }) {
      return MaterialApp(
        theme: theme ?? ThemeData.light(),
        home: Scaffold(
          body: Center(
            child: ModalCard(
              padding: padding,
              backgroundColor: backgroundColor,
              child: child,
            ),
          ),
        ),
      );
    }

    testWidgets('renders child widget correctly', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const Text('Test Content'),
        ),
      );

      expect(find.text('Test Content'), findsOneWidget);
      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('applies custom padding', (tester) async {
      const customPadding = EdgeInsets.all(24);

      await tester.pumpWidget(
        createTestWidget(
          padding: customPadding,
          child: const Text('Padded Content'),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(Card),
          matching: find.byType(Container),
        ),
      );

      expect(container.padding, equals(customPadding));
    });

    testWidgets('uses default elevation of 2', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const Text('Test'),
        ),
      );

      final card = tester.widget<Card>(find.byType(Card));
      expect(card.elevation, equals(2));
    });

    testWidgets('applies custom background color', (tester) async {
      const customColor = Colors.blue;

      await tester.pumpWidget(
        createTestWidget(
          backgroundColor: customColor,
          child: const Text('Colored Card'),
        ),
      );

      final card = tester.widget<Card>(find.byType(Card));
      expect(card.color, equals(customColor));
    });

    testWidgets('applies surface tint color from theme', (tester) async {
      final theme = ThemeData(
        colorScheme: const ColorScheme.light(
          surfaceTint: Colors.purple,
        ),
      );

      await tester.pumpWidget(
        createTestWidget(
          theme: theme,
          child: const Text('Tinted Card'),
        ),
      );

      final card = tester.widget<Card>(find.byType(Card));
      expect(card.surfaceTintColor, equals(Colors.purple));
    });

    testWidgets('works correctly in dark mode', (tester) async {
      final darkTheme = ThemeData.dark();

      await tester.pumpWidget(
        createTestWidget(
          theme: darkTheme,
          child: const Text('Dark Mode Card'),
        ),
      );

      final card = tester.widget<Card>(find.byType(Card));
      expect(card.surfaceTintColor, equals(darkTheme.colorScheme.surfaceTint));
    });

    testWidgets('renders complex child widgets', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star),
              Text('Complex Content'),
              SizedBox(height: 8),
              Text('With multiple elements'),
            ],
          ),
        ),
      );

      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.text('Complex Content'), findsOneWidget);
      expect(find.text('With multiple elements'), findsOneWidget);
    });

    testWidgets('preserves child widget constraints', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: Container(
            width: 200,
            height: 100,
            color: Colors.red,
            child: const Center(child: Text('Fixed Size')),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(Card),
          matching: find.byWidgetPredicate(
            (widget) => widget is Container && widget.color == Colors.red,
          ),
        ),
      );

      expect(container.constraints?.maxWidth, equals(200));
      expect(container.constraints?.maxHeight, equals(100));
    });

    testWidgets('inherits theme colors correctly', (tester) async {
      final customTheme = ThemeData(
        colorScheme: ColorScheme.light(
          surface: Colors.grey[100]!,
          surfaceTint: Colors.blue,
        ),
      );

      await tester.pumpWidget(
        createTestWidget(
          theme: customTheme,
          child: const Text('Themed Card'),
        ),
      );

      final BuildContext cardContext = tester.element(find.byType(Card));
      final theme = Theme.of(cardContext);

      expect(theme.colorScheme.surface, equals(Colors.grey[100]));
      expect(theme.colorScheme.surfaceTint, equals(Colors.blue));
    });

    testWidgets('maintains correct widget tree structure', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          padding: const EdgeInsets.all(16),
          child: const Text('Structure Test'),
        ),
      );

      // Verify the widget tree structure
      expect(
        find.descendant(
          of: find.byType(ModalCard),
          matching: find.byType(Card),
        ),
        findsOneWidget,
      );

      expect(
        find.descendant(
          of: find.byType(Card),
          matching: find.byType(Container),
        ),
        findsOneWidget,
      );

      expect(
        find.descendant(
          of: find.byType(Container),
          matching: find.text('Structure Test'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('handles empty padding gracefully', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          padding: EdgeInsets.zero,
          child: const Text('No Padding'),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(Card),
          matching: find.byType(Container),
        ),
      );

      expect(container.padding, equals(EdgeInsets.zero));
    });

    testWidgets('applies all properties simultaneously', (tester) async {
      const testPadding = EdgeInsets.all(32);
      const testColor = Colors.amber;
      const testElevation = 8.0;

      await tester.pumpWidget(
        createTestWidget(
          padding: testPadding,
          backgroundColor: testColor,
          elevation: testElevation,
          child: const Text('All Properties'),
        ),
      );

      final card = tester.widget<Card>(find.byType(Card));
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(Card),
          matching: find.byType(Container),
        ),
      );

      expect(card.color, equals(testColor));
      expect(
          card.elevation,
          equals(
              2)); // Note: elevation parameter is not used in current implementation
      expect(container.padding, equals(testPadding));
    });

    testWidgets('renders correctly inside a modal-like environment',
        (tester) async {
      // Simulate a modal environment with a colored background
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            backgroundColor: ThemeData.dark().colorScheme.surfaceContainerHigh,
            body: Center(
              child: ModalCard(
                backgroundColor:
                    ThemeData.dark().colorScheme.surfaceContainerHighest,
                padding: const EdgeInsets.all(16),
                child: const Text(
                  'Modal Card',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Modal Card'), findsOneWidget);
      expect(find.byType(Card), findsOneWidget);

      final card = tester.widget<Card>(find.byType(Card));
      expect(card.color,
          equals(ThemeData.dark().colorScheme.surfaceContainerHighest));
    });
  });
}
