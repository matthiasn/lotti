import 'package:auto_route/auto_route.dart';
import 'package:lotti/pages/journal/entry_details_page.dart';
import 'package:lotti/pages/tasks_page.dart';

const AutoRoute taskRoutes = AutoRoute(
  path: 'tasks',
  name: 'TasksRouter',
  page: EmptyRouterPage,
  children: [
    AutoRoute(
      path: '',
      page: TasksPage,
    ),
    AutoRoute(
      path: ':entryId',
      page: EntryDetailPage,
    ),
  ],
);
