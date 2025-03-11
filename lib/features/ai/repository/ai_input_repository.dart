import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/model/ai_input.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/features/tasks/state/task_progress_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/widgets/charts/utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ai_input_repository.g.dart';

class AiInputRepository {
  AiInputRepository(this.ref);

  final JournalDb _db = getIt<JournalDb>();
  final Ref ref;

  Future<AiInputTaskObject?> generate(String id) async {
    final start = DateTime.now();

    final entry = await _db.journalEntityById(id);

    if (entry is! Task) {
      return null;
    }

    final task = entry;

    final timeSpent = ref
            .read(taskProgressControllerProvider(id: task.id))
            .valueOrNull
            ?.progress ??
        Duration.zero;

    final logEntries = <AiInputLogEntryObject>[];
    final linkedEntities = await _db.getLinkedEntities(id);

    for (final linked in linkedEntities) {
      if (linked is JournalEntry ||
          linked is JournalImage ||
          linked is JournalAudio) {
        logEntries.add(
          AiInputLogEntryObject(
            creationTimestamp: linked.meta.dateFrom,
            loggedDuration: formatHhMm(entryDuration(linked)),
            text: linked.entryText?.plainText ?? '',
          ),
        );
      }
    }

    final checklistIds = task.data.checklistIds ?? [];

    final checklistItems = <ChecklistItemData>[];
    for (final checklistId in checklistIds) {
      final checklist = await _db.journalEntityById(checklistId);
      if (checklist != null && checklist is Checklist) {
        final checklistItemIds = checklist.data.linkedChecklistItems;
        for (final checklistItemId in checklistItemIds) {
          final checklistItem = await _db.journalEntityById(checklistItemId);
          if (checklistItem != null && checklistItem is ChecklistItem) {
            final data = checklistItem.data.copyWith(id: checklistItemId);
            checklistItems.add(data);
          }
        }
      }
    }

    final actionItems = checklistItems
        .map(
          (item) => AiActionItem(
            title: item.title,
            completed: item.isChecked,
          ),
        )
        .toList();

    final aiInput = AiInputTaskObject(
      title: task.data.title,
      status: task.data.status.map(
        open: (_) => 'OPEN',
        groomed: (_) => 'GROOMED',
        started: (_) => 'STARTED',
        inProgress: (_) => 'IN PROGRESS',
        blocked: (_) => 'BLOCKED',
        onHold: (_) => 'ON HOLD',
        done: (_) => 'DONE',
        rejected: (_) => 'REJECTED',
      ),
      creationDate: start,
      actionItems: actionItems,
      logEntries: logEntries,
      estimatedDuration: formatHhMm(task.data.estimate ?? Duration.zero),
      timeSpent: formatHhMm(timeSpent),
    );

    return aiInput;
  }
}

@riverpod
AiInputRepository aiInputRepository(Ref ref) {
  return AiInputRepository(ref);
}
