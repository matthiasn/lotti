import 'package:auto_route/auto_route.dart';
import 'package:lotti/pages/dashboards/dashboard_page.dart';
import 'package:lotti/pages/dashboards/dashboards_list_page.dart';

const AutoRoute dashboardRoutes = AutoRoute(
  path: 'dashboards',
  name: 'DashboardsRouter',
  page: EmptyRouterPage,
  children: [
    AutoRoute(
      path: '',
      page: DashboardsListPage,
    ),
    AutoRoute(
      path: ':dashboardId',
      page: DashboardPage,
    ),
  ],
);
