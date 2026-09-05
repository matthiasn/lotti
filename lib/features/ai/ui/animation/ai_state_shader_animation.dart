import 'dart:async';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

export 'package:lotti/features/ai/ui/animation/ai_thinking_line_shader.dart';
export 'package:lotti/features/ai/ui/animation/ai_voice_input_shader.dart';

typedef AiShaderProgramLoader = Future<ui.FragmentProgram> Function();

/// Writes an RGBA [color] into four consecutive shader floats starting
/// at [index]. Shared by the voice-input and thinking-line shader
/// painters so both encode colors into their fragment uniforms the
/// same way.
void aiSetShaderColor(ui.FragmentShader shader, int index, Color color) {
  shader
    ..setFloat(index, color.r)
    ..setFloat(index + 1, color.g)
    ..setFloat(index + 2, color.b)
    ..setFloat(index + 3, color.a);
}

enum AiThinkingShaderRoute {
  quietThread,
  packetScan,
  circuitTrace,
  probabilityBand,
  decoderBars,
}

extension AiThinkingShaderRouteLabel on AiThinkingShaderRoute {
  String get label {
    return switch (this) {
      AiThinkingShaderRoute.quietThread => 'Quiet thread',
      AiThinkingShaderRoute.packetScan => 'Packet scan',
      AiThinkingShaderRoute.circuitTrace => 'Circuit trace',
      AiThinkingShaderRoute.probabilityBand => 'Probability band',
      AiThinkingShaderRoute.decoderBars => 'Decoder bars',
    };
  }
}

@visibleForTesting
abstract final class AiStateShaderAssets {
  static const voiceInput = 'shaders/ai_voice_input.frag';
  static const thinkingLine = 'shaders/ai_thinking_line.frag';
}

/// Reuses compiled programs within one application or widget-test zone.
///
/// Flutter gives each `testWidgets` body its own zone and render context.
/// Scoping the cache the same way prevents a program compiled by one test
/// context from leaking into the next while production still compiles each
/// bundled shader only once.
abstract final class AiStateShaderProgramCache {
  static final _programsByZone = Expando<_AiStateShaderPrograms>();

  static _AiStateShaderPrograms get _programs =>
      _programsByZone[Zone.current] ??= _AiStateShaderPrograms();

  static Future<ui.FragmentProgram> loadVoiceInput() {
    return _programs.voiceInput ??= ui.FragmentProgram.fromAsset(
      AiStateShaderAssets.voiceInput,
    );
  }

  static Future<ui.FragmentProgram> loadThinkingLine() {
    return _programs.thinkingLine ??= ui.FragmentProgram.fromAsset(
      AiStateShaderAssets.thinkingLine,
    );
  }
}

final class _AiStateShaderPrograms {
  Future<ui.FragmentProgram>? voiceInput;
  Future<ui.FragmentProgram>? thinkingLine;
}
