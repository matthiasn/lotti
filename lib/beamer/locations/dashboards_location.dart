import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/pages/create/create_measurement_page.dart';
import 'package:lotti/pages/dashboards/dashboard_page.dart';
import 'package:lotti/pages/dashboards/dashboards_carousel_page.dart';
import 'package:lotti/pages/dashboards/dashboards_list_page.dart';
import 'package:lotti/utils/uuid.dart';

class DashboardsLocation extends BeamLocation<BeamState> {
  DashboardsLocation(RouteInformation super.routeInformation);

  @override
  List<String> get pathPatterns => [
        '/dashboards',
        '/dashboards/:dashboardId',
        '/dashboards/carousel',
        '/dashboards/:dashboardId/measure/:selectedId',
      ];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) {
    bool pathContains(String s) => state.uri.path.contains(s);
    final dashboardId = state.pathParameters['dashboardId'];
    final selectedId = state.pathParameters['selectedId'];

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
      if (pathContains('carousel'))
        const BeamPage(
          key: ValueKey('dashboards-carousel'),
          child: DashboardCarouselPage(),
        ),
      if (isUuid(dashboardId) && isUuid(selectedId))
        BeamPage(
          key: ValueKey('dashboards-$dashboardId-measure-$selectedId'),
          child: CreateMeasurementPage(selectedId: selectedId),
        ),
    ];

    debugPrint('$pages');
    return pages;
  }
}
