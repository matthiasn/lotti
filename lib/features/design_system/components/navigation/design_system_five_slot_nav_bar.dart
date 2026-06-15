import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_navigation_tab_bar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// One destination slot of [DesignSystemFiveSlotNavBar].
class DesignSystemFiveSlotNavBarItem {
  const DesignSystemFiveSlotNavBarItem({
    required this.label,
    required this.icon,
    this.activeIcon,
    this.active = false,
    this.onTap,
    this.semanticsLabel,
  });

  final String label;
  final Widget icon;
  final Widget? activeIcon;
  final bool active;
  final VoidCallback? onTap;

  /// Overrides [label] for screen readers — used by the More slot to
  /// announce how many destinations hide behind it.
  final String? semanticsLabel;
}

/// Mobile bottom navigation bar docked flush against the screen's bottom
/// edge (`Tasks · DailyOS · Logbook · More` on compact windows).
///
/// Unlike [DesignSystemNavigationTabBar] — which hugs its content and gets
/// scaled down by a `FittedBox` when too many tabs are visible, shrinking
/// labels into illegibility — this bar gives every slot an equal flex
/// share, so labels always render at the caption size (ellipsizing rather
/// than scaling). The mobile shell budgets slots against
/// [comfortableSlotWidth] and [availableRowWidth]: destinations that do
/// not fit overflow into a More sheet and are promoted back into the bar
/// one by one as window width allows; once everything fits
/// ([allSlotsFit]) the More slot disappears. The slot row handles any of
/// those line-ups.
///
/// The bar spans the full width with only the top corners rounded, and pads
/// the bottom safe-area inset *inside* its surface ([bottomInsetFraction]
/// of it, replacing the internal bottom padding), so the frosted fill
/// reaches the physical bottom edge with zero gap while the slot row stays
/// clear of the home indicator.
///
/// Selection tint cross-fades over [tintDuration]; when the platform asks
/// for reduced motion the tint snaps instead.
class DesignSystemFiveSlotNavBar extends StatelessWidget {
  const DesignSystemFiveSlotNavBar({
    required this.items,
    super.key,
  });

  static const double iconSize = 22;

  /// Minimum tappable extent of every slot (accessibility floor).
  static const double minTapTarget = 44;

  /// Minimum width a slot needs to read as comfortable rather than merely
  /// tappable — Material's fixed bottom-navigation item minimum (80dp).
  /// [allSlotsFit] uses this floor so the all-destinations line-up only
  /// engages when every slot gets real breathing room, not as soon as the
  /// labels technically squeeze in.
  static const double comfortableMinSlotWidth = 80;

  static const Duration tintDuration = Duration(milliseconds: 240);

  /// Fraction of the bottom safe-area inset the bar absorbs into its
  /// surface. The OS-reported home-indicator inset (34px on iPhones) is
  /// generous for a docked bar; rendering half of it keeps the slot row
  /// clear of the indicator without dead space below the labels.
  static const double bottomInsetFraction = 0.5;

  /// `cubic-bezier(0.25, 1, 0.5, 1)` — easeOutQuart.
  static const Curve tintCurve = Cubic(0.25, 1, 0.5, 1);

  final List<DesignSystemFiveSlotNavBarItem> items;

  /// Intrinsic content height of the slot row (excluding the frosted
  /// surface's padding and the safe-area inset). Scales with the system
  /// text size: the label line grows under [MediaQuery.textScalerOf], so
  /// the fixed-height row must grow with it or large-font users get
  /// clipped captions.
  static double contentHeight(BuildContext context) {
    final tokens = context.designTokens;
    final scaledCaptionHeight = MediaQuery.textScalerOf(
      context,
    ).scale(tokens.typography.lineHeight.caption);
    return math.max(
      minTapTarget,
      iconSize + tokens.spacing.step1 + scaledCaptionHeight,
    );
  }

  /// Total rendered height of the bar: content plus the frosted surface's
  /// vertical padding, its hairline border (which `Container` stacks onto
  /// the padding on each bordered side), and the absorbed bottom safe-area
  /// inset (see [_bottomPadding]). The docked bar omits the bottom border
  /// (`includeBottomBorder: false`), so only the top hairline contributes
  /// here — a single [DesignSystemNavigationFrostedSurface.borderWidth], not
  /// two. Shared with the bottom-nav container's occupied-height math so the
  /// numbers cannot drift apart.
  static double barHeight(BuildContext context) {
    final tokens = context.designTokens;
    return contentHeight(context) +
        tokens.spacing.step2 +
        _bottomPadding(context) +
        DesignSystemNavigationFrostedSurface.borderWidth;
  }

  /// Bottom padding of the frosted surface: [bottomInsetFraction] of the
  /// safe-area inset, replacing — rather than stacking onto — the internal
  /// `step2` padding, so home-indicator devices get no double spacing
  /// below the slot row.
  static double _bottomPadding(BuildContext context) {
    final tokens = context.designTokens;
    return math.max(
      tokens.spacing.step2,
      MediaQuery.paddingOf(context).bottom * bottomInsetFraction,
    );
  }

  /// Width one slot needs to render [label] comfortably: the caption line
  /// laid out at the current text scale (so large system fonts demand
  /// wider slots), or the icon if wider, plus `step3` breathing room per
  /// side — floored at [comfortableMinSlotWidth], so short labels do not
  /// shrink the demand below a comfortable slot.
  static double comfortableSlotWidth(BuildContext context, String label) {
    final tokens = context.designTokens;
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: tokens.typography.styles.others.caption.copyWith(
          fontWeight: tokens.typography.weight.semiBold,
        ),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final contentWidth = math.max(painter.width, iconSize);
    painter.dispose();
    return math.max(
      contentWidth + tokens.spacing.step3 * 2,
      comfortableMinSlotWidth,
    );
  }

  /// Horizontal space the slot row gets inside the frosted surface: the
  /// window width minus the surface's own horizontal padding and the
  /// safe-area insets it absorbs. Callers budgeting slots against the bar
  /// (see [comfortableSlotWidth]) measure against this.
  static double availableRowWidth(BuildContext context) {
    final tokens = context.designTokens;
    final insets = MediaQuery.paddingOf(context);
    return MediaQuery.sizeOf(context).width -
        tokens.spacing.step2 * 2 -
        insets.left -
        insets.right;
  }

  /// True when one slot per [labels] entry fits the current window
  /// comfortably — the caller can then give every destination its own
  /// slot instead of overflowing into a More sheet. Adapts to both the
  /// window width and the system text scale: a larger font widens every
  /// label and flips this back to `false` sooner.
  static bool allSlotsFit(BuildContext context, List<String> labels) {
    var required = 0.0;
    for (final label in labels) {
      required += comfortableSlotWidth(context, label);
    }
    return required <= availableRowWidth(context);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final insets = MediaQuery.paddingOf(context);

    return DesignSystemNavigationFrostedSurface(
      // Docked: only the top corners are rounded, the bottom edge sits
      // flush against the screen edge — deliberately with zero gap below,
      // including on devices that report no home-indicator inset.
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(tokens.radii.sectionCards),
      ),
      // Flush against the screen edge, so the bottom hairline would render
      // as a stray light line below the bar — drop it. [barHeight] accounts
      // for the single remaining (top) hairline.
      includeBottomBorder: false,
      // The safe-area insets live inside the surface so the frosted fill
      // reaches the physical edges while the slot row stays clear of the
      // home indicator, notches, and landscape navigation buttons. The
      // bottom inset is trimmed and absorbed by _bottomPadding instead of
      // stacking onto the internal padding.
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.step2 + insets.left,
        tokens.spacing.step2,
        tokens.spacing.step2 + insets.right,
        _bottomPadding(context),
      ),
      child: SizedBox(
        height: contentHeight(context),
        child: Row(
          children: [
            for (final item in items)
              Expanded(child: _FiveSlotNavBarSlot(item: item)),
          ],
        ),
      ),
    );
  }
}

class _FiveSlotNavBarSlot extends StatelessWidget {
  const _FiveSlotNavBarSlot({required this.item});

  final DesignSystemFiveSlotNavBarItem item;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final tint = item.active
        ? tokens.colors.interactive.enabled
        : tokens.colors.text.mediumEmphasis;
    final icon = item.active ? item.activeIcon ?? item.icon : item.icon;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    // The label text is excluded below (this node already carries it), but
    // the icon subtree keeps its semantics so badge decorations — e.g. the
    // Settings outbox count — stay announced. The InkWell contributes the
    // tap action.
    return Semantics(
      button: true,
      selected: item.active,
      label: item.semanticsLabel ?? item.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(tokens.radii.l),
          onTap: item.onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: DesignSystemFiveSlotNavBar.minTapTarget,
              minWidth: DesignSystemFiveSlotNavBar.minTapTarget,
            ),
            child: TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: tint),
              duration: reduceMotion
                  ? Duration.zero
                  : DesignSystemFiveSlotNavBar.tintDuration,
              curve: DesignSystemFiveSlotNavBar.tintCurve,
              builder: (context, color, _) {
                final resolved = color ?? tint;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconTheme.merge(
                      data: IconThemeData(
                        size: DesignSystemFiveSlotNavBar.iconSize,
                        color: resolved,
                      ),
                      child: icon,
                    ),
                    SizedBox(height: tokens.spacing.step1),
                    ExcludeSemantics(
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: tokens.typography.styles.others.caption.copyWith(
                          color: resolved,
                          fontWeight: tokens.typography.weight.semiBold,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
