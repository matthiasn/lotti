import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:lotti/features/plaza/ui/plaza_style.dart';

/// An LED ticker band: [text] scrolls leftward forever at
/// [speedMetersPerSecond], two copies back to back so the loop is seamless.
///
/// The scroll is a pure function of the harness [clock] (elapsed seconds),
/// so the band moves only when the harness paints a frame and the scene
/// decides how often it is captured; nothing here ticks on its own.
class TickerWidget extends StatelessWidget {
  const TickerWidget({
    required this.text,
    required this.heightMeters,
    required this.pxPerMeter,
    required this.speedMetersPerSecond,
    required this.clock,
    super.key,
  });

  final String text;
  final double heightMeters;
  final double pxPerMeter;
  final double speedMetersPerSecond;

  /// Elapsed seconds, advanced by the harness once per painted frame.
  final ValueListenable<double> clock;

  @override
  Widget build(BuildContext context) {
    final fontPx = heightMeters * pxPerMeter * 0.62;
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
                text: TextSpan(text: text, style: style),
                textDirection: TextDirection.ltr,
                maxLines: 1,
              )..layout();
              // A gap of at least half the band between copies, so a phrase
              // is read whole before the next one arrives.
              final gap = math.max(fontPx * 4, constraints.maxWidth * 0.5);
              final copyWidth = painter.width + gap;
              final pxPerSecond = speedMetersPerSecond * pxPerMeter;
              return ValueListenableBuilder<double>(
                valueListenable: clock,
                builder: (context, seconds, _) {
                  final offset = (seconds * pxPerSecond) % copyWidth;
                  return Stack(
                    children: [
                      for (var i = 0; i < 2; i++)
                        Positioned(
                          left: -offset + i * copyWidth,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: Text(
                              text,
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
