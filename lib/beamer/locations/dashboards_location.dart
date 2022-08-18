import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/pages/create/create_measurement_page.dart';
import 'package:lotti/pages/dashboards/dashboard_page.dart';
import 'package:lotti/pages/dashboards/dashboards_carousel_page.dart';
import 'package:lotti/pages/dashboards/dashboards_list_page.dart';

class DashboardsLocation extends BeamLocation<BeamState> {
  DashboardsLocation(RouteInformation super.routeInformation);

  @override
  List<String> get pathPatterns => [
        '/dashboards/dashboard/:dashboardId',
        '/dashboards/carousel',
        '/dashboards/dashboard/:dashboardId/measure/:selectedId',
      ];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) {
    bool pathContains(String s) => state.uri.path.contains(s);
    bool pathContainsKey(String s) => state.pathParameters.containsKey(s);

    return [
      const BeamPage(
        key: ValueKey('dashboards'),
        title: 'Dashboards',
        type: BeamPageType.noTransition,
        child: DashboardsListPage(),
      ),
      if (pathContainsKey('dashboardId'))
        BeamPage(
          key: ValueKey('dashboards-${state.pathParameters['dashboardId']}'),
          child: DashboardPage(
            dashboardId: state.pathParameters['dashboardId']!,
            showBackIcon: false,
          ),
        ),
      if (pathContains('carousel'))
        const BeamPage(
          key: ValueKey('dashboards-carousel'),
          child: DashboardCarouselPage(),
        ),
      if (pathContainsKey('selectedId'))
        BeamPage(
          key: ValueKey(
            'dashboards-${state.pathParameters['dashboardId']}-measure',
          ),
          child: CreateMeasurementWithTypePage(
            selectedId: state.pathParameters['selectedId'],
          ),
        ),
    ];
  }
}
