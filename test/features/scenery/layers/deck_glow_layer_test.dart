import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/scenery/layers/backdrop_layer.dart';
import 'package:lotti/features/scenery/layers/deck_glow_layer.dart';
import 'package:lotti/features/scenery/model/backdrop_palette.dart';

// 16:9 viewport so the art cover-fits with no crop and normalized lantern
// anchors map straight onto pixels (anchor * size).
const _w = 160;
const _h = 90;

Future<Uint8List> _render(DeckGlowLayer layer) async {
  final ctx = BackdropContext(
    size: Size(_w.toDouble(), _h.toDouble()),
    timeSeconds: 0,
    palette: kBlueHourPalette,
  );
  final recorder = ui.PictureRecorder();
  layer.paint(Canvas(recorder), ctx);
  final out = await recorder.endRecording().toImage(_w, _h);
  final bytes = (await out.toByteData())!.buffer.asUint8List();
  out.dispose();
  return bytes;
}

Color _at(Uint8List bytes, int x, int y) {
  final i = (y * _w + x) * 4;
  return Color.fromARGB(bytes[i + 3], bytes[i], bytes[i + 1], bytes[i + 2]);
}

void main() {
  group('DeckGlowLayer', () {
    testWidgets('pools a warm lantern glow on its anchor, dark away from it', (
      tester,
    ) async {
      await tester.runAsync(() async {
        // Single lantern at the frame centre so the maths is obvious.
        const layer = DeckGlowLayer(lanterns: [Offset(0.5, 0.5)]);
        final bytes = await _render(layer);

        final lamp = _at(bytes, _w ~/ 2, _h ~/ 2);
        // The lamp core is lit and unmistakably WARM (amber: red > blue).
        expect(lamp.a, greaterThan(0));
        expect(lamp.r, greaterThan(0.2));
        expect(lamp.r, greaterThan(lamp.b));

        // A corner well outside the pool radius gets no glow.
        final corner = _at(bytes, 2, 2);
        expect(corner.a, lessThan(0.02));
      });
    });

    testWidgets('falls off from the hot core to the surrounding deck', (
      tester,
    ) async {
      await tester.runAsync(() async {
        const layer = DeckGlowLayer(lanterns: [Offset(0.5, 0.5)]);
        final bytes = await _render(layer);
        final core = _at(bytes, _w ~/ 2, _h ~/ 2);
        // A few px below the lamp sits in the spill pool, not the hot core.
        final spill = _at(bytes, _w ~/ 2, _h ~/ 2 + 12);
        expect(core.a, greaterThan(spill.a));
        expect(spill.a, greaterThan(0));
      });
    });

    testWidgets('renders nothing when intensity is zero', (tester) async {
      await tester.runAsync(() async {
        const layer = DeckGlowLayer(lanterns: [Offset(0.5, 0.5)], intensity: 0);
        final bytes = await _render(layer);
        expect(_at(bytes, _w ~/ 2, _h ~/ 2).a, 0);
      });
    });

    test('no-ops without throwing when there are no lanterns', () {
      const layer = DeckGlowLayer(lanterns: []);
      const ctx = BackdropContext(
        size: Size(10, 10),
        timeSeconds: 0,
        palette: kBlueHourPalette,
      );
      final recorder = ui.PictureRecorder();
      expect(() => layer.paint(Canvas(recorder), ctx), returnsNormally);
      recorder.endRecording().dispose();
    });

    test(
      'default lanterns are normalized and frame the deck symmetrically',
      () {
        expect(kDeckLanterns, hasLength(2));
        for (final l in kDeckLanterns) {
          expect(l.dx, inInclusiveRange(0, 1));
          expect(l.dy, inInclusiveRange(0, 1));
          // Lanterns sit low on the deck, in its lower half.
          expect(l.dy, greaterThan(0.5));
        }
        // One near each edge: left lantern well left of the right lantern.
        expect(kDeckLanterns.first.dx, lessThan(0.2));
        expect(kDeckLanterns.last.dx, greaterThan(0.8));
      },
    );
  });
}
