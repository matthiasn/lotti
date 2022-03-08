import 'package:auto_route/auto_route.dart';
import 'package:lotti/pages/home_page.dart';
import 'package:lotti/pages/my_day.dart';
import 'package:lotti/routes/dashboard_routes.dart';
import 'package:lotti/routes/flagged_routes.dart';
import 'package:lotti/routes/journal_routes.dart';
import 'package:lotti/routes/settings_routes.dart';
import 'package:lotti/routes/task_routes.dart';

@MaterialAutoRouter(
  replaceInRouteName: 'Page,Route',
  routes: [
    AutoRoute(
      path: '/',
      page: HomePage,
      children: [
        journalRoutes,
        flaggedRoutes,
        taskRoutes,
        dashboardRoutes,
        AutoRoute(
          path: 'my_day',
          name: 'MyDayRouter',
          page: EmptyRouterPage,
          children: [
            AutoRoute(
              path: '',
              page: MyDayPage,
            ),
          ],
        ),
        settingsRoutes,
      ],
    ),
  ],
)
class $AppRouter {}
