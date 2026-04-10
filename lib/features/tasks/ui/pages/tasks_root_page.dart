import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/navigation/desktop_detail_empty_state.dart';
import 'package:lotti/features/design_system/components/navigation/resizable_divider.dart';
import 'package:lotti/features/design_system/state/pane_width_controller.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/tasks/ui/pages/tasks_tab_page.dart';
import 'package:lotti/features/tasks/ui/widgets/desktop_task_detail_view.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';

class TasksRootPage extends ConsumerWidget {
  const TasksRootPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isDesktopLayout(context)) {
      return const TasksTabPage();
    }

    final paneWidths = ref.watch(paneWidthControllerProvider);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: TaskShowcasePalette.page(context),
      ),
      child: Row(
        children: [
          SizedBox(
            width: paneWidths.listPaneWidth,
            child: const TasksTabPage(),
          ),
          ResizableDivider(
            onDrag: (delta) => ref
                .read(paneWidthControllerProvider.notifier)
                .updateListPaneWidth(delta),
          ),
          Expanded(
            child: ValueListenableBuilder<String?>(
              valueListenable: getIt<NavService>().desktopSelectedTaskId,
              builder: (context, selectedTaskId, _) {
                if (selectedTaskId != null) {
                  return DesktopTaskDetailView(taskId: selectedTaskId);
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
