import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/scenery/layers/backdrop_layer.dart';
import 'package:lotti/features/scenery/layers/image_layer.dart';
import 'package:lotti/features/scenery/model/backdrop_palette.dart';

Future<ui.Image> _solid(Color color, int w, int h) {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    Paint()..color = color,
  );
  return recorder.endRecording().toImage(w, h);
}

void main() {
  testWidgets('draws the keyed image filling the backdrop rect', (
    tester,
  ) async {
    await tester.runAsync(() async {
      const key = 'master';
      final source = await _solid(const Color(0xFFFF0000), 8, 8);
      const layer = ImageLayer(key);
      final ctx = BackdropContext(
        size: const Size(40, 30),
        timeSeconds: 0,
        palette: kBlueHourPalette,
        images: {key: source},
      );

      final recorder = ui.PictureRecorder();
      layer.paint(Canvas(recorder), ctx);
      final out = await recorder.endRecording().toImage(40, 30);
      final bytes = (await out.toByteData())!.buffer.asUint8List();
      Color at(int x, int y) {
        final i = (y * 40 + x) * 4;
        return Color.fromARGB(
          bytes[i + 3],
          bytes[i],
          bytes[i + 1],
          bytes[i + 2],
        );
      }

      final center = at(20, 15);
      expect(center.r, greaterThan(0.5));
      expect(center.g, lessThan(0.2));
      expect(center.a, 1.0);

      source.dispose();
      out.dispose();
    });
  });

  test('no-ops without throwing when the image has not decoded yet', () {
    const layer = ImageLayer('missing');
    const ctx = BackdropContext(
      size: Size(10, 10),
      timeSeconds: 0,
      palette: kBlueHourPalette,
    );
    final recorder = ui.PictureRecorder();
    expect(() => layer.paint(Canvas(recorder), ctx), returnsNormally);
    recorder.endRecording().dispose();
  });
}
