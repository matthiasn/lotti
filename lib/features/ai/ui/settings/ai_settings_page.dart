import 'dart:async';

import 'package:extended_sliver/extended_sliver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_filter_service.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_filter_state.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_navigation_service.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ai_settings_config_sliver.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ai_settings_fixed_header.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ai_settings_floating_action_button.dart';
import 'package:lotti/themes/theme.dart';

/// Main AI Settings page providing a unified interface for managing AI configurations
///
/// This page serves as the central hub for managing all AI-related configurations
/// including inference providers, models, and prompts. It replaces the previous
/// scattered AI settings with a cohesive, user-friendly interface.
///
/// **Key Features:**
/// - Tabbed interface for different configuration types
/// - Advanced search and filtering capabilities
/// - Direct navigation to edit pages
/// - Responsive design with proper loading states
///
/// **Architecture:**
/// - Uses service layer for business logic (filtering, navigation)
/// - Immutable state management with Freezed
/// - Modular widget composition for maintainability
/// - Comprehensive error handling and loading states
///
/// **Usage:**
/// ```dart
/// // Navigate via routing
/// context.beamToNamed('/settings/ai');
///
/// // Or push directly
/// Navigator.push(context, MaterialPageRoute(
///   builder: (_) => const AiSettingsPage(),
/// ));
/// ```
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
      case AiSettingsTab.prompts:
        await _navigationService.navigateToCreatePrompt(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colorScheme.scrim,
      body: CustomScrollView(
        controller: _scrollController,
        physics: const ClampingScrollPhysics(),
        slivers: [
          // Simple app bar with collapsing title
          SliverAppBar(
            expandedHeight: 100,
            pinned: true,
            backgroundColor: context.colorScheme.surface,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: context.colorScheme.onSurface,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'AI Settings',
                style: TextStyle(
                  color: context.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      context.colorScheme.surface,
                      context.colorScheme.scrim,
                    ],
                  ),
                ),
              ),
            ),
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
      case AiSettingsTab.prompts:
        return [_buildPromptsSliver()];
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
        final providers =
            configs.whereType<AiConfigInferenceProvider>().toList();
        final filteredProviders =
            _filterService.filterProviders(providers, _filterState);

        return AiSettingsConfigSliver<AiConfigInferenceProvider>(
          configsAsync: providersAsync,
          filteredConfigs: filteredProviders,
          emptyMessage: 'No AI providers configured',
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
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => SliverFillRemaining(
        child: Center(
          child: Text('Error loading providers: $error'),
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
        final filteredModels =
            _filterService.filterModels(models, _filterState);

        return AiSettingsConfigSliver<AiConfigModel>(
          configsAsync: modelsAsync,
          filteredConfigs: filteredModels,
          emptyMessage: 'No AI models configured',
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
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => SliverFillRemaining(
        child: Center(
          child: Text('Error loading models: $error'),
        ),
      ),
    );
  }

  /// Builds the prompts sliver
  Widget _buildPromptsSliver() {
    final promptsAsync = ref.watch(
      aiConfigByTypeControllerProvider(
        configType: AiConfigType.prompt,
      ),
    );

    return promptsAsync.when(
      data: (configs) {
        final prompts = configs.whereType<AiConfigPrompt>().toList();
        final filteredPrompts =
            _filterService.filterPrompts(prompts, _filterState);

        return AiSettingsConfigSliver<AiConfigPrompt>(
          configsAsync: promptsAsync,
          filteredConfigs: filteredPrompts,
          emptyMessage: 'No AI prompts configured',
          emptyIcon: Icons.psychology,
          onConfigTap: _handleConfigTap,
          onRetry: () => ref.invalidate(
            aiConfigByTypeControllerProvider(
              configType: AiConfigType.prompt,
            ),
          ),
        );
      },
      loading: () => const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => SliverFillRemaining(
        child: Center(
          child: Text('Error loading prompts: $error'),
        ),
      ),
    );
  }
}
