import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

abstract final class DesignSystemFilterMetrics {
  static const frameWidth = 402.0;
  static const frameRadius = 32.0;
  static const handleWidth = 40.0;
  static const handleHeight = 4.0;
  static const actionRadius = 26.0;
}

/// Strips a trailing colon and any whitespace before it from a label string.
///
/// Some locales append a colon to field labels (e.g. "Status:" or "Statut :").
/// Filter headers display the bare word, so this helper removes the suffix.
String stripTrailingColon(String value) {
  return value.endsWith(':')
      ? value.substring(0, value.length - 1).trimRight()
      : value;
}

@immutable
class DesignSystemFilterPalette {
  const DesignSystemFilterPalette({
    required this.sheetBackground,
    required this.handleColor,
    required this.primaryText,
    required this.secondaryText,
    required this.pillFill,
    required this.selectedPillBackground,
    required this.fieldBackground,
    required this.fieldOutline,
    required this.dismissFill,
    required this.dismissIcon,
    required this.dividerColor,
    required this.accent,
    required this.accentText,
    required this.applyBadgeFill,
    required this.priorityP0,
    required this.priorityP1,
    required this.priorityP2,
    required this.priorityP3,
  });

  factory DesignSystemFilterPalette.fromTokens(DsTokens tokens) {
    final isDark = tokens.colors.background.level01.computeLuminance() < 0.5;

    if (isDark) {
      return DesignSystemFilterPalette(
        sheetBackground: const Color(0xFF1C1C1C),
        handleColor: tokens.colors.decorative.level02,
        primaryText: tokens.colors.text.highEmphasis,
        secondaryText: tokens.colors.text.mediumEmphasis,
        pillFill: const Color(0xFF2C2C2C),
        selectedPillBackground: const Color(0xFF253A36),
        fieldBackground: const Color(0xFF1C1C1C),
        fieldOutline: const Color(0xFF3A3A3A),
        dismissFill: const Color(0xFFCFCFCF),
        dismissIcon: const Color(0xFF373737),
        dividerColor: const Color(0xFF343434),
        accent: const Color(0xFF5AD5BE),
        accentText: const Color(0xFF0F2620),
        applyBadgeFill: const Color(0xFF8BE2D1),
        priorityP0: const Color(0xFFE2655D),
        priorityP1: const Color(0xFFF6A53B),
        priorityP2: const Color(0xFF5DB8FF),
        priorityP3: const Color(0xFF7AAE80),
      );
    }

    return DesignSystemFilterPalette(
      sheetBackground: const Color(0xFFFFFCF8),
      handleColor: tokens.colors.decorative.level02,
      primaryText: tokens.colors.text.highEmphasis,
      secondaryText: tokens.colors.text.mediumEmphasis,
      pillFill: const Color(0xFFF0EEE9),
      selectedPillBackground: const Color(0xFFE5F7F2),
      fieldBackground: const Color(0xFFFFFCF8),
      fieldOutline: const Color(0xFFD8D3CC),
      dismissFill: const Color(0xFF707070),
      dismissIcon: const Color(0xFFFFFFFF),
      dividerColor: const Color(0xFFE4DED7),
      accent: const Color(0xFF2CA990),
      accentText: const Color(0xFFFFFFFF),
      applyBadgeFill: const Color(0xFF1E8A74),
      priorityP0: const Color(0xFFD94A44),
      priorityP1: const Color(0xFFF19819),
      priorityP2: const Color(0xFF44AEEF),
      priorityP3: const Color(0xFF6C9E71),
    );
  }

  final Color sheetBackground;
  final Color handleColor;
  final Color primaryText;
  final Color secondaryText;
  final Color pillFill;
  final Color selectedPillBackground;
  final Color fieldBackground;
  final Color fieldOutline;
  final Color dismissFill;
  final Color dismissIcon;
  final Color dividerColor;
  final Color accent;
  final Color accentText;
  final Color applyBadgeFill;
  final Color priorityP0;
  final Color priorityP1;
  final Color priorityP2;
  final Color priorityP3;
}

class DesignSystemFilterActionButton extends StatelessWidget {
  const DesignSystemFilterActionButton({
    required this.label,
    required this.palette,
    required this.highlighted,
    required this.textStyle,
    required this.onTap,
    this.counter,
    super.key,
  });

  final String label;
  final DesignSystemFilterPalette palette;
  final bool highlighted;
  final TextStyle textStyle;
  final VoidCallback onTap;
  final int? counter;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: highlighted ? palette.accent : palette.pillFill,
          borderRadius: BorderRadius.circular(
            DesignSystemFilterMetrics.actionRadius,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(
            DesignSystemFilterMetrics.actionRadius,
          ),
          onTap: onTap,
          child: SizedBox(
            height: 44,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: textStyle.copyWith(
                    color: highlighted
                        ? palette.accentText
                        : palette.primaryText,
                  ),
                ),
                if (counter != null) ...[
                  SizedBox(width: spacing.step4 - spacing.step1),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: palette.applyBadgeFill,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$counter',
                        style: tokens.typography.styles.subtitle.subtitle2
                            .copyWith(
                              color: highlighted
                                  ? palette.accentText
                                  : palette.primaryText,
                            ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DesignSystemFilterDragHandle extends StatelessWidget {
  const DesignSystemFilterDragHandle({
    required this.color,
    super.key,
  });

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: DesignSystemFilterMetrics.handleWidth,
        height: DesignSystemFilterMetrics.handleHeight,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}
