import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/ui/animation/ai_thinking_line_shader.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/voice_button.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/voice_orb_zone.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_capture_view.dart';

import '../../../../widget_test_utils.dart';

void main() {
  const accent = Color(0xFF00C2A8);

  var orbTaps = 0;
  var ratherTypeTaps = 0;

  // Reduced motion so the orb breath / shimmer tickers settle instead of
  // pumping forever, and a bounded surface for the Column + Spacers.
  Future<void> pumpView(
    WidgetTester tester,
    OnboardingCapturePhase phase,
  ) async {
    await tester.pumpWidget(
      makeTestableWidget(
        SizedBox(
          width: 390,
          height: 844,
          child: OnboardingCaptureView(
            phase: phase,
            accent: accent,
            promptHeadline: "What's on your mind?",
            promptHint: 'Try: a quick errand',
            listeningCaption: 'Tap when done',
            thinkingHeadline: 'Building your task',
            thinkingReassurance: 'You can edit everything next',
            ratherTypeLabel: 'Rather type?',
            orbSemanticLabel: 'Record',
            transcript: 'call the dentist and book the car service',
            amplitudes: const [0.2, 0.6, 0.4, 0.8, 0.3],
            onOrbTap: () => orbTaps++,
            onRatherType: () => ratherTypeTaps++,
          ),
        ),
        mediaQueryData: const MediaQueryData(
          size: Size(390, 844),
          disableAnimations: true,
        ),
      ),
    );
    await tester.pump();
  }

  setUp(() {
    orbTaps = 0;
    ratherTypeTaps = 0;
  });

  testWidgets('prompt shows the orb, headline, hint and Rather type?', (
    tester,
  ) async {
    await pumpView(tester, OnboardingCapturePhase.prompt);

    expect(find.text("What's on your mind?"), findsOneWidget);
    expect(find.byType(VoiceOrbZone), findsOneWidget);
    expect(find.text('Try: a quick errand'), findsOneWidget);
    expect(find.text('Rather type?'), findsOneWidget);

    // Invoke the handler directly: the idle orb's shader overflow box covers
    // the lower region in the test surface, so a hit-test tap is unreliable —
    // we're verifying the callback is wired, not pointer geometry.
    tester
        .widget<TextButton>(find.widgetWithText(TextButton, 'Rather type?'))
        .onPressed!();
    expect(ratherTypeTaps, 1);
  });

  testWidgets('tapping the orb invokes onOrbTap', (tester) async {
    await pumpView(tester, OnboardingCapturePhase.prompt);

    await tester.tap(find.byType(VoiceButton), warnIfMissed: false);
    expect(orbTaps, 1);
  });

  testWidgets('listening renders the live orb zone with its caption', (
    tester,
  ) async {
    await pumpView(tester, OnboardingCapturePhase.listening);

    expect(find.byType(VoiceOrbZone), findsOneWidget);
    expect(find.text('Tap when done'), findsOneWidget);
    // Still listenable, so the escape hatch remains.
    expect(find.text('Rather type?'), findsOneWidget);
  });

  testWidgets('thinking echoes the transcript with a shimmer and reassurance', (
    tester,
  ) async {
    await pumpView(tester, OnboardingCapturePhase.thinking);

    expect(find.text('Building your task'), findsOneWidget);
    expect(
      find.text('"call the dentist and book the car service"'),
      findsOneWidget,
    );
    expect(find.byType(AiThinkingLineShader), findsOneWidget);
    expect(find.text('You can edit everything next'), findsOneWidget);
    // No escape hatch once we're past listening — the page navigates to the
    // real task from here, there is no in-page reveal.
    expect(find.text('Rather type?'), findsNothing);
  });
}
