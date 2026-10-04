import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/beamer/journal_detail_slots_wiring.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/events/ui/widgets/linked_event_card.dart';
import 'package:lotti/features/github/ui/track_pull_requests_item.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_card_wrapper.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_item_row.dart';
import 'package:lotti/features/tasks/ui/checklists/linked_from_checklist_widget.dart';
import 'package:lotti/features/tasks/ui/pages/task_details_page.dart';

void main() {
  final at = DateTime(2026, 5, 12);
  final meta = Metadata(
    id: 'entry-id',
    createdAt: at,
    updatedAt: at,
    dateFrom: at,
    dateTo: at,
  );

  test('the task page slot opens the task details page for that task', () {
    final page = appJournalDetailSlots.taskDetailPage!('task-1');
    expect(page, isA<TaskDetailsPage>());
    expect((page as TaskDetailsPage).taskId, 'task-1');
  });

  test('the linked event slot shows the event card for that event', () {
    final event = JournalEvent(
      meta: meta,
      data: const EventData(
        title: 'Launch Party',
        stars: 0,
        status: EventStatus.completed,
      ),
    );
    final card = appJournalDetailSlots.linkedEventCard!(event);
    expect(card, isA<LinkedEventCard>());
    expect((card as LinkedEventCard).event, same(event));
  });

  test('the checklist slot shows the checklist card inside its task', () {
    final body = appJournalDetailSlots.checklistBody!(
      checklistId: 'checklist-1',
      taskId: 'task-1',
    );
    expect(body, isA<ChecklistCardWrapper>());
    body as ChecklistCardWrapper;
    expect(body.entryId, 'checklist-1');
    expect(body.taskId, 'task-1');
  });

  test('the checklist item slot shows the item row in its checklist', () {
    final row = appJournalDetailSlots.checklistItemBody!(
      itemId: 'item-1',
      checklistId: 'checklist-1',
      taskId: 'task-1',
    );
    expect(row, isA<ChecklistItemRow>());
    row as ChecklistItemRow;
    expect(row.itemId, 'item-1');
    expect(row.checklistId, 'checklist-1');
    expect(row.taskId, 'task-1');
  });

  test('the linked-from-checklist slot shows the checklists of that item', () {
    final item = ChecklistItem(
      meta: meta,
      data: const ChecklistItemData(
        title: 'Item',
        isChecked: false,
        linkedChecklists: ['checklist-1'],
      ),
    );
    final section = appJournalDetailSlots.linkedFromChecklist!(item);
    expect(section, isA<LinkedFromChecklistWidget>());
    expect((section as LinkedFromChecklistWidget).item, same(item));
  });

  test('the task create action is the GitHub pull request tracking row', () {
    expect(
      appJournalDetailSlots.taskCreateAction,
      same(pullRequestTrackingAction),
    );
  });
}
