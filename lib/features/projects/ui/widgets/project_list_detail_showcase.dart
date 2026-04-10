import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/navigation/desktop_navigation_sidebar.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_modal.dart';
import 'package:lotti/features/design_system/widgetbook/widgetbook_helpers.dart';
import 'package:lotti/features/projects/ui/widgets/project_detail_pane.dart';
import 'package:lotti/features/projects/ui/widgets/project_list_pane.dart';
import 'package:lotti/features/projects/ui/widgets/projects_filter_modal.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_palette.dart';
import 'package:lotti/features/projects/widgetbook/project_list_detail_mock_controller.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_shared_widgets.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Desktop list/detail showcase composed from production widgets fed with mock
/// data.
class ProjectListDetailShowcase extends ConsumerWidget {
  const ProjectListDetailShowcase({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(projectListDetailShowcaseControllerProvider);
    final controller = ref.read(
      projectListDetailShowcaseControllerProvider.notifier,
    );
    final selected = state.selectedProject;
    final navDestinations = widgetbookNavigationDestinations(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ShowcasePalette.page(context),
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
              activeIndex: 2, // Projects
              onDestinationSelected: (_) {},
            ),
            Expanded(
              child: Column(
                children: [
                  TaskShowcaseDesktopTopBar(
                    title: context.messages.designSystemBreadcrumbProjectsLabel,
                  ),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 402,
                          child: ProjectListPane(
                            state: state,
                            onProjectSelected: controller.selectProject,
                            onSearchChanged: controller.updateSearchQuery,
                            onSearchCleared: () =>
                                controller.updateSearchQuery(''),
                            onFilterPressed: () => showProjectsFilterModal(
                              context: context,
                              initialFilter: state.filter,
                              categories: state.data.categories,
                              onApplied: controller.updateFilter,
                              presentation:
                                  DesignSystemFilterPresentation.desktop,
                            ),
                          ),
                        ),
                        Expanded(
                          child: selected == null
                              ? const SizedBox.shrink()
                              : ProjectDetailPane(
                                  record: selected,
                                  currentTime: state.data.currentTime,
                                ),
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
