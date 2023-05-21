// ignore_for_file: equal_keys_in_map
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/themes/themes.dart';
import 'package:lotti/themes/themes_service.dart';
import 'package:tinycolor2/tinycolor2.dart';

const fontSizeSmall = 11.0;
const fontSizeMedium = 15.0;
const fontSizeLarge = 25.0;

class AppTheme {
  static const double bottomNavIconSize = 24;

  static const chartDateHorizontalPadding = EdgeInsets.only(
    right: 4,
  );
}

const double chipBorderRadius = 10;
const mainFont = 'PlusJakartaSans';

const habitCardTextColor = Colors.black87;

final inputBorder = OutlineInputBorder(
  borderRadius: BorderRadius.circular(chipBorderRadius),
  borderSide: BorderSide(color: styleConfig().secondaryTextColor),
);

final errorBorder = OutlineInputBorder(
  borderRadius: BorderRadius.circular(chipBorderRadius),
  borderSide: BorderSide(color: styleConfig().alarm),
);

final inputBorderFocused = OutlineInputBorder(
  borderRadius: BorderRadius.circular(chipBorderRadius),
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
      color: habitCardTextColor,
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

TextStyle monospaceTextStyle() => TextStyle(
      fontWeight: FontWeight.w300,
      fontSize: fontSizeMedium,
      color: styleConfig().primaryTextColor,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

TextStyle monospaceTextStyleSmall() => monospaceTextStyle().copyWith(
      fontSize: fontSizeSmall,
    );

TextStyle monospaceTextStyleLarge() => monospaceTextStyle().copyWith(
      fontSize: fontSizeLarge,
    );

Brightness keyboardAppearance() {
  return styleConfig().keyboardAppearance;
}

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

TextStyle logDetailStyle() => monospaceTextStyle();

TextStyle appBarTextStyle() => TextStyle(
      color: styleConfig().primaryTextColor,
      fontSize: fontSizeMedium,
      fontWeight: FontWeight.bold,
    );

TextStyle appBarTextStyleNew() => TextStyle(
      color: styleConfig().primaryTextColor,
      fontSize: fontSizeMedium,
      fontWeight: FontWeight.w300,
    );

TextStyle appBarTextStyleNewLarge() => TextStyle(
      color: styleConfig().primaryTextColor,
      fontSize: fontSizeLarge,
      fontWeight: FontWeight.w100,
    );

TextStyle searchFieldStyle() => TextStyle(
      color: styleConfig().primaryTextColor,
      fontSize: fontSizeMedium,
      fontWeight: FontWeight.w200,
    );

TextStyle searchFieldHintStyle() => searchFieldStyle().copyWith(
      color: styleConfig().secondaryTextColor,
    );

TextStyle settingsCardTextStyle() => TextStyle(
      color: styleConfig().primaryTextColor,
      fontSize: fontSizeLarge,
      fontWeight: FontWeight.w300,
    );

TextStyle titleStyle() => TextStyle(
      color: styleConfig().primaryTextColor,
      fontSize: fontSizeLarge,
      fontWeight: FontWeight.w300,
    );

TextStyle taskTitleStyle() => TextStyle(
      color: styleConfig().primaryTextColor,
      fontSize: fontSizeLarge,
    );

TextStyle multiSelectStyle() => TextStyle(
      color: styleConfig().primaryTextColor,
      fontWeight: FontWeight.w100,
      fontSize: fontSizeLarge,
    );

TextStyle chartTitleStyle() => TextStyle(
      fontSize: fontSizeMedium,
      color: styleConfig().primaryTextColor,
      fontWeight: FontWeight.w300,
    );

TextStyle chartTitleStyleSmall() => TextStyle(
      fontSize: fontSizeSmall,
      color: styleConfig().primaryTextColor,
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
  fontFamily: 'Oswald',
  fontSize: fontSizeMedium,
  fontWeight: FontWeight.w100,
);

const badgeStyle = TextStyle(
  fontFamily: 'Oswald',
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
      fontFamily: 'Oswald',
      fontSize: fontSizeMedium,
      fontWeight: FontWeight.w100,
    );

ThemeData getTheme() {
  return ThemeData(
    fontFamily: mainFont,
    cardTheme: CardTheme(
      color: styleConfig().cardColor,
      elevation: 1,
      clipBehavior: Clip.hardEdge,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    useMaterial3: true,
    iconTheme: IconThemeData(
      color: styleConfig().secondaryTextColor,
    ),
    brightness: styleConfig().keyboardAppearance,
    scaffoldBackgroundColor: styleConfig().negspace,
    highlightColor: Colors.transparent,
    hoverColor: styleConfig().primaryColor.withOpacity(0.5),
    chipTheme: ChipThemeData(
      side: BorderSide.none,
      backgroundColor: styleConfig().primaryColor.withOpacity(0.6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    appBarTheme: AppBarTheme(
      iconTheme: IconThemeData(color: styleConfig().primaryTextColor),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: styleConfig().cardColor.darken(5),
      clipBehavior: Clip.hardEdge,
    ),
    tooltipTheme: TooltipThemeData(
      textStyle: chartTitleStyleSmall().copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w400,
      ),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(5),
      ),
    ),
    searchBarTheme: SearchBarThemeData(
      backgroundColor: MaterialStateProperty.resolveWith(
        (_) => styleConfig().cardColor.withOpacity(0.3),
      ),
      hintStyle: MaterialStateProperty.resolveWith(
        (_) => searchFieldHintStyle(),
      ),
      textStyle: MaterialStateProperty.resolveWith(
        (_) => searchFieldStyle(),
      ),
    ),
    colorScheme: ColorScheme.fromSwatch(
      primarySwatch: primaryColorMaterial,
    ).copyWith(
      background: styleConfig().cardColor,
      brightness: keyboardAppearance(),
    ),
    textTheme: TextTheme(
      bodyLarge: TextStyle(color: styleConfig().primaryTextColor),
      bodyMedium: TextStyle(color: styleConfig().primaryTextColor),
    ),
  );
}
