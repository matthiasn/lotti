import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/branding/design_system_brand_logo.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Stable key on the sidebar's collapse/expand toggle tile — used by widget
/// tests to locate and tap the toggle without depending on Material icon
/// variants (which can drift between Flutter versions).
@visibleForTesting
const Key desktopSidebarToggleKey = Key('desktop-sidebar-toggle');

/// A navigation destination displayed in the [DesktopNavigationSidebar].
class DesktopSidebarDestination {
  const DesktopSidebarDestination({
    required this.label,
    required this.iconBuilder,
    this.trailingBuilder,
  });

  /// Display label for this destination.
  final String label;

  /// Builder that returns an icon widget based on the active state.
  final Widget Function({required bool active}) iconBuilder;

  /// Optional builder for a trailing widget (e.g. a count badge) rendered
  /// on the right side of the row, aligned with the label.
  final Widget Function({required bool active})? trailingBuilder;
}

/// Persistent left-hand navigation sidebar for the desktop layout.
///
/// Replaces the mobile bottom navigation bar when the window is wide enough.
/// Contains the brand logo, a collapse/expand toggle, navigation items, and
/// a Settings entry pinned to the bottom.
///
/// When [collapsed] is true the sidebar shrinks to [collapsedWidth] and
/// renders icon-only tiles. Trailing widgets (e.g. count badges) are
/// intentionally omitted in collapsed mode — the strip is too narrow to
/// fit a pill, and labels/counts resurface when the user expands the
/// sidebar. Drag-to-resize is expected to be disabled by the parent while
/// collapsed (see `ResizableDivider.enabled`).
class DesktopNavigationSidebar extends StatelessWidget {
  const DesktopNavigationSidebar({
    required this.destinations,
    required this.activeIndex,
    required this.onDestinationSelected,
    this.settingsDestination,
    this.onSettingsSelected,
    this.isSettingsActive = false,
    this.width = 320,
    this.collapsed = false,
    this.collapsedWidth = 72,
    this.onToggleCollapsed,
    super.key,
  });

  /// The main navigation destinations (excluding Settings).
  final List<DesktopSidebarDestination> destinations;

  /// Index of the currently active destination in [destinations].
  final int activeIndex;

  /// Called when a destination is tapped.
  final ValueChanged<int> onDestinationSelected;

  /// Optional Settings destination pinned to the bottom of the sidebar.
  final DesktopSidebarDestination? settingsDestination;

  /// Called when the Settings destination is tapped.
  final VoidCallback? onSettingsSelected;

  /// Whether the Settings destination is currently active.
  final bool isSettingsActive;

  /// Width of the sidebar when expanded. Defaults to 320.
  final double width;

  /// Whether the sidebar is rendered in the narrow icon-only layout.
  final bool collapsed;

  /// Width applied when [collapsed] is true.
  final double collapsedWidth;

  /// Called when the toggle icon next to the logo is tapped. When null, the
  /// toggle icon is rendered but not interactive.
  final VoidCallback? onToggleCollapsed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final effectiveWidth = collapsed ? collapsedWidth : width;

    return Container(
      width: effectiveWidth,
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.step5,
        tokens.spacing.step6,
        tokens.spacing.step5,
        tokens.spacing.step6,
      ),
      decoration: BoxDecoration(
        // Sidebar sits on the lighter `background.level02` so it reads as a
        // distinct surface from the task-list pane (level01). Matches the
        // Figma reference where the nav sidebar is the lighter column.
        color: tokens.colors.background.level02,
      ),
      child: Column(
        crossAxisAlignment: collapsed
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          _SidebarLogoRow(
            collapsed: collapsed,
            onToggle: onToggleCollapsed,
          ),
          const SizedBox(height: 24),

          // Navigation destinations (scrollable for short windows)
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: collapsed
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < destinations.length; i++) ...[
                    _DesktopSidebarNavItem(
                      destination: destinations[i],
                      active: i == activeIndex && !isSettingsActive,
                      collapsed: collapsed,
                      onTap: () => onDestinationSelected(i),
                    ),
                    if (i < destinations.length - 1)
                      SizedBox(height: tokens.spacing.step6),
                  ],
                ],
              ),
            ),
          ),

          // Settings at the bottom
          if (settingsDestination != null)
            _DesktopSidebarNavItem(
              destination: settingsDestination!,
              active: isSettingsActive,
              collapsed: collapsed,
              onTap: onSettingsSelected,
            ),
        ],
      ),
    );
  }
}

/// Logo row at the top of the sidebar.
///
/// Always renders a tappable toggle tile. When expanded, the brand logo is
/// rendered next to the toggle. While collapsed, the brand text is hidden
/// — only the toggle tile remains. The tile itself is a 30×30 square with
/// `background.level03` fill, 8 px rounded corners, and a sidebar-panel
/// glyph (`Icons.view_sidebar_rounded`) at 18 px drawn in
/// `text.highEmphasis`. Matches the Figma spec from the "closed" and "open"
/// Sidebar variants. When [onToggle] is null the tile renders disabled so
/// assistive tech announces it as unavailable instead of silently ignoring
/// taps.
class _SidebarLogoRow extends StatelessWidget {
  const _SidebarLogoRow({
    required this.collapsed,
    this.onToggle,
  });

  final bool collapsed;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final tooltip = collapsed
        ? context.messages.sidebarToggleExpandLabel
        : context.messages.sidebarToggleCollapseLabel;

    final toggleIcon = _SidebarToggleTile(
      tooltip: tooltip,
      onPressed: onToggle,
      tokens: tokens,
    );

    if (collapsed) {
      return SizedBox(height: 32, child: Center(child: toggleIcon));
    }

    // Expanded layout: brand logo on the left, toggle tile pushed to the
    // far right edge of the sidebar — matches the Figma mock where the
    // sidebar-panel glyph sits opposite the logo.
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          const DesignSystemBrandLogo(),
          const Spacer(),
          toggleIcon,
        ],
      ),
    );
  }
}

/// Filled 30×30 tile housing the sidebar-panel toggle glyph. Matches the
/// Figma "Icon" node on both the open and closed Sidebar variants.
class _SidebarToggleTile extends StatelessWidget {
  const _SidebarToggleTile({
    required this.tooltip,
    required this.tokens,
    this.onPressed,
  });

  final String tooltip;
  final DsTokens tokens;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final tile = Material(
      key: desktopSidebarToggleKey,
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: tokens.colors.background.level03,
          borderRadius: BorderRadius.circular(tokens.radii.s),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(tokens.radii.s),
          onTap: onPressed,
          child: SizedBox(
            width: 30,
            height: 30,
            child: Center(
              child: _SidebarPanelGlyph(
                color: tokens.colors.text.highEmphasis,
              ),
            ),
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: tooltip,
      child: Tooltip(message: tooltip, child: tile),
    );
  }
}

/// Hand-drawn sidebar-panel glyph that mirrors the Figma "Union" boolean
/// operation: an outlined 18×14 rounded rectangle with a filled left pane
/// sitting inside it. Using a painter instead of `Icons.view_sidebar_*`
/// avoids Material variant drift between Flutter versions — the Figma
/// mockup dictates stroke width, corner radius, and pane position, so we
/// honour them exactly.
class _SidebarPanelGlyph extends StatelessWidget {
  const _SidebarPanelGlyph({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(
        painter: _SidebarPanelPainter(color: color),
      ),
    );
  }
}

class _SidebarPanelPainter extends CustomPainter {
  const _SidebarPanelPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Figma dimensions: Rectangle 1 is 18×14 (stroke only) and Vector 1 is a
    // 12-long vertical stroke placed inside it. Both left and right of the
    // divider are hollow — only the outer rectangle outline plus the single
    // vertical line are drawn.
    const strokeWidth = 1.75;
    const cornerRadius = 3.0;
    final outerRect = Rect.fromLTWH(
      strokeWidth / 2,
      (size.height - 14) / 2,
      size.width - strokeWidth,
      14 - strokeWidth,
    );
    final outerRRect = RRect.fromRectAndRadius(
      outerRect,
      const Radius.circular(cornerRadius),
    );

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawRRect(outerRRect, strokePaint);

    // Vertical divider — sits about a third of the way from the left edge
    // so the glyph reads as "narrow sidebar on the left, main area on the
    // right". The line extends all the way from the top to the bottom of
    // the outer rectangle so it visually meets both strokes.
    final dividerX = outerRect.left + outerRect.width / 3;
    canvas.drawLine(
      Offset(dividerX, outerRect.top),
      Offset(dividerX, outerRect.bottom),
      strokePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SidebarPanelPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _DesktopSidebarNavItem extends StatelessWidget {
  const _DesktopSidebarNavItem({
    required this.destination,
    required this.active,
    required this.collapsed,
    this.onTap,
  });

  final DesktopSidebarDestination destination;
  final bool active;
  final bool collapsed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    final semantics = Semantics(
      button: true,
      selected: active,
      label: destination.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(tokens.radii.m),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              color: active ? tokens.colors.surface.active : Colors.transparent,
              borderRadius: BorderRadius.circular(tokens.radii.m),
            ),
            child: collapsed
                ? _CollapsedRowContent(
                    destination: destination,
                    active: active,
                  )
                : _ExpandedRowContent(
                    destination: destination,
                    active: active,
                  ),
          ),
        ),
      ),
    );

    if (collapsed) {
      // Tooltip is the visual hover hint only — the Semantics wrapper
      // already contributes `destination.label` as the accessible name, so
      // excluding the tooltip from semantics avoids screen readers
      // announcing the label twice.
      return Tooltip(
        message: destination.label,
        excludeFromSemantics: true,
        child: semantics,
      );
    }

    return semantics;
  }
}

class _ExpandedRowContent extends StatelessWidget {
  const _ExpandedRowContent({
    required this.destination,
    required this.active,
  });

  final DesktopSidebarDestination destination;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step5,
        vertical: tokens.spacing.step4,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Align(
              alignment: Alignment.centerLeft,
              child: ExcludeSemantics(
                child: IconTheme(
                  data: IconThemeData(
                    size: 20,
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                  child: destination.iconBuilder(active: active),
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              destination.label,
              style: tokens.typography.styles.body.bodyMedium.copyWith(
                color: tokens.colors.text.highEmphasis,
              ),
            ),
          ),
          if (destination.trailingBuilder != null) ...[
            SizedBox(width: tokens.spacing.step3),
            destination.trailingBuilder!(active: active),
          ],
        ],
      ),
    );
  }
}

class _CollapsedRowContent extends StatelessWidget {
  const _CollapsedRowContent({
    required this.destination,
    required this.active,
  });

  final DesktopSidebarDestination destination;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return SizedBox(
      width: 40,
      height: 40,
      child: Center(
        child: ExcludeSemantics(
          child: IconTheme(
            data: IconThemeData(
              size: 20,
              color: tokens.colors.text.mediumEmphasis,
            ),
            child: destination.iconBuilder(active: active),
          ),
        ),
      ),
    );
  }
}
