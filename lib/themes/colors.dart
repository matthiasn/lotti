// ignore_for_file: equal_keys_in_map
import 'package:flutter/material.dart';
import 'package:lotti/utils/color.dart';
import 'package:tinycolor2/tinycolor2.dart';

final Color oldPrimaryColor = colorFromCssHex('#82E6CE');
final Color oldPrimaryColorLight = colorFromCssHex('#CFF3EA');
final Color alarm = colorFromCssHex('#FF7373');
final Color nickel = colorFromCssHex('#B4B2B2');
final cardColor = oldPrimaryColor.desaturate(60).darken(60);

final habitSuccessColor = colorFromCssHex('#34C191');
final habitFailColor = colorFromCssHex('#FF7373');

final habitSkipColor = habitSuccessColor
    .lighten()
    .desaturate()
    .mix(habitFailColor.lighten().desaturate().complement());

const tagColor = Color.fromRGBO(155, 200, 246, 1);
const tagTextColor = Color.fromRGBO(51, 51, 51, 1);
const personTagColor = Color.fromRGBO(55, 201, 154, 1);
const storyTagColor = Color.fromRGBO(200, 120, 0, 1);
const starredGold = Color.fromRGBO(255, 215, 0, 1);

const unselectedChoiceChipTextColor = Color.fromRGBO(99, 99, 99, 0.7);
final secondaryTextColor = oldPrimaryColor.desaturate(70).darken(20);
final chartTextColor = nickel;
