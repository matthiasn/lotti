import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/scenery/runtime/stage_effects.dart';
import 'package:lotti/features/scenery/stage_effects_overlay.dart';

const _w = 240;
const _h = 180;

Future<Uint8List> _render(StageEffectsPainter painter) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..drawRect(
      Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble()),
      Paint()..color = const Color(0xFF000000),
    );
  painter.paint(canvas, Size(_w.toDouble(), _h.toDouble()));
  final img = await recorder.endRecording().toImage(_w, _h);
  final bytes = (await img.toByteData())!.buffer.asUint8List();
  img.dispose();
  return bytes;
}

Color _at(Uint8List b, double nx, double ny) {
  final x = (nx * _w).round().clamp(0, _w - 1);
  final y = (ny * _h).round().clamp(0, _h - 1);
  final i = (y * _w + x) * 4;
  return Color.fromARGB(b[i + 3], b[i], b[i + 1], b[i + 2]);
}

double _lum(Color c) => c.r + c.g + c.b;

StageParticleSample _sample(
  StageEffectKind kind, {
  double progress = 0.35,
  Offset origin = const Offset(0.5, 0.75),
}) => StageParticleSample(
  kind: kind,
  progress: progress,
  origin: origin,
  directionRadians: -1.57079632679,
  palette: const [
    Color(0xFFFFF6C8),
    Color(0xFFFFB547),
    Color(0xFFFF2E8C),
  ],
  count: 30,
  reach: 0.35,
  intensity: 0.9,
);

void main() {
  group('StageEffectsPainter', () {
    testWidgets('cold sparks light pixels above the emitter', (tester) async {
      await tester.runAsync(() async {
        final bytes = await _render(
          StageEffectsPainter(samples: [_sample(StageEffectKind.coldSparks)]),
        );
        expect(_lum(_at(bytes, 0.5, 0.62)), greaterThan(0.02));
      });
    });

    testWidgets('confetti paints non-black pixels from a side cannon', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final bytes = await _render(
          StageEffectsPainter(
            samples: [
              _sample(
                StageEffectKind.confetti,
                origin: const Offset(0.08, 0.78),
              ),
            ],
          ),
        );
        var lit = 0;
        for (var i = 0; i < bytes.length; i += 4) {
          if (bytes[i] + bytes[i + 1] + bytes[i + 2] > 0) lit++;
        }
        expect(lit, greaterThan(20));
      });
    });

    testWidgets('bubbles paint soft membranes', (tester) async {
      await tester.runAsync(() async {
        final bytes = await _render(
          StageEffectsPainter(samples: [_sample(StageEffectKind.bubbles)]),
        );
        var lit = 0;
        for (var i = 0; i < bytes.length; i += 4) {
          if (bytes[i] + bytes[i + 1] + bytes[i + 2] > 0) lit++;
        }
        expect(lit, greaterThan(20));
      });
    });

    testWidgets('reduced motion paints a static empty frame', (tester) async {
      await tester.runAsync(() async {
        final a = await _render(
          StageEffectsPainter(
            samples: [_sample(StageEffectKind.coldSparks, progress: 0.2)],
            reducedMotion: true,
          ),
        );
        final b = await _render(
          StageEffectsPainter(
            samples: [_sample(StageEffectKind.coldSparks, progress: 0.8)],
            reducedMotion: true,
          ),
        );
        expect(a, equals(b));
      });
    });

    test('no-ops for an empty size', () {
      final recorder = ui.PictureRecorder();
      expect(
        () => const StageEffectsPainter(samples: []).paint(
          Canvas(recorder),
          Size.zero,
        ),
        returnsNormally,
      );
      recorder.endRecording().dispose();
    });

    test('shouldRepaint tracks sample and reduced-motion changes', () {
      final base = StageEffectsPainter(
        samples: [_sample(StageEffectKind.coldSparks)],
      );
      expect(base.shouldRepaint(base), isFalse);
      expect(
        base.shouldRepaint(
          StageEffectsPainter(samples: [_sample(StageEffectKind.confetti)]),
        ),
        isTrue,
      );
      expect(
        base.shouldRepaint(
          StageEffectsPainter(
            samples: [_sample(StageEffectKind.coldSparks)],
            reducedMotion: true,
          ),
        ),
        isTrue,
      );
    });
  });
}
