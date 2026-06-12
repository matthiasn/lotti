import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/categories/ui/widgets/category_color_picker.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/settings/settings_picker_field.dart';

import '../../../../test_helper.dart';

void main() {
  group('CategoryColorPicker', () {
    Future<void> pumpPicker(
      WidgetTester tester, {
      Color? selectedColor,
      ValueChanged<Color>? onColorChanged,
    }) {
      return tester.pumpWidget(
        WidgetTestBench(
          child: CategoryColorPicker(
            selectedColor: selectedColor,
            onColorChanged: onColorChanged ?? (_) {},
          ),
        ),
      );
    }

    /// The tappable row inside the picker field.
    Finder fieldTapTarget() => find.descendant(
      of: find.byType(CategoryColorPicker),
      matching: find.byType(InkWell),
    );

    /// Containers whose decoration is filled with [color] (the swatch).
    Iterable<Container> swatchesWithColor(WidgetTester tester, Color color) =>
        tester.widgetList<Container>(find.byType(Container)).where((
          container,
        ) {
          final decoration = container.decoration;
          return decoration is BoxDecoration && decoration.color == color;
        });

    testWidgets('shows hint and no swatch when no color is selected', (
      tester,
    ) async {
      await pumpPicker(tester);

      // Field label and hint from l10n.
      expect(find.text('Color'), findsOneWidget);
      expect(find.text('Select a color'), findsOneWidget);

      // Reads as a kit field: chevron instead of the old palette glyph.
      expect(find.byType(SettingsPickerField), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
      expect(find.byIcon(Icons.palette_outlined), findsNothing);

      // No leading swatch without a selection.
      final field = tester.widget<SettingsPickerField>(
        find.byType(SettingsPickerField),
      );
      expect(field.leading, isNull);
    });

    testWidgets('shows hex value and leading swatch when color is selected', (
      tester,
    ) async {
      const selectedColor = Colors.red;

      await pumpPicker(tester, selectedColor: selectedColor);

      // Hex value replaces the hint.
      expect(find.text(colorToCssHex(selectedColor)), findsOneWidget);
      expect(find.text('Select a color'), findsNothing);

      // The leading swatch is filled with the selected color.
      expect(swatchesWithColor(tester, selectedColor), isNotEmpty);
    });

    testWidgets('opens color picker dialog on tap', (tester) async {
      await pumpPicker(tester, selectedColor: Colors.blue);

      await tester.tap(fieldTapTarget());
      await tester.pumpAndSettle();

      // Verify dialog is shown
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Select a color'), findsOneWidget); // Dialog title
      expect(find.byType(ColorPicker), findsOneWidget);

      // Verify dialog buttons
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Select'), findsOneWidget);
    });

    testWidgets('calls onColorChanged when color is picked', (tester) async {
      Color? changedColor;

      await pumpPicker(
        tester,
        selectedColor: Colors.blue,
        onColorChanged: (color) => changedColor = color,
      );

      // Open dialog
      await tester.tap(fieldTapTarget());
      await tester.pumpAndSettle();

      // The ColorPicker widget is complex, so we'll simulate changing the
      // color by directly tapping the Select button which will use the
      // initial color. In a real scenario, the user would interact with
      // the ColorPicker first.
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();

      // The color should be the initial pickerColor (blue in this case)
      expect(changedColor, Colors.blue);
    });

    testWidgets('closes dialog on cancel without changing color', (
      tester,
    ) async {
      Color? changedColor;

      await pumpPicker(
        tester,
        selectedColor: Colors.blue,
        onColorChanged: (color) => changedColor = color,
      );

      // Open dialog
      await tester.tap(fieldTapTarget());
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
      await pumpPicker(tester, selectedColor: Colors.blue);

      // Open dialog
      await tester.tap(fieldTapTarget());
      await tester.pumpAndSettle();

      // Tap select
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();

      // Dialog should be closed
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('uses correct initial color in picker', (tester) async {
      const initialColor = Colors.purple;

      await pumpPicker(tester, selectedColor: initialColor);

      // Open dialog
      await tester.tap(fieldTapTarget());
      await tester.pumpAndSettle();

      // Verify ColorPicker has correct initial color
      final colorPicker = tester.widget<ColorPicker>(find.byType(ColorPicker));
      expect(colorPicker.pickerColor, initialColor);
    });

    testWidgets('uses red as default when no color selected', (tester) async {
      await pumpPicker(tester);

      // Open dialog
      await tester.tap(fieldTapTarget());
      await tester.pumpAndSettle();

      // Verify ColorPicker defaults to red
      final colorPicker = tester.widget<ColorPicker>(find.byType(ColorPicker));
      expect(colorPicker.pickerColor, Colors.red);
    });

    testWidgets('has correct ColorPicker configuration', (tester) async {
      await pumpPicker(tester, selectedColor: Colors.blue);

      // Open dialog
      await tester.tap(fieldTapTarget());
      await tester.pumpAndSettle();

      // Verify ColorPicker configuration
      final colorPicker = tester.widget<ColorPicker>(find.byType(ColorPicker));
      expect(colorPicker.enableAlpha, isFalse);
      expect(colorPicker.labelTypes, isEmpty);
      expect(colorPicker.pickerAreaBorderRadius, BorderRadius.circular(10));
    });
  });
}
