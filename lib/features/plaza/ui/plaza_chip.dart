/// The plaza's chip: a state word on its fill, or a call to action, sized
/// from the font it carries so it scales with the surface it sits on.
library;

import 'package:flutter/material.dart';
import 'package:lotti/features/plaza/ui/plaza_style.dart';

/// A chip of [label] in [ink] on [fill]; every measure is a fraction of
/// [fontPx]. With [onTap] it is a button with the teal hover.
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
    final child = Container(
      padding: EdgeInsets.symmetric(
        horizontal: fontPx * 0.8,
        vertical: fontPx * 0.25,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(fontPx * 0.35),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: PlazaStyle.fontText,
          fontSize: fontPx,
          fontWeight: FontWeight.w700,
          letterSpacing: fontPx * 0.05,
          color: ink,
        ),
      ),
    );
    if (onTap == null) return child;
    return InkWell(
      onTap: onTap,
      hoverColor: PlazaStyle.tealHover,
      borderRadius: BorderRadius.circular(fontPx * 0.35),
      child: child,
    );
  }
}
