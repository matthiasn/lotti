import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/tasks/state/checklist_controller.dart';
import 'package:lotti/features/tasks/state/checklist_item_controller.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_item_with_suggestion_widget.dart';
import 'package:lotti/features/tasks/ui/checklists/drag_utils.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/misc/countdown_snackbar_content.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

/// Duration for the archive SnackBar countdown.
const kChecklistArchiveDuration = Duration(seconds: 2);

/// Duration for the delete SnackBar countdown (longer, since delete is harder
/// to reverse without undo).
const kChecklistDeleteDuration = Duration(seconds: 5);

class ChecklistItemWrapper extends ConsumerWidget {
  const ChecklistItemWrapper(
    this.itemId, {
    required this.checklistId,
    required this.taskId,
    this.hideIfChecked = false,
    this.index = 0,
    super.key,
  });

  final String itemId;
  final String taskId;
  final String checklistId;
  final bool hideIfChecked;

  /// Index of this item in the list, used for ReorderableDragStartListener.
  final int index;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final provider = checklistItemControllerProvider((
      id: itemId,
      taskId: taskId,
    ));
    final item = ref.watch(provider);

    return item.map(
      data: (data) {
        final item = data.value;
        if (item == null || item.isDeleted) {
          return const SizedBox.shrink();
        }

        // Capture notifiers and messenger before widget disposal
        final itemNotifier = ref.read(provider.notifier);
        final checklistNotifier = ref.read(checklistControllerProvider((
          id: checklistId,
          taskId: taskId,
        )).notifier);
        final messenger = ScaffoldMessenger.of(context);

        // Wrap in DropRegion to handle drops on this specific item
        // This enables both within-list reordering and cross-checklist moves
        final child = DropRegion(
          formats: Formats.standardFormats,
          onDropOver: (event) => DropOperation.move,
          onPerformDrop: (event) => handleChecklistItemDrop(
            event: event,
            checklistNotifier: checklistNotifier,
            targetIndex: index,
            targetItemId: itemId,
          ),
          child: DragItemWidget(
            dragItemProvider: (request) async => createChecklistItemDragItem(
              itemId: item.id,
              checklistId: checklistId,
              title: item.data.title,
            ),
            allowedOperations: () => [DropOperation.move],
            dragBuilder: buildDragDecorator,
            child: DraggableWidget(
              child: Dismissible(
                key: Key(item.id),
                dismissThresholds: const {
                  DismissDirection.endToStart: 0.25,
                  DismissDirection.startToEnd: 0.25,
                },
                onDismissed: (_) async {
                  final deletedMessage = context.messages.checklistItemDeleted;
                  final undoLabel = context.messages.checklistItemArchiveUndo;

                  // Unlink visually but delay the actual delete so undo
                  // can simply re-link without needing to restore data.
                  await checklistNotifier.unlinkItem(itemId);

                  final deleteTimer = Timer(
                    kChecklistDeleteDuration,
                    () async {
                      await itemNotifier.delete();
                    },
                  );

                  showCountdownSnackBar(
                    messenger,
                    message: deletedMessage,
                    duration: kChecklistDeleteDuration,
                    actionLabel: undoLabel,
                    onAction: () {
                      deleteTimer.cancel();
                      checklistNotifier.relinkItem(itemId);
                      messenger.hideCurrentSnackBar();
                    },
                  );
                },
                // Archive background (swipe right)
                background: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ColoredBox(
                      color: Colors.amber.shade700,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Icon(
                            item.data.isArchived
                                ? Icons.unarchive
                                : Icons.archive,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Delete background (swipe left)
                secondaryBackground: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ColoredBox(
                      color: context.colorScheme.error,
                      child: const Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(
                            Icons.delete,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                confirmDismiss: (direction) async {
                  if (direction == DismissDirection.startToEnd) {
                    // Toggle archive state
                    if (item.data.isArchived) {
                      itemNotifier.unarchive();
                    } else {
                      itemNotifier.archive();
                      showCountdownSnackBar(
                        messenger,
                        message: context.messages.checklistItemArchived,
                        duration: kChecklistArchiveDuration,
                        actionLabel: context.messages.checklistItemArchiveUndo,
                        onAction: () {
                          itemNotifier.unarchive();
                          messenger.hideCurrentSnackBar();
                        },
                      );
                    }
                    // Don't dismiss — state update handles the visual change
                    return false;
                  }
                  // Delete direction: dismiss immediately, SnackBar in onDismissed
                  return true;
                },
                child: ChecklistItemWithSuggestionWidget(
                  itemId: item.id,
                  title: item.data.title,
                  isChecked: item.data.isChecked,
                  isArchived: item.data.isArchived,
                  hideCompleted: hideIfChecked,
                  index: index,
                  onChanged: (checked) => ref
                      .read(provider.notifier)
                      .updateChecked(checked: checked),
                  onTitleChange: ref.read(provider.notifier).updateTitle,
                ),
              ),
            ),
          ),
        );

        // RepaintBoundary isolates repaints to individual checklist items
        return RepaintBoundary(child: child);
      },
      error: ErrorWidget.new,
      loading: (_) => const SizedBox.shrink(),
    );
  }
}
