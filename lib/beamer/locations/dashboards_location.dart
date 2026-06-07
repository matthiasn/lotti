import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/dashboards/ui/pages/dashboard_page.dart';
import 'package:lotti/features/dashboards/ui/pages/dashboards_list_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
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
    final navService = getIt<NavService>();
    final isDesktop = navService.isDesktopMode;

    if (isDesktop) {
      navService.desktopSelectedDashboardId.value = isUuid(dashboardId)
          ? dashboardId
          : null;
    }

    return [
      const BeamPage(
        key: ValueKey('dashboards'),
        title: 'Dashboards',
        child: DashboardsListPage(),
      ),
      if (!isDesktop && isUuid(dashboardId))
        BeamPage(
          key: ValueKey('dashboards-$dashboardId'),
          child: DashboardPage(dashboardId: dashboardId!),
        ),
    ];
  }
}
