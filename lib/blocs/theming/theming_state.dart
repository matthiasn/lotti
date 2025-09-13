import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'theming_state.freezed.dart';

final Map<String, FlexScheme> themes = {
  'Material': FlexScheme.material,
  'Material High Contrast': FlexScheme.materialHc,
  'Deep Blue': FlexScheme.deepBlue,
  'Flutter Dash': FlexScheme.flutterDash,
  'Grey Law': FlexScheme.greyLaw,
  'Indigo': FlexScheme.indigo,
  'Mallard Green': FlexScheme.mallardGreen,
  'Mandy Red': FlexScheme.mandyRed,
  'Blue Whale': FlexScheme.blueWhale,
  'Damask': FlexScheme.damask,
  'Amber': FlexScheme.amber,
  'Shark': FlexScheme.shark,
  'Sakura': FlexScheme.sakura,
  'San Juan Blue': FlexScheme.sanJuanBlue,
  'Blumine Blue': FlexScheme.blumineBlue,
  'Aqua Blue': FlexScheme.aquaBlue,
  'Wasabi': FlexScheme.wasabi,
  'Vesuvius Burn': FlexScheme.vesuviusBurn,
  'Outer Space': FlexScheme.outerSpace,
  'Hippie Blue': FlexScheme.hippieBlue,
  'Money': FlexScheme.money,
};

@freezed
abstract class ThemingState with _$ThemingState {
  factory ThemingState({
    required bool enableTooltips,
    ThemeData? darkTheme,
    ThemeData? lightTheme,
    String? darkThemeName,
    String? lightThemeName,
    ThemeMode? themeMode,
  }) = _ThemingState;
}
