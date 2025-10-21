import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_page.dart';
import 'package:lotti/features/categories/ui/pages/categories_list_page.dart'
    as new_categories;
import 'package:lotti/features/categories/ui/pages/category_details_page.dart'
    as new_category_details;
import 'package:lotti/features/journal/ui/pages/entry_details_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/about_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/conflicts_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/logging_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/maintenance_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced_settings_page.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/create_dashboard_page.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/dashboard_definition_page.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/dashboards_page.dart';
import 'package:lotti/features/settings/ui/pages/flags_page.dart';
import 'package:lotti/features/settings/ui/pages/habits/habit_create_page.dart';
import 'package:lotti/features/settings/ui/pages/habits/habit_details_page.dart';
import 'package:lotti/features/settings/ui/pages/habits/habits_page.dart';
import 'package:lotti/features/settings/ui/pages/health_import_page.dart';
import 'package:lotti/features/settings/ui/pages/measurables/measurable_create_page.dart';
import 'package:lotti/features/settings/ui/pages/measurables/measurable_details_page.dart';
import 'package:lotti/features/settings/ui/pages/measurables/measurables_page.dart';
import 'package:lotti/features/settings/ui/pages/outbox/outbox_monitor.dart';
import 'package:lotti/features/settings/ui/pages/settings_page.dart';
import 'package:lotti/features/settings/ui/pages/tags/create_tag_page.dart';
import 'package:lotti/features/settings/ui/pages/tags/tag_edit_page.dart';
import 'package:lotti/features/settings/ui/pages/tags/tags_page.dart';
import 'package:lotti/features/settings/ui/pages/theming_page.dart';
import 'package:lotti/features/sync/ui/sync_settings_page.dart';
import 'package:lotti/features/sync/ui/sync_stats_page.dart';

class SettingsLocation extends BeamLocation<BeamState> {
  SettingsLocation(RouteInformation super.routeInformation);

  @override
  List<String> get pathPatterns => [
        '/settings',
        '/settings/ai',
        '/settings/sync',
        '/settings/sync/stats',
        '/settings/sync/outbox',
        '/settings/tags',
        '/settings/tags/:tagEntityId',
        '/settings/tags/create/:tagType',
        '/settings/categories',
        '/settings/categories/:categoryId',
        '/settings/categories/create',
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
        '/settings/flags',
        '/settings/theming',
        '/settings/advanced',
        '/settings/logging',
        '/settings/advanced/logging/:logEntryId',
        '/settings/advanced/conflicts/:conflictId',
        '/settings/advanced/conflicts/:conflictId/edit',
        '/settings/advanced/conflicts',
        '/settings/maintenance',
      ];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) {
    bool pathContains(String s) => state.uri.path.contains(s);
    bool pathContainsKey(String s) => state.pathParameters.containsKey(s);
    final path = state.uri.path;

    return [
      const BeamPage(
        key: ValueKey('settings'),
        title: 'Settings',
        child: SettingsPage(),
      ),

      // AI Settings
      if (pathContains('ai') && !pathContains('advanced'))
        const BeamPage(
          key: ValueKey('settings-ai'),
          title: 'AI Settings',
          child: AiSettingsPage(),
        ),

      // Sync Settings (exact matches for robustness)
      if (path == '/settings/sync')
        const BeamPage(
          key: ValueKey('settings-sync'),
          title: 'Sync Settings',
          child: SyncSettingsPage(),
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

      // Tags
      if (pathContains('tags'))
        const BeamPage(
          key: ValueKey('settings-tags'),
          child: TagsPage(),
        ),

      if (pathContains('tags') &&
          !pathContains('create') &&
          pathContainsKey('tagEntityId'))
        BeamPage(
          key: ValueKey(
            'settings-tags-${state.pathParameters['tagEntityId']}',
          ),
          child: EditExistingTagPage(
            tagEntityId: state.pathParameters['tagEntityId']!,
          ),
        ),

      if (pathContains('tags/create') && pathContainsKey('tagType'))
        BeamPage(
          key: ValueKey(
            'settings-tags-create-${state.pathParameters['tagType']}',
          ),
          child: CreateTagPage(tagType: state.pathParameters['tagType']!),
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

      if (pathContains('advanced/logging'))
        const BeamPage(
          key: ValueKey('settings-logging'),
          child: LoggingPage(),
        ),

      if (pathContains('advanced/about'))
        const BeamPage(
          key: ValueKey('settings-about'),
          child: AboutPage(),
        ),

      if (pathContains('advanced/logging') && pathContainsKey('logEntryId'))
        BeamPage(
          key: ValueKey(
            'settings-logging-${state.pathParameters['logEntryId']}',
          ),
          child: LogDetailPage(
            logEntryId: state.pathParameters['logEntryId']!,
          ),
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

      if (pathContains('advanced/maintenance'))
        const BeamPage(
          key: ValueKey('settings-maintenance'),
          child: MaintenancePage(),
        ),
    ];
  }
}
