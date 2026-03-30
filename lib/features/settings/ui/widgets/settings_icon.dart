import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

class SettingsIcon extends StatelessWidget {
  const SettingsIcon({required this.icon, super.key});

  static const containerSize = 36.0;
  static const _iconSize = 20.0;

  /// Matches the surface.hover / decorative.level01 opacity from tokens.json.
  static const _kBackgroundAlpha = 0.12;

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      width: containerSize,
      height: containerSize,
      decoration: BoxDecoration(
        color: tokens.colors.interactive.enabled.withValues(
          alpha: _kBackgroundAlpha,
        ),
        borderRadius: BorderRadius.circular(tokens.radii.s),
      ),
      child: Center(
        child: Icon(
          icon,
          size: _iconSize,
          color: tokens.colors.interactive.enabled,
        ),
      ),
    );
  }
}
