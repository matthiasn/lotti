import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/speech/ui/widgets/recording/live_waveform.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../widget_test_utils.dart';

/// Counts what the painter draws.
class _CountingCanvas implements Canvas {
  final lines = <(Offset, Offset, Paint)>[];
  final bars = <RRect>[];

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) =>
      lines.add((p1, p2, paint));

  @override
  void drawRRect(RRect rrect, Paint paint) => bars.add(rrect);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  group('LiveWaveformPainter baseline', () {
    const size = Size(200, 24);
    const ink = Color(0xFF00FF00);
    const hairline = Color(0xFF888888);

    _CountingCanvas paint(List<double> amplitudes, {Color? baseline}) {
      final canvas = _CountingCanvas();
      LiveWaveformPainter(
        barCount: 10,
        color: ink,
        amplitudes: amplitudes,
        baselineColor: baseline,
        baselineWidth: 2,
      ).paint(canvas, size);
      return canvas;
    }

    test('without one, silence is a row of idle bars and no line', () {
      final canvas = paint(const [0, 0, 0]);
      expect(canvas.lines, isEmpty);
      expect(canvas.bars, hasLength(10));
    });

    test('with one, silence is a single hairline at the middle, in its '
        'colour and weight, from the oldest sample to now — and only sound '
        'draws a bar', () {
      // Four samples of ten slots: the line starts at the seventh slot.
      final canvas = paint(const [0, 0, 0.8, 0], baseline: hairline);
      final (start, end, linePaint) = canvas.lines.single;
      expect(start, const Offset(120, 12));
      expect(end, const Offset(200, 12));
      expect(linePaint.color.toARGB32(), hairline.toARGB32());
      expect(linePaint.strokeWidth, 2);
      expect(canvas.bars, hasLength(1));
      expect(canvas.bars.single.height, closeTo(24 * 0.8, 0.01));
    });

    test('before the first sample there is no line yet; a full window '
        'spans the strip', () {
      expect(paint(const [], baseline: hairline).lines, isEmpty);
      final full = paint(List.filled(12, 0), baseline: hairline);
      expect(full.lines.single.$1, const Offset(0, 12));
    });

    test('standing still for reduced motion, the line spans the strip', () {
      final canvas = _CountingCanvas();
      LiveWaveformPainter(
        barCount: 10,
        color: ink,
        amplitudes: const [0.5],
        reducedMotion: true,
        baselineColor: hairline,
      ).paint(canvas, size);
      expect(canvas.lines.single.$1, const Offset(0, 12));
      expect(canvas.bars, isEmpty);
    });

    test('a change of baseline repaints', () {
      final plain = LiveWaveformPainter(
        barCount: 10,
        color: ink,
        amplitudes: const [],
      );
      final lined = LiveWaveformPainter(
        barCount: 10,
        color: ink,
        amplitudes: plain.amplitudes,
        baselineColor: hairline,
      );
      expect(lined.shouldRepaint(plain), isTrue);
      expect(
        LiveWaveformPainter(
          barCount: 10,
          color: ink,
          amplitudes: plain.amplitudes,
          baselineColor: hairline,
          baselineWidth: 3,
        ).shouldRepaint(lined),
        isTrue,
      );
    });
  });

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
