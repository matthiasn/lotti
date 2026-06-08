import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/ui/animation/ai_state_shader_animation.dart';
import 'ai_state_shader_animation_test_helpers.dart';

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

    testWidgets('cache returns the identical program for any call count', (
      tester,
    ) async {
      // Exhaustive over 2..9 calls per fresh cache — every call must return
      // the very same memoised object, not merely an equal one.
      for (var n = 2; n <= 9; n++) {
        AiStateShaderProgramCache.reset();
        final voice = [
          for (var i = 0; i < n; i++)
            await AiStateShaderProgramCache.loadVoiceInput(),
        ];
        final thinking = [
          for (var i = 0; i < n; i++)
            await AiStateShaderProgramCache.loadThinkingLine(),
        ];

        for (final program in voice.skip(1)) {
          expect(identical(program, voice.first), isTrue, reason: 'n=$n');
        }
        for (final program in thinking.skip(1)) {
          expect(identical(program, thinking.first), isTrue, reason: 'n=$n');
        }
      }
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
        TestSurface(
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
        hCustomPaintUnder<AiVoiceInputShader>(tester).painter,
        isA<AiVoiceInputShaderPainter>(),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('wraps output in Semantics with the provided label', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        const TestSurface(
          child: AiVoiceInputShader(
            dbfs: -24,
            size: 160,
            primaryColor: Color(0xFF63D7C7),
            secondaryColor: Color(0xFFE9EEF2),
            backgroundColor: Color(0x00000000),
            timeOverride: 1,
            programLoader: hFailingProgramLoader,
            semanticsLabel: 'Voice level indicator',
          ),
        ),
      );
      await tester.pump();

      expect(
        find.bySemanticsLabel('Voice level indicator'),
        findsOneWidget,
      );

      semantics.dispose();
    });

    testWidgets('renders a deterministic fallback when shader loading fails', (
      tester,
    ) async {
      await tester.pumpWidget(
        const TestSurface(
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
            programLoader: hFailingProgramLoader,
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
          TestSurface(
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
          TestSurface(
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

    testWidgets(
      'does not reload the program when programLoader is unchanged',
      (tester) async {
        var loadCount = 0;

        Future<ui.FragmentProgram> loader() {
          loadCount += 1;
          return Future<ui.FragmentProgram>.error(StateError('loader'));
        }

        Widget build({required double dbfs}) => TestSurface(
          child: AiVoiceInputShader(
            dbfs: dbfs,
            size: 120,
            primaryColor: const Color(0xFF63D7C7),
            secondaryColor: const Color(0xFFE9EEF2),
            backgroundColor: const Color(0x00000000),
            programLoader: loader,
          ),
        );

        await tester.pumpWidget(build(dbfs: -34));
        await tester.pump(const Duration(milliseconds: 16));

        // Same loader identity → didUpdateWidget must reuse the program.
        await tester.pumpWidget(build(dbfs: -20));
        await tester.pump(const Duration(milliseconds: 16));

        expect(loadCount, 1);
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
        TestSurface(
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
        hCustomPaintUnder<AiThinkingLineShader>(tester).painter,
        isA<AiThinkingLineShaderPainter>(),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders a deterministic fallback when shader loading fails', (
      tester,
    ) async {
      await tester.pumpWidget(
        const TestSurface(
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
            programLoader: hFailingProgramLoader,
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
          TestSurface(
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
          TestSurface(
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

    testWidgets(
      'does not reload the program when programLoader is unchanged',
      (tester) async {
        var loadCount = 0;

        Future<ui.FragmentProgram> loader() {
          loadCount += 1;
          return Future<ui.FragmentProgram>.error(StateError('loader'));
        }

        Widget build({required double width}) => TestSurface(
          child: AiThinkingLineShader(
            width: width,
            height: 72,
            primaryColor: const Color(0xFF63D7C7),
            secondaryColor: const Color(0xFFE9EEF2),
            backgroundColor: const Color(0x00000000),
            programLoader: loader,
          ),
        );

        await tester.pumpWidget(build(width: 320));
        await tester.pump(const Duration(milliseconds: 16));

        // Same loader identity → didUpdateWidget must reuse the program.
        await tester.pumpWidget(build(width: 280));
        await tester.pump(const Duration(milliseconds: 16));

        expect(loadCount, 1);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
