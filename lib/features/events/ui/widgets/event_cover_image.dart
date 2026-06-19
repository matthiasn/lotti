import 'package:flutter/material.dart';

/// Scrim treatment painted over an event cover photo.
enum EventCoverScrim {
  /// No darkening — for inline thumbnails.
  none,

  /// Light bottom fade so a chip/rating reads over the lower edge.
  card,

  /// Strong bottom fade + a faint top fade, for the detail hero where a white
  /// title and toolbar icons must stay legible over any photo.
  hero,
}

/// Renders an event's cover photo cropped to fill its box, with an optional
/// scrim for overlaid content. When no [image] is provided it falls back to a
/// calm category-tinted gradient with a faint glyph, so a cover-less event
/// still looks deliberate rather than empty.
///
/// The crop math mirrors the task cover-art treatment: [cropX] in `0..1` maps to
/// a horizontal [Alignment] of `cropX * 2 - 1` under [BoxFit.cover].
class EventCoverImage extends StatelessWidget {
  const EventCoverImage({
    required this.image,
    required this.fallbackColor,
    this.cropX = 0.5,
    this.icon = Icons.event_rounded,
    this.scrim = EventCoverScrim.card,
    this.child,
    super.key,
  });

  final ImageProvider? image;
  final Color fallbackColor;
  final double cropX;
  final IconData icon;
  final EventCoverScrim scrim;

  /// Overlaid content (chips, title, rating). Positioned by the caller.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final alignmentX = (cropX * 2) - 1;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (image != null)
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            alignment: Alignment(alignmentX, 0),
            child: Image(image: image!),
          )
        else
          _Fallback(color: fallbackColor, icon: icon),
        if (scrim == EventCoverScrim.hero) ...[
          // Faint global darken so the title holds contrast over any photo,
          // however bright the crop.
          const ColoredBox(color: Color(0x26000000)),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.2],
                colors: [Color(0x59000000), Color(0x00000000)],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.15, 1],
                colors: [Color(0x00000000), Color(0xE6000000)],
              ),
            ),
          ),
        ] else if (scrim == EventCoverScrim.card)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.5, 1],
                colors: [Color(0x00000000), Color(0x99000000)],
              ),
            ),
          ),
        ?child,
      ],
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(color.withValues(alpha: 0.55), Colors.black),
            Color.alphaBlend(color.withValues(alpha: 0.18), Colors.black),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          size: 56,
          color: Colors.white.withValues(alpha: 0.16),
        ),
      ),
    );
  }
}
