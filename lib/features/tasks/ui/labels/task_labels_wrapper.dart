import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/labels/ui/widgets/label_chip.dart';
import 'package:lotti/features/tasks/ui/labels/task_labels_sheet.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';

class TaskLabelsWrapper extends ConsumerWidget {
  const TaskLabelsWrapper({
    required this.taskId,
    super.key,
  });

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entryState = ref.watch(entryControllerProvider(id: taskId)).value;
    final task = entryState?.entry;

    if (task is! Task) {
      return const SizedBox.shrink();
    }

    final cache = getIt<EntitiesCacheService>();
    final assignedIds = task.meta.labelIds ?? <String>[];
    final assignedLabels = assignedIds
        .map(cache.getLabelById)
        .whereType<LabelDefinition>()
        .toList()
      ..sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

    final hasLabels =
        assignedLabels.isNotEmpty || cache.sortedLabels.isNotEmpty;

    if (!hasLabels) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Labels',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Edit labels',
                onPressed: () => _openSelector(context, ref, assignedIds),
                icon: const Icon(Icons.edit_outlined, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (assignedLabels.isEmpty)
            Text(
              'No labels',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.color
                        ?.withValues(alpha: 0.6),
                  ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: assignedLabels
                  .map((label) => LabelChip(label: label))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Future<void> _openSelector(
    BuildContext context,
    WidgetRef ref,
    List<String> assignedIds,
  ) async {
    await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => TaskLabelsSheet(
        taskId: taskId,
        initialLabelIds: assignedIds,
      ),
    );
    // Result handled inside sheet; we only show a snackbar if labels updated
    // No-op: sheet handles messaging when persistence fails.
  }
}
