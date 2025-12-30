import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

/// Light mode surface overrides - forces white backgrounds instead of grey
class LightModeSurfaces {
  LightModeSurfaces._();

  static const Color surface = Color(0xFFFFFFFF); // Pure white
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFFAFAFA);
  static const Color surfaceContainer = Color(0xFFF5F5F5);
  static const Color surfaceContainerHigh = Color(0xFFEFEFEF);
  static const Color surfaceContainerHighest = Color(0xFFE8E8E8);
}

/// Standard FlexScheme themes available for selection.
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

/// Default theme name used when no theme is configured.
const String defaultThemeName = 'Grey Law';
