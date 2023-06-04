// ignore_for_file: equal_keys_in_map
import 'package:flutter/material.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/utils/color.dart';
import 'package:tinycolor2/tinycolor2.dart';

final Color white = colorFromCssHex('#FFFFFF');
final Color iron = colorFromCssHex('#909090');
final Color primaryColor = colorFromCssHex('#82E6CE');

final Color primaryColorLight = colorFromCssHex('#CFF3EA');
final Color alarm = colorFromCssHex('#FF7373');
final Color nickel = colorFromCssHex('#B4B2B2');

final darkTheme = StyleConfig(
  tagColor: const Color.fromRGBO(155, 200, 246, 1),
  tagTextColor: const Color.fromRGBO(51, 51, 51, 1),
  personTagColor: const Color.fromRGBO(55, 201, 154, 1),
  storyTagColor: const Color.fromRGBO(200, 120, 0, 1),
  starredGold: const Color.fromRGBO(255, 215, 0, 1),
  selectedChoiceChipColor: primaryColor,
  selectedChoiceChipTextColor: const Color.fromRGBO(33, 33, 33, 1),
  unselectedChoiceChipColor: colorFromCssHex('#BBBBBB'),
  unselectedChoiceChipTextColor: const Color.fromRGBO(255, 245, 240, 1),
  primaryTextColor: white,
  secondaryTextColor: primaryColor.desaturate(70).darken(20),
  primaryColor: primaryColor,
  primaryColorLight: primaryColorLight,
  hover: iron,
  cardColor: primaryColor.desaturate(60).darken(60),
  chartTextColor: nickel,
  keyboardAppearance: Brightness.dark,
  textEditorBackground: Colors.white.withOpacity(0.1),
);
