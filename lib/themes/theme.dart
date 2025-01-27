// ignore_for_file: equal_keys_in_map
import 'package:flutter/material.dart';
import 'package:lotti/themes/colors.dart';

const fontSizeSmall = 11.0;
const fontSizeMedium = 15.0;
const fontSizeMediumLarge = 20.0;
const fontSizeLarge = 25.0;

class AppTheme {
  static const double bottomNavIconSize = 24;

  static const chartDateHorizontalPadding = EdgeInsets.only(
    right: 4,
  );
}

const double inputBorderRadius = 10;
const mainFont = 'PlusJakartaSans';

const verticalModalSpacer = SizedBox(height: 30);

InputDecoration inputDecoration({
  required ThemeData themeData,
  String? labelText,
  String? semanticsLabel,
  Widget? suffixIcon,
}) {
  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(inputBorderRadius),
    borderSide: BorderSide(
      color: themeData.colorScheme.outline.withAlpha(100),
    ),
  );

  final errorBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(inputBorderRadius),
    borderSide: BorderSide(color: themeData.colorScheme.error),
  );

  return InputDecoration(
    border: inputBorder,
    errorBorder: errorBorder,
    enabledBorder: inputBorder,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(inputBorderRadius),
      borderSide: BorderSide(
        color: themeData.colorScheme.outline,
        width: 2,
      ),
    ),
    floatingLabelBehavior: FloatingLabelBehavior.always,
    suffixIcon: suffixIcon,
    label: Text(
      labelText ?? '',
      semanticsLabel: semanticsLabel,
    ),
  );
}

InputDecoration createDialogInputDecoration({
  required ThemeData themeData,
  String? labelText,
  TextStyle? style,
}) {
  final decoration = inputDecoration(
    labelText: labelText,
    themeData: themeData,
  );

  if (style == null) {
    return decoration;
  } else {
    return decoration.copyWith(
      labelStyle: TextStyle(color: style.color),
    );
  }
}

const switchDecoration = InputDecoration(border: InputBorder.none);

const inputSpacer = SizedBox(height: 25);
const inputSpacerSmall = SizedBox(height: 15);

TextStyle choiceChipTextStyle({
  required ThemeData themeData,
  required bool isSelected,
}) =>
    TextStyle(
      fontSize: fontSizeMedium,
      fontWeight: FontWeight.w300,
      color: isSelected
          ? themeData.colorScheme.onSecondary
          : themeData.colorScheme.secondary,
    );

const chartTooltipStyle = TextStyle(
  fontSize: fontSizeSmall,
  fontWeight: FontWeight.w300,
);

const chartTooltipStyleBold = TextStyle(
  fontSize: fontSizeMedium,
  fontWeight: FontWeight.bold,
);

const transcriptHeaderStyle = TextStyle(
  fontSize: fontSizeSmall,
  fontWeight: FontWeight.w300,
);

const monospaceTextStyle = TextStyle(
  fontSize: fontSizeMedium,
  fontWeight: FontWeight.w500,
  fontFeatures: [FontFeature.tabularFigures()],
);

final monospaceTextStyleSmall = monospaceTextStyle.copyWith(
  fontSize: fontSizeSmall,
);

final monospaceTextStyleLarge = monospaceTextStyle.copyWith(
  fontSize: fontSizeLarge,
);

const appBarTextStyle = TextStyle(
  fontSize: fontSizeMedium,
  fontWeight: FontWeight.bold,
);

const appBarTextStyleNew = TextStyle(
  fontSize: fontSizeMedium,
  fontWeight: FontWeight.w300,
);

const appBarTextStyleNewLarge = TextStyle(
  fontSize: fontSizeLarge,
  fontWeight: FontWeight.w100,
);

const settingsCardTextStyle = TextStyle(
  fontSize: fontSizeLarge,
  fontWeight: FontWeight.w300,
);

const titleStyle = TextStyle(
  fontSize: fontSizeLarge,
  fontWeight: FontWeight.w300,
);

const taskTitleStyle = TextStyle(
  fontSize: fontSizeLarge,
);

const multiSelectStyle = TextStyle(
  fontWeight: FontWeight.w100,
  fontSize: fontSizeLarge,
);

const chartTitleStyle = TextStyle(
  fontSize: fontSizeMedium,
  fontWeight: FontWeight.w300,
);

final chartTitleStyleMonospace = chartTitleStyle.copyWith(
  fontFeatures: [const FontFeature.tabularFigures()],
);

const habitTitleStyle = TextStyle(
  fontSize: fontSizeMediumLarge,
  fontWeight: FontWeight.w300,
);

TextStyle saveButtonStyle(ThemeData themeData) => TextStyle(
      fontSize: fontSizeMediumLarge,
      fontWeight: FontWeight.bold,
      color: themeData.colorScheme.error,
    );

TextStyle failButtonStyle() => TextStyle(
      fontSize: fontSizeMediumLarge,
      fontWeight: FontWeight.bold,
      color: failColor,
    );

const segmentItemStyle = TextStyle(
  fontSize: fontSizeMedium,
);

const badgeStyle = TextStyle(
  fontWeight: FontWeight.w300,
  fontSize: fontSizeSmall,
);

const settingsIconSize = 24.0;

const habitCompletionHeaderStyle = TextStyle(fontSize: 20);

TextStyle searchLabelStyle() => TextStyle(
      color: secondaryTextColor,
      fontSize: fontSizeMedium,
      fontWeight: FontWeight.w100,
    );

ThemeData withOverrides(ThemeData themeData) {
  return themeData.copyWith(
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    cardTheme: themeData.cardTheme.copyWith(
      clipBehavior: Clip.hardEdge,
      color: themeData.colorScheme.surfaceContainer,
    ),
    sliderTheme: themeData.sliderTheme.copyWith(
      activeTrackColor: themeData.colorScheme.secondary,
      inactiveTrackColor: themeData.colorScheme.secondary.withAlpha(178),
      thumbColor: themeData.colorScheme.secondary,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      overlayColor: themeData.colorScheme.secondary.withAlpha(127),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      clipBehavior: Clip.hardEdge,
      elevation: 100,
    ),
    textTheme: themeData.textTheme.copyWith(
      titleMedium: themeData.textTheme.titleMedium?.copyWith(
        fontSize: fontSizeMedium,
        fontWeight: FontWeight.normal,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        alignment: Alignment.center,
        visualDensity: VisualDensity.compact,
        textStyle: WidgetStateProperty.resolveWith(
          (states) => const TextStyle(fontSize: fontSizeSmall),
        ),
        side: WidgetStateProperty.resolveWith((states) {
          return BorderSide(
            color: themeData.colorScheme.tertiary,
          );
        }),
        shape: WidgetStateProperty.resolveWith((states) {
          return RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(inputBorderRadius),
          );
        }),
        padding: WidgetStateProperty.resolveWith((states) {
          return const EdgeInsets.symmetric(horizontal: 5);
        }),
        enableFeedback: true,
      ),
    ),
    chipTheme: const ChipThemeData(side: BorderSide.none),
    inputDecorationTheme: InputDecorationTheme(
      fillColor: themeData.primaryColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(inputBorderRadius),
        borderSide: BorderSide(color: themeData.colorScheme.outline),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(inputBorderRadius),
        borderSide: BorderSide(color: themeData.colorScheme.error),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(inputBorderRadius),
        borderSide: BorderSide(
          color: themeData.primaryColor,
          width: 2,
        ),
      ),
      floatingLabelBehavior: FloatingLabelBehavior.always,
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        textStyle: WidgetStateProperty.resolveWith((states) {
          return const TextStyle(
            fontSize: fontSizeMediumLarge,
            fontFamily: mainFont,
          );
        }),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{},
    ),
  );
}

extension AppThemeExtension on BuildContext {
  TextTheme get textTheme => Theme.of(this).textTheme;

  ColorScheme get colorScheme => Theme.of(this).colorScheme;
}

extension TextThemeExtension on TextStyle {
  TextStyle get withTabularFigures =>
      copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
}
