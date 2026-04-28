import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:lotti/features/agents/ui/agent_settings_page.dart';
import 'package:lotti/features/ai/ui/inference_profile_page.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_page.dart';
import 'package:lotti/features/categories/ui/pages/categories_list_page.dart';
import 'package:lotti/features/categories/ui/pages/category_details_page.dart';
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
import 'package:lotti/features/sync/ui/pages/conflicts/conflicts_page.dart';
import 'package:lotti/features/sync/ui/pages/outbox/outbox_monitor_page.dart';
import 'package:lotti/features/sync/ui/sync_stats_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';

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
      // Branches that carry their own landing page. Both render full
      // pages with their own scroll machinery.
      'ai': SettingsPanelSpec(build: _aiPanel),
      'agents': SettingsPanelSpec(build: _agentsPanel),

      // Step 7 — simple leaves.
      'flags': SettingsPanelSpec(build: _flagsPanel, scrollable: true),
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
      'ai-profiles': SettingsPanelSpec(build: _aiProfilesPanel),
      'agents-templates': SettingsPanelSpec(build: _agentsTemplatesPanel),
      'agents-souls': SettingsPanelSpec(build: _agentsSoulsPanel),
      'agents-instances': SettingsPanelSpec(build: _agentsInstancesPanel),
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

// --- Step 7 builders --------------------------------------------------------
Widget _flagsPanel(BuildContext context) => const FlagsBody();
Widget _themingPanel(BuildContext context) => const ThemingBody();
Widget _advancedAboutPanel(BuildContext context) => const AboutBody();
Widget _advancedMaintenancePanel(BuildContext context) =>
    const MaintenanceBody();
Widget _advancedLoggingPanel(BuildContext context) =>
    const LoggingSettingsBody();
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
Widget _syncConflictsPanel(BuildContext context) => const ConflictsBody();

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

  /// Cross-fade duration between list / detail / create modes — kept
  /// in sync with `kSettingsDetailPaneSwap` in `SettingsDetailPane` so
  /// every transition under the V2 detail surface lands on the same
  /// motion grammar.
  static const Duration _kModeSwapDuration = Duration(milliseconds: 180);

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
          duration: _kModeSwapDuration,
          transitionBuilder: (current, animation) =>
              FadeTransition(opacity: animation, child: current),
          child: KeyedSubtree(key: ValueKey(modeKey), child: child),
        );
      },
    );
  }
}

// --- Step 9 builders --------------------------------------------------------
Widget _aiPanel(BuildContext context) => const AiSettingsBody();
Widget _aiProfilesPanel(BuildContext context) => const InferenceProfilesBody();
Widget _agentsPanel(BuildContext context) => const AgentSettingsBody();
Widget _agentsTemplatesPanel(BuildContext context) =>
    const AgentSettingsBody(initialTab: AgentSettingsTab.templates);
Widget _agentsSoulsPanel(BuildContext context) =>
    const AgentSettingsBody(initialTab: AgentSettingsTab.souls);
Widget _agentsInstancesPanel(BuildContext context) =>
    const AgentSettingsBody(initialTab: AgentSettingsTab.instances);
