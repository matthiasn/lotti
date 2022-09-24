// ignore_for_file: equal_keys_in_map
import 'package:flutter/material.dart';
import 'package:flutter_datetime_picker/flutter_datetime_picker.dart';
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
      color: colorConfig().coal,
      fontWeight: FontWeight.bold,
      fontFamily: mainFont,
      fontSize: 18,
    );

TextStyle newInputStyle() => TextStyle(
      color: colorConfig().coal,
      fontSize: fontSizeMedium,
    );

TextStyle textStyle() => TextStyle(
      color: colorConfig().coal,
      fontFamily: mainFont,
      fontWeight: FontWeight.w400,
      fontSize: fontSizeMedium,
    );

TextStyle textStyleLarger() => textStyle().copyWith(
      fontSize: 18,
      fontWeight: FontWeight.normal,
    );

TextStyle textStyleLargerUnderlined() => textStyle().copyWith(
      fontSize: 20,
      fontWeight: FontWeight.w100,
      decoration: TextDecoration.underline,
      fontFamily: 'Inconsolata',
    );

TextStyle labelStyleLarger() => textStyleLarger().copyWith(
      fontSize: 18,
      fontWeight: FontWeight.w300,
    );

TextStyle labelStyle() => TextStyle(
      color: colorConfig().coal,
      fontWeight: FontWeight.w500,
      fontSize: 18,
    );

TextStyle newLabelStyle() => TextStyle(
      color: colorConfig().coal,
      fontSize: fontSizeMedium,
    );

TextStyle monospaceTextStyle() => const TextStyle(
      fontFamily: 'Inconsolata',
      fontWeight: FontWeight.w300,
      fontSize: fontSizeMedium,
    );

TextStyle monospaceTextStyleSmall() => monospaceTextStyle().copyWith(
      fontSize: fontSizeSmall,
    );

TextStyle monospaceTextStyleLarge() => monospaceTextStyle().copyWith(
      fontSize: fontSizeLarge,
    );

TextStyle pickerMonoTextStyle() => monospaceTextStyle().copyWith(
      fontWeight: FontWeight.w100,
    );

TextStyle formLabelStyle() => TextStyle(
      color: colorConfig().coal,
      fontFamily: mainFont,
      fontSize: fontSizeMedium,
    );

TextStyle buttonLabelStyle() => TextStyle(
      color: colorConfig().coal,
      fontFamily: mainFont,
      fontSize: fontSizeMedium,
    );

TextStyle settingsLabelStyle() => TextStyle(
      color: colorConfig().coal,
      fontFamily: mainFont,
      fontSize: fontSizeMedium,
    );

TextStyle choiceLabelStyle() => TextStyle(
      color: colorConfig().coal,
      fontFamily: mainFont,
      fontSize: fontSizeMedium,
    );

TextStyle logDetailStyle() => monospaceTextStyle();

TextStyle appBarTextStyle() => TextStyle(
      color: colorConfig().coal,
      fontFamily: mainFont,
      fontSize: fontSizeMedium,
      fontWeight: FontWeight.bold,
    );

TextStyle appBarTextStyleNew() => TextStyle(
      color: colorConfig().coal,
      fontFamily: mainFont,
      fontSize: fontSizeMedium,
      fontWeight: FontWeight.w400,
    );

TextStyle settingsCardTextStyle() => TextStyle(
      //color: colorConfig().entryTextColor,
      color: colorConfig().coal,
      fontFamily: mainFont,
      fontSize: fontSizeLarge,
    );

TextStyle titleStyle() => TextStyle(
      color: colorConfig().coal,
      fontFamily: mainFont,
      fontSize: fontSizeLarge,
      fontWeight: FontWeight.w300,
    );

TextStyle taskTitleStyle() => TextStyle(
      color: colorConfig().coal,
      fontFamily: mainFont,
      fontSize: fontSizeLarge,
    );

TextStyle multiSelectStyle() => TextStyle(
      color: colorConfig().coal,
      fontFamily: mainFont,
      fontWeight: FontWeight.w100,
      fontSize: fontSizeLarge,
    );

TextStyle chartTitleStyle() => TextStyle(
      fontFamily: mainFont,
      fontSize: fontSizeMedium,
      color: colorConfig().coal,
      fontWeight: FontWeight.w300,
    );

const taskFormFieldStyle = TextStyle(color: Colors.black87);

TextStyle saveButtonStyle() => TextStyle(
      fontSize: fontSizeMedium,
      fontFamily: mainFont,
      color: colorConfig().alarm,
    );

TextStyle cancelButtonStyle() => TextStyle(
      fontSize: fontSizeMedium,
      fontFamily: mainFont,
      fontWeight: FontWeight.w100,
      color: colorConfig().coal,
    );

const segmentItemStyle = TextStyle(
  fontFamily: mainFont,
  fontSize: fontSizeSmall,
);

const badgeStyle = TextStyle(
  fontFamily: mainFont,
  fontWeight: FontWeight.w300,
  fontSize: fontSizeSmall,
);

const bottomNavLabelStyle = TextStyle(
  fontFamily: mainFont,
  fontWeight: FontWeight.w300,
);

TextStyle definitionCardTitleStyle() => TextStyle(
      color: colorConfig().coal,
      fontFamily: mainFont,
      fontSize: fontSizeLarge,
      height: 1.2,
    );

TextStyle definitionCardSubtitleStyle() => TextStyle(
      color: colorConfig().coal,
      fontFamily: mainFont,
      fontWeight: FontWeight.w200,
      fontSize: fontSizeMedium,
    );

const settingsIconSize = 24.0;

ColorConfig colorConfig() => getIt<ThemesService>().current;

DatePickerTheme datePickerTheme() => DatePickerTheme(
      headerColor: colorConfig().iron,
      backgroundColor: colorConfig().ice,
      itemStyle: TextStyle(
        color: colorConfig().coal,
        fontSize: 20,
      ),
      cancelStyle: TextStyle(
        color: colorConfig().ice,
        fontSize: 20,
      ),
      doneStyle: TextStyle(
        color: colorConfig().coal,
        fontSize: 20,
      ),
    );
