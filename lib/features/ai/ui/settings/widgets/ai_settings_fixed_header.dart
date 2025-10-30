import 'package:extended_sliver/extended_sliver.dart'
    show SliverPinnedToBoxAdapter;
import 'package:flutter/material.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_filter_state.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ai_settings_filter_chips.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ai_settings_search_bar.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ai_settings_tab_bar.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

/// The fixed header section of the AI Settings page
///
/// This widget contains the search bar, tab bar, and filter chips
/// that remain pinned below the app bar when scrolling.
///
/// The header is designed to work with [SliverPinnedToBoxAdapter]
/// to provide a sticky header experience in the sliver-based layout.
///
/// Features:
/// - Search bar for filtering configurations
/// - Tab bar for switching between providers, models, and prompts
/// - Context-aware filter chips (only shown on models tab)
/// - Proper visual separation with border
///
/// Example:
/// ```dart
/// SliverPinnedToBoxAdapter(
///   child: AiSettingsFixedHeader(
///     searchController: _searchController,
///     tabController: _tabController,
///     filterState: _filterState,
///     onSearchClear: _handleSearchClear,
///     onTabChanged: _handleTabChange,
///     onFilterChanged: _updateFilterState,
///   ),
/// )
/// ```
class AiSettingsFixedHeader extends StatelessWidget {
  const AiSettingsFixedHeader({
    required this.searchController,
    required this.tabController,
    required this.filterState,
    required this.onSearchClear,
    required this.onTabChanged,
    required this.onFilterChanged,
    super.key,
  });

  /// Controller for the search text field
  final TextEditingController searchController;

  /// Controller for the tab bar
  final TabController tabController;

  /// Current filter state
  final AiSettingsFilterState filterState;

  /// Callback when search clear button is pressed
  final VoidCallback onSearchClear;

  /// Callback when a tab is selected
  final ValueChanged<AiSettingsTab> onTabChanged;

  /// Callback when filter state changes
  final ValueChanged<AiSettingsFilterState> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: context.colorScheme.primaryContainer.withValues(alpha: 0.15),
          ),
        ),
      ),
      child: Column(
        children: [
          _buildSearchBar(),
          _buildTabBar(),
          _buildFilterSection(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Builder(
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: AiSettingsSearchBar(
            controller: searchController,
            onChanged: (_) => {}, // Handled by controller listener
            onClear: onSearchClear,
            hintText: context.messages.aiSettingsSearchHint,
          ),
        );
      },
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AiSettingsTabBar(
        controller: tabController,
        onTabChanged: onTabChanged,
      ),
    );
  }

  Widget _buildFilterSection() {
    // Provider filters are shown only on Models tab
    if (filterState.activeTab == AiSettingsTab.models) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: AiSettingsFilterChips(
            filterState: filterState,
            onFilterChanged: onFilterChanged,
          ),
        ),
      );
    } else {
      // Maintain consistent spacing when filters are hidden
      return const SizedBox(height: 10);
    }
  }
}
