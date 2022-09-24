// ignore_for_file: equal_keys_in_map
import 'package:flutter/material.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/themes/utils.dart';
import 'package:lotti/utils/color.dart';
import 'package:tinycolor2/tinycolor2.dart';

const defaultBaseColor = Color.fromRGBO(51, 77, 118, 1);
const brightBaseColor = Color.fromRGBO(244, 187, 41, 1);

final darkTheme = ColorConfig(
  actionColor: const Color.fromRGBO(155, 200, 245, 1),
  tagColor: const Color.fromRGBO(155, 200, 246, 1),
  tagTextColor: const Color.fromRGBO(51, 51, 51, 1),
  personTagColor: const Color.fromRGBO(55, 201, 154, 1),
  storyTagColor: const Color.fromRGBO(200, 120, 0, 1),
  privateTagColor: Colors.red,
  bottomNavBackground: darken(defaultBaseColor, 10),
  bottomNavIconUnselected: const Color.fromRGBO(200, 195, 190, 1),
  bottomNavIconSelected: const Color.fromRGBO(252, 147, 76, 1),
  starredGold: const Color.fromRGBO(255, 215, 0, 1),
  codeBlockBackground: const Color.fromRGBO(228, 232, 240, 1),
  timeRecording: const Color.fromRGBO(255, 22, 22, 1),
  timeRecordingBg: const Color.fromRGBO(255, 44, 44, 0.95),
  outboxSuccessColor: const Color.fromRGBO(50, 120, 50, 1),
  outboxPendingColor: const Color.fromRGBO(200, 120, 0, 1),
  activeAudioControl: Colors.red,
  audioMeterBar: Colors.blue,
  audioMeterTooHotBar: Colors.orange,
  audioMeterPeakedBar: Colors.red,
  private: Colors.red,
  audioMeterBarBackground:
      TinyColor.fromColor(defaultBaseColor).lighten(30).color,
  selectedChoiceChipColor: Colors.lightBlue,
  selectedChoiceChipTextColor: const Color.fromRGBO(200, 195, 190, 1),
  unselectedChoiceChipColor: colorFromCssHex('#BBBBBB'),
  unselectedChoiceChipTextColor: colorFromCssHex('#474b40'),
  negspace: colorFromCssHex('#FFFFFF'),
  coal: colorFromCssHex('#000000'),
  iron: colorFromCssHex('#909090'),
  riptide: colorFromCssHex('#82E6CE'),
  riplight: colorFromCssHex('#CFF3EA'),
  alarm: colorFromCssHex('#FF7373'),
  ice: colorFromCssHex('#F5F5F5'),
);

final brightTheme = ColorConfig(
  actionColor: colorFromCssHex('#E27930'),
  tagColor: colorFromCssHex('#89BE2E'),
  tagTextColor: colorFromCssHex('#474B40'),
  personTagColor: const Color.fromRGBO(55, 201, 154, 1),
  storyTagColor: colorFromCssHex('#E27930'),
  privateTagColor: colorFromCssHex('#CF322F'),
  bottomNavBackground: darken(brightBaseColor, 10),
  bottomNavIconUnselected: colorFromCssHex('#474B40'),
  bottomNavIconSelected: Colors.white,
  starredGold: const Color.fromRGBO(255, 215, 0, 1),
  codeBlockBackground: const Color.fromRGBO(228, 232, 240, 1),
  timeRecording: colorFromCssHex('#CF322F'),
  timeRecordingBg: colorFromCssHex('#CF322FEE'),
  outboxSuccessColor: const Color.fromRGBO(50, 120, 50, 1),
  outboxPendingColor: const Color.fromRGBO(200, 120, 0, 1),
  activeAudioControl: colorFromCssHex('#CF322F'),
  audioMeterBar: Colors.blue,
  audioMeterTooHotBar: Colors.orange,
  audioMeterPeakedBar: colorFromCssHex('#CF322F'),
  private: colorFromCssHex('#CF322F'),
  audioMeterBarBackground:
      TinyColor.fromColor(defaultBaseColor).lighten(30).color,
  selectedChoiceChipColor: Colors.lightBlue,
  selectedChoiceChipTextColor: const Color.fromRGBO(200, 195, 190, 1),
  unselectedChoiceChipColor: colorFromCssHex('#BBBBBB'),
  unselectedChoiceChipTextColor: colorFromCssHex('#474b40'),
  negspace: colorFromCssHex('#FFFFFF'),
  coal: colorFromCssHex('#000000'),
  iron: colorFromCssHex('#909090'),
  riptide: colorFromCssHex('#82E6CE'),
  riplight: colorFromCssHex('#CFF3EA'),
  alarm: colorFromCssHex('#FF7373'),
  ice: colorFromCssHex('#F5F5F5'),
);
