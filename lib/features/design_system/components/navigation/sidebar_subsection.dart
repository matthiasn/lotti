import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// A quiet grouped surface for active desktop-sidebar sub-navigation.
///
/// Used by destinations whose active row expands into secondary controls, such
/// as Daily OS' calendar/time-analysis section and Insights' AI impact link.
class SidebarSubsectionSurface extends StatelessWidget {
  const SidebarSubsectionSurface({
    required this.children,
    this.padding,
    super.key,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding:
          padding ?? EdgeInsetsDirectional.only(start: tokens.spacing.step5),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.colors.surface.enabled,
          borderRadius: BorderRadius.circular(tokens.radii.m),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

/// A token-backed action row for [SidebarSubsectionSurface].
class SidebarSubsectionAction extends StatelessWidget {
  const SidebarSubsectionAction({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.active,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final rowRadius = BorderRadius.circular(tokens.radii.s);
    final foregroundColor = tokens.colors.text.highEmphasis;

    return Padding(
      padding: EdgeInsets.all(tokens.spacing.step2),
      child: Semantics(
        selected: active,
        child: Material(
          color: active ? tokens.colors.surface.active : Colors.transparent,
          borderRadius: rowRadius,
          child: InkWell(
            onTap: onTap,
            borderRadius: rowRadius,
            hoverColor: tokens.colors.surface.hover,
            focusColor: tokens.colors.surface.focusPressed,
            child: Stack(
              children: [
                PositionedDirectional(
                  start: 0,
                  top: tokens.spacing.step2,
                  bottom: tokens.spacing.step2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: active
                          ? tokens.colors.interactive.enabled
                          : tokens.colors.decorative.level02,
                      borderRadius: BorderRadius.circular(tokens.radii.xs),
                    ),
                    child: SizedBox(
                      width: active
                          ? tokens.spacing.step2
                          : tokens.spacing.step1,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsetsDirectional.only(
                    start: tokens.spacing.step4,
                    top: tokens.spacing.step2,
                    end: tokens.spacing.step3,
                    bottom: tokens.spacing.step2,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        active ? activeIcon : icon,
                        size: tokens.spacing.step5,
                        color: foregroundColor,
                      ),
                      SizedBox(width: tokens.spacing.step3),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tokens.typography.styles.others.caption
                              .copyWith(
                                color: foregroundColor,
                                fontWeight: active
                                    ? tokens.typography.weight.semiBold
                                    : null,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
