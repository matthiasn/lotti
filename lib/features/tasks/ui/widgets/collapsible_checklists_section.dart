import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/tasks/state/checklist_controller.dart';
import 'package:lotti/features/tasks/ui/checklists/checklists_widget.dart';
import 'package:lotti/features/tasks/ui/widgets/collapsible_task_section.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class CollapsibleChecklistsSection extends ConsumerWidget {
  const CollapsibleChecklistsSection({
    required this.task,
    required this.scrollController,
    super.key,
  });

  final Task task;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checklistIds = task.data.checklistIds ?? [];

    if (checklistIds.isEmpty) {
      return const SizedBox.shrink();
    }

    // Watch completion rates for all checklists
    final completionData = <String, double>{};
    var totalItems = 0;
    var completedItems = 0;

    for (final checklistId in checklistIds) {
      final completion = ref
          .watch(
            checklistCompletionControllerProvider(
              id: checklistId,
              taskId: task.id,
            ),
          )
          .value;

      if (completion != null) {
        totalItems += completion.totalCount;
        completedItems += completion.completedCount;
        completionData[checklistId] = completion.completedCount /
            (completion.totalCount > 0 ? completion.totalCount : 1);
      }
    }

    final overallCompletion =
        totalItems > 0 ? completedItems / totalItems : 0.0;

    // Build preview content
    final previewLines = <String>[];
    if (checklistIds.length == 1) {
      previewLines.add(
        '${(overallCompletion * 100).toInt()}% complete '
        '($completedItems/$totalItems items)',
      );
    } else {
      previewLines.add(
        '${checklistIds.length} checklists, '
        '${(overallCompletion * 100).toInt()}% complete',
      );
      if (totalItems > 0) {
        previewLines.add('$completedItems of $totalItems items completed');
      }
    }

    return CollapsibleTaskSection(
      title: context.messages.checklistsTitle,
      icon: MdiIcons.checkboxMultipleOutline,
      initiallyExpanded: false,
      collapsedChild: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          previewLines.join('\n'),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      expandedChild: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: ChecklistsWidget(
          entryId: task.id,
          task: task,
        ),
      ),
    );
  }
}
