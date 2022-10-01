import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/beamer/beamer_delegates.dart';
import 'package:lotti/pages/create/complete_habit_dialog.dart';
import 'package:lotti/pages/create/create_measurement_dialog.dart';
import 'package:lotti/pages/dashboards/dashboard_page.dart';
import 'package:lotti/pages/dashboards/dashboards_carousel_page.dart';
import 'package:lotti/pages/dashboards/dashboards_list_page.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/uuid.dart';

class DashboardsLocation extends BeamLocation<BeamState> {
  DashboardsLocation(RouteInformation super.routeInformation);

  @override
  List<String> get pathPatterns => [
        '/dashboards',
        '/dashboards/:dashboardId',
        '/dashboards/carousel',
        '/dashboards/carousel/measure/:measurableId',
        '/dashboards/:dashboardId/measure/:measurableId',
        '/dashboards/carousel/complete_habit/:habitId',
        '/dashboards/:dashboardId/complete_habit/:habitId',
      ];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) {
    bool pathContains(String s) => state.uri.path.contains(s);
    final dashboardId = state.pathParameters['dashboardId'];
    final measurableId = state.pathParameters['measurableId'];
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
      if (pathContains('carousel'))
        const BeamPage(
          key: ValueKey('dashboards-carousel'),
          child: DashboardCarouselPage(),
        ),
      if ((isUuid(dashboardId) || pathContains('carousel')) &&
          measurableId != null &&
          isUuid(measurableId))
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
          key: ValueKey('measure-$measurableId'),
          child: MeasurementDialog(measurableId: measurableId),
          onPopPage: (context, delegate, _, page) {
            dashboardsBeamerDelegate.beamBack();
            return false;
          },
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
          key: ValueKey('measure-$measurableId'),
          child: HabitDialog(habitId: habitId),
          onPopPage: (context, delegate, _, page) {
            dashboardsBeamerDelegate.beamBack();
            return false;
          },
        ),
    ];

    return pages;
  }
}
