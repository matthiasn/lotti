// ignore_for_file: equal_keys_in_map
import 'dart:ui';

import 'package:flex_color_scheme/flex_color_scheme.dart';
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

InputDecoration inputDecoration({
  required ThemeData themeData,
  String? labelText,
  String? semanticsLabel,
  Widget? suffixIcon,
}) {
  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(inputBorderRadius),
    borderSide: BorderSide(color: themeData.colorScheme.outline),
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
        color: themeData.primaryColor,
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
}) =>
    TextStyle(
      fontSize: fontSizeMedium,
      fontWeight: FontWeight.w300,
      color: themeData.colorScheme.inversePrimary,
    );

const chartTooltipStyle = TextStyle(
  fontSize: fontSizeSmall,
  fontWeight: FontWeight.w300,
);

const chartTooltipStyleBold = TextStyle(
  fontSize: fontSizeSmall,
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

const searchFieldStyle = TextStyle(
  fontSize: fontSizeMedium,
  fontWeight: FontWeight.w200,
);

final searchFieldHintStyle = searchFieldStyle.copyWith(
  color: secondaryTextColor,
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

const habitTitleStyle = TextStyle(
  fontSize: fontSizeMediumLarge,
  fontWeight: FontWeight.w300,
);

const chartTitleStyleSmall = TextStyle(
  fontSize: fontSizeSmall,
  fontWeight: FontWeight.w300,
);

TextStyle saveButtonStyle() => TextStyle(
      fontSize: fontSizeMedium,
      fontWeight: FontWeight.bold,
      color: alarm.darken(),
    );

TextStyle failButtonStyle() => TextStyle(
      fontSize: fontSizeMedium,
      fontWeight: FontWeight.bold,
      color: alarm.darken(),
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
    cardTheme: themeData.cardTheme.copyWith(
      clipBehavior: Clip.hardEdge,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      clipBehavior: Clip.hardEdge,
      elevation: 100,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        alignment: Alignment.center,
        visualDensity: VisualDensity.compact,
        side: MaterialStateProperty.resolveWith((states) {
          return BorderSide(
            color: themeData.colorScheme.tertiary,
          );
        }),
        padding: MaterialStateProperty.resolveWith((states) {
          return const EdgeInsets.symmetric(horizontal: 6);
        }),
        enableFeedback: true,
      ),
    ),
    inputDecorationTheme:
        InputDecorationTheme(fillColor: themeData.primaryColor),
  );
}
