import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/chat_input/design_system_voice_waveform.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

/// Records every bar the painter draws.
class _Canvas extends Fake implements Canvas {
  final bars = <Rect>[];

  @override
  void drawRRect(RRect rrect, Paint paint) => bars.add(rrect.outerRect);
}

void main() {
  DesignSystemVoiceWaveformPainter painter(
    List<double> levels, {
    double samplesPerWindow = 40,
  }) => DesignSystemVoiceWaveformPainter(
    levels: levels,
    samplesPerWindow: samplesPerWindow,
    barWidth: 2,
    barSpacing: 2,
    color: const Color(0xFFFFFFFF),
  );

  List<Rect> paint(DesignSystemVoiceWaveformPainter p, double width) {
    final canvas = _Canvas();
    p.paint(canvas, Size(width, 32));
    return canvas.bars;
  }

  test('a wide row is full once the take is as long as the window — not '
      'one bar per sample with the rest left for before the take', () {
    // 4 s at 100 ms; a 1400 px row has 350 slots.
    final bars = paint(painter(List.filled(41, 0.5)), 1400);

    expect(bars, hasLength(350));
    expect(bars.first.left, closeTo(0, 4));
    expect(bars.last.right, closeTo(1400, 0.01));
  });

  test('before the window is filled, nothing is drawn for the time before '
      'the take: it grows in from the right', () {
    // One second of a four-second window.
    final bars = paint(painter(List.filled(11, 0.5)), 1400);

    expect(bars.length, inInclusiveRange(80, 95));
    expect(bars.last.right, closeTo(1400, 0.01));
    expect(bars.first.left, greaterThan(1000));
  });

  test('no take, no bars', () {
    expect(paint(painter(const []), 400), isEmpty);
    expect(paint(painter(const [0.5]), 0), isEmpty);
  });

  test('levels are read between samples, and loud stands taller than '
      'quiet, centred', () {
    // A one-sample window: the row walks from the first level to the last.
    final p = painter(const [0, 1], samplesPerWindow: 1);
    expect(p.levelAt(-0.1), isNull);
    expect(p.levelAt(0.5), closeTo(0.5, 1e-9));
    expect(p.levelAt(3), 1);
    expect(p.barHeight(0, 32), 2);
    expect(p.barHeight(1, 32), 32);
    final bars = paint(p, 40);
    for (final bar in bars) {
      expect(bar.center.dy, closeTo(16, 1e-9));
    }
    expect(bars.last.height, greaterThan(bars.first.height));
  });

  test('repaints only when what it draws changes', () {
    final a = painter([0.1]);
    expect(a.shouldRepaint(painter([0.1])), isTrue); // a new take's list
    final levels = [0.2];
    expect(painter(levels).shouldRepaint(painter(levels)), isFalse);
    expect(
      painter(levels).shouldRepaint(painter(levels, samplesPerWindow: 80)),
      isTrue,
    );
  });

  testWidgets('spans the width it is given and is silent to a screen reader', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const SizedBox(
          width: 500,
          child: DesignSystemVoiceWaveform(levels: [0.2, 0.8]),
        ),
      ),
    );

    final paint = find.descendant(
      of: find.byType(DesignSystemVoiceWaveform),
      matching: find.byType(CustomPaint),
    );
    expect(tester.getSize(paint).width, 500);
    final painter =
        tester.widget<CustomPaint>(paint).painter!
            as DesignSystemVoiceWaveformPainter;
    expect(
      painter.samplesPerWindow,
      DesignSystemVoiceWaveform.defaultWindow.inMilliseconds /
          DesignSystemVoiceWaveform.defaultSampleInterval.inMilliseconds,
    );
    expect(
      find.ancestor(
        of: find.byType(CustomPaint).last,
        matching: find.byType(ExcludeSemantics),
      ),
      findsWidgets,
    );
  });
}
