import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/ui/agent_detail_page.dart';
import 'package:lotti/features/agents/ui/agent_settings_page.dart';
import 'package:lotti/features/agents/ui/agent_soul_detail_page.dart';
import 'package:lotti/features/agents/ui/agent_template_detail_page.dart';
import 'package:lotti/features/ai/ui/inference_profile_form.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_filter_state.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_page.dart';
import 'package:lotti/features/ai/ui/settings/inference_model_edit_page.dart';
import 'package:lotti/features/ai/ui/settings/provider/ai_provider_detail_page.dart';
import 'package:lotti/features/categories/ui/pages/categories_list_page.dart';
import 'package:lotti/features/categories/ui/pages/category_details_page.dart';
import 'package:lotti/features/design_system/components/lists/design_system_grouped_list.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/labels/ui/pages/label_details_page.dart';
import 'package:lotti/features/labels/ui/pages/labels_list_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/about_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/logging_settings_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/maintenance_page.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/create_dashboard_page.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/dashboard_definition_page.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/dashboards_page.dart';
import 'package:lotti/features/settings/ui/pages/flags_page.dart';
import 'package:lotti/features/settings/ui/pages/habits/habits_page.dart';
import 'package:lotti/features/settings/ui/pages/measurables/measurable_create_page.dart';
import 'package:lotti/features/settings/ui/pages/measurables/measurable_details_page.dart';
import 'package:lotti/features/settings/ui/pages/measurables/measurables_page.dart';
import 'package:lotti/features/settings/ui/pages/theming_page.dart';
import 'package:lotti/features/sync/ui/backfill_settings_page.dart';
import 'package:lotti/features/sync/ui/matrix_sync_maintenance_page.dart';
import 'package:lotti/features/sync/ui/pages/conflicts/conflict_detail_route.dart';
import 'package:lotti/features/sync/ui/pages/conflicts/conflicts_page.dart';
import 'package:lotti/features/sync/ui/pages/outbox/outbox_monitor_page.dart';
import 'package:lotti/features/sync/ui/provisioned/provisioned_sync_modal.dart';
import 'package:lotti/features/sync/ui/sync_stats_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/consts.dart';

/// Signature for a registered detail-pane panel body. The builder
/// receives a fresh [BuildContext] under the Settings V2 detail
/// pane's `Scaffold`, so embedded pages can call `ScaffoldMessenger.of`
/// without extra wrapping.
typedef SettingsPanelBuilder = Widget Function(BuildContext context);

/// Declarative spec for one entry in [kSettingsPanels]. Splits the
/// "how do I build the body" concern from the "does this body
/// manage its own scrolling?" concern — the host (`LeafPanel`) wraps
/// the body in a [SingleChildScrollView] iff [scrollable] is `true`.
///
/// The ad-hoc `_scrollable(...)` wrapping the registry used before
/// was a silent authoring trap: a column-based body classified as
/// "scrollable" that later added its own `ListView` / `CustomScrollView`
/// would crash with an unbounded-height assertion deep inside
/// rendering. By making the wrapping an explicit per-panel flag,
/// contributors opt in at the registration site and bodies with
/// their own scroll widgets declare `scrollable: false` — the
/// default.
@immutable
class SettingsPanelSpec {
  const SettingsPanelSpec({
    required this.build,
    this.scrollable = false,
  });

  final SettingsPanelBuilder build;

  /// When `true`, the host wraps [build]'s widget in a
  /// `SingleChildScrollView` so flat `Column`-based bodies don't
  /// overflow the fixed detail-pane height. Column-based bodies
  /// should declare `scrollable: true`. Bodies that render their
  /// own `Scaffold` / `CustomScrollView` / `ListView` MUST keep this
  /// `false` — otherwise the outer scroll view would give unbounded
  /// height to the inner viewport and panic at paint time.
  final bool scrollable;
}

/// Panel-id → spec map. Keys match `SettingsNode.panel` strings as
/// declared in `buildSettingsTree`; any leaf whose `panel` is absent
/// from this map falls back to `DefaultPanel`.
///
/// Populated across plan steps 7-9:
/// - **Step 7** — "simple" leaves (flags, theming, advanced tooling,
///   sync pages).
/// - **Step 8** — dynamic list panels (categories, labels, habits,
///   dashboards, measurables, sync-conflicts).
/// - **Step 9** — AI + agents (ai, ai-profiles, agents-*).
///
/// Each entry resolves to a `*Body` widget — the body either strips
/// the legacy `SliverBoxAdapterPage` chrome or (for pages we haven't
/// body-extracted yet) aliases the V1 page. Polish (step 10) will
/// give the aliased pages a headerless embedded mode so the
/// duplicate title under the leaf panel goes away.
const Map<String, SettingsPanelSpec> kSettingsPanels =
    <String, SettingsPanelSpec>{
      // Branches that carry their own landing page. AI / Agents
      // render full pages with their own scroll machinery; Sync is a
      // light grouped-list body so the host wraps it.
      'ai': SettingsPanelSpec(build: _aiPanel),
      'agents': SettingsPanelSpec(build: _agentsPanel),
      'sync': SettingsPanelSpec(build: _syncPanel, scrollable: true),

      // Step 7 — simple leaves.
      // FlagsBody is `Column[fixed search, Expanded(scrollable list)]`
      // so it manages its own scrolling and MUST NOT be wrapped in a
      // SingleChildScrollView (the inner Expanded would receive
      // unbounded height).
      'flags': SettingsPanelSpec(build: _flagsPanel),
      'theming': SettingsPanelSpec(build: _themingPanel, scrollable: true),
      'advanced-about': SettingsPanelSpec(
        build: _advancedAboutPanel,
        scrollable: true,
      ),
      'advanced-maintenance': SettingsPanelSpec(
        build: _advancedMaintenancePanel,
        scrollable: true,
      ),
      'advanced-logging': SettingsPanelSpec(
        build: _advancedLoggingPanel,
        scrollable: true,
      ),
      'sync-backfill': SettingsPanelSpec(
        build: _syncBackfillPanel,
        scrollable: true,
      ),
      'sync-stats': SettingsPanelSpec(
        build: _syncStatsPanel,
        scrollable: true,
      ),
      // Outbox renders its own Scaffold + CustomScrollView; wrapping
      // in SingleChildScrollView would crash the inner viewport.
      'sync-outbox': SettingsPanelSpec(build: _syncOutboxPanel),
      'sync-matrix-maintenance': SettingsPanelSpec(
        build: _syncMatrixMaintenancePanel,
        scrollable: true,
      ),

      // Step 8 — dynamic lists. These manage their own scrolling via
      // internal ListView / CustomScrollView.
      'categories': SettingsPanelSpec(build: _categoriesPanel),
      'labels': SettingsPanelSpec(build: _labelsPanel),
      'habits': SettingsPanelSpec(build: _habitsPanel),
      'dashboards': SettingsPanelSpec(build: _dashboardsPanel),
      'measurables': SettingsPanelSpec(build: _measurablesPanel),
      'sync-conflicts': SettingsPanelSpec(build: _syncConflictsPanel),

      // Step 9 — AI + agents. Full pages with their own scrolling.
      // The AI tabs (Providers / Models / Profiles) get their own
      // sidebar leaves under "AI Settings"; each renders the matching
      // tab body without an in-pane TabBar, since the sidebar leaf
      // itself already names the view (see plan v4).
      'ai-providers': SettingsPanelSpec(build: _aiProvidersPanel),
      'ai-models': SettingsPanelSpec(build: _aiModelsPanel),
      'ai-profiles': SettingsPanelSpec(build: _aiProfilesPanel),
      'agents-stats': SettingsPanelSpec(build: _agentsStatsPanel),
      'agents-templates': SettingsPanelSpec(build: _agentsTemplatesPanel),
      'agents-instances': SettingsPanelSpec(build: _agentsInstancesPanel),
      'agents-souls': SettingsPanelSpec(build: _agentsSoulsPanel),
      'agents-pending-wakes': SettingsPanelSpec(
        build: _agentsPendingWakesPanel,
      ),
    };

/// Returns the registered spec for [panelId], or `null` when the id
/// is unknown (caller should render `DefaultPanel`).
///
/// Extracted into a named helper so tests + the dispatcher share a
/// single resolution site — swapping the backing map for a mutable
/// injection mechanism later only requires editing this function.
SettingsPanelSpec? panelSpecFor(String? panelId) {
  if (panelId == null) return null;
  return kSettingsPanels[panelId];
}

/// Cross-fade duration shared by every dispatcher under the V2 detail
/// surface (`DetailIdDispatch`, `AiPanelDispatch`, …) so panel swaps
/// land on the same motion grammar as `SettingsDetailPane`.
const Duration kSettingsPanelSwapDuration = Duration(milliseconds: 180);

// --- Step 7 builders --------------------------------------------------------
Widget _flagsPanel(BuildContext context) => const FlagsBody();
Widget _themingPanel(BuildContext context) => const ThemingBody();
Widget _advancedAboutPanel(BuildContext context) => const AboutBody();
Widget _advancedMaintenancePanel(BuildContext context) =>
    const MaintenanceBody();
Widget _advancedLoggingPanel(BuildContext context) =>
    const LoggingSettingsBody();

/// Landing panel for the Sync branch on V2 desktop. Surfaces the
/// provisioned-sync (QR-pairing) entry point that the mobile
/// SyncSettingsPage already shows but that desktop V2 used to omit
/// because the Sync branch was leafless.
///
/// The card is matrix-only, so we gate it on `enableMatrixFlag` —
/// but unlike `SyncFeatureGate` we DON'T redirect away when the flag
/// is off. The Sync branch stays visible even with Matrix disabled
/// (the conflicts leaf still needs to be reachable for legacy /
/// local-only conflicts), so a parent-branch click must not bounce
/// the user out of `/settings/sync`. With Matrix off the panel
/// renders as an empty placeholder and the user can still drill into
/// `sync-conflicts` via the sidebar tree.
///
/// Wired through Riverpod's `configFlagProvider` rather than a raw
/// `StreamBuilder` so the underlying flag stream is cached across
/// rebuilds — a fresh `watchConfigFlag(...)` subscription on every
/// rebuild would resubscribe + re-emit the loading state unnecessarily.
Widget _syncPanel(BuildContext context) {
  return Consumer(
    builder: (context, ref, _) {
      final tokens = context.designTokens;
      final enabled =
          ref.watch(configFlagProvider(enableMatrixFlag)).value ?? false;
      if (!enabled) return const SizedBox.shrink();
      return Padding(
        padding: EdgeInsets.symmetric(vertical: tokens.spacing.step4),
        child: const DesignSystemGroupedList(
          children: [
            ProvisionedSyncSettingsCard(showDivider: false),
          ],
        ),
      );
    },
  );
}

Widget _syncBackfillPanel(BuildContext context) => const BackfillSettingsBody();
Widget _syncStatsPanel(BuildContext context) => const SyncStatsBody();
Widget _syncOutboxPanel(BuildContext context) => const OutboxMonitorBody();
Widget _syncMatrixMaintenancePanel(BuildContext context) =>
    const MatrixSyncMaintenanceBody();

// --- Step 8 builders --------------------------------------------------------
//
// Categories / Labels / Dashboards each carry a list ↔ detail/create swap
// driven by URL `pathParameters`. The legacy desktop column-stack used to
// route those URLs to a fresh detail column; under V2 the panel slot itself
// owns the dispatch via [DetailIdDispatch] so the same content area swaps
// in place when a row is tapped (`/settings/<branch>/<id>`) or the create
// CTA is hit (`/settings/<branch>/create`).
Widget _categoriesPanel(BuildContext context) => DetailIdDispatch(
  idParamKey: 'categoryId',
  list: (_) => const CategoriesListBody(),
  create: (_, _) => const CategoryDetailsPage(),
  detail: (_, id) => CategoryDetailsPage(
    key: ValueKey('settings-v2-category-$id'),
    categoryId: id,
  ),
);
Widget _labelsPanel(BuildContext context) => DetailIdDispatch(
  idParamKey: 'labelId',
  list: (_) => const LabelsListBody(),
  create: (_, route) => LabelDetailsPage(
    initialName: route?.queryParameters['name'],
  ),
  detail: (_, id) => LabelDetailsPage(
    key: ValueKey('settings-v2-label-$id'),
    labelId: id,
  ),
);
Widget _habitsPanel(BuildContext context) => const HabitsBody();
Widget _dashboardsPanel(BuildContext context) => DetailIdDispatch(
  idParamKey: 'dashboardId',
  list: (_) => const DashboardsBody(),
  create: (_, _) => CreateDashboardPage(),
  detail: (_, id) => EditDashboardPage(
    key: ValueKey('settings-v2-dashboard-$id'),
    dashboardId: id,
  ),
);
Widget _measurablesPanel(BuildContext context) => DetailIdDispatch(
  idParamKey: 'measurableId',
  list: (_) => const MeasurablesBody(),
  create: (_, _) => CreateMeasurablePage(),
  detail: (_, id) => EditMeasurablePage(
    key: ValueKey('settings-v2-measurable-$id'),
    measurableId: id,
  ),
);
// Conflicts follow the list ↔ detail dispatch pattern shared with the
// other dynamic-list panels. Without this, a row tap on desktop would
// only update the URL — the detail pane would keep rendering the list
// because the V2 surface picks its child from the registered panel,
// not from the main Beamer location stack. There's no create flow, so
// the `create` slot just falls through to the list.
Widget _syncConflictsPanel(BuildContext context) => DetailIdDispatch(
  idParamKey: 'conflictId',
  list: (_) => const ConflictsBody(),
  create: (_, _) => const ConflictsBody(),
  detail: (_, id) => ConflictDetailRoute(
    key: ValueKey('settings-v2-conflict-$id'),
    conflictId: id,
  ),
);

/// Generic list ↔ detail/create dispatcher for V2 panel bodies.
///
/// Listens to [NavService.desktopSelectedSettingsRoute] directly via
/// a [ValueListenableBuilder] (no Riverpod adapter — the underlying
/// `ValueNotifier` already emits on every Beamer-driven route change,
/// and stock Flutter rebuild semantics avoid any "did the provider
/// observe the update" doubt). Chooses between three builders:
///
/// - **create** — when the URL ends with `/create`. Receives the full
///   route so create flows can read query parameters
///   (e.g. labels prefilling the new label's name).
/// - **detail** — when [idParamKey] is present in `pathParameters` and
///   not the literal `'create'` (which Beamer hands back as a path
///   parameter on the matching route definition).
/// - **list** — fallback for the bare branch URL.
///
/// The dispatcher is intentionally local to the registry: keeping it
/// here means the categories / labels / dashboards features stay
/// agnostic of V2 routing, and the registry stays the single place
/// to wire a new list-detail pair. The optional [listenable] hook
/// lets tests drive the dispatch with their own ValueNotifier without
/// having to register a `NavService` in `get_it`.
class DetailIdDispatch extends StatelessWidget {
  const DetailIdDispatch({
    required this.idParamKey,
    required this.list,
    required this.create,
    required this.detail,
    this.listenable,
    super.key,
  });

  final String idParamKey;
  final Widget Function(BuildContext context) list;
  final Widget Function(BuildContext context, DesktopSettingsRoute? route)
  create;
  final Widget Function(BuildContext context, String id) detail;

  /// Test-only override for the route source. Production callers leave
  /// this `null` so the dispatcher reads from `getIt<NavService>()`.
  @visibleForTesting
  final ValueListenable<DesktopSettingsRoute?>? listenable;

  @override
  Widget build(BuildContext context) {
    final source =
        listenable ?? getIt<NavService>().desktopSelectedSettingsRoute;
    return ValueListenableBuilder<DesktopSettingsRoute?>(
      valueListenable: source,
      builder: (context, route, _) {
        final params = route?.pathParameters ?? const <String, String>{};
        final path = route?.path ?? '';

        final Widget child;
        final String modeKey;
        if (path.endsWith('/create')) {
          child = create(context, route);
          modeKey = 'create';
        } else {
          final id = params[idParamKey];
          if (id != null && id.isNotEmpty && id != 'create') {
            child = detail(context, id);
            // Key includes the id so swapping between two detail rows
            // (e.g. tapping a different category) cross-fades instead
            // of reusing the previous detail's element.
            modeKey = 'detail:$id';
          } else {
            child = list(context);
            modeKey = 'list';
          }
        }

        return AnimatedSwitcher(
          duration: kSettingsPanelSwapDuration,
          // Default layout uses `StackFit.loose`, which collapses
          // Scaffold-based children to their minimum size and hides
          // their FloatingActionButton — the "+" in the agents tab is
          // the canonical case, but this is a property of every
          // dispatcher consumer (categories, labels, dashboards,
          // measurables, agents). Force `StackFit.expand` so children
          // fill the panel slot — Scaffolds get bounded constraints
          // and lay out their FAB the same way they would unwrapped.
          // The previous children list still cross-fades correctly
          // because `AnimatedSwitcher` paints them above us during
          // the swap.
          layoutBuilder: (currentChild, previousChildren) => Stack(
            alignment: Alignment.center,
            fit: StackFit.expand,
            children: [
              ...previousChildren,
              ?currentChild,
            ],
          ),
          transitionBuilder: (current, animation) =>
              FadeTransition(opacity: animation, child: current),
          child: KeyedSubtree(key: ValueKey(modeKey), child: child),
        );
      },
    );
  }
}

// --- Step 9 builders --------------------------------------------------------
// AI Settings: list ↔ provider/model/profile detail dispatch.
//
// Unlike categories / labels / dashboards (each of which has ONE detail
// kind keyed off a single path parameter), the AI panel has three
// orthogonal detail surfaces — provider, model, inference profile —
// reachable from three different tab bodies in the list. The generic
// `DetailIdDispatch` only handles one id key, so the AI panel uses a
// custom `AiPanelDispatch` widget that reads all three keys off the
// route and picks whichever is present.
//
// URL space:
//   /settings/ai                        → list (AiSettingsBody)
//   /settings/ai/provider/<providerId>  → AiProviderDetailPage
//   /settings/ai/model/<modelId>        → InferenceModelEditPage
//   /settings/ai/profile/<profileId>    → InferenceProfileDetailPage
//                                          (resolves id → AiConfig via
//                                          Riverpod and hands the loaded
//                                          profile to InferenceProfileForm)
//
// The legacy `/settings/ai/profiles` leaf renders InferenceProfilePage
// directly and is unrelated — it's the seeded-profile list, not the
// per-profile edit form.
Widget _aiPanel(BuildContext context) => const AiPanelDispatch();

/// Multi-kind dispatcher for the AI Settings panel. Watches the
/// settings route ValueNotifier and renders one of:
///
/// - [AiSettingsBody] (the list) when no detail id is bound,
/// - [AiProviderDetailPage] (with `focusApiKey` from the route query)
///   when `providerId` is bound,
/// - [InferenceModelEditPage] when `modelId` is bound,
/// - [InferenceProfileDetailPage] when `profileId` is bound.
///
/// Wraps the swap in an [AnimatedSwitcher] tuned to the same 180 ms
/// cross-fade as `DetailIdDispatch` so the AI panel feels consistent
/// with the other Settings V2 panels.
class AiPanelDispatch extends StatelessWidget {
  const AiPanelDispatch({this.listenable, super.key});

  /// Test-only override for the route source. Production callers leave
  /// this `null` so the dispatcher reads from `getIt<NavService>()`.
  @visibleForTesting
  final ValueListenable<DesktopSettingsRoute?>? listenable;

  @override
  Widget build(BuildContext context) {
    final source =
        listenable ?? getIt<NavService>().desktopSelectedSettingsRoute;
    return ValueListenableBuilder<DesktopSettingsRoute?>(
      valueListenable: source,
      builder: (context, route, _) {
        final selection = aiPanelSelectionFor(route);
        return AnimatedSwitcher(
          duration: kSettingsPanelSwapDuration,
          // Same layout choice as `DetailIdDispatch` — `StackFit.expand`
          // gives Scaffold-based children bounded constraints so their
          // FAB and bottom bar lay out correctly.
          layoutBuilder: (currentChild, previousChildren) => Stack(
            alignment: Alignment.center,
            fit: StackFit.expand,
            children: [
              ...previousChildren,
              ?currentChild,
            ],
          ),
          transitionBuilder: (current, animation) =>
              FadeTransition(opacity: animation, child: current),
          child: KeyedSubtree(
            key: ValueKey(selection.modeKey),
            child: selection.child,
          ),
        );
      },
    );
  }
}

/// Result of resolving the route → page mapping for the AI panel. The
/// dispatcher keys its [AnimatedSwitcher] by [modeKey] so swapping
/// between two distinct detail pages cross-fades (rather than reusing
/// the previous element) and keys each detail page by a stable
/// per-id [ValueKey] so successive detail rows tear down cleanly.
@immutable
class AiPanelSelection {
  const AiPanelSelection({required this.modeKey, required this.child});

  final String modeKey;
  final Widget child;
}

/// Pure route → child resolver for the AI panel.
///
/// Extracted so the registry tests can verify the multi-kind dispatch
/// (list / provider / model / profile) without pumping the heavy
/// destination pages — each carries its own Riverpod / Scaffold setup
/// and would force every dispatcher test to register a real
/// repository. The widget calls this helper from its builder; the
/// tests assert directly on the returned widget TYPE and `modeKey`.
AiPanelSelection aiPanelSelectionFor(DesktopSettingsRoute? route) {
  final params = route?.pathParameters ?? const <String, String>{};

  final providerId = params['providerId'];
  if (providerId != null && providerId.isNotEmpty) {
    final focusApiKey = route?.queryParameters['focusApiKey'] == 'true';
    return AiPanelSelection(
      modeKey: 'provider:$providerId:${focusApiKey ? 'fix' : 'view'}',
      child: AiProviderDetailPage(
        key: ValueKey('settings-v2-ai-provider-$providerId'),
        providerId: providerId,
        focusApiKey: focusApiKey,
      ),
    );
  }

  final modelId = params['modelId'];
  if (modelId != null && modelId.isNotEmpty) {
    return AiPanelSelection(
      modeKey: 'model:$modelId',
      child: InferenceModelEditPage(
        key: ValueKey('settings-v2-ai-model-$modelId'),
        configId: modelId,
      ),
    );
  }

  final profileId = params['profileId'];
  if (profileId != null && profileId.isNotEmpty) {
    return AiPanelSelection(
      modeKey: 'profile:$profileId',
      child: InferenceProfileDetailPage(
        key: ValueKey('settings-v2-ai-profile-$profileId'),
        profileId: profileId,
      ),
    );
  }

  // AI Settings parent landing on desktop. The page's
  // `AiSettingsFilterState.initial()` already defaults the active tab
  // to Providers, so hiding the TabBar here makes the parent row land
  // visually identical to the Providers leaf — both render the
  // providers list with no in-pane tabs. Mobile bypasses this panel
  // entirely (Beamer routes `/settings/ai` to `AiSettingsPage()`
  // directly, which keeps its TabBar because the sidebar doesn't
  // exist on phone-sized viewports).
  return const AiPanelSelection(
    modeKey: 'list',
    child: AiSettingsBody(hideTabBar: true),
  );
}

// Per-leaf desktop bodies for the AI sidebar children. Each renders
// `AiSettingsBody` pinned to one tab with the in-pane TabBar hidden so
// the sidebar leaf naming isn't duplicated above the list. The
// `ai-profiles` panel now points at the v3 profiles tab body — the
// legacy `InferenceProfilesBody` is still kept around for any direct
// `/settings/ai/profiles` deep-links in older bookmarks, but the v2
// panel registry no longer uses it.
Widget _aiProvidersPanel(BuildContext context) =>
    const AiSettingsBody(initialTab: AiSettingsTab.providers, hideTabBar: true);
Widget _aiModelsPanel(BuildContext context) =>
    const AiSettingsBody(initialTab: AiSettingsTab.models, hideTabBar: true);
Widget _aiProfilesPanel(BuildContext context) =>
    const AiSettingsBody(initialTab: AiSettingsTab.profiles, hideTabBar: true);
Widget _agentsPanel(BuildContext context) => const AgentSettingsBody();

// Stats and pending-wakes are read-only views with no detail/create
// flow, so they reuse `AgentSettingsBody` directly. The body resolves
// its tab from the URL on desktop, so the explicit `initialTab`
// argument here is just a fallback for mobile / test contexts where
// `NavService` isn't desktop-driven.
Widget _agentsStatsPanel(BuildContext context) =>
    const AgentSettingsBody(initialTab: AgentSettingsTab.stats);
Widget _agentsPendingWakesPanel(BuildContext context) =>
    const AgentSettingsBody(initialTab: AgentSettingsTab.pendingWakes);

// Agent panels follow the same list ↔ detail/create pattern as the
// other dynamic-list panels (categories, labels, dashboards, …) — the
// floating "+" beams to `/settings/agents/<tab>/create`, list rows
// beam to `/settings/agents/<tab>/<id>`. Each tab has its own id key
// (`templateId` / `soulId` / `agentId`).
Widget _agentsTemplatesPanel(BuildContext context) => DetailIdDispatch(
  idParamKey: 'templateId',
  list: (_) => const AgentSettingsBody(initialTab: AgentSettingsTab.templates),
  create: (_, _) => const AgentTemplateDetailPage(),
  detail: (_, id) => AgentTemplateDetailPage(
    key: ValueKey('settings-v2-agent-template-$id'),
    templateId: id,
  ),
);

Widget _agentsSoulsPanel(BuildContext context) => DetailIdDispatch(
  idParamKey: 'soulId',
  list: (_) => const AgentSettingsBody(initialTab: AgentSettingsTab.souls),
  create: (_, _) => const AgentSoulDetailPage(),
  detail: (_, id) => AgentSoulDetailPage(
    key: ValueKey('settings-v2-agent-soul-$id'),
    soulId: id,
  ),
);

Widget _agentsInstancesPanel(BuildContext context) => DetailIdDispatch(
  idParamKey: 'agentId',
  list: (_) => const AgentSettingsBody(initialTab: AgentSettingsTab.instances),
  // Instances are created indirectly (from a template) — there is no
  // `/settings/agents/instances/create` route in beamer, so the
  // create branch is structurally unreachable. Fall back to the list
  // defensively rather than crashing if a stray URL ever arrives.
  create: (_, _) =>
      const AgentSettingsBody(initialTab: AgentSettingsTab.instances),
  detail: (_, id) => AgentDetailPage(
    key: ValueKey('settings-v2-agent-instance-$id'),
    agentId: id,
  ),
);
