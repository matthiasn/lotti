import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Paints [inner] smooth-edged on any GPU: draws it at [factor] times the
/// device's pixels, then halves the image down, step by step, to size.
///
/// Every halving averages each 2 × 2 block of pixels into one (an exact 2:1
/// bilinear sample), so a factor of 4 gives each edge pixel 16 samples of
/// coverage. A renderer that draws paths without anti-aliasing (Impeller on
/// a GL driver with no multisampling, as in a Linux VM) otherwise shows her
/// outline as stair steps that crawl as she moves.
class SupersampledPainter extends CustomPainter {
  SupersampledPainter({
    required this.inner,
    required this.devicePixelRatio,
    this.factor = 4,
  }) : assert(
         factor >= 1 && (factor & (factor - 1)) == 0,
         'factor must be a power of two',
       );

  final CustomPainter inner;
  final double devicePixelRatio;

  /// Samples per device pixel along each axis: 1, 2, 4 or 8.
  final int factor;

  /// The largest texture side drawn; a big view takes a smaller factor.
  static const maxTextureSide = 4096;

  /// The factor actually used for a view of [pixels] device pixels: the
  /// requested one, halved until the texture fits.
  static int effectiveFactor(Size pixels, int requested) {
    var f = requested;
    while (f > 1 &&
        math.max(pixels.width, pixels.height) * f > maxTextureSide) {
      f ~/= 2;
    }
    return f;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final pixels = Size(
      (size.width * devicePixelRatio).ceilToDouble(),
      (size.height * devicePixelRatio).ceilToDouble(),
    );
    var f = effectiveFactor(pixels, factor);
    if (f == 1) {
      inner.paint(canvas, size);
      return;
    }
    final recorder = ui.PictureRecorder();
    final big = Canvas(recorder)..scale(devicePixelRatio * f);
    inner.paint(big, size);
    final picture = recorder.endRecording();
    var image = picture.toImageSync(
      (pixels.width * f).round(),
      (pixels.height * f).round(),
    );
    picture.dispose();
    while (f > 1) {
      f ~/= 2;
      final half = _halve(image, pixels * f.toDouble());
      image.dispose();
      image = half;
    }
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(
        0,
        0,
        pixels.width / devicePixelRatio,
        pixels.height / devicePixelRatio,
      ),
      Paint()..filterQuality = FilterQuality.low,
    );
    image.dispose();
  }

  static ui.Image _halve(ui.Image image, Size to) {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Offset.zero & to,
      Paint()..filterQuality = FilterQuality.low,
    );
    final picture = recorder.endRecording();
    final out = picture.toImageSync(to.width.round(), to.height.round());
    picture.dispose();
    return out;
  }

  @override
  bool shouldRepaint(SupersampledPainter oldDelegate) =>
      oldDelegate.factor != factor ||
      oldDelegate.devicePixelRatio != devicePixelRatio ||
      inner.shouldRepaint(oldDelegate.inner);
}
