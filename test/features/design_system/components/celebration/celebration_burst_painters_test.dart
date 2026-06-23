import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_burst_painters.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_variant.dart';
import 'package:lotti/themes/colors.dart';

/// A [Canvas] that only tallies the draw primitives the burst painters use, so a
/// test can assert a variant actually paints its characteristic shape (confetti
/// → rects, sparks → lines, etc.) rather than merely "did not throw".
class _CountingCanvas implements Canvas {
  int circles = 0;
  int lines = 0;
  int rects = 0;

  @override
  void drawCircle(Offset c, double radius, Paint paint) => circles++;

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) => lines++;

  @override
  void drawRect(Rect rect, Paint paint) => rects++;

  // Transforms used by the confetti painter — accepted, ignored.
  @override
  void save() {}
  @override
  void restore() {}
  @override
  void translate(double dx, double dy) {}
  @override
  void rotate(double radians) {}
  @override
  void scale(double sx, [double? sy]) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

const _accent = Color(0xFF3366FF);
const _size = Size(200, 200);

CelebrationBurstPainter painterFor(
  CelebrationVariant variant, {
  required double progress,
  double sizeScale = 1.0,
  int count = 40,
}) => buildCelebrationBurstPainter(
  variant: variant,
  progress: progress,
  origin: Alignment.center,
  accent: _accent,
  count: count,
  sizeScale: sizeScale,
  clearCenter: 0.2,
  reachFactor: 2.1,
  reachOverride: null,
);

// ignore: library_private_types_in_public_api
_CountingCanvas paintTo(CelebrationBurstPainter painter) {
  final canvas = _CountingCanvas();
  painter.paint(canvas, _size);
  return canvas;
}

void main() {
  group('celebrationPalette', () {
    test('sparks is the accent plus gold', () {
      expect(celebrationPalette(CelebrationVariant.sparks, _accent), [
        _accent,
        starredGold,
      ]);
    });

    test('fireworks and confetti share the festive multi-colour set', () {
      final fireworks = celebrationPalette(
        CelebrationVariant.fireworks,
        _accent,
      );
      final confetti = celebrationPalette(CelebrationVariant.confetti, _accent);
      expect(fireworks, confetti);
      expect(fireworks.first, _accent);
      expect(fireworks.length, greaterThan(4));
    });

    test('embers is a warm set led by gold and ending in dark orange', () {
      final embers = celebrationPalette(CelebrationVariant.embers, _accent);
      expect(embers.first, starredGold);
      expect(embers.last, taskStatusDarkOrange);
      // The accent (cool) is deliberately absent from the warm set.
      expect(embers, isNot(contains(_accent)));
    });

    test('bubbles keeps the cool accent as its lead colour', () {
      final bubbles = celebrationPalette(CelebrationVariant.bubbles, _accent);
      expect(bubbles.first, _accent);
    });

    test('every variant yields a non-empty palette', () {
      for (final variant in CelebrationVariant.values) {
        expect(
          celebrationPalette(variant, _accent),
          isNotEmpty,
          reason: variant.name,
        );
      }
    });
  });

  group('buildCelebrationBurstPainter dispatch', () {
    final expected = <CelebrationVariant, Type>{
      CelebrationVariant.sparks: SparksBurstPainter,
      CelebrationVariant.fireworks: FireworksBurstPainter,
      CelebrationVariant.confetti: ConfettiBurstPainter,
      CelebrationVariant.embers: EmbersBurstPainter,
      CelebrationVariant.bubbles: BubblesBurstPainter,
    };

    test('maps every variant to its dedicated painter', () {
      for (final variant in CelebrationVariant.values) {
        expect(
          painterFor(variant, progress: 0.5).runtimeType,
          expected[variant],
          reason: variant.name,
        );
      }
    });
  });

  group('base geometry helpers', () {
    final painter = painterFor(CelebrationVariant.sparks, progress: 0.5);

    test('reachOf uses reachFactor × height when no override is set', () {
      // reachFactor 2.1 × height 200 = 420.
      expect(painter.reachOf(_size), 420);
    });

    test('reachOf prefers an absolute override', () {
      final overridden = buildCelebrationBurstPainter(
        variant: CelebrationVariant.sparks,
        progress: 0.5,
        origin: Alignment.center,
        accent: _accent,
        count: 10,
        sizeScale: 1,
        clearCenter: 0,
        reachFactor: 2.1,
        reachOverride: 77,
      );
      expect(overridden.reachOf(_size), 77);
    });

    test('centerOf resolves the fractional origin to pixels', () {
      expect(painter.centerOf(_size), const Offset(100, 100));
    });

    test('paletteColor cycles through the palette by index', () {
      final p = painterFor(CelebrationVariant.sparks, progress: 0.5);
      // palette is [accent, gold]; index wraps modulo length.
      expect(p.paletteColor(0), _accent);
      expect(p.paletteColor(1), starredGold);
      expect(p.paletteColor(2), _accent);
    });
  });

  group('shouldRepaint', () {
    SparksBurstPainter spark({
      double progress = 0.5,
      Alignment origin = Alignment.center,
      int count = 40,
      double sizeScale = 1,
      double clearCenter = 0.2,
      double reachFactor = 2.1,
      double? reachOverride,
      List<Color>? palette,
    }) => SparksBurstPainter(
      progress: progress,
      origin: origin,
      palette: palette ?? const [_accent, starredGold],
      count: count,
      sizeScale: sizeScale,
      clearCenter: clearCenter,
      reachFactor: reachFactor,
      reachOverride: reachOverride,
    );

    test('false when every input is identical', () {
      expect(spark().shouldRepaint(spark()), isFalse);
    });

    test('true when the painter type differs (variant switch)', () {
      final other = painterFor(CelebrationVariant.embers, progress: 0.5);
      expect(spark().shouldRepaint(other), isTrue);
    });

    test('true for any single changed field', () {
      final base = spark();
      expect(base.shouldRepaint(spark(progress: 0.6)), isTrue);
      expect(
        base.shouldRepaint(spark(origin: const Alignment(0.1, 0))),
        isTrue,
      );
      expect(base.shouldRepaint(spark(count: 41)), isTrue);
      expect(base.shouldRepaint(spark(sizeScale: 0.9)), isTrue);
      expect(base.shouldRepaint(spark(clearCenter: 0.3)), isTrue);
      expect(base.shouldRepaint(spark(reachFactor: 2.2)), isTrue);
      expect(base.shouldRepaint(spark(reachOverride: 50)), isTrue);
      expect(
        base.shouldRepaint(spark(palette: const [_accent])),
        isTrue,
      );
    });
  });

  group('each variant paints its characteristic primitive', () {
    test('sparks draws comet heads (circles) and trails (lines)', () {
      final c = paintTo(painterFor(CelebrationVariant.sparks, progress: 0.4));
      expect(c.circles, greaterThan(0));
      expect(c.lines, greaterThan(0));
    });

    test('fireworks draws a rocket streak (line) during the launch', () {
      final c = paintTo(
        painterFor(CelebrationVariant.fireworks, progress: 0.1),
      );
      expect(c.lines, greaterThan(0));
    });

    test('fireworks draws shell sparks (circles) after the launch', () {
      final c = paintTo(
        painterFor(CelebrationVariant.fireworks, progress: 0.5),
      );
      expect(c.circles, greaterThan(0));
    });

    test('confetti draws ribbons (rects)', () {
      final c = paintTo(painterFor(CelebrationVariant.confetti, progress: 0.3));
      expect(c.rects, greaterThan(0));
    });

    test('embers draws glowing motes (circles)', () {
      final c = paintTo(painterFor(CelebrationVariant.embers, progress: 0.4));
      expect(c.circles, greaterThan(0));
    });

    test('bubbles draws membranes (circles) while alive', () {
      final c = paintTo(painterFor(CelebrationVariant.bubbles, progress: 0.3));
      expect(c.circles, greaterThan(0));
    });

    test('embers tolerates a degenerate single-colour palette', () {
      // The dispatch always pairs embers with its 4-colour palette, but the
      // painter must not divide by zero if ever handed a length-1 palette.
      final painter = EmbersBurstPainter(
        progress: 0.5,
        origin: Alignment.center,
        palette: const [_accent],
        count: 20,
        sizeScale: 1,
        clearCenter: 0.2,
        reachFactor: 2.1,
        reachOverride: null,
      );
      expect(() => paintTo(painter), returnsNormally);
    });

    test('bubbles still paints during the pop phase', () {
      // Bubbles live ~0.7 of the timeline, so progress 0.66 puts them past the
      // pop threshold (lt > 0.9) — the membrane ring must still draw.
      final c = paintTo(
        painterFor(CelebrationVariant.bubbles, progress: 0.66),
      );
      expect(c.circles, greaterThan(0));
    });
  });

  group('paints across the whole timeline without throwing', () {
    for (final variant in CelebrationVariant.values) {
      test(
        '${variant.name} survives early/mid/late progress + tiny sparks',
        () {
          for (final progress in const [0.05, 0.3, 0.6, 0.95]) {
            expect(
              () => paintTo(painterFor(variant, progress: progress)),
              returnsNormally,
            );
          }
          // A near-zero size scale drives heads below the cull threshold,
          // exercising the "too small to draw" skip branch.
          expect(
            () => paintTo(
              painterFor(variant, progress: 0.5, sizeScale: 0.02),
            ),
            returnsNormally,
          );
        },
      );
    }
  });
}
