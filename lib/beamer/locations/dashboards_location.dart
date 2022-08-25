import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/beamer/beamer_app.dart';
import 'package:lotti/pages/create/create_measurement_dialog.dart';
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
        '/dashboards/carousel/measure/:selectedId',
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
      if ((isUuid(dashboardId) || pathContains('carousel')) &&
          isUuid(selectedId))
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
            );
          },
          key: ValueKey('measure-$selectedId'),
          child: MeasurementDialog(selectedId: selectedId),
          onPopPage: (context, delegate, _, page) {
            dashboardsDelegate.beamBack();
            return false;
          },
        ),
    ];

    return pages;
  }
}
