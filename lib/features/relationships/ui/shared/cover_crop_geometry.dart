import 'dart:math' as math;
import 'dart:ui';

import 'package:lotti/classes/relationship_data.dart';

/// The geometry behind a `BoxFit.cover` crop: how a picture at alignment
/// `(x, y)` and zoom `scale` sits inside a [viewport], and how a drag or a
/// pinch moves it.
///
/// Pure, and shared by everything that draws or edits a crop — the avatar
/// crop surface and its live 40 px preview, `PersonaAvatar` itself, and the
/// banner's drag-to-reposition — so the framing a user chooses is the framing
/// every surface renders. The numbers it produces are fractions of the
/// picture, which is what makes one crop valid at every size a surface is
/// drawn at: the avatar edits at a large circle and the list draws at 40, the
/// banner edits in the form's card and the hero draws it across the pane, and
/// in each pair the same crop means the same framing.
///
/// The model is exactly the renderer's: the picture is cover-fitted into the
/// viewport, its overflow placed by the alignment (`0` hugs the leading edge,
/// `1` the trailing edge, `0.5` centres), and then scaled about the same
/// alignment point. Scaling a covering picture about a point inside the
/// viewport keeps it covering the viewport, which is why any alignment in
/// `0…1` at any zoom in `1…4` shows a full viewport — the invariant
/// [visibleFraction] makes testable.
class CoverCropGeometry {
  /// [viewport] must have an area; a zero side is a layout that has not
  /// happened yet, and a host waits for it rather than dividing by it.
  const CoverCropGeometry({required this.imageSize, required this.viewport});

  /// A circle of [diameter] — the avatar's case. The circle is inscribed in
  /// the square, and a square that shows picture everywhere does so inside
  /// the circle too.
  factory CoverCropGeometry.circle({
    required Size imageSize,
    required double diameter,
  }) =>
      CoverCropGeometry(imageSize: imageSize, viewport: Size.square(diameter));

  /// The picture's size in its own pixels.
  final Size imageSize;

  /// The box the picture is cover-fitted into, in logical pixels.
  final Size viewport;

  /// The picture once cover-fitted into the viewport, before zoom: one side
  /// meets the viewport's, the other overflows.
  Size get coveredSize {
    if (imageSize.width <= 0 || imageSize.height <= 0) {
      return viewport;
    }
    final k = math.max(
      viewport.width / imageSize.width,
      viewport.height / imageSize.height,
    );
    return Size(imageSize.width * k, imageSize.height * k);
  }

  /// How far the picture, zoomed by [scale], overflows the viewport on each
  /// axis — the distance a drag can travel. Never negative: a covering
  /// picture is at least the viewport's size.
  Offset overflow(double scale) {
    final covered = coveredSize;
    return Offset(
      math.max(0, covered.width * scale - viewport.width),
      math.max(0, covered.height * scale - viewport.height),
    );
  }

  /// The crop after dragging the picture by [delta] logical pixels: it
  /// follows the finger, and stops at its own edge.
  ///
  /// An axis with no overflow cannot move — a landscape picture at the
  /// widest zoom already shows its full height — and is left alone rather
  /// than snapped.
  AvatarCrop panBy(AvatarCrop crop, Offset delta) {
    final room = overflow(crop.scale);
    return crop
        .copyWith(
          x: room.dx > 0 ? crop.x - delta.dx / room.dx : crop.x,
          y: room.dy > 0 ? crop.y - delta.dy / room.dy : crop.y,
        )
        .clamped;
  }

  /// The crop zoomed by [factor] (above `1` zooms in) about its own
  /// alignment point, so the part of the picture under the fingers stays
  /// under the fingers. Clamped to the range the surface offers.
  static AvatarCrop zoomBy(AvatarCrop crop, double factor) =>
      crop.copyWith(scale: crop.scale * factor).clamped;

  /// The part of the picture the viewport shows, as fractions of the picture
  /// on each axis — `Rect.fromLTRB(0, 0, 1, 1)` would be all of it.
  ///
  /// This is the renderer's arithmetic run backwards: a point of the viewport
  /// comes from the point of the cover-fitted picture that the zoom about the
  /// alignment maps onto it. Inside `0…1` on both axes means the viewport
  /// shows picture everywhere.
  Rect visibleFraction(AvatarCrop crop) {
    final covered = coveredSize;
    final room = overflow(1);
    final scale = crop.scale;
    // Where the zoom pivots, in viewport pixels — the alignment point.
    final px = crop.x * viewport.width;
    final py = crop.y * viewport.height;
    // The cover-fitted picture's leading edges, in viewport pixels: the
    // alignment places that fraction of the overflow before the viewport.
    final leftEdge = -crop.x * room.dx;
    final topEdge = -crop.y * room.dy;
    // The viewport pulled back through the zoom about the pivot, then
    // expressed as a fraction of the cover-fitted picture.
    return Rect.fromLTRB(
      ((px - px / scale) - leftEdge) / covered.width,
      ((py - py / scale) - topEdge) / covered.height,
      ((px + (viewport.width - px) / scale) - leftEdge) / covered.width,
      ((py + (viewport.height - py) / scale) - topEdge) / covered.height,
    );
  }
}
