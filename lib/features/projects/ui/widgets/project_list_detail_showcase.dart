import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/projects/ui/widgets/project_detail_pane.dart';
import 'package:lotti/features/projects/ui/widgets/project_list_pane.dart';
import 'package:lotti/features/projects/ui/widgets/shared_widgets.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_palette.dart';
import 'package:lotti/features/projects/ui/widgets/sidebar.dart';
import 'package:lotti/features/projects/widgetbook/project_list_detail_mock_controller.dart';

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

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ShowcasePalette.page(context),
      ),
      child: SizedBox(
        width: 1440,
        height: 900,
        child: Row(
          children: [
            const Sidebar(),
            Expanded(
              child: Column(
                children: [
                  const MainTopBar(),
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
                          ),
                        ),
                        Expanded(
                          child: selected == null
                              ? const NoResultsPane()
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
