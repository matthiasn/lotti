import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:lotti/features/scenery/layers/backdrop_layer.dart';
import 'package:lotti/features/scenery/layers/city_lights_layer.dart'
    show coverFit;

/// Warm lantern light pooling on the foreground deck. The painted deck lanterns
/// (`foreground.png`) sit with dark glass; this additive pass lights each one
/// with a hot warm core inside the glass and a soft warm pool spilling down onto
/// the planks, so the lower third reads as a lit foreground plane instead of a
/// dead black void. It is drawn AFTER the deck bitmap (otherwise the planks
/// would occlude it) and behind the dancers, with [BlendMode.plus] so it only
/// adds glow.
///
/// Anchors are normalized 0..1 in the master art's cover-fit space (the SAME
/// [coverFit] mapping every other layer uses), so the pools pin to the painted
/// lanterns at any viewport aspect ratio.
class DeckGlowLayer implements BackdropLayer {
  const DeckGlowLayer({
    this.lanterns = kDeckLanterns,
    this.poolRadiusFraction = 0.17,
    this.intensity = 0.85,
    this.deckTop = 0.66,
    this.sheen = 0.5,
  });

  /// Normalized lantern positions in cover-fit art space.
  final List<Offset> lanterns;

  /// Pool radius as a fraction of the cover-fit art width.
  final double poolRadiusFraction;

  /// Overall warm-glow strength (0 = off).
  final double intensity;

  /// Normalized art-y where the deck/dock edge meets the water — the cool
  /// sky-sheen band sits just below it (the wet, grazing-angle planks).
  final double deckTop;

  /// Strength of the cool plank sheen reflecting the dusk sky (0 = off).
  final double sheen;

  @override
  void paint(Canvas canvas, BackdropContext ctx) {
    if (lanterns.isEmpty && sheen <= 0) return;
    final cover = coverFit(ctx.size);
    _paintSheen(canvas, ctx, cover);
    if (intensity <= 0 || lanterns.isEmpty) return;
    final warm = ctx.palette.yachtCabinGlow; // ~2700 K lantern interior
    final radius = cover.width * poolRadiusFraction;
    // The lit-flame core stays GLASS-sized regardless of how wide the spill
    // pool is, so widening the pool never turns the lamp into a blob.
    final coreR = cover.width * 0.013;
    for (final l in lanterns) {
      final lamp = Offset(
        cover.left + l.dx * cover.width,
        cover.top + l.dy * cover.height,
      );
      // Pool centred well below the lamp: warm light spills DOWN and OUT across
      // the planks, falling off smoothly so it never reads as a hard disc.
      final pool = lamp.translate(0, radius * 0.42);
      canvas
        ..drawCircle(
          pool,
          radius,
          Paint()
            ..blendMode = BlendMode.plus
            ..shader = ui.Gradient.radial(
              pool,
              radius,
              [
                warm.withValues(alpha: 0.22 * intensity),
                warm.withValues(alpha: 0.09 * intensity),
                warm.withValues(alpha: 0),
              ],
              [0.0, 0.45, 1.0],
            ),
        )
        // Hot core inside the lantern glass so the lamp itself reads as lit —
        // a soft radial glow (not a hard disc) so it looks like a flame behind
        // glass, brightest at the wick and feathering to the frame.
        ..drawCircle(
          lamp,
          coreR,
          Paint()
            ..blendMode = BlendMode.plus
            ..shader = ui.Gradient.radial(
              lamp,
              coreR,
              [
                Color.lerp(
                  warm,
                  const Color(0xFFFFF3E0),
                  0.5,
                )!.withValues(alpha: 0.95 * intensity),
                warm.withValues(alpha: 0.35 * intensity),
                warm.withValues(alpha: 0),
              ],
              [0.0, 0.45, 1.0],
            ),
        );
      _paintStreak(canvas, lamp, cover.width, warm);
    }
  }

  /// A thin horizontal anamorphic streak through the lamp — a lens/film light
  /// signature that makes the flame read as an emissive SOURCE rather than a
  /// flat disc. A radial glow squashed vertically into a horizontal sliver.
  void _paintStreak(Canvas canvas, Offset lamp, double coverWidth, Color warm) {
    final len = coverWidth * 0.05;
    canvas
      ..save()
      ..translate(lamp.dx, lamp.dy)
      ..scale(1, 0.16)
      ..drawCircle(
        Offset.zero,
        len,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = ui.Gradient.radial(
            Offset.zero,
            len,
            [
              Color.lerp(
                warm,
                const Color(0xFFFFF3E0),
                0.5,
              )!.withValues(alpha: 0.5 * intensity),
              warm.withValues(alpha: 0.12 * intensity),
              warm.withValues(alpha: 0),
            ],
            [0.0, 0.4, 1.0],
          ),
      )
      ..restore();
  }

  /// A cool dusk-sky reflection along the wet, grazing-angle planks at the
  /// deck's water edge: lifts the foreground out of dead black and reads the
  /// floor as a polished, reflective surface. Ramps in just under the edge,
  /// peaks, then fades a sixth of the deck down. Additive, so it only lifts.
  void _paintSheen(Canvas canvas, BackdropContext ctx, Rect cover) {
    if (sheen <= 0) return;
    final top = cover.top + deckTop * cover.height;
    final fadeEnd = cover.top + (deckTop + 0.16) * cover.height;
    const cool = Color(0xFF2A4A66); // desaturated dusk-sky blue
    canvas.drawRect(
      Rect.fromLTRB(cover.left, top, cover.right, fadeEnd),
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.linear(
          Offset(0, top),
          Offset(0, fadeEnd),
          [
            cool.withValues(alpha: 0),
            cool.withValues(alpha: 0.16 * sheen),
            cool.withValues(alpha: 0),
          ],
          [0.0, 0.2, 1.0],
        ),
    );
  }
}

/// The two painted deck lanterns in `foreground.png`, normalized in cover-fit
/// art space (left rail post and right rail post). Measured from the rendered
/// plate; they frame the foreground symmetrically.
const List<Offset> kDeckLanterns = [
  Offset(0.096, 0.722),
  Offset(0.922, 0.720),
];
