import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// The band a [Dismissible] reveals behind a row while it is dragged: a fill
/// with the action's glyph and name at the edge the row moves away from, so
/// a swipe always says what letting go will do.
///
/// Callers pass the fill and the ink together so the pair is chosen once per
/// surface — a habit row drags over the completion colours with high-emphasis
/// text, an AI band row over its own accent wash with the accent ink.
class DesignSystemSwipeActionBackground extends StatelessWidget {
  const DesignSystemSwipeActionBackground({
    required this.alignment,
    required this.color,
    required this.foregroundColor,
    required this.icon,
    required this.label,
    super.key,
  });

  /// Where the glyph and label sit: the leading edge for a start-to-end
  /// swipe, the trailing edge for the reverse.
  final Alignment alignment;
  final Color color;
  final Color foregroundColor;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return ColoredBox(
      color: color,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step5),
        child: Align(
          alignment: alignment,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: foregroundColor, size: tokens.spacing.step6),
              SizedBox(width: tokens.spacing.step2),
              Text(
                label,
                style: tokens.typography.styles.body.bodyMedium.copyWith(
                  color: foregroundColor,
                  fontWeight: tokens.typography.weight.semiBold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
