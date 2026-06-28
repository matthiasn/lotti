import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/scenery/layers/backdrop_layer.dart';
import 'package:lotti/features/scenery/layers/vignette_layer.dart';
import 'package:lotti/features/scenery/model/backdrop_palette.dart';

const _w = 160;
const _h = 90;

// Render a flat white field, then multiply the vignette over it, so the darkened
// corners are directly readable as the surviving luminance.
Future<Uint8List> _renderOverWhite(VignetteLayer layer) async {
  final ctx = BackdropContext(
    size: Size(_w.toDouble(), _h.toDouble()),
    timeSeconds: 0,
    palette: kBlueHourPalette,
  );
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..drawRect(
      Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble()),
      Paint()..color = const Color(0xFFFFFFFF),
    );
  layer.paint(canvas, ctx);
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
  group('VignetteLayer', () {
    testWidgets('keeps the focal centre bright and sinks the corners', (
      tester,
    ) async {
      await tester.runAsync(() async {
        const layer = VignetteLayer();
        final bytes = await _renderOverWhite(layer);

        // Focal centre (0.5, 0.42) survives the multiply at ~full white.
        final centre = _at(bytes, (_w * 0.5).round(), (_h * 0.42).round());
        expect(centre.r, greaterThan(0.95));
        expect(centre.a, 1.0);

        // The far corner is darkened relative to the centre.
        final corner = _at(bytes, _w - 1, _h - 1);
        expect(corner.r, lessThan(centre.r));
        // The drop is gentle (a vignette, not a black frame).
        expect(corner.r, greaterThan(0.6));
        // Neutral darkening: it multiplies all channels equally.
        expect((corner.r - corner.g).abs(), lessThan(0.02));
        expect((corner.r - corner.b).abs(), lessThan(0.02));
      });
    });

    testWidgets('deeper strength sinks the corners further', (tester) async {
      await tester.runAsync(() async {
        final soft = await _renderOverWhite(const VignetteLayer(strength: 0.1));
        final hard = await _renderOverWhite(const VignetteLayer(strength: 0.5));
        final softCorner = _at(soft, _w - 1, _h - 1).r;
        final hardCorner = _at(hard, _w - 1, _h - 1).r;
        expect(hardCorner, lessThan(softCorner));
      });
    });

    testWidgets('zero strength leaves the field untouched', (tester) async {
      await tester.runAsync(() async {
        final bytes = await _renderOverWhite(const VignetteLayer(strength: 0));
        expect(_at(bytes, _w - 1, _h - 1).r, greaterThan(0.99));
        expect(_at(bytes, _w ~/ 2, _h ~/ 2).r, greaterThan(0.99));
      });
    });

    test('no-ops without throwing for an empty viewport', () {
      const layer = VignetteLayer();
      const ctx = BackdropContext(
        size: Size.zero,
        timeSeconds: 0,
        palette: kBlueHourPalette,
      );
      final recorder = ui.PictureRecorder();
      expect(() => layer.paint(Canvas(recorder), ctx), returnsNormally);
      recorder.endRecording().dispose();
    });
  });
}
