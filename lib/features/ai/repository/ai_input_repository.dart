import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/model/ai_input.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/features/labels/utils/assigned_labels_util.dart';
import 'package:lotti/features/tasks/repository/task_progress_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/entities_cache_service.dart';
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
    final timeSpent = await _calculateTimeSpent(task.id);

    final logEntries = <AiInputLogEntryObject>[];
    final linkedEntities = await _db.getLinkedEntities(id);

    for (final linked in linkedEntities) {
      if (linked is JournalEntry ||
          linked is JournalImage ||
          linked is JournalAudio) {
        String? audioTranscript;
        String? transcriptLanguage;
        String? entryType;
        final editedText = linked.entryText?.plainText;
        // An explicit edit (even to empty string) takes precedence over transcript
        final hasEditedText = editedText != null;

        if (linked is JournalAudio) {
          entryType = 'audio';
          // Only include original transcript if user hasn't edited the text.
          // When entryText exists, it represents the user's corrections and
          // should take precedence over the raw transcript.
          if (!hasEditedText) {
            final transcripts = linked.data.transcripts;
            if (transcripts != null && transcripts.isNotEmpty) {
              final latestTranscript = transcripts.last;
              audioTranscript = latestTranscript.transcript;
              transcriptLanguage = latestTranscript.detectedLanguage;
            }
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
            text: editedText ?? '',
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

    // Start with the base task JSON
    final base = aiInput.toJson();

    // Extend with assigned labels [{id,name}] when available
    try {
      final entity = await _db.journalEntityById(id);
      if (entity is Task) {
        final ids = entity.meta.labelIds ?? const <String>[];
        if (ids.isNotEmpty) {
          base['labels'] = await buildAssignedLabelTuples(db: _db, ids: ids);
        } else {
          base['labels'] = <Map<String, String>>[];
        }

        // Phase 3: include suppressed label IDs for transparency
        final suppressed = entity.data.aiSuppressedLabelIds;
        if (suppressed != null && suppressed.isNotEmpty) {
          base['aiSuppressedLabelIds'] = suppressed.toList();
        } else {
          base['aiSuppressedLabelIds'] = <String>[];
        }
      }
    } catch (_) {
      // On lookup failure, omit labels extension silently
    }

    const encoder = JsonEncoder.withIndent('    ');
    final jsonString = encoder.convert(base);
    return jsonString;
  }

  /// Build label tuples from the cache service (O(1) per label).
  ///
  /// Falls back to the ID if a label definition is not found in cache.
  List<Map<String, String>> _buildLabelTuplesFromCache(List<String> ids) {
    if (ids.isEmpty) return <Map<String, String>>[];
    final cache = getIt<EntitiesCacheService>();
    return ids.map((id) {
      final def = cache.getLabelById(id);
      return {'id': id, 'name': def?.name ?? id};
    }).toList();
  }

  /// Calculate the time spent on a task.
  ///
  /// Returns the total duration of work logged against this task.
  Future<Duration> _calculateTimeSpent(String taskId) async {
    final progressRepository = ref.read(taskProgressRepositoryProvider);
    final progressData = await progressRepository.getTaskProgressData(
      id: taskId,
    );
    final durations = progressData?.$2 ?? {};
    return progressRepository
        .getTaskProgress(durations: durations, estimate: progressData?.$1)
        .progress;
  }

  /// Build context for tasks that link TO this task (children/subtasks).
  /// These are tasks where the current task is the target of the link.
  ///
  /// This method is primarily used internally by [buildLinkedTasksJson].
  /// It is exposed for testing purposes only.
  @visibleForTesting
  Future<List<AiLinkedTaskContext>> buildLinkedFromContext(
      String taskId) async {
    // Get entities that link TO this task (where toId = taskId)
    final linkedEntities = await _db.linkedToJournalEntities(taskId).get();
    final tasks = linkedEntities
        .map(fromDbEntity)
        .whereType<Task>()
        .where((t) => t.meta.deletedAt == null)
        .toList()
      ..sort((a, b) => a.meta.createdAt.compareTo(b.meta.createdAt));

    final results = <AiLinkedTaskContext>[];
    for (final task in tasks) {
      final context = await _buildLinkedTaskContext(task);
      results.add(context);
    }
    return results;
  }

  /// Build context for tasks this task links TO (parents/epics).
  /// These are tasks where the current task is the source of the link.
  ///
  /// This method is primarily used internally by [buildLinkedTasksJson].
  /// It is exposed for testing purposes only.
  @visibleForTesting
  Future<List<AiLinkedTaskContext>> buildLinkedToContext(String taskId) async {
    // Get entities that this task links TO (where fromId = taskId)
    final linkedEntities = await _db.getLinkedEntities(taskId);
    final tasks = linkedEntities
        .whereType<Task>()
        .where((t) => t.meta.deletedAt == null)
        .toList()
      ..sort((a, b) => a.meta.createdAt.compareTo(b.meta.createdAt));

    final results = <AiLinkedTaskContext>[];
    for (final task in tasks) {
      final context = await _buildLinkedTaskContext(task);
      results.add(context);
    }
    return results;
  }

  /// Build context object for a single linked task.
  Future<AiLinkedTaskContext> _buildLinkedTaskContext(Task task) async {
    final timeSpent = await _calculateTimeSpent(task.id);

    // Get labels from cache (avoids N+1 query per task)
    final labelIds = task.meta.labelIds ?? const <String>[];
    final labels = _buildLabelTuplesFromCache(labelIds);

    // Get latest summary
    final latestSummary = await _getLatestTaskSummary(task.id);

    return AiLinkedTaskContext(
      id: task.id,
      title: task.data.title,
      status: task.data.status.toDbString,
      statusSince: task.data.status.createdAt,
      priority: task.data.priority.short,
      estimate: formatHhMm(task.data.estimate ?? Duration.zero),
      timeSpent: formatHhMm(timeSpent),
      createdAt: task.meta.createdAt,
      labels: labels,
      languageCode: task.data.languageCode,
      latestSummary: latestSummary,
    );
  }

  /// Get the latest AI summary for a task.
  Future<String?> _getLatestTaskSummary(String taskId) async {
    final linkedEntities = await _db.getLinkedEntities(taskId);
    final summaries = linkedEntities
        .whereType<AiResponseEntry>()
        .where((e) => e.data.type == AiResponseType.taskSummary)
        .toList()
      ..sort((a, b) => b.meta.dateFrom.compareTo(a.meta.dateFrom));

    if (summaries.isEmpty) return null;
    return summaries.first.data.response;
  }

  /// Build the full linked tasks JSON for prompt injection.
  Future<String> buildLinkedTasksJson(String taskId) async {
    final linkedFrom = await buildLinkedFromContext(taskId);
    final linkedTo = await buildLinkedToContext(taskId);

    final data = <String, dynamic>{
      'linked_from': linkedFrom.map((c) => c.toJson()).toList(),
      'linked_to': linkedTo.map((c) => c.toJson()).toList(),
    };

    // Add note if there are any linked tasks with summaries containing links
    if (linkedFrom.isNotEmpty || linkedTo.isNotEmpty) {
      data['note'] =
          'If summaries contain links to GitHub PRs, Issues, or similar '
          'platforms, use web search to retrieve additional context when relevant.';
    }

    const encoder = JsonEncoder.withIndent('    ');
    return encoder.convert(data);
  }
}

@riverpod
AiInputRepository aiInputRepository(Ref ref) {
  return AiInputRepository(ref);
}
