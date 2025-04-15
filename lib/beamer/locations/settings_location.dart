import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/journal/ui/pages/entry_details_page.dart';
import 'package:lotti/features/speech/ui/pages/speech_settings_page.dart';
import 'package:lotti/pages/settings/advanced/about_page.dart';
import 'package:lotti/pages/settings/advanced/conflicts_page.dart';
import 'package:lotti/pages/settings/advanced/logging_page.dart';
import 'package:lotti/pages/settings/advanced/maintenance_page.dart';
import 'package:lotti/pages/settings/advanced_settings_page.dart';
import 'package:lotti/pages/settings/categories/categories_page.dart';
import 'package:lotti/pages/settings/categories/category_create_page.dart';
import 'package:lotti/pages/settings/categories/category_details_page.dart';
import 'package:lotti/pages/settings/dashboards/create_dashboard_page.dart';
import 'package:lotti/pages/settings/dashboards/dashboard_definition_page.dart';
import 'package:lotti/pages/settings/dashboards/dashboards_page.dart';
import 'package:lotti/pages/settings/flags_page.dart';
import 'package:lotti/pages/settings/habits/habit_create_page.dart';
import 'package:lotti/pages/settings/habits/habit_details_page.dart';
import 'package:lotti/pages/settings/habits/habits_page.dart';
import 'package:lotti/pages/settings/health_import_page.dart';
import 'package:lotti/pages/settings/measurables/measurable_create_page.dart';
import 'package:lotti/pages/settings/measurables/measurable_details_page.dart';
import 'package:lotti/pages/settings/measurables/measurables_page.dart';
import 'package:lotti/pages/settings/outbox/outbox_monitor.dart';
import 'package:lotti/pages/settings/settings_page.dart';
import 'package:lotti/pages/settings/tags/create_tag_page.dart';
import 'package:lotti/pages/settings/tags/tag_edit_page.dart';
import 'package:lotti/pages/settings/tags/tags_page.dart';
import 'package:lotti/pages/settings/theming_page.dart';
import 'package:showcaseview/showcaseview.dart';

class SettingsLocation extends BeamLocation<BeamState> {
  SettingsLocation(RouteInformation super.routeInformation);

  @override
  List<String> get pathPatterns => [
        '/settings',
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
        '/settings/outbox_monitor',
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

    return [
      const BeamPage(
        key: ValueKey('settings'),
        title: 'Settings',
        child: SettingsPage(),
      ),

      // Categories
      if (pathContains('categories'))
        const BeamPage(
          key: ValueKey('settings-categories'),
          child: CategoriesPage(),
        ),

      if (pathContains('categories') &&
          !pathContains('create') &&
          pathContainsKey('categoryId'))
        BeamPage(
          key: ValueKey(
            'settings-categories-${state.pathParameters['categoryId']}',
          ),
          child: EditCategoryPage(
            categoryId: state.pathParameters['categoryId']!,
          ),
        ),

      if (pathContains('categories/create'))
        BeamPage(
          key: const ValueKey('settings-categories-create'),
          child: CreateCategoryPage(),
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
        BeamPage(
          key: const ValueKey('settings-flags'),
          child: ShowCaseWidget(
            builder: (context) => const FlagsPage(),
          ),
        ),

      // Theming
      if (pathContains('theming'))
        BeamPage(
          key: const ValueKey('settings-theming'),
          child: ShowCaseWidget(
            builder: (context) => const ThemingPage(),
          ),
        ),

      // Health Import
      if (pathContains('health_import'))
        const BeamPage(
          key: ValueKey('settings-health_import'),
          child: HealthImportPage(),
        ),

      // Speech Settings
      if (pathContains('speech_settings'))
        const BeamPage(
          key: ValueKey('speech_settings'),
          child: SpeechSettingsPage(),
        ),

      // Advanced Settings
      if (pathContains('advanced'))
        BeamPage(
          key: const ValueKey('settings-advanced'),
          child: ShowCaseWidget(
            builder: (context) => const AdvancedSettingsPage(),
          ),
        ),

      if (pathContains('advanced/outbox_monitor'))
        const BeamPage(
          key: ValueKey('settings-outbox_monitor'),
          child: OutboxMonitorPage(),
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
