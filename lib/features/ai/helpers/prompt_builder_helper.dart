import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/util/preconfigured_prompts.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/consts.dart';

/// Helper class for building AI prompts with support for template tracking
class PromptBuilderHelper {
  PromptBuilderHelper({
    required this.aiInputRepository,
    this.journalRepository,
  });

  final AiInputRepository aiInputRepository;
  final JournalRepository? journalRepository;

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
      var enabled = false;
      try {
        final dynamic fut = getIt<JournalDb>().getConfigFlag(
          enableAiLabelAssignmentFlag,
        );
        if (fut is Future<bool>) {
          enabled = await fut;
        }
      } catch (_) {
        enabled = false;
      }
      if (enabled) {
        final labelsJson = await _buildLabelsJson();
        prompt = prompt.replaceAll('{{labels}}', labelsJson);
      } else {
        prompt = prompt.replaceAll('{{labels}}', '[]');
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

  /// Build a compact JSON array [{"id":"...","name":"..."}] of labels
  /// limited to 100 entries (top-50 by usage + next-50 alphabetical).
  Future<String> _buildLabelsJson() async {
    final db = getIt<JournalDb>();

    // Respect privacy toggle
    var includePrivate = true;
    try {
      final dynamic fut = db.getConfigFlag(includePrivateLabelsInPromptsFlag);
      if (fut is Future<bool>) {
        includePrivate = await fut;
      }
    } catch (_) {
      includePrivate = true;
    }

    // Fetch label definitions and usage stats
    final all = await db.getAllLabelDefinitions();
    final usage = await db.getLabelUsageCounts();

    // Optionally filter private labels
    final filtered =
        includePrivate ? all : all.where((l) => !(l.private ?? false)).toList();

    // Sort: top 50 by usage desc (ties by name asc), then next 50 alphabetical
    final byUsage = [...filtered]..sort((a, b) {
        final ua = usage[a.id] ?? 0;
        final ub = usage[b.id] ?? 0;
        if (ua != ub) return ub.compareTo(ua);
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    final topUsage = byUsage.take(50).toList();

    final remaining = filtered
        .where((l) => !topUsage.any((t) => t.id == l.id))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final nextAlpha = remaining.take(50).toList();

    final selected = [...topUsage, ...nextAlpha];
    final tuples = selected
        .map((l) => {
              'id': l.id,
              'name': l.name,
            })
        .toList();

    return jsonEncode(tuples);
  }
}
