import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/state/project_providers.dart';
import 'package:lotti/features/projects/ui/widgets/project_status_chip.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Modal content for selecting a project within a category.
class ProjectSelectionModalContent extends ConsumerWidget {
  const ProjectSelectionModalContent({
    required this.categoryId,
    required this.onProjectSelected,
    this.currentProjectId,
    super.key,
  });

  final String categoryId;
  final Future<void> Function(ProjectEntry? project) onProjectSelected;
  final String? currentProjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ProjectSelectionModalBody(
      projectsAsync: ref.watch(projectsForCategoryProvider(categoryId)),
      onProjectSelected: onProjectSelected,
      currentProjectId: currentProjectId,
    );
  }
}

/// Testable rendering core shared by every project-picker entry point.
class ProjectSelectionModalBody extends StatelessWidget {
  const ProjectSelectionModalBody({
    required this.projectsAsync,
    required this.onProjectSelected,
    this.currentProjectId,
    super.key,
  });

  final AsyncValue<List<ProjectEntry>> projectsAsync;
  final Future<void> Function(ProjectEntry? project) onProjectSelected;
  final String? currentProjectId;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final tokens = context.designTokens;

    return projectsAsync.when(
      loading: () => Padding(
        padding: EdgeInsets.all(tokens.spacing.step7),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Padding(
        padding: EdgeInsets.all(tokens.spacing.step6),
        child: Center(
          child: Text(
            context.messages.projectErrorLoadProjects,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: tokens.colors.alert.error.defaultColor,
            ),
          ),
        ),
      ),
      data: (List<ProjectEntry> projects) {
        final items = <_ProjectItem>[
          _ProjectItem.none(),
          ...projects.map(_ProjectItem.project),
        ];

        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final item in items)
                DesignSystemSelectionRow(
                  key: ValueKey(
                    item.isNone
                        ? 'project-none'
                        : 'project-${item.project!.meta.id}',
                  ),
                  title: item.isNone
                      ? messages.projectPickerUnassigned
                      : item.project!.data.title,
                  type: DesignSystemSelectionRowType.singleSelect,
                  selected: item.isNone
                      ? currentProjectId == null
                      : item.project!.meta.id == currentProjectId,
                  leading: Icon(
                    item.isNone
                        ? Icons.do_not_disturb_alt_outlined
                        : Icons.folder_outlined,
                    color: tokens.colors.text.mediumEmphasis,
                    size: tokens.spacing.step6,
                  ),
                  trailing: item.isNone
                      ? null
                      : ProjectStatusChip(status: item.project!.data.status),
                  onTap: () async {
                    await onProjectSelected(item.project);
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  },
                ),
              if (projects.isEmpty)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    tokens.spacing.step5,
                    tokens.spacing.step4,
                    tokens.spacing.step5,
                    tokens.spacing.step3,
                  ),
                  child: Text(
                    messages.projectNoProjects,
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ProjectItem {
  _ProjectItem.none() : project = null;
  _ProjectItem.project(this.project);

  final ProjectEntry? project;

  bool get isNone => project == null;
}
