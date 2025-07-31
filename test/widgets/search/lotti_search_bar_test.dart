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

    testWidgets('disposes properly when removed from widget tree',
        (tester) async {
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

    group('Edge Cases', () {
      testWidgets('handles very long search text', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: LottiSearchBar(controller: controller),
          ),
        );

        final longText = 'a' * 200;
        await tester.enterText(find.byType(TextField), longText);
        await tester.pump();

        expect(controller.text, equals(longText));
        expect(find.byIcon(Icons.clear_rounded), findsOneWidget);
      });

      testWidgets('handles empty hint text', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: LottiSearchBar(
              controller: controller,
              hintText: '',
            ),
          ),
        );

        // With empty hint text, there's the empty text in the TextField and the hint
        expect(find.text(''), findsAtLeastNWidgets(1));
      });

      testWidgets('handles rapid text changes', (tester) async {
        final changes = <String>[];
        await tester.pumpWidget(
          createTestWidget(
            child: LottiSearchBar(
              controller: controller,
              onChanged: changes.add,
            ),
          ),
        );

        // Rapid typing simulation
        await tester.enterText(find.byType(TextField), 'a');
        await tester.pump();
        await tester.enterText(find.byType(TextField), 'ab');
        await tester.pump();
        await tester.enterText(find.byType(TextField), 'abc');
        await tester.pump();

        expect(changes.length, greaterThanOrEqualTo(3));
        expect(controller.text, equals('abc'));
      });

      testWidgets('handles special characters in search', (tester) async {
        String? searchValue;
        await tester.pumpWidget(
          createTestWidget(
            child: LottiSearchBar(
              controller: controller,
              onChanged: (value) => searchValue = value,
            ),
          ),
        );

        const specialChars = '@#\$%^&*()_+{}[]|\\:";\'<>?,./';
        await tester.enterText(find.byType(TextField), specialChars);
        await tester.pump();

        expect(searchValue, equals(specialChars));
        expect(controller.text, equals(specialChars));
      });

      testWidgets('handles Unicode characters', (tester) async {
        String? searchValue;
        await tester.pumpWidget(
          createTestWidget(
            child: LottiSearchBar(
              controller: controller,
              onChanged: (value) => searchValue = value,
            ),
          ),
        );

        const unicodeText = '🔍 Búsqueda 搜索 поиск';
        await tester.enterText(find.byType(TextField), unicodeText);
        await tester.pump();

        expect(searchValue, equals(unicodeText));
        expect(find.text(unicodeText), findsOneWidget);
      });

      testWidgets('clear button only calls onClear if provided',
          (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: LottiSearchBar(
              controller: controller,
              // No onClear callback
            ),
          ),
        );

        controller.text = 'test';
        await tester.pump();

        // Should not throw when tapping clear without onClear
        await tester.tap(find.byIcon(Icons.clear_rounded));
        await tester.pump();

        expect(controller.text, isEmpty);
      });

      testWidgets('handles controller changes', (tester) async {
        final controller2 = TextEditingController();

        await tester.pumpWidget(
          createTestWidget(
            child: LottiSearchBar(controller: controller),
          ),
        );

        controller.text = 'first controller';
        await tester.pump();
        expect(find.byIcon(Icons.clear_rounded), findsOneWidget);

        // Change to different controller
        await tester.pumpWidget(
          createTestWidget(
            child: LottiSearchBar(controller: controller2),
          ),
        );
        await tester.pump(); // Allow widget to rebuild

        expect(find.byIcon(Icons.clear_rounded), findsNothing);

        controller2.text = 'second controller';
        await tester.pump();
        await tester.pump(); // Extra pump to ensure state update
        expect(find.byIcon(Icons.clear_rounded), findsOneWidget);

        controller2.dispose();
      });

      testWidgets('maintains state during rebuilds', (tester) async {
        var rebuildCount = 0;

        await tester.pumpWidget(
          createTestWidget(
            child: StatefulBuilder(
              builder: (context, setState) {
                rebuildCount++;
                return LottiSearchBar(controller: controller);
              },
            ),
          ),
        );

        controller.text = 'test';
        await tester.pump();

        // Force rebuild
        await tester.pumpWidget(
          createTestWidget(
            child: StatefulBuilder(
              builder: (context, setState) {
                rebuildCount++;
                return LottiSearchBar(controller: controller);
              },
            ),
          ),
        );

        expect(controller.text, equals('test'));
        expect(find.byIcon(Icons.clear_rounded), findsOneWidget);
        expect(rebuildCount, equals(2));
      });

      testWidgets('accessibility - semantic labels are present',
          (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: LottiSearchBar(controller: controller),
          ),
        );

        // Check search icon semantic label
        final searchIcon =
            tester.widget<Icon>(find.byIcon(Icons.search_rounded));
        expect(searchIcon.semanticLabel, equals('Search icon'));

        // Add text to show clear button
        controller.text = 'test';
        await tester.pump();

        // Check clear icon semantic label
        final clearIcon = tester.widget<Icon>(find.byIcon(Icons.clear_rounded));
        expect(clearIcon.semanticLabel, equals('Clear search'));
      });

      testWidgets('handles theme changes dynamically', (tester) async {
        // Test light theme
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: Center(
                child: LottiSearchBar(controller: controller),
              ),
            ),
          ),
        );

        // Find LottiSearchBar widget first
        final searchBarFinder = find.byType(LottiSearchBar);
        expect(searchBarFinder, findsOneWidget);

        // Find the Container that is a descendant of LottiSearchBar and has decoration
        final containerFinder = find.descendant(
          of: searchBarFinder,
          matching: find.byWidgetPredicate((widget) {
            return widget is Container &&
                widget.decoration != null &&
                widget.decoration is BoxDecoration &&
                (widget.decoration! as BoxDecoration).border != null;
          }),
        );

        expect(containerFinder, findsOneWidget);
        final lightContainer = tester.widget<Container>(containerFinder);
        final lightDecoration = lightContainer.decoration! as BoxDecoration;
        expect(lightDecoration.gradient, isNull);
        expect(lightDecoration.color, isNotNull);

        // Test dark theme
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: Center(
                child: LottiSearchBar(controller: controller),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find the container again
        final darkContainerFinder = find.descendant(
          of: find.byType(LottiSearchBar),
          matching: find.byWidgetPredicate((widget) {
            return widget is Container &&
                widget.decoration != null &&
                widget.decoration is BoxDecoration &&
                (widget.decoration! as BoxDecoration).border != null;
          }),
        );

        expect(darkContainerFinder, findsOneWidget);
        final darkContainer = tester.widget<Container>(darkContainerFinder);
        final darkDecoration = darkContainer.decoration! as BoxDecoration;

        // In dark theme, non-compact mode should have gradient
        expect(darkDecoration.gradient, isNotNull,
            reason: 'Dark theme should have gradient background');
        expect(darkDecoration.color, isNull,
            reason:
                'Dark theme should not have color when gradient is present');
      });

      testWidgets('compact mode styling with dark theme', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            theme: ThemeData.dark(),
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

        final decoration = container.decoration! as BoxDecoration;
        // In compact + dark mode, should have color, not gradient
        expect(decoration.color, isNotNull);
        expect(decoration.gradient, isNull);
        expect(decoration.boxShadow, isEmpty);
      });
    });
  });
}
