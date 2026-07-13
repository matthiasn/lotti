import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

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

  /// Whether the GPU fragment shaders are used on this platform.
  ///
  /// Disabled on Linux: para-virtualized GPUs (e.g. virtio-gpu in VMs) have
  /// been observed to hang on these shaders' fragment loops, stalling the
  /// compositor's atomic commit on a DMA fence for minutes and freezing the
  /// entire desktop (kernel hung-task in `drm_atomic_helper_wait_for_fences`).
  /// When disabled, the loaders fail fast and the shader widgets render their
  /// CPU fallback painters (`AiVoiceInputFallbackPainter`,
  /// `AiThinkingLineFallbackPainter`) instead.
  static bool get shadersEnabled =>
      debugShadersEnabledOverride ?? !Platform.isLinux;

  /// Test-only override for [shadersEnabled]. Cleared by [reset].
  @visibleForTesting
  static bool? debugShadersEnabledOverride;

  static Future<ui.FragmentProgram> loadVoiceInput() {
    return _voiceInputProgram ??= _load(AiStateShaderAssets.voiceInput);
  }

  static Future<ui.FragmentProgram> loadThinkingLine() {
    return _thinkingLineProgram ??= _load(AiStateShaderAssets.thinkingLine);
  }

  static Future<ui.FragmentProgram> _load(String asset) {
    if (!shadersEnabled) {
      // ignore() marks the failure as handled so the memoised future never
      // surfaces as an unhandled async error; FutureBuilder listeners still
      // receive the error and switch to the CPU fallback painter.
      return Future<ui.FragmentProgram>.error(
        UnsupportedError('GPU fragment shaders are disabled on this platform'),
      )..ignore();
    }
    return ui.FragmentProgram.fromAsset(asset);
  }

  @visibleForTesting
  static void reset() {
    _voiceInputProgram = null;
    _thinkingLineProgram = null;
    debugShadersEnabledOverride = null;
  }
}
