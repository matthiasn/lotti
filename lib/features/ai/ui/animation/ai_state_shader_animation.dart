import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

part 'ai_thinking_line_shader.dart';
part 'ai_voice_input_shader.dart';

typedef AiShaderProgramLoader = Future<ui.FragmentProgram> Function();

enum AiVoiceShaderRoute {
  elasticMembrane,
  impactRipples,
  tensionLoop,
  liquidPulse,
  resonanceBraid,
}

extension AiVoiceShaderRouteLabel on AiVoiceShaderRoute {
  String get label {
    return switch (this) {
      AiVoiceShaderRoute.elasticMembrane => 'Elastic membrane',
      AiVoiceShaderRoute.impactRipples => 'Impact ripples',
      AiVoiceShaderRoute.tensionLoop => 'Tension loop',
      AiVoiceShaderRoute.liquidPulse => 'Liquid pulse',
      AiVoiceShaderRoute.resonanceBraid => 'Resonance braid',
    };
  }
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

abstract final class AiStateShaderProgramCache {
  static Future<ui.FragmentProgram>? _voiceInputProgram;
  static Future<ui.FragmentProgram>? _thinkingLineProgram;

  static Future<ui.FragmentProgram> loadVoiceInput() {
    return _voiceInputProgram ??= ui.FragmentProgram.fromAsset(
      AiStateShaderAssets.voiceInput,
    );
  }

  static Future<ui.FragmentProgram> loadThinkingLine() {
    return _thinkingLineProgram ??= ui.FragmentProgram.fromAsset(
      AiStateShaderAssets.thinkingLine,
    );
  }

  @visibleForTesting
  static void reset() {
    _voiceInputProgram = null;
    _thinkingLineProgram = null;
  }
}
