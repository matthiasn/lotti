import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

class NavigationFooter extends StatelessWidget {
  const NavigationFooter({
    required this.totalReleases,
    required this.currentRelease,
    required this.colorScheme,
    required this.onNavigate,
    required this.onMarkAllSeen,
    super.key,
  });

  final int totalReleases;
  final int currentRelease;
  final ColorScheme colorScheme;
  final ValueChanged<int> onNavigate;
  final VoidCallback onMarkAllSeen;

  @override
  Widget build(BuildContext context) {
    final canGoNewer = currentRelease > 0;
    final canGoOlder = currentRelease < totalReleases - 1;
    final isLastPage = !canGoOlder;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.85),
            border: Border(
              top: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.1),
              ),
            ),
          ),
          child: Row(
            children: [
              // Skip button (hidden on last page)
              _buildActionButton(
                context,
                label: context.messages.whatsNewSkipButton,
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
                isVisible: !isLastPage,
              ),

              // Left arrow (newer)
              _NavigationArrow(
                icon: Icons.chevron_left,
                isVisible: canGoNewer,
                onTap: () => onNavigate(currentRelease - 1),
                tooltip: 'Newer release',
                colorScheme: colorScheme,
              ),

              // Indicator dots (centered)
              Expanded(
                child: Center(
                  child: _IndicatorDots(
                    total: totalReleases,
                    current: currentRelease,
                    colorScheme: colorScheme,
                  ),
                ),
              ),

              // Right arrow (older)
              _NavigationArrow(
                icon: Icons.chevron_right,
                isVisible: canGoOlder,
                onTap: () => onNavigate(currentRelease + 1),
                tooltip: 'Older release',
                colorScheme: colorScheme,
              ),

              // Done button (shown on last page)
              _buildActionButton(
                context,
                label: context.messages.whatsNewDoneButton,
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
                isVisible: isLastPage,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a footer action button (Skip or Done).
  Widget _buildActionButton(
    BuildContext context, {
    required String label,
    required Color color,
    required FontWeight fontWeight,
    required bool isVisible,
  }) {
    return SizedBox(
      width: 64,
      child: isVisible
          ? TextButton(
              onPressed: onMarkAllSeen,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: fontWeight,
                ),
              ),
            )
          : null,
    );
  }
}

/// Navigation arrow button with animated visibility.
class _NavigationArrow extends StatelessWidget {
  const _NavigationArrow({
    required this.icon,
    required this.isVisible,
    required this.onTap,
    required this.tooltip,
    required this.colorScheme,
  });

  final IconData icon;
  final bool isVisible;
  final VoidCallback onTap;
  final String tooltip;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isVisible ? 1.0 : 0.0,
        child: isVisible
            ? IconButton(
                icon: Icon(icon),
                onPressed: onTap,
                tooltip: tooltip,
                color: colorScheme.primary,
                iconSize: 28,
              )
            : null,
      ),
    );
  }
}

/// Animated indicator dots showing current position in releases.
class _IndicatorDots extends StatelessWidget {
  const _IndicatorDots({
    required this.total,
    required this.current,
    required this.colorScheme,
  });

  final int total;
  final int current;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (index) {
        final isActive = index == current;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutQuart,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: isActive
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.3),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.4),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }
}
