import 'package:flutter/gestures.dart';
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

      testWidgets('forwards an empty hint into the decoration', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: LottiSearchBar(
              controller: controller,
              hintText: '',
            ),
          ),
        );

        // The configured (empty) hint must reach InputDecoration.hintText
        // rather than falling back to the default 'Search...'.
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.decoration?.hintText, '');
      });

      testWidgets('uses the default hint when none is configured', (
        tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(
            child: LottiSearchBar(controller: controller),
          ),
        );

        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.decoration?.hintText, 'Search...');
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

      testWidgets('clear button only calls onClear if provided', (
        tester,
      ) async {
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

      testWidgets('accessibility - semantic labels are present', (
        tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(
            child: LottiSearchBar(controller: controller),
          ),
        );

        // Check search icon semantic label
        final searchIcon = tester.widget<Icon>(
          find.byIcon(Icons.search_rounded),
        );
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
        expect(
          darkDecoration.gradient,
          isNotNull,
          reason: 'Dark theme should have gradient background',
        );
        expect(
          darkDecoration.color,
          isNull,
          reason: 'Dark theme should not have color when gradient is present',
        );
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

    group('Hover Effect', () {
      testWidgets('uses AnimatedContainer for smooth hover transitions', (
        tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(
            child: LottiSearchBar(controller: controller),
          ),
        );

        // Verify AnimatedContainer is used
        expect(find.byType(AnimatedContainer), findsOneWidget);

        final animatedContainer = tester.widget<AnimatedContainer>(
          find.byType(AnimatedContainer),
        );

        // Verify animation duration is 150ms for hover transitions
        expect(
          animatedContainer.duration,
          equals(const Duration(milliseconds: 150)),
        );
      });

      testWidgets('decoration includes border and shadow styling', (
        tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(
            child: LottiSearchBar(controller: controller),
          ),
        );

        final container = tester.widget<AnimatedContainer>(
          find.byType(AnimatedContainer),
        );
        final decoration = container.decoration! as BoxDecoration;

        // Should have styling elements for hover effect
        expect(decoration.boxShadow, isNotNull);
        expect(decoration.border, isNotNull);
        expect(decoration.borderRadius, isNotNull);
      });

      testWidgets('hover adds additional shadow for glow effect', (
        tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(
            child: LottiSearchBar(controller: controller),
          ),
        );

        // Get initial shadow count
        final containerBefore = tester.widget<AnimatedContainer>(
          find.byType(AnimatedContainer),
        );
        final decorationBefore = containerBefore.decoration! as BoxDecoration;
        final initialShadowCount = decorationBefore.boxShadow?.length ?? 0;

        // Simulate mouse enter
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: Offset.zero);
        addTearDown(gesture.removePointer);
        await tester.pump();

        await gesture.moveTo(tester.getCenter(find.byType(LottiSearchBar)));
        await tester.pumpAndSettle();

        // Get shadows after hover
        final containerAfter = tester.widget<AnimatedContainer>(
          find.byType(AnimatedContainer),
        );
        final decorationAfter = containerAfter.decoration! as BoxDecoration;
        final hoverShadowCount = decorationAfter.boxShadow?.length ?? 0;

        // Should have more shadows when hovering (adds glow)
        expect(hoverShadowCount, greaterThan(initialShadowCount));
      });
    });

    group('FocusNode', () {
      testWidgets('accepts optional focusNode parameter', (tester) async {
        final focusNode = FocusNode();

        await tester.pumpWidget(
          createTestWidget(
            child: LottiSearchBar(
              controller: controller,
              focusNode: focusNode,
            ),
          ),
        );

        expect(find.byType(LottiSearchBar), findsOneWidget);

        focusNode.dispose();
      });

      testWidgets('focusNode can request focus', (tester) async {
        final focusNode = FocusNode();

        await tester.pumpWidget(
          createTestWidget(
            child: LottiSearchBar(
              controller: controller,
              focusNode: focusNode,
            ),
          ),
        );

        // Initially not focused
        expect(focusNode.hasFocus, isFalse);

        // Request focus
        focusNode.requestFocus();
        await tester.pumpAndSettle();

        // Should now have focus
        expect(focusNode.hasFocus, isTrue);

        focusNode.dispose();
      });

      testWidgets('TextField receives the focusNode', (tester) async {
        final focusNode = FocusNode();

        await tester.pumpWidget(
          createTestWidget(
            child: LottiSearchBar(
              controller: controller,
              focusNode: focusNode,
            ),
          ),
        );

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.focusNode, equals(focusNode));

        focusNode.dispose();
      });

      testWidgets('works without focusNode (null)', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: LottiSearchBar(controller: controller),
          ),
        );

        // Should render fine without focusNode
        expect(find.byType(LottiSearchBar), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);

        // Can still enter text
        await tester.enterText(find.byType(TextField), 'test');
        await tester.pump();
        expect(controller.text, equals('test'));
      });
    });
  });
}
