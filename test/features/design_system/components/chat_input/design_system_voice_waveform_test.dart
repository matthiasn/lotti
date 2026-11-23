import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/chat_input/design_system_voice_waveform.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

/// Records every bar and line the painter draws.
class _Canvas extends Fake implements Canvas {
  final bars = <Rect>[];
  final lines = <(Offset, Offset, Paint)>[];

  @override
  void drawRRect(RRect rrect, Paint paint) => bars.add(rrect.outerRect);

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) =>
      lines.add((p1, p2, paint));
}

const _ink = Color(0xFF00FF00);
const _hairline = Color(0xFF777777);

void main() {
  DesignSystemVoiceWaveformPainter painter(
    List<double> levels, {
    double samplesPerBar = 1,
    bool reducedMotion = false,
  }) => DesignSystemVoiceWaveformPainter(
    levels: levels,
    samplesPerBar: samplesPerBar,
    barWidth: 2,
    barSpacing: 4,
    color: _ink,
    baselineColor: _hairline,
    baselineWidth: 1,
    reducedMotion: reducedMotion,
  );

  _Canvas paint(DesignSystemVoiceWaveformPainter p, double width) {
    final canvas = _Canvas();
    p.paint(canvas, Size(width, 24));
    return canvas;
  }

  test('one bar per stretch of the take, as many as fit the width: a long '
      'take fills the row to both edges', () {
    // 2 px bars on a 6 px pitch: 300 px holds 50, with no gap after the last.
    final canvas = paint(painter(List.filled(200, 0.5)), 300);

    expect(canvas.bars, hasLength(50));
    expect(canvas.bars.last.right, closeTo(300, 0.01));
    expect(canvas.bars.first.left, closeTo(300 - (50 * 6 - 4), 0.01));
    // Sound stands centred on the hairline, as tall as it is loud.
    for (final bar in canvas.bars) {
      expect(bar.center.dy, closeTo(12, 1e-9));
      expect(bar.height, closeTo(12, 1e-9));
    }
  });

  test('a take grows in from the right: nothing is drawn for the time '
      'before it, and the hairline is only as long as the take', () {
    final canvas = paint(painter(List.filled(10, 0.5)), 300);

    expect(canvas.bars, hasLength(10));
    expect(canvas.bars.last.right, closeTo(300, 0.01));
    expect(canvas.bars.first.left, closeTo(300 - (10 * 6 - 4), 0.01));
    final (from, to, line) = canvas.lines.single;
    expect(from.dx, canvas.bars.first.left);
    expect(to.dx, 300);
    expect(from.dy, 12);
    expect(line.color.toARGB32(), _hairline.toARGB32());
    expect(line.strokeWidth, 1);
  });

  test('silence is the hairline alone', () {
    final canvas = paint(painter(List.filled(10, 0)), 300);
    expect(canvas.bars, isEmpty);
    expect(canvas.lines, hasLength(1));
  });

  test('no take, or no room: nothing at all', () {
    final none = paint(painter(const []), 300);
    expect(none.bars, isEmpty);
    expect(none.lines, isEmpty);
    final narrow = paint(painter(const [0.5]), 0);
    expect(narrow.bars, isEmpty);
    expect(narrow.lines, isEmpty);
  });

  test('a slow recorder is read between its samples; a fast one gives each '
      'bar the loudest of the samples it stands for', () {
    final slow = painter(const [0, 1], samplesPerBar: 0.5);
    expect(slow.levelAt(-0.1), isNull);
    expect(slow.levelAt(0.5), closeTo(0.5, 1e-9));
    expect(slow.levelAt(3), 1);
    expect(slow.barLevelAt(0.5), closeTo(0.5, 1e-9));
    // Newest at full height, the bar before it half-way to the sample before.
    final slowBars = paint(slow, 300).bars;
    expect(slowBars.last.height, closeTo(24, 1e-9));
    expect(slowBars[slowBars.length - 2].height, closeTo(12, 1e-9));

    final fast = painter(const [0.1, 0.9, 0.2, 0.4, 0.3], samplesPerBar: 2);
    expect(fast.barLevelAt(4), 0.4, reason: 'samples 3 and 4');
    expect(fast.barLevelAt(2), 0.9, reason: 'samples 1 and 2');
    expect(fast.barLevelAt(0), 0.1, reason: 'the first sample alone');
    expect(fast.barLevelAt(-1), isNull);
    // Five samples at two per bar: three bars reached.
    expect(paint(fast, 300).bars, hasLength(3));
  });

  test('under reduced motion the hairline lies still across the whole '
      'width and no bar is drawn, whatever the level', () {
    final canvas = paint(
      painter(List.filled(10, 0.9), reducedMotion: true),
      300,
    );
    expect(canvas.bars, isEmpty);
    final (from, to, _) = canvas.lines.single;
    expect(from.dx, 0);
    expect(to.dx, 300);
    // Before a take too: the strip is never an empty hole.
    expect(
      paint(painter(const [], reducedMotion: true), 300).lines,
      hasLength(1),
    );
  });

  test('repaints only when what it draws changes', () {
    expect(painter([0.1]).shouldRepaint(painter([0.1])), isTrue);
    final levels = [0.2];
    expect(painter(levels).shouldRepaint(painter(levels)), isFalse);
    expect(
      painter(levels).shouldRepaint(painter(levels, samplesPerBar: 2)),
      isTrue,
    );
    expect(
      painter(levels).shouldRepaint(painter(levels, reducedMotion: true)),
      isTrue,
    );
  });

  group('the widget', () {
    Future<DesignSystemVoiceWaveformPainter> pump(
      WidgetTester tester, {
      Duration? sampleInterval,
      bool disableAnimations = false,
    }) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SizedBox(
            width: 500,
            child: sampleInterval == null
                ? const DesignSystemVoiceWaveform(levels: [0.2, 0.8])
                : DesignSystemVoiceWaveform(
                    levels: const [0.2, 0.8],
                    sampleInterval: sampleInterval,
                  ),
          ),
          mediaQueryData: MediaQueryData(disableAnimations: disableAnimations),
        ),
      );
      return tester
              .widget<CustomPaint>(
                find.descendant(
                  of: find.byType(DesignSystemVoiceWaveform),
                  matching: find.byType(CustomPaint),
                ),
              )
              .painter!
          as DesignSystemVoiceWaveformPainter;
    }

    testWidgets('spans the width it is given, in the accent over the '
        'decorative hairline, and is silent to a screen reader', (
      tester,
    ) async {
      final painter = await pump(tester);
      final tokens = tester
          .element(find.byType(DesignSystemVoiceWaveform))
          .designTokens;

      expect(
        tester.getSize(
          find.descendant(
            of: find.byType(DesignSystemVoiceWaveform),
            matching: find.byType(CustomPaint),
          ),
        ),
        Size(500, tokens.spacing.step6),
      );
      expect(painter.color, tokens.colors.interactive.enabled);
      expect(painter.baselineColor, tokens.colors.decorative.level02);
      expect(painter.barWidth, tokens.spacing.step1);
      expect(painter.barSpacing, tokens.spacing.step2);
      expect(painter.reducedMotion, isFalse);
      expect(
        find.descendant(
          of: find.byType(DesignSystemVoiceWaveform),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a bar stands for the same stretch of a take whatever the '
        "host's sample rate, so the bars move at one pace everywhere", (
      tester,
    ) async {
      // The chat recorder's 100 ms: two and a half bars per sample.
      expect((await pump(tester)).samplesPerBar, closeTo(0.4, 1e-9));
      // The entry recorder's 20 ms: two samples per bar.
      expect(
        (await pump(
          tester,
          sampleInterval: const Duration(milliseconds: 20),
        )).samplesPerBar,
        closeTo(2, 1e-9),
      );
    });

    testWidgets('fades out at its oldest end only, so the newest bars are '
        'at full strength', (tester) async {
      await pump(tester);
      final mask = tester.widget<ShaderMask>(
        find.descendant(
          of: find.byType(DesignSystemVoiceWaveform),
          matching: find.byType(ShaderMask),
        ),
      );
      expect(mask.blendMode, BlendMode.dstIn);
      expect(
        mask.shaderCallback(const Rect.fromLTWH(0, 0, 100, 10)),
        isNotNull,
      );
    });

    testWidgets('the system reduced-motion setting reaches the painter', (
      tester,
    ) async {
      expect(
        (await pump(tester, disableAnimations: true)).reducedMotion,
        isTrue,
      );
    });
  });
}
