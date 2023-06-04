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
        style: newLabelStyle(),
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
      labelStyle: newLabelStyle().copyWith(color: style.color),
    );
  }
}

const switchDecoration = InputDecoration(border: InputBorder.none);

const inputSpacer = SizedBox(height: 25);
const inputSpacerSmall = SizedBox(height: 15);

TextStyle inputStyle() => TextStyle(
      color: styleConfig().primaryTextColor,
      fontSize: fontSizeMedium,
    );

TextStyle dialogInputStyle() => const TextStyle(
      fontSize: fontSizeMedium,
    );

TextStyle textStyle() => TextStyle(
      color: styleConfig().primaryTextColor,
      fontWeight: FontWeight.w400,
      fontSize: fontSizeMedium,
    );

TextStyle choiceChipTextStyle({required bool isSelected}) => TextStyle(
      fontSize: fontSizeMedium,
      fontWeight: FontWeight.w300,
      color: isSelected
          ? styleConfig().selectedChoiceChipTextColor
          : styleConfig().unselectedChoiceChipTextColor,
    );

TextStyle chartTooltipStyle() => const TextStyle(
      fontSize: fontSizeSmall,
      fontWeight: FontWeight.w300,
    );

TextStyle chartTooltipStyleBold() => const TextStyle(
      fontSize: fontSizeSmall,
      fontWeight: FontWeight.bold,
    );

TextStyle textStyleLarger() => textStyle().copyWith(
      fontSize: 18,
      fontWeight: FontWeight.normal,
    );

TextStyle transcriptStyle() => textStyle().copyWith(
      fontSize: fontSizeMedium,
      fontWeight: FontWeight.normal,
      color: styleConfig().secondaryTextColor,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

TextStyle transcriptHeaderStyle() => transcriptStyle().copyWith(
      fontSize: fontSizeSmall,
      fontWeight: FontWeight.w300,
    );

TextStyle labelStyleLarger() => textStyleLarger().copyWith(
      fontSize: 20,
      fontWeight: FontWeight.w300,
    );

TextStyle labelStyle() => TextStyle(
      color: styleConfig().primaryTextColor,
      fontWeight: FontWeight.w500,
      fontSize: 18,
    );

TextStyle newLabelStyle() => TextStyle(
      color: styleConfig().secondaryTextColor,
      fontSize: fontSizeMedium,
    );

const monospaceTextStyle = TextStyle(
  fontWeight: FontWeight.w300,
  fontSize: fontSizeMedium,
  fontFeatures: [FontFeature.tabularFigures()],
);

final monospaceTextStyleSmall = monospaceTextStyle.copyWith(
  fontSize: fontSizeSmall,
);

TextStyle monospaceTextStyleLarge() => monospaceTextStyle.copyWith(
      fontSize: fontSizeLarge,
    );

TextStyle formLabelStyle() => TextStyle(
      color: styleConfig().secondaryTextColor,
      fontSize: fontSizeMedium,
    );

TextStyle buttonLabelStyle() => TextStyle(
      color: styleConfig().primaryTextColor,
      fontSize: fontSizeMedium,
    );

TextStyle buttonLabelStyleLarger() => TextStyle(
      color: styleConfig().primaryTextColor,
      fontSize: 20,
    );

TextStyle choiceLabelStyle() => TextStyle(
      color: styleConfig().primaryTextColor,
      fontSize: fontSizeMedium,
    );

TextStyle logDetailStyle() => monospaceTextStyle;

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

TextStyle searchFieldHintStyle() => searchFieldStyle.copyWith(
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

final lightTheme = FlexThemeData.light(
  scheme: FlexScheme.flutterDash,
  useMaterial3: true,
  fontFamily: mainFont,
);

final lightThemeMod = lightTheme.copyWith(
  cardTheme: lightTheme.cardTheme.copyWith(
    clipBehavior: Clip.hardEdge,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  ),
);

Brightness keyboardAppearance() {
  return getIt<ThemesService>().darkKeyboard
      ? Brightness.dark
      : Brightness.light;
}

final darkTheme = FlexThemeData.dark(
  scheme: FlexScheme.flutterDash,
  useMaterial3: true,
  fontFamily: mainFont,
);

final darkThemeMod = darkTheme.copyWith(
  cardTheme: darkTheme.cardTheme.copyWith(
    clipBehavior: Clip.hardEdge,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  ),
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
