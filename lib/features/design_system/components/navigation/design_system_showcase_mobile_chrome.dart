import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

class DesignSystemShowcaseMobileShell extends StatelessWidget {
  const DesignSystemShowcaseMobileShell({
    required this.child,
    this.backgroundColor,
    super.key,
  });

  final Widget child;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final frameColor = isLight
        ? tokens.colors.background.level01
        : tokens.colors.background.level03;

    return SizedBox(
      width: 402,
      height: 874,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: frameColor,
          borderRadius: BorderRadius.circular(36),
          border: Border.all(
            color: isLight
                ? tokens.colors.decorative.level02
                : Colors.black.withValues(alpha: 0.6),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isLight ? 0.1 : 0.28),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: backgroundColor ?? tokens.colors.background.level01,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class DesignSystemShowcaseMobileStatusBar extends StatelessWidget {
  const DesignSystemShowcaseMobileStatusBar({
    this.foregroundColor,
    super.key,
  });

  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final iconColor = foregroundColor ?? tokens.colors.text.highEmphasis;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
      child: SizedBox(
        height: 24,
        child: Row(
          children: [
            Text(
              '9:41',
              style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                color: iconColor,
              ),
            ),
            const Spacer(),
            Icon(Icons.signal_cellular_alt_rounded, size: 18, color: iconColor),
            const SizedBox(width: 4),
            Icon(Icons.wifi_rounded, size: 18, color: iconColor),
            const SizedBox(width: 4),
            Icon(Icons.battery_full_rounded, size: 20, color: iconColor),
          ],
        ),
      ),
    );
  }
}

class DesignSystemShowcaseMobileHomeIndicator extends StatelessWidget {
  const DesignSystemShowcaseMobileHomeIndicator({
    this.foregroundColor,
    super.key,
  });

  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final color =
        foregroundColor ?? context.designTokens.colors.text.mediumEmphasis;

    return Container(
      width: 175,
      height: 5,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}
