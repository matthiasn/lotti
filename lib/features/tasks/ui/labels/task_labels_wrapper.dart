import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/labels/state/label_assignment_event_provider.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/labels/ui/widgets/label_chip.dart';
import 'package:lotti/features/tasks/ui/labels/task_labels_sheet.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/logging_service.dart';

class TaskLabelsWrapper extends ConsumerWidget {
  const TaskLabelsWrapper({
    required this.taskId,
    super.key,
  });

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listen for AI label assignment events to show toast with Undo
    ref
      ..listen(labelAssignmentEventsProvider, (previous, next) async {
        final event = next.valueOrNull;
        if (event == null || event.taskId != taskId) return;
        if (!context.mounted) return;
        final cache = getIt<EntitiesCacheService>();
        final messenger = ScaffoldMessenger.of(context);
        final assignedNames = event.assignedIds
            .map(cache.getLabelById)
            .whereType<LabelDefinition>()
            .map((l) => l.name)
            .toList();
        final message = assignedNames.isEmpty
            ? 'Assigned ${event.assignedIds.length} label(s)'
            : 'Assigned: ${assignedNames.join(', ')}';
        messenger.showSnackBar(
          SnackBar(
            content: Text(message),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                final repo = ref.read(labelsRepositoryProvider);
                for (final id in event.assignedIds) {
                  await repo.removeLabel(journalEntityId: taskId, labelId: id);
                }
                // Log undo metrics
                getIt<LoggingService>().captureEvent(
                  'undo_triggered',
                  domain: 'labels_ai_assignment',
                  subDomain: 'ui',
                );
              },
            ),
          ),
        );
      })
      // Watch label stream to rebuild when labels change
      ..watch(labelsStreamProvider);
    final entryState = ref.watch(entryControllerProvider(id: taskId)).value;
    final task = entryState?.entry;

    if (task is! Task) {
      return const SizedBox.shrink();
    }

    final cache = getIt<EntitiesCacheService>();
    final assignedIds = task.meta.labelIds ?? <String>[];
    final showPrivate = cache.showPrivateEntries;
    final assignedLabels = assignedIds
        .map(cache.getLabelById)
        .whereType<LabelDefinition>()
        .where((label) => showPrivate || !(label.private ?? false))
        .toList()
      ..sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

    // Respect privacy filtering when deciding if the wrapper should render.
    // Apply the same privacy rule to cache-backed labels using the local flag.
    final filteredCacheLabels = cache.sortedLabels
        .where((label) => showPrivate || !(label.private ?? false))
        .toList();

    final hasLabels =
        assignedLabels.isNotEmpty || filteredCacheLabels.isNotEmpty;

    if (!hasLabels) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final headerStyle = theme.textTheme.titleSmall?.copyWith(
      color: colorScheme.outline,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.messages.tasksLabelsHeaderTitle,
              style: headerStyle,
            ),
            IconButton(
              tooltip: context.messages.tasksLabelsHeaderEditTooltip,
              onPressed: () => _openSelector(context, ref, assignedIds),
              icon: Icon(
                Icons.edit_outlined,
                size: 18,
                color: colorScheme.outline,
              ),
            ),
          ],
        ),
        if (assignedLabels.isEmpty)
          Text(
            context.messages.tasksLabelsNoLabels,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
            ),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: assignedLabels
                .map(
                  (label) => GestureDetector(
                    onLongPress: _hasDescription(label)
                        ? () => _showLabelDescription(context, label)
                        : null,
                    behavior: HitTestBehavior.opaque,
                    child: LabelChip(label: label, showDot: false),
                  ),
                )
                .toList(),
          ),
      ],
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
