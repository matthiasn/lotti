// ignore_for_file: equal_keys_in_map
import 'package:flutter/material.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/themes/themes_service.dart';

class AppTheme {
  static const double bottomNavIconSize = 24;

  static const chartDateHorizontalPadding = EdgeInsets.only(
    right: 4,
  );
}

const double chipBorderRadius = 8;
const mainFont = 'PlusJakartaSans';

const chipPadding = EdgeInsets.symmetric(
  vertical: 2,
  horizontal: 8,
);

const chipPaddingClosable = EdgeInsets.only(
  top: 1,
  bottom: 1,
  left: 8,
  right: 4,
);

TextStyle inputStyle() => TextStyle(
      color: colorConfig().entryTextColor,
      fontWeight: FontWeight.bold,
      fontFamily: 'Lato',
      fontSize: 18,
    );

TextStyle textStyle() => TextStyle(
      color: colorConfig().entryTextColor,
      fontFamily: mainFont,
      fontWeight: FontWeight.w400,
      fontSize: 16,
    );

TextStyle textStyleLarger() => textStyle().copyWith(
      fontSize: 18,
      fontWeight: FontWeight.normal,
    );

TextStyle textStyleLargerUnderlined() => textStyle().copyWith(
      fontSize: 18,
      fontWeight: FontWeight.w100,
      decoration: TextDecoration.underline,
    );

TextStyle labelStyleLarger() => textStyleLarger().copyWith(
      fontSize: 18,
      fontWeight: FontWeight.w300,
    );

TextStyle labelStyle() => TextStyle(
      color: colorConfig().entryTextColor,
      fontWeight: FontWeight.w500,
      fontSize: 18,
    );

TextStyle pickerMonoTextStyle() => textStyle().copyWith(
      fontFamily: 'ShareTechMono',
      fontWeight: FontWeight.w100,
    );

TextStyle formLabelStyle() => TextStyle(
      color: colorConfig().entryTextColor,
      fontFamily: mainFont,
      fontSize: 16,
    );

TextStyle buttonLabelStyle() => TextStyle(
      color: colorConfig().entryTextColor,
      fontFamily: mainFont,
      fontSize: 16,
    );

TextStyle settingsLabelStyle() => TextStyle(
      color: colorConfig().entryTextColor,
      fontFamily: mainFont,
      fontSize: 16,
    );

TextStyle choiceLabelStyle() => TextStyle(
      color: colorConfig().entryTextColor,
      fontFamily: mainFont,
      fontSize: 16,
    );

TextStyle logDetailStyle() => TextStyle(
      color: colorConfig().entryTextColor,
      fontFamily: 'ShareTechMono',
      fontSize: 14,
    );

TextStyle appBarTextStyle() => TextStyle(
      color: colorConfig().entryTextColor,
      fontFamily: mainFont,
      fontSize: 22,
      fontWeight: FontWeight.bold,
    );

TextStyle settingsCardTextStyle() => const TextStyle(
      //color: colorConfig().entryTextColor,
      color: Colors.black,
      fontFamily: mainFont,
      fontSize: 25,
    );

TextStyle titleStyle() => TextStyle(
      color: colorConfig().entryTextColor,
      fontFamily: mainFont,
      fontSize: 32,
      fontWeight: FontWeight.w300,
    );

TextStyle taskTitleStyle() => const TextStyle(
      //color: colorConfig().entryTextColor,
      color: Colors.black,
      fontFamily: mainFont,
      fontSize: 24,
    );

TextStyle multiSelectStyle() => TextStyle(
      color: colorConfig().entryTextColor,
      fontFamily: mainFont,
      fontWeight: FontWeight.w100,
      fontSize: 24,
    );

TextStyle chartTitleStyle() => const TextStyle(
      fontFamily: mainFont,
      fontSize: 15,
      //color: colorConfig().bodyBgColor.withAlpha(192),
      color: Colors.black,
      fontWeight: FontWeight.w300,
    );

const taskFormFieldStyle = TextStyle(color: Colors.black87);

TextStyle saveButtonStyle() => TextStyle(
      fontSize: 20,
      fontFamily: mainFont,
      color: colorConfig().error,
    );

TextStyle cancelButtonStyle() => TextStyle(
      fontSize: 20,
      fontFamily: mainFont,
      fontWeight: FontWeight.w100,
      color: colorConfig().entryTextColor,
    );

const segmentItemStyle = TextStyle(
  fontFamily: mainFont,
  fontSize: 14,
);

const badgeStyle = TextStyle(
  fontFamily: mainFont,
  fontWeight: FontWeight.w300,
  fontSize: 12,
);

const bottomNavLabelStyle = TextStyle(
  fontFamily: mainFont,
  fontWeight: FontWeight.w300,
);

TextStyle definitionCardTitleStyle() => TextStyle(
      color: colorConfig().entryTextColor,
      fontFamily: mainFont,
      fontSize: 24,
      height: 1.2,
    );

TextStyle definitionCardSubtitleStyle() => TextStyle(
      color: colorConfig().entryTextColor,
      fontFamily: mainFont,
      fontWeight: FontWeight.w200,
      fontSize: 16,
    );

const settingsIconSize = 24.0;

ColorConfig colorConfig() => getIt<ThemesService>().current;
