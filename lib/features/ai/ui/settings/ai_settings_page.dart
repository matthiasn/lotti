import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_filter_service.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_filter_state.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_navigation_service.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ai_settings_config_list.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ai_settings_filter_chips.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ai_settings_search_bar.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ai_settings_tab_bar.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/sliver_show_case_title_bar.dart';

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
      body: CustomScrollView(
        slivers: [
          // App bar with title and back button
          const SliverShowCaseTitleBar(
            title: 'AI Settings',
          ),

          // Search and tab bar
          SliverToBoxAdapter(
            child: _buildHeaderSection(),
          ),

          // Main content area
          SliverFillRemaining(
            child: _buildTabContent(),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  /// Builds the header section with search bar and tabs
  Widget _buildHeaderSection() {
    return Container(
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: context.colorScheme.outline.withValues(alpha: 0.15),
          ),
        ),
      ),
      child: Column(
        children: [
          // Search Bar
          AiSettingsSearchBar(
            controller: _searchController,
            onChanged: (_) => {}, // Handled by controller listener
            onClear: _handleSearchClear,
          ),

          // Tab Bar
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AiSettingsTabBar(
              controller: _tabController,
              onTabChanged: _handleTabChange,
            ),
          ),

          // Model Filters (only shown on Models tab)
          if (_filterState.activeTab == AiSettingsTab.models)
            AiSettingsFilterChips(
              filterState: _filterState,
              onFilterChanged: _updateFilterState,
            ),
        ],
      ),
    );
  }

  /// Builds the main tab content area
  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildProvidersTab(),
        _buildModelsTab(),
        _buildPromptsTab(),
      ],
    );
  }

  /// Builds the providers tab content
  Widget _buildProvidersTab() {
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

        return AiSettingsConfigList<AiConfigInferenceProvider>(
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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text('Error loading providers: $error'),
      ),
    );
  }

  /// Builds the models tab content
  Widget _buildModelsTab() {
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

        return AiSettingsConfigList<AiConfigModel>(
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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text('Error loading models: $error'),
      ),
    );
  }

  /// Builds the prompts tab content
  Widget _buildPromptsTab() {
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

        return AiSettingsConfigList<AiConfigPrompt>(
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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text('Error loading prompts: $error'),
      ),
    );
  }

  /// Builds a stylish floating action button with contextual icon and label
  Widget _buildFloatingActionButton() {
    final (icon, label) = switch (_filterState.activeTab) {
      AiSettingsTab.providers => (Icons.hub, 'Add Provider'),
      AiSettingsTab.models => (Icons.smart_toy, 'Add Model'),
      AiSettingsTab.prompts => (Icons.psychology, 'Add Prompt'),
    };

    return FloatingActionButton.extended(
      onPressed: _handleAddTap,
      icon: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: context.colorScheme.onPrimary.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 20,
          color: context.colorScheme.onPrimary,
        ),
      ),
      label: Text(
        label,
        style: context.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: context.colorScheme.onPrimary,
        ),
      ),
      backgroundColor: context.colorScheme.primary,
      foregroundColor: context.colorScheme.onPrimary,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
