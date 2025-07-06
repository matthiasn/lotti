// ignore_for_file: equal_keys_in_map
import 'package:flutter/material.dart';
import 'package:lotti/utils/color.dart';
import 'package:tinycolor2/tinycolor2.dart';

final Color oldPrimaryColor = colorFromCssHex('#82E6CE');
final Color oldPrimaryColorLight = colorFromCssHex('#CFF3EA');
final Color alarm = colorFromCssHex('#FF7373');
final Color nickel = colorFromCssHex('#B4B2B2');

final Color successColor = colorFromCssHex('#34C191');
final Color failColor = colorFromCssHex('#FF7373');

final Color habitSkipColor = successColor
    .lighten()
    .desaturate()
    .mix(failColor.lighten().desaturate().complement());

const tagColor = Color.fromRGBO(155, 200, 246, 1);
const tagTextColor = Color.fromRGBO(51, 51, 51, 1);
const personTagColor = Color.fromRGBO(55, 201, 154, 1);
const storyTagColor = Color.fromRGBO(200, 120, 0, 1);
const starredGold = Color.fromRGBO(255, 215, 0, 1);

final Color secondaryTextColor = oldPrimaryColor.desaturate(70).darken(20);
final Color chartTextColor = nickel;
