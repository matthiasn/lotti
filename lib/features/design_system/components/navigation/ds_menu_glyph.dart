import 'package:material_ui/material_ui.dart';

/// The two-stroke menu mark: a long stroke over a shorter one, both starting
/// on the leading edge, with round caps.
///
/// Drawn rather than taken from the icon font, which has only the three-bar
/// menu and the two *equal* bars of "equals" — neither reads as "open the
/// navigation" the way the unequal pair does. Sized and tinted by the
/// ambient [IconTheme], like an [Icon], so it drops into any icon slot.
class DsMenuGlyph extends StatelessWidget {
  const DsMenuGlyph({super.key});

  @override
  Widget build(BuildContext context) {
    // `IconTheme.of` always answers fully resolved: size and colour fall
    // back to the framework's defaults, never to null.
    final theme = IconTheme.of(context);
    return SizedBox.square(
      dimension: theme.size,
      child: CustomPaint(
        painter: _MenuGlyphPainter(
          color: theme.color!,
          leadingIsLeft: Directionality.of(context) == TextDirection.ltr,
        ),
      ),
    );
  }
}

class _MenuGlyphPainter extends CustomPainter {
  const _MenuGlyphPainter({required this.color, required this.leadingIsLeft});

  final Color color;
  final bool leadingIsLeft;

  @override
  void paint(Canvas canvas, Size size) {
    // Proportions of the mark, as fractions of its box — the geometry of a
    // glyph, not spacing: the long stroke spans the box, the short one two
    // thirds of it, an eighth of the box thick, their centres a little under
    // half the box apart.
    final side = size.shortestSide;
    final thickness = side / 8;
    final gap = side * 11 / 24;
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;

    void stroke(double length, double y) {
      // Round caps extend half a thickness past each end, so the visible
      // stroke is exactly [length] long and starts on the leading edge.
      final inset = thickness / 2;
      final start = leadingIsLeft ? inset : size.width - inset;
      final end = leadingIsLeft ? length - inset : size.width - length + inset;
      canvas.drawLine(Offset(start, y), Offset(end, y), paint);
    }

    final middle = size.height / 2;
    stroke(side, middle - gap / 2);
    stroke(side * 2 / 3, middle + gap / 2);
  }

  @override
  bool shouldRepaint(covariant _MenuGlyphPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.leadingIsLeft != leadingIsLeft;
}
