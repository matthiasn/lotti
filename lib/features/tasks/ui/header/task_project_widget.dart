import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/projects/ui/widgets/project_selection_modal_content.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/modern_status_chip.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

typedef ProjectIdCallback = Future<bool> Function(String?);

class TaskProjectWidget extends StatelessWidget {
  const TaskProjectWidget({
    required this.project,
    required this.categoryId,
    required this.onSave,
    super.key,
  });

  final ProjectEntry? project;
  final String? categoryId;
  final ProjectIdCallback onSave;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final Color chipColor;
    final String chipLabel;

    if (project != null) {
      chipLabel = project!.data.title;
      chipColor = Theme.of(context).colorScheme.tertiary;
    } else {
      chipLabel = messages.projectPickerUnassigned;
      chipColor = Theme.of(context).colorScheme.outline;
    }

    void onTap() {
      if (categoryId == null) return;

      ModalUtils.showSinglePageModal<void>(
        context: context,
        title: messages.projectPickerLabel,
        padding: EdgeInsets.zero,
        builder: (BuildContext _) {
          return ProjectSelectionModalContent(
            categoryId: categoryId!,
            currentProjectId: project?.meta.id,
            onProjectSelected: (selectedProject) async {
              await onSave(selectedProject?.meta.id);
            },
          );
        },
      );
    }

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 5),
        child: ModernStatusChip(
          label: chipLabel,
          color: chipColor,
          icon: Icons.folder_outlined,
          borderWidth: AppTheme.statusIndicatorBorderWidth * 1.5,
        ),
      ),
    );
  }
}
