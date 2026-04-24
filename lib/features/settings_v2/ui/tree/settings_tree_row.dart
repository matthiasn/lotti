import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings_v2/domain/settings_node.dart';
import 'package:lotti/features/settings_v2/ui/settings_v2_constants.dart';

/// Fixed row height from spec §3. Exposed here as a convenience alias
/// so the old `kSettingsTreeRowHeight` consumers outside this file
/// keep compiling.
const double kSettingsTreeRowHeight = SettingsV2Constants.rowHeight;

/// Renders one tree row per spec §3 "Row anatomy": left active rail,
/// icon tile, title + description column, optional badge, chevron.
///
/// Stateless on purpose — visibility of the rail + chevron rotation
/// + selected styling are all derived from the props so parents can
/// drive them off the single `List<String> path` source of truth
/// without this widget owning any state.
class SettingsTreeRow extends StatelessWidget {
  const SettingsTreeRow({
    required this.node,
    required this.depth,
    required this.onActivePath,
    required this.isExpanded,
    required this.onTap,
    super.key,
  });

  final SettingsNode node;
  final int depth;

  /// True when this row's id appears anywhere in the current tree
  /// path — drives the active rail, tile fill, and dim/selection
  /// styling.
  final bool onActivePath;

  /// True when this row is a branch and is the currently-open one at
  /// its depth — drives the chevron rotation.
  final bool isExpanded;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final textHi = tokens.colors.text.highEmphasis;
    final textMid = tokens.colors.text.mediumEmphasis;
    final textLo = tokens.colors.text.lowEmphasis;
    final accent = tokens.colors.interactive.enabled;
    final rowFill = onActivePath
        ? accent.withValues(alpha: SettingsV2Constants.activeRowFillAlpha)
        : Colors.transparent;
    final tileBg = onActivePath
        ? accent.withValues(alpha: SettingsV2Constants.activeTileFillAlpha)
        : tokens.colors.background.level02;
    final tileGlyph = onActivePath ? accent : textMid;

    // MergeSemantics collapses the InkWell's auto-emitted button node
    // into the outer selected+expanded+label wrapper so screen readers
    // see one row rather than a nested button-inside-button.
    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: onActivePath,
        expanded: node.hasChildren ? isExpanded : null,
        label: node.title,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(tokens.radii.m),
          child: AnimatedContainer(
            duration: SettingsV2Constants.rowFillTransition,
            height: SettingsV2Constants.rowHeight,
            decoration: BoxDecoration(
              color: rowFill,
              borderRadius: BorderRadius.circular(tokens.radii.m),
            ),
            padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step5),
            child: Row(
              children: [
                // Teal rail on the left when on path; transparent
                // placeholder otherwise so the row content doesn't
                // shift horizontally between states.
                AnimatedContainer(
                  duration: SettingsV2Constants.railTransition,
                  width: SettingsV2Constants.activeRailWidth,
                  height: SettingsV2Constants.activeRailHeight,
                  margin: EdgeInsets.only(right: tokens.spacing.step3),
                  decoration: BoxDecoration(
                    color: onActivePath ? accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(
                      SettingsV2Constants.activeRailCornerRadius,
                    ),
                  ),
                ),
                // Icon tile
                Container(
                  width: SettingsV2Constants.iconTileSize,
                  height: SettingsV2Constants.iconTileSize,
                  decoration: BoxDecoration(
                    color: tileBg,
                    borderRadius: BorderRadius.circular(tokens.radii.s),
                  ),
                  child: Icon(
                    node.icon,
                    size: SettingsV2Constants.iconTileGlyphSize,
                    color: tileGlyph,
                  ),
                ),
                SizedBox(width: tokens.spacing.step4),
                // Title + description (min-width 0 so they truncate)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        node.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tokens.typography.styles.subtitle.subtitle2
                            .copyWith(
                              color: textHi,
                            ),
                      ),
                      if (node.desc.isNotEmpty)
                        Text(
                          node.desc,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tokens.typography.styles.others.caption
                              .copyWith(
                                color: textMid,
                              ),
                        ),
                    ],
                  ),
                ),
                // Optional badge
                if (node.badge case final badge?) ...[
                  SizedBox(width: tokens.spacing.step3),
                  _NodeBadgeChip(badge: badge, tokens: tokens),
                ],
                // Chevron — rotates for branches; absent for leaves.
                if (node.hasChildren) ...[
                  SizedBox(width: tokens.spacing.step3),
                  AnimatedRotation(
                    duration: SettingsV2Constants.chevronRotation,
                    curve: Curves.easeOutCubic,
                    turns: isExpanded ? 0.25 : 0,
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: SettingsV2Constants.chevronSize,
                      color: textLo,
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

class _NodeBadgeChip extends StatelessWidget {
  const _NodeBadgeChip({required this.badge, required this.tokens});

  final NodeBadge badge;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    const bgAlpha = SettingsV2Constants.badgeBackgroundAlpha;
    final (bg, fg) = switch (badge.tone) {
      NodeTone.info => (
        tokens.colors.alert.info.defaultColor.withValues(alpha: bgAlpha),
        tokens.colors.alert.info.defaultColor,
      ),
      NodeTone.teal => (
        tokens.colors.interactive.enabled.withValues(alpha: bgAlpha),
        tokens.colors.interactive.enabled,
      ),
      NodeTone.error => (
        tokens.colors.alert.error.defaultColor.withValues(alpha: bgAlpha),
        tokens.colors.alert.error.defaultColor,
      ),
    };
    return Container(
      height: SettingsV2Constants.badgeHeight,
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(tokens.radii.xl),
      ),
      alignment: Alignment.center,
      child: Text(
        badge.label,
        style: tokens.typography.styles.others.caption.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
