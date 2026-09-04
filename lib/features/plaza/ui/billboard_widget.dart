import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/ui/plaza_chip.dart';
import 'package:lotti/features/plaza/ui/plaza_style.dart';

/// A frontier-plaza billboard: the headline for one task that needs
/// attention, framed in its state colour.
///
/// Mid tier (captured on an interval). For anomalies the frame glow
/// breathes on a [pulseSeconds] cycle, read off the harness [clock] so the
/// panel changes only when the harness paints a frame; nothing here ticks
/// on its own.
class BillboardWidget extends StatelessWidget {
  const BillboardWidget({
    required this.attention,
    required this.widthMeters,
    required this.heightMeters,
    required this.pxPerMeter,
    required this.clock,
    this.pulseSeconds = 3,
    this.reasonFirst = false,
    super.key,
  });

  /// A panel over its own facade leads with the reason (the facade below
  /// already carries the title) and drops its 'fly there'.
  final bool reasonFirst;

  final TaskAttention attention;
  final double widthMeters;

  /// Panel height; a squat roof panel drops the cover, then the reason.
  final double heightMeters;
  final double pxPerMeter;

  /// Full glow cycle for anomalies; shorter is more agitated.
  final double pulseSeconds;

  /// Elapsed seconds, advanced by the harness once per painted frame.
  final ValueListenable<double> clock;

  /// The glow at [seconds]: up over half a cycle, down over the other
  /// half, eased at both ends, between 0.55 and 1.
  double glowAt(double seconds) {
    final half = pulseSeconds / 2;
    final cycle = (seconds / half) % 2;
    final phase = Curves.easeInOut.transform(cycle <= 1 ? cycle : 2 - cycle);
    return 0.55 + 0.45 * phase;
  }

  @override
  Widget build(BuildContext context) {
    Widget face(double glow) => _BillboardFace(
      attention: attention,
      widthMeters: widthMeters,
      heightMeters: heightMeters,
      pxPerMeter: pxPerMeter,
      glow: glow,
      reasonFirst: reasonFirst,
    );
    if (!attention.anomalous) return face(1);
    return ValueListenableBuilder<double>(
      valueListenable: clock,
      builder: (context, seconds, _) => face(glowAt(seconds)),
    );
  }
}

class _BillboardFace extends StatelessWidget {
  const _BillboardFace({
    required this.attention,
    required this.widthMeters,
    required this.heightMeters,
    required this.pxPerMeter,
    required this.glow,
    required this.reasonFirst,
  });

  final TaskAttention attention;
  final double widthMeters;
  final double heightMeters;
  final double pxPerMeter;
  final double glow;
  final bool reasonFirst;

  /// Aspect threshold: below [reasonAspect] the reason goes and the title
  /// gets one line. The cover always stays: it is the backdrop, and a
  /// squat panel with art still reads as a billboard, a bare one as a sign.
  static const reasonAspect = 0.45;

  @override
  Widget build(BuildContext context) {
    double m(double meters) => meters * pxPerMeter;
    final w = widthMeters;
    final task = attention.task;
    final chip = PlazaStyle.chip(attention);
    final frame = PlazaStyle.lantern(attention.lantern);
    final aspect = heightMeters / w;
    final showCover = task.coverImageUrl != null;
    final showReason = attention.reason.isNotEmpty && aspect >= reasonAspect;
    // Squat panels scale by height instead of width so nothing overflows.
    final pad = m(math.min(0.06 * w, 0.1 * heightMeters));
    // The title is the largest text on every panel: sized from the
    // height first, capped by the width.
    final titlePx = m(math.min(0.07 * w, 0.3 * heightMeters));
    final chipPx = m(math.min(0.036 * w, 0.12 * heightMeters));

    // The state chip yields (scales down) before the row can overflow;
    // the call to action keeps its size.
    final chipRow = Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: PlazaChip(
                label: '${PlazaStyle.glyph(attention)}  ${chip.label}',
                fill: chip.fill,
                ink: chip.ink,
                fontPx: chipPx,
              ),
            ),
          ),
        ),
        if (!reasonFirst) SizedBox(width: chipPx * 0.6),
        if (!reasonFirst)
          // The call to action is a chip like the state, not loose type.
          PlazaChip(
            label: 'fly there ›',
            fill: PlazaStyle.teal,
            ink: const Color(0xFF0D0D0D),
            fontPx: chipPx,
          ),
      ],
    );
    // A roof panel over its own facade leads with the reason on a solid
    // band across the top in the state colour, the way the sign-tier
    // facade wears its marquee band; the title sits small on the scrim.
    final lead = reasonFirst && attention.reason.isNotEmpty;
    final leadPx = m(math.min(0.05 * w, 0.16 * heightMeters));
    final title = Text(
      task.title,
      maxLines: lead
          ? 1
          : aspect >= reasonAspect
          ? 2
          : 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: PlazaStyle.fontText,
        fontWeight: FontWeight.w700,
        fontSize: lead ? leadPx * 1.1 : titlePx,
        height: 1.05,
        letterSpacing: -titlePx * 0.02,
        color: PlazaStyle.text,
        shadows: showCover
            ? [
                Shadow(
                  color: const Color(0xCC000000),
                  blurRadius: titlePx * 0.4,
                ),
              ]
            : null,
      ),
    );
    final reasonText = lead
        ? null
        : showReason
        ? Text(
            attention.reason,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            // One voice for the reason everywhere: the state colour,
            // semibold, big enough to read from the paving.
            style: TextStyle(
              fontFamily: PlazaStyle.fontMono,
              fontWeight: FontWeight.w600,
              fontSize: m(math.min(0.05 * w, 0.14 * heightMeters)),
              color: frame,
              shadows: showCover
                  ? [const Shadow(color: Color(0xCC000000), blurRadius: 6)]
                  : null,
            ),
          )
        : null;

    // Art first: the cover fills the panel, the words sit on a scrim at the
    // bottom — the way a real billboard is laid out.
    return Material(
      color: PlazaStyle.panel,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: frame.withValues(alpha: glow),
            width: m(0.15),
          ),
          boxShadow: [
            BoxShadow(
              color: frame.withValues(alpha: 0.6 * glow),
              blurRadius: m(1.3),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (showCover)
              Image.network(
                task.coverImageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(),
              ),
            if (showCover)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0, 0.35, 1],
                    // The scrim ends in the panel's own dark, not the
                    // frame colour: the chip keeps its hue to itself and
                    // the lightbox reads as a lightbox.
                    colors: [
                      const Color(0x00000000),
                      const Color(0x33000000),
                      PlazaStyle.panel.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),
            if (lead)
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: double.infinity,
                  color: frame,
                  padding: EdgeInsets.symmetric(
                    horizontal: pad,
                    vertical: leadPx * 0.35,
                  ),
                  child: Text(
                    attention.reason,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: PlazaStyle.fontText,
                      fontWeight: FontWeight.w800,
                      fontSize: leadPx,
                      letterSpacing: leadPx * 0.04,
                      color: PlazaStyle.panel,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.all(pad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!showCover) const Spacer(),
                  // The title yields to the chip row on a squat panel.
                  Flexible(
                    child: LayoutBuilder(
                      builder: (context, constraints) => FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.bottomLeft,
                        child: SizedBox(
                          width: constraints.maxWidth,
                          child: title,
                        ),
                      ),
                    ),
                  ),
                  if (reasonText != null) ...[
                    SizedBox(height: m(0.25)),
                    reasonText,
                  ],
                  SizedBox(height: m(0.35)),
                  chipRow,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
