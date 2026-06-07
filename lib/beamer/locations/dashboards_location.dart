import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/dashboards/ui/pages/dashboard_page.dart';
import 'package:lotti/features/dashboards/ui/pages/dashboards_list_page.dart';
import 'package:lotti/features/insights/ui/time_analysis_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/uuid.dart';

/// Reserved `:dashboardId` segment that selects the Time Analysis
/// dashboard instead of a dashboard detail. Dashboard ids are UUIDs, so
/// the segment can never collide with a real id.
const String timeAnalysisPathSegment = 'time';

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
    final isTimeAnalysis = dashboardId == timeAnalysisPathSegment;
    final navService = getIt<NavService>();
    final isDesktop = navService.isDesktopMode;

    if (isDesktop) {
      // Single writer for the desktop pane selection: this location maps
      // the URL onto the two notifiers, keeping them mutually exclusive.
      navService
        ..desktopShowTimeAnalysis.value = isTimeAnalysis
        ..desktopSelectedDashboardId.value =
            !isTimeAnalysis && isUuid(dashboardId) ? dashboardId : null;
    }

    return [
      const BeamPage(
        key: ValueKey('dashboards'),
        title: 'Dashboards',
        child: DashboardsListPage(),
      ),
      // The Time Analysis entry point is desktop-only, but a deep link on a
      // narrow window still renders the page rather than dead-ending.
      if (!isDesktop && isTimeAnalysis)
        const BeamPage(
          key: ValueKey('dashboards-time'),
          child: TimeAnalysisPage(),
        ),
      if (!isDesktop && !isTimeAnalysis && isUuid(dashboardId))
        BeamPage(
          key: ValueKey('dashboards-$dashboardId'),
          child: DashboardPage(dashboardId: dashboardId!),
        ),
    ];
  }
}
