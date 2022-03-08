import 'package:auto_route/auto_route.dart';
import 'package:lotti/pages/flagged_entries_page.dart';
import 'package:lotti/pages/home_page.dart';
import 'package:lotti/pages/journal_page.dart';
import 'package:lotti/pages/my_day.dart';
import 'package:lotti/pages/tasks_page.dart';
import 'package:lotti/routes/dashboard_routes.dart';
import 'package:lotti/routes/settings_routes.dart';

@MaterialAutoRouter(
  replaceInRouteName: 'Page,Route',
  routes: [
    AutoRoute(
      path: '/',
      page: HomePage,
      children: [
        AutoRoute(
          path: 'journal',
          name: 'JournalRouter',
          page: EmptyRouterPage,
          children: [
            AutoRoute(
              path: '',
              page: JournalPage,
            ),
          ],
        ),
        AutoRoute(
          path: 'flagged',
          name: 'FlaggedRouter',
          page: EmptyRouterPage,
          children: [
            AutoRoute(
              path: '',
              page: FlaggedEntriesPage,
            ),
            AutoRoute(
              path: ':userId',
              page: EmptyRouterPage,
            ),
          ],
        ),
        AutoRoute(
          path: 'tasks',
          name: 'TasksRouter',
          page: EmptyRouterPage,
          children: [
            AutoRoute(
              path: '',
              page: TasksPage,
            ),
            AutoRoute(
              path: ':userId',
              page: EmptyRouterPage,
            ),
          ],
        ),
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
