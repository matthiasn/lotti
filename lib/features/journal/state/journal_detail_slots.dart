import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:material_ui/material_ui.dart';

/// Builds a task's full details page.
typedef TaskDetailPageBuilder = Widget Function(String taskId);

/// Builds the card an event shows where it is linked from an entry.
typedef LinkedEventCardBuilder = Widget Function(JournalEvent event);

/// Builds a checklist's body inside its parent task.
typedef ChecklistBodyBuilder =
    Widget Function({required String checklistId, required String taskId});

/// Builds a single checklist item's row.
typedef ChecklistItemBodyBuilder =
    Widget Function({
      required String itemId,
      required String checklistId,
      required String taskId,
    });

/// Builds the "linked from" section a checklist item shows for its
/// checklists.
typedef LinkedFromChecklistBuilder = Widget Function(ChecklistItem item);

/// Builds an extra action for the create-entry list on a task, or returns
/// null when there is none to offer. Called while the list builds, with its
/// [WidgetRef], so it may watch providers.
typedef TaskCreateActionBuilder =
    Widget? Function(WidgetRef ref, String taskId);

/// The widgets journal surfaces show for things higher features own: tasks,
/// checklists, events and pull requests.
///
/// Journal ranks below those features, so it cannot import their widgets;
/// the composition root fills these slots instead. An unfilled slot renders
/// nothing (or, for the task page, the plain entry page).
@immutable
class JournalDetailSlots {
  const JournalDetailSlots({
    this.taskDetailPage,
    this.linkedEventCard,
    this.checklistBody,
    this.checklistItemBody,
    this.linkedFromChecklist,
    this.taskCreateAction,
  });

  final TaskDetailPageBuilder? taskDetailPage;
  final LinkedEventCardBuilder? linkedEventCard;
  final ChecklistBodyBuilder? checklistBody;
  final ChecklistItemBodyBuilder? checklistItemBody;
  final LinkedFromChecklistBuilder? linkedFromChecklist;
  final TaskCreateActionBuilder? taskCreateAction;
}

/// The [JournalDetailSlots] the composition root wires.
final journalDetailSlotsProvider = Provider<JournalDetailSlots>(
  (ref) => const JournalDetailSlots(),
  name: 'journalDetailSlotsProvider',
);
