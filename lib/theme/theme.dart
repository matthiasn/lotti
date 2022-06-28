import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:tinycolor2/tinycolor2.dart';

Color getTagColor(TagEntity tagEntity) {
  if (tagEntity.private) {
    return getIt<ThemeService>().colors.privateTagColor;
  }

  return tagEntity.maybeMap(
    personTag: (_) => getIt<ThemeService>().colors.personTagColor,
    storyTag: (_) => getIt<ThemeService>().colors.storyTagColor,
    orElse: () => getIt<ThemeService>().colors.tagColor,
  );
}

const defaultBaseColor = Color.fromRGBO(51, 77, 118, 1);

ColorConfig defaultColors = ColorConfig(
  entryBgColor: Colors.white,
  unselectedChoiceChipColor: const Color.fromRGBO(200, 195, 190, 1),
  actionColor: const Color.fromRGBO(155, 200, 245, 1),
  tagColor: const Color.fromRGBO(155, 200, 245, 1),
  tagTextColor: const Color.fromRGBO(51, 51, 51, 1),
  personTagColor: const Color.fromRGBO(55, 201, 154, 1),
  storyTagColor: const Color.fromRGBO(200, 120, 0, 1),
  privateTagColor: Colors.red,
  bottomNavIconUnselected: const Color.fromRGBO(200, 195, 190, 1),
  bottomNavIconSelected: const Color.fromRGBO(252, 147, 76, 1),
  editorTextColor: const Color.fromRGBO(51, 51, 51, 1),
  starredGold: const Color.fromRGBO(255, 215, 0, 1),
  editorBgColor: Colors.white,
  baseColor: const Color.fromRGBO(51, 77, 118, 1),
  bodyBgColor: darken(defaultBaseColor, 20),
  headerBgColor: darken(defaultBaseColor, 10),
  entryCardColor: defaultBaseColor,
  entryTextColor: const Color.fromRGBO(200, 195, 190, 1),
  searchBgColor: const Color.fromRGBO(68, 68, 85, 0.3),
  appBarFgColor: const Color.fromRGBO(180, 190, 200, 1),
  codeBlockBackground: const Color.fromRGBO(228, 232, 240, 1),
  timeRecording: const Color.fromRGBO(255, 22, 22, 1),
  timeRecordingBg: const Color.fromRGBO(255, 44, 44, 0.95),
  outboxSuccessColor: const Color.fromRGBO(50, 120, 50, 1),
  outboxPendingColor: const Color.fromRGBO(200, 120, 0, 1),
  outboxErrorColor: const Color.fromRGBO(120, 50, 50, 1),
  headerFontColor: const Color.fromRGBO(155, 200, 245, 1),
  activeAudioControl: Colors.red,
  audioMeterBar: Colors.blue,
  audioMeterTooHotBar: Colors.orange,
  audioMeterPeakedBar: Colors.red,
  error: Colors.red,
  private: Colors.red,
  audioMeterBarBackground:
      TinyColor.fromColor(defaultBaseColor).lighten(30).color,
  inactiveAudioControl: const Color.fromRGBO(155, 155, 177, 1),
  unselectedChoiceChipTextColor: const Color.fromRGBO(51, 77, 118, 1),
);

const brightBaseColor = Color.fromRGBO(244, 187, 41, 1);

ColorConfig brightColors = ColorConfig(
  entryBgColor: Colors.white,
  unselectedChoiceChipColor: const Color.fromRGBO(200, 195, 190, 1),
  actionColor: const Color.fromRGBO(155, 200, 245, 1),
  tagColor: const Color.fromRGBO(155, 200, 245, 1),
  tagTextColor: const Color.fromRGBO(51, 51, 51, 1),
  personTagColor: const Color.fromRGBO(55, 201, 154, 1),
  storyTagColor: const Color.fromRGBO(200, 120, 0, 1),
  privateTagColor: Colors.red,
  bottomNavIconUnselected: const Color.fromRGBO(30, 50, 90, 1),
  bottomNavIconSelected: Colors.white,
  editorTextColor: const Color.fromRGBO(51, 51, 51, 1),
  starredGold: const Color.fromRGBO(255, 215, 0, 1),
  editorBgColor: Colors.white,
  baseColor: const Color.fromRGBO(244, 187, 41, 1),
  bodyBgColor: darken(brightBaseColor, 20),
  headerBgColor: darken(brightBaseColor, 10),
  entryCardColor: brightBaseColor,
  entryTextColor: const Color.fromRGBO(30, 50, 90, 1),
  searchBgColor: const Color.fromRGBO(68, 68, 85, 0.3),
  appBarFgColor: const Color.fromRGBO(180, 190, 200, 1),
  codeBlockBackground: const Color.fromRGBO(228, 232, 240, 1),
  timeRecording: const Color.fromRGBO(255, 22, 22, 1),
  timeRecordingBg: const Color.fromRGBO(255, 44, 44, 0.95),
  outboxSuccessColor: const Color.fromRGBO(50, 120, 50, 1),
  outboxPendingColor: const Color.fromRGBO(200, 120, 0, 1),
  outboxErrorColor: const Color.fromRGBO(120, 50, 50, 1),
  headerFontColor: const Color.fromRGBO(40, 60, 100, 1),
  activeAudioControl: Colors.red,
  audioMeterBar: Colors.blue,
  audioMeterTooHotBar: Colors.orange,
  audioMeterPeakedBar: Colors.red,
  error: Colors.red,
  private: Colors.red,
  audioMeterBarBackground:
      TinyColor.fromColor(defaultBaseColor).lighten(30).color,
  inactiveAudioControl: const Color.fromRGBO(155, 155, 177, 1),
  unselectedChoiceChipTextColor: const Color.fromRGBO(51, 77, 118, 1),
);

class ThemeService {
  ThemeService() {
    _db.watchConfigFlag('show_bright_scheme').listen((bright) {
      colors = bright ? brightColors : defaultColors;
      debugPrint(jsonEncode(colors));
    });
  }

  final _db = getIt<JournalDb>();
  ColorConfig colors = defaultColors;
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
  color: getIt<ThemeService>().colors.entryTextColor,
  fontWeight: FontWeight.bold,
  fontFamily: 'Lato',
  fontSize: 18,
);

TextStyle textStyle = TextStyle(
  color: getIt<ThemeService>().colors.entryTextColor,
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
  color: getIt<ThemeService>().colors.entryTextColor,
  fontWeight: FontWeight.w500,
  fontSize: 18,
);

TextStyle formLabelStyle = TextStyle(
  color: getIt<ThemeService>().colors.entryTextColor,
  fontFamily: 'Oswald',
  fontSize: 16,
);

TextStyle buttonLabelStyle = TextStyle(
  color: getIt<ThemeService>().colors.entryTextColor,
  fontFamily: 'Oswald',
  fontSize: 16,
);

TextStyle settingsLabelStyle = TextStyle(
  color: getIt<ThemeService>().colors.entryTextColor,
  fontFamily: 'Oswald',
  fontSize: 16,
);

TextStyle choiceLabelStyle = TextStyle(
  color: getIt<ThemeService>().colors.entryTextColor,
  fontFamily: 'Oswald',
  fontSize: 16,
);

TextStyle logDetailStyle = TextStyle(
  color: getIt<ThemeService>().colors.entryTextColor,
  fontFamily: 'ShareTechMono',
  fontSize: 10,
);

TextStyle appBarTextStyle = TextStyle(
  color: getIt<ThemeService>().colors.entryTextColor,
  fontFamily: 'Oswald',
  fontSize: 20,
);

TextStyle titleStyle = TextStyle(
  color: getIt<ThemeService>().colors.entryTextColor,
  fontFamily: 'Oswald',
  fontSize: 32,
  fontWeight: FontWeight.w300,
);

TextStyle taskTitleStyle = TextStyle(
  color: getIt<ThemeService>().colors.entryTextColor,
  fontFamily: 'Oswald',
  fontSize: 24,
);

TextStyle multiSelectStyle = TextStyle(
  color: getIt<ThemeService>().colors.entryTextColor,
  fontFamily: 'Oswald',
  fontWeight: FontWeight.w100,
  fontSize: 24,
);

TextStyle chartTitleStyle = TextStyle(
  fontFamily: 'Oswald',
  fontSize: 14,
  color: getIt<ThemeService>().colors.bodyBgColor,
  fontWeight: FontWeight.w300,
);

const taskFormFieldStyle = TextStyle(color: Colors.black87);

TextStyle saveButtonStyle = TextStyle(
  fontSize: 20,
  fontFamily: 'Oswald',
  color: getIt<ThemeService>().colors.error,
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
  color: getIt<ThemeService>().colors.entryTextColor,
  fontFamily: 'Oswald',
  fontSize: 24,
  height: 1.2,
);

final definitionCardSubtitleStyle = TextStyle(
  color: getIt<ThemeService>().colors.entryTextColor,
  fontFamily: 'Oswald',
  fontWeight: FontWeight.w200,
  fontSize: 16,
);

final settingsCardTitleStyle = TextStyle(
  color: getIt<ThemeService>().colors.entryTextColor,
  fontFamily: 'Oswald',
  fontSize: 22,
  fontWeight: FontWeight.w300,
);

const settingsIconSize = 24.0;
