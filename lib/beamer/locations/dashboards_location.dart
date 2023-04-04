import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/beamer/beamer_delegates.dart';
import 'package:lotti/pages/create/complete_habit_dialog.dart';
import 'package:lotti/pages/dashboards/dashboard_page.dart';
import 'package:lotti/pages/dashboards/dashboards_list_page.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/uuid.dart';

class DashboardsLocation extends BeamLocation<BeamState> {
  DashboardsLocation(RouteInformation super.routeInformation);

  @override
  List<String> get pathPatterns => [
        '/dashboards',
        '/dashboards/:dashboardId',
        '/dashboards/:dashboardId/complete_habit/:habitId',
      ];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) {
    bool pathContains(String s) => state.uri.path.contains(s);
    final dashboardId = state.pathParameters['dashboardId'];
    final habitId = state.pathParameters['habitId'];

    final pages = [
      const BeamPage(
        key: ValueKey('dashboards'),
        title: 'Dashboards',
        type: BeamPageType.noTransition,
        child: DashboardsListPage(),
      ),
      if (isUuid(dashboardId))
        BeamPage(
          key: ValueKey('dashboards-$dashboardId'),
          child: DashboardPage(dashboardId: dashboardId!),
        ),
      if ((isUuid(dashboardId) || pathContains('carousel')) &&
          habitId != null &&
          isUuid(habitId))
        BeamPage(
          routeBuilder: (
            BuildContext context,
            RouteSettings settings,
            Widget child,
          ) {
            return DialogRoute<void>(
              context: context,
              builder: (context) => child,
              settings: settings,
              barrierColor: styleConfig().negspace.withOpacity(0.54),
            );
          },
          key: ValueKey('dashboards-habit-$habitId'),
          child: HabitDialog(
            habitId: habitId,
            beamerDelegate: dashboardsBeamerDelegate,
          ),
          onPopPage: (context, delegate, _, page) {
            dashboardsBeamerDelegate.beamBack();
            return false;
          },
        ),
    ];

    return pages;
  }
}
