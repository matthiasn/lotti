import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/labels/ui/widgets/label_chip.dart';
import 'package:lotti/features/labels/ui/widgets/label_selection_modal_utils.dart';
import 'package:lotti/features/tasks/state/task_progress_controller.dart';
import 'package:lotti/features/tasks/ui/compact_task_progress.dart';
import 'package:lotti/features/tasks/ui/header/estimated_time_widget.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/widgets/cards/subtle_action_chip.dart';

class TaskLabelsWrapper extends ConsumerWidget {
  const TaskLabelsWrapper({
    required this.taskId,
    super.key,
  });

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch label definitions stream to rebuild when label names/colors/visibility change.
    // Label assignment reactivity comes from entryControllerProvider below.
    ref.watch(labelsStreamProvider);
    final entryState = ref.watch(entryControllerProvider(id: taskId)).value;
    final task = entryState?.entry;

    if (task is! Task) {
      return const SizedBox.shrink();
    }

    final cache = getIt<EntitiesCacheService>();
    final assignedIds = task.meta.labelIds ?? <String>[];
    final showPrivate = cache.showPrivateEntries;
    final assignedLabels =
        assignedIds
            .map(cache.getLabelById)
            .whereType<LabelDefinition>()
            .where((label) => showPrivate || !(label.private ?? false))
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

    final estimate = task.data.estimate;
    final hasEstimate = estimate != null && estimate != Duration.zero;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row 3: Secondary Actions (Add Label + Estimate)
        Row(
          spacing: 8,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => _openSelector(context, ref, assignedIds),
              child: SubtleActionChip(
                label: context.messages.tasksAddLabelButton,
                icon: Icons.add,
              ),
            ),
            _EditableEstimateChip(
              taskId: taskId,
              hasEstimate: hasEstimate,
              estimate: estimate,
            ),
          ],
        ),
        // Row 4: Label chips (if any)
        if (assignedLabels.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: assignedLabels
                .map(
                  (label) => GestureDetector(
                    onLongPress: _hasDescription(label)
                        ? () => _showLabelDescription(context, label)
                        : null,
                    behavior: HitTestBehavior.opaque,
                    child: LabelChip(label: label),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  Future<void> _openSelector(
    BuildContext context,
    WidgetRef ref,
    List<String> assignedIds,
  ) async {
    final selectedCategoryId = ref
        .read(entryControllerProvider(id: taskId))
        .value
        ?.entry
        ?.meta
        .categoryId;

    await LabelSelectionModalUtils.openLabelSelector(
      context: context,
      entryId: taskId,
      initialLabelIds: assignedIds,
      categoryId: selectedCategoryId,
    );
  }

  bool _hasDescription(LabelDefinition label) =>
      label.description?.trim().isNotEmpty ?? false;

  Future<void> _showLabelDescription(
    BuildContext context,
    LabelDefinition label,
  ) async {
    final description = label.description?.trim();
    if (description == null || description.isEmpty) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label.name),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.messages.tasksLabelsDialogClose),
          ),
        ],
      ),
    );
  }
}

class _EditableEstimateChip extends ConsumerWidget {
  const _EditableEstimateChip({
    required this.taskId,
    required this.hasEstimate,
    this.estimate,
  });

  final String taskId;
  final bool hasEstimate;
  final Duration? estimate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: taskId);
    final notifier = ref.read(provider.notifier);

    Future<void> onTap() async {
      await showEstimatePicker(
        context: context,
        initialDuration: estimate ?? Duration.zero,
        onEstimateChanged: (newDuration) async {
          await notifier.save(estimate: newDuration);
        },
      );
    }

    // Show progress bar when there's an estimate, wrapped in subtle chip
    if (hasEstimate) {
      final progressState = ref
          .watch(taskProgressControllerProvider(id: taskId))
          .value;
      final isOvertime =
          progressState != null &&
          progressState.progress > progressState.estimate;

      return GestureDetector(
        onTap: onTap,
        child: SubtleActionChip(
          isUrgent: isOvertime,
          child: CompactTaskProgress(
            taskId: taskId,
            showTimeText: true,
          ),
        ),
      );
    }

    // Show "No estimate" chip when no estimate set
    return GestureDetector(
      onTap: onTap,
      child: SubtleActionChip(
        label: context.messages.taskNoEstimateLabel,
        icon: Icons.timer_outlined,
      ),
    );
  }
}
