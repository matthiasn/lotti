import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/pages/settings/dashboards/create_dashboard_page.dart';
import 'package:lotti/pages/settings/dashboards/dashboard_definition_page.dart';
import 'package:lotti/pages/settings/dashboards/dashboards_page.dart';
import 'package:lotti/pages/settings/flags_page.dart';
import 'package:lotti/pages/settings/measurables/measurable_create_page.dart';
import 'package:lotti/pages/settings/measurables/measurable_details_page.dart';
import 'package:lotti/pages/settings/measurables/measurables_page.dart';
import 'package:lotti/pages/settings/settings_page.dart';
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
    ];
  }
}

class ConfigFlagsLocation extends BeamLocation<BeamState> {
  ConfigFlagsLocation(RouteInformation super.routeInformation);

  @override
  List<String> get pathPatterns => ['/config_flags/'];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) => [
        const BeamPage(
          key: ValueKey('settings'),
          title: 'Settings',
          type: BeamPageType.noTransition,
          child: FlagsPage(),
        ),
      ];
}
