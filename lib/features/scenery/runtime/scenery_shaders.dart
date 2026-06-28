import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// Loads a compiled fragment program. Injectable so tests can supply a fake
/// (or failing) loader, mirroring the AI shaders' `AiShaderProgramLoader`.
typedef SceneryShaderProgramLoader = Future<ui.FragmentProgram> Function();

@visibleForTesting
abstract final class SceneryShaderAssets {
  static const sky = 'shaders/scenery_sky.frag';
  static const ocean = 'shaders/scenery_ocean.frag';
  static const cityLights = 'shaders/scenery_city_lights.frag';
}

/// Memoizing cache for the scenery fragment programs — each `.frag` is compiled
/// from its asset at most once per process, mirroring the AI shaders'
/// `AiStateShaderProgramCache`.
abstract final class SceneryShaderProgramCache {
  static Future<ui.FragmentProgram>? _sky;
  static Future<ui.FragmentProgram>? _ocean;
  static Future<ui.FragmentProgram>? _cityLights;

  static Future<ui.FragmentProgram> loadSky() {
    return _sky ??= ui.FragmentProgram.fromAsset(SceneryShaderAssets.sky);
  }

  static Future<ui.FragmentProgram> loadOcean() {
    return _ocean ??= ui.FragmentProgram.fromAsset(SceneryShaderAssets.ocean);
  }

  static Future<ui.FragmentProgram> loadCityLights() {
    return _cityLights ??= ui.FragmentProgram.fromAsset(
      SceneryShaderAssets.cityLights,
    );
  }

  @visibleForTesting
  static void reset() {
    _sky = null;
    _ocean = null;
    _cityLights = null;
  }
}

/// Writes an RGBA [color] into four consecutive shader floats starting at
/// [index]. The scenery painters use this to pack palette colors into their
/// fragment uniforms; it is local to the feature so the scenery module never
/// depends on the AI feature.
void setSceneryColor(ui.FragmentShader shader, int index, ui.Color color) {
  shader
    ..setFloat(index, color.r)
    ..setFloat(index + 1, color.g)
    ..setFloat(index + 2, color.b)
    ..setFloat(index + 3, color.a);
}
