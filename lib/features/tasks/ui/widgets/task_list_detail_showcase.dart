import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/navigation/desktop_navigation_sidebar.dart';
import 'package:lotti/features/design_system/widgetbook/widgetbook_helpers.dart';
import 'package:lotti/features/tasks/ui/widgets/task_detail_pane.dart';
import 'package:lotti/features/tasks/ui/widgets/task_list_pane.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_filter_modal.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_shared_widgets.dart';
import 'package:lotti/features/tasks/widgetbook/task_list_detail_mock_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

class TaskListDetailShowcase extends ConsumerWidget {
  const TaskListDetailShowcase({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(taskListDetailShowcaseControllerProvider);
    final controller = ref.read(
      taskListDetailShowcaseControllerProvider.notifier,
    );
    final selected = state.selectedTask;
    final navDestinations = widgetbookNavigationDestinations(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: TaskShowcasePalette.page(context),
      ),
      child: SizedBox(
        width: 1440,
        height: 900,
        child: Row(
          children: [
            DesktopNavigationSidebar(
              destinations: [
                for (final dest in navDestinations)
                  DesktopSidebarDestination(
                    label: dest.label,
                    iconBuilder: ({required active}) => Icon(dest.icon),
                  ),
              ],
              activeIndex: 1, // Tasks (after My Daily)
              onDestinationSelected: (_) {},
              settingsDestination: DesktopSidebarDestination(
                label: context.messages.navTabTitleSettings,
                iconBuilder: ({required active}) =>
                    const Icon(Icons.settings_outlined),
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  TaskShowcaseDesktopTopBar(
                    title: context.messages.navTabTitleTasks,
                  ),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 540,
                          child: TaskListPane(
                            state: state,
                            onTaskSelected: controller.selectTask,
                            onSearchChanged: controller.updateSearchQuery,
                            onSearchCleared: () =>
                                controller.updateSearchQuery(''),
                            onFilterPressed: () => showTaskShowcaseFilterModal(
                              context: context,
                              initialState: state.filterState,
                              onApplied: controller.updateFilterState,
                              presentation:
                                  TaskShowcaseFilterPresentation.desktop,
                            ),
                          ),
                        ),
                        Expanded(
                          child: selected == null
                              ? const SizedBox.shrink()
                              : TaskDetailPane(record: selected),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
