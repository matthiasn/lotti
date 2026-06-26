import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Lays out [children] in a column and plays a one-time staggered entrance:
/// each child fades in and rises a few pixels, offset from the previous by
/// [interval], so a freshly loaded surface reads as *arriving* rather than
/// hard-appearing.
///
/// The motion runs once on first mount — flutter_animate keeps its controller
/// in element state, so a later rebuild from a background data refresh does not
/// replay it (the page must not re-animate when sync or a DB notification
/// fires). Inter-section spacing should be baked into the children (e.g. a
/// leading [Padding]) so every entry is a real section and the cascade timing
/// stays even.
///
/// Under reduced motion the children render immediately with no animation.
class StaggeredEntrance extends StatelessWidget {
  const StaggeredEntrance({
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.interval = const Duration(milliseconds: 70),
    this.duration = const Duration(milliseconds: 360),
    this.rise = 12.0,
    this.initialOpacity = 0,
    super.key,
  });

  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;

  /// Delay added per child, so they cascade rather than arrive together.
  final Duration interval;

  /// Duration of each child's fade + rise.
  final Duration duration;

  /// Pixels each child rises into place.
  final double rise;

  /// Starting opacity for each animated child. Keep the default at fully
  /// transparent for normal screen entrances; surfaces that must never read as
  /// empty during their first frame can opt into a visible floor.
  final double initialOpacity;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      return Column(
        crossAxisAlignment: crossAxisAlignment,
        children: children,
      );
    }
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        for (var i = 0; i < children.length; i++)
          children[i]
              .animate(delay: interval * i)
              .fadeIn(
                begin: initialOpacity,
                duration: duration,
                curve: Curves.easeOutCubic,
              )
              .moveY(
                begin: rise,
                end: 0,
                duration: duration,
                curve: Curves.easeOutCubic,
              ),
      ],
    );
  }
}
