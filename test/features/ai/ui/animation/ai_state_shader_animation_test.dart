import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/ui/animation/ai_state_shader_animation.dart';

void main() {
  tearDown(AiStateShaderProgramCache.reset);

  group('AI state shader assets', () {
    test('are registered in pubspec.yaml', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();

      expect(pubspec, contains(AiStateShaderAssets.voiceInput));
      expect(pubspec, contains(AiStateShaderAssets.thinkingLine));
      expect(pubspec, contains('shaders:'));
    });

    testWidgets('compile as Flutter runtime-effect shaders', (tester) async {
      final voiceProgram = await ui.FragmentProgram.fromAsset(
        AiStateShaderAssets.voiceInput,
      );
      final thinkingProgram = await ui.FragmentProgram.fromAsset(
        AiStateShaderAssets.thinkingLine,
      );

      expect(voiceProgram, isA<ui.FragmentProgram>());
      expect(thinkingProgram, isA<ui.FragmentProgram>());
    });
  });

  group('AiVoiceInputShader', () {
    test('exposes five deformed-circle voice routes', () {
      expect(AiVoiceShaderRoute.values, hasLength(5));
      expect(AiVoiceShaderRoute.values.map((route) => route.label), [
        'Elastic membrane',
        'Impact ripples',
        'Tension loop',
        'Liquid pulse',
        'Resonance braid',
      ]);
    });

    test('defaults to the hotter tension loop route at production speed', () {
      const shader = AiVoiceInputShader(
        dbfs: -24,
        size: 160,
        primaryColor: Color(0xFF63D7C7),
        secondaryColor: Color(0xFFE9EEF2),
        backgroundColor: Color(0x00000000),
      );

      expect(shader.route, AiVoiceShaderRoute.tensionLoop);
      expect(shader.speed, 2);
    });

    testWidgets('renders a deterministic fallback when shader loading fails', (
      tester,
    ) async {
      await tester.pumpWidget(
        const _TestSurface(
          child: AiVoiceInputShader(
            dbfs: -24,
            size: 160,
            intensity: 0.8,
            lineDensity: 20,
            orbitalMix: 0.5,
            primaryColor: Color(0xFF63D7C7),
            secondaryColor: Color(0xFFE9EEF2),
            backgroundColor: Color(0x22000000),
            timeOverride: 1.5,
            programLoader: _failingProgramLoader,
          ),
        ),
      );
      await tester.pump();

      final customPaint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(AiVoiceInputShader),
          matching: find.byType(CustomPaint),
        ),
      );

      expect(customPaint.painter, isNotNull);
      expect(
        customPaint.painter!.runtimeType.toString(),
        contains('Fallback'),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('AiThinkingLineShader', () {
    testWidgets('renders a deterministic fallback when shader loading fails', (
      tester,
    ) async {
      await tester.pumpWidget(
        const _TestSurface(
          child: AiThinkingLineShader(
            width: 320,
            height: 72,
            speed: 0.9,
            amplitude: 0.6,
            randomness: 0.5,
            pulse: 0.4,
            primaryColor: Color(0xFF63D7C7),
            secondaryColor: Color(0xFFE9EEF2),
            backgroundColor: Color(0x22000000),
            timeOverride: 2,
            programLoader: _failingProgramLoader,
          ),
        ),
      );
      await tester.pump();

      final customPaint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(AiThinkingLineShader),
          matching: find.byType(CustomPaint),
        ),
      );

      expect(customPaint.painter, isNotNull);
      expect(
        customPaint.painter!.runtimeType.toString(),
        contains('Fallback'),
      );
      expect(tester.takeException(), isNull);
    });
  });
}

Future<ui.FragmentProgram> _failingProgramLoader() {
  return Future<ui.FragmentProgram>.error(StateError('shader unavailable'));
}

class _TestSurface extends StatelessWidget {
  const _TestSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(child: child),
      ),
    );
  }
}
