import 'dart:math' as math;

import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';

/// Builds the always-visible trigger of an [AgentSurfaceMenuButton]; [open]
/// shows the menu under it.
typedef AgentSurfaceMenuTriggerBuilder =
    Widget Function(BuildContext context, VoidCallback open);

/// The overflow menu of a page an agent serves — a goal, a person.
///
/// One menu on both, so they read as one product: the design system's menu
/// surface — rounded, on its own raised level, rows in the design-system
/// type — opened over the page behind the shared modal scrim, so the page
/// steps back and the open menu is plainly the thing in front. A tap on the
/// scrim or Escape closes it without acting; a row closes it, then acts.
///
/// The rows follow one order everywhere: the page's own actions, then the
/// agent's ([agentInternalsMenuItem] last among them), delete at the bottom
/// in the error ink — each group opened by `startsGroup`.
class AgentSurfaceMenuButton extends StatelessWidget {
  const AgentSurfaceMenuButton({
    required this.items,
    required this.triggerBuilder,
    this.semanticsLabel,
    this.header,
    super.key,
  });

  final List<DesignSystemContextMenuItem> items;
  final AgentSurfaceMenuTriggerBuilder triggerBuilder;

  /// A quiet heading above the rows: what they act on, when the trigger
  /// alone does not say it — a row of a list.
  final String? header;

  /// Names the open menu for assistive technology.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) => Builder(
    builder: (anchorContext) => triggerBuilder(
      anchorContext,
      () => showAgentSurfaceMenu(
        anchorContext,
        items: items,
        semanticsLabel: semanticsLabel,
        header: header,
      ),
    ),
  );
}

/// The menu's way into the agent's internals — the same words and glyph on
/// every page that offers it, and the title of the panel it opens.
DesignSystemContextMenuItem agentInternalsMenuItem({
  required BuildContext context,
  required VoidCallback onTap,
  Key? key,
  bool startsGroup = false,
}) => DesignSystemContextMenuItem(
  key: key,
  icon: LottiIcons.tune,
  label: context.messages.aiInternalsTitle,
  onTap: onTap,
  startsGroup: startsGroup,
);

/// Opens the agent-surface menu under the widget [anchorContext] belongs
/// to, on the root navigator so the scrim covers the whole window — the
/// sidebar and the list beside a detail pane included.
Future<void> showAgentSurfaceMenu(
  BuildContext anchorContext, {
  required List<DesignSystemContextMenuItem> items,
  String? semanticsLabel,
  String? header,
}) {
  final navigator = Navigator.of(anchorContext, rootNavigator: true);
  final anchorBox = anchorContext.findRenderObject()! as RenderBox;
  final overlayBox =
      navigator.overlay!.context.findRenderObject()! as RenderBox;
  final anchor =
      anchorBox.localToGlobal(Offset.zero, ancestor: overlayBox) &
      anchorBox.size;
  final theme = Theme.of(anchorContext);
  return navigator.push(
    _AgentSurfaceMenuRoute(
      anchor: anchor,
      items: items,
      semanticsLabel: semanticsLabel,
      header: header,
      barrierColor: ModalUtils.getModalBarrierColor(
        isDark: theme.brightness == Brightness.dark,
        context: anchorContext,
      ),
      barrierLabel: MaterialLocalizations.of(
        anchorContext,
      ).modalBarrierDismissLabel,
      textDirection: Directionality.of(anchorContext),
      capturedThemes: InheritedTheme.capture(
        from: anchorContext,
        to: navigator.context,
      ),
    ),
  );
}

class _AgentSurfaceMenuRoute extends PopupRoute<void> {
  _AgentSurfaceMenuRoute({
    required this.anchor,
    required this.items,
    required this.semanticsLabel,
    required this.header,
    required this.barrierColor,
    required this.barrierLabel,
    required this.textDirection,
    required this.capturedThemes,
  });

  final Rect anchor;
  final List<DesignSystemContextMenuItem> items;
  final String? semanticsLabel;
  final String? header;
  final TextDirection textDirection;
  final CapturedThemes capturedThemes;

  @override
  final Color barrierColor;

  @override
  final String barrierLabel;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => MotionDurations.short4;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final tokens = context.designTokens;
    final menu = DesignSystemContextMenu(
      semanticsLabel: semanticsLabel,
      header: header,
      // As wide as its longest row, and raised off the dimmed page on the
      // card surface — the base level read as a dark hole in the scrim.
      fitContent: true,
      surfaceColor: dsCardSurface(context),
      // The first and last row's hover fill meets the rounded edge instead
      // of leaving a strip of padding above and below it.
      edgeToEdge: true,
      items: [
        for (final item in items)
          DesignSystemContextMenuItem(
            key: item.key,
            label: item.label,
            icon: item.icon,
            iconColor: item.iconColor,
            isDestructive: item.isDestructive,
            isSelected: item.isSelected,
            checked: item.checked,
            startsGroup: item.startsGroup,
            // A null callback is a disabled row and must stay one; a real
            // one closes the menu first, so what it opens is not stacked
            // under a scrim nobody can see the reason for.
            onTap: switch (item.onTap) {
              null => null,
              final onTap => () {
                Navigator.of(context).pop();
                onTap();
              },
            },
          ),
      ],
    );
    return capturedThemes.wrap(
      CustomSingleChildLayout(
        delegate: _AgentSurfaceMenuLayout(
          anchor: anchor,
          textDirection: textDirection,
          gap: tokens.spacing.step2,
          margin: tokens.spacing.step4,
          padding: MediaQuery.paddingOf(context),
        ),
        child: FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: MotionCurves.standard,
          ),
          child: menu,
        ),
      ),
    );
  }
}

/// Places the menu under its trigger, its trailing edge on the trigger's,
/// inside the window's safe area — above the trigger when there is no room
/// below.
class _AgentSurfaceMenuLayout extends SingleChildLayoutDelegate {
  const _AgentSurfaceMenuLayout({
    required this.anchor,
    required this.textDirection,
    required this.gap,
    required this.margin,
    required this.padding,
  });

  final Rect anchor;
  final TextDirection textDirection;
  final double gap;
  final double margin;
  final EdgeInsets padding;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(
        Size(
          math.max(0, constraints.maxWidth - margin * 2),
          math.max(0, constraints.maxHeight - padding.vertical - margin * 2),
        ),
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final preferredX = textDirection == TextDirection.rtl
        ? anchor.left
        : anchor.right - childSize.width;
    final x = preferredX.clamp(
      margin,
      math.max<double>(margin, size.width - margin - childSize.width),
    );
    final below = anchor.bottom + gap;
    final bottomLimit = size.height - padding.bottom - margin;
    final y = below + childSize.height <= bottomLimit
        ? below
        : math.max<double>(
            padding.top + margin,
            anchor.top - gap - childSize.height,
          );
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_AgentSurfaceMenuLayout oldDelegate) =>
      anchor != oldDelegate.anchor ||
      textDirection != oldDelegate.textDirection ||
      gap != oldDelegate.gap ||
      margin != oldDelegate.margin ||
      padding != oldDelegate.padding;
}
