// ignore_for_file: equal_keys_in_map
import 'package:flutter/material.dart';
import 'package:flutter_datetime_picker/flutter_datetime_picker.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/get_it.dart';
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

const double chipBorderRadius = 8;
const mainFont = 'PlusJakartaSans';
const monospaceFont = 'Inconsolata';

const chipPadding = EdgeInsets.symmetric(
  vertical: 3,
  horizontal: 8,
);

final inputBorder = OutlineInputBorder(
  borderRadius: BorderRadius.circular(chipBorderRadius),
  borderSide: BorderSide(color: styleConfig().secondaryTextColor),
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
  Widget? suffixIcon,
}) =>
    InputDecoration(
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorderFocused,
      labelText: labelText,
      labelStyle: newLabelStyle().copyWith(
        color: styleConfig().secondaryTextColor,
      ),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      suffixIcon: suffixIcon,
    );

InputDecoration createDialogInputDecoration({String? labelText}) =>
    inputDecoration(labelText: labelText).copyWith(
      labelStyle: newLabelStyle().copyWith(color: Colors.black),
    );

const switchDecoration = InputDecoration(border: InputBorder.none);

const inputSpacer = SizedBox(height: 25);

const chipPaddingClosable = EdgeInsets.only(
  top: 1,
  bottom: 1,
  left: 8,
  right: 4,
);

TextStyle inputStyle() => TextStyle(
      color: styleConfig().primaryTextColor,
      fontSize: fontSizeMedium,
    );

TextStyle newInputStyle() => TextStyle(
      color: styleConfig().primaryTextColor,
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

TextStyle textStyleLargerUnderlined() => textStyle().copyWith(
      fontSize: 20,
      fontWeight: FontWeight.w100,
      decoration: TextDecoration.underline,
      fontFamily: monospaceFont,
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
      fontFamily: monospaceFont,
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
      fontSize: fontSizeMedium,
    );

TextStyle buttonLabelStyle() => TextStyle(
      color: styleConfig().primaryTextColor,
      fontSize: fontSizeMedium,
    );

TextStyle settingsLabelStyle() => TextStyle(
      color: styleConfig().primaryTextColor,
      fontSize: fontSizeMedium,
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
      fontWeight: FontWeight.bold,
    );

TextStyle appBarTextStyleNewLarge() => TextStyle(
      color: styleConfig().primaryTextColor,
      fontSize: fontSizeLarge,
      fontWeight: FontWeight.w100,
    );

TextStyle searchFieldStyle() => TextStyle(
      color: styleConfig().primaryTextColor,
      fontSize: fontSizeLarge,
      fontWeight: FontWeight.w100,
    );

TextStyle searchFieldHintStyle() => searchFieldStyle().copyWith(
      color: styleConfig().secondaryTextColor,
    );

TextStyle settingsCardTextStyle() => TextStyle(
      //color: colorConfig().entryTextColor,
      color: styleConfig().primaryTextColor,

      fontSize: fontSizeLarge,
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

const taskFormFieldStyle = TextStyle(color: Colors.black87);

TextStyle saveButtonStyle() => TextStyle(
      fontSize: fontSizeMedium,
      fontWeight: FontWeight.bold,
      color: styleConfig().primaryColor.darken(25),
    );

TextStyle cancelButtonStyle() => TextStyle(
      fontSize: fontSizeMedium,
      fontWeight: FontWeight.w100,
      color: styleConfig().primaryTextColor,
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

const bottomNavLabelStyle = TextStyle(
  fontWeight: FontWeight.w300,
);

TextStyle definitionCardTitleStyle() => TextStyle(
      color: styleConfig().primaryTextColor,
      fontSize: fontSizeLarge,
      height: 1.2,
    );

TextStyle definitionCardSubtitleStyle() => TextStyle(
      color: styleConfig().primaryTextColor,
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
  fontSize: 20,
);

TextStyle searchLabelStyle() => TextStyle(
      color: styleConfig().secondaryTextColor,
      fontFamily: 'Oswald',
      fontSize: fontSizeMedium,
      fontWeight: FontWeight.w100,
    );
