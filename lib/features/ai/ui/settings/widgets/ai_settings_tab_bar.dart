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
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color:
            context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: controller,
        onTap: (index) {
          final tab = AiSettingsTab.values[index];
          onTabChanged?.call(tab);
        },
        indicator: BoxDecoration(
          color: context.colorScheme.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(3),
        dividerColor: Colors.transparent,
        labelColor: context.colorScheme.onPrimary,
        unselectedLabelColor: context.colorScheme.onSurfaceVariant,
        labelStyle: context.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        unselectedLabelStyle: context.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w500,
          letterSpacing: -0.2,
        ),
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        tabAlignment: TabAlignment.fill,
        tabs: AiSettingsTab.values
            .map((tab) => Tab(
                  height: 36, // Reduced height for more compact look
                  text: tab.displayName,
                ))
            .toList(),
      ),
    );
  }
}
