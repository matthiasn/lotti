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
    super.key,
  });

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
  });

  final TaskAttention attention;
  final double widthMeters;
  final double heightMeters;
  final double pxPerMeter;
  final double glow;

  /// Aspect thresholds: below [coverAspect] the cover goes, below
  /// [reasonAspect] the reason goes too and the title gets one line.
  static const coverAspect = 0.5;
  static const reasonAspect = 0.34;

  @override
  Widget build(BuildContext context) {
    double m(double meters) => meters * pxPerMeter;
    final w = widthMeters;
    final task = attention.task;
    final chip = PlazaStyle.chip(attention);
    final frame = PlazaStyle.lantern(attention.lantern);
    final aspect = heightMeters / w;
    final showCover = task.coverImageUrl != null && aspect >= coverAspect;
    final showReason = attention.reason.isNotEmpty && aspect >= reasonAspect;
    // Squat panels scale by height instead of width so nothing overflows.
    final pad = m(math.min(0.06 * w, 0.1 * heightMeters));
    final titlePx = m(math.min(0.07 * w, 0.24 * heightMeters));
    final chipPx = m(math.min(0.036 * w, 0.12 * heightMeters));

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
        padding: EdgeInsets.all(pad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The title yields to the chip row and the gaps: on a squat
            // panel it scales down instead of overflowing.
            Flexible(
              flex: 2,
              child: LayoutBuilder(
                builder: (context, constraints) => FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: constraints.maxWidth,
                    child: Text(
                      task.title,
                      maxLines: aspect >= reasonAspect ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: PlazaStyle.fontText,
                        fontWeight: FontWeight.w700,
                        fontSize: titlePx,
                        height: 1.1,
                        letterSpacing: -titlePx * 0.02,
                        color: PlazaStyle.text,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (showReason) ...[
              SizedBox(height: m(0.3)),
              Text(
                attention.reason,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: PlazaStyle.fontMono,
                  fontSize: m(0.04 * w),
                  color: const Color(0xF2FFFFFF),
                ),
              ),
            ],
            if (showCover) ...[
              SizedBox(height: m(0.4)),
              Expanded(
                child: Image.network(
                  task.coverImageUrl!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox(),
                ),
              ),
            ] else
              const Spacer(),
            SizedBox(height: m(0.4)),
            Row(
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
            ),
          ],
        ),
      ),
    );
  }
}
