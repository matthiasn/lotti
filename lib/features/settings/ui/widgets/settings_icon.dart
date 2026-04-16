import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

class SettingsIcon extends StatelessWidget {
  const SettingsIcon({required this.icon, super.key});

  static const containerSize = 36.0;
  static const _iconSize = 20.0;

  /// Standard divider indent for settings list items with a leading
  /// [SettingsIcon]. Aligns the divider to the start of the title text.
  static double dividerIndent(DsTokens tokens) =>
      tokens.spacing.step5 + containerSize + tokens.spacing.step3;

  /// Matches the surface.hover / decorative.level01 opacity from tokens.json.
  static const _kBackgroundAlpha = 0.12;

  /// Standard trailing chevron used on navigable settings rows.
  static Widget trailingChevron(DsTokens tokens) => Icon(
    Icons.chevron_right_rounded,
    size: tokens.spacing.step6,
    color: tokens.colors.text.lowEmphasis,
  );

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
