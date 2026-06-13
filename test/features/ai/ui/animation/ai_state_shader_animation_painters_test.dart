import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai/ui/animation/ai_state_shader_animation.dart';
import 'ai_state_shader_animation_test_helpers.dart';

void main() {
  tearDown(AiStateShaderProgramCache.reset);

  group('AI state shader painters', () {
    // One shared load per program instead of per-test asset reads.
    late ui.FragmentProgram voiceProgram;
    late ui.FragmentProgram thinkingProgram;

    setUpAll(() async {
      voiceProgram = await ui.FragmentProgram.fromAsset(
        AiStateShaderAssets.voiceInput,
      );
      thinkingProgram = await ui.FragmentProgram.fromAsset(
        AiStateShaderAssets.thinkingLine,
      );
    });

    testWidgets('paint voice shader and compare repaint inputs', (
      _,
    ) async {
      final painter = AiVoiceInputShaderPainter(
        program: voiceProgram,
        dbfs: -18,
        dbfsFloor: -80,
        time: 1.4,
        intensity: 0.9,
        lineDensity: 24,
        orbitalMix: 0.55,
        route: AiVoiceShaderRoute.tensionLoop,
        primaryColor: const Color(0xFF63D7C7),
        secondaryColor: const Color(0xFFE9EEF2),
        backgroundColor: const Color(0x00000000),
      );
      final samePainter = AiVoiceInputShaderPainter(
        program: voiceProgram,
        dbfs: -18,
        dbfsFloor: -80,
        time: 1.4,
        intensity: 0.9,
        lineDensity: 24,
        orbitalMix: 0.55,
        route: AiVoiceShaderRoute.tensionLoop,
        primaryColor: const Color(0xFF63D7C7),
        secondaryColor: const Color(0xFFE9EEF2),
        backgroundColor: const Color(0x00000000),
      );
      final changedPainter = AiVoiceInputShaderPainter(
        program: voiceProgram,
        dbfs: -12,
        dbfsFloor: -80,
        time: 1.4,
        intensity: 0.9,
        lineDensity: 24,
        orbitalMix: 0.55,
        route: AiVoiceShaderRoute.tensionLoop,
        primaryColor: const Color(0xFF63D7C7),
        secondaryColor: const Color(0xFFE9EEF2),
        backgroundColor: const Color(0x00000000),
      );

      hPaintWith(painter, const Size(96, 96));

      expect(samePainter.shouldRepaint(painter), isFalse);
      expect(changedPainter.shouldRepaint(painter), isTrue);
    });

    testWidgets('paint thinking shader and compare repaint inputs', (
      _,
    ) async {
      final painter = AiThinkingLineShaderPainter(
        program: thinkingProgram,
        time: 2,
        speed: 2.3,
        amplitude: 0.7,
        randomness: 0.9,
        lineCount: 5,
        pulse: 0.6,
        route: AiThinkingShaderRoute.decoderBars,
        primaryColor: const Color(0xFF63D7C7),
        secondaryColor: const Color(0xFFE9EEF2),
        backgroundColor: const Color(0x00000000),
      );
      final samePainter = AiThinkingLineShaderPainter(
        program: thinkingProgram,
        time: 2,
        speed: 2.3,
        amplitude: 0.7,
        randomness: 0.9,
        lineCount: 5,
        pulse: 0.6,
        route: AiThinkingShaderRoute.decoderBars,
        primaryColor: const Color(0xFF63D7C7),
        secondaryColor: const Color(0xFFE9EEF2),
        backgroundColor: const Color(0x00000000),
      );
      final changedPainter = AiThinkingLineShaderPainter(
        program: thinkingProgram,
        time: 3,
        speed: 2.3,
        amplitude: 0.7,
        randomness: 0.9,
        lineCount: 5,
        pulse: 0.6,
        route: AiThinkingShaderRoute.decoderBars,
        primaryColor: const Color(0xFF63D7C7),
        secondaryColor: const Color(0xFFE9EEF2),
        backgroundColor: const Color(0x00000000),
      );
      final changedOpacityPainter = AiThinkingLineShaderPainter(
        program: thinkingProgram,
        time: 2,
        speed: 2.3,
        amplitude: 0.7,
        randomness: 0.9,
        lineCount: 5,
        pulse: 0.6,
        opacity: 0.5,
        route: AiThinkingShaderRoute.decoderBars,
        primaryColor: const Color(0xFF63D7C7),
        secondaryColor: const Color(0xFFE9EEF2),
        backgroundColor: const Color(0x00000000),
      );

      hPaintWith(painter, const Size(320, 72));

      expect(samePainter.shouldRepaint(painter), isFalse);
      expect(changedPainter.shouldRepaint(painter), isTrue);
      expect(changedOpacityPainter.shouldRepaint(painter), isTrue);
    });

    testWidgets('changing only the shader route forces a repaint', (
      _,
    ) async {
      // The route selects a different visual program branch inside the shader,
      // so two painters that differ in nothing but their route must repaint.
      AiVoiceInputShaderPainter voice(AiVoiceShaderRoute route) =>
          AiVoiceInputShaderPainter(
            program: voiceProgram,
            dbfs: -18,
            dbfsFloor: -80,
            time: 1.4,
            intensity: 0.9,
            lineDensity: 24,
            orbitalMix: 0.55,
            route: route,
            primaryColor: const Color(0xFF63D7C7),
            secondaryColor: const Color(0xFFE9EEF2),
            backgroundColor: const Color(0x00000000),
          );
      AiThinkingLineShaderPainter thinking(AiThinkingShaderRoute route) =>
          AiThinkingLineShaderPainter(
            program: thinkingProgram,
            time: 2,
            speed: 2.3,
            amplitude: 0.7,
            randomness: 0.9,
            lineCount: 5,
            pulse: 0.6,
            route: route,
            primaryColor: const Color(0xFF63D7C7),
            secondaryColor: const Color(0xFFE9EEF2),
            backgroundColor: const Color(0x00000000),
          );

      for (final route in AiVoiceShaderRoute.values) {
        final other = AiVoiceShaderRoute
            .values[(route.index + 1) % AiVoiceShaderRoute.values.length];
        expect(
          voice(route).shouldRepaint(voice(other)),
          isTrue,
          reason: 'voice $route vs $other must repaint',
        );
        expect(
          voice(route).shouldRepaint(voice(route)),
          isFalse,
          reason: 'voice $route vs itself must not repaint',
        );
      }

      for (final route in AiThinkingShaderRoute.values) {
        final other = AiThinkingShaderRoute
            .values[(route.index + 1) % AiThinkingShaderRoute.values.length];
        expect(
          thinking(route).shouldRepaint(thinking(other)),
          isTrue,
          reason: 'thinking $route vs $other must repaint',
        );
        expect(
          thinking(route).shouldRepaint(thinking(route)),
          isFalse,
          reason: 'thinking $route vs itself must not repaint',
        );
      }
    });

    test('paint fallback painters and compare repaint inputs', () {
      final voicePainter = AiVoiceInputFallbackPainter(
        dbfs: -22,
        dbfsFloor: -80,
        time: 1.1,
        intensity: 0.8,
        lineDensity: 20,
        orbitalMix: 0.5,
        route: AiVoiceShaderRoute.elasticMembrane,
        primaryColor: const Color(0xFF63D7C7),
        secondaryColor: const Color(0xFFE9EEF2),
        backgroundColor: const Color(0x11000000),
      );
      final sameVoicePainter = AiVoiceInputFallbackPainter(
        dbfs: -22,
        dbfsFloor: -80,
        time: 1.1,
        intensity: 0.8,
        lineDensity: 20,
        orbitalMix: 0.5,
        route: AiVoiceShaderRoute.elasticMembrane,
        primaryColor: const Color(0xFF63D7C7),
        secondaryColor: const Color(0xFFE9EEF2),
        backgroundColor: const Color(0x11000000),
      );
      final changedVoicePainter = AiVoiceInputFallbackPainter(
        dbfs: -22,
        dbfsFloor: -60,
        time: 1.1,
        intensity: 0.8,
        lineDensity: 20,
        orbitalMix: 0.5,
        route: AiVoiceShaderRoute.elasticMembrane,
        primaryColor: const Color(0xFF63D7C7),
        secondaryColor: const Color(0xFFE9EEF2),
        backgroundColor: const Color(0x11000000),
      );
      final thinkingPainter = AiThinkingLineFallbackPainter(
        time: 1.4,
        speed: 2.3,
        amplitude: 0.7,
        randomness: 0.9,
        lineCount: 9,
        pulse: 0.6,
        route: AiThinkingShaderRoute.decoderBars,
        primaryColor: const Color(0xFF63D7C7),
        secondaryColor: const Color(0xFFE9EEF2),
        backgroundColor: const Color(0x11000000),
      );
      final singleLineThinkingPainter = AiThinkingLineFallbackPainter(
        time: 1.4,
        speed: 2.3,
        amplitude: 0.7,
        randomness: 0.9,
        lineCount: 1,
        pulse: 0.6,
        route: AiThinkingShaderRoute.decoderBars,
        primaryColor: const Color(0xFF63D7C7),
        secondaryColor: const Color(0xFFE9EEF2),
        backgroundColor: const Color(0x00000000),
      );
      final sameThinkingPainter = AiThinkingLineFallbackPainter(
        time: 1.4,
        speed: 2.3,
        amplitude: 0.7,
        randomness: 0.9,
        lineCount: 9,
        pulse: 0.6,
        route: AiThinkingShaderRoute.decoderBars,
        primaryColor: const Color(0xFF63D7C7),
        secondaryColor: const Color(0xFFE9EEF2),
        backgroundColor: const Color(0x11000000),
      );
      final changedThinkingPainter = AiThinkingLineFallbackPainter(
        time: 1.4,
        speed: 2.3,
        amplitude: 0.7,
        randomness: 0.5,
        lineCount: 9,
        pulse: 0.6,
        route: AiThinkingShaderRoute.decoderBars,
        primaryColor: const Color(0xFF63D7C7),
        secondaryColor: const Color(0xFFE9EEF2),
        backgroundColor: const Color(0x11000000),
      );
      final changedOpacityThinkingPainter = AiThinkingLineFallbackPainter(
        time: 1.4,
        speed: 2.3,
        amplitude: 0.7,
        randomness: 0.9,
        lineCount: 9,
        pulse: 0.6,
        opacity: 0.5,
        route: AiThinkingShaderRoute.decoderBars,
        primaryColor: const Color(0xFF63D7C7),
        secondaryColor: const Color(0xFFE9EEF2),
        backgroundColor: const Color(0x11000000),
      );

      hPaintWith(voicePainter, const Size(96, 96));
      hPaintWith(thinkingPainter, const Size(320, 72));
      hPaintWith(singleLineThinkingPainter, const Size(320, 72));

      expect(sameVoicePainter.shouldRepaint(voicePainter), isFalse);
      expect(changedVoicePainter.shouldRepaint(voicePainter), isTrue);
      expect(sameThinkingPainter.shouldRepaint(thinkingPainter), isFalse);
      expect(changedThinkingPainter.shouldRepaint(thinkingPainter), isTrue);
      expect(
        changedOpacityThinkingPainter.shouldRepaint(thinkingPainter),
        isTrue,
      );
    });
  });

  group('shouldRepaint properties', () {
    late ui.FragmentProgram voiceProgram;
    late ui.FragmentProgram thinkingProgram;

    setUpAll(() async {
      voiceProgram = await ui.FragmentProgram.fromAsset(
        AiStateShaderAssets.voiceInput,
      );
      thinkingProgram = await ui.FragmentProgram.fromAsset(
        AiStateShaderAssets.thinkingLine,
      );
    });

    AiVoiceInputShaderPainter voicePainter({
      required int seed,
      int? bumpField,
    }) {
      // Field i gets a deterministic base value from the seed; bumpField
      // (when set) perturbs exactly that field.
      double f(int i) => (seed % 97) + i + (bumpField == i ? 0.5 : 0.0);
      Color c(int i) => Color(
        0xFF000000 |
            ((((seed + i) * 2654435761) & 0x00FFFFFF) ^
                (bumpField == i ? 1 : 0)),
      );
      return AiVoiceInputShaderPainter(
        program: voiceProgram,
        dbfs: f(0),
        dbfsFloor: f(1),
        time: f(2),
        intensity: f(3),
        lineDensity: f(4),
        orbitalMix: f(5),
        route:
            AiVoiceShaderRoute.values[(seed + (bumpField == 6 ? 1 : 0)) %
                AiVoiceShaderRoute.values.length],
        primaryColor: c(7),
        secondaryColor: c(8),
        backgroundColor: c(9),
      );
    }

    AiThinkingLineShaderPainter thinkingPainter({
      required int seed,
      int? bumpField,
    }) {
      double f(int i) => (seed % 89) + i + (bumpField == i ? 0.5 : 0.0);
      Color c(int i) => Color(
        0xFF000000 |
            ((((seed + i) * 2654435761) & 0x00FFFFFF) ^
                (bumpField == i ? 1 : 0)),
      );
      return AiThinkingLineShaderPainter(
        program: thinkingProgram,
        time: f(0),
        speed: f(1),
        amplitude: f(2),
        randomness: f(3),
        lineCount: (seed % 7) + 1 + (bumpField == 4 ? 1 : 0),
        pulse: f(5),
        opacity: (seed.isEven ? 0.5 : 1.0) - (bumpField == 6 ? 0.1 : 0.0),
        route:
            AiThinkingShaderRoute.values[(seed + (bumpField == 7 ? 1 : 0)) %
                AiThinkingShaderRoute.values.length],
        primaryColor: c(8),
        secondaryColor: c(9),
        backgroundColor: c(10),
      );
    }

    glados.Glados2<int, int>(
      glados.IntAnys(glados.any).intInRange(0, 1 << 16),
      glados.IntAnys(glados.any).intInRange(0, 10),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'voice painter repaints iff any field differs',
      (seed, field) {
        final base = voicePainter(seed: seed);
        final equal = voicePainter(seed: seed);
        expect(
          base.shouldRepaint(equal),
          isFalse,
          reason: 'identical fields must not repaint (seed=$seed)',
        );

        final bumped = voicePainter(seed: seed, bumpField: field);
        expect(
          base.shouldRepaint(bumped),
          isTrue,
          reason: 'field $field changed (seed=$seed)',
        );
      },
      tags: 'glados',
    );

    glados.Glados2<int, int>(
      glados.IntAnys(glados.any).intInRange(0, 1 << 16),
      glados.IntAnys(glados.any).intInRange(0, 11),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'thinking painter repaints iff any field differs',
      (seed, field) {
        final base = thinkingPainter(seed: seed);
        final equal = thinkingPainter(seed: seed);
        expect(
          base.shouldRepaint(equal),
          isFalse,
          reason: 'identical fields must not repaint (seed=$seed)',
        );

        final bumped = thinkingPainter(seed: seed, bumpField: field);
        expect(
          base.shouldRepaint(bumped),
          isTrue,
          reason: 'field $field changed (seed=$seed)',
        );
      },
      tags: 'glados',
    );
  });
}
