import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/live_waveform.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Future<CustomPaint> pumpWaveform(
    WidgetTester tester, {
    List<double> amplitudes = const [],
    int barCount = 28,
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
  });
}
