import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/pages/dashboards/dashboard_page.dart';
import 'package:lotti/pages/dashboards/dashboards_list_page.dart';

class DashboardsLocation extends BeamLocation<BeamState> {
  DashboardsLocation(RouteInformation super.routeInformation);

  @override
  List<String> get pathPatterns => ['/dashboards/dashboard/:dashboardId'];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) => [
        const BeamPage(
          key: ValueKey('dashboards'),
          title: 'Dashboards',
          type: BeamPageType.noTransition,
          child: DashboardsListPage(),
        ),
        if (state.pathParameters.containsKey('dashboardId'))
          BeamPage(
            key: ValueKey('dashboards-${state.pathParameters['dashboardId']}'),
            child: DashboardPage(
              dashboardId: state.pathParameters['dashboardId']!,
              showBackIcon: false,
            ),
          ),
      ];
}
