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

  testWidgets('modulate pulls the bitmap down in exposure and cools it', (
    tester,
  ) async {
    await tester.runAsync(() async {
      const key = 'yacht';
      // A white source so the per-channel multiply is directly readable.
      final source = await _solid(const Color(0xFFFFFFFF), 8, 8);
      final ctx = BackdropContext(
        size: const Size(40, 30),
        timeSeconds: 0,
        palette: kBlueHourPalette,
        images: {key: source},
      );

      Future<Color> centreOf(ImageLayer layer) async {
        final recorder = ui.PictureRecorder();
        layer.paint(Canvas(recorder), ctx);
        final out = await recorder.endRecording().toImage(40, 30);
        final bytes = (await out.toByteData())!.buffer.asUint8List();
        out.dispose();
        const i = (15 * 40 + 20) * 4;
        return Color.fromARGB(
          bytes[i + 3],
          bytes[i],
          bytes[i + 1],
          bytes[i + 2],
        );
      }

      final plain = await centreOf(const ImageLayer(key));
      // A cool blue-grey multiply: darkens all channels, red most, blue least.
      final dimmed = await centreOf(
        const ImageLayer(key, modulate: Color(0xFF8696B0)),
      );

      // Pulled down in exposure (every channel below the white source)...
      expect(dimmed.r, lessThan(plain.r));
      expect(dimmed.g, lessThan(plain.g));
      expect(dimmed.b, lessThan(plain.b));
      // ...and cooled: blue survives more than red, so the hull reads cooler.
      expect(dimmed.b, greaterThan(dimmed.r));
      // Opaque areas stay opaque (the modulate colour is opaque).
      expect(dimmed.a, 1.0);

      source.dispose();
    });
  });

  testWidgets('blurSigma softens a hard edge into a gradient', (tester) async {
    await tester.runAsync(() async {
      const key = 'yacht';
      // A vertical hard edge: left half black, right half white.
      final recorder0 = ui.PictureRecorder();
      Canvas(recorder0)
        ..drawRect(
          const Rect.fromLTWH(0, 0, 20, 16),
          Paint()..color = const Color(0xFF000000),
        )
        ..drawRect(
          const Rect.fromLTWH(20, 0, 20, 16),
          Paint()..color = const Color(0xFFFFFFFF),
        );
      final source = await recorder0.endRecording().toImage(40, 16);
      final ctx = BackdropContext(
        size: const Size(40, 16),
        timeSeconds: 0,
        palette: kBlueHourPalette,
        images: {key: source},
      );

      Future<List<int>> rowOf(ImageLayer layer) async {
        final recorder = ui.PictureRecorder();
        // Paint over a mid-grey so the blur has neutral surround.
        final canvas = Canvas(recorder)
          ..drawRect(
            const Rect.fromLTWH(0, 0, 40, 16),
            Paint()..color = const Color(0xFF808080),
          );
        layer.paint(canvas, ctx);
        final out = await recorder.endRecording().toImage(40, 16);
        final bytes = (await out.toByteData())!.buffer.asUint8List();
        out.dispose();
        return [for (var x = 0; x < 40; x++) bytes[(8 * 40 + x) * 4]];
      }

      final sharp = await rowOf(const ImageLayer(key));
      final blurred = await rowOf(const ImageLayer(key, blurSigma: 3));

      // Sharp: the edge column (x=19→20) jumps nearly black→white in one step.
      expect(sharp[20] - sharp[19], greaterThan(150));
      // Blurred: that same step is spread out, so the single-column jump is far
      // smaller and the transition band carries intermediate greys.
      expect(blurred[20] - blurred[19], lessThan(sharp[20] - sharp[19]));
      expect(blurred[17], greaterThan(sharp[17])); // black side lifted by blur
      expect(blurred[23], lessThan(sharp[23])); // white side pulled down

      source.dispose();
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
