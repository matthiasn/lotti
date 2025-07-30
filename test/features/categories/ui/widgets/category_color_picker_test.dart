import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/categories/ui/widgets/category_color_picker.dart';
import 'package:lotti/utils/color.dart';

import '../../../../test_helper.dart';

void main() {
  group('CategoryColorPicker', () {
    testWidgets('displays correctly with no color selected', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryColorPicker(
            selectedColor: null,
            onColorChanged: (_) {},
          ),
        ),
      );

      // Verify title
      expect(find.text('Color:'), findsOneWidget);

      // Verify default color is shown (primary color)
      final containers = tester.widgetList<Container>(find.byType(Container));
      final colorContainer = containers.firstWhere(
        (container) {
          final decoration = container.decoration;
          return decoration is BoxDecoration && decoration.color != null;
        },
      );
      final decoration = colorContainer.decoration! as BoxDecoration;
      expect(decoration.color, isNotNull);

      // Verify "Select color" text
      expect(find.text('Select Color'), findsOneWidget);

      // Verify icon
      expect(find.byIcon(Icons.palette_outlined), findsOneWidget);
    });

    testWidgets('displays correctly with color selected', (tester) async {
      const selectedColor = Colors.red;

      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryColorPicker(
            selectedColor: selectedColor,
            onColorChanged: (_) {},
          ),
        ),
      );

      // Verify color hex is displayed
      expect(find.text(colorToCssHex(selectedColor)), findsOneWidget);

      // Verify selected color is shown
      final colorContainers = tester
          .widgetList<Container>(
        find.byType(Container),
      )
          .where((container) {
        final decoration = container.decoration;
        if (decoration is BoxDecoration) {
          return decoration.color == selectedColor;
        }
        return false;
      });
      expect(colorContainers, isNotEmpty);
    });

    testWidgets('opens color picker dialog on tap', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryColorPicker(
            selectedColor: Colors.blue,
            onColorChanged: (_) {},
          ),
        ),
      );

      // Tap on the color picker
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Verify dialog is shown
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Select Color'), findsOneWidget); // Title only
      expect(find.byType(ColorPicker), findsOneWidget);

      // Verify dialog buttons
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Select'), findsOneWidget);
    });

    testWidgets('calls onColorChanged when color is picked', (tester) async {
      Color? changedColor;

      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryColorPicker(
            selectedColor: Colors.blue,
            onColorChanged: (color) {
              changedColor = color;
            },
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // The ColorPicker widget is complex, so we'll simulate changing the color
      // by directly tapping the Select button which will use the initial color
      // In a real scenario, the user would interact with the ColorPicker first

      // Tap Select button to confirm the color
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();

      // The color should be the initial pickerColor (blue in this case)
      expect(changedColor, Colors.blue);
    });

    testWidgets('closes dialog on cancel without changing color',
        (tester) async {
      Color? changedColor;

      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryColorPicker(
            selectedColor: Colors.blue,
            onColorChanged: (color) {
              changedColor = color;
            },
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Tap cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Dialog should be closed
      expect(find.byType(AlertDialog), findsNothing);

      // Color should not have changed
      expect(changedColor, isNull);
    });

    testWidgets('closes dialog on select', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryColorPicker(
            selectedColor: Colors.blue,
            onColorChanged: (_) {},
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Tap select
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();

      // Dialog should be closed
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('uses correct initial color in picker', (tester) async {
      const initialColor = Colors.purple;

      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryColorPicker(
            selectedColor: initialColor,
            onColorChanged: (_) {},
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Verify ColorPicker has correct initial color
      final colorPicker = tester.widget<ColorPicker>(find.byType(ColorPicker));
      expect(colorPicker.pickerColor, initialColor);
    });

    testWidgets('uses red as default when no color selected', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryColorPicker(
            selectedColor: null,
            onColorChanged: (_) {},
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Verify ColorPicker defaults to red
      final colorPicker = tester.widget<ColorPicker>(find.byType(ColorPicker));
      expect(colorPicker.pickerColor, Colors.red);
    });

    testWidgets('has correct ColorPicker configuration', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryColorPicker(
            selectedColor: Colors.blue,
            onColorChanged: (_) {},
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Verify ColorPicker configuration
      final colorPicker = tester.widget<ColorPicker>(find.byType(ColorPicker));
      expect(colorPicker.enableAlpha, isFalse);
      expect(colorPicker.labelTypes, isEmpty);
      expect(colorPicker.pickerAreaBorderRadius, BorderRadius.circular(10));
    });

    testWidgets('responds to theme changes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: WidgetTestBench(
            child: CategoryColorPicker(
              selectedColor: null,
              onColorChanged: (_) {},
            ),
          ),
        ),
      );

      // Get initial theme colors
      final context = tester.element(find.byType(CategoryColorPicker));
      final initialPrimaryColor = Theme.of(context).colorScheme.primary;

      // Verify primary color is used when no color selected
      final containers = tester.widgetList<Container>(find.byType(Container));
      final colorContainer = containers.firstWhere(
        (container) {
          final decoration = container.decoration;
          return decoration is BoxDecoration &&
              decoration.color == initialPrimaryColor;
        },
      );
      expect(colorContainer, isNotNull);
    });

    testWidgets('has correct layout structure', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryColorPicker(
            selectedColor: Colors.green,
            onColorChanged: (_) {},
          ),
        ),
      );

      // Verify structure
      expect(find.byType(Column), findsOneWidget);
      expect(find.byType(InkWell), findsOneWidget);
      expect(find.byType(Row), findsOneWidget);

      // Verify spacing - SizedBox count may vary due to framework internals
      expect(find.byType(SizedBox), findsWidgets);
    });
  });
}
