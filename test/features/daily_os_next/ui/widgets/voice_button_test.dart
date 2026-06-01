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

  testWidgets('captured state swaps to the stop glyph and removes the shader', (
    tester,
  ) async {
    await pumpVoiceButton(tester, phase: CapturePhase.captured);

    expect(find.byType(AiVoiceInputShader), findsNothing);
    expect(find.byKey(VoiceButton.listeningFrameKey), findsNothing);
    expect(find.byKey(VoiceButton.restingFrameKey), findsNothing);
    expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
    expect(
      tester.getSize(find.byKey(VoiceButton.fieldKey)),
      Size.square(VoiceButton.fieldSizeFor(132)),
    );
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
}
