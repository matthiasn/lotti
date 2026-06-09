import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/search/lotti_search_bar.dart';

void main() {
  group('LottiSearchBar', () {
    late TextEditingController controller;

    setUp(() {
      controller = TextEditingController();
    });

    tearDown(() {
      controller.dispose();
    });

    Widget createTestWidget({
      required Widget child,
      ThemeData? theme,
    }) {
      return MaterialApp(
        theme: theme ?? ThemeData.light(),
        home: Scaffold(
          body: child,
        ),
      );
    }

    testWidgets('renders correctly with default properties', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: LottiSearchBar(controller: controller),
        ),
      );

      expect(find.byType(LottiSearchBar), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
      expect(find.text('Search...'), findsOneWidget);
    });

    testWidgets('renders with custom hint text', (tester) async {
      const customHint = 'Search categories...';
      await tester.pumpWidget(
        createTestWidget(
          child: LottiSearchBar(
            controller: controller,
            hintText: customHint,
          ),
        ),
      );

      expect(find.text(customHint), findsOneWidget);
    });

    testWidgets('shows clear button when text is entered', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: LottiSearchBar(controller: controller),
        ),
      );

      // Initially, clear button should not be visible
      expect(find.byIcon(Icons.clear_rounded), findsNothing);

      // Enter some text
      controller.text = 'test';
      await tester.pump();

      // Clear button should now be visible
      expect(find.byIcon(Icons.clear_rounded), findsOneWidget);
    });

    testWidgets('clears text when clear button is tapped', (tester) async {
      var clearCalled = false;

      await tester.pumpWidget(
        createTestWidget(
          child: LottiSearchBar(
            controller: controller,
            onClear: () {
              clearCalled = true;
            },
          ),
        ),
      );

      // Enter text
      controller.text = 'test';
      await tester.pump();

      // Tap clear button
      await tester.tap(find.byIcon(Icons.clear_rounded));
      await tester.pump();

      // Text should be cleared and callback should be called
      expect(controller.text, isEmpty);
      expect(clearCalled, isTrue);
    });

    testWidgets('calls onChanged when text changes', (tester) async {
      String? changedValue;

      await tester.pumpWidget(
        createTestWidget(
          child: LottiSearchBar(
            controller: controller,
            onChanged: (value) {
              changedValue = value;
            },
          ),
        ),
      );

      // Enter text
      await tester.enterText(find.byType(TextField), 'test search');
      await tester.pump();

      expect(changedValue, equals('test search'));
    });

    testWidgets('renders in compact mode', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: LottiSearchBar(
            controller: controller,
            isCompact: true,
          ),
        ),
      );

      final container = tester.widget<Container>(
        find
            .ancestor(
              of: find.byType(TextField),
              matching: find.byType(Container),
            )
            .first,
      );

      expect(container.constraints?.maxHeight, equals(36));
    });

    testWidgets('renders in normal mode', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: LottiSearchBar(
            controller: controller,
          ),
        ),
      );

      final container = tester.widget<Container>(
        find
            .ancestor(
              of: find.byType(TextField),
              matching: find.byType(Container),
            )
            .first,
      );

      expect(container.constraints?.maxHeight, equals(48));
    });

    testWidgets('applies correct styling in light theme', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          theme: ThemeData.light(),
          child: LottiSearchBar(controller: controller),
        ),
      );

      final container = tester.widget<Container>(
        find
            .ancestor(
              of: find.byType(TextField),
              matching: find.byType(Container),
            )
            .first,
      );

      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, isNotNull);
      expect(decoration.gradient, isNull);
    });

    testWidgets('applies correct styling in dark theme', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          theme: ThemeData.dark(),
          child: LottiSearchBar(controller: controller),
        ),
      );

      final container = tester.widget<Container>(
        find
            .ancestor(
              of: find.byType(TextField),
              matching: find.byType(Container),
            )
            .first,
      );

      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.gradient, isNotNull);
    });

    testWidgets('disposes properly when removed from widget tree', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(
          child: LottiSearchBar(controller: controller),
        ),
      );

      controller.text = 'test';
      await tester.pump();

      // Remove widget from tree
      await tester.pumpWidget(
        createTestWidget(
          child: const SizedBox(),
        ),
      );

      // Should not throw
      controller.text = 'new text';
    });
  });
}
