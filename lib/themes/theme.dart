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
  vertical: 3,
  horizontal: 8,
);

const chipPaddingClosable = EdgeInsets.only(
  top: 1,
  bottom: 1,
  left: 8,
  right: 4,
);

TextStyle inputStyle() => TextStyle(
      color: styleConfig().primaryTextColor,
      fontFamily: mainFont,
      fontSize: fontSizeMedium,
    );

TextStyle newInputStyle() => TextStyle(
      color: styleConfig().primaryTextColor,
      fontSize: fontSizeMedium,
    );

TextStyle textStyle() => TextStyle(
      color: styleConfig().primaryTextColor,
      fontFamily: mainFont,
      fontWeight: FontWeight.w400,
      fontSize: fontSizeMedium,
    );

TextStyle chartTooltipStyle() => const TextStyle(
      fontSize: fontSizeSmall,
      fontFamily: mainFont,
      fontWeight: FontWeight.w300,
    );

TextStyle chartTooltipStyleBold() => const TextStyle(
      fontSize: fontSizeSmall,
      fontFamily: mainFont,
      fontWeight: FontWeight.bold,
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
      color: styleConfig().primaryTextColor,
      fontWeight: FontWeight.w500,
      fontSize: 18,
    );

TextStyle newLabelStyle() => TextStyle(
      color: styleConfig().secondaryTextColor,
      fontSize: fontSizeMedium,
    );

TextStyle monospaceTextStyle() => TextStyle(
      fontFamily: 'Inconsolata',
      fontWeight: FontWeight.w300,
      fontSize: fontSizeMedium,
      color: styleConfig().primaryTextColor,
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

Brightness keyboardAppearance() {
  return styleConfig().keyboardAppearance;
}

TextStyle formLabelStyle() => TextStyle(
      color: styleConfig().primaryTextColor,
      fontFamily: mainFont,
      fontSize: fontSizeMedium,
    );

TextStyle buttonLabelStyle() => TextStyle(
      color: styleConfig().primaryTextColor,
      fontFamily: mainFont,
      fontSize: fontSizeMedium,
    );

TextStyle settingsLabelStyle() => TextStyle(
      color: styleConfig().primaryTextColor,
      fontFamily: mainFont,
      fontSize: fontSizeMedium,
    );

TextStyle choiceLabelStyle() => TextStyle(
      color: styleConfig().primaryTextColor,
      fontFamily: mainFont,
      fontSize: fontSizeMedium,
    );

TextStyle logDetailStyle() => monospaceTextStyle();

TextStyle appBarTextStyle() => TextStyle(
      color: styleConfig().primaryTextColor,
      fontFamily: mainFont,
      fontSize: fontSizeMedium,
      fontWeight: FontWeight.bold,
    );

TextStyle appBarTextStyleNew() => TextStyle(
      color: styleConfig().primaryTextColor,
      fontFamily: mainFont,
      fontSize: fontSizeMedium,
      fontWeight: FontWeight.bold,
    );

TextStyle appBarTextStyleNewLarge() => TextStyle(
      color: styleConfig().primaryTextColor,
      fontFamily: mainFont,
      fontSize: fontSizeLarge,
      fontWeight: FontWeight.w100,
    );

TextStyle searchFieldStyle() => TextStyle(
      color: styleConfig().primaryTextColor,
      fontFamily: mainFont,
      fontSize: fontSizeLarge,
      fontWeight: FontWeight.w100,
    );

TextStyle searchFieldHintStyle() => searchFieldStyle().copyWith(
      color: styleConfig().secondaryTextColor,
    );

TextStyle settingsCardTextStyle() => TextStyle(
      //color: colorConfig().entryTextColor,
      color: styleConfig().primaryTextColor,
      fontFamily: mainFont,
      fontSize: fontSizeLarge,
    );

TextStyle titleStyle() => TextStyle(
      color: styleConfig().primaryTextColor,
      fontFamily: mainFont,
      fontSize: fontSizeLarge,
      fontWeight: FontWeight.w300,
    );

TextStyle taskTitleStyle() => TextStyle(
      color: styleConfig().primaryTextColor,
      fontFamily: mainFont,
      fontSize: fontSizeLarge,
    );

TextStyle multiSelectStyle() => TextStyle(
      color: styleConfig().primaryTextColor,
      fontFamily: mainFont,
      fontWeight: FontWeight.w100,
      fontSize: fontSizeLarge,
    );

TextStyle chartTitleStyle() => TextStyle(
      fontFamily: mainFont,
      fontSize: fontSizeMedium,
      color: styleConfig().primaryTextColor,
      fontWeight: FontWeight.w300,
    );

TextStyle chartTitleStyleSmall() => TextStyle(
      fontFamily: mainFont,
      fontSize: fontSizeSmall,
      color: styleConfig().primaryTextColor,
      fontWeight: FontWeight.w300,
    );

const taskFormFieldStyle = TextStyle(color: Colors.black87);

TextStyle saveButtonStyle() => TextStyle(
      fontSize: fontSizeMedium,
      fontFamily: mainFont,
      fontWeight: FontWeight.bold,
      color: styleConfig().alarm,
    );

TextStyle cancelButtonStyle() => TextStyle(
      fontSize: fontSizeMedium,
      fontFamily: mainFont,
      fontWeight: FontWeight.w100,
      color: styleConfig().primaryTextColor,
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
      color: styleConfig().primaryTextColor,
      fontFamily: mainFont,
      fontSize: fontSizeLarge,
      height: 1.2,
    );

TextStyle definitionCardSubtitleStyle() => TextStyle(
      color: styleConfig().primaryTextColor,
      fontFamily: mainFont,
      fontWeight: FontWeight.w200,
      fontSize: fontSizeMedium,
    );

const settingsIconSize = 24.0;

StyleConfig styleConfig() => getIt<ThemesService>().current;

DatePickerTheme datePickerTheme() => DatePickerTheme(
      headerColor: styleConfig().secondaryTextColor,
      backgroundColor: styleConfig().cardColor,
      itemStyle: TextStyle(
        color: styleConfig().primaryTextColor,
        fontSize: 20,
      ),
      cancelStyle: TextStyle(
        color: styleConfig().cardColor,
        fontSize: 20,
      ),
      doneStyle: TextStyle(
        color: styleConfig().primaryTextColor,
        fontSize: 20,
      ),
    );

const habitCompletionHeaderStyle = TextStyle(
  color: Colors.black,
  fontFamily: mainFont,
  fontSize: 20,
);
