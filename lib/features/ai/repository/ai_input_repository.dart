import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/model/ai_input.dart';
import 'package:lotti/features/ai/repository/prompts.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/features/tasks/repository/task_progress_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/widgets/charts/utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ai_input_repository.g.dart';

class AiInputRepository {
  AiInputRepository(this.ref);

  final JournalDb _db = getIt<JournalDb>();
  final Ref ref;

  Future<JournalEntity?> getEntity(String id) async {
    return _db.journalEntityById(id);
  }

  Future<void> createAiResponseEntry({
    required AiResponseData data,
    required DateTime start,
    String? linkedId,
    String? categoryId,
  }) async {
    await getIt<PersistenceLogic>().createAiResponseEntry(
      data: data,
      dateFrom: start,
      linkedId: linkedId,
      categoryId: categoryId,
    );
  }

  Future<AiInputTaskObject?> generate(String id) async {
    final entry = await getEntity(id);

    if (entry is! Task) {
      return null;
    }

    final task = entry;

    final progressRepository = ref.read(taskProgressRepositoryProvider);
    final taskProgressData =
        await progressRepository.getTaskProgressData(id: task.id);
    final durations = taskProgressData?.$2 ?? {};

    final timeSpent = progressRepository
        .getTaskProgress(
          durations: durations,
          estimate: taskProgressData?.$1,
        )
        .progress;

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
      creationDate: task.meta.createdAt,
      actionItems: actionItems,
      logEntries: logEntries,
      estimatedDuration: formatHhMm(task.data.estimate ?? Duration.zero),
      timeSpent: formatHhMm(timeSpent),
    );

    return aiInput;
  }

  Future<String?> buildPrompt({
    required String id,
    required AiResponseType aiResponseType,
  }) async {
    final aiInput = await generate(id);

    if (aiInput == null) {
      return null;
    }

    const encoder = JsonEncoder.withIndent('    ');
    final jsonString = encoder.convert(aiInput);

    if (aiResponseType == AiResponseType.taskSummary) {
      return createTaskSummaryPrompt(jsonString);
    }
    if (aiResponseType == AiResponseType.actionItemSuggestions) {
      return createActionItemSuggestionsPrompt(jsonString);
    }
    return null;
  }
}

@riverpod
AiInputRepository aiInputRepository(Ref ref) {
  return AiInputRepository(ref);
}
