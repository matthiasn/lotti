import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/inference_profile_controller.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_filter_service.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_filter_state.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_navigation_service.dart';
import 'package:lotti/features/ai/ui/settings/breakpoints.dart';
import 'package:lotti/features/ai/ui/settings/services/ai_config_delete_service.dart';
import 'package:lotti/features/ai/ui/settings/util/active_profile.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ai_settings_filter_chips.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ai_settings_floating_action_button.dart';
import 'package:lotti/features/ai/ui/settings/widgets/config_error_state.dart';
import 'package:lotti/features/ai/ui/settings/widgets/config_loading_state.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ftue/ai_pick_provider_modal.dart';
import 'package:lotti/features/ai/ui/settings/widgets/provider_type_selection_modal.dart';
import 'package:lotti/features/ai/ui/settings/widgets/v2/ai_card_action_menu.dart';
import 'package:lotti/features/ai/ui/settings/widgets/v2/ai_settings_cards.dart';
import 'package:lotti/features/ai/ui/settings/widgets/v2/ai_settings_empty_view.dart';
import 'package:lotti/features/ai/ui/settings/widgets/v2/ai_settings_header_bar.dart';
import 'package:lotti/features/ai/ui/settings/widgets/v2/ai_settings_tab_bar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/app_bar/settings_page_header.dart';

/// `SettingsDb` key that suppresses the [AiPickProviderModal] FTUE
/// prompt after the user taps "Don't show again". Lives at the page
/// level (not on the modal) so the FAB handler can short-circuit
/// straight to the create form without first instantiating the modal.
const String kAiPickProviderDismissedKey = 'AI_PICK_PROVIDER_DISMISSED';

/// Embeddable body alias for the Settings V2 detail pane.
///
/// Same widget tree as the standalone page in its default form. The
/// optional [initialTab] + [hideTabBar] params drive the per-leaf
/// embedded mode the master/detail panel registry uses on desktop:
/// when a specific tab is pinned and the tab bar is hidden, the
/// panel slot renders only that tab's body so the sidebar leaves
/// (Providers / Models / Profiles) each map to one focused view —
/// no in-pane tab strip on top of the sidebar selection.
class AiSettingsBody extends StatelessWidget {
  const AiSettingsBody({
    this.initialTab,
    this.hideTabBar = false,
    this.hideHeader = false,
    super.key,
  });

  /// Pre-selects a tab. When provided, [AiSettingsPage] seeds its
  /// filter state and `TabController.index` from this value so the
  /// matching tab's body renders without the user tapping anything.
  final AiSettingsTab? initialTab;

  /// Removes the in-pane tab bar widget when `true`. Used by the
  /// per-leaf desktop panels — the sidebar already names the leaf, a
  /// second tab strip on top would be redundant.
  final bool hideTabBar;

  /// Suppresses the in-pane `SettingsPageHeader` (the "< AI Settings"
  /// title strip). Used by the desktop master/detail surface where
  /// the panel chrome already shows the breadcrumb
  /// "Settings > AI Settings > Providers" — repeating the title above
  /// the search bar is redundant.
  final bool hideHeader;

  @override
  Widget build(BuildContext context) => AiSettingsPage(
    initialTab: initialTab,
    hideTabBar: hideTabBar,
    hideHeader: hideHeader,
  );
}

/// Main AI Settings page. Visual reference: the D1 PNGs at
/// `/Desktop/ai-settings-images`. Layered top-to-bottom:
///
/// 1. SettingsPageHeader — "AI Settings" title strip with back nav.
/// 2. AiSettingsHeaderBar — subtitle paragraph + search field + green
///    "+ Add provider" CTA. Replaces the v1 floating action button.
/// 3. AiSettingsFtueBanner — visible only when zero providers exist.
/// 4. AiSettingsTabBar — Providers / Models / Profiles with counters
///    baked into each label.
/// 5. Active tab body:
///    - Zero providers: AiSettingsNoProvidersCard with four compact
///      provider chips inside a single wrapper card.
///    - Providers tab: 2-column responsive grid of AiProviderCard.
///    - Models tab: single-column list of AiModelCard.
///    - Profiles tab: 2-column responsive grid of AiProfileCard.
///
/// State management (tab controller, search debounce, filter state,
/// navigation service) is preserved verbatim from the v1 page; only
/// the rendering layer is new.
class AiSettingsPage extends ConsumerStatefulWidget {
  const AiSettingsPage({
    this.initialTab,
    this.hideTabBar = false,
    this.hideHeader = false,
    super.key,
  });

  /// Pre-selects a tab. Seeds the filter state and the
  /// `TabController.index` so the matching body renders on first
  /// frame; the page falls back to `AiSettingsFilterState.initial()`
  /// when this is null (standalone mobile usage).
  final AiSettingsTab? initialTab;

  /// Suppresses the in-pane `AiSettingsTabBar`. Used by the v4 panel
  /// registry so each desktop leaf (Providers / Models / Profiles)
  /// renders only its focused tab body — the sidebar leaf itself
  /// already names the view.
  final bool hideTabBar;

  /// Suppresses the in-pane `SettingsPageHeader`. Used by the v4
  /// desktop panel registry — the master/detail chrome already
  /// renders the breadcrumb so the duplicate title strip just
  /// crowded the search bar.
  final bool hideHeader;

  @override
  ConsumerState<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends ConsumerState<AiSettingsPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final _filterService = const AiSettingsFilterService();
  final _navigationService = const AiSettingsNavigationService();
  final _deleteService = const AiConfigDeleteService();

  late AiSettingsFilterState _filterState;

  Timer? _searchDebounceTimer;

  @override
  void initState() {
    super.initState();
    final seededTab = widget.initialTab;
    _filterState = seededTab == null
        ? AiSettingsFilterState.initial()
        : AiSettingsFilterState.initial().copyWith(activeTab: seededTab);
    _tabController = TabController(
      length: AiSettingsTab.values.length,
      initialIndex: seededTab?.index ?? 0,
      vsync: this,
    )..addListener(_handleTabControllerChange);
    _searchController.addListener(_handleSearchChange);
  }

  @override
  void didUpdateWidget(covariant AiSettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The desktop master/detail surface reuses this page's State
    // across leaf swaps (Providers / Models / Profiles); reapply
    // `initialTab` so the visible tab, filter state, and per-tab FAB
    // handler stay in sync. `initState` only fires on first mount,
    // so without this the page would stay pinned to the seed tab.
    final nextTab = widget.initialTab;
    if (nextTab == null || nextTab == oldWidget.initialTab) return;
    if (_filterState.activeTab != nextTab) {
      setState(() {
        _filterState = _filterState.copyWith(activeTab: nextTab);
      });
    }
    if (_tabController.index != nextTab.index) {
      _tabController.index = nextTab.index;
    }
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleSearchChange() {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      final newQuery = _searchController.text.toLowerCase();
      if (newQuery != _filterState.searchQuery) {
        _updateFilterState(_filterState.copyWith(searchQuery: newQuery));
      }
    });
  }

  void _handleTabControllerChange() {
    if (_tabController.indexIsChanging) return;
    final newTab = AiSettingsTab.values[_tabController.index];
    if (newTab != _filterState.activeTab) {
      _updateFilterState(_filterState.copyWith(activeTab: newTab));
    }
  }

  void _updateFilterState(AiSettingsFilterState newState) {
    setState(() => _filterState = newState);
  }

  void _handleTabChange(AiSettingsTab tab) {
    _updateFilterState(_filterState.copyWith(activeTab: tab));
    if (_tabController.index != tab.index) {
      _tabController.animateTo(tab.index);
    }
  }

  void _handleSearchClear() {
    _searchController.clear();
    _updateFilterState(_filterState.copyWith(searchQuery: ''));
  }

  Future<void> _handleConfigTap(AiConfig config) async {
    // Provider rows route through the new detail page (PR-4);
    // model + profile rows still open their edit form directly.
    if (config is AiConfigInferenceProvider) {
      await _navigationService.navigateToProviderDetail(
        context,
        providerId: config.id,
      );
      return;
    }
    await _navigationService.navigateToConfigEdit(context, config);
  }

  /// Fires from the provider card's "Fix" affordance when status is
  /// `invalidKey`. Routes through the detail page so the user lands in
  /// the same place they'd land from a regular row tap, but the detail
  /// page immediately pushes the edit form with the API key field
  /// focused — saves the user a tap when the only thing they came
  /// here for was to paste a fresh key.
  Future<void> _handleFixProvider(AiConfigInferenceProvider provider) async {
    await _navigationService.navigateToProviderDetail(
      context,
      providerId: provider.id,
      focusApiKey: true,
    );
  }

  Future<void> _handleAddProvider() async {
    // Two-tier picker behaviour:
    //
    //  - Fresh users (dismiss flag NOT set) see the rich
    //    [AiPickProviderModal] with branded tiles (Gemini, OpenAI,
    //    Anthropic, Alibaba, Ollama, Voxtral) — the FTUE-grade flow.
    //
    //  - Users who tapped "Don't show again" once before see the
    //    legacy [ProviderTypeSelectionModal] instead. It lists the
    //    full `InferenceProviderType` enum (including OpenRouter,
    //    Nebius, generic OpenAI, etc.) so power users can still
    //    reach every provider type, including Ollama — without
    //    being re-prompted with the FTUE pitch they've already
    //    opted out of. Before this routing existed the dismissed
    //    path landed on the create form pre-filled to
    //    `genericOpenAi` with no surfaced way to pick a different
    //    type, which silently blocked the "start with Gemini, then
    //    add Ollama" workflow.
    final settingsDb = getIt<SettingsDb>();
    final dismissed =
        await settingsDb.itemByKey(kAiPickProviderDismissedKey) == 'true';
    if (!mounted) return;
    if (dismissed) {
      final pickedType = await ProviderTypeSelectionModal.showForResult(
        context: context,
      );
      if (!mounted || pickedType == null) return;
      await _navigationService.navigateToCreateProvider(
        context,
        preselectedType: pickedType,
      );
      return;
    }

    final result = await AiPickProviderModal.show(context: context);
    if (!mounted) return;
    switch (result.kind) {
      case AiPickProviderResultKind.confirmed:
        await _navigationService.navigateToCreateProvider(
          context,
          preselectedType: result.providerType,
        );
      case AiPickProviderResultKind.dontShowAgain:
        // Persist the suppression flag — next FAB tap routes through
        // the legacy [ProviderTypeSelectionModal] above instead of
        // re-popping this FTUE picker. We do NOT also push the form
        // here: tapping "Don't show again" is a hide-this-prompt
        // action, not an add-a-provider one.
        await settingsDb.saveSettingsItem(kAiPickProviderDismissedKey, 'true');
      case AiPickProviderResultKind.cancelled:
        break;
    }
  }

  /// Per-tab handler that the `AiSettingsFloatingActionButton`
  /// dispatches to. The FAB itself already owns the icon + semantic
  /// label per active tab (`add_link` for providers,
  /// `auto_awesome` for models, `tune` for profiles), so the page
  /// just plumbs through the right `navigateToCreate*` call.
  VoidCallback _activeTabAddHandler() {
    switch (_filterState.activeTab) {
      case AiSettingsTab.providers:
        return _handleAddProvider;
      case AiSettingsTab.models:
        return () => _navigationService.navigateToCreateModel(context);
      case AiSettingsTab.profiles:
        return () => _navigationService.navigateToCreateProfile(context);
    }
  }

  /// Opens the provider edit page preselected to [type] — used by the
  /// four quick-add chips inside the empty-state "No providers yet"
  /// card. The form's existing save handler still runs the FTUE flow.
  Future<void> _handleQuickAddChip(InferenceProviderType type) async {
    await _navigationService.navigateToCreateProvider(
      context,
      preselectedType: type,
    );
  }

  /// Builds the `Edit` + `Delete` rows shown in a v2 card's `⋯`
  /// overflow menu. `Edit` mirrors a card tap (kept so the menu is
  /// the source of truth for what a row can do); `Delete` runs the
  /// existing [AiConfigDeleteService] which handles confirmation,
  /// cascade delete for providers, and the undo snackbar.
  List<AiCardMenuAction> _buildCardMenu(AiConfig config) {
    return [
      AiCardMenuAction(
        icon: Icons.edit_outlined,
        label: context.messages.aiCardMenuActionEdit,
        onSelected: () => _handleConfigTap(config),
      ),
      AiCardMenuAction(
        icon: Icons.delete_outline_rounded,
        label: context.messages.aiCardMenuActionDelete,
        isDestructive: true,
        onSelected: () => _deleteService.deleteConfig(
          context: context,
          ref: ref,
          config: config,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Scaffold(
      backgroundColor: tokens.colors.background.level01,
      floatingActionButton: AiSettingsFloatingActionButton(
        key: ValueKey('ai-settings-fab-${_filterState.activeTab.name}'),
        activeTab: _filterState.activeTab,
        onPressed: _activeTabAddHandler(),
      ),
      body: CustomScrollView(
        controller: _scrollController,
        physics: const ClampingScrollPhysics(),
        slivers: [
          if (!widget.hideHeader)
            SettingsPageHeader(
              title: context.messages.aiSettingsPageTitle,
              showBackButton: true,
            ),
          SliverPadding(
            // The page header sliver above contributes its own bottom
            // padding to the search bar; when it's hidden (desktop
            // master/detail) the search bar would otherwise sit flush
            // against the panel chrome, so we add an explicit top
            // breathing room from the design-system spacing scale.
            padding: EdgeInsets.only(
              top: widget.hideHeader ? tokens.spacing.step5 : 0,
            ),
            sliver: SliverToBoxAdapter(
              child: AiSettingsHeaderBar(
                searchController: _searchController,
                onSearchClear: _handleSearchClear,
              ),
            ),
          ),
          ..._buildBodySlivers(),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  List<Widget> _buildBodySlivers() {
    final providersAsync = ref.watch(
      aiConfigByTypeControllerProvider(
        configType: AiConfigType.inferenceProvider,
      ),
    );

    final providers = providersAsync.value
        ?.whereType<AiConfigInferenceProvider>()
        .toList();

    if (providersAsync.isLoading && providers == null) {
      return [const SliverFillRemaining(child: ConfigLoadingState())];
    }
    if (providersAsync.hasError && providers == null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ConfigErrorState(
            error: providersAsync.error!,
            onRetry: () => ref.invalidate(
              aiConfigByTypeControllerProvider(
                configType: AiConfigType.inferenceProvider,
              ),
            ),
          ),
        ),
      ];
    }

    final modelsAsync = ref.watch(
      aiConfigByTypeControllerProvider(configType: AiConfigType.model),
    );
    final profilesAsync = ref.watch(inferenceProfileControllerProvider);
    final models =
        modelsAsync.value?.whereType<AiConfigModel>().toList() ??
        const <AiConfigModel>[];
    final profiles =
        profilesAsync.value?.whereType<AiConfigInferenceProfile>().toList() ??
        const <AiConfigInferenceProfile>[];

    final tokens = context.designTokens;

    if ((providers ?? const []).isEmpty) {
      return [
        SliverPadding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.step5,
            vertical: tokens.spacing.step3,
          ),
          sliver: SliverToBoxAdapter(
            child: AiSettingsFtueBanner(
              onStartSetup: _handleAddProvider,
            ),
          ),
        ),
        if (!widget.hideTabBar)
          SliverToBoxAdapter(
            child: AiSettingsTabBar(
              tabController: _tabController,
              providerCount: 0,
              modelCount: models.length,
              profileCount: profiles.length,
              onTabChanged: _handleTabChange,
            ),
          ),
        SliverPadding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.step5,
            vertical: tokens.spacing.step5,
          ),
          sliver: SliverToBoxAdapter(
            child: AiSettingsNoProvidersCard(
              onProviderChipTap: _handleQuickAddChip,
            ),
          ),
        ),
      ];
    }

    return [
      if (!widget.hideTabBar)
        SliverToBoxAdapter(
          child: AiSettingsTabBar(
            tabController: _tabController,
            providerCount: providers!.length,
            modelCount: models.length,
            profileCount: profiles.length,
            onTabChanged: _handleTabChange,
          ),
        ),
      ..._buildActiveTabBody(providers!, models, profiles),
    ];
  }

  List<Widget> _buildActiveTabBody(
    List<AiConfigInferenceProvider> providers,
    List<AiConfigModel> models,
    List<AiConfigInferenceProfile> profiles,
  ) {
    switch (_filterState.activeTab) {
      case AiSettingsTab.providers:
        return [_buildProvidersGrid(providers, models)];
      case AiSettingsTab.models:
        return [
          // Filter strip on the Models tab — same wiring main's
          // `AiSettingsFixedHeader._buildFilterSection` uses: wrap
          // `AiSettingsFilterChips` in a horizontal
          // `SingleChildScrollView` so each of the widget's two
          // inner `Wrap`s (providers row, capabilities row) gets
          // unbounded width and lays every chip on a single line.
          // On mobile the user swipes left/right to see overflowing
          // chips instead of seeing them stack into 5+ rows. Padding
          // tracks the design-system spacing scale (step5/step4)
          // — main's literal `(20, 12, 20, 10)` predates token
          // adoption and gets the same visual weight rounded to the
          // nearest token step.
          SliverToBoxAdapter(
            child: Builder(
              builder: (context) {
                final tokens = context.designTokens;
                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    tokens.spacing.step5,
                    tokens.spacing.step4,
                    tokens.spacing.step5,
                    tokens.spacing.step4,
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: AiSettingsFilterChips(
                      filterState: _filterState,
                      onFilterChanged: _updateFilterState,
                    ),
                  ),
                );
              },
            ),
          ),
          _buildModelsList(models, providers),
        ];
      case AiSettingsTab.profiles:
        return [_buildProfilesGrid(profiles, models, providers)];
    }
  }

  // ---------------------------------------------------------------
  // Providers tab — responsive list (1 col mobile, 2 col desktop)
  // ---------------------------------------------------------------

  Widget _buildProvidersGrid(
    List<AiConfigInferenceProvider> providers,
    List<AiConfigModel> models,
  ) {
    final tokens = context.designTokens;
    final modelsByProvider = <String, int>{};
    for (final m in models) {
      modelsByProvider[m.inferenceProviderId] =
          (modelsByProvider[m.inferenceProviderId] ?? 0) + 1;
    }
    final filtered = _filterService.filterProviders(providers, _filterState);
    if (filtered.isEmpty) {
      return _emptyTabSliver(context.messages.aiSettingsNoProvidersConfigured);
    }

    AiProviderCard buildCard(AiConfigInferenceProvider provider) {
      final modelCount = modelsByProvider[provider.id] ?? 0;
      final status = AiProviderCard.statusFor(
        provider: provider,
        modelCount: modelCount,
      );
      return AiProviderCard(
        provider: provider,
        modelCount: modelCount,
        status: status,
        onTap: () => _handleConfigTap(provider),
        menuActions: _buildCardMenu(provider),
        onFix: status == AiProviderCardStatus.invalidKey
            ? () => _handleFixProvider(provider)
            : null,
      );
    }

    return _buildCardList<AiConfigInferenceProvider>(
      tokens: tokens,
      items: filtered,
      buildCard: buildCard,
    );
  }

  // ---------------------------------------------------------------
  // Models tab — single-column list
  // ---------------------------------------------------------------

  Widget _buildModelsList(
    List<AiConfigModel> models,
    List<AiConfigInferenceProvider> providers,
  ) {
    final filtered = _filterService.filterModels(models, _filterState);
    if (filtered.isEmpty) {
      return _emptyTabSliver(context.messages.aiSettingsNoModelsConfigured);
    }
    final tokens = context.designTokens;
    final providerTypeById = <String, InferenceProviderType>{
      for (final p in providers) p.id: p.inferenceProviderType,
    };
    return SliverPadding(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step5,
        vertical: tokens.spacing.step3,
      ),
      sliver: SliverList.separated(
        itemCount: filtered.length,
        separatorBuilder: (_, _) => SizedBox(height: tokens.spacing.step3),
        itemBuilder: (context, index) {
          final model = filtered[index];
          // Pass through the resolved type when we have one. If the
          // owning provider hasn't loaded yet or was deleted, leave it
          // null and let the card render neutral chrome instead of
          // misbranding a model as Gemini.
          return AiModelCard(
            model: model,
            providerType: providerTypeById[model.inferenceProviderId],
            onTap: () => _handleConfigTap(model),
            menuActions: _buildCardMenu(model),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------
  // Profiles tab — responsive list (1 col mobile, 2 col desktop)
  // ---------------------------------------------------------------

  Widget _buildProfilesGrid(
    List<AiConfigInferenceProfile> profiles,
    List<AiConfigModel> models,
    List<AiConfigInferenceProvider> providers,
  ) {
    final query = _filterState.searchQuery;
    final filtered = query.isEmpty
        ? profiles
        : profiles.where((p) => p.name.toLowerCase().contains(query)).toList();
    if (filtered.isEmpty) {
      return _emptyTabSliver(
        query.isNotEmpty
            ? context.messages.multiSelectNoItemsFound
            : context.messages.inferenceProfilesEmpty,
      );
    }
    final tokens = context.designTokens;
    final modelNamesById = <String, String>{
      for (final m in models) m.providerModelId: m.name,
    };
    final providerTypeByProviderId = <String, InferenceProviderType>{
      for (final p in providers) p.id: p.inferenceProviderType,
    };
    final providerIdByModelProviderModelId = <String, String>{
      for (final m in models) m.providerModelId: m.inferenceProviderId,
    };
    // A profile earns the Active badge iff it's the winning candidate
    // for at least one configured provider — same rule the detail
    // page uses for its "Active profile" section.
    final activeProfileIds = activeProfileIdsForProviders(
      providers: providers,
      models: models,
      profiles: profiles,
    );

    AiProfileCard buildCard(AiConfigInferenceProfile profile) {
      return AiProfileCard(
        profile: profile,
        isActive: activeProfileIds.contains(profile.id),
        providerTypeFor: () => _providerTypeForProfile(
          profile,
          providerIdByModelProviderModelId,
          providerTypeByProviderId,
        ),
        modelLookup: (id) => modelNamesById[id],
        onTap: () => _handleConfigTap(profile),
        menuActions: _buildCardMenu(profile),
      );
    }

    return _buildCardList<AiConfigInferenceProfile>(
      tokens: tokens,
      items: filtered,
      buildCard: buildCard,
    );
  }

  /// Renders [items] as a vertical list of cards. Above the responsive
  /// breakpoint each row pairs two cards in a Row; below the breakpoint
  /// each row carries one card at full width. Cards size to their
  /// intrinsic content — no fixed aspect ratio, so taglines and the
  /// status row never clip on mobile (the v2-rewrite SliverGrid was
  /// flagging RenderFlex overflows at the smallest viewport widths).
  Widget _buildCardList<T>({
    required DsTokens tokens,
    required List<T> items,
    required Widget Function(T) buildCard,
  }) {
    return SliverPadding(
      padding: EdgeInsets.all(tokens.spacing.step5),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final columns =
              constraints.crossAxisExtent >= aiSettingsGridColumnBreakpoint
              ? 2
              : 1;
          if (columns == 1) {
            return SliverList.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) =>
                  SizedBox(height: tokens.spacing.step4),
              itemBuilder: (context, index) => buildCard(items[index]),
            );
          }
          // Desktop: pair items into rows of two. Odd last items get
          // a half-width placeholder so the grid stays aligned.
          final rowCount = (items.length + 1) ~/ 2;
          return SliverList.separated(
            itemCount: rowCount,
            separatorBuilder: (_, _) => SizedBox(height: tokens.spacing.step4),
            itemBuilder: (context, rowIndex) {
              final leftIndex = rowIndex * 2;
              final rightIndex = leftIndex + 1;
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: buildCard(items[leftIndex])),
                    SizedBox(width: tokens.spacing.step4),
                    Expanded(
                      child: rightIndex < items.length
                          ? buildCard(items[rightIndex])
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Best-guess provider type for a profile card. The profile schema
  /// doesn't carry a provider id — it just references models by their
  /// `providerModelId`. Walk the five skill slots in priority order
  /// (thinking → thinking-high-end → image recognition → transcription
  /// → image generation) and pick the first model whose owning provider
  /// we can resolve. Returns null when none of the slots resolve — the
  /// card paints neutral chrome in that case rather than impersonating
  /// Gemini.
  InferenceProviderType? _providerTypeForProfile(
    AiConfigInferenceProfile profile,
    Map<String, String> providerIdByModelProviderModelId,
    Map<String, InferenceProviderType> providerTypeByProviderId,
  ) {
    final candidates = <String?>[
      profile.thinkingModelId,
      profile.thinkingHighEndModelId,
      profile.imageRecognitionModelId,
      profile.transcriptionModelId,
      profile.imageGenerationModelId,
    ];
    for (final candidate in candidates) {
      if (candidate == null) continue;
      final providerId = providerIdByModelProviderModelId[candidate];
      if (providerId == null) continue;
      final type = providerTypeByProviderId[providerId];
      if (type != null) return type;
    }
    return null;
  }

  Widget _emptyTabSliver(String message) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(context.designTokens.spacing.step5),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: context.designTokens.typography.styles.body.bodySmall
                .copyWith(
                  color: context.designTokens.colors.text.mediumEmphasis,
                ),
          ),
        ),
      ),
    );
  }
}
