import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/scenery/runtime/stage_lights.dart';
import 'package:lotti/features/scenery/stage_lights_overlay.dart';

const _w = 200;
const _h = 200;

// Paint the overlay's painter over black so the additive floor pools are
// directly readable as lit pixels.
Future<Uint8List> _render(StageLightsPainter painter) async {
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

// Hue distance ignoring brightness: compare the additive result to a gel by
// normalized channel ratios, so a dim pool still matches its full-strength gel.
double _dist(Color a, Color b) {
  final an = a.r + a.g + a.b;
  final bn = b.r + b.g + b.b;
  if (an == 0 || bn == 0) return double.infinity;
  final dr = a.r / an - b.r / bn;
  final dg = a.g / an - b.g / bn;
  final db = a.b / an - b.b / bn;
  return dr * dr + dg * dg + db * db;
}

double _lum(Color c) => c.r + c.g + c.b;

// The painter's pool sits a touch below floorY (the puddle is offset onto the
// deck in front of the feet); sample near the pool centre for these tests.
const _poolY = 0.835; // floorY 0.82 + the small downward puddle offset

StageLightsPainter _painter({double beat = 0, bool reducedMotion = false}) =>
    StageLightsPainter(
      time: 0,
      beat: beat,
      rig: const StageLightRig(),
      reducedMotion: reducedMotion,
    );

void main() {
  group('StageLightsPainter (floor pools)', () {
    testWidgets('each pool lands its own gel colour at its floor anchor', (
      tester,
    ) async {
      await tester.runAsync(() async {
        // Reduced motion pins the pools on their anchors (0.30/0.50/0.70). At
        // t=0 light i shows gel colour i, so each pool centre must read closest
        // to its OWN gel among the three (palette-agnostic).
        const rig = StageLightRig();
        final bytes = await _render(_painter(reducedMotion: true));
        for (var i = 0; i < rig.count; i++) {
          final sampled = _at(bytes, rig.anchors[i], _poolY);
          var best = 0;
          var bestDist = double.infinity;
          for (var j = 0; j < rig.colors.length; j++) {
            final d = _dist(sampled, rig.colors[j]);
            if (d < bestDist) {
              bestDist = d;
              best = j;
            }
          }
          expect(best, i, reason: 'pool $i should read as gel $i');
          expect(_lum(sampled), greaterThan(0.05), reason: 'pool $i is lit');
        }
      });
    });

    testWidgets('a designated lead crushes the flanking backup pools', (
      tester,
    ) async {
      await tester.runAsync(() async {
        // Same rig with vs without a designated lead. The flanking backup pools
        // (anchors 0 + 2) dim + desaturate under a lead so they stop out-glowing
        // it; with no designated lead every pool stays at full gel.
        const anchors = [0.30, 0.5, 0.70];
        final flat = await _render(
          const StageLightsPainter(
            time: 0,
            beat: 0,
            rig: StageLightRig(),
            reducedMotion: true,
          ),
        );
        final ranked = await _render(
          const StageLightsPainter(
            time: 0,
            beat: 0,
            rig: StageLightRig(leadGoldIndex: 1),
            reducedMotion: true,
          ),
        );
        for (final b in const [0, 2]) {
          expect(
            _lum(_at(ranked, anchors[b], _poolY)),
            lessThan(_lum(_at(flat, anchors[b], _poolY))),
            reason: 'backup pool $b is crushed under a designated lead',
          );
        }
      });
    });

    testWidgets('the beat boosts the pool brightness', (tester) async {
      await tester.runAsync(() async {
        // Both at time 0 (identical geometry — only the beat differs). Light 0
        // sits on its 0.30 anchor; the pool there is brighter on the beat.
        final calm = await _render(
          const StageLightsPainter(time: 0, beat: 0, rig: StageLightRig()),
        );
        final hit = await _render(
          const StageLightsPainter(time: 0, beat: 1, rig: StageLightRig()),
        );
        expect(
          _lum(_at(hit, 0.30, _poolY)),
          greaterThan(_lum(_at(calm, 0.30, _poolY))),
        );
      });
    });

    testWidgets('reduced motion renders a static frame across clock values', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final a = await _render(
          const StageLightsPainter(
            time: 0,
            beat: 1,
            rig: StageLightRig(),
            reducedMotion: true,
          ),
        );
        final b = await _render(
          const StageLightsPainter(
            time: 9.5,
            beat: 0.3,
            rig: StageLightRig(),
            reducedMotion: true,
          ),
        );
        expect(a, equals(b));
      });
    });

    testWidgets('position overrides relocate a pool to track its dancer', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final bytes = await _render(
          const StageLightsPainter(
            time: 0,
            beat: 0,
            rig: StageLightRig(count: 1, anchors: [0.25]),
            aimX: [0.78],
            footY: [0.82],
          ),
        );
        // The single pool now lands at 0.78, not at its 0.25 home anchor.
        expect(_lum(_at(bytes, 0.78, _poolY)), greaterThan(0.05));
        expect(
          _lum(_at(bytes, 0.25, _poolY)),
          lessThan(_lum(_at(bytes, 0.78, _poolY))),
        );
      });
    });

    testWidgets('lazily follows the dancer anchor — lag, then converge', (
      tester,
    ) async {
      await tester.runAsync(() async {
        tester.view.physicalSize = const Size(200, 200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        Widget tree(double ax) => MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: key,
            child: ColoredBox(
              color: const Color(0xFF000000),
              child: StageLightsOverlay(
                timeSeconds: 0,
                rig: const StageLightRig(count: 1, anchors: [0.2]),
                dancerAnchors: [Offset(ax, 0.82)],
              ),
            ),
          ),
        );
        Future<Uint8List> cap() async {
          final b =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final img = await b.toImage();
          final bytes = (await img.toByteData())!.buffer.asUint8List();
          img.dispose();
          return bytes;
        }

        // Init the pool on 0.2, then jump the dancer to 0.8.
        await tester.pumpWidget(tree(0.2));
        await tester.pumpWidget(tree(0.8));
        final afterOne = await cap();
        for (var i = 0; i < 80; i++) {
          await tester.pumpWidget(tree(0.8));
        }
        final converged = await cap();
        // The pool arrives at the dancer over time — but not on the first frame
        // (a lazy follow lag, not a rigid snap).
        expect(
          _lum(_at(converged, 0.8, _poolY)),
          greaterThan(_lum(_at(afterOne, 0.8, _poolY))),
        );
        expect(_lum(_at(converged, 0.8, _poolY)), greaterThan(0.05));
      });
    });

    test('no-ops without throwing for an empty size', () {
      final recorder = ui.PictureRecorder();
      expect(
        () => _painter().paint(Canvas(recorder), Size.zero),
        returnsNormally,
      );
      recorder.endRecording().dispose();
    });

    test('shouldRepaint tracks clock, beat and reduced-motion changes', () {
      const base = StageLightsPainter(time: 0, beat: 0, rig: StageLightRig());
      expect(
        base.shouldRepaint(
          const StageLightsPainter(time: 1, beat: 0, rig: StageLightRig()),
        ),
        isTrue,
      );
      expect(
        base.shouldRepaint(
          const StageLightsPainter(
            time: 0,
            beat: 0,
            rig: StageLightRig(),
            footY: [0.5],
          ),
        ),
        isTrue,
      );
      expect(base.shouldRepaint(base), isFalse);
    });
  });
}
