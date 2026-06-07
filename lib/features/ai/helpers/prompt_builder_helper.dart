import 'dart:convert';
import 'dart:developer' as developer;

import 'package:collection/collection.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/repository/task_summary_resolver.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/util/preconfigured_prompts.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/entities_cache_service.dart';

part 'prompt_builder_placeholder_resolvers.dart';

/// Helper class for building AI prompts with support for template tracking
class PromptBuilderHelper {
  PromptBuilderHelper({
    required this.aiInputRepository,
    required this.journalRepository,
    required this.taskSummaryResolver,
  });

  final AiInputRepository aiInputRepository;
  final JournalRepository journalRepository;
  final TaskSummaryResolver taskSummaryResolver;
  DomainLogger? get _loggingService =>
      getIt.isRegistered<DomainLogger>() ? getIt<DomainLogger>() : null;

  /// Get effective message from prompt config, using preconfigured if tracking is enabled
  String getEffectiveMessage({
    required AiConfigPrompt promptConfig,
    required bool isSystemMessage,
  }) {
    final baseMessage = isSystemMessage
        ? promptConfig.systemMessage
        : promptConfig.userMessage;

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

  /// Build system message with entity data (placeholder substitution)
  ///
  /// Note: {{speech_dictionary}} is only supported in user messages (buildPromptWithData)
  /// to avoid token waste from duplication in both system and user messages.
  Future<String> buildSystemMessageWithData({
    required AiConfigPrompt promptConfig,
    required JournalEntity entity,
  }) async {
    return getEffectiveMessage(
      promptConfig: promptConfig,
      isSystemMessage: true,
    );
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
      final jsonString = await aiInputRepository.buildTaskDetailsJson(
        id: entity.id,
      );
      prompt = '$userMessage \n $jsonString';
    }

    // Inject language code if requested (from task or linked task)
    if (prompt.contains('{{languageCode}}')) {
      String languageCodeToInject;
      try {
        languageCodeToInject = await _getLanguageCodeForEntity(entity) ?? '';
      } catch (error, stackTrace) {
        _logPlaceholderFailure(
          entity: entity,
          placeholder: 'languageCode',
          error: error,
          stackTrace: stackTrace,
        );
        languageCodeToInject = '';
      }
      prompt = prompt.replaceAll('{{languageCode}}', languageCodeToInject);
    }

    // Inject speech dictionary if requested (from task's category)
    if (prompt.contains('{{speech_dictionary}}')) {
      String dictionaryText;
      try {
        dictionaryText = await _buildSpeechDictionaryPromptText(entity);
      } catch (error, stackTrace) {
        _logPlaceholderFailure(
          entity: entity,
          placeholder: 'speech_dictionary',
          error: error,
          stackTrace: stackTrace,
        );
        dictionaryText = '';
      }
      prompt = prompt.replaceAll('{{speech_dictionary}}', dictionaryText);
    }

    // Inject audio transcript if requested (for prompt generation)
    if (prompt.contains('{{audioTranscript}}')) {
      String transcriptText;
      try {
        transcriptText = _resolveAudioTranscript(entity);
      } catch (error, stackTrace) {
        _logPlaceholderFailure(
          entity: entity,
          placeholder: 'audioTranscript',
          error: error,
          stackTrace: stackTrace,
        );
        transcriptText = '[No transcription available]';
      }
      prompt = prompt.replaceAll('{{audioTranscript}}', transcriptText);
    }

    // Inject correction examples if requested (audio transcription)
    if (prompt.contains('{{correction_examples}}') &&
        promptConfig.aiResponseType == AiResponseType.audioTranscription) {
      String examplesText;
      try {
        examplesText = await _buildCorrectionExamplesPromptText(entity);
      } catch (error, stackTrace) {
        _logPlaceholderFailure(
          entity: entity,
          placeholder: 'correction_examples',
          error: error,
          stackTrace: stackTrace,
        );
        examplesText = '';
      }
      prompt = prompt.replaceAll('{{correction_examples}}', examplesText);
    }

    // Inject linked tasks context if requested (available for all prompt types)
    if (prompt.contains('{{linked_tasks}}')) {
      String linkedTasksJson;
      try {
        linkedTasksJson = await _buildLinkedTasksJson(entity);
      } catch (error, stackTrace) {
        _logPlaceholderFailure(
          entity: entity,
          placeholder: 'linked_tasks',
          error: error,
          stackTrace: stackTrace,
        );
        linkedTasksJson = '{"linked_from": [], "linked_to": []}';
      }
      prompt = prompt.replaceAll('{{linked_tasks}}', linkedTasksJson);
    }

    // Inject current task's latest summary if requested
    if (prompt.contains('{{current_task_summary}}')) {
      String summaryText;
      try {
        summaryText = await _buildCurrentTaskSummary(entity);
      } catch (error, stackTrace) {
        _logPlaceholderFailure(
          entity: entity,
          placeholder: 'current_task_summary',
          error: error,
          stackTrace: stackTrace,
        );
        summaryText = '[No task summary available]';
      }
      prompt = prompt.replaceAll('{{current_task_summary}}', summaryText);
    }

    return prompt;
  }

  /// Build linked tasks JSON for the given entity with prompt semantics.
  ///
  /// Works with [Task] entities directly, or finds the linked task for
  /// images/audio via [_findLinkedTask].
  ///
  /// **Separation of Concerns**: The underlying data is constructed by
  /// [AiInputRepository.buildLinkedTasksJson] (pure data, no prompt logic).
  /// This method adds prompt-specific semantics:
  /// - A contextual note encouraging web search for external links (GitHub
  ///   PRs, Issues, etc.) when linked tasks with summaries are present
  ///
  /// This separation keeps the repository focused on data construction while
  /// prompt-building logic lives here.
  Future<String> _buildLinkedTasksJson(JournalEntity entity) async {
    String? taskId;
    if (entity is Task) {
      taskId = entity.id;
    } else {
      final linkedTask = await _findLinkedTask(entity);
      taskId = linkedTask?.id;
    }

    if (taskId == null) {
      return '{"linked_from": [], "linked_to": []}';
    }

    final json = await aiInputRepository.buildLinkedTasksJson(taskId);

    // Add contextual note if there are linked tasks
    final data = jsonDecode(json) as Map<String, dynamic>;
    final linkedFrom = data['linked_from'] as List<dynamic>? ?? [];
    final linkedTo = data['linked_to'] as List<dynamic>? ?? [];

    if (linkedFrom.isNotEmpty || linkedTo.isNotEmpty) {
      data['note'] =
          'If summaries contain links to GitHub PRs, Issues, or similar '
          'platforms, use web search to retrieve additional context when '
          'relevant.';
      const encoder = JsonEncoder.withIndent('    ');
      return encoder.convert(data);
    }

    // Return original JSON if no linked tasks (no note needed)
    return json;
  }

  /// Build the current task's latest summary for the given entity.
  ///
  /// Works with [Task] entities directly, or finds the linked task for
  /// images/audio via [_findLinkedTask].
  ///
  /// The summary typically contains learnings, annoyances, and key insights
  /// that can inform visual representation in image generation.
  ///
  /// Returns `[No task summary available]` if no summary exists.
  Future<String> _buildCurrentTaskSummary(JournalEntity entity) async {
    String? taskId;
    if (entity is Task) {
      taskId = entity.id;
    } else {
      final linkedTask = await _findLinkedTask(entity);
      taskId = linkedTask?.id;
    }

    if (taskId == null) {
      return '[No task summary available]';
    }

    // Get linked entities for legacy fallback
    final linkedEntities = await journalRepository.getLinkedToEntities(
      linkedTo: taskId,
    );

    // Use resolver: tries agent report first, then legacy AI summary
    final summary = await taskSummaryResolver.resolve(
      taskId,
      linkedEntities: linkedEntities,
    );

    if (summary == null) {
      developer.log(
        'No task summary found for task $taskId',
        name: 'PromptBuilderHelper',
      );
      return '[No task summary available]';
    }

    developer.log(
      'Found task summary for $taskId (${summary.length} chars)',
      name: 'PromptBuilderHelper',
    );
    return summary;
  }

  /// Returns raw speech dictionary terms for a given entity's category
  /// (or linked task's category), or an empty list if none are available.
  ///
  /// This is used both for prompt text injection (chat completions) and for
  /// Mistral's `context_bias` parameter (transcription endpoint).
  Future<List<String>> getSpeechDictionaryTerms(JournalEntity entity) async {
    // First check if the entity itself has a category
    var categoryId = entity.meta.categoryId;
    var source = 'entity';

    // If no direct category, try to get it from a linked task
    if (categoryId == null) {
      final task = entity is Task ? entity : await _findLinkedTask(entity);
      if (task != null) {
        categoryId = task.meta.categoryId;
        source = 'linked task';
      }
    }

    if (categoryId == null) {
      developer.log(
        'Speech dictionary: no category found for entity ${entity.id}',
        name: 'PromptBuilderHelper',
      );
      return [];
    }

    // Get the category from cache service
    CategoryDefinition? category;
    try {
      if (getIt.isRegistered<EntitiesCacheService>()) {
        final cache = getIt<EntitiesCacheService>();
        category = cache.getCategoryById(categoryId);
      }
    } catch (e) {
      developer.log(
        'Speech dictionary: error getting category $categoryId: $e',
        name: 'PromptBuilderHelper',
      );
      return [];
    }

    if (category == null) {
      developer.log(
        'Speech dictionary: category $categoryId not found in cache',
        name: 'PromptBuilderHelper',
      );
      return [];
    }

    // Get the speech dictionary
    final dictionary = category.speechDictionary;
    if (dictionary == null || dictionary.isEmpty) {
      developer.log(
        'Speech dictionary: category "${category.name}" has no dictionary',
        name: 'PromptBuilderHelper',
      );
      return [];
    }

    developer.log(
      'Speech dictionary: found ${dictionary.length} terms from '
      '$source category "${category.name}": ${dictionary.join(", ")}',
      name: 'PromptBuilderHelper',
    );

    return dictionary;
  }
}
