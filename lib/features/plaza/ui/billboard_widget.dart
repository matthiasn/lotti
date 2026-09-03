import 'package:flutter/material.dart';
import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/ui/plaza_style.dart';

/// A frontier-plaza billboard: the headline for one task that needs
/// attention, framed in its state colour.
///
/// Mid tier (captured on an interval). For anomalies the frame glow
/// breathes on a three-second cycle, driven by an animation so the capture
/// interval decides how often it re-renders.
class BillboardWidget extends StatefulWidget {
  const BillboardWidget({
    required this.attention,
    required this.widthMeters,
    required this.pxPerMeter,
    super.key,
  });

  final TaskAttention attention;
  final double widthMeters;
  final double pxPerMeter;

  @override
  State<BillboardWidget> createState() => _BillboardWidgetState();
}

class _BillboardWidgetState extends State<BillboardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
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
    required this.pxPerMeter,
    required this.glow,
  });

  final TaskAttention attention;
  final double widthMeters;
  final double pxPerMeter;
  final double glow;

  @override
  Widget build(BuildContext context) {
    double m(double meters) => meters * pxPerMeter;
    final w = widthMeters;
    final task = attention.task;
    final chip = PlazaStyle.chip(attention);
    final frame = PlazaStyle.lantern(attention.lantern);
    final pad = m(0.09 * w);
    final chipPx = m(0.038 * w);

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
            Text(
              task.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: PlazaStyle.fontText,
                fontWeight: FontWeight.w700,
                fontSize: m(0.088 * w),
                height: 1.1,
                letterSpacing: -m(0.088 * w) * 0.02,
                color: PlazaStyle.text,
              ),
            ),
            if (attention.reason.isNotEmpty) ...[
              SizedBox(height: m(0.4)),
              Text(
                attention.reason,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: PlazaStyle.fontMono,
                  fontSize: m(0.042 * w),
                  color: frame.withValues(alpha: glow),
                ),
              ),
            ],
            if (task.coverImageUrl != null) ...[
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
                    chip.label,
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
