// ignore_for_file: equal_keys_in_map
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/themes_service.dart';
import 'package:lotti/utils/consts.dart';

class AppTheme {
  static const double bottomNavIconSize = 24;

  static const chartDateHorizontalPadding = EdgeInsets.symmetric(
    horizontal: 4,
  );
}

enum Themes {
  dark,
  bright,
}

class ThemeService {
  ThemeService() {
    _controller = StreamController<Themes>.broadcast();

    _db.watchConfigFlag(showBrightSchemeFlagName).listen((bright) {
      _controller.add(bright ? Themes.bright : Themes.dark);
      getIt<NavService>().restoreRoute();
    });
  }

  late final StreamController<Themes> _controller;
  final _db = getIt<JournalDb>();

  Stream<Themes> getStream() {
    return _controller.stream;
  }
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
  color: colorConfig().entryTextColor,
  fontWeight: FontWeight.bold,
  fontFamily: 'Lato',
  fontSize: 18,
);

TextStyle textStyle = TextStyle(
  color: colorConfig().entryTextColor,
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
  color: colorConfig().entryTextColor,
  fontWeight: FontWeight.w500,
  fontSize: 18,
);

TextStyle formLabelStyle = TextStyle(
  color: colorConfig().entryTextColor,
  fontFamily: 'Oswald',
  fontSize: 16,
);

TextStyle buttonLabelStyle = TextStyle(
  color: colorConfig().entryTextColor,
  fontFamily: 'Oswald',
  fontSize: 16,
);

TextStyle settingsLabelStyle = TextStyle(
  color: colorConfig().entryTextColor,
  fontFamily: 'Oswald',
  fontSize: 16,
);

TextStyle choiceLabelStyle = TextStyle(
  color: colorConfig().entryTextColor,
  fontFamily: 'Oswald',
  fontSize: 16,
);

TextStyle logDetailStyle = TextStyle(
  color: colorConfig().entryTextColor,
  fontFamily: 'ShareTechMono',
  fontSize: 10,
);

TextStyle appBarTextStyle = TextStyle(
  color: colorConfig().entryTextColor,
  fontFamily: 'Oswald',
  fontSize: 20,
);

TextStyle titleStyle = TextStyle(
  color: colorConfig().entryTextColor,
  fontFamily: 'Oswald',
  fontSize: 32,
  fontWeight: FontWeight.w300,
);

TextStyle taskTitleStyle = TextStyle(
  color: colorConfig().entryTextColor,
  fontFamily: 'Oswald',
  fontSize: 24,
);

TextStyle multiSelectStyle = TextStyle(
  color: colorConfig().entryTextColor,
  fontFamily: 'Oswald',
  fontWeight: FontWeight.w100,
  fontSize: 24,
);

TextStyle chartTitleStyle = TextStyle(
  fontFamily: 'Oswald',
  fontSize: 14,
  color: colorConfig().entryTextColor,
  fontWeight: FontWeight.w300,
);

const taskFormFieldStyle = TextStyle(color: Colors.black87);

TextStyle saveButtonStyle = TextStyle(
  fontSize: 20,
  fontFamily: 'Oswald',
  color: colorConfig().error,
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
  color: colorConfig().entryTextColor,
  fontFamily: 'Oswald',
  fontSize: 24,
  height: 1.2,
);

final definitionCardSubtitleStyle = TextStyle(
  color: colorConfig().entryTextColor,
  fontFamily: 'Oswald',
  fontWeight: FontWeight.w200,
  fontSize: 16,
);

const settingsIconSize = 24.0;

ColorConfig colorConfig() => getIt<ColorsService>().current;
