import 'package:flutter/material.dart';
import 'package:tinycolor2/tinycolor2.dart';

class AppColors {
  static Color bodyBgColor = const Color.fromRGBO(47, 47, 59, 1);
  static Color entryBgColor = const Color.fromRGBO(155, 200, 245, 1);
  static Color entryTextColor = const Color.fromRGBO(180, 190, 200, 1);
  static Color editorBgColor = Colors.white;
  static Color headerBgColor = const Color.fromRGBO(68, 68, 85, 1);
  static Color outboxSuccessColor = const Color.fromRGBO(50, 120, 50, 1);
  static Color outboxPendingColor = const Color.fromRGBO(200, 120, 0, 1);
  static Color outboxErrorColor = const Color.fromRGBO(120, 50, 50, 1);
  static Color headerFontColor = Colors.white;
  static Color headerFontColor2 = entryBgColor;
  static Color activeAudioControl = Colors.red;
  static Color audioMeterBar = Colors.blue;
  static Color audioMeterTooHotBar = Colors.orange;
  static Color audioMeterPeakedBar = Colors.red;
  static Color audioMeterBarBackground =
      TinyColor(headerBgColor).lighten(40).color;
  static Color inactiveAudioControl = const Color.fromRGBO(155, 155, 177, 1);
  static Color listItemText = bodyBgColor;
}

class AppNumbers {
  static const double borderRadius = 3.0;
}
