import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lotti/features/plaza/ui/plaza_style.dart';

/// An LED ticker band: [text] scrolls leftward forever at
/// [speedMetersPerSecond], two copies back to back so the loop is seamless.
///
/// Driven by an [AnimationController] so the scroll is a pure function of
/// elapsed time; the scene decides how often the band is captured.
class TickerWidget extends StatefulWidget {
  const TickerWidget({
    required this.text,
    required this.heightMeters,
    required this.pxPerMeter,
    required this.speedMetersPerSecond,
    super.key,
  });

  final String text;
  final double heightMeters;
  final double pxPerMeter;
  final double speedMetersPerSecond;

  @override
  State<TickerWidget> createState() => _TickerWidgetState();
}

class _TickerWidgetState extends State<TickerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fontPx = widget.heightMeters * widget.pxPerMeter * 0.62;
    final style = TextStyle(
      fontFamily: PlazaStyle.fontMono,
      fontSize: fontPx,
      fontWeight: FontWeight.w500,
      color: PlazaStyle.teal,
    );
    final border = BorderSide(
      color: PlazaStyle.teal.withValues(alpha: 0.45),
      width: fontPx * 0.08,
    );
    return Material(
      color: const Color(0xFF05070C),
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: border, bottom: border),
        ),
        clipBehavior: Clip.hardEdge,
        // The type fades in and out at the housing's ends instead of
        // being sliced mid-glyph.
        child: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              Color(0x00000000),
              Color(0xFF000000),
              Color(0xFF000000),
              Color(0x00000000),
            ],
            stops: [0, 0.06, 0.94, 1],
          ).createShader(bounds),
          blendMode: BlendMode.dstIn,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final painter = TextPainter(
                text: TextSpan(text: widget.text, style: style),
                textDirection: TextDirection.ltr,
                maxLines: 1,
              )..layout();
              // A gap of at least half the band between copies, so a phrase
              // is read whole before the next one arrives.
              final gap = math.max(fontPx * 4, constraints.maxWidth * 0.5);
              final copyWidth = painter.width + gap;
              final pxPerSecond =
                  widget.speedMetersPerSecond * widget.pxPerMeter;
              return AnimatedBuilder(
                animation: _clock,
                builder: (context, _) {
                  final elapsed =
                      _clock.lastElapsedDuration?.inMicroseconds ?? 0;
                  final offset = (elapsed / 1e6 * pxPerSecond) % copyWidth;
                  return Stack(
                    children: [
                      for (var i = 0; i < 2; i++)
                        Positioned(
                          left: -offset + i * copyWidth,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: Text(
                              widget.text,
                              maxLines: 1,
                              softWrap: false,
                              style: style,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
