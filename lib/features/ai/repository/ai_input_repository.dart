import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/model/ai_input.dart';
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

  Future<AiResponseEntry?> createAiResponseEntry({
    required AiResponseData data,
    required DateTime start,
    String? linkedId,
    String? categoryId,
  }) async {
    return getIt<PersistenceLogic>().createAiResponseEntry(
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
        String? audioTranscript;
        String? transcriptLanguage;
        String? entryType;

        if (linked is JournalAudio) {
          entryType = 'audio';
          // Get the most recent transcript if available
          final transcripts = linked.data.transcripts;
          if (transcripts != null && transcripts.isNotEmpty) {
            final latestTranscript = transcripts.last;
            audioTranscript = latestTranscript.transcript;
            transcriptLanguage = latestTranscript.detectedLanguage;
          }
        } else if (linked is JournalImage) {
          entryType = 'image';
        } else if (linked is JournalEntry) {
          entryType = 'text';
        }

        logEntries.add(
          AiInputLogEntryObject(
            creationTimestamp: linked.meta.dateFrom,
            loggedDuration: formatHhMm(entryDuration(linked)),
            text: linked.entryText?.plainText ?? '',
            audioTranscript: audioTranscript,
            transcriptLanguage: transcriptLanguage,
            entryType: entryType,
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
            id: item.id,
          ),
        )
        .toList();

    final aiInput = AiInputTaskObject(
      title: task.data.title,
      status: task.data.status.map(
        open: (_) => 'OPEN',
        groomed: (_) => 'GROOMED',
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
      languageCode: task.data.languageCode,
    );

    return aiInput;
  }

  Future<String?> buildTaskDetailsJson({required String id}) async {
    final aiInput = await generate(id);

    if (aiInput == null) {
      return null;
    }

    const encoder = JsonEncoder.withIndent('    ');
    final jsonString = encoder.convert(aiInput);
    return jsonString;
  }
}

@riverpod
AiInputRepository aiInputRepository(Ref ref) {
  return AiInputRepository(ref);
}
