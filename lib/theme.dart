import 'package:flutter/material.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:themed/themed.dart';
import 'package:tinycolor2/tinycolor2.dart';

Color getTagColor(TagEntity tagEntity) {
  if (tagEntity.private) {
    return AppColors.privateTagColor;
  }

  return tagEntity.maybeMap(
    personTag: (_) => AppColors.personTagColor,
    storyTag: (_) => AppColors.storyTagColor,
    orElse: () => AppColors.tagColor,
  );
}

class AppColors {
  static Color entryBgColor = const ColorRef(Color.fromRGBO(155, 200, 245, 1));
  static Color actionColor = const ColorRef(Color.fromRGBO(155, 200, 245, 1));
  static Color tagColor = const ColorRef(Color.fromRGBO(155, 200, 245, 1));
  static Color tagTextColor = ColorRef(editorTextColor);
  static Color personTagColor = const ColorRef(Color.fromRGBO(55, 201, 154, 1));
  static Color storyTagColor = const ColorRef(Color.fromRGBO(200, 120, 0, 1));
  static Color privateTagColor = const ColorRef(Colors.red);
  static Color bottomNavIconUnselected = ColorRef(entryTextColor);
  static Color bottomNavIconSelected =
      const ColorRef(Color.fromRGBO(252, 147, 76, 1));
  static Color editorTextColor = const ColorRef(Color.fromRGBO(51, 51, 51, 1));
  static Color starredGold = const ColorRef(Color.fromRGBO(255, 215, 0, 1));
  static Color editorBgColor = const ColorRef(Colors.white);

  static Color baseColor = const ColorRef(Color.fromRGBO(51, 77, 118, 1));

  static Color bodyBgColor = ColorRef(darken(baseColor, 20));
  static Color headerBgColor = ColorRef(darken(baseColor, 10));
  static Color entryCardColor = ColorRef(baseColor);
  static Color entryTextColor =
      const ColorRef(Color.fromRGBO(200, 195, 190, 1));

  static Color searchBgColor = const ColorRef(Color.fromRGBO(68, 68, 85, 0.3));
  static Color appBarFgColor = const ColorRef(Color.fromRGBO(180, 190, 200, 1));
  static Color codeBlockBackground =
      const ColorRef(Color.fromRGBO(228, 232, 240, 1));

  static Color timeRecording = const ColorRef(Color.fromRGBO(255, 22, 22, 1));
  static Color timeRecordingBg =
      const ColorRef(Color.fromRGBO(255, 44, 44, 0.95));

  static Color outboxSuccessColor =
      const ColorRef(Color.fromRGBO(50, 120, 50, 1));
  static Color outboxPendingColor =
      const ColorRef(Color.fromRGBO(200, 120, 0, 1));
  static Color outboxErrorColor =
      const ColorRef(Color.fromRGBO(120, 50, 50, 1));
  static Color headerFontColor = ColorRef(entryBgColor);
  static Color activeAudioControl = const ColorRef(Colors.red);
  static Color audioMeterBar = const ColorRef(Colors.blue);
  static Color audioMeterTooHotBar = const ColorRef(Colors.orange);
  static Color audioMeterPeakedBar = const ColorRef(Colors.red);
  static Color error = const ColorRef(Colors.red);
  static Color private = const ColorRef(Colors.red);
  static Color audioMeterBarBackground = ColorRef(lighten(headerBgColor, 40));
  static Color inactiveAudioControl =
      const ColorRef(Color.fromRGBO(155, 155, 177, 1));
}

Color darken(Color color, int value) {
  return TinyColor.fromColor(color).darken(value).color;
}

Color lighten(Color color, int value) {
  return TinyColor.fromColor(color).lighten(value).color;
}

class AppTheme {
  static const double bottomNavIconSize = 24;

  static const chartDateHorizontalPadding = EdgeInsets.symmetric(
    horizontal: 4,
  );
}

const double chipBorderRadius = 8;

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

TextStyle inputStyle = TextStyle(
  color: AppColors.entryTextColor,
  fontWeight: FontWeight.bold,
  fontFamily: 'Lato',
  fontSize: 18,
);

TextStyle textStyle = TextStyle(
  color: AppColors.entryTextColor,
  fontFamily: 'Oswald',
  fontWeight: FontWeight.w400,
  fontSize: 16,
);

TextStyle textStyleLarger = textStyle.copyWith(
  fontSize: 18,
  fontWeight: FontWeight.normal,
);

TextStyle labelStyleLarger = textStyleLarger.copyWith(
  fontSize: 18,
  fontWeight: FontWeight.w300,
);

TextStyle labelStyle = TextStyle(
  color: AppColors.entryTextColor,
  fontWeight: FontWeight.w500,
  fontSize: 18,
);

TextStyle formLabelStyle = TextStyle(
  color: AppColors.entryTextColor,
  fontFamily: 'Oswald',
  fontSize: 16,
);

TextStyle buttonLabelStyle = TextStyle(
  color: AppColors.entryTextColor,
  fontFamily: 'Oswald',
  fontSize: 16,
);

TextStyle settingsLabelStyle = TextStyle(
  color: AppColors.entryTextColor,
  fontFamily: 'Oswald',
  fontSize: 16,
);

TextStyle choiceLabelStyle = TextStyle(
  color: AppColors.entryTextColor,
  fontFamily: 'Oswald',
  fontSize: 16,
);

TextStyle logDetailStyle = TextStyle(
  color: AppColors.entryTextColor,
  fontFamily: 'ShareTechMono',
  fontSize: 10,
);

TextStyle appBarTextStyle = TextStyle(
  color: AppColors.entryTextColor,
  fontFamily: 'Oswald',
  fontSize: 20,
);

TextStyle titleStyle = TextStyle(
  color: AppColors.entryTextColor,
  fontFamily: 'Oswald',
  fontSize: 32,
  fontWeight: FontWeight.w300,
);

TextStyle taskTitleStyle = TextStyle(
  color: AppColors.entryTextColor,
  fontFamily: 'Oswald',
  fontSize: 24,
);

TextStyle multiSelectStyle = TextStyle(
  color: AppColors.entryTextColor,
  fontFamily: 'Oswald',
  fontWeight: FontWeight.w100,
  fontSize: 24,
);

TextStyle chartTitleStyle = TextStyle(
  fontFamily: 'Oswald',
  fontSize: 14,
  color: AppColors.bodyBgColor,
  fontWeight: FontWeight.w300,
);

const taskFormFieldStyle = TextStyle(color: Colors.black87);

TextStyle saveButtonStyle = TextStyle(
  fontSize: 20,
  fontFamily: 'Oswald',
  color: AppColors.error,
);

const segmentItemStyle = TextStyle(
  fontFamily: 'Oswald',
  fontSize: 14,
);

const badgeStyle = TextStyle(
  fontFamily: 'Oswald',
  fontWeight: FontWeight.w300,
  fontSize: 12,
);

const bottomNavLabelStyle = TextStyle(
  fontFamily: 'Oswald',
  fontWeight: FontWeight.w300,
);

final definitionCardTitleStyle = TextStyle(
  color: AppColors.entryTextColor,
  fontFamily: 'Oswald',
  fontSize: 24,
  height: 1.2,
);

final definitionCardSubtitleStyle = TextStyle(
  color: AppColors.entryTextColor,
  fontFamily: 'Oswald',
  fontWeight: FontWeight.w200,
  fontSize: 16,
);

const settingsIconSize = 24.0;
