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
import 'package:lotti/features/settings/ui/pages/habits/habit_create_page.dart';
import 'package:lotti/features/settings/ui/pages/habits/habit_details_page.dart';
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
import 'package:lotti/features/sync/ui/pages/sync_node_profile_page.dart';
import 'package:lotti/features/sync/ui/provisioned/provisioned_sync_modal.dart';
import 'package:lotti/features/sync/ui/sync_stats_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/consts.dart';

part 'detail_id_dispatch.dart';
part 'ai_panel_dispatch.dart';

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
      // SyncNodeProfilePage owns its Scaffold; don't wrap.
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
Widget _syncNodeProfilePanel(BuildContext context) =>
    const SyncNodeProfilePage();
Widget _syncMatrixMaintenancePanel(BuildContext context) =>
    const MatrixSyncMaintenanceBody();
