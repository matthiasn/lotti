import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:lotti/features/scenery/layers/backdrop_layer.dart';

/// Draws one decoded bitmap layer (a painted PNG) scaled to fill the backdrop.
///
/// The image is looked up in [BackdropContext.images] by [assetKey]; the layer
/// no-ops until that image has been decoded, so the scene degrades gracefully
/// while assets load. An optional horizontal [parallaxFraction] offsets the
/// layer with the scene camera for depth (0 = locked to the frame).
class ImageLayer implements BackdropLayer {
  const ImageLayer(
    this.assetKey, {
    this.opacity = 1,
    this.fit = BoxFit.cover,
    this.parallaxFraction = 0,
    this.modulate,
    this.blurSigma = 0,
  });

  /// Key into [BackdropContext.images] — an asset path from `SceneryAssets`.
  final String assetKey;

  /// 0..1 multiplier applied to the layer's alpha.
  final double opacity;

  /// How the image fills the backdrop rect.
  final BoxFit fit;

  /// Fraction of the width the layer drifts with parallax (reserved for the
  /// camera; 0 keeps it locked to the frame).
  final double parallaxFraction;

  /// Optional per-channel multiply ([BlendMode.modulate]) applied to the bitmap
  /// — i.e. the drawn pixels are scaled by `modulate / 255` per channel. Use it
  /// to pull a baked-bright structure DOWN in exposure and shift its temperature
  /// so it recedes into the midground (e.g. the over-exposed yacht hull), since
  /// the painted PNG can't be re-lit. Null leaves the bitmap untouched. The
  /// alpha channel is preserved (pass an opaque colour) so transparency holds.
  final Color? modulate;

  /// Optional Gaussian blur sigma (logical px) applied to the bitmap. A real
  /// defocus / aerial-haze softening: a midground structure baked at full
  /// sharpness reads as a foreground hero next to atmospherically-softened
  /// neighbours, so a couple of px of blur drops its high-frequency edge detail
  /// (portholes, rails, masts) onto its depth plane. 0 leaves it crisp.
  final double blurSigma;

  @override
  void paint(Canvas canvas, BackdropContext ctx) {
    final image = ctx.images[assetKey];
    if (image == null) return;
    final blurred = blurSigma > 0;
    if (blurred) {
      // Isolate so the blur feathers the bitmap's own alpha edge (its silhouette
      // softens into the scene) instead of smearing whatever was drawn behind.
      canvas.saveLayer(
        Offset.zero & ctx.size,
        Paint()
          ..imageFilter = ui.ImageFilter.blur(
            sigmaX: blurSigma,
            sigmaY: blurSigma,
          ),
      );
    }
    paintImage(
      canvas: canvas,
      rect: Offset.zero & ctx.size,
      image: image,
      fit: fit,
      opacity: opacity.clamp(0.0, 1.0),
      colorFilter: modulate == null
          ? null
          : ColorFilter.mode(modulate!, BlendMode.modulate),
    );
    if (blurred) canvas.restore();
  }
}
