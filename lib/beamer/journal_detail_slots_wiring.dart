import 'package:lotti/features/events/ui/widgets/linked_event_card.dart';
import 'package:lotti/features/github/ui/track_pull_requests_item.dart';
import 'package:lotti/features/journal/state/journal_detail_slots.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_card_wrapper.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_item_row.dart';
import 'package:lotti/features/tasks/ui/checklists/linked_from_checklist_widget.dart';
import 'package:lotti/features/tasks/ui/pages/task_details_page.dart';

/// The app's [JournalDetailSlots]: the tasks, checklist, event and GitHub
/// widgets journal surfaces show. The composition root overrides
/// `journalDetailSlotsProvider` with it, and so do tests that render those
/// widgets through a journal surface.
final appJournalDetailSlots = JournalDetailSlots(
  taskDetailPage: (taskId) => TaskDetailsPage(taskId: taskId),
  linkedEventCard: (event) => LinkedEventCard(event: event),
  checklistBody: ({required checklistId, required taskId}) =>
      ChecklistCardWrapper(entryId: checklistId, taskId: taskId),
  checklistItemBody:
      ({required itemId, required checklistId, required taskId}) =>
          ChecklistItemRow(
            itemId: itemId,
            checklistId: checklistId,
            taskId: taskId,
            index: 0,
          ),
  linkedFromChecklist: LinkedFromChecklistWidget.new,
  taskCreateAction: pullRequestTrackingAction,
);
