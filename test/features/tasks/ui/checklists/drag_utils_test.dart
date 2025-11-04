import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tasks/ui/checklists/drag_utils.dart';

void main() {
  group('buildDragDecorator', () {
    testWidgets('creates container with correct styling', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final testChild = Container(key: const ValueKey('test-child'));
                final decoratedWidget = buildDragDecorator(context, testChild);

                return decoratedWidget;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the decorated container
      final container = tester.widget<Container>(
        find.ancestor(
          of: find.byKey(const ValueKey('test-child')),
          matching: find.byType(Container),
        ),
      );

      // Verify the decoration
      expect(container.decoration, isA<BoxDecoration>());
      final decoration = container.decoration! as BoxDecoration;

      // Verify border styling
      expect(decoration.border, isA<Border>());
      final border = decoration.border! as Border;
      expect(border.top.width, 2);
      expect(border.bottom.width, 2);
      expect(border.left.width, 2);
      expect(border.right.width, 2);

      // Verify border radius
      expect(decoration.borderRadius, BorderRadius.circular(12));

      // Verify surface color is set
      expect(decoration.color, isNotNull);

      // Verify child is preserved
      expect(find.byKey(const ValueKey('test-child')), findsOneWidget);
    });

    testWidgets('uses theme colors correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final testChild = Container(key: const ValueKey('test-child'));
                final decoratedWidget = buildDragDecorator(context, testChild);
                final theme = Theme.of(context);

                // Verify the decorator uses theme colors
                final container = decoratedWidget as Container;
                final decoration = container.decoration! as BoxDecoration;
                expect(decoration.color, theme.colorScheme.surface);

                final border = decoration.border! as Border;
                expect(border.top.color, theme.colorScheme.primary);

                return decoratedWidget;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
    });

    testWidgets('preserves child widget in decoration', (tester) async {
      const testKey = ValueKey('test-child');
      const testText = 'Test Content';

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final testChild = Container(
                  key: testKey,
                  child: const Text(testText),
                );
                return buildDragDecorator(context, testChild);
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify child widget and its content are preserved
      expect(find.byKey(testKey), findsOneWidget);
      expect(find.text(testText), findsOneWidget);
    });
  });
}
