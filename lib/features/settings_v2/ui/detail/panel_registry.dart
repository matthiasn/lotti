import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/ui/agent_detail_page.dart';
import 'package:lotti/features/agents/ui/agent_settings_page.dart';
import 'package:lotti/features/agents/ui/agent_soul_detail_page.dart';
import 'package:lotti/features/agents/ui/agent_template_detail_page.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_filter_state.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_page.dart';
import 'package:lotti/features/categories/ui/pages/categories_list_page.dart';
import 'package:lotti/features/categories/ui/pages/category_details_page.dart';
import 'package:lotti/features/design_system/components/lists/design_system_grouped_list.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/labels/ui/pages/label_details_page.dart';
import 'package:lotti/features/labels/ui/pages/labels_list_page.dart';
import 'package:lotti/features/onboarding/ui/onboarding_metrics_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/about_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/celebration_settings_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/logging_settings_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/maintenance_page.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/create_dashboard_page.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/dashboard_definition_page.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/dashboards_page.dart';
import 'package:lotti/features/settings/ui/pages/flags_page.dart';
import 'package:lotti/features/settings/ui/pages/habits/habit_create_page.dart';
import 'package:lotti/features/settings/ui/pages/habits/habit_details_page.dart';
import 'package:lotti/features/settings/ui/pages/habits/habits_page.dart';
import 'package:lotti/features/settings/ui/pages/measurables/measurable_create_page.dart';
import 'package:lotti/features/settings/ui/pages/measurables/measurable_details_page.dart';
import 'package:lotti/features/settings/ui/pages/measurables/measurables_page.dart';
import 'package:lotti/features/settings/ui/pages/theming_page.dart';
import 'package:lotti/features/settings_v2/ui/detail/ai_panel_dispatch.dart';
import 'package:lotti/features/settings_v2/ui/detail/detail_id_dispatch.dart';
import 'package:lotti/features/sync/ui/backfill_settings_page.dart';
import 'package:lotti/features/sync/ui/matrix_sync_maintenance_page.dart';
import 'package:lotti/features/sync/ui/pages/conflicts/conflict_detail_route.dart';
import 'package:lotti/features/sync/ui/pages/conflicts/conflicts_page.dart';
import 'package:lotti/features/sync/ui/pages/outbox/outbox_monitor_page.dart';
import 'package:lotti/features/sync/ui/pages/sync_node_profile_page.dart';
import 'package:lotti/features/sync/ui/provisioned/provisioned_sync_modal.dart';
import 'package:lotti/features/sync/ui/sync_stats_page.dart';
import 'package:lotti/features/tts/ui/speech_settings_body.dart';
import 'package:lotti/utils/consts.dart';

export 'package:lotti/features/settings_v2/ui/detail/ai_panel_dispatch.dart';
export 'package:lotti/features/settings_v2/ui/detail/detail_id_dispatch.dart';

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
      // render full pages with their own scroll machinery. Sync has no
      // landing panel — its provisioned-sync entry is a leaf
      // (`sync-provisioned`) instead, so selecting the branch leaves the
      // detail pane empty.
      'ai': SettingsPanelSpec(build: _aiPanel),
      'agents': SettingsPanelSpec(build: _agentsPanel),

      // Step 7 — simple leaves.
      // FlagsBody is `Column[fixed search, Expanded(scrollable list)]`
      // so it manages its own scrolling and MUST NOT be wrapped in a
      // SingleChildScrollView (the inner Expanded would receive
      // unbounded height).
      'flags': SettingsPanelSpec(build: _flagsPanel),
      'theming': SettingsPanelSpec(build: _themingPanel, scrollable: true),
      'speech': SettingsPanelSpec(build: _speechPanel, scrollable: true),
      'advanced-about': SettingsPanelSpec(
        build: _advancedAboutPanel,
        scrollable: true,
      ),
      'advanced-maintenance': SettingsPanelSpec(
        build: _advancedMaintenancePanel,
        scrollable: true,
      ),
      'advanced-onboarding-metrics': SettingsPanelSpec(
        build: _advancedOnboardingMetricsPanel,
        scrollable: true,
      ),
      'advanced-logging': SettingsPanelSpec(
        build: _advancedLoggingPanel,
        scrollable: true,
      ),
      'advanced-animations': SettingsPanelSpec(
        build: _advancedAnimationsPanel,
        scrollable: true,
      ),
      // Light grouped-list body (the provisioned-sync QR card), so the
      // host wraps it in a scroll view.
      'sync-provisioned': SettingsPanelSpec(
        build: _syncProvisionedPanel,
        scrollable: true,
      ),
      // SyncNodeProfileBody is headerless and owns its own ListView — the
      // breadcrumb supplies the title, so it renders straight into the pane.
      'sync-node-profile': SettingsPanelSpec(build: _syncNodeProfilePanel),
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
Widget _speechPanel(BuildContext context) => const SpeechSettingsBody();
Widget _advancedAboutPanel(BuildContext context) => const AboutBody();
Widget _advancedMaintenancePanel(BuildContext context) =>
    const MaintenanceBody();
Widget _advancedOnboardingMetricsPanel(BuildContext context) =>
    const OnboardingMetricsBody();
Widget _advancedLoggingPanel(BuildContext context) =>
    const LoggingSettingsBody();
Widget _advancedAnimationsPanel(BuildContext context) =>
    const CelebrationSettingsBody();

/// Leaf panel for the `sync/provisioned` entry. Surfaces the
/// provisioned-sync (QR-pairing) card — the first row under the Sync
/// branch, replacing the old branch-level landing panel.
///
/// The card is matrix-only, so we gate it on `enableMatrixFlag` —
/// but unlike `SyncFeatureGate` we DON'T redirect away when the flag
/// is off. With Matrix off the panel renders as an empty placeholder.
///
/// Wired through Riverpod's `configFlagProvider` rather than a raw
/// `StreamBuilder` so the underlying flag stream is cached across
/// rebuilds — a fresh `watchConfigFlag(...)` subscription on every
/// rebuild would resubscribe + re-emit the loading state unnecessarily.
Widget _syncProvisionedPanel(BuildContext context) {
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

// Desktop-only: the legacy mobile `BackfillSettingsPage` supplies its own
// horizontal gutter, but the V2 detail pane embeds `BackfillSettingsBody`
// bare. Add a horizontal inset so the content doesn't run edge-to-edge and
// instead matches the breathing room the Stats panel gets from
// `SyncStatsBody`'s card margin (`tokens.spacing.step3`).
Widget _syncBackfillPanel(BuildContext context) {
  final tokens = context.designTokens;
  return Padding(
    padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step3),
    child: const BackfillSettingsBody(),
  );
}

Widget _syncStatsPanel(BuildContext context) => const SyncStatsBody();
Widget _syncOutboxPanel(BuildContext context) => const OutboxMonitorBody();
Widget _syncNodeProfilePanel(BuildContext context) =>
    const SyncNodeProfileBody();
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
Widget _habitsPanel(BuildContext context) => DetailIdDispatch(
  idParamKey: 'habitId',
  list: (_) => const HabitsBody(),
  create: (_, _) => CreateHabitPage(),
  detail: (_, id) => EditHabitPage(
    key: ValueKey('settings-v2-habit-$id'),
    habitId: id,
  ),
);
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

// Per-leaf desktop bodies for the AI sidebar children. Each renders
// `AiSettingsBody` pinned to one tab with the in-pane TabBar AND the
// page header hidden so the sidebar leaf / breadcrumb naming isn't
// duplicated above the list. The `ai-profiles` panel now points at
// the v3 profiles tab body — the legacy `InferenceProfilesBody` is
// still kept around for any direct `/settings/ai/profiles` deep-links
// in older bookmarks, but the v2 panel registry no longer uses it.
Widget _aiProvidersPanel(BuildContext context) => const AiSettingsBody(
  initialTab: AiSettingsTab.providers,
  hideTabBar: true,
  hideHeader: true,
);
Widget _aiModelsPanel(BuildContext context) => const AiSettingsBody(
  initialTab: AiSettingsTab.models,
  hideTabBar: true,
  hideHeader: true,
);
Widget _aiProfilesPanel(BuildContext context) => const AiSettingsBody(
  initialTab: AiSettingsTab.profiles,
  hideTabBar: true,
  hideHeader: true,
);
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
