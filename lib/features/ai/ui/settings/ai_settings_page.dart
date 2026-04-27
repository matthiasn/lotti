import 'dart:async';

import 'package:extended_sliver/extended_sliver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/inference_profile_controller.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_filter_service.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_filter_state.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_navigation_service.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ai_settings_config_sliver.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ai_settings_fixed_header.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ai_settings_floating_action_button.dart';
import 'package:lotti/features/ai/ui/settings/widgets/config_error_state.dart';
import 'package:lotti/features/ai/ui/settings/widgets/config_loading_state.dart';
import 'package:lotti/features/ai/ui/widgets/profile_card.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/settings_page_header.dart';

/// Embeddable body alias for the Settings V2 detail pane (plan
/// step 9). Polish step 10 will give the V1 page a headerless
/// embedded mode; today this alias ships the page as-is with a
/// minor duplicate title.
class AiSettingsBody extends StatelessWidget {
  const AiSettingsBody({super.key});

  @override
  Widget build(BuildContext context) => const AiSettingsPage();
}

/// Main AI Settings page providing a unified interface for managing
/// AI configurations including inference providers, models, and profiles.
class AiSettingsPage extends ConsumerStatefulWidget {
  const AiSettingsPage({super.key});

  @override
  ConsumerState<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends ConsumerState<AiSettingsPage>
    with TickerProviderStateMixin {
  // Controllers
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Services
  final _filterService = const AiSettingsFilterService();
  final _navigationService = const AiSettingsNavigationService();

  // State
  AiSettingsFilterState _filterState = AiSettingsFilterState.initial();

  // Debouncing
  Timer? _searchDebounceTimer;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  /// Initializes controllers and sets up listeners
  void _initializeControllers() {
    _tabController = TabController(
      length: AiSettingsTab.values.length,
      vsync: this,
    );

    // Listen to tab changes
    _tabController.addListener(_handleTabControllerChange);

    // Listen to search changes with debouncing
    _searchController.addListener(_handleSearchChange);
  }

  /// Properly disposes of controllers to prevent memory leaks
  void _disposeControllers() {
    _searchDebounceTimer?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
  }

  /// Handles search query changes with debouncing to avoid excessive filtering
  void _handleSearchChange() {
    // Cancel the previous timer if it exists
    _searchDebounceTimer?.cancel();

    // Set up a new timer for debouncing (300ms delay)
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      final newQuery = _searchController.text.toLowerCase();
      if (newQuery != _filterState.searchQuery) {
        _updateFilterState(_filterState.copyWith(searchQuery: newQuery));
      }
    });
  }

  /// Handles tab controller changes and updates filter state
  void _handleTabControllerChange() {
    if (_tabController.indexIsChanging) return;

    final newTab = AiSettingsTab.values[_tabController.index];
    if (newTab != _filterState.activeTab) {
      _updateFilterState(_filterState.copyWith(activeTab: newTab));
    }
  }

  /// Updates the filter state and triggers UI rebuild
  void _updateFilterState(AiSettingsFilterState newState) {
    setState(() {
      _filterState = newState;
    });
  }

  /// Handles tab changes and updates filter state
  void _handleTabChange(AiSettingsTab tab) {
    final newState = _filterState.copyWith(activeTab: tab);
    _updateFilterState(newState);

    // Sync the tab controller if needed (for programmatic tab changes)
    if (_tabController.index != tab.index) {
      _tabController.animateTo(tab.index);
    }
  }

  /// Handles search bar clear action
  void _handleSearchClear() {
    _searchController.clear();
    _updateFilterState(_filterState.copyWith(searchQuery: ''));
  }

  /// Handles configuration tap and navigates to edit page
  Future<void> _handleConfigTap(AiConfig config) async {
    await _navigationService.navigateToConfigEdit(context, config);
  }

  /// Handles add button tap and navigates to create page based on current tab
  Future<void> _handleAddTap() async {
    switch (_filterState.activeTab) {
      case AiSettingsTab.providers:
        await _navigationService.navigateToCreateProvider(context);
      case AiSettingsTab.models:
        await _navigationService.navigateToCreateModel(context);
      case AiSettingsTab.profiles:
        await _navigationService.navigateToCreateProfile(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.light
          ? context.colorScheme.surfaceContainerLowest
          : context.colorScheme.scrim,
      body: CustomScrollView(
        controller: _scrollController,
        physics: const ClampingScrollPhysics(),
        slivers: [
          // Premium settings header with collapsing title
          SettingsPageHeader(
            title: context.messages.aiSettingsPageTitle,
            showBackButton: true,
          ),

          // Fixed header with search, tabs and filters
          SliverPinnedToBoxAdapter(
            child: AiSettingsFixedHeader(
              searchController: _searchController,
              tabController: _tabController,
              filterState: _filterState,
              onSearchClear: _handleSearchClear,
              onTabChanged: _handleTabChange,
              onFilterChanged: _updateFilterState,
            ),
          ),

          // Main content
          ..._buildTabContentSlivers(),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: AiSettingsFloatingActionButton(
        activeTab: _filterState.activeTab,
        onPressed: _handleAddTap,
      ),
    );
  }

  /// Builds the main tab content area as slivers
  List<Widget> _buildTabContentSlivers() {
    switch (_filterState.activeTab) {
      case AiSettingsTab.providers:
        return [_buildProvidersSliver()];
      case AiSettingsTab.models:
        return [_buildModelsSliver()];
      case AiSettingsTab.profiles:
        return [_buildProfilesSliver()];
    }
  }

  /// Builds the providers sliver
  Widget _buildProvidersSliver() {
    final providersAsync = ref.watch(
      aiConfigByTypeControllerProvider(
        configType: AiConfigType.inferenceProvider,
      ),
    );

    return providersAsync.when(
      data: (configs) {
        final providers = configs
            .whereType<AiConfigInferenceProvider>()
            .toList();
        final filteredProviders = _filterService.filterProviders(
          providers,
          _filterState,
        );

        return AiSettingsConfigSliver<AiConfigInferenceProvider>(
          configsAsync: providersAsync,
          filteredConfigs: filteredProviders,
          emptyMessage: context.messages.aiSettingsNoProvidersConfigured,
          emptyIcon: Icons.hub,
          onConfigTap: _handleConfigTap,
          onRetry: () => ref.invalidate(
            aiConfigByTypeControllerProvider(
              configType: AiConfigType.inferenceProvider,
            ),
          ),
        );
      },
      loading: () => const SliverFillRemaining(
        child: ConfigLoadingState(),
      ),
      error: (error, _) => SliverFillRemaining(
        hasScrollBody: false,
        child: ConfigErrorState(
          error: error,
          onRetry: () => ref.invalidate(
            aiConfigByTypeControllerProvider(
              configType: AiConfigType.inferenceProvider,
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the models sliver
  Widget _buildModelsSliver() {
    final modelsAsync = ref.watch(
      aiConfigByTypeControllerProvider(
        configType: AiConfigType.model,
      ),
    );

    return modelsAsync.when(
      data: (configs) {
        final models = configs.whereType<AiConfigModel>().toList();
        final filteredModels = _filterService.filterModels(
          models,
          _filterState,
        );

        return AiSettingsConfigSliver<AiConfigModel>(
          configsAsync: modelsAsync,
          filteredConfigs: filteredModels,
          emptyMessage: context.messages.aiSettingsNoModelsConfigured,
          emptyIcon: Icons.smart_toy,
          onConfigTap: _handleConfigTap,
          showCapabilities: true,
          onRetry: () => ref.invalidate(
            aiConfigByTypeControllerProvider(
              configType: AiConfigType.model,
            ),
          ),
        );
      },
      loading: () => const SliverFillRemaining(
        child: ConfigLoadingState(),
      ),
      error: (error, _) => SliverFillRemaining(
        hasScrollBody: false,
        child: ConfigErrorState(
          error: error,
          onRetry: () => ref.invalidate(
            aiConfigByTypeControllerProvider(
              configType: AiConfigType.model,
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the profiles sliver
  Widget _buildProfilesSliver() {
    final profilesAsync = ref.watch(inferenceProfileControllerProvider);

    return profilesAsync.when(
      data: (configs) {
        final profiles = configs.whereType<AiConfigInferenceProfile>().toList();

        // Apply search filter
        final query = _filterState.searchQuery;
        final filteredProfiles = query.isEmpty
            ? profiles
            : profiles
                  .where((p) => p.name.toLowerCase().contains(query))
                  .toList();

        if (filteredProfiles.isEmpty) {
          final emptyMessage = query.isNotEmpty
              ? context.messages.multiSelectNoItemsFound
              : context.messages.inferenceProfilesEmpty;
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tune,
                    size: 48,
                    color: context.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    emptyMessage,
                    style: context.textTheme.bodyLarge?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.separated(
            itemCount: filteredProfiles.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final profile = filteredProfiles[index];
              return ProfileCard(
                profile: profile,
                onTap: () => _handleConfigTap(profile),
              );
            },
          ),
        );
      },
      loading: () => const SliverFillRemaining(
        child: ConfigLoadingState(),
      ),
      error: (error, _) => SliverFillRemaining(
        hasScrollBody: false,
        child: ConfigErrorState(
          error: error,
          onRetry: () => ref.invalidate(inferenceProfileControllerProvider),
        ),
      ),
    );
  }
}
