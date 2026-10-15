import 'dart:ui' as ui;
import 'dart:ui';

import 'package:lotti/features/companion/rig/paint_kit.dart';

/// The dark stage she stands on in the pitch videos: a navy ground that
/// deepens to the floor, a soft light behind her, a shadow under her feet
/// and a vignette at the edges.
///
/// Like her own colours, these are the illustration's, sampled from the
/// videos, not interface colours.
abstract final class CompanionStage {
  static const top = Color(0xFF16131C);
  static const bottom = Color(0xFF0A0B13);
  static const light = Color(0x8C262B3D);

  /// The ground and the light behind her, over the whole view; [figure] is
  /// the character-space point the light centres on, already mapped to the
  /// view.
  static void paintGround(Canvas canvas, Size size, Offset figure, double r) {
    final all = Offset.zero & size;
    canvas
      ..drawRect(
        all,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset.zero,
            Offset(0, size.height),
            const [top, bottom],
          ),
      )
      ..drawRect(
        all,
        Paint()
          ..shader = ui.Gradient.radial(figure, r, [
            light,
            light.withValues(alpha: 0),
          ]),
      );
  }

  /// The soft shadow under her feet, in character space (origin on the
  /// floor between them).
  static void paintFloorShadow(Canvas canvas) {
    canvas
      ..save()
      ..translate(0, 2)
      ..scale(95, 16);
    final paint = Paint()
      ..shader = ui.Gradient.radial(Offset.zero, 1, const [
        Color(0x8C000000),
        Color(0x00000000),
      ]);
    canvas
      ..drawPath(circle(Offset.zero, 1), paint)
      ..restore();
  }

  /// Darkens the edges of the view.
  static void paintVignette(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final r = size.longestSide * 0.75;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(
          centre,
          r,
          const [Color(0x00000000), Color(0x00000000), Color(0x59000000)],
          const [0, 0.55, 1],
        ),
    );
  }
}
