import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:tinycolor2/tinycolor2.dart';

class AppColors {
  static Color bodyBgColor = Color.fromRGBO(155, 200, 245, 1);
  static Color editorBgColor = Colors.white;
  static Color headerBgColor = Color.fromRGBO(68, 68, 85, 1);
  static Color headerFontColor = Colors.white;
  static Color activeAudioControl = Colors.red;
  static Color audioMeterBar = Colors.blue;
  static Color audioMeterTooHotBar = Colors.orange;
  static Color audioMeterPeakedBar = Colors.red;
  static Color audioMeterBarBackground =
      TinyColor(headerBgColor).lighten(40).color;
  static Color inactiveAudioControl = headerBgColor;
}

class AppNumbers {
  static const double borderRadius = 3.0;
}
