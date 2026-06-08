import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';

/// One sampled (fontSize, color, fontWeight) tuple for the tabular-style
/// constructors. Colors are generated opaque (alpha 255) since these styles
/// pass the color straight through and never touch the alpha channel.
class _GeneratedTabularInput {
  const _GeneratedTabularInput({
    required this.fontSize,
    required this.red,
    required this.green,
    required this.blue,
    required this.fontWeight,
  });

  final double fontSize;
  final int red;
  final int green;
  final int blue;
  final FontWeight fontWeight;

  Color get color => Color.fromARGB(255, red, green, blue);

  @override
  String toString() =>
      '_GeneratedTabularInput(fontSize: $fontSize, '
      'color: $color, fontWeight: $fontWeight)';
}

extension _AnyThemeStyles on glados.Any {
  glados.Generator<int> get _channel => glados.IntAnys(this).intInRange(0, 256);

  glados.Generator<FontWeight> get _fontWeight =>
      glados.AnyUtils(this).choose(FontWeight.values);

  glados.Generator<_GeneratedTabularInput> get tabularInput =>
      glados.CombinableAny(this).combine5(
        // Font sizes used across the UI live well within this range; the
        // constructors are pure passthrough so the exact bound is not load
        // bearing, only that arbitrary positive sizes flow through unchanged.
        glados.DoubleAnys(this).doubleInRange(1, 200),
        _channel,
        _channel,
        _channel,
        _fontWeight,
        (
          double fontSize,
          int red,
          int green,
          int blue,
          FontWeight fontWeight,
        ) => _GeneratedTabularInput(
          fontSize: fontSize,
          red: red,
          green: green,
          blue: blue,
          fontWeight: fontWeight,
        ),
      );
}

void main() {
  group('inputDecoration helper', () {
    test('creates decoration with correct border radius', () {
      final themeData = ThemeData.light();
      final decoration = inputDecoration(
        themeData: themeData,
        labelText: 'Test Label',
      );

      expect(decoration.border, isA<OutlineInputBorder>());
      final border = decoration.border! as OutlineInputBorder;
      expect(border.borderRadius, isA<BorderRadius>());
      // The radius value itself is the behavior worth pinning, not just the type.
      expect(border.borderRadius.topLeft.x, equals(inputBorderRadius));
      expect(border.borderRadius.bottomRight.y, equals(inputBorderRadius));
    });

    test('creates decoration with error border', () {
      final themeData = ThemeData.light();
      final decoration = inputDecoration(
        themeData: themeData,
      );

      expect(decoration.errorBorder, isA<OutlineInputBorder>());
      final errorBorder = decoration.errorBorder! as OutlineInputBorder;
      expect(
        errorBorder.borderSide.color,
        equals(themeData.colorScheme.error),
      );
    });

    test('applies label text with correct style', () {
      final themeData = ThemeData.light();
      final decoration = inputDecoration(
        themeData: themeData,
        labelText: 'Test Label',
      );

      expect(decoration.label, isA<Text>());
      final label = decoration.label! as Text;
      expect(label.data, equals('Test Label'));
      expect(label.style?.fontSize, equals(fontSizeMedium));
    });

    test('applies semantics label when provided', () {
      final themeData = ThemeData.light();
      final decoration = inputDecoration(
        themeData: themeData,
        labelText: 'Test Label',
        semanticsLabel: 'Test Semantics',
      );

      final label = decoration.label! as Text;
      expect(label.semanticsLabel, equals('Test Semantics'));
    });

    test('includes suffix icon when provided', () {
      final themeData = ThemeData.light();
      const suffixIcon = Icon(Icons.search);
      final decoration = inputDecoration(
        themeData: themeData,
        suffixIcon: suffixIcon,
      );

      expect(decoration.suffixIcon, equals(suffixIcon));
    });
  });

  group('searchLabelStyle', () {
    test('uses secondary text color, medium font size, and w200 weight', () {
      final style = searchLabelStyle();

      expect(style.color, equals(secondaryTextColor));
      expect(style.fontSize, equals(fontSizeMedium));
      expect(style.fontWeight, equals(FontWeight.w200));
    });
  });

  group('createDialogInputDecoration', () {
    test('returns the base inputDecoration unchanged when style is null', () {
      final themeData = ThemeData.light();

      final decoration = createDialogInputDecoration(
        themeData: themeData,
        labelText: 'Field',
      );
      final base = inputDecoration(themeData: themeData, labelText: 'Field');

      // The null branch must forward the plain inputDecoration: no labelStyle
      // override and the same label/border configuration.
      expect(decoration.labelStyle, isNull);
      expect((decoration.label! as Text).data, equals('Field'));
      expect(decoration.border, equals(base.border));
      expect(decoration.errorBorder, equals(base.errorBorder));
    });

    test('overrides only the label color when a style is provided', () {
      final themeData = ThemeData.light();
      const provided = TextStyle(
        color: Color(0xFF123456),
        fontSize: 99,
        fontWeight: FontWeight.bold,
      );

      final decoration = createDialogInputDecoration(
        themeData: themeData,
        labelText: 'Field',
        style: provided,
      );
      final base = inputDecoration(themeData: themeData, labelText: 'Field');

      // Only the color is lifted from the provided style; everything else in
      // the labelStyle stays unset (the function builds a bare TextStyle).
      expect(decoration.labelStyle, isNotNull);
      expect(decoration.labelStyle!.color, equals(const Color(0xFF123456)));
      expect(decoration.labelStyle!.fontSize, isNull);
      expect(decoration.labelStyle!.fontWeight, isNull);
      // The rest of the decoration is untouched relative to the base helper.
      expect(decoration.border, equals(base.border));
    });

    test('forwards a null style color into the labelStyle', () {
      final themeData = ThemeData.light();
      const provided = TextStyle(fontSize: 12);

      final decoration = createDialogInputDecoration(
        themeData: themeData,
        style: provided,
      );

      // The non-null-style branch is still taken even though the color is
      // null; the resulting labelStyle therefore carries a null color.
      expect(decoration.labelStyle, isNotNull);
      expect(decoration.labelStyle!.color, isNull);
    });
  });

  group('choiceChipTextStyle', () {
    test('uses onSecondary when selected and secondary when not', () {
      final themeData = ThemeData.light();

      final selected = choiceChipTextStyle(
        themeData: themeData,
        isSelected: true,
      );
      final unselected = choiceChipTextStyle(
        themeData: themeData,
        isSelected: false,
      );

      expect(selected.color, equals(themeData.colorScheme.onSecondary));
      expect(unselected.color, equals(themeData.colorScheme.secondary));
      // Size and weight are constant across the boolean branch.
      for (final style in [selected, unselected]) {
        expect(style.fontSize, equals(fontSizeMedium));
        expect(style.fontWeight, equals(TypographyConstants.bodyFontWeight));
      }
    });

    glados.Glados(
      glados.any.bool,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'color is always one of onSecondary or secondary',
      (isSelected) {
        // Build distinct secondary/onSecondary colors so the branch choice is
        // observable and the assertion is non-vacuous.
        const scheme = ColorScheme.light(
          secondary: Color(0xFF0A0B0C),
          onSecondary: Color(0xFFF0E0D0),
        );
        final themeData = ThemeData.from(colorScheme: scheme);

        final style = choiceChipTextStyle(
          themeData: themeData,
          isSelected: isSelected,
        );

        expect(
          style.color,
          equals(
            isSelected ? scheme.onSecondary : scheme.secondary,
          ),
          reason: 'isSelected=$isSelected',
        );
        expect(
          style.color,
          anyOf(equals(scheme.onSecondary), equals(scheme.secondary)),
        );
      },
      tags: 'glados',
    );
  });

  group('monoTabularStyle', () {
    test('uses Inconsolata with tabular figures and given defaults', () {
      final style = monoTabularStyle(fontSize: 14);

      expect(style.fontFamily, equals('Inconsolata'));
      expect(style.fontSize, equals(14));
      // Default weight per the signature.
      expect(style.fontWeight, equals(FontWeight.w500));
      expect(style.color, isNull);
      expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
    });

    glados.Glados(
      glados.any.tabularInput,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'passes through size/weight/color and always pins Inconsolata + tnum',
      (input) {
        final style = monoTabularStyle(
          fontSize: input.fontSize,
          color: input.color,
          fontWeight: input.fontWeight,
        );

        expect(style.fontFamily, equals('Inconsolata'), reason: '$input');
        expect(style.fontSize, equals(input.fontSize), reason: '$input');
        expect(style.fontWeight, equals(input.fontWeight), reason: '$input');
        expect(style.color, equals(input.color), reason: '$input');
        expect(
          style.fontFeatures,
          contains(const FontFeature.tabularFigures()),
          reason: '$input',
        );
      },
      tags: 'glados',
    );
  });

  group('tabularFigureStyle', () {
    test('keeps the UI font and applies the numeric badge features', () {
      final style = tabularFigureStyle(fontSize: 14);

      // No explicit fontFamily -> regular UI font (Inter) is used.
      expect(style.fontFamily, isNull);
      expect(style.fontSize, equals(14));
      expect(style.fontWeight, equals(FontWeight.w500));
      expect(style.color, isNull);
      expect(style.fontFeatures, equals(numericBadgeFontFeatures));
    });

    glados.Glados(
      glados.any.tabularInput,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'passes through size/weight/color and reuses numericBadgeFontFeatures',
      (input) {
        final style = tabularFigureStyle(
          fontSize: input.fontSize,
          color: input.color,
          fontWeight: input.fontWeight,
        );

        expect(style.fontFamily, isNull, reason: '$input');
        expect(style.fontSize, equals(input.fontSize), reason: '$input');
        expect(style.fontWeight, equals(input.fontWeight), reason: '$input');
        expect(style.color, equals(input.color), reason: '$input');
        expect(
          style.fontFeatures,
          equals(numericBadgeFontFeatures),
          reason: '$input',
        );
      },
      tags: 'glados',
    );
  });
}
