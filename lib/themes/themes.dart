// ignore_for_file: equal_keys_in_map
import 'package:flutter/material.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/utils/color.dart';
import 'package:tinycolor2/tinycolor2.dart';

final Color white = colorFromCssHex('#FFFFFF');
final Color coal = colorFromCssHex('#000000');
final Color iron = colorFromCssHex('#909090');
final Color primaryColor = colorFromCssHex('#82E6CE');

final MaterialColor primaryColorMaterial = MaterialColor(
  primaryColor.value,
  {
    50: primaryColor.withOpacity(.1),
    100: primaryColor.withOpacity(.2),
    200: primaryColor.withOpacity(.3),
    300: primaryColor.withOpacity(.4),
    400: primaryColor.withOpacity(.5),
    500: primaryColor.withOpacity(.6),
    600: primaryColor.withOpacity(.7),
    700: primaryColor.withOpacity(.8),
    800: primaryColor.withOpacity(.9),
    900: primaryColor.withOpacity(1),
  },
);

final Color primaryColorLight = colorFromCssHex('#CFF3EA');
final Color ripIce = colorFromCssHex('#EFFFFB');
final Color alarm = colorFromCssHex('#FF7373');
final Color ice = colorFromCssHex('#F5F5F5');
final Color nickel = colorFromCssHex('#B4B2B2');

final darkTheme = StyleConfig(
  tagColor: const Color.fromRGBO(155, 200, 246, 1),
  tagTextColor: const Color.fromRGBO(51, 51, 51, 1),
  personTagColor: const Color.fromRGBO(55, 201, 154, 1),
  storyTagColor: const Color.fromRGBO(200, 120, 0, 1),
  privateTagColor: alarm,
  starredGold: const Color.fromRGBO(255, 215, 0, 1),
  activeAudioControl: alarm,
  audioMeterBar: Colors.blue,
  audioMeterTooHotBar: Colors.orange,
  audioMeterPeakedBar: alarm,
  private: alarm,
  selectedChoiceChipColor: primaryColor,
  selectedChoiceChipTextColor: const Color.fromRGBO(33, 33, 33, 1),
  unselectedChoiceChipColor: colorFromCssHex('#BBBBBB'),
  unselectedChoiceChipTextColor: const Color.fromRGBO(255, 245, 240, 1),
  negspace: coal,
  primaryTextColor: white,
  secondaryTextColor: primaryColor.desaturate(70).darken(20),
  primaryColor: primaryColor,
  primaryColorLight: primaryColorLight,
  hover: iron,
  alarm: alarm,
  cardColor: primaryColor.desaturate(60).darken(60),
  chartTextColor: nickel,
  keyboardAppearance: Brightness.dark,
  textEditorBackground: Colors.white.withOpacity(0.1),
);

final brightTheme = StyleConfig(
  tagColor: colorFromCssHex('#89BE2E'),
  tagTextColor: colorFromCssHex('#474B40'),
  personTagColor: const Color.fromRGBO(55, 201, 154, 1),
  storyTagColor: colorFromCssHex('#E27930'),
  privateTagColor: alarm,
  starredGold: const Color.fromRGBO(255, 215, 0, 1),
  activeAudioControl: colorFromCssHex('#CF322F'),
  audioMeterBar: Colors.blue,
  audioMeterTooHotBar: Colors.orange,
  audioMeterPeakedBar: alarm,
  private: alarm,
  selectedChoiceChipColor: primaryColor,
  selectedChoiceChipTextColor: const Color.fromRGBO(33, 33, 33, 1),
  unselectedChoiceChipColor: colorFromCssHex('#BBBBBB'),
  unselectedChoiceChipTextColor: const Color.fromRGBO(255, 245, 240, 1),
  negspace: white,
  primaryTextColor: coal,
  secondaryTextColor: iron,
  primaryColor: primaryColor,
  primaryColorLight: primaryColorLight,
  hover: ripIce,
  alarm: alarm,
  cardColor: ice,
  chartTextColor: iron,
  keyboardAppearance: Brightness.light,
  textEditorBackground: Colors.white,
);
