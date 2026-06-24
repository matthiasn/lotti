import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/ui/animation/ai_state_shader_animation.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/voice_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../test_helper.dart';

void main() {
  Future<void> pumpVoiceButton(
    WidgetTester tester, {
    CapturePhase phase = CapturePhase.idle,
    double size = 132,
    double dbfs = CaptureState.defaultDbfs,
    double dbfsFloor = CaptureState.defaultDbfs,
    VoidCallback? onTap,
  }) async {
    await tester.pumpWidget(
      WidgetTestBench(
        child: Center(
          child: VoiceButton(
            phase: phase,
            dbfs: dbfs,
            dbfsFloor: dbfsFloor,
            size: size,
            semanticLabel: 'Record voice',
            onTap: onTap ?? () {},
          ),
        ),
      ),
    );
  }

  testWidgets('idle state renders the mic button without a shader ticker', (
    tester,
  ) async {
    await pumpVoiceButton(tester);

    expect(find.byType(AiVoiceInputShader), findsNothing);
    expect(find.byKey(VoiceButton.listeningFrameKey), findsNothing);
    expect(find.byKey(VoiceButton.restingFrameKey), findsOneWidget);
    expect(find.byIcon(MdiIcons.microphone), findsOneWidget);
    expect(
      tester.getSize(find.byKey(VoiceButton.restingFrameKey)),
      Size.square(VoiceButton.restingFrameSizeFor(132)),
    );
    expect(
      tester.getSize(find.byKey(VoiceButton.fieldKey)),
      Size.square(VoiceButton.fieldSizeFor(132)),
    );
    expect(
      tester.getSize(find.byKey(VoiceButton.coreButtonKey)),
      const Size.square(132),
    );
  });

  testWidgets('listening state wraps the button in the dBFS tension loop', (
    tester,
  ) async {
    const buttonSize = 88.0;

    await pumpVoiceButton(
      tester,
      phase: CapturePhase.listening,
      size: buttonSize,
      dbfs: -18,
      dbfsFloor: -72,
    );

    final shaderFinder = find.byType(AiVoiceInputShader);
    final shader = tester.widget<AiVoiceInputShader>(shaderFinder);
    expect(shader.route, AiVoiceShaderRoute.tensionLoop);
    expect(shader.dbfs, -18);
    expect(shader.dbfsFloor, -72);
    expect(shader.size, VoiceButton.shaderSizeFor(buttonSize));
    expect(shader.size, greaterThan(VoiceButton.fieldSizeFor(buttonSize)));
    expect(shader.speed, 2);
    expect(shader.intensity, 0.84);
    expect(shader.lineDensity, 24);
    expect(shader.orbitalMix, 0.60);
    expect(shader.backgroundColor, Colors.transparent);
    expect(
      tester
          .widget<ClipPath>(
            find.ancestor(of: shaderFinder, matching: find.byType(ClipPath)),
          )
          .clipper,
      isA<CustomClipper<Path>>(),
    );
    expect(
      tester.getSize(find.byKey(VoiceButton.listeningFrameKey)),
      Size.square(VoiceButton.listeningFrameSizeFor(buttonSize)),
    );
    expect(find.byKey(VoiceButton.restingFrameKey), findsNothing);
    expect(
      tester.getSize(find.byKey(VoiceButton.fieldKey)),
      Size.square(VoiceButton.fieldSizeFor(buttonSize)),
    );
    expect(
      VoiceButton.shaderHoleSizeFor(buttonSize),
      greaterThan(buttonSize),
    );
    expect(
      VoiceButton.listeningFrameSizeFor(buttonSize),
      greaterThan(VoiceButton.shaderHoleSizeFor(buttonSize)),
    );
    // While listening the core rests back inside the field and swells
    // with the voice: −18 dBFS over the −72 floor → norm 0.75, with the
    // slow idle breath (±listeningIdleBreath) riding on top.
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester.getSize(find.byKey(VoiceButton.coreButtonKey)).width,
      closeTo(
        buttonSize *
            (VoiceButton.listeningCoreScale +
                VoiceButton.listeningBreathSpan * 0.75),
        buttonSize * VoiceButton.listeningIdleBreath + 0.01,
      ),
    );
  });

  testWidgets(
    'listening state shows the stop glyph (tap = stop recording)',
    (tester) async {
      await pumpVoiceButton(tester, phase: CapturePhase.listening);

      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      expect(find.byIcon(MdiIcons.microphone), findsNothing);
    },
  );

  testWidgets(
    'listening inverts the stop mark: teal glyph, no filled disc',
    (tester) async {
      await pumpVoiceButton(tester, phase: CapturePhase.listening);

      final tokens = tester.element(find.byType(VoiceButton)).designTokens;
      final teal = tokens.colors.interactive.enabled;

      // The stop square is drawn in the orb's own teal (inverted), not the
      // light on-interactive color it used to punch out of the disc, and at
      // roughly double the mic glyph since there is no disc to sit inside.
      final stopIcon = tester.widget<Icon>(find.byIcon(Icons.stop_rounded));
      expect(stopIcon.color, teal);
      expect(stopIcon.color, isNot(tokens.colors.text.onInteractiveAlert));
      expect(stopIcon.size, 132 * 0.76);

      // The filled disc is gone: the core decoration has no fill and no
      // shadow while listening — just the teal square sits in the field.
      final decoration =
          tester
                  .widget<Ink>(
                    find.ancestor(
                      of: find.byKey(VoiceButton.coreButtonKey),
                      matching: find.byType(Ink),
                    ),
                  )
                  .decoration!
              as BoxDecoration;
      expect(decoration.color, isNull);
      expect(decoration.boxShadow, isNull);

      // Idle keeps the solid teal disc, so the inversion is scoped to
      // listening rather than flattening the orb everywhere.
      await pumpVoiceButton(tester);
      final idleDecoration =
          tester
                  .widget<Ink>(
                    find.ancestor(
                      of: find.byKey(VoiceButton.coreButtonKey),
                      matching: find.byType(Ink),
                    ),
                  )
                  .decoration!
              as BoxDecoration;
      expect(idleDecoration.color, teal);
    },
  );

  testWidgets(
    'captured state returns to the mic glyph and removes the shader',
    (tester) async {
      await pumpVoiceButton(tester, phase: CapturePhase.captured);

      expect(find.byType(AiVoiceInputShader), findsNothing);
      expect(find.byKey(VoiceButton.listeningFrameKey), findsNothing);
      expect(find.byKey(VoiceButton.restingFrameKey), findsNothing);
      // Tap re-records, so the glyph advertises talking — not "stop".
      expect(find.byIcon(MdiIcons.microphone), findsOneWidget);
      expect(find.byIcon(Icons.stop_rounded), findsNothing);
      expect(
        tester.getSize(find.byKey(VoiceButton.fieldKey)),
        Size.square(VoiceButton.fieldSizeFor(132)),
      );
    },
  );

  testWidgets('transcribing state dims the core button', (tester) async {
    await pumpVoiceButton(tester, phase: CapturePhase.transcribing);

    final opacity = tester.widget<AnimatedOpacity>(
      find
          .ancestor(
            of: find.byKey(VoiceButton.coreButtonKey),
            matching: find.byType(AnimatedOpacity),
          )
          .first,
    );
    expect(opacity.opacity, lessThan(1));
  });

  testWidgets('tap delegates to the supplied callback', (tester) async {
    var taps = 0;

    await pumpVoiceButton(
      tester,
      onTap: () => taps += 1,
    );
    await tester.tap(find.byType(InkWell));

    expect(taps, 1);
  });

  testWidgets('press feedback scales the core down and back up', (
    tester,
  ) async {
    await pumpVoiceButton(tester);

    double scaleTarget() => tester
        .widget<TweenAnimationBuilder<double>>(
          find.byKey(VoiceButton.pressScaleKey),
        )
        .tween
        .end!;

    expect(scaleTarget(), 1.0);

    final gesture = await tester.press(
      find.byKey(VoiceButton.coreButtonKey),
    );
    await tester.pump();
    expect(scaleTarget(), VoiceButton.pressedScale);

    await gesture.up();
    await tester.pump();
    expect(scaleTarget(), 1.0);
    // Let the release animation (with overshoot) finish cleanly.
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets(
    'while listening the core breathes with the voice level: rests '
    'smaller at silence, swells with dBFS, full size in other phases',
    (tester) async {
      double scaleTarget() => tester
          .widget<TweenAnimationBuilder<double>>(
            find.byKey(VoiceButton.pressScaleKey),
          )
          .tween
          .end!;

      // Silence (dbfs == floor): the disc rests at the listening scale so
      // the shader owns the field. (The slow idle-breath sine multiplies
      // in OUTSIDE this tween, so the target stays exact.)
      await pumpVoiceButton(tester, phase: CapturePhase.listening);
      expect(scaleTarget(), VoiceButton.listeningCoreScale);

      // Loud speech (-8 dBFS over the -80 floor → norm 0.9): the disc
      // swells with the same signal that drives the shader.
      await pumpVoiceButton(
        tester,
        phase: CapturePhase.listening,
        dbfs: -8,
      );
      expect(
        scaleTarget(),
        closeTo(
          VoiceButton.listeningCoreScale +
              VoiceButton.listeningBreathSpan * 0.9,
          1e-9,
        ),
      );

      // Outside listening the breathing is inert and the ticker stops.
      await pumpVoiceButton(tester, phase: CapturePhase.captured);
      expect(scaleTarget(), 1.0);
      await tester.pump(const Duration(milliseconds: 300));
    },
  );

  testWidgets(
    'reduced motion: the listening orb settles (no perpetual ticker) yet the '
    'core still tracks the live voice level',
    (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(800, 600),
              disableAnimations: true,
            ),
            child: Center(
              child: VoiceButton(
                phase: CapturePhase.listening,
                dbfs: -8,
                size: 132,
                semanticLabel: 'Record voice',
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      // With reduced motion BOTH the idle-breath ticker and the shader's time
      // ticker are held still, so the listening frame has no perpetual
      // animation: pumpAndSettle returns instead of timing out.
      await tester.pumpAndSettle();

      // The voice field is still mounted (it just no longer swirls) and the
      // core still rests at the dBFS-driven scale — direct feedback is kept,
      // only the decorative motion is dropped.
      expect(find.byType(AiVoiceInputShader), findsOneWidget);
      final scaleEnd = tester
          .widget<TweenAnimationBuilder<double>>(
            find.byKey(VoiceButton.pressScaleKey),
          )
          .tween
          .end!;
      expect(
        scaleEnd,
        closeTo(
          VoiceButton.listeningCoreScale +
              VoiceButton.listeningBreathSpan * 0.9,
          1e-9,
        ),
      );
    },
  );

  testWidgets('ink ripple is configured above the gradient surface', (
    tester,
  ) async {
    await pumpVoiceButton(tester);

    final inkWell = tester.widget<InkWell>(
      find.byKey(VoiceButton.coreButtonKey),
    );
    // The splash must be explicit and visible — the old design painted the
    // ripple beneath an opaque gradient container, which read as a dead
    // button.
    expect(inkWell.splashColor, isNotNull);
    expect(inkWell.splashColor!.a, greaterThan(0));
    final ink = tester.widget<Ink>(
      find.ancestor(
        of: find.byKey(VoiceButton.coreButtonKey),
        matching: find.byType(Ink),
      ),
    );
    expect(ink.decoration, isA<BoxDecoration>());
  });
}
