import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/pages/journal/entry_details_page.dart';
import 'package:lotti/pages/settings/about_page.dart';
import 'package:lotti/pages/settings/advanced_settings_page.dart';
import 'package:lotti/pages/settings/conflicts_page.dart';
import 'package:lotti/pages/settings/dashboards/create_dashboard_page.dart';
import 'package:lotti/pages/settings/dashboards/dashboard_definition_page.dart';
import 'package:lotti/pages/settings/dashboards/dashboards_page.dart';
import 'package:lotti/pages/settings/flags_page.dart';
import 'package:lotti/pages/settings/habits/habit_create_page.dart';
import 'package:lotti/pages/settings/habits/habit_details_page.dart';
import 'package:lotti/pages/settings/habits/habits_page.dart';
import 'package:lotti/pages/settings/health_import_page.dart';
import 'package:lotti/pages/settings/logging_page.dart';
import 'package:lotti/pages/settings/maintenance_page.dart';
import 'package:lotti/pages/settings/measurables/measurable_create_page.dart';
import 'package:lotti/pages/settings/measurables/measurable_details_page.dart';
import 'package:lotti/pages/settings/measurables/measurables_page.dart';
import 'package:lotti/pages/settings/outbox/outbox_monitor.dart';
import 'package:lotti/pages/settings/settings_page.dart';
import 'package:lotti/pages/settings/sync/sync_assistant_page.dart';
import 'package:lotti/pages/settings/tags/create_tag_page.dart';
import 'package:lotti/pages/settings/tags/tag_edit_page.dart';
import 'package:lotti/pages/settings/tags/tags_page.dart';

class SettingsLocation extends BeamLocation<BeamState> {
  SettingsLocation(RouteInformation super.routeInformation);

  @override
  List<String> get pathPatterns => [
        '/settings',
        '/settings/tags',
        '/settings/tags/:tagEntityId',
        '/settings/tags/create/:tagType',
        '/settings/dashboards',
        '/settings/dashboards/:dashboardId',
        '/settings/dashboards/create',
        '/settings/measurables',
        '/settings/measurables/:measurableId',
        '/settings/measurables/create',
        '/settings/habits',
        '/settings/habits/:habitId',
        '/settings/habits/create',
        '/settings/flags',
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
        type: BeamPageType.noTransition,
        child: SettingsPage(),
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
        const BeamPage(
          key: ValueKey('settings-dashboards-create'),
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
        const BeamPage(
          key: ValueKey('settings-measurables-create'),
          child: CreateMeasurablePage(),
        ),

      // Habits
      if (pathContains('habits'))
        const BeamPage(
          key: ValueKey('settings-habits'),
          child: HabitsPage(),
        ),

      if (pathContains('habits') &&
          !pathContains('create') &&
          pathContainsKey('habitId'))
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

      if (pathContains('advanced/sync_settings'))
        const BeamPage(
          key: ValueKey('settings-sync_settings'),
          child: SyncAssistantPage(),
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
          child: EntryDetailPage(itemId: state.pathParameters['conflictId']!),
        ),

      if (pathContains('advanced/maintenance'))
        const BeamPage(
          key: ValueKey('settings-maintenance'),
          child: MaintenancePage(),
        ),
    ];
  }
}
