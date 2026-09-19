import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/chat/waveform_bars.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

/// Records the rounded rectangles a painter draws, in order.
class _RecordingCanvas implements Canvas {
  final rects = <RRect>[];
  final colors = <Color>[];

  @override
  void drawRRect(RRect rrect, Paint paint) {
    rects.add(rrect);
    colors.add(paint.color);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  const barWidth = 3.0;
  const size = Size(60, 32);

  WaveformBarsPainter painter(List<double> amplitudes, {Color? color}) =>
      WaveformBarsPainter(
        amplitudes: amplitudes,
        barWidth: barWidth,
        barSpacing: barWidth,
        color: color ?? Colors.white,
      );

  List<RRect> paint(List<double> amplitudes) {
    final canvas = _RecordingCanvas();
    painter(amplitudes).paint(canvas, size);
    return canvas.rects;
  }

  group('WaveformBarsPainter', () {
    test('fills the whole row, newest bar flush with the right edge', () {
      final rects = paint(const [1]);

      // (60 + 3) / 6 = 10 slots.
      expect(rects, hasLength(10));
      expect(rects.last.right, size.width);
      for (var i = 1; i < rects.length; i++) {
        expect(rects[i].left - rects[i - 1].right, barWidth);
      }
    });

    test('slots older than the recording, and silence, are round dots on '
        'the centre line', () {
      final rects = paint(const [0, 1]);

      for (final dot in rects.take(9)) {
        expect(dot.width, barWidth);
        expect(dot.height, barWidth, reason: 'as tall as it is wide');
        expect(dot.tlRadiusX, barWidth / 2);
        expect(dot.center.dy, size.height / 2);
      }
      expect(rects.last.height, size.height, reason: 'full level, full bar');
      expect(rects.last.center.dy, size.height / 2);
    });

    test('shows only the newest samples that fit, oldest scrolled off the '
        'left', () {
      final amplitudes = [
        for (var i = 0; i < 25; i++)
          if (i.isEven) 0.0 else 1.0,
      ];
      final rects = paint(amplitudes);

      expect(rects, hasLength(10));
      // The last sample (index 24) is even: a dot at the right edge.
      expect(rects.last.height, barWidth);
      expect(rects[rects.length - 2].height, size.height);
    });

    test('taller for louder, and quiet stays close to a dot', () {
      final p = painter(const []);
      final heights = [
        for (final level in [0.0, 0.2, 0.5, 0.8, 1.0])
          p.barHeight(level, size.height),
      ];

      for (var i = 1; i < heights.length; i++) {
        expect(heights[i], greaterThan(heights[i - 1]));
      }
      expect(heights[1], lessThan(barWidth + (size.height - barWidth) * 0.1));
      expect(p.barHeight(-1, size.height), barWidth);
      expect(p.barHeight(2, size.height), size.height);
    });

    test('draws nothing in a row too narrow for one bar', () {
      final canvas = _RecordingCanvas();
      painter(const [1]).paint(canvas, const Size(2, 32));
      expect(canvas.rects, isEmpty);
    });

    test('repaints when what it draws changes, and only then', () {
      final base = painter(const [0.5]);
      expect(base.shouldRepaint(painter(const [0.5])), isFalse);
      expect(base.shouldRepaint(painter(const [0.6])), isTrue);
      expect(
        base.shouldRepaint(painter(const [0.5], color: Colors.red)),
        isTrue,
      );
      expect(
        base.shouldRepaint(
          WaveformBarsPainter(
            amplitudes: const [0.5],
            barWidth: 4,
            barSpacing: barWidth,
            color: Colors.white,
          ),
        ),
        isTrue,
      );
      expect(
        base.shouldRepaint(
          WaveformBarsPainter(
            amplitudes: const [0.5],
            barWidth: barWidth,
            barSpacing: 4,
            color: Colors.white,
          ),
        ),
        isTrue,
      );
    });
  });

  testWidgets('sits in the composer row unframed: token height, token '
      'colour, bars as wide as their gaps', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const SizedBox(
          width: 200,
          child: WaveformBars(amplitudesNormalized: [0.2, 0.9]),
        ),
      ),
    );

    final tokens = tester.element(find.byType(WaveformBars)).designTokens;
    expect(
      tester.getSize(find.byType(WaveformBars)).height,
      tokens.spacing.step7,
    );
    expect(
      find.descendant(
        of: find.byType(WaveformBars),
        matching: find.byType(Container),
      ),
      findsNothing,
      reason: 'no frame, no border around the waveform',
    );
    final painter = tester
        .widgetList<CustomPaint>(
          find.descendant(
            of: find.byType(WaveformBars),
            matching: find.byType(CustomPaint),
          ),
        )
        .map((paint) => paint.painter)
        .whereType<WaveformBarsPainter>()
        .single;
    expect(painter.color, tokens.colors.text.highEmphasis);
    expect(painter.barWidth, tokens.spacing.step1);
    expect(painter.barSpacing, tokens.spacing.step1);
    expect(painter.amplitudes, const [0.2, 0.9]);
  });
}
