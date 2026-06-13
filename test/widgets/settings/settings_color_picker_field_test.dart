import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/settings/settings_color_picker_field.dart';
import 'package:lotti/widgets/settings/settings_picker_field.dart';

import '../../test_helper.dart';

void main() {
  group('SettingsColorPickerField', () {
    Future<void> pumpField(
      WidgetTester tester, {
      Color? color,
      ValueChanged<Color>? onColorChanged,
      String? label,
    }) async {
      // Tall surface so the picker modal content is on-screen and
      // tappable when opened.
      tester.view.physicalSize = const Size(1024, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        WidgetTestBench(
          child: SettingsColorPickerField(
            color: color,
            onColorChanged: onColorChanged ?? (_) {},
            label: label,
          ),
        ),
      );
    }

    /// The tappable row inside the picker field.
    Finder fieldTapTarget() => find.descendant(
      of: find.byType(SettingsColorPickerField),
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

    testWidgets('shows the matching preset name for a preset hex, never the '
        'raw hex', (tester) async {
      // 'Ocean Blue' in labelColorPresets.
      final oceanBlue = colorFromCssHex('#0066CC');

      await pumpField(tester, color: oceanBlue);

      expect(find.text('Ocean Blue'), findsOneWidget);
      // The hex stays behind the picker — it never surfaces in the field.
      expect(find.textContaining('#'), findsNothing);
      expect(find.text('Select a color'), findsNothing);
    });

    testWidgets('shows the localized Custom label for a non-preset color', (
      tester,
    ) async {
      const custom = Color(0xFF123456);

      await pumpField(tester, color: custom);

      expect(find.text('Custom'), findsOneWidget);
      expect(find.textContaining('#'), findsNothing);
    });

    testWidgets('renders a leading swatch filled with the selected color', (
      tester,
    ) async {
      final crimson = colorFromCssHex('#E63946');

      await pumpField(tester, color: crimson);

      expect(swatchesWithColor(tester, crimson), isNotEmpty);
    });

    testWidgets('shows hint and no swatch when no color is selected', (
      tester,
    ) async {
      await pumpField(tester);

      expect(find.text('Select a color'), findsOneWidget);
      final field = tester.widget<SettingsPickerField>(
        find.byType(SettingsPickerField),
      );
      expect(field.leading, isNull);
    });

    testWidgets('passes label through to the picker field', (tester) async {
      await pumpField(tester, color: const Color(0xFF123456), label: 'Color');

      expect(find.text('Color'), findsOneWidget);
    });

    testWidgets('tap opens the shared modal hosting the full picker, seeded '
        'with the current color', (tester) async {
      final oceanBlue = colorFromCssHex('#0066CC');

      await pumpField(tester, color: oceanBlue);
      await openModal(tester);

      // Modal title plus the flex picker with the preset swatches.
      expect(find.text('Select a color'), findsOneWidget);
      final picker = tester.widget<ColorPicker>(find.byType(ColorPicker));
      expect(picker.color, oceanBlue);
      // The preset tab shows named swatches (proper-noun palette names).
      expect(find.byType(ColorIndicator), findsWidgets);
    });

    testWidgets('selecting a preset swatch in the modal fires onColorChanged '
        'with that color', (tester) async {
      Color? picked;
      final oceanBlue = colorFromCssHex('#0066CC');

      await pumpField(
        tester,
        color: oceanBlue,
        onColorChanged: (color) => picked = color,
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

      expect(picked, isNotNull);
      expect(colorToCssHex(picked!), '#E63946');
    });
  });
}
