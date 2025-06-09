import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/ui/settings/widgets/config_empty_state.dart';

void main() {
  group('ConfigEmptyState', () {
    Widget createWidget({
      required String message,
      required IconData icon,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: ConfigEmptyState(
            message: message,
            icon: icon,
          ),
        ),
      );
    }

    testWidgets('displays message and icon', (WidgetTester tester) async {
      const testMessage = 'No items found';
      const testIcon = Icons.search_off;

      await tester.pumpWidget(createWidget(
        message: testMessage,
        icon: testIcon,
      ));

      expect(find.text(testMessage), findsOneWidget);
      expect(find.byIcon(testIcon), findsOneWidget);
      expect(find.text('Tap the + button to add one'), findsOneWidget);
    });

    testWidgets('displays icon in container with gradient',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget(
        message: 'Test',
        icon: Icons.hub,
      ));

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(ConfigEmptyState),
          matching: find.byType(Container).first,
        ),
      );

      expect(container.decoration, isA<BoxDecoration>());
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.gradient, isNotNull);
      expect(decoration.borderRadius, BorderRadius.circular(24));
    });

    testWidgets('maintains proper spacing between elements',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget(
        message: 'No providers',
        icon: Icons.link,
      ));

      // Verify spacing using SizedBox widgets that are direct children of Column
      final column = find.byType(Column).first;
      final sizedBoxes = find.descendant(
        of: column,
        matching: find.byWidgetPredicate((widget) {
          return widget is SizedBox && widget.height != null;
        }),
      );

      // Should have 2 SizedBox widgets for spacing (excluding the icon's size)
      final spacingBoxes = <SizedBox>[];
      for (final element in sizedBoxes.evaluate()) {
        final box = element.widget as SizedBox;
        if (box.height == 20 || box.height == 8) {
          spacingBoxes.add(box);
        }
      }

      expect(spacingBoxes.length, 2);
      expect(spacingBoxes[0].height, 20);
      expect(spacingBoxes[1].height, 8);
    });

    testWidgets('uses correct text styles', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget(
        message: 'Empty state message',
        icon: Icons.error,
      ));

      // Message text style
      final messageText = tester.widget<Text>(find.text('Empty state message'));
      expect(messageText.style?.fontWeight, FontWeight.w500);

      // Hint text style
      final hintText = tester.widget<Text>(
        find.text('Tap the + button to add one'),
      );
      expect(hintText.style?.color?.a, lessThan(1)); // Has opacity
    });

    testWidgets('centers content properly', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget(
        message: 'Centered content',
        icon: Icons.folder_open,
      ));

      // ConfigEmptyState itself contains a Center widget
      // Find the column inside the center
      final columnFinder = find.descendant(
        of: find.byType(ConfigEmptyState),
        matching: find.byType(Column),
      );
      expect(columnFinder, findsOneWidget);

      final column = tester.widget<Column>(columnFinder);
      expect(column.mainAxisAlignment, MainAxisAlignment.center);
    });

    testWidgets('handles long messages gracefully',
        (WidgetTester tester) async {
      const longMessage =
          'This is a very long message that might wrap to multiple lines '
          'when displayed in the empty state widget';

      await tester.pumpWidget(createWidget(
        message: longMessage,
        icon: Icons.info,
      ));

      expect(find.text(longMessage), findsOneWidget);
      // Should not overflow
      expect(tester.takeException(), isNull);
    });
  });
}
