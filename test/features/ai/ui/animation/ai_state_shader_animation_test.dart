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

    testWidgets('cache loads and reuses runtime-effect programs', (
      tester,
    ) async {
      final firstVoiceProgram =
          await AiStateShaderProgramCache.loadVoiceInput();
      final secondVoiceProgram =
          await AiStateShaderProgramCache.loadVoiceInput();
      final firstThinkingProgram =
          await AiStateShaderProgramCache.loadThinkingLine();
      final secondThinkingProgram =
          await AiStateShaderProgramCache.loadThinkingLine();

      expect(identical(firstVoiceProgram, secondVoiceProgram), isTrue);
      expect(identical(firstThinkingProgram, secondThinkingProgram), isTrue);
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

    testWidgets('renders shader-backed painter when the program loads', (
      tester,
    ) async {
      final program = await ui.FragmentProgram.fromAsset(
        AiStateShaderAssets.voiceInput,
      );

      await tester.pumpWidget(
        _TestSurface(
          child: AiVoiceInputShader(
            dbfs: -18,
            size: 160,
            intensity: 0.9,
            lineDensity: 24,
            orbitalMix: 0.6,
            route: AiVoiceShaderRoute.resonanceBraid,
            primaryColor: const Color(0xFF63D7C7),
            secondaryColor: const Color(0xFFE9EEF2),
            backgroundColor: const Color(0x00000000),
            timeOverride: 1.25,
            programLoader: () async => program,
          ),
        ),
      );
      await tester.pump();

      expect(
        _customPaintUnder<AiVoiceInputShader>(tester).painter,
        isA<AiVoiceInputShaderPainter>(),
      );
      expect(tester.takeException(), isNull);
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
      expect(customPaint.painter, isA<AiVoiceInputFallbackPainter>());
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'reloads programs and stops animation when time override is set',
      (tester) async {
        var loadCount = 0;

        Future<ui.FragmentProgram> firstLoader() {
          loadCount += 1;
          return Future<ui.FragmentProgram>.error(StateError('first'));
        }

        Future<ui.FragmentProgram> secondLoader() {
          loadCount += 1;
          return Future<ui.FragmentProgram>.error(StateError('second'));
        }

        await tester.pumpWidget(
          _TestSurface(
            child: AiVoiceInputShader(
              dbfs: -34,
              size: 120,
              primaryColor: const Color(0xFF63D7C7),
              secondaryColor: const Color(0xFFE9EEF2),
              backgroundColor: const Color(0x00000000),
              programLoader: firstLoader,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 16));

        await tester.pumpWidget(
          _TestSurface(
            child: AiVoiceInputShader(
              dbfs: -28,
              size: 120,
              primaryColor: const Color(0xFF63D7C7),
              secondaryColor: const Color(0xFFE9EEF2),
              backgroundColor: const Color(0x00000000),
              timeOverride: 2,
              programLoader: secondLoader,
            ),
          ),
        );
        await tester.pump();

        expect(loadCount, 2);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('AiThinkingLineShader', () {
    test('exposes five horizontal thinking routes', () {
      expect(AiThinkingShaderRoute.values, hasLength(5));
      expect(AiThinkingShaderRoute.values.map((route) => route.label), [
        'Quiet thread',
        'Packet scan',
        'Circuit trace',
        'Probability band',
        'Decoder bars',
      ]);
    });

    testWidgets('renders shader-backed painter when the program loads', (
      tester,
    ) async {
      final program = await ui.FragmentProgram.fromAsset(
        AiStateShaderAssets.thinkingLine,
      );

      await tester.pumpWidget(
        _TestSurface(
          child: AiThinkingLineShader(
            width: 320,
            height: 72,
            speed: 2.3,
            amplitude: 0.7,
            randomness: 0.9,
            lineCount: 5,
            pulse: 0.6,
            primaryColor: const Color(0xFF63D7C7),
            secondaryColor: const Color(0xFFE9EEF2),
            backgroundColor: const Color(0x00000000),
            timeOverride: 2,
            programLoader: () async => program,
          ),
        ),
      );
      await tester.pump();

      expect(
        _customPaintUnder<AiThinkingLineShader>(tester).painter,
        isA<AiThinkingLineShaderPainter>(),
      );
      expect(tester.takeException(), isNull);
    });

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
      expect(customPaint.painter, isA<AiThinkingLineFallbackPainter>());
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'reloads programs and stops animation when time override is set',
      (tester) async {
        var loadCount = 0;

        Future<ui.FragmentProgram> firstLoader() {
          loadCount += 1;
          return Future<ui.FragmentProgram>.error(StateError('first'));
        }

        Future<ui.FragmentProgram> secondLoader() {
          loadCount += 1;
          return Future<ui.FragmentProgram>.error(StateError('second'));
        }

        await tester.pumpWidget(
          _TestSurface(
            child: AiThinkingLineShader(
              width: 320,
              height: 72,
              primaryColor: const Color(0xFF63D7C7),
              secondaryColor: const Color(0xFFE9EEF2),
              backgroundColor: const Color(0x00000000),
              programLoader: firstLoader,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 16));

        await tester.pumpWidget(
          _TestSurface(
            child: AiThinkingLineShader(
              width: 320,
              height: 72,
              primaryColor: const Color(0xFF63D7C7),
              secondaryColor: const Color(0xFFE9EEF2),
              backgroundColor: const Color(0x00000000),
              timeOverride: 2,
              programLoader: secondLoader,
            ),
          ),
        );
        await tester.pump();

        expect(loadCount, 2);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('AI state shader painters', () {
    testWidgets('paint voice shader and compare repaint inputs', (
      _,
    ) async {
      final program = await ui.FragmentProgram.fromAsset(
        AiStateShaderAssets.voiceInput,
      );
      final painter = AiVoiceInputShaderPainter(
        program: program,
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
        program: program,
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
        program: program,
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

      _paintWith(painter, const Size(96, 96));

      expect(samePainter.shouldRepaint(painter), isFalse);
      expect(changedPainter.shouldRepaint(painter), isTrue);
    });

    testWidgets('paint thinking shader and compare repaint inputs', (
      _,
    ) async {
      final program = await ui.FragmentProgram.fromAsset(
        AiStateShaderAssets.thinkingLine,
      );
      final painter = AiThinkingLineShaderPainter(
        program: program,
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
        program: program,
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
        program: program,
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
        program: program,
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

      _paintWith(painter, const Size(320, 72));

      expect(samePainter.shouldRepaint(painter), isFalse);
      expect(changedPainter.shouldRepaint(painter), isTrue);
      expect(changedOpacityPainter.shouldRepaint(painter), isTrue);
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

      _paintWith(voicePainter, const Size(96, 96));
      _paintWith(thinkingPainter, const Size(320, 72));
      _paintWith(singleLineThinkingPainter, const Size(320, 72));

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
}

Future<ui.FragmentProgram> _failingProgramLoader() {
  return Future<ui.FragmentProgram>.error(StateError('shader unavailable'));
}

CustomPaint _customPaintUnder<T extends Widget>(WidgetTester tester) {
  return tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(T),
      matching: find.byType(CustomPaint),
    ),
  );
}

void _paintWith(CustomPainter painter, Size size) {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  painter.paint(canvas, size);
  recorder.endRecording().dispose();
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
