import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Screen-fixed finishing texture for the staged scenery.
///
/// The layered backdrop itself can be panned/zoomed for camera parallax. This
/// pass deliberately does not live inside that transform: it adds a tiny film
/// grain and optional edge sink in final screen space, so side bands and
/// letterboxed camera moves get the same texture treatment as the centre.
class SceneTextureOverlay extends StatelessWidget {
  const SceneTextureOverlay({
    this.grainOpacity = 0.045,
    this.vignetteStrength = 0.06,
    super.key,
  });

  /// Alpha budget for the black/white grain points.
  final double grainOpacity;

  /// Additional screen-space edge darkening. Kept low because the scene already
  /// owns its art-directed vignette in the layer stack.
  final double vignetteStrength;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: SceneTexturePainter(
            grainOpacity: grainOpacity,
            vignetteStrength: vignetteStrength,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class SceneTexturePainter extends CustomPainter {
  const SceneTexturePainter({
    this.grainOpacity = 0.045,
    this.vignetteStrength = 0.06,
  });

  final double grainOpacity;
  final double vignetteStrength;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    _paintVignette(canvas, size);
    _paintGrain(canvas, size);
  }

  void _paintVignette(Canvas canvas, Size size) {
    final strength = vignetteStrength.clamp(0.0, 1.0);
    if (strength <= 0) return;
    final center = Offset(size.width * 0.5, size.height * 0.43);
    final radius = size.longestSide * 0.74;
    final edgeAlpha = (255 * strength).round();
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..blendMode = BlendMode.srcOver
        ..shader = ui.Gradient.radial(
          center,
          radius,
          [
            const Color(0x00000000),
            const Color(0x00000000),
            Color.fromARGB(edgeAlpha, 0, 0, 0),
          ],
          const [0.0, 0.62, 1.0],
        ),
    );
  }

  void _paintGrain(Canvas canvas, Size size) {
    final opacity = grainOpacity.clamp(0.0, 1.0);
    if (opacity <= 0) return;

    // Keep density proportional to the frame, but bounded. The point count is
    // intentionally modest: enough to break clean vertical strips, cheap enough
    // for the live audio demo.
    final count = (size.width * size.height / 1100).clamp(600, 1800).round();
    final dark = <Offset>[];
    final light = <Offset>[];

    for (var i = 0; i < count; i++) {
      final x = _unit(i, 17) * size.width;
      final y = _unit(i, 43) * size.height;
      final point = Offset(x.floorToDouble() + 0.5, y.floorToDouble() + 0.5);
      if (_unit(i, 89) < 0.55) {
        dark.add(point);
      } else {
        light.add(point);
      }
    }

    final darkAlpha = (255 * opacity).round();
    final lightAlpha = (255 * opacity * 0.75).round();
    if (dark.isNotEmpty) {
      canvas.drawPoints(
        ui.PointMode.points,
        dark,
        Paint()
          ..strokeWidth = 1
          ..color = Color.fromARGB(darkAlpha, 0, 0, 0),
      );
    }
    if (light.isNotEmpty) {
      canvas.drawPoints(
        ui.PointMode.points,
        light,
        Paint()
          ..strokeWidth = 1
          ..color = Color.fromARGB(lightAlpha, 255, 255, 255),
      );
    }
  }

  double _unit(int i, int salt) {
    var x = (i + 1) * 374761393 + salt * 668265263;
    x = (x ^ (x >> 13)) * 1274126177;
    x = x ^ (x >> 16);
    return (x & 0x7fffffff) / 0x7fffffff;
  }

  @override
  bool shouldRepaint(SceneTexturePainter oldDelegate) {
    return oldDelegate.grainOpacity != grainOpacity ||
        oldDelegate.vignetteStrength != vignetteStrength;
  }
}
