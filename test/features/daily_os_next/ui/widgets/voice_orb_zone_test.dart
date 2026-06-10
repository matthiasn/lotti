import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/live_waveform.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/voice_button.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/voice_orb_zone.dart';

import '../../../../test_helper.dart';

void main() {
  Future<void> pumpZone(
    WidgetTester tester, {
    CapturePhase phase = CapturePhase.idle,
    String caption = 'Tap to talk',
    Color captionColor = Colors.white70,
    List<double> amplitudes = const [],
    VoidCallback? onTap,
  }) async {
    await tester.pumpWidget(
      WidgetTestBench(
        child: Center(
          child: VoiceOrbZone(
            phase: phase,
            caption: caption,
            captionColor: captionColor,
            semanticLabel: 'Record voice',
            amplitudes: amplitudes,
            onTap: onTap ?? () {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
  }

  testWidgets('reserves identical height in every phase', (tester) async {
    // The whole point of the zone: the orb cannot move vertically because
    // the block never changes height — waveform slot always reserved, the
    // caption a single forced-strut line.
    double? referenceHeight;
    for (final phase in CapturePhase.values) {
      await pumpZone(
        tester,
        phase: phase,
        amplitudes: const [0.2, 0.5, 0.8],
        caption: switch (phase) {
          CapturePhase.idle => 'Tap to talk',
          CapturePhase.listening => 'Listening…',
          CapturePhase.transcribing => 'Transcribing…',
          CapturePhase.captured => 'Got it.',
          CapturePhase.error => 'Tap to talk',
        },
      );
      final height = tester.getSize(find.byType(VoiceOrbZone)).height;
      if (referenceHeight == null) {
        referenceHeight = height;
      } else {
        expect(
          height,
          referenceHeight,
          reason: 'zone height changed in $phase',
        );
      }
    }
  });

  testWidgets('waveform renders only while listening or transcribing', (
    tester,
  ) async {
    await pumpZone(tester, amplitudes: const [0.4, 0.6]);
    expect(find.byType(LiveWaveform), findsNothing);

    await pumpZone(
      tester,
      phase: CapturePhase.listening,
      amplitudes: const [0.4, 0.6],
    );
    expect(find.byType(LiveWaveform), findsOneWidget);

    await pumpZone(
      tester,
      phase: CapturePhase.transcribing,
      amplitudes: const [0.4, 0.6],
    );
    final dimmed = tester.widget<AnimatedOpacity>(
      find.ancestor(
        of: find.byType(LiveWaveform),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    // Frozen-but-visible during transcription so nothing jumps.
    expect(dimmed.opacity, lessThan(1));

    await pumpZone(tester, phase: CapturePhase.captured);
    expect(find.byType(LiveWaveform), findsNothing);
  });

  testWidgets('caption renders with the given color and a forced strut', (
    tester,
  ) async {
    const color = Color(0xFF2BA184);
    await pumpZone(tester, caption: 'Listening…', captionColor: color);

    final caption = tester.widget<Text>(find.text('Listening…'));
    expect(caption.style?.color, color);
    expect(caption.strutStyle?.forceStrutHeight, isTrue);
    expect(caption.maxLines, 1);
  });

  testWidgets('tap on the orb reaches the callback', (tester) async {
    var taps = 0;
    await pumpZone(tester, onTap: () => taps += 1);
    await tester.tap(find.byKey(VoiceButton.coreButtonKey));
    expect(taps, 1);
  });

  group('LiveTranscriptView', () {
    testWidgets('pins text to the bottom and follows the newest words', (
      tester,
    ) async {
      const text = 'first line\nsecond line\nthird line';
      await tester.pumpWidget(
        const WidgetTestBench(
          child: SizedBox(
            width: 300,
            height: 120,
            child: LiveTranscriptView(text: text, color: Colors.white),
          ),
        ),
      );

      final scrollView = tester.widget<SingleChildScrollView>(
        find.descendant(
          of: find.byKey(LiveTranscriptView.viewportKey),
          matching: find.byType(SingleChildScrollView),
        ),
      );
      expect(scrollView.reverse, isTrue);
      expect(scrollView.physics, isA<NeverScrollableScrollPhysics>());
      expect(find.text(text), findsOneWidget);
    });

    testWidgets('renders nothing for empty text', (tester) async {
      await tester.pumpWidget(
        const WidgetTestBench(
          child: SizedBox(
            width: 300,
            height: 120,
            child: LiveTranscriptView(text: '', color: Colors.white),
          ),
        ),
      );
      expect(find.byKey(LiveTranscriptView.viewportKey), findsNothing);
    });
  });
}
