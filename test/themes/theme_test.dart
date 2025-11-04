import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/themes/theme.dart';

void main() {
  group('withOverrides theme configuration', () {
    test('applies snackBarTheme with primary colors in light mode', () {
      final baseTheme = ThemeData.light();
      final themedData = withOverrides(baseTheme);

      // Verify snackBarTheme is configured
      expect(themedData.snackBarTheme, isNotNull);
      expect(
        themedData.snackBarTheme.backgroundColor,
        equals(baseTheme.colorScheme.primary),
      );
      expect(
        themedData.snackBarTheme.contentTextStyle?.color,
        equals(baseTheme.colorScheme.onPrimary),
      );
      expect(
        themedData.snackBarTheme.actionTextColor,
        equals(baseTheme.colorScheme.onPrimary),
      );
      expect(
        themedData.snackBarTheme.contentTextStyle?.fontSize,
        equals(fontSizeMedium),
      );
    });

    test('applies snackBarTheme with primary colors in dark mode', () {
      final baseTheme = ThemeData.dark();
      final themedData = withOverrides(baseTheme);

      // Verify snackBarTheme is configured
      expect(themedData.snackBarTheme, isNotNull);
      expect(
        themedData.snackBarTheme.backgroundColor,
        equals(baseTheme.colorScheme.primary),
      );
      expect(
        themedData.snackBarTheme.contentTextStyle?.color,
        equals(baseTheme.colorScheme.onPrimary),
      );
      expect(
        themedData.snackBarTheme.actionTextColor,
        equals(baseTheme.colorScheme.onPrimary),
      );
      expect(
        themedData.snackBarTheme.contentTextStyle?.fontSize,
        equals(fontSizeMedium),
      );
    });

    test('applies card theme with correct border radius', () {
      final baseTheme = ThemeData.light();
      final themedData = withOverrides(baseTheme);

      expect(themedData.cardTheme.clipBehavior, equals(Clip.hardEdge));
      expect(themedData.cardTheme.shape, isA<RoundedRectangleBorder>());

      final shape = themedData.cardTheme.shape! as RoundedRectangleBorder;
      final borderRadius = shape.borderRadius as BorderRadius;
      expect(
        borderRadius.topLeft.x,
        equals(AppTheme.cardBorderRadius),
      );
    });

    test('applies dark scaffold background in dark mode', () {
      final baseTheme = ThemeData.dark();
      final themedData = withOverrides(baseTheme);

      // In dark mode, scaffold should use surface color
      expect(
        themedData.scaffoldBackgroundColor,
        equals(baseTheme.colorScheme.surface),
      );
      expect(
        themedData.canvasColor,
        equals(baseTheme.colorScheme.surface),
      );
    });

    test('preserves light scaffold background in light mode', () {
      final baseTheme = ThemeData.light();
      final themedData = withOverrides(baseTheme);

      // In light mode, scaffold should keep original background
      expect(
        themedData.scaffoldBackgroundColor,
        equals(baseTheme.scaffoldBackgroundColor),
      );
    });

    test('applies custom slider theme', () {
      final baseTheme = ThemeData.light();
      final themedData = withOverrides(baseTheme);

      expect(
        themedData.sliderTheme.activeTrackColor,
        equals(baseTheme.colorScheme.secondary),
      );
      expect(
        themedData.sliderTheme.thumbColor,
        equals(baseTheme.colorScheme.secondary),
      );
      expect(themedData.sliderTheme.thumbShape, isA<RoundSliderThumbShape>());
    });

    test('applies custom bottom sheet theme', () {
      final baseTheme = ThemeData.light();
      final themedData = withOverrides(baseTheme);

      expect(themedData.bottomSheetTheme.clipBehavior, equals(Clip.hardEdge));
      expect(themedData.bottomSheetTheme.elevation, equals(0));
      expect(
        themedData.bottomSheetTheme.shape,
        isA<RoundedRectangleBorder>(),
      );
    });

    test('applies custom text theme with correct font sizes', () {
      final baseTheme = ThemeData.light();
      final themedData = withOverrides(baseTheme);

      expect(
        themedData.textTheme.titleMedium?.fontSize,
        equals(fontSizeMedium),
      );
      expect(
        themedData.textTheme.bodyLarge?.fontSize,
        equals(fontSizeMedium),
      );
      expect(
        themedData.textTheme.bodyMedium?.fontSize,
        equals(fontSizeMedium),
      );
    });

    test('applies custom chip theme', () {
      final baseTheme = ThemeData.light();
      final themedData = withOverrides(baseTheme);

      expect(themedData.chipTheme.side, equals(BorderSide.none));
      expect(themedData.chipTheme.shape, isA<RoundedRectangleBorder>());
    });

    test('applies custom input decoration theme', () {
      final baseTheme = ThemeData.light();
      final themedData = withOverrides(baseTheme);

      expect(
        themedData.inputDecorationTheme.floatingLabelBehavior,
        equals(FloatingLabelBehavior.always),
      );
      expect(
        themedData.inputDecorationTheme.border,
        isA<OutlineInputBorder>(),
      );
    });
  });

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
}
