import 'package:lotti/features/plaza/ui/plaza_style.dart';
import 'package:material_ui/material_ui.dart';

/// A vertical neon banner down a tall building's end wall: the category
/// name (or the task's state) running top to bottom in mono capitals on a
/// dark strip with a neon edge. Captured once.
class BannerWidget extends StatelessWidget {
  const BannerWidget({
    required this.label,
    required this.color,
    required this.widthMeters,
    required this.heightMeters,
    required this.pxPerMeter,
    super.key,
  });

  final String label;

  /// The neon colour of the strip's edge and type.
  final Color color;
  final double widthMeters;
  final double heightMeters;
  final double pxPerMeter;

  @override
  Widget build(BuildContext context) {
    final fontPx = widthMeters * pxPerMeter * 0.5;
    return Material(
      color: const Color(0xFF07050E),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: color,
              width: widthMeters * pxPerMeter * 0.08,
            ),
            right: BorderSide(
              color: color.withValues(alpha: 0.35),
              width: widthMeters * pxPerMeter * 0.04,
            ),
          ),
        ),
        alignment: Alignment.topCenter,
        padding: EdgeInsets.symmetric(vertical: fontPx * 0.8),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topCenter,
          child: RotatedBox(
            quarterTurns: 1,
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontFamily: PlazaStyle.fontMono,
                fontSize: fontPx,
                fontWeight: FontWeight.w500,
                letterSpacing: fontPx * 0.35,
                color: color,
                shadows: [Shadow(color: color, blurRadius: fontPx * 0.6)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
