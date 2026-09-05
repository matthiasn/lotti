/// The plaza's chip: a state word on its fill, or a call to action, sized
/// from the font it carries so it scales with the surface it sits on.
library;

import 'package:lotti/features/plaza/ui/plaza_style.dart';
import 'package:material_ui/material_ui.dart';

/// A chip of [label] in [ink] on [fill]; every measure is a fraction of
/// [fontPx]. With [onTap] it is a button with the teal hover, and needs a
/// [Material] ancestor to paint its fill on.
class PlazaChip extends StatelessWidget {
  const PlazaChip({
    required this.label,
    required this.fill,
    required this.ink,
    required this.fontPx,
    this.onTap,
    super.key,
  });

  final String label;
  final Color fill;
  final Color ink;
  final double fontPx;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final padding = EdgeInsets.symmetric(
      horizontal: fontPx * 0.8,
      vertical: fontPx * 0.25,
    );
    final radius = BorderRadius.circular(fontPx * 0.35);
    final decoration = BoxDecoration(color: fill, borderRadius: radius);
    final text = Text(
      label,
      style: TextStyle(
        fontFamily: PlazaStyle.fontText,
        fontSize: fontPx,
        fontWeight: FontWeight.w700,
        letterSpacing: fontPx * 0.05,
        color: ink,
      ),
    );
    if (onTap == null) {
      return Container(padding: padding, decoration: decoration, child: text);
    }
    // Ink, not a Container: the fill goes on the Material's ink layer, so
    // the hover wash and the splash show over it instead of under it.
    return InkWell(
      onTap: onTap,
      hoverColor: PlazaStyle.tealHover,
      borderRadius: radius,
      child: Ink(padding: padding, decoration: decoration, child: text),
    );
  }
}
