import 'package:auto_route/auto_route.dart';
import 'package:lotti/pages/home_page.dart';
import 'package:lotti/routes/dashboard_routes.dart';
import 'package:lotti/routes/journal_routes.dart';
import 'package:lotti/routes/settings_routes.dart';
import 'package:lotti/routes/task_routes.dart';
import 'package:lotti/routes/ask_me_routes.dart';

@MaterialAutoRouter(
  replaceInRouteName: 'Page,Route',
  routes: [
    AutoRoute(
      path: '/',
      page: HomePage,
      children: [
        journalRoutes,
        taskRoutes,
        askMeRoutes,
        dashboardRoutes,
        settingsRoutes,
      ],
    ),
  ],
)
class $AppRouter {}
