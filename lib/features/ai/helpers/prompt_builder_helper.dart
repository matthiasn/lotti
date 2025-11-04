import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/util/preconfigured_prompts.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/labels/constants/label_assignment_constants.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/consts.dart';

/// Helper class for building AI prompts with support for template tracking
typedef LabelFilterFn = List<LabelDefinition> Function(
  List<LabelDefinition> all,
  String? categoryId, {
  required bool includePrivate,
});

class PromptBuilderHelper {
  PromptBuilderHelper({
    required this.aiInputRepository,
    this.journalRepository,
    this.labelFilterForCategory,
  });

  final AiInputRepository aiInputRepository;
  final JournalRepository? journalRepository;
  final LabelFilterFn? labelFilterForCategory;

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

    // Inject labels list if requested and enabled via feature flag
    if (prompt.contains('{{labels}}') &&
        promptConfig.aiResponseType == AiResponseType.checklistUpdates) {
      final enabled = await _getFlagSafe(enableAiLabelAssignmentFlag);
      if (enabled) {
        final labels = await _buildCategoryScopedLabelsJsonWithCounts(entity);
        prompt = prompt.replaceAll('{{labels}}', labels.json);
        if (labels.totalCount > labels.selectedCount) {
          // Add a short note after the JSON block to avoid breaking JSON parsing
          prompt =
              '$prompt\n(Note: showing ${labels.selectedCount} of ${labels.totalCount} labels)';
        }
      } else {
        prompt = prompt.replaceAll('{{labels}}', '[]');
      }
    }

    // Inject currently assigned labels if requested
    if (prompt.contains('{{assigned_labels}}') &&
        promptConfig.aiResponseType == AiResponseType.checklistUpdates) {
      try {
        final assigned = await _buildAssignedLabelsJson(entity);
        prompt = prompt.replaceAll('{{assigned_labels}}', assigned);
      } catch (_) {
        prompt = prompt.replaceAll('{{assigned_labels}}', '[]');
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
    if (journalRepository == null) {
      return null;
    }

    final linkedFromEntities = await journalRepository!.getLinkedToEntities(
      linkedTo: entity.id,
    );

    // Find if any linked entity is a task
    final task = linkedFromEntities.firstWhereOrNull(
      (entity) => entity is Task,
    ) as Task?;
    return task;
  }

  // Note: the legacy global labels builder was removed. The category-scoped
  // builder covers both category and no-category (global-only) scenarios.

  /// Build a compact JSON array of labels scoped to the task's category
  /// when available. Falls back to global behavior when no category is
  /// resolvable for the current context.
  Future<({String json, int selectedCount, int totalCount})>
      _buildCategoryScopedLabelsJsonWithCounts(JournalEntity entity) async {
    final db = getIt<JournalDb>();

    // Determine categoryId from the current entity or linked task
    String? categoryId;
    if (entity is Task) {
      categoryId = entity.meta.categoryId;
    } else {
      final linkedTask = await _findLinkedTask(entity);
      categoryId = linkedTask?.meta.categoryId;
    }

    // Respect privacy toggle for prompts
    final includePrivate = await _getFlagSafe(
      includePrivateLabelsInPromptsFlag,
    );

    // Fetch label definitions and usage stats
    final all = await db.getAllLabelDefinitions();
    final usage = await db.getLabelUsageCounts();

    // Scope to category (union of global ∪ scoped(category)) using injected or cache filter
    final scoped = _getLabelFilterFn().call(
      all,
      categoryId,
      includePrivate: includePrivate,
    );

    // Sort into top usage and next alpha, within the scoped set
    final byUsage = [...scoped]..sort((a, b) {
        final ua = usage[a.id] ?? 0;
        final ub = usage[b.id] ?? 0;
        if (ua != ub) return ub.compareTo(ua);
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    final topUsage = byUsage.take(kLabelsPromptTopUsageCount).toList();

    final remaining = scoped
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
      totalCount: scoped.length,
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
  List<LabelDefinition> _localFilterLabelsForCategory(
    List<LabelDefinition> all,
    String? categoryId, {
    required bool includePrivate,
  }) {
    final dedup = <String, LabelDefinition>{};
    for (final l in all) {
      if (l.deletedAt != null) continue;
      if (!includePrivate && (l.private ?? false)) continue;
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
    final db = getIt<JournalDb>();
    Task? task;
    if (entity is Task) {
      task = entity;
    } else {
      task = await _findLinkedTask(entity);
    }
    if (task == null) return '[]';
    final ids = task.meta.labelIds ?? const <String>[];
    if (ids.isEmpty) return '[]';
    // Batch lookup for names
    final defs = await db.getAllLabelDefinitions();
    final byId = {for (final d in defs) d.id: d};
    final tuples = <Map<String, String>>[];
    for (final id in ids) {
      final def = byId[id];
      final name = def?.name ?? id;
      tuples.add({'id': id, 'name': name});
    }
    return jsonEncode(tuples);
  }

  // Removed obsolete helper _buildLabelsJson(); the category-scoped builder
  // covers all current use cases.

  Future<bool> _getFlagSafe(String name, {bool defaultValue = false}) async {
    try {
      final dynamic fut = getIt<JournalDb>().getConfigFlag(name);
      if (fut is Future<bool>) {
        return await fut;
      }
    } catch (_) {
      // ignore and use default
    }
    return defaultValue;
  }
}
