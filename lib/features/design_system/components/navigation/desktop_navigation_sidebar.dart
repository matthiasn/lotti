import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/branding/design_system_brand_logo.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

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
/// Contains the brand logo, a "New" action button, navigation items,
/// and a Settings entry pinned to the bottom.
class DesktopNavigationSidebar extends StatelessWidget {
  const DesktopNavigationSidebar({
    required this.destinations,
    required this.activeIndex,
    required this.onDestinationSelected,
    this.settingsDestination,
    this.onSettingsSelected,
    this.isSettingsActive = false,
    this.width = 320,
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

  /// Width of the sidebar. Defaults to 320.
  final double width;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Container(
      width: width,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo row
          SizedBox(
            height: 32,
            child: Row(
              children: [
                Icon(
                  Icons.menu_rounded,
                  size: 24,
                  color: tokens.colors.text.mediumEmphasis,
                ),
                const SizedBox(width: 16),
                const DesignSystemBrandLogo(),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Navigation destinations (scrollable for short windows)
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < destinations.length; i++) ...[
                    _DesktopSidebarNavItem(
                      destination: destinations[i],
                      active: i == activeIndex && !isSettingsActive,
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
              onTap: onSettingsSelected,
            ),
        ],
      ),
    );
  }
}

class _DesktopSidebarNavItem extends StatelessWidget {
  const _DesktopSidebarNavItem({
    required this.destination,
    required this.active,
    this.onTap,
  });

  final DesktopSidebarDestination destination;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Semantics(
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
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.step5,
                vertical: tokens.spacing.step4,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: IconTheme(
                        data: IconThemeData(
                          size: 20,
                          color: tokens.colors.text.mediumEmphasis,
                        ),
                        child: destination.iconBuilder(active: active),
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
            ),
          ),
        ),
      ),
    );
  }
}
