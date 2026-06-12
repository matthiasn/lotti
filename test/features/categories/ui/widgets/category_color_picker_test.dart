import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/categories/ui/widgets/category_color_picker.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/settings/settings_color_picker_field.dart';
import 'package:lotti/widgets/settings/settings_picker_field.dart';

import '../../../../test_helper.dart';

void main() {
  group('CategoryColorPicker', () {
    Future<void> pumpPicker(
      WidgetTester tester, {
      Color? selectedColor,
      ValueChanged<Color>? onColorChanged,
    }) async {
      // Tall surface so the picker modal content is on-screen when opened.
      tester.view.physicalSize = const Size(1024, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
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

    Future<void> openModal(WidgetTester tester) async {
      await tester.tap(fieldTapTarget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
    }

    testWidgets('shows hint and no swatch when no color is selected', (
      tester,
    ) async {
      await pumpPicker(tester);

      // Field label and hint from l10n.
      expect(find.text('Color'), findsOneWidget);
      expect(find.text('Select a color'), findsOneWidget);

      // Delegates to the shared color field (one interaction model for
      // categories and labels).
      expect(find.byType(SettingsColorPickerField), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);

      // No leading swatch without a selection.
      final field = tester.widget<SettingsPickerField>(
        find.byType(SettingsPickerField),
      );
      expect(field.leading, isNull);
    });

    testWidgets('shows the preset name (not hex) and a leading swatch for a '
        'preset color', (tester) async {
      // 'Ocean Blue' in labelColorPresets.
      final selectedColor = colorFromCssHex('#0066CC');

      await pumpPicker(tester, selectedColor: selectedColor);

      expect(find.text('Ocean Blue'), findsOneWidget);
      // Raw hex never surfaces in the field.
      expect(find.textContaining('#'), findsNothing);
      expect(find.text('Select a color'), findsNothing);

      // The leading swatch is filled with the selected color.
      expect(swatchesWithColor(tester, selectedColor), isNotEmpty);
    });

    testWidgets('shows the localized Custom label for a non-preset color', (
      tester,
    ) async {
      const selectedColor = Color(0xFF123456);

      await pumpPicker(tester, selectedColor: selectedColor);

      expect(find.text('Custom'), findsOneWidget);
      expect(find.textContaining('#'), findsNothing);
      expect(swatchesWithColor(tester, selectedColor), isNotEmpty);
    });

    testWidgets('opens the shared picker modal on tap — no second dialog', (
      tester,
    ) async {
      await pumpPicker(tester, selectedColor: colorFromCssHex('#0066CC'));

      await openModal(tester);

      // The shared modal hosts the full flex picker; there is no
      // AlertDialog-based second picker anymore.
      expect(find.text('Select a color'), findsOneWidget); // modal title
      expect(find.byType(ColorPicker), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('seeds the picker with the selected color', (tester) async {
      final initialColor = colorFromCssHex('#E63946');

      await pumpPicker(tester, selectedColor: initialColor);
      await openModal(tester);

      final colorPicker = tester.widget<ColorPicker>(find.byType(ColorPicker));
      expect(colorPicker.color, initialColor);
    });

    testWidgets('selecting a preset in the modal fires onColorChanged live', (
      tester,
    ) async {
      Color? changedColor;

      await pumpPicker(
        tester,
        selectedColor: colorFromCssHex('#0066CC'),
        onColorChanged: (color) => changedColor = color,
      );
      await openModal(tester);

      // Tap the 'Crimson' preset indicator (#E63946) in the swatch grid.
      final crimsonIndicator = find.byWidgetPredicate(
        (widget) =>
            widget is ColorIndicator &&
            colorToCssHex(widget.color) == '#E63946',
      );
      expect(crimsonIndicator, findsOneWidget);
      await tester.tap(crimsonIndicator, warnIfMissed: false);
      await tester.pump();

      // The color is applied live — no confirm button between the user
      // and the change.
      expect(changedColor, isNotNull);
      expect(colorToCssHex(changedColor!), '#E63946');
    });
  });
}
