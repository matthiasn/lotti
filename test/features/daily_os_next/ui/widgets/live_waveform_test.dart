import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/live_waveform.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Future<CustomPaint> pumpWaveform(
    WidgetTester tester, {
    List<double> amplitudes = const [],
    int barCount = 28,
    bool reducedMotion = false,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: Center(
            child: LiveWaveform(
              amplitudes: amplitudes,
              barCount: barCount,
            ),
          ),
        ),
        mediaQueryData: MediaQueryData(
          size: const Size(800, 600),
          disableAnimations: reducedMotion,
        ),
      ),
    );
    await tester.pump();
    return tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(LiveWaveform),
        matching: find.byType(CustomPaint),
      ),
    );
  }

  group('LiveWaveform', () {
    testWidgets('renders an explicitly sized strip even with no samples', (
      tester,
    ) async {
      final paint = await pumpWaveform(tester);

      // The idle baseline keeps the strip visible: the CustomPaint has the
      // explicit size and a painter, and painting throws nothing.
      expect(paint.size, const Size(240, 28));
      expect(paint.painter, isNotNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('clamps out-of-range samples without throwing', (
      tester,
    ) async {
      await pumpWaveform(
        tester,
        amplitudes: [-0.5, 0.2, 1.7, 0.9],
        barCount: 4,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('shouldRepaint follows identity, color and barCount', (
      tester,
    ) async {
      final samples = [0.1, 0.5];
      final first = await pumpWaveform(tester, amplitudes: samples);
      final firstPainter = first.painter!;

      // Same list identity and config: repaint not requested.
      await tester.pumpWidget(const SizedBox.shrink());
      final second = await pumpWaveform(tester, amplitudes: samples);
      expect(second.painter!.shouldRepaint(firstPainter), isFalse);

      // A new list instance (fresh sample tick) requests a repaint.
      final third = await pumpWaveform(tester, amplitudes: [0.1, 0.5]);
      expect(third.painter!.shouldRepaint(firstPainter), isTrue);

      // A different bar count requests a repaint.
      final fourth = await pumpWaveform(
        tester,
        amplitudes: samples,
        barCount: 12,
      );
      expect(fourth.painter!.shouldRepaint(firstPainter), isTrue);
    });

    testWidgets(
      'reduced motion rests on a static baseline and ignores the live signal',
      (tester) async {
        // Loud samples that WOULD make the bars dance — but reduced motion is
        // on, so the painter must run in its static-baseline mode.
        final loud = await pumpWaveform(
          tester,
          amplitudes: const [1, 1, 1, 1],
          reducedMotion: true,
        );
        final painter = loud.painter! as LiveWaveformPainter;
        expect(painter.reducedMotion, isTrue);
        expect(tester.takeException(), isNull);

        // A fresh, louder, differently-shaped sample tick must NOT request a
        // repaint under reduced motion — the baseline is independent of the
        // live signal, so the strip never animates.
        await tester.pumpWidget(const SizedBox.shrink());
        final next = await pumpWaveform(
          tester,
          amplitudes: const [0.2, 0.9, 0.3, 0.7],
          reducedMotion: true,
        );
        expect(
          (next.painter! as LiveWaveformPainter).shouldRepaint(painter),
          isFalse,
        );
      },
    );

    testWidgets('toggling reduced motion forces a repaint', (tester) async {
      final moving = await pumpWaveform(tester, amplitudes: const [0.5]);
      final movingPainter = moving.painter! as LiveWaveformPainter;
      expect(movingPainter.reducedMotion, isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
      final still = await pumpWaveform(
        tester,
        amplitudes: const [0.5],
        reducedMotion: true,
      );
      // The motion ⇄ static switch is a visual change, so it always repaints.
      expect(
        (still.painter! as LiveWaveformPainter).shouldRepaint(movingPainter),
        isTrue,
      );
    });
  });
}
