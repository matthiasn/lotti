// ignore_for_file: equal_keys_in_map
import 'dart:ui';

import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/themes/themes_service.dart';

const fontSizeSmall = 11.0;
const fontSizeMedium = 15.0;
const fontSizeLarge = 25.0;

class AppTheme {
  static const double bottomNavIconSize = 24;

  static const chartDateHorizontalPadding = EdgeInsets.only(
    right: 4,
  );
}

const double inputBorderRadius = 10;
const mainFont = 'PlusJakartaSans';

final inputBorder = OutlineInputBorder(
  borderRadius: BorderRadius.circular(inputBorderRadius),
  borderSide: BorderSide(color: styleConfig().secondaryTextColor),
);

final errorBorder = OutlineInputBorder(
  borderRadius: BorderRadius.circular(inputBorderRadius),
  borderSide: BorderSide(color: styleConfig().alarm),
);

final inputBorderFocused = OutlineInputBorder(
  borderRadius: BorderRadius.circular(inputBorderRadius),
  borderSide: BorderSide(
    color: styleConfig().primaryColor,
    width: 2,
  ),
);

InputDecoration inputDecoration({
  String? labelText,
  String? semanticsLabel,
  Widget? suffixIcon,
}) =>
    InputDecoration(
      border: inputBorder,
      errorBorder: errorBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorderFocused,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      suffixIcon: suffixIcon,
      label: Text(
        labelText ?? '',
        semanticsLabel: semanticsLabel,
      ),
    );

InputDecoration createDialogInputDecoration({
  String? labelText,
  TextStyle? style,
}) {
  final decoration = inputDecoration(labelText: labelText);

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

TextStyle choiceChipTextStyle({required bool isSelected}) => TextStyle(
      fontSize: fontSizeMedium,
      fontWeight: FontWeight.w300,
      color: isSelected
          ? styleConfig().selectedChoiceChipTextColor
          : styleConfig().unselectedChoiceChipTextColor,
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
  fontWeight: FontWeight.w300,
  fontSize: fontSizeMedium,
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
  color: styleConfig().secondaryTextColor,
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

const chartTitleStyleSmall = TextStyle(
  fontSize: fontSizeSmall,
  fontWeight: FontWeight.w300,
);

TextStyle saveButtonStyle() => TextStyle(
      fontSize: fontSizeMedium,
      fontWeight: FontWeight.bold,
      color: styleConfig().alarm.darken(),
    );

TextStyle failButtonStyle() => TextStyle(
      fontSize: fontSizeMedium,
      fontWeight: FontWeight.bold,
      color: styleConfig().alarm.darken(),
    );

const segmentItemStyle = TextStyle(
  fontSize: fontSizeMedium,
);

const badgeStyle = TextStyle(
  fontWeight: FontWeight.w300,
  fontSize: fontSizeSmall,
);

const settingsIconSize = 24.0;

StyleConfig styleConfig() => getIt<ThemesService>().current;

const habitCompletionHeaderStyle = TextStyle(
  color: Colors.black,
  fontSize: 20,
);

TextStyle searchLabelStyle() => TextStyle(
      color: styleConfig().secondaryTextColor,
      fontSize: fontSizeMedium,
      fontWeight: FontWeight.w100,
    );

Brightness keyboardAppearance() {
  return getIt<ThemesService>().darkKeyboard
      ? Brightness.dark
      : Brightness.light;
}

final lightTheme = FlexThemeData.light(
  scheme: FlexScheme.flutterDash,
  useMaterial3: true,
  fontFamily: mainFont,
);

final darkTheme = FlexThemeData.dark(
  scheme: FlexScheme.deepBlue,
  useMaterial3: true,
  fontFamily: mainFont,
);

ThemeData withOverrides(ThemeData themeData) {
  return themeData.copyWith(
    cardTheme: darkTheme.cardTheme.copyWith(
      clipBehavior: Clip.hardEdge,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(clipBehavior: Clip.hardEdge),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        alignment: Alignment.center,
        visualDensity: VisualDensity.compact,
        side: MaterialStateProperty.resolveWith((states) {
          return BorderSide(
            color: darkTheme.colorScheme.tertiary,
          );
        }),
        padding: MaterialStateProperty.resolveWith((states) {
          return const EdgeInsets.symmetric(horizontal: 6);
        }),
        enableFeedback: true,
      ),
    ),
  );
}

final lightThemeMod = withOverrides(lightTheme);
final darkThemeMod = withOverrides(darkTheme);
