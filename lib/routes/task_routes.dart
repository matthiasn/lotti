import 'package:auto_route/auto_route.dart';
import 'package:lotti/pages/create/create_task_page.dart';
import 'package:lotti/pages/journal/entry_details_page.dart';
import 'package:lotti/pages/tasks/tasks_page.dart';

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
      path: ':itemId',
      page: EntryDetailPage,
    ),
    AutoRoute(
      path: 'create/:linkedId',
      page: CreateTaskPage,
    ),
  ],
);
