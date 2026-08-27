import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/agents/ui/agent_detail_page.dart';
import 'package:lotti/features/agents/ui/agent_settings_page.dart';
import 'package:lotti/features/agents/ui/agent_soul_detail_page.dart';
import 'package:lotti/features/agents/ui/agent_template_detail_page.dart';
import 'package:lotti/features/agents/ui/evolution/evolution_review_page.dart';
import 'package:lotti/features/agents/ui/evolution/soul_evolution_review_page.dart';
import 'package:lotti/features/ai/ui/inference_profile_form.dart';
import 'package:lotti/features/ai/ui/inference_profile_page.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_page.dart';
import 'package:lotti/features/ai/ui/settings/inference_model_edit_page.dart';
import 'package:lotti/features/ai/ui/settings/provider/ai_provider_detail_page.dart';
import 'package:lotti/features/categories/ui/pages/categories_list_page.dart'
    as new_categories;
import 'package:lotti/features/categories/ui/pages/category_details_page.dart'
    as new_category_details;
import 'package:lotti/features/daily_os_next/ui/pages/daily_os_settings_page.dart';
import 'package:lotti/features/habits/ui/pages/habit_editor_page.dart';
import 'package:lotti/features/keyboard/ui/keyboard_shortcuts_page.dart';
import 'package:lotti/features/labels/ui/pages/label_details_page.dart';
import 'package:lotti/features/labels/ui/pages/labels_list_page.dart';
import 'package:lotti/features/onboarding/ui/onboarding_metrics_page.dart';
import 'package:lotti/features/onboarding/ui/onboarding_settings_panel.dart';
import 'package:lotti/features/projects/ui/pages/project_detail_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/about_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/celebration_settings_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/logging_settings_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/maintenance_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/manual_language_settings_page.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/create_dashboard_page.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/dashboard_definition_page.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/dashboards_page.dart';
import 'package:lotti/features/settings/ui/pages/flags_page.dart';
import 'package:lotti/features/settings/ui/pages/habits/habits_page.dart';
import 'package:lotti/features/settings/ui/pages/health_import_page.dart';
import 'package:lotti/features/settings/ui/pages/measurables/measurable_create_page.dart';
import 'package:lotti/features/settings/ui/pages/measurables/measurable_details_page.dart';
import 'package:lotti/features/settings/ui/pages/measurables/measurables_page.dart';
import 'package:lotti/features/settings/ui/pages/recording_style_settings_page.dart';
import 'package:lotti/features/settings/ui/pages/settings_root_page.dart';
import 'package:lotti/features/settings/ui/pages/theming_page.dart';
import 'package:lotti/features/settings_v2/domain/settings_tree_index.dart';
import 'package:lotti/features/settings_v2/ui/mobile/settings_mobile_branch_page.dart';
import 'package:lotti/features/settings_v2/ui/mobile/settings_mobile_root_page.dart';
import 'package:lotti/features/sync/ui/backfill_settings_page.dart';
import 'package:lotti/features/sync/ui/matrix_sync_maintenance_page.dart';
import 'package:lotti/features/sync/ui/pages/conflicts/conflict_detail_route.dart';
import 'package:lotti/features/sync/ui/pages/conflicts/conflicts_page.dart';
import 'package:lotti/features/sync/ui/pages/outbox/outbox_monitor_page.dart';
import 'package:lotti/features/sync/ui/pages/sync_node_profile_page.dart';
import 'package:lotti/features/sync/ui/provisioned_sync_page.dart';
import 'package:lotti/features/sync/ui/sync_stats_page.dart';
import 'package:lotti/features/sync/ui/widgets/sync_feature_gate.dart';
import 'package:lotti/features/tts/ui/speech_settings_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';

class SettingsLocation extends BeamLocation<BeamState> {
  SettingsLocation(RouteInformation super.routeInformation);

  @override
  List<String> get pathPatterns => [
    '/settings',
    '/settings/onboarding',
    '/settings/ai',
    '/settings/ai/profiles',
    // AI Settings detail surfaces. Each detail kind sits behind its own
    // literal prefix (provider / model / profile) so the segments
    // can't collide with one another or with the legacy `/profiles`
    // leaf — the dispatcher in the panel registry picks the right
    // page based on which `pathParameters` key beamer captured.
    '/settings/ai/provider/:providerId',
    '/settings/ai/model/:modelId',
    '/settings/ai/profile/:profileId',
    '/settings/sync',
    '/settings/sync/provisioned',
    '/settings/sync/matrix/maintenance',
    '/settings/sync/node-profile',
    '/settings/sync/backfill',
    '/settings/sync/stats',
    '/settings/sync/outbox',
    '/settings/categories',
    '/settings/categories/:categoryId',
    '/settings/categories/create',
    '/settings/projects/:projectId',
    '/settings/labels',
    '/settings/labels/create',
    '/settings/labels/:labelId',
    '/settings/dashboards',
    '/settings/dashboards/:dashboardId',
    '/settings/dashboards/create',
    '/settings/measurables',
    '/settings/measurables/:measurableId',
    '/settings/measurables/create',
    '/settings/habits',
    '/settings/habits/by_id/:habitId',
    '/settings/habits/create',
    '/settings/habits/search/:searchTerm',
    '/settings/agents',
    // Bare per-tab landings. The Settings V2 tree leaves under
    // `agents` canonicalize to these URLs via `pathToBeamUrl`, and
    // the tab-bar inside `AgentSettingsBody` beams here when the
    // user switches tabs on desktop. Listing them as explicit
    // patterns makes Beamer accept them without falling back to a
    // parent location.
    '/settings/agents/templates',
    '/settings/agents/instances',
    '/settings/agents/souls',
    '/settings/agents/pending-wakes',
    '/settings/agents/templates/create',
    '/settings/agents/templates/:templateId',
    '/settings/agents/templates/:templateId/review',
    '/settings/agents/souls/create',
    '/settings/agents/souls/:soulId',
    '/settings/agents/souls/:soulId/review',
    '/settings/agents/instances/:agentId',
    '/settings/daily-os',
    '/settings/flags',
    '/settings/recording-style',
    '/settings/theming',
    '/settings/keyboard-shortcuts',
    '/settings/speech',
    // Spelled out, not `definitionsHubUrl` & co. `pathPatterns` doubles as
    // this app's machine-readable route manifest: `validate-manual.mjs` in
    // `docs-site/scripts` regex-scans this getter for quoted route literals
    // and cross-checks them against the manual's surface inventory. A
    // constant here is invisible to that scan, and the manual build fails
    // claiming no location declares the route. (Its regex reads comments
    // too, so do not write an example route in one.) The hub URL constants
    // are still what the branch predicates and `settingsBranchHubOf` read —
    // that is where a second spelling could actually diverge in behaviour.
    '/settings/definitions',
    '/settings/preferences',
    '/settings/advanced',
    '/settings/advanced/animations',
    '/settings/advanced/manual-language',
    '/settings/advanced/logging_domains',
    '/settings/advanced/conflicts/:conflictId',
    '/settings/advanced/conflicts',
    '/settings/advanced/maintenance',
    '/settings/advanced/onboarding_metrics',
    // Flat legacy route for the mobile-only Health import leaf
    // (`advanced/health-import` in the tree). Declared here so Beamer
    // selects this location for the URL.
    '/settings/health_import',
    // Legacy alias. `/settings/maintenance` was declared as a path
    // pattern on `main` but never rendered a page in `buildPages`
    // (the check was `pathContains('advanced/maintenance')`). To keep
    // any hand-edited bookmarks that hit the advertised pattern
    // working, accept the old URL and render the maintenance page in
    // the mobile/legacy branch below. The canonical URL is now
    // `/settings/advanced/maintenance`.
    '/settings/maintenance',
  ];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) {
    bool pathContains(String s) => state.uri.path.contains(s);
    bool pathContainsKey(String s) => state.pathParameters.containsKey(s);
    final path = state.uri.path;
    // The hub a branch leaf pops back to. Null outside the three branches and
    // on the hubs themselves — see [settingsBranchHubOf].
    final branchHub = settingsBranchHubOf(path);
    final navService = getIt<NavService>();
    final isDesktop = navService.isDesktopMode;

    // On desktop, set the route ValueNotifier and only push the root page.
    // The SettingsRootPage renders the list on the left and routes content
    // into the right pane via SettingsContentPane.
    if (isDesktop) {
      final hasSubRoute = path != '/settings';
      navService.desktopSelectedSettingsRoute.value = hasSubRoute
          ? (
              path: path,
              pathParameters: Map<String, String>.of(state.pathParameters),
              queryParameters: Map<String, String>.of(
                state.uri.queryParameters,
              ),
            )
          : null;

      return const [
        BeamPage(
          key: ValueKey('settings-desktop'),
          title: 'Settings',
          child: SettingsRootPage(),
        ),
      ];
    }

    // Mobile: page-stack drill-down. The landing and the pure-navigation
    // hubs (Definitions / Advanced) are rendered from the shared settings
    // tree; the leaf pages below are the feature pages, unchanged.
    return [
      const BeamPage(
        key: ValueKey('settings'),
        title: 'Settings',
        child: SettingsMobileRootPage(),
      ),

      // Pure-navigation branch hubs stay in the stack beneath their
      // leaves so a back tap returns to the hub, not all the way to the
      // root — the drill-down the unified tree describes.
      if (_inDefinitionsBranch(path))
        const BeamPage(
          key: ValueKey('settings-definitions'),
          title: 'Definitions',
          child: SettingsMobileBranchPage(branchId: 'definitions'),
        ),
      if (_inPreferencesBranch(path))
        const BeamPage(
          key: ValueKey('settings-preferences'),
          title: 'Preferences',
          child: SettingsMobileBranchPage(branchId: 'preferences'),
        ),
      if (_inAdvancedBranch(path))
        const BeamPage(
          key: ValueKey('settings-advanced'),
          title: 'Advanced Settings',
          child: SettingsMobileBranchPage(branchId: 'advanced'),
        ),

      // AI Settings — list view. Rendered under EVERY `/settings/ai/*`
      // URL, always on the same `settings-ai` key, so the mobile page
      // stack reads `SettingsPage > AiSettingsPage > <detail>` and the
      // system back gesture returns to the list rather than all the way
      // to the Settings root.
      //
      // The one-stable-key rule matters as much as the presence: a child
      // URL that omits this page (the legacy `/settings/ai/profiles`
      // leaf used to) makes Navigator *swap* the leaf for the list on
      // pop instead of revealing the list underneath it, so the leaf
      // slides out while the list slides in — a push animation played on
      // a back gesture. Sync learned the same lesson; see the
      // `settings-sync` hub below.
      if (path.startsWith('/settings/ai') && !pathContains('advanced'))
        const BeamPage(
          key: ValueKey('settings-ai'),
          title: 'AI Settings',
          child: AiSettingsPage(),
        ),

      // AI Settings — provider detail. Sits above the list page in the
      // mobile stack. `focusApiKey` is plumbed via a query parameter
      // so the Fix-flow URL is bookmarkable.
      //
      // Every AI detail URL is two segments deep under the list
      // (`/settings/ai/<kind>/<id>`), but Beamer's default pop strips only
      // ONE segment — stranding the route on `/settings/ai/<kind>`, which
      // carries no id and so rebuilds the list page. The next back tap then
      // popped that dead URI to `/settings/ai` and built the very same list
      // again: the user watched the list slide out and an identical list
      // slide back in, still on the page they were leaving. `popToNamed`
      // skips the dead intermediate URI so one back tap is one level, with
      // a real pop transition. Same rule as the two-segment habits
      // sub-routes below.
      if (pathContainsKey('providerId'))
        BeamPage(
          key: ValueKey(
            'settings-ai-provider-${state.pathParameters['providerId']}',
          ),
          title: context.messages.aiProviderDetailPageTitle,
          popToNamed: aiSettingsParentRoute,
          child: AiProviderDetailPage(
            providerId: state.pathParameters['providerId']!,
            focusApiKey: state.uri.queryParameters['focusApiKey'] == 'true',
          ),
        ),

      // AI Settings — model edit. Same stacking and same pop rule.
      if (pathContainsKey('modelId'))
        BeamPage(
          key: ValueKey(
            'settings-ai-model-${state.pathParameters['modelId']}',
          ),
          title: context.messages.settingsBeamPageEditModelTitle,
          popToNamed: aiSettingsParentRoute,
          child: InferenceModelEditPage(
            configId: state.pathParameters['modelId'],
          ),
        ),

      // AI Settings — profile edit. The legacy `Navigator.push` path
      // handed the resolved `AiConfigInferenceProfile` to
      // `InferenceProfileForm`; URL-based routing only carries the
      // id, so we go through `InferenceProfileDetailPage` which
      // resolves the id via Riverpod and hands the loaded profile to
      // the form.
      if (pathContainsKey('profileId'))
        BeamPage(
          key: ValueKey(
            'settings-ai-profile-${state.pathParameters['profileId']}',
          ),
          title: context.messages.settingsBeamPageEditProfileTitle,
          popToNamed: aiSettingsParentRoute,
          child: InferenceProfileDetailPage(
            profileId: state.pathParameters['profileId']!,
          ),
        ),

      // Inference Profiles (legacy)
      if (path == '/settings/ai/profiles')
        const BeamPage(
          key: ValueKey('settings-ai-profiles'),
          title: 'Inference Profiles',
          child: InferenceProfilePage(),
        ),

      // Sync Settings — the list, ordering, copy, and feature-flag gating
      // all come from the shared settings tree (`buildSettingsTree`), so
      // mobile renders the exact same `sync` branch the desktop V2 sidebar
      // does. The provisioned-sync QR card is the first child leaf
      // (`/settings/sync/provisioned`), not a branch header, so the bare
      // branch hub just lists its rows. `SyncFeatureGate` preserves the
      // deep-link bounce back to `/settings` when Matrix sync is disabled.
      //
      // The hub is emitted with the SAME `ValueKey('settings-sync')` for the
      // bare `/settings/sync` URL and for every `/settings/sync/*` leaf. A
      // stable key is what lets the back gesture from a leaf (e.g. Backfill)
      // pop cleanly to reveal the existing hub page beneath it. Splitting the
      // key between base and leaf states (the previous `settings-sync-base`)
      // made Navigator swap the underlying page instead of revealing it,
      // producing the wrong pop animation. The Definitions/Advanced/AI
      // branches use the same one-stable-key rule.
      if (path == '/settings/sync' || path.startsWith('/settings/sync/'))
        const BeamPage(
          key: ValueKey('settings-sync'),
          title: 'Sync Settings',
          child: SyncFeatureGate(
            child: SettingsMobileBranchPage(branchId: 'sync'),
          ),
        ),

      // Provisioned-sync leaf. The body is the same QR-pairing card the
      // desktop `sync-provisioned` panel renders; the wrapper supplies the
      // mobile page chrome (title + back button) and the sync feature gate.
      if (path == '/settings/sync/provisioned')
        const BeamPage(
          key: ValueKey('settings-sync-provisioned'),
          title: 'Devices',
          child: ProvisionedSyncPage(),
        ),

      if (path == '/settings/sync/matrix/maintenance')
        const BeamPage(
          key: ValueKey('settings-sync-matrix-maintenance'),
          title: 'Matrix Sync Maintenance',
          child: MatrixSyncMaintenancePage(),
        ),

      // Node-profile and outbox pages carry no gate of their own (unlike
      // Provisioned / Stats / Backfill / Matrix-maintenance, which embed
      // `SyncFeatureGate` in the page widget), so the route wraps them:
      // without it a stale deep link in a guest/demo world would render a
      // sync surface whose stack is structurally absent.
      if (path == '/settings/sync/node-profile')
        const BeamPage(
          key: ValueKey('settings-sync-node-profile'),
          child: SyncFeatureGate(child: SyncNodeProfilePage()),
        ),

      if (path == '/settings/sync/backfill')
        const BeamPage(
          key: ValueKey('settings-sync-backfill'),
          title: 'Backfill Settings',
          child: BackfillSettingsPage(),
        ),

      if (path == '/settings/sync/stats')
        const BeamPage(
          key: ValueKey('settings-sync-stats'),
          title: 'Sync Stats',
          child: SyncStatsPage(),
        ),

      if (path == '/settings/sync/outbox')
        const BeamPage(
          key: ValueKey('settings-sync-outbox'),
          child: SyncFeatureGate(child: OutboxMonitorPage()),
        ),

      if (pathContains('labels'))
        BeamPage(
          key: const ValueKey('settings-labels'),
          popToNamed: branchHub,
          child: const LabelsListPage(),
        ),

      if (pathContains('labels/create'))
        BeamPage(
          key: const ValueKey('settings-labels-create'),
          child: LabelDetailsPage(
            initialName: state.uri.queryParameters['name'],
          ),
        ),

      if (pathContains('labels') && pathContainsKey('labelId'))
        BeamPage(
          key: ValueKey('settings-labels-${state.pathParameters['labelId']}'),
          child: LabelDetailsPage(
            labelId: state.pathParameters['labelId'],
          ),
        ),

      // New Categories Implementation (Riverpod)
      if (pathContains('categories'))
        BeamPage(
          key: const ValueKey('settings-categories'),
          popToNamed: branchHub,
          child: const new_categories.CategoriesListPage(),
        ),

      if (pathContains('categories/create'))
        const BeamPage(
          key: ValueKey('settings-categories-create'),
          child: new_category_details.CategoryDetailsPage(),
        ),

      if (pathContains('categories') &&
          pathContainsKey('categoryId') &&
          state.pathParameters['categoryId'] != 'create')
        BeamPage(
          key: ValueKey(
            'settings-categories-${state.pathParameters['categoryId']}',
          ),
          child: new_category_details.CategoryDetailsPage(
            categoryId: state.pathParameters['categoryId'],
          ),
        ),

      // Projects (per-project drill-down from category pages). The create
      // flow runs in a modal launched from the Projects tab (no route of its
      // own), so it never gets trapped in the Settings V2 panel registry,
      // which has no `projects` entry. Explicitly exclude the reserved
      // `create` slug so a stale `/settings/projects/create` deep link (the
      // `:projectId` pattern would still greedily match it) cannot render
      // `ProjectDetailPage` against a non-id slug.
      if (pathContains('projects') &&
          pathContainsKey('projectId') &&
          state.pathParameters['projectId'] != 'create')
        BeamPage(
          key: ValueKey(
            'settings-projects-${state.pathParameters['projectId']}',
          ),
          child: ProjectDetailPage(
            projectId: state.pathParameters['projectId']!,
            categoryId: state.uri.queryParameters['categoryId'],
          ),
        ),

      // Dashboards
      if (pathContains('dashboards'))
        BeamPage(
          key: const ValueKey('settings-dashboards'),
          popToNamed: branchHub,
          child: const DashboardSettingsPage(),
        ),

      if (pathContains('dashboards') &&
          !pathContains('create') &&
          pathContainsKey('dashboardId'))
        BeamPage(
          key: ValueKey(
            'settings-dashboards-${state.pathParameters['dashboardId']}',
          ),
          child: EditDashboardPage(
            dashboardId: state.pathParameters['dashboardId']!,
          ),
        ),

      if (pathContains('dashboards/create'))
        BeamPage(
          key: const ValueKey('settings-dashboards-create'),
          child: CreateDashboardPage(),
        ),

      // Measurables
      if (pathContains('measurables'))
        BeamPage(
          key: const ValueKey('settings-measurables'),
          popToNamed: branchHub,
          child: const MeasurablesPage(),
        ),

      if (pathContains('measurables') &&
          !pathContains('create') &&
          pathContainsKey('measurableId'))
        BeamPage(
          key: ValueKey(
            'settings-measurables-${state.pathParameters['measurableId']}',
          ),
          child: EditMeasurablePage(
            measurableId: state.pathParameters['measurableId']!,
          ),
        ),

      if (pathContains('measurables/create'))
        BeamPage(
          key: const ValueKey('settings-measurables-create'),
          child: CreateMeasurablePage(),
        ),

      // Habits
      if (pathContains('habits') && !pathContains('/search'))
        BeamPage(
          key: const ValueKey('settings-habits'),
          popToNamed: branchHub,
          child: const HabitsPage(),
        ),

      // The habits sub-routes are two segments deep (`by_id/<id>`,
      // `search/<term>`), but Beamer's default pathSegmentPop removes only
      // ONE segment — landing on dead intermediate URIs like
      // `/settings/habits/by_id` that render the list while the route
      // state still looks like an editor. `popToNamed` skips straight to
      // the list URI so a single back tap leaves the editor for real.
      if (pathContains('habits/search') && pathContainsKey('searchTerm'))
        BeamPage(
          key: ValueKey(
            'settings-habits-search-${state.pathParameters['searchTerm']}',
          ),
          popToNamed: '/settings/habits',
          child: HabitsPage(
            initialSearchTerm: state.pathParameters['searchTerm'],
          ),
        ),

      if (pathContains('habits/by_id') && pathContainsKey('habitId'))
        BeamPage(
          key: ValueKey(
            'settings-habits-${state.pathParameters['habitId']}',
          ),
          popToNamed: '/settings/habits',
          child: HabitEditorPage(
            habitId: state.pathParameters['habitId'],
            returnPath: '/settings/habits',
          ),
        ),

      if (pathContains('habits/create'))
        const BeamPage(
          key: ValueKey('settings-habits-create'),
          child: HabitEditorPage(returnPath: '/settings/habits'),
        ),

      // Agents — landing page is always in the stack for sub-routes
      if (pathContains('agents'))
        const BeamPage(
          key: ValueKey('settings-agents'),
          child: AgentSettingsPage(),
        ),

      if (pathContains('agents/templates/create'))
        const BeamPage(
          key: ValueKey('settings-agents-templates-create'),
          child: AgentTemplateDetailPage(),
        )
      else if (pathContains('agents/templates') &&
          pathContainsKey('templateId'))
        BeamPage(
          key: ValueKey(
            'settings-agents-templates-'
            '${state.pathParameters['templateId']}',
          ),
          child: AgentTemplateDetailPage(
            templateId: state.pathParameters['templateId'],
          ),
        ),

      if (pathContains('agents/templates') &&
          pathContainsKey('templateId') &&
          path.endsWith('/review'))
        BeamPage(
          key: ValueKey(
            'settings-agents-templates-review-'
            '${state.pathParameters['templateId']}',
          ),
          child: EvolutionReviewPage(
            templateId: state.pathParameters['templateId']!,
          ),
        ),
      if (pathContains('agents/souls/create'))
        const BeamPage(
          key: ValueKey('settings-agents-souls-create'),
          child: AgentSoulDetailPage(),
        )
      else if (pathContains('agents/souls') &&
          pathContainsKey('soulId') &&
          path.endsWith('/review'))
        BeamPage(
          key: ValueKey(
            'settings-agents-souls-review-'
            '${state.pathParameters['soulId']}',
          ),
          child: SoulEvolutionReviewPage(
            soulId: state.pathParameters['soulId']!,
          ),
        )
      else if (pathContains('agents/souls') && pathContainsKey('soulId'))
        BeamPage(
          key: ValueKey(
            'settings-agents-souls-'
            '${state.pathParameters['soulId']}',
          ),
          child: AgentSoulDetailPage(
            soulId: state.pathParameters['soulId'],
          ),
        ),

      if (pathContains('agents/instances') && pathContainsKey('agentId'))
        BeamPage(
          key: ValueKey(
            'settings-agents-instances-'
            '${state.pathParameters['agentId']}',
          ),
          child: AgentDetailPage(
            agentId: state.pathParameters['agentId']!,
          ),
        ),

      if (path == '/settings/daily-os')
        const BeamPage(
          key: ValueKey('settings-daily-os'),
          child: DailyOsSettingsPage(),
        ),

      // Flags
      if (pathContains('flags'))
        BeamPage(
          key: const ValueKey('settings-flags'),
          popToNamed: branchHub,
          child: const FlagsPage(),
        ),

      // Onboarding — top-level leaf, opens directly. Exact-path match
      // (not `pathContains`) so it can never accidentally swallow
      // `/settings/advanced/onboarding_metrics`.
      if (path == '/settings/onboarding')
        const BeamPage(
          key: ValueKey('settings-onboarding'),
          child: OnboardingSettingsPage(),
        ),

      // Recording style — top-level leaf, opens directly.
      if (pathContains('recording-style'))
        BeamPage(
          key: const ValueKey('settings-recording-style'),
          popToNamed: branchHub,
          child: const RecordingStyleSettingsPage(),
        ),

      // Theming
      if (pathContains('theming'))
        BeamPage(
          key: const ValueKey('settings-theming'),
          popToNamed: branchHub,
          child: const ThemingPage(),
        ),

      if (pathContains('keyboard-shortcuts'))
        BeamPage(
          key: const ValueKey('settings-keyboard-shortcuts'),
          popToNamed: branchHub,
          child: const KeyboardShortcutsPage(),
        ),

      // Speech (text-to-speech) — top-level leaf, opens directly.
      if (pathContains('speech'))
        BeamPage(
          key: const ValueKey('settings-speech'),
          popToNamed: branchHub,
          child: const SpeechSettingsPage(),
        ),

      // Health Import
      if (pathContains('health_import'))
        BeamPage(
          key: const ValueKey('settings-health_import'),
          popToNamed: branchHub,
          child: const HealthImportPage(),
        ),

      if (pathContains('advanced/animations'))
        BeamPage(
          key: const ValueKey('settings-animations'),
          popToNamed: branchHub,
          child: const CelebrationSettingsPage(),
        ),

      if (pathContains('advanced/manual-language'))
        const BeamPage(
          key: ValueKey('settings-manual-language'),
          child: ManualLanguageSettingsPage(),
        ),

      if (pathContains('advanced/logging_domains'))
        const BeamPage(
          key: ValueKey('settings-logging-domains'),
          child: LoggingSettingsPage(),
        ),

      if (pathContains('advanced/about'))
        const BeamPage(
          key: ValueKey('settings-about'),
          child: AboutPage(),
        ),

      if (pathContains('advanced/conflicts'))
        const BeamPage(
          key: ValueKey('settings-conflicts'),
          child: ConflictsPage(),
        ),

      if (pathContains('advanced/conflicts/') && pathContainsKey('conflictId'))
        BeamPage(
          key: ValueKey(
            'settings-conflict-${state.pathParameters['conflictId']}',
          ),
          child: ConflictDetailRoute(
            conflictId: state.pathParameters['conflictId']!,
          ),
        ),

      if (pathContains('advanced/maintenance') ||
          path == '/settings/maintenance')
        const BeamPage(
          key: ValueKey('settings-maintenance'),
          child: MaintenancePage(),
        ),

      if (pathContains('advanced/onboarding_metrics'))
        const BeamPage(
          key: ValueKey('settings-onboarding-metrics'),
          child: OnboardingMetricsPage(),
        ),
    ];
  }
}

/// Public Beamer URLs of the definition leaves. Their tree ids live under
/// the `definitions/` branch, but their URLs stay flat for deep-link
/// compatibility (see `settingsNodeUrls`), so the Definitions hub is
/// matched on the flat URL here.
const List<String> definitionsLeafPaths = [
  '/settings/categories',
  '/settings/labels',
  '/settings/habits',
  '/settings/dashboards',
  '/settings/measurables',
];

bool _inDefinitionsBranch(String path) =>
    path == definitionsHubUrl ||
    definitionsLeafPaths.any((p) => path == p || path.startsWith('$p/'));

/// Animations moved into the `preferences` branch but kept the URL it
/// shipped with, under `/settings/advanced/` (see `settingsNodeUrls`). That
/// makes it the one path [_inAdvancedBranch]'s `/settings/advanced/` prefix
/// would otherwise claim, which is why that predicate defers to
/// [_inPreferencesBranch] instead of reading the branch off the URL shape.
const String _animationsPath = '/settings/advanced/animations';

/// Public Beamer URLs of the preference leaves. Their tree ids live under
/// the `preferences/` branch while their URLs stay where they were, so the
/// Preferences hub is matched on those URLs here — exactly as the
/// Definitions hub is matched on the flat definition URLs.
const List<String> preferencesLeafPaths = [
  '/settings/theming',
  _animationsPath,
  '/settings/recording-style',
  '/settings/speech',
  '/settings/keyboard-shortcuts',
];

bool _inPreferencesBranch(String path) =>
    path == preferencesHubUrl ||
    preferencesLeafPaths.any((p) => path == p || path.startsWith('$p/'));

/// The hub of the branch [path] belongs to, or `null` when it belongs to
/// none — and, on a branch's own leaf page, the destination that leaf must
/// name with `popToNamed`.
///
/// **Only a leaf page may use this as its pop destination.** The answer is
/// branch membership, which every URL inside a branch shares: a page stacked
/// *above* a leaf gets the same hub back, though it must pop to the leaf
/// beneath it instead. `/settings/advanced/conflicts/:conflictId` returns
/// [advancedHubUrl] here and pops to `/settings/advanced/conflicts`; the
/// habit editor returns [definitionsHubUrl] and pops to `/settings/habits`.
/// Passing this to a detail page would skip a level.
///
/// Beamer's default pop ([BeamPage.pathSegmentPop]) strips exactly one URI
/// segment. That is the right answer only when a leaf's URL nests under its
/// hub's: popping `/settings/advanced/maintenance` lands on
/// `/settings/advanced`, where [_inAdvancedBranch] still matches, so the hub
/// stays in the stack and the back tap moves one level.
///
/// Most branch leaves do not nest. The definition and preference leaves keep
/// the flat URLs they shipped with (`/settings/categories`,
/// `/settings/theming`) for deep-link compatibility, `/settings/flags` and
/// `/settings/health_import` do the same under Advanced, and Animations sits
/// under `/settings/advanced/` while belonging to Preferences. For every one
/// of them the single-segment pop lands where the leaf's own hub predicate
/// does *not* match — so `buildPages` drops the hub as well, and one back tap
/// left the branch entirely. The hub was still revealed by the Navigator's
/// pop animation, then replaced by the Settings root when the rebuild landed,
/// which is why it read as the page bouncing back on its own after a second.
///
/// Deriving the destination from the same predicates that decide whether the
/// hub is *in* the stack is the point: hub presence and hub pop cannot
/// disagree, and a leaf added to one of the `*LeafPaths` lists is routed here
/// without a second edit.
String? settingsBranchHubOf(String path) {
  // A hub itself pops to the Settings root, which the default pop already
  // does — naming a hub as its own destination would trap the back gesture.
  if (path == definitionsHubUrl ||
      path == preferencesHubUrl ||
      path == advancedHubUrl) {
    return null;
  }
  if (_inDefinitionsBranch(path)) return definitionsHubUrl;
  if (_inPreferencesBranch(path)) return preferencesHubUrl;
  if (_inAdvancedBranch(path)) return advancedHubUrl;
  return null;
}

/// Advanced's leaves that kept a flat URL instead of nesting under
/// [advancedHubUrl] — Health import's tree node lives under Advanced but its
/// public URL never moved. Listed so the hub is matched on them, and so the
/// tests can derive their coverage from the same list the routing reads.
const List<String> advancedFlatLeafPaths = [
  '/settings/flags',
  '/settings/health_import',
];

bool _inAdvancedBranch(String path) =>
    !_inPreferencesBranch(path) &&
    (path == advancedHubUrl ||
        path.startsWith('$advancedHubUrl/') ||
        advancedFlatLeafPaths.contains(path));
