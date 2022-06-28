// ignore_for_file: equal_keys_in_map
import 'package:flutter/material.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
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

const defaultBaseColor = Color.fromRGBO(51, 77, 118, 1);

class AppColors {
  static const entryBgColor = ColorRef(Color.fromRGBO(155, 200, 245, 1));
  static const actionColor = ColorRef(Color.fromRGBO(155, 200, 245, 1));
  static const tagColor = ColorRef(Color.fromRGBO(155, 200, 245, 1));
  static const tagTextColor = ColorRef(editorTextColor);
  static const personTagColor = ColorRef(Color.fromRGBO(55, 201, 154, 1));
  static const storyTagColor = ColorRef(Color.fromRGBO(200, 120, 0, 1));
  static const privateTagColor = ColorRef(Colors.red);
  static const bottomNavIconUnselected = ColorRef(entryTextColor);
  static const bottomNavIconSelected =
      ColorRef(Color.fromRGBO(252, 147, 76, 1));
  static const editorTextColor = ColorRef(Color.fromRGBO(51, 51, 51, 1));
  static const starredGold = ColorRef(Color.fromRGBO(255, 215, 0, 1));
  static const editorBgColor = ColorRef(Colors.white);

  static const baseColor = ColorRef(Color.fromRGBO(51, 77, 118, 1));

  static final bodyBgColor = ColorRef(darken(baseColor, 20));
  static final headerBgColor = ColorRef(darken(baseColor, 10));
  static const entryCardColor = ColorRef(baseColor);
  static const entryTextColor = ColorRef(Color.fromRGBO(200, 195, 190, 1));

  static const searchBgColor = ColorRef(Color.fromRGBO(68, 68, 85, 0.3));
  static const appBarFgColor = ColorRef(Color.fromRGBO(180, 190, 200, 1));
  static const codeBlockBackground = ColorRef(Color.fromRGBO(228, 232, 240, 1));

  static const timeRecording = ColorRef(Color.fromRGBO(255, 22, 22, 1));
  static const timeRecordingBg = ColorRef(Color.fromRGBO(255, 44, 44, 0.95));

  static const outboxSuccessColor = ColorRef(Color.fromRGBO(50, 120, 50, 1));
  static const outboxPendingColor = ColorRef(Color.fromRGBO(200, 120, 0, 1));
  static const outboxErrorColor = ColorRef(Color.fromRGBO(120, 50, 50, 1));
  static const headerFontColor = ColorRef(entryBgColor);
  static const activeAudioControl = ColorRef(Colors.red);
  static const audioMeterBar = ColorRef(Colors.blue);
  static const audioMeterTooHotBar = ColorRef(Colors.orange);
  static const audioMeterPeakedBar = ColorRef(Colors.red);
  static const error = ColorRef(Colors.red);
  static const private = ColorRef(Colors.red);
  static final audioMeterBarBackground = ColorRef(lighten(headerBgColor, 40));
  static const inactiveAudioControl =
      ColorRef(Color.fromRGBO(155, 155, 177, 1));

  static const unselectedChoiceChipColor =
      ColorRef(Color.fromRGBO(200, 195, 190, 1));

  static const unselectedChoiceChipTextColor =
      ColorRef(Color.fromRGBO(51, 77, 118, 1));
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

Map<ThemeRef, Object> darkTheme = {
  AppColors.entryBgColor: Colors.white,
  AppColors.unselectedChoiceChipColor: const Color.fromRGBO(200, 195, 190, 1),
  AppColors.actionColor: const Color.fromRGBO(155, 200, 245, 1),
  AppColors.tagColor: const Color.fromRGBO(155, 200, 245, 1),
  AppColors.tagTextColor: const Color.fromRGBO(51, 51, 51, 1),
  AppColors.personTagColor: const Color.fromRGBO(55, 201, 154, 1),
  AppColors.storyTagColor: const Color.fromRGBO(200, 120, 0, 1),
  AppColors.privateTagColor: Colors.red,
  AppColors.bottomNavIconUnselected: const Color.fromRGBO(200, 195, 190, 1),
  AppColors.bottomNavIconSelected: const Color.fromRGBO(252, 147, 76, 1),
  AppColors.editorTextColor: const Color.fromRGBO(51, 51, 51, 1),
  AppColors.starredGold: const Color.fromRGBO(255, 215, 0, 1),
  AppColors.editorBgColor: Colors.white,
  AppColors.baseColor: const Color.fromRGBO(51, 77, 118, 1),
  AppColors.bodyBgColor: darken(defaultBaseColor, 20),
  AppColors.headerBgColor: darken(defaultBaseColor, 10),
  AppColors.entryCardColor: defaultBaseColor,
  AppColors.entryTextColor: const Color.fromRGBO(200, 195, 190, 1),
  AppColors.searchBgColor: const Color.fromRGBO(68, 68, 85, 0.3),
  AppColors.appBarFgColor: const Color.fromRGBO(180, 190, 200, 1),
  AppColors.codeBlockBackground: const Color.fromRGBO(228, 232, 240, 1),
  AppColors.timeRecording: const Color.fromRGBO(255, 22, 22, 1),
  AppColors.timeRecordingBg: const Color.fromRGBO(255, 44, 44, 0.95),
  AppColors.outboxSuccessColor: const Color.fromRGBO(50, 120, 50, 1),
  AppColors.outboxPendingColor: const Color.fromRGBO(200, 120, 0, 1),
  AppColors.outboxErrorColor: const Color.fromRGBO(120, 50, 50, 1),
  AppColors.headerFontColor: const Color.fromRGBO(155, 200, 245, 1),
  AppColors.activeAudioControl: Colors.red,
  AppColors.audioMeterBar: Colors.blue,
  AppColors.audioMeterTooHotBar: Colors.orange,
  AppColors.audioMeterPeakedBar: Colors.red,
  AppColors.error: Colors.red,
  AppColors.private: Colors.red,
  AppColors.audioMeterBarBackground:
      TinyColor.fromColor(defaultBaseColor).lighten(30).color,
  AppColors.inactiveAudioControl: const Color.fromRGBO(155, 155, 177, 1),
  AppColors.unselectedChoiceChipTextColor: const Color.fromRGBO(51, 77, 118, 1),
};
const brightBaseColor = Color.fromRGBO(244, 187, 41, 1);

Map<ThemeRef, Object> brightTheme = {
  AppColors.entryBgColor: Colors.white,
  AppColors.unselectedChoiceChipColor: const Color.fromRGBO(200, 195, 190, 1),
  AppColors.actionColor: const Color.fromRGBO(155, 200, 245, 1),
  AppColors.tagColor: const Color.fromRGBO(155, 200, 245, 1),
  AppColors.tagTextColor: const Color.fromRGBO(51, 51, 51, 1),
  AppColors.personTagColor: const Color.fromRGBO(55, 201, 154, 1),
  AppColors.storyTagColor: const Color.fromRGBO(200, 120, 0, 1),
  AppColors.privateTagColor: Colors.red,
  AppColors.bottomNavIconUnselected: const Color.fromRGBO(30, 50, 90, 1),
  AppColors.bottomNavIconSelected: Colors.white,
  AppColors.editorTextColor: const Color.fromRGBO(51, 51, 51, 1),
  AppColors.starredGold: const Color.fromRGBO(255, 215, 0, 1),
  AppColors.editorBgColor: Colors.white,
  AppColors.baseColor: const Color.fromRGBO(244, 187, 41, 1),
  AppColors.bodyBgColor: darken(brightBaseColor, 20),
  AppColors.headerBgColor: darken(brightBaseColor, 10),
  AppColors.entryCardColor: brightBaseColor,
  AppColors.entryTextColor: const Color.fromRGBO(30, 50, 90, 1),
  AppColors.searchBgColor: const Color.fromRGBO(68, 68, 85, 0.3),
  AppColors.appBarFgColor: const Color.fromRGBO(180, 190, 200, 1),
  AppColors.codeBlockBackground: const Color.fromRGBO(228, 232, 240, 1),
  AppColors.timeRecording: const Color.fromRGBO(255, 22, 22, 1),
  AppColors.timeRecordingBg: const Color.fromRGBO(255, 44, 44, 0.95),
  AppColors.outboxSuccessColor: const Color.fromRGBO(50, 120, 50, 1),
  AppColors.outboxPendingColor: const Color.fromRGBO(200, 120, 0, 1),
  AppColors.outboxErrorColor: const Color.fromRGBO(120, 50, 50, 1),
  AppColors.headerFontColor: const Color.fromRGBO(40, 60, 100, 1),
  AppColors.activeAudioControl: Colors.red,
  AppColors.audioMeterBar: Colors.blue,
  AppColors.audioMeterTooHotBar: Colors.orange,
  AppColors.audioMeterPeakedBar: Colors.red,
  AppColors.error: Colors.red,
  AppColors.private: Colors.red,
  AppColors.audioMeterBarBackground:
      TinyColor.fromColor(defaultBaseColor).lighten(30).color,
  AppColors.inactiveAudioControl: const Color.fromRGBO(155, 155, 177, 1),
  AppColors.unselectedChoiceChipTextColor: const Color.fromRGBO(51, 77, 118, 1),
};

class ThemeService {
  ThemeService() {
    Themed.defaultTheme = darkTheme;

    _db.watchConfigFlag('show_bright_scheme').listen((bright) {
      Themed.currentTheme = bright ? brightTheme : darkTheme;
    });
  }

  final _db = getIt<JournalDb>();
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

TextStyle inputStyle = const TextStyle(
  color: AppColors.entryTextColor,
  fontWeight: FontWeight.bold,
  fontFamily: 'Lato',
  fontSize: 18,
);

TextStyle textStyle = const TextStyle(
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

TextStyle labelStyle = const TextStyle(
  color: AppColors.entryTextColor,
  fontWeight: FontWeight.w500,
  fontSize: 18,
);

TextStyle formLabelStyle = const TextStyle(
  color: AppColors.entryTextColor,
  fontFamily: 'Oswald',
  fontSize: 16,
);

TextStyle buttonLabelStyle = const TextStyle(
  color: AppColors.entryTextColor,
  fontFamily: 'Oswald',
  fontSize: 16,
);

TextStyle settingsLabelStyle = const TextStyle(
  color: AppColors.entryTextColor,
  fontFamily: 'Oswald',
  fontSize: 16,
);

TextStyle choiceLabelStyle = const TextStyle(
  color: AppColors.entryTextColor,
  fontFamily: 'Oswald',
  fontSize: 16,
);

TextStyle logDetailStyle = const TextStyle(
  color: AppColors.entryTextColor,
  fontFamily: 'ShareTechMono',
  fontSize: 10,
);

TextStyle appBarTextStyle = const TextStyle(
  color: AppColors.entryTextColor,
  fontFamily: 'Oswald',
  fontSize: 20,
);

TextStyle titleStyle = const TextStyle(
  color: AppColors.entryTextColor,
  fontFamily: 'Oswald',
  fontSize: 32,
  fontWeight: FontWeight.w300,
);

TextStyle taskTitleStyle = const TextStyle(
  color: AppColors.entryTextColor,
  fontFamily: 'Oswald',
  fontSize: 24,
);

TextStyle multiSelectStyle = const TextStyle(
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

TextStyle saveButtonStyle = const TextStyle(
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

const definitionCardTitleStyle = TextStyle(
  color: AppColors.entryTextColor,
  fontFamily: 'Oswald',
  fontSize: 24,
  height: 1.2,
);

const definitionCardSubtitleStyle = TextStyle(
  color: AppColors.entryTextColor,
  fontFamily: 'Oswald',
  fontWeight: FontWeight.w200,
  fontSize: 16,
);

const settingsIconSize = 24.0;
