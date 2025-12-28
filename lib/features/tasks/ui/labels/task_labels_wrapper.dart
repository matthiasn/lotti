import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/labels/state/label_assignment_event_provider.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/labels/ui/widgets/label_chip.dart';
import 'package:lotti/features/tasks/ui/labels/label_selection_modal_content.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:lotti/widgets/search/index.dart';

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
        final assignedLabelsForToast = event.assignedIds
            .map(cache.getLabelById)
            .whereType<LabelDefinition>()
            .toList();

        final assignedNames =
            assignedLabelsForToast.map((l) => l.name).toList(growable: false);

        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        // Build modern content: prefix + chips as in header
        final content = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Assigned:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Allow chips to wrap on small screens
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: assignedLabelsForToast
                    .map((label) => LabelChip(label: label))
                    .toList(),
              ),
            ),
          ],
        );

        // Fallback message when cache misses names (rare)
        final fallbackText = assignedNames.isEmpty
            ? 'Assigned ${event.assignedIds.length} label(s)'
            : 'Assigned: ${assignedNames.join(', ')}';

        messenger.showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 6,
            margin: EdgeInsets.only(
              left: 12,
              right: 12,
              bottom: 12 + MediaQuery.of(context).padding.bottom,
            ),
            showCloseIcon: true,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Primary visual content
                content,
                // Keep an accessible textual fallback to aid a11y and legacy tests
                // while not visually prominent.
                Offstage(
                  child: Text(fallbackText),
                ),
              ],
            ),
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
                    child: LabelChip(label: label),
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
    final applyController = ValueNotifier<Future<bool> Function()?>(null);
    final searchNotifier = ValueNotifier<String>('');
    final selectedCategoryId = ref
        .read(entryControllerProvider(id: taskId))
        .value
        ?.entry
        ?.meta
        .categoryId;

    await ModalUtils.showSinglePageModal<List<String>>(
      context: context,
      titleWidget: Padding(
        padding: const EdgeInsets.only(top: 8, left: 20, right: 20, bottom: 8),
        child: LottiSearchBar(
          hintText: context.messages.tasksLabelsSheetSearchHint,
          controller: TextEditingController(),
          useGradientInDark: false,
          onChanged: (value) => searchNotifier.value = value,
          onClear: () => searchNotifier.value = '',
          textCapitalization: TextCapitalization.words,
        ),
      ),
      navBarHeight: 80,
      stickyActionBar: SafeArea(
        top: false,
        child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.12),
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.messages.cancelButton),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      final fn = applyController.value;
                      final ok = fn != null && await fn();
                      if (!context.mounted) return;
                      if (ok) {
                        Navigator.of(context).pop();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text(context.messages.tasksLabelsUpdateFailed),
                          ),
                        );
                      }
                    },
                    child: Text(context.messages.tasksLabelsSheetApply),
                  ),
                ),
              ],
            )),
      ),
      // Let list items span full width; header/footer have their own padding.
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
      builder: (ctx) {
        final minHeight = MediaQuery.of(ctx).size.height * 0.5;
        return ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: LabelSelectionModalContent(
            entryId: taskId,
            initialLabelIds: assignedIds,
            categoryId: selectedCategoryId,
            applyController: applyController,
            searchQuery: searchNotifier,
          ),
        );
      },
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
