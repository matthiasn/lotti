import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/pages/dashboards/dashboard_page.dart';
import 'package:lotti/pages/dashboards/dashboards_list_page.dart';
import 'package:lotti/utils/uuid.dart';

class DashboardsLocation extends BeamLocation<BeamState> {
  DashboardsLocation(RouteInformation super.routeInformation);

  @override
  List<String> get pathPatterns => [
        '/dashboards',
        '/dashboards/:dashboardId',
      ];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) {
    final dashboardId = state.pathParameters['dashboardId'];

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
    ];

    return pages;
  }
}
