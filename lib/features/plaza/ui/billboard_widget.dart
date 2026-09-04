import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/ui/plaza_style.dart';

/// A frontier-plaza billboard: the headline for one task that needs
/// attention, framed in its state colour.
///
/// Mid tier (captured on an interval). For anomalies the frame glow
/// breathes on a [pulseSeconds] cycle, driven by an animation so the capture
/// interval decides how often it re-renders.
class BillboardWidget extends StatefulWidget {
  const BillboardWidget({
    required this.attention,
    required this.widthMeters,
    required this.heightMeters,
    required this.pxPerMeter,
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

  @override
  State<BillboardWidget> createState() => _BillboardWidgetState();
}

class _BillboardWidgetState extends State<BillboardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (widget.pulseSeconds * 500).round()),
  );

  @override
  void initState() {
    super.initState();
    if (widget.attention.anomalous) _glow.repeat(reverse: true);
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glow,
      builder: (context, _) {
        final phase = Curves.easeInOut.transform(_glow.value);
        return _BillboardFace(
          attention: widget.attention,
          widthMeters: widget.widthMeters,
          heightMeters: widget.heightMeters,
          pxPerMeter: widget.pxPerMeter,
          glow: widget.attention.anomalous ? 0.55 + 0.45 * phase : 1,
          reasonFirst: widget.reasonFirst,
        );
      },
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

    final chipRow = Row(
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: chipPx * 0.8,
            vertical: chipPx * 0.25,
          ),
          decoration: BoxDecoration(
            color: chip.fill,
            borderRadius: BorderRadius.circular(chipPx * 0.35),
          ),
          child: Text(
            '${PlazaStyle.glyph(attention)}  ${chip.label}',
            style: TextStyle(
              fontFamily: PlazaStyle.fontText,
              fontSize: chipPx,
              fontWeight: FontWeight.w700,
              letterSpacing: chipPx * 0.05,
              color: chip.ink,
            ),
          ),
        ),
        const Spacer(),
        if (!reasonFirst)
          Text(
            'fly there ›',
            style: TextStyle(
              fontFamily: PlazaStyle.fontText,
              fontSize: chipPx,
              fontWeight: FontWeight.w600,
              color: PlazaStyle.teal,
            ),
          ),
      ],
    );
    // A roof panel over its own facade leads with the reason: the big
    // line is what is wrong, in the state colour, and the title is the
    // small line under it.
    final lead = reasonFirst && attention.reason.isNotEmpty;
    final title = Text(
      lead ? attention.reason : task.title,
      // A reason is a sentence: it gets two lines even on a squat panel.
      maxLines: lead || aspect >= reasonAspect ? 2 : 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: PlazaStyle.fontText,
        fontWeight: FontWeight.w700,
        fontSize: titlePx,
        height: 1.05,
        letterSpacing: -titlePx * 0.02,
        color: lead ? frame : PlazaStyle.text,
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
        ? Text(
            task.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: PlazaStyle.fontText,
              fontWeight: FontWeight.w600,
              fontSize: m(math.min(0.045 * w, 0.14 * heightMeters)),
              color: PlazaStyle.text,
              shadows: showCover
                  ? [const Shadow(color: Color(0xCC000000), blurRadius: 6)]
                  : null,
            ),
          )
        : showReason
        ? Text(
            attention.reason,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: PlazaStyle.fontMono,
              fontSize: m(math.min(0.04 * w, 0.12 * heightMeters)),
              color: const Color(0xF2FFFFFF),
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
