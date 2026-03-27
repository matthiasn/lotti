import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_ai_assistant_button.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_modal.dart';
import 'package:lotti/features/projects/ui/widgets/project_detail_pane.dart';
import 'package:lotti/features/projects/ui/widgets/project_list_pane.dart';
import 'package:lotti/features/projects/ui/widgets/projects_filter_modal.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_palette.dart';
import 'package:lotti/features/projects/ui/widgets/sidebar.dart';
import 'package:lotti/features/projects/widgetbook/project_list_detail_mock_controller.dart';
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
    final closeButtonLabel = MaterialLocalizations.of(context).closeButtonLabel;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ShowcasePalette.page(context),
      ),
      child: SizedBox(
        width: 1440,
        height: 900,
        child: Row(
          children: [
            Sidebar(
              onAiAssistantPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: Text(dialogContext.messages.aiAssistantTitle),
                    content: SizedBox(
                      width: 160,
                      height: 120,
                      child: Center(
                        child: DesignSystemAiAssistantButton(
                          assetName:
                              'assets/design_system/ai_assistant_variant_1.png',
                          semanticLabel: dialogContext
                              .messages
                              .designSystemNavigationAiAssistantSectionTitle,
                        ),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: Text(closeButtonLabel),
                      ),
                    ],
                  ),
                );
              },
            ),
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
                            onFilterPressed: () => showProjectsFilterModal(
                              context: context,
                              initialFilter: state.filter,
                              categories: state.data.categories,
                              onApplied: controller.updateFilter,
                              presentation: DesignSystemFilterPresentation.desktop,
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
