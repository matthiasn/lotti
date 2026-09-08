import 'dart:math' as math;
import 'dart:ui';

import 'package:lotti/classes/relationship_data.dart';

/// The geometry behind an [AvatarCrop]: how a `BoxFit.cover` picture at
/// alignment `(x, y)` and zoom `scale` sits inside a square of side
/// [diameter], and how a drag or a pinch moves it.
///
/// Pure, and shared by everything that draws or edits a crop — the crop
/// surface, its live 40 px preview and `PersonaAvatar` itself — so the
/// framing a user chooses is the framing every avatar renders. The numbers
/// it produces are fractions of the picture, which is what makes one crop
/// valid at every size the avatar is drawn at: the surface edits at a large
/// diameter, the list draws at 40, and the same [AvatarCrop] means the same
/// face in both.
///
/// The model is exactly the renderer's: the picture is cover-fitted into the
/// square, its overflow placed by the alignment (`0` hugs the leading edge,
/// `1` the trailing edge, `0.5` centres), and then scaled about the same
/// alignment point. Scaling a covering picture about a point inside the
/// square keeps it covering the square, which is why any alignment in
/// `0…1` at any zoom in `1…4` shows a full circle — the invariant
/// [visibleFraction] makes testable.
class AvatarCropGeometry {
  const AvatarCropGeometry({required this.imageSize, required this.diameter})
    : assert(diameter > 0, 'the square needs a side');

  /// The picture's size in its own pixels.
  final Size imageSize;

  /// The side of the square the circle is inscribed in, in logical pixels.
  final double diameter;

  /// The picture once cover-fitted into the square, before zoom: its short
  /// side equals [diameter], its long side overflows.
  Size get coveredSize {
    if (imageSize.width <= 0 || imageSize.height <= 0) {
      return Size.square(diameter);
    }
    final k = math.max(
      diameter / imageSize.width,
      diameter / imageSize.height,
    );
    return Size(imageSize.width * k, imageSize.height * k);
  }

  /// How far the picture, zoomed by [scale], overflows the square on each
  /// axis — the distance a drag can travel. Never negative: a covering
  /// picture is at least the square's size.
  Offset overflow(double scale) {
    final covered = coveredSize;
    return Offset(
      math.max(0, covered.width * scale - diameter),
      math.max(0, covered.height * scale - diameter),
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
  /// alignment point, so the part of the face under the fingers stays under
  /// the fingers. Clamped to the range the surface offers.
  static AvatarCrop zoomBy(AvatarCrop crop, double factor) =>
      crop.copyWith(scale: crop.scale * factor).clamped;

  /// The part of the picture the square shows, as fractions of the picture
  /// on each axis — `Rect.fromLTRB(0, 0, 1, 1)` would be all of it.
  ///
  /// This is the renderer's arithmetic run backwards: a point of the square
  /// comes from the point of the cover-fitted picture that the zoom about
  /// the alignment maps onto it. Inside `0…1` on both axes means the square
  /// — and so the circle inscribed in it — shows picture everywhere.
  Rect visibleFraction(AvatarCrop crop) {
    final covered = coveredSize;
    final room = overflow(1);
    final scale = crop.scale;
    // Where the zoom pivots, in square pixels — the alignment point.
    final px = crop.x * diameter;
    final py = crop.y * diameter;
    // The cover-fitted picture's leading edges, in square pixels: the
    // alignment places that fraction of the overflow before the square.
    final leftEdge = -crop.x * room.dx;
    final topEdge = -crop.y * room.dy;
    // The square's [0, diameter] pulled back through the zoom about the
    // pivot, then expressed as a fraction of the cover-fitted picture.
    return Rect.fromLTRB(
      ((px - px / scale) - leftEdge) / covered.width,
      ((py - py / scale) - topEdge) / covered.height,
      ((px + (diameter - px) / scale) - leftEdge) / covered.width,
      ((py + (diameter - py) / scale) - topEdge) / covered.height,
    );
  }
}
