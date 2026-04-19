import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/widgetbook/widgetbook_helpers.dart';
import 'package:lotti/features/tasks/ui/widgets/task_list_detail_showcase.dart';
import 'package:lotti/features/tasks/ui/widgets/task_mobile_list_detail_showcase.dart';
import 'package:lotti/features/tasks/widgetbook/desktop_task_header_widgetbook.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookFolder buildTasksWidgetbookFolder() {
  return WidgetbookFolder(
    name: 'Tasks',
    children: [
      buildTaskListDetailWidgetbookComponent(),
      buildDesktopTaskHeaderWidgetbookComponent(),
    ],
  );
}

WidgetbookComponent buildTaskListDetailWidgetbookComponent() {
  return WidgetbookComponent(
    name: 'Task list & detail',
    useCases: [
      WidgetbookUseCase(
        name: 'Desktop',
        builder: (context) => const _TaskListDetailOverviewPage(),
      ),
      WidgetbookUseCase(
        name: 'Mobile',
        builder: (context) => const _TaskListDetailMobilePage(),
      ),
    ],
  );
}

class _TaskListDetailOverviewPage extends StatelessWidget {
  const _TaskListDetailOverviewPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: const [
          WidgetbookViewport(
            width: 1440,
            child: ProviderScope(
              child: TaskListDetailShowcase(),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskListDetailMobilePage extends StatelessWidget {
  const _TaskListDetailMobilePage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: const [
          WidgetbookViewport(
            width: 860,
            child: ProviderScope(
              child: Center(
                child: TaskMobileListDetailShowcase(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
