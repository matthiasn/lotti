import 'package:flutter/material.dart';
import 'package:tinycolor2/tinycolor2.dart';

import 'classes/tag_type_definitions.dart';

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
  static Color bodyBgColor = const Color.fromRGBO(47, 47, 59, 1);
  static Color entryBgColor = const Color.fromRGBO(155, 200, 245, 1);
  static Color tagColor = const Color.fromRGBO(155, 200, 245, 1);
  static Color tagTextColor = editorTextColor;
  static Color personTagColor = const Color.fromRGBO(55, 201, 154, 1);
  static Color storyTagColor = const Color.fromRGBO(200, 120, 0, 1);
  static Color privateTagColor = Colors.red;
  static Color entryTextColor = const Color.fromRGBO(158, 158, 158, 1);
  static Color editorTextColor = const Color.fromRGBO(51, 51, 51, 1);
  static Color starredGold = const Color.fromRGBO(255, 215, 0, 1);
  static Color editorBgColor = Colors.white;

  static Color headerBgColor = const Color.fromRGBO(68, 68, 85, 1);
  static Color searchBgColor = const Color.fromRGBO(68, 68, 85, 0.3);
  static Color searchBgHoverColor = const Color.fromRGBO(68, 68, 85, 0.6);
  static Color appBarFgColor = const Color.fromRGBO(180, 190, 200, 1);
  static Color codeBlockBackground = const Color.fromRGBO(228, 232, 240, 1);

  static Color outboxSuccessColor = const Color.fromRGBO(50, 120, 50, 1);
  static Color outboxPendingColor = const Color.fromRGBO(200, 120, 0, 1);
  static Color outboxErrorColor = const Color.fromRGBO(120, 50, 50, 1);
  static Color headerFontColor = Colors.white;
  static Color headerFontColor2 = entryBgColor;
  static Color activeAudioControl = Colors.red;
  static Color audioMeterBar = Colors.blue;
  static Color audioMeterTooHotBar = Colors.orange;
  static Color audioMeterPeakedBar = Colors.red;
  static Color error = Colors.red;
  static Color private = Colors.red;
  static Color audioMeterBarBackground =
      TinyColor(headerBgColor).lighten(40).color;
  static Color inactiveAudioControl = const Color.fromRGBO(155, 155, 177, 1);
  static Color listItemText = bodyBgColor;
}

class AppNumbers {
  static const double borderRadius = 3.0;
}

TextStyle inputStyle = TextStyle(
  color: AppColors.entryTextColor,
  fontWeight: FontWeight.bold,
  fontFamily: 'Lato',
  fontSize: 18.0,
);

TextStyle textStyle = TextStyle(
  color: AppColors.entryTextColor,
  fontFamily: 'Oswald',
  fontSize: 14.0,
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
  fontSize: 16.0,
);

TextStyle formLabelStyle = TextStyle(
  color: AppColors.entryTextColor,
  height: 1.6,
  fontFamily: 'Oswald',
  fontSize: 20,
);
