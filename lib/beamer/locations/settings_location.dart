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
import 'package:lotti/features/journal/ui/pages/entry_details_page.dart';
import 'package:lotti/features/labels/ui/pages/label_details_page.dart';
import 'package:lotti/features/labels/ui/pages/labels_list_page.dart';
import 'package:lotti/features/projects/ui/pages/project_detail_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/about_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/logging_settings_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/maintenance_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced_settings_page.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/create_dashboard_page.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/dashboard_definition_page.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/dashboards_page.dart';
import 'package:lotti/features/settings/ui/pages/definitions_page.dart';
import 'package:lotti/features/settings/ui/pages/flags_page.dart';
import 'package:lotti/features/settings/ui/pages/habits/habit_create_page.dart';
import 'package:lotti/features/settings/ui/pages/habits/habit_details_page.dart';
import 'package:lotti/features/settings/ui/pages/habits/habits_page.dart';
import 'package:lotti/features/settings/ui/pages/health_import_page.dart';
import 'package:lotti/features/settings/ui/pages/measurables/measurable_create_page.dart';
import 'package:lotti/features/settings/ui/pages/measurables/measurable_details_page.dart';
import 'package:lotti/features/settings/ui/pages/measurables/measurables_page.dart';
import 'package:lotti/features/settings/ui/pages/settings_page.dart';
import 'package:lotti/features/settings/ui/pages/settings_root_page.dart';
import 'package:lotti/features/settings/ui/pages/theming_page.dart';
import 'package:lotti/features/sync/ui/backfill_settings_page.dart';
import 'package:lotti/features/sync/ui/matrix_sync_maintenance_page.dart';
import 'package:lotti/features/sync/ui/pages/conflicts/conflict_detail_route.dart';
import 'package:lotti/features/sync/ui/pages/conflicts/conflicts_page.dart';
import 'package:lotti/features/sync/ui/pages/outbox/outbox_monitor_page.dart';
import 'package:lotti/features/sync/ui/pages/sync_node_profile_page.dart';
import 'package:lotti/features/sync/ui/sync_settings_page.dart';
import 'package:lotti/features/sync/ui/sync_stats_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';

class SettingsLocation extends BeamLocation<BeamState> {
  SettingsLocation(RouteInformation super.routeInformation);

  @override
  List<String> get pathPatterns => [
    '/settings',
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
    '/settings/agents/stats',
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
    '/settings/flags',
    '/settings/theming',
    '/settings/definitions',
    '/settings/advanced',
    '/settings/advanced/logging_domains',
    '/settings/advanced/conflicts/:conflictId',
    '/settings/advanced/conflicts/:conflictId/edit',
    '/settings/advanced/conflicts',
    '/settings/advanced/maintenance',
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

    // Mobile: keep the existing page-stack navigation.
    return [
      const BeamPage(
        key: ValueKey('settings'),
        title: 'Settings',
        child: SettingsPage(),
      ),

      // AI Settings — list view. Rendered under any `/settings/ai/*`
      // URL so the mobile page stack reads
      // `SettingsPage > AiSettingsPage > <detail>` and the system
      // back gesture returns to the list, not all the way to the
      // Settings root. The legacy `/settings/ai/profiles` leaf opts
      // out so it can render its own page directly.
      if (path.startsWith('/settings/ai') &&
          !pathContains('advanced') &&
          path != '/settings/ai/profiles')
        const BeamPage(
          key: ValueKey('settings-ai'),
          title: 'AI Settings',
          child: AiSettingsPage(),
        ),

      // AI Settings — provider detail. Sits above the list page in the
      // mobile stack. `focusApiKey` is plumbed via a query parameter
      // so the Fix-flow URL is bookmarkable.
      if (pathContainsKey('providerId'))
        BeamPage(
          key: ValueKey(
            'settings-ai-provider-${state.pathParameters['providerId']}',
          ),
          title: context.messages.aiProviderDetailPageTitle,
          child: AiProviderDetailPage(
            providerId: state.pathParameters['providerId']!,
            focusApiKey: state.uri.queryParameters['focusApiKey'] == 'true',
          ),
        ),

      // AI Settings — model edit. Same stacking rule.
      if (pathContainsKey('modelId'))
        BeamPage(
          key: ValueKey(
            'settings-ai-model-${state.pathParameters['modelId']}',
          ),
          title: context.messages.settingsBeamPageEditModelTitle,
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

      // Sync Settings (exact matches for robustness)
      if (path == '/settings/sync')
        const BeamPage(
          key: ValueKey('settings-sync'),
          title: 'Sync Settings',
          child: SyncSettingsPage(),
        ),
      if (path != '/settings/sync' && path.startsWith('/settings/sync/'))
        const BeamPage(
          key: ValueKey('settings-sync-base'),
          title: 'Sync Settings',
          child: SyncSettingsPage(),
        ),

      if (path == '/settings/sync/matrix/maintenance')
        const BeamPage(
          key: ValueKey('settings-sync-matrix-maintenance'),
          title: 'Matrix Sync Maintenance',
          child: MatrixSyncMaintenancePage(),
        ),

      if (path == '/settings/sync/node-profile')
        const BeamPage(
          key: ValueKey('settings-sync-node-profile'),
          child: SyncNodeProfilePage(),
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
          child: OutboxMonitorPage(),
        ),

      if (pathContains('labels'))
        const BeamPage(
          key: ValueKey('settings-labels'),
          child: LabelsListPage(),
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
        const BeamPage(
          key: ValueKey('settings-categories'),
          child: new_categories.CategoriesListPage(),
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
      // flow lives under `ProjectsLocation` so it doesn't get trapped in
      // the Settings V2 panel registry, which has no `projects` entry.
      // Explicitly exclude the reserved `create` slug so a stale
      // `/settings/projects/create` deep link (the URL has been moved
      // out of `pathPatterns`, but the `:projectId` pattern would still
      // greedily match it) cannot render `ProjectDetailPage` against a
      // non-id slug.
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
        const BeamPage(
          key: ValueKey('settings-dashboards'),
          child: DashboardSettingsPage(),
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
        const BeamPage(
          key: ValueKey('settings-measurables'),
          child: MeasurablesPage(),
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
        const BeamPage(
          key: ValueKey('settings-habits'),
          child: HabitsPage(),
        ),

      if (pathContains('habits/search') && pathContainsKey('searchTerm'))
        BeamPage(
          key: ValueKey(
            'settings-habits-search-${state.pathParameters['searchTerm']}',
          ),
          child: HabitsPage(
            initialSearchTerm: state.pathParameters['searchTerm'],
          ),
        ),

      if (pathContains('habits/by_id') && pathContainsKey('habitId'))
        BeamPage(
          key: ValueKey(
            'settings-habits-${state.pathParameters['habitId']}',
          ),
          child: EditHabitPage(
            habitId: state.pathParameters['habitId']!,
          ),
        ),

      if (pathContains('habits/create'))
        BeamPage(
          key: const ValueKey('settings-habits-create'),
          child: CreateHabitPage(),
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

      // Flags
      if (pathContains('flags'))
        const BeamPage(
          key: ValueKey('settings-flags'),
          child: FlagsPage(),
        ),

      // Theming
      if (pathContains('theming'))
        const BeamPage(
          key: ValueKey('settings-theming'),
          child: ThemingPage(),
        ),

      // Definitions hub (groups habits / categories / labels /
      // dashboards / measurables under one entry on the v1 root list).
      if (path == '/settings/definitions')
        const BeamPage(
          key: ValueKey('settings-definitions'),
          child: DefinitionsPage(),
        ),

      // Health Import
      if (pathContains('health_import'))
        const BeamPage(
          key: ValueKey('settings-health_import'),
          child: HealthImportPage(),
        ),

      // Advanced Settings
      if (pathContains('advanced'))
        const BeamPage(
          key: ValueKey('settings-advanced'),
          child: AdvancedSettingsPage(),
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

      if (pathContains('advanced/conflicts/') &&
          pathContainsKey('conflictId') &&
          pathContains('/edit'))
        BeamPage(
          key: ValueKey(
            'settings-conflict-edit-${state.pathParameters['conflictId']}',
          ),
          child: EntryDetailsPage(itemId: state.pathParameters['conflictId']!),
        ),

      if (pathContains('advanced/maintenance') ||
          path == '/settings/maintenance')
        const BeamPage(
          key: ValueKey('settings-maintenance'),
          child: MaintenancePage(),
        ),
    ];
  }
}
