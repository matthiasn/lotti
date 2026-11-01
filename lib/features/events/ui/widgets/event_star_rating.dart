import 'package:lotti/features/design_system/components/ds_quiet_ink.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/colors.dart';
import 'package:material_ui/material_ui.dart';

/// The event hero's 0–5 star rating, sized to sit in the same row as the
/// category and status pills.
///
/// Each star is its own quiet target: hovering one lifts that star alone, and
/// nothing is painted around the row as a whole. A tap sets the rating to that
/// star and a long press to the half below it, so half ratings stay reachable.
/// With [onRatingChanged] null the stars are a read-only display with no
/// targets at all.
class EventStarRating extends StatelessWidget {
  const EventStarRating({
    required this.rating,
    this.onRatingChanged,
    this.size = 20,
    super.key,
  });

  /// The current rating, 0–5 in steps of 0.5.
  final double rating;

  /// Receives the new rating; null renders the stars read-only.
  final ValueChanged<double>? onRatingChanged;

  /// Glyph size of one star.
  final double size;

  static const int starCount = 5;

  /// How far the hovered star grows: enough to read as "this one", small
  /// enough not to collide with its neighbour.
  static const double hoverScale = 1.2;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < starCount; index++)
          _Star(
            index: index,
            fill: _fillFor(index),
            size: size,
            onRatingChanged: onRatingChanged,
          ),
      ],
    );
  }

  /// Full, half or empty for the star at [index] under the current [rating].
  StarFill _fillFor(int index) {
    if (rating >= index + 1) return StarFill.full;
    if (rating > index) return StarFill.half;
    return StarFill.empty;
  }
}

/// How much of one star the rating covers.
enum StarFill { empty, half, full }

class _Star extends StatelessWidget {
  const _Star({
    required this.index,
    required this.fill,
    required this.size,
    required this.onRatingChanged,
  });

  final int index;
  final StarFill fill;
  final double size;
  final ValueChanged<double>? onRatingChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final onRatingChanged = this.onRatingChanged;
    final star = index + 1;

    Widget glyphFor({required bool highlighted}) => Padding(
      padding: EdgeInsets.all(tokens.spacing.step1),
      child: AnimatedScale(
        scale: highlighted ? EventStarRating.hoverScale : 1,
        duration: reduceMotion ? Duration.zero : MotionDurations.short3,
        curve: MotionCurves.standard,
        child: _StarGlyph(fill: fill, size: size),
      ),
    );

    if (onRatingChanged == null) {
      return ExcludeSemantics(child: glyphFor(highlighted: false));
    }

    return Semantics(
      button: true,
      label: context.messages.eventsRatingStarLabel(
        star,
        EventStarRating.starCount,
      ),
      excludeSemantics: true,
      child: DsQuietInk(
        customBorder: const CircleBorder(),
        onTap: () => onRatingChanged(star.toDouble()),
        onLongPress: () => onRatingChanged(star - 0.5),
        builder: (context, highlighted) => glyphFor(highlighted: highlighted),
      ),
    );
  }
}

/// One star in the token glyphs: the filled silhouette, the outline, or —
/// since the filled font has no half glyph — the outline with the filled
/// silhouette clipped to its leading half.
class _StarGlyph extends StatelessWidget {
  const _StarGlyph({required this.fill, required this.size});

  final StarFill fill;
  final double size;

  @override
  Widget build(BuildContext context) {
    final outline = Icon(LottiIcons.star, size: size, color: starredGold);
    final filled = Icon(LottiIconsFilled.star, size: size, color: starredGold);
    return switch (fill) {
      StarFill.full => filled,
      StarFill.empty => outline,
      StarFill.half => Stack(
        children: [
          outline,
          ClipRect(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: 0.5,
              child: filled,
            ),
          ),
        ],
      ),
    };
  }
}
