import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/ui/animation/ai_voice_input_shader.dart';

void main() {
  Future<void> pumpShader(
    WidgetTester tester, {
    required bool reducedMotion,
    double dbfs = -20,
  }) async {
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: const Size(800, 600),
          disableAnimations: reducedMotion,
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: AiVoiceInputShader(
              dbfs: dbfs,
              size: 120,
              primaryColor: const Color(0xFF00C2A8),
              secondaryColor: const Color(0xFFFFFFFF),
              backgroundColor: const Color(0x00000000),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  // The shader paints through a fragment program when one loads, else a CPU
  // fallback; both expose the animation `time`, which is what we assert on.
  double paintTime(WidgetTester tester) {
    final paint = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(AiVoiceInputShader),
        matching: find.byType(CustomPaint),
      ),
    );
    final painter = paint.painter;
    if (painter is AiVoiceInputFallbackPainter) return painter.time;
    if (painter is AiVoiceInputShaderPainter) return painter.time;
    throw StateError('unexpected painter: $painter');
  }

  testWidgets('with motion allowed the shader time advances with real time', (
    tester,
  ) async {
    await pumpShader(tester, reducedMotion: false);
    final t0 = paintTime(tester);

    await tester.pump(const Duration(seconds: 2));
    final t1 = paintTime(tester);

    // The continuous ticker drives the swirl forward.
    expect(t1, greaterThan(t0));

    // Unmount to stop the perpetual ticker so the test tears down cleanly.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('reduced motion holds the shader on a single static frame', (
    tester,
  ) async {
    await pumpShader(tester, reducedMotion: true);
    final t0 = paintTime(tester);

    await tester.pump(const Duration(seconds: 2));
    final t1 = paintTime(tester);

    // No clock-driven motion: the frame is pinned (and deterministic at 0), so
    // the listening visual is calm and static for a reduced-motion user — yet
    // it still renders (the orb does not disappear).
    expect(t1, t0);
    expect(t0, 0);
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
