import 'package:flutter/widgets.dart';
import 'package:lotti/features/design_system/components/navigation/desktop_detail_empty_state.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/tasks/ui/pages/task_details_page.dart';
import 'package:lotti/features/tasks/ui/pages/tasks_tab_page.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';

class TasksRootPage extends StatelessWidget {
  const TasksRootPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (!isDesktopLayout(context)) {
      return const TasksTabPage();
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: TaskShowcasePalette.page(context),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 540,
            child: TasksTabPage(),
          ),
          Expanded(
            child: ValueListenableBuilder<String?>(
              valueListenable: getIt<NavService>().desktopSelectedTaskId,
              builder: (context, selectedTaskId, _) {
                if (selectedTaskId != null) {
                  return TaskDetailsPage(taskId: selectedTaskId);
                }
                return DesktopDetailEmptyState(
                  message: context.messages.desktopEmptyStateSelectTask,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
