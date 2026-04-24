import 'package:flutter/widgets.dart';
import 'package:lotti/features/agents/ui/agent_settings_page.dart';
import 'package:lotti/features/ai/ui/inference_profile_page.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_page.dart';
import 'package:lotti/features/categories/ui/pages/categories_list_page.dart';
import 'package:lotti/features/labels/ui/pages/labels_list_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/about_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/logging_settings_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/maintenance_page.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/dashboards_page.dart';
import 'package:lotti/features/settings/ui/pages/flags_page.dart';
import 'package:lotti/features/settings/ui/pages/habits/habits_page.dart';
import 'package:lotti/features/settings/ui/pages/measurables/measurables_page.dart';
import 'package:lotti/features/settings/ui/pages/theming_page.dart';
import 'package:lotti/features/sync/ui/backfill_settings_page.dart';
import 'package:lotti/features/sync/ui/matrix_sync_maintenance_page.dart';
import 'package:lotti/features/sync/ui/pages/conflicts/conflicts_page.dart';
import 'package:lotti/features/sync/ui/pages/outbox/outbox_monitor_page.dart';
import 'package:lotti/features/sync/ui/sync_stats_page.dart';

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
///   dashboards, measurables, advanced-conflicts).
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
      'advanced-conflicts': SettingsPanelSpec(build: _advancedConflictsPanel),

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
Widget _categoriesPanel(BuildContext context) => const CategoriesListBody();
Widget _labelsPanel(BuildContext context) => const LabelsListBody();
Widget _habitsPanel(BuildContext context) => const HabitsBody();
Widget _dashboardsPanel(BuildContext context) => const DashboardsBody();
Widget _measurablesPanel(BuildContext context) => const MeasurablesBody();
Widget _advancedConflictsPanel(BuildContext context) => const ConflictsBody();

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
