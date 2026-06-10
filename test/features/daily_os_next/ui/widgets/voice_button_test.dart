import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/ui/animation/ai_state_shader_animation.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/voice_button.dart';

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
    expect(
      tester.getSize(find.byKey(VoiceButton.coreButtonKey)),
      const Size.square(buttonSize),
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

    AnimatedScale pressScale() => tester.widget<AnimatedScale>(
      find.byKey(VoiceButton.pressScaleKey),
    );

    expect(pressScale().scale, 1.0);

    final gesture = await tester.press(
      find.byKey(VoiceButton.coreButtonKey),
    );
    await tester.pump();
    expect(pressScale().scale, VoiceButton.pressedScale);

    await gesture.up();
    await tester.pump();
    expect(pressScale().scale, 1.0);
    // Let the release animation (with overshoot) finish cleanly.
    await tester.pump(const Duration(milliseconds: 300));
  });

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
