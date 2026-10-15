import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// A canvas drawing rasterised to RGBA, for asserting what the companion's
/// painters put where.
///
/// `Picture.toImage` completes on the real event loop, so call this from a
/// plain `test()` (or inside `tester.runAsync`), never from a fake-async
/// widget test body — see test/README.md, "Image decoding never completes
/// inside testWidgets".
class Raster {
  Raster._(this.width, this.height, this._bytes);

  final int width;
  final int height;
  final ByteData _bytes;

  /// Paints [draw] on a [width] × [height] canvas cleared to [background].
  static Future<Raster> of(
    int width,
    int height,
    void Function(Canvas canvas) draw, {
    Color background = const Color(0xFF000000),
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..drawColor(background, BlendMode.src);
    draw(canvas);
    final image = await recorder.endRecording().toImage(width, height);
    final bytes = await image.toByteData();
    image.dispose();
    return Raster._(width, height, bytes!);
  }

  /// The colour at pixel (x, y), opaque.
  Color at(num x, num y) {
    final i = (y.round() * width + x.round()) * 4;
    return Color.fromARGB(
      255,
      _bytes.getUint8(i),
      _bytes.getUint8(i + 1),
      _bytes.getUint8(i + 2),
    );
  }

  List<Offset> _matches(Color colour, int tolerance) {
    final out = <Offset>[];
    final r = (colour.r * 255).round();
    final g = (colour.g * 255).round();
    final b = (colour.b * 255).round();
    for (var i = 0; i < width * height * 4; i += 4) {
      if ((_bytes.getUint8(i) - r).abs() <= tolerance &&
          (_bytes.getUint8(i + 1) - g).abs() <= tolerance &&
          (_bytes.getUint8(i + 2) - b).abs() <= tolerance) {
        final p = i ~/ 4;
        out.add(Offset((p % width).toDouble(), (p ~/ width).toDouble()));
      }
    }
    return out;
  }

  /// How many pixels are within [tolerance] per channel of [colour].
  int count(Color colour, {int tolerance = 6}) =>
      _matches(colour, tolerance).length;

  /// The mean position of the pixels of [colour], or null if there are none.
  Offset? centroid(Color colour, {int tolerance = 6}) {
    final m = _matches(colour, tolerance);
    if (m.isEmpty) return null;
    return m.reduce((a, b) => a + b) / m.length.toDouble();
  }
}

/// Whether [a] and [b] match within [tolerance] per channel.
bool near(Color a, Color b, {int tolerance = 6}) =>
    ((a.r - b.r) * 255).abs() <= tolerance &&
    ((a.g - b.g) * 255).abs() <= tolerance &&
    ((a.b - b.b) * 255).abs() <= tolerance;
