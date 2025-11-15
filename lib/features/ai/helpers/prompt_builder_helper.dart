import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/util/preconfigured_prompts.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/labels/constants/label_assignment_constants.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/logging_service.dart';

/// Helper class for building AI prompts with support for template tracking
typedef LabelFilterFn = List<LabelDefinition> Function(
  List<LabelDefinition> all,
  String? categoryId,
);

typedef ConfigFlagFn = Future<bool> Function(String name, {bool defaultValue});

class PromptBuilderHelper {
  PromptBuilderHelper({
    required this.aiInputRepository,
    required this.checklistRepository,
    required this.journalRepository,
    required this.labelsRepository,
    this.labelFilterForCategory,
  });

  final AiInputRepository aiInputRepository;
  final JournalRepository journalRepository;
  final LabelsRepository labelsRepository;
  final LabelFilterFn? labelFilterForCategory;
  final ChecklistRepository checklistRepository;
  LoggingService? get _loggingService =>
      getIt.isRegistered<LoggingService>() ? getIt<LoggingService>() : null;

  /// Get effective message from prompt config, using preconfigured if tracking is enabled
  String getEffectiveMessage({
    required AiConfigPrompt promptConfig,
    required bool isSystemMessage,
  }) {
    final baseMessage =
        isSystemMessage ? promptConfig.systemMessage : promptConfig.userMessage;

    if (promptConfig.trackPreconfigured &&
        promptConfig.preconfiguredPromptId != null) {
      final preconfiguredPrompt =
          preconfiguredPrompts[promptConfig.preconfiguredPromptId!];
      if (preconfiguredPrompt != null) {
        return isSystemMessage
            ? preconfiguredPrompt.systemMessage
            : preconfiguredPrompt.userMessage;
      }
    }

    return baseMessage;
  }

  /// Build prompt with entity data
  Future<String?> buildPromptWithData({
    required AiConfigPrompt promptConfig,
    required JournalEntity entity,
    String? linkedEntityId,
  }) async {
    // Get user message - use preconfigured if tracking is enabled
    final userMessage = getEffectiveMessage(
      promptConfig: promptConfig,
      isSystemMessage: false,
    );

    var prompt = userMessage;

    // Check if prompt contains {{task}} placeholder
    if (prompt.contains('{{task}}')) {
      final taskJson = await _getTaskJsonForEntity(entity);
      if (taskJson != null) {
        prompt = prompt.replaceAll('{{task}}', taskJson);
      }
      // If no task data available, leave the placeholder - AI will handle gracefully
    } else if (promptConfig.requiredInputData.contains(InputDataType.task) &&
        entity is Task) {
      // For prompts that require task data but don't use {{task}} placeholder
      // (legacy support for summaries, action items)
      final jsonString =
          await aiInputRepository.buildTaskDetailsJson(id: entity.id);
      prompt = '$userMessage \n $jsonString';
    }

    // Inject current entry if requested and linkedEntityId provided
    if (prompt.contains('{{current_entry}}') &&
        promptConfig.aiResponseType == AiResponseType.checklistUpdates) {
      try {
        final repo = journalRepository;
        if (linkedEntityId != null) {
          final current = await repo.getJournalEntityById(linkedEntityId);
          if (current != null) {
            final json = await _buildCurrentEntryJson(current);
            prompt = prompt.replaceAll('{{current_entry}}', json);
          } else {
            prompt = prompt.replaceAll('{{current_entry}}', '');
          }
        } else {
          prompt = prompt.replaceAll('{{current_entry}}', '');
        }
      } catch (error, stackTrace) {
        _logPlaceholderFailure(
          entity: entity,
          placeholder: 'current_entry',
          error: error,
          stackTrace: stackTrace,
          context: 'linkedEntityId=$linkedEntityId',
        );
        prompt = prompt.replaceAll('{{current_entry}}', '');
      }
    }

    // Inject labels list if requested and enabled via feature flag
    if (prompt.contains('{{labels}}') &&
        promptConfig.aiResponseType == AiResponseType.checklistUpdates) {
      final labels = await _buildCategoryScopedLabelsJsonWithCounts(entity);
      prompt = prompt.replaceAll('{{labels}}', labels.json);
      if (labels.totalCount > labels.selectedCount) {
        // Add a short note after the JSON block to avoid breaking JSON parsing
        prompt =
            '$prompt\n(Note: showing ${labels.selectedCount} of ${labels.totalCount} labels)';
      }
    }

    // Inject currently assigned labels if requested
    if (prompt.contains('{{assigned_labels}}') &&
        promptConfig.aiResponseType == AiResponseType.checklistUpdates) {
      try {
        final assigned = await _buildAssignedLabelsJson(entity);
        prompt = prompt.replaceAll('{{assigned_labels}}', assigned);
      } catch (error, stackTrace) {
        _logPlaceholderFailure(
          entity: entity,
          placeholder: 'assigned_labels',
          error: error,
          stackTrace: stackTrace,
        );
        prompt = prompt.replaceAll('{{assigned_labels}}', '[]');
      }
    }

    // Inject suppressed labels if requested (id and name for clarity)
    if (prompt.contains('{{suppressed_labels}}') &&
        promptConfig.aiResponseType == AiResponseType.checklistUpdates) {
      try {
        final suppressed = await _buildSuppressedLabelsJson(entity);
        prompt = prompt.replaceAll('{{suppressed_labels}}', suppressed);
      } catch (error, stackTrace) {
        _logPlaceholderFailure(
          entity: entity,
          placeholder: 'suppressed_labels',
          error: error,
          stackTrace: stackTrace,
        );
        prompt = prompt.replaceAll('{{suppressed_labels}}', '[]');
      }
    }

    // Inject deleted checklist items (recent) if requested
    if (prompt.contains('{{deleted_checklist_items}}') &&
        promptConfig.aiResponseType == AiResponseType.checklistUpdates) {
      try {
        final deleted = await _buildDeletedChecklistItemsJson(entity);
        prompt = prompt.replaceAll('{{deleted_checklist_items}}', deleted);
      } catch (error, stackTrace) {
        _logPlaceholderFailure(
          entity: entity,
          placeholder: 'deleted_checklist_items',
          error: error,
          stackTrace: stackTrace,
        );
        prompt = prompt.replaceAll('{{deleted_checklist_items}}', '[]');
      }
    }

    return prompt;
  }

  /// Get task JSON for a given entity
  /// For images and audio, looks for linked tasks
  /// For tasks, directly gets the task JSON
  Future<String?> _getTaskJsonForEntity(JournalEntity entity) async {
    if (entity is Task) {
      // Direct task entity
      return aiInputRepository.buildTaskDetailsJson(id: entity.id);
    } else if (entity is JournalImage || entity is JournalAudio) {
      // For images and audio, check if they are linked to a task
      final linkedTask = await _findLinkedTask(entity);
      if (linkedTask != null) {
        final json =
            await aiInputRepository.buildTaskDetailsJson(id: linkedTask.id);
        return json;
      }
    }
    return null;
  }

  /// Find a task linked to the given entity
  Future<Task?> _findLinkedTask(JournalEntity entity) async {
    List<JournalEntity> linkedEntities;
    linkedEntities =
        await journalRepository.getLinkedToEntities(linkedTo: entity.id);

    final task = linkedEntities.firstWhereOrNull(
      (linked) => linked is Task,
    ) as Task?;
    return task;
  }

  /// Build JSON array of deleted checklist item titles for the task.
  /// Each item: {"title": String, "deletedAt": ISO8601 String}
  Future<String> _buildDeletedChecklistItemsJson(JournalEntity entity) async {
    final checklistItems = await _getChecklistItemsForTask(
      entity: entity,
      deletedOnly: true,
    );
    if (checklistItems.isEmpty) {
      return '[]';
    }

    final results = <Map<String, String>>[];
    for (final item in checklistItems) {
      final title = item.data.title.trim();
      if (title.isEmpty) continue;
      final deletedAt = (item.meta.deletedAt ?? item.meta.updatedAt)
          .toUtc()
          .toIso8601String();
      results.add({
        'title': title,
        'deletedAt': deletedAt,
      });
    }

    return jsonEncode(results);
  }

  /// Fetches checklist items linked to the task, including soft-deleted ones.
  ///
  /// We look up each checklist ID’s `linked_entries` so that hidden links (set
  /// when the item is removed from the UI) still surface here. The returned
  /// list is sorted by `dateFrom` descending.
  Future<List<ChecklistItem>> _getChecklistItemsForTask({
    required JournalEntity entity,
    required bool deletedOnly,
  }) async {
    Task? task;
    if (entity is Task) {
      task = entity;
    } else {
      task = await _findLinkedTask(entity);
    }

    if (task == null) {
      return const [];
    }

    return checklistRepository.getChecklistItemsForTask(
      task: task,
      deletedOnly: deletedOnly,
    );
  }

  /// Build Current Entry JSON with id, createdAt, entryType, and text.
  Future<String> _buildCurrentEntryJson(JournalEntity entry) async {
    final entryType = switch (entry) {
      JournalAudio() => 'audio',
      JournalImage() => 'image',
      JournalEntry() => 'text',
      _ => 'text',
    };

    final text = _resolveEntryText(entry);

    final jsonMap = {
      'id': entry.id,
      'createdAt': entry.meta.dateFrom.toUtc().toIso8601String(),
      'entryType': entryType,
      'text': text,
    };
    return jsonEncode(jsonMap);
  }

  // Note: the legacy global labels builder was removed. The category-scoped
  // builder covers both category and no-category (global-only) scenarios.

  /// Build a compact JSON array of labels scoped to the task's category
  /// when available. Falls back to global behavior when no category is
  /// resolvable for the current context.
  Future<({String json, int selectedCount, int totalCount})>
      _buildCategoryScopedLabelsJsonWithCounts(JournalEntity entity) async {
    // Determine categoryId from the current entity or linked task
    String? categoryId;
    if (entity is Task) {
      categoryId = entity.meta.categoryId;
    } else {
      final linkedTask = await _findLinkedTask(entity);
      categoryId = linkedTask?.meta.categoryId;
    }

    // Fetch label definitions and usage stats via repository
    final all = await labelsRepository.getAllLabels();
    final usage = await labelsRepository.getLabelUsageCounts();

    // Scope to category (union of global ∪ scoped(category)) using injected or cache filter
    final scoped = _getLabelFilterFn().call(
      all,
      categoryId,
    );

    // Phase 3: Exclude task-suppressed labels from the Available list
    final suppressedIds = await _getSuppressedIdsForEntity(entity);
    final scopedNotSuppressed = suppressedIds == null || suppressedIds.isEmpty
        ? scoped
        : scoped.where((l) => !suppressedIds.contains(l.id)).toList();

    // Sort into top usage and next alpha, within the scoped set
    final byUsage = [...scopedNotSuppressed]..sort((a, b) {
        final ua = usage[a.id] ?? 0;
        final ub = usage[b.id] ?? 0;
        if (ua != ub) return ub.compareTo(ua);
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    final topUsage = byUsage.take(kLabelsPromptTopUsageCount).toList();

    final remaining = scopedNotSuppressed
        .where((l) => !topUsage.any((t) => t.id == l.id))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final nextAlpha = remaining.take(kLabelsPromptNextAlphaCount).toList();

    final selected = [...topUsage, ...nextAlpha];
    final tuples = selected
        .map((l) => {
              'id': l.id,
              'name': l.name,
            })
        .toList();

    return (
      json: jsonEncode(tuples),
      selectedCount: tuples.length,
      totalCount: scopedNotSuppressed.length,
    );
  }

  /// Resolve the filter function preference order:
  /// 1) Injected [labelFilterForCategory]
  /// 2) EntitiesCacheService.filterLabelsForCategory (if registered)
  /// 3) Local fallback (kept minimal; keep in sync with EntitiesCacheService)
  LabelFilterFn _getLabelFilterFn() {
    if (labelFilterForCategory != null) return labelFilterForCategory!;
    try {
      if (getIt.isRegistered<EntitiesCacheService>()) {
        final cache = getIt<EntitiesCacheService>();
        return cache.filterLabelsForCategory;
      }
    } catch (_) {}
    return _localFilterLabelsForCategory;
  }

  /// Local fallback for category scoping used when neither an injected filter
  /// nor EntitiesCacheService is available (primarily in tests).
  /// IMPORTANT: Keep semantics in sync with
  /// `EntitiesCacheService.filterLabelsForCategory`.
  /// Note: Privacy filtering is handled at the database layer via config flags.
  List<LabelDefinition> _localFilterLabelsForCategory(
    List<LabelDefinition> all,
    String? categoryId,
  ) {
    final dedup = <String, LabelDefinition>{};
    for (final l in all) {
      if (l.deletedAt != null) continue;
      final cats = l.applicableCategoryIds;
      final isGlobal = cats == null || cats.isEmpty;
      final inCategory =
          categoryId != null && (cats?.contains(categoryId) ?? false);
      if (isGlobal || inCategory) {
        dedup[l.id] = l;
      }
    }
    // Caller applies ranking/sorting (usage then alpha). Avoid extra sort here.
    return dedup.values.toList();
  }

  /// Build JSON array of assigned labels [{id,name}] for the task or linked task
  Future<String> _buildAssignedLabelsJson(JournalEntity entity) async {
    Task? task;
    if (entity is Task) {
      task = entity;
    } else {
      task = await _findLinkedTask(entity);
    }
    if (task == null) return '[]';
    final ids = task.meta.labelIds ?? const <String>[];
    if (ids.isEmpty) return '[]';
    final tuples = await labelsRepository.buildLabelTuples(ids);
    return jsonEncode(tuples);
  }

  /// Build JSON array of suppressed labels [{id,name}] for the task or linked task
  Future<String> _buildSuppressedLabelsJson(JournalEntity entity) async {
    Task? task;
    if (entity is Task) {
      task = entity;
    } else {
      task = await _findLinkedTask(entity);
    }
    if (task == null) return '[]';
    final ids = task.data.aiSuppressedLabelIds ?? const <String>{};
    if (ids.isEmpty) return '[]';
    final tuples = await labelsRepository.buildLabelTuples(ids.toList());
    return jsonEncode(tuples);
  }

  Future<Set<String>?> _getSuppressedIdsForEntity(JournalEntity entity) async {
    Task? task;
    if (entity is Task) {
      task = entity;
    } else {
      task = await _findLinkedTask(entity);
    }
    return task?.data.aiSuppressedLabelIds;
  }

  String _resolveEntryText(JournalEntity entry) {
    final editedText = entry.entryText?.plainText.trim();
    if (editedText != null && editedText.isNotEmpty) {
      return editedText;
    }

    if (entry is JournalAudio) {
      final transcripts = entry.data.transcripts;
      if (transcripts != null && transcripts.isNotEmpty) {
        final latestTranscript = transcripts.reduce(
          (current, candidate) =>
              candidate.created.isAfter(current.created) ? candidate : current,
        );
        final transcriptText = latestTranscript.transcript.trim();
        if (transcriptText.isNotEmpty) {
          return transcriptText;
        }
      }
    }

    return '';
  }

  void _logPlaceholderFailure({
    required JournalEntity entity,
    required String placeholder,
    required Object error,
    required StackTrace stackTrace,
    String? context,
  }) {
    final suffix = (context == null || context.isEmpty) ? '' : ' $context';
    _loggingService?.captureException(
      'Failed to inject {{$placeholder}} for entity=${entity.id}$suffix: $error',
      domain: 'prompt_builder_helper',
      subDomain: 'placeholder_injection',
      stackTrace: stackTrace,
    );
  }
}
