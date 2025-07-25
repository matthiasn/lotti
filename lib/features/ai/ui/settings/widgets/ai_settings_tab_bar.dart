import 'package:flutter/material.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_filter_state.dart';
import 'package:lotti/themes/theme.dart';

/// A specialized tab bar widget for AI Settings page
///
/// This widget provides a polished tab interface with Material 3 design
/// and smooth transitions between different AI configuration types.
///
/// **Features:**
/// - Material 3 pill-style tab indicator
/// - Smooth animations and transitions
/// - Consistent spacing and typography
/// - Proper accessibility labels
///
/// **Usage:**
/// ```dart
/// AiSettingsTabBar(
///   controller: _tabController,
///   onTabChanged: (tab) => _handleTabChange(tab),
/// )
/// ```
class AiSettingsTabBar extends StatelessWidget {
  const AiSettingsTabBar({
    required this.controller,
    this.onTabChanged,
    super.key,
  });

  /// Controller for the tab bar
  final TabController controller;

  /// Callback invoked when tab selection changes
  final ValueChanged<AiSettingsTab>? onTabChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.light
            ? context.colorScheme.surfaceContainerHighest
            : context.colorScheme.surfaceContainerHigh.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: TabBar(
        controller: controller,
        onTap: (index) {
          final tab = AiSettingsTab.values[index];
          onTabChanged?.call(tab);
        },
        indicator: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.light
              ? context.colorScheme.primaryContainer
              : context.colorScheme.primary,
          borderRadius: BorderRadius.circular(12),
          boxShadow: Theme.of(context).brightness == Brightness.light
              ? []
              : [
                  BoxShadow(
                    color: context.colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(4),
        dividerColor: Colors.transparent,
        labelColor: Theme.of(context).brightness == Brightness.light
            ? context.colorScheme.onPrimaryContainer
            : context.colorScheme.onPrimary,
        unselectedLabelColor:
            context.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
        labelStyle: context.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          fontSize: 14,
        ),
        unselectedLabelStyle: context.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
          fontSize: 14,
        ),
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        tabAlignment: TabAlignment.fill,
        tabs: AiSettingsTab.values
            .map((tab) => Tab(
                  height: 40,
                  text: tab.getLocalizedDisplayName(context),
                ))
            .toList(),
      ),
    );
  }
}
