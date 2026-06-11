import 'package:flutter/material.dart';

/// Dissolves one horizontal edge of [child] so content meeting that edge
/// (a scroll viewport boundary, a squeezed zone) fades out instead of
/// being razor-cut at full brightness.
///
/// The ramp spans [rampExtent] logical pixels — when the faded content is
/// text, pass at least one full *scaled* line height (resolve the
/// [TextScaler] in build, not at paint time) or the edge line gets sliced
/// flat instead of fading. The ramp is bounded to
/// [minFraction]..[maxFraction] of the painted height so shallow boxes
/// keep a fully opaque region.
class EdgeFade extends StatelessWidget {
  const EdgeFade({
    required this.rampExtent,
    required this.child,
    this.fadeTop = true,
    this.minFraction = 0.05,
    this.maxFraction = 0.3,
    super.key,
  }) : assert(rampExtent >= 0, 'rampExtent must be non-negative'),
       assert(
         minFraction >= 0 && minFraction <= 1,
         'minFraction must be within [0, 1]',
       ),
       assert(
         maxFraction >= 0 && maxFraction <= 1,
         'maxFraction must be within [0, 1]',
       ),
       assert(
         minFraction <= maxFraction,
         'minFraction must not exceed maxFraction',
       );

  /// Logical pixels the dissolve should span before content reads as
  /// fully opaque.
  final double rampExtent;

  /// True dissolves the top edge; false dissolves the bottom edge.
  final bool fadeTop;

  /// Lower bound of the ramp as a fraction of the painted height.
  final double minFraction;

  /// Upper bound of the ramp as a fraction of the painted height.
  final double maxFraction;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) {
        final ramp = bounds.height <= 0
            ? minFraction
            : (rampExtent / bounds.height).clamp(minFraction, maxFraction);
        return LinearGradient(
          begin: fadeTop ? Alignment.topCenter : Alignment.bottomCenter,
          end: fadeTop ? Alignment.bottomCenter : Alignment.topCenter,
          colors: const [Color(0x00FFFFFF), Color(0xFFFFFFFF)],
          stops: [0, ramp],
        ).createShader(bounds);
      },
      child: child,
    );
  }
}
