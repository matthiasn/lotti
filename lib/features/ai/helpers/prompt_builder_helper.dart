import 'dart:convert';
import 'dart:developer' as developer;

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

/// Maximum number of correction examples to inject into prompts.
/// Examples beyond this limit are not injected (but remain stored for future use).
const int _kMaxCorrectionExamples = 500;

/// Template for the correction examples prompt injection.
/// The {examples} placeholder will be replaced with the actual examples.
const String _kCorrectionExamplesPromptTemplate = '''
USER-PROVIDED CORRECTION EXAMPLES:
The user has manually corrected these checklist item titles in the past.
When creating or updating items, apply these corrections when you see matching patterns.

{examples}
''';

/// Template for the speech dictionary prompt injection.
/// The {terms} placeholder will be replaced with the actual dictionary terms.
const String _kSpeechDictionaryPromptTemplate = '''
IMPORTANT - SPEECH DICTIONARY (MUST USE):
The following terms are domain-specific and MUST be spelled exactly as shown when they appear in the audio.
Speech recognition often misinterprets these terms. When you hear anything that sounds like these terms,
you MUST use the exact spelling and casing provided below - do NOT use alternative spellings.

Required spellings: {terms}

Examples of what to correct:
- "mac OS" or "Mac OS" → use the dictionary spelling if "macOS" is listed
- "i phone" or "I Phone" → use the dictionary spelling if "iPhone" is listed
- Any phonetically similar word → use the exact dictionary term''';

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

    // Inject correction examples if requested (checklist updates + audio transcription)
    if (prompt.contains('{{correction_examples}}') &&
        (promptConfig.aiResponseType == AiResponseType.checklistUpdates ||
            promptConfig.aiResponseType == AiResponseType.audioTranscription)) {
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

  /// Get language code for a given entity.
  /// For tasks, returns the task's language code directly.
  /// For images and audio, looks for a linked task and returns its language code.
  Future<String?> _getLanguageCodeForEntity(JournalEntity entity) async {
    final task = entity is Task ? entity : await _findLinkedTask(entity);
    return task?.data.languageCode;
  }

  /// Build speech dictionary prompt text for a given entity.
  /// Returns formatted text with dictionary terms from the task's category,
  /// or empty string if no dictionary is available.
  Future<String> _buildSpeechDictionaryPromptText(JournalEntity entity) async {
    // Get the task (directly or via linked entity)
    final task = entity is Task ? entity : await _findLinkedTask(entity);
    if (task == null) {
      developer.log(
        'Speech dictionary: no task found for entity ${entity.id}',
        name: 'PromptBuilderHelper',
      );
      return '';
    }

    // Get the category ID from the task
    final categoryId = task.meta.categoryId;
    if (categoryId == null) {
      developer.log(
        'Speech dictionary: task ${task.id} has no category',
        name: 'PromptBuilderHelper',
      );
      return '';
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
      return '';
    }

    if (category == null) {
      developer.log(
        'Speech dictionary: category $categoryId not found in cache',
        name: 'PromptBuilderHelper',
      );
      return '';
    }

    // Get the speech dictionary
    final dictionary = category.speechDictionary;
    if (dictionary == null || dictionary.isEmpty) {
      developer.log(
        'Speech dictionary: category "${category.name}" has no dictionary',
        name: 'PromptBuilderHelper',
      );
      return '';
    }

    developer.log(
      'Speech dictionary: injecting ${dictionary.length} terms from '
      'category "${category.name}": ${dictionary.join(", ")}',
      name: 'PromptBuilderHelper',
    );

    // Format the dictionary terms as prompt text
    // Escape quotes, backslashes, and newlines for safety
    String escapeForJson(String s) => s
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n');
    final termsJson = dictionary.map((t) => '"${escapeForJson(t)}"').join(', ');

    return _kSpeechDictionaryPromptTemplate.replaceAll(
        '{terms}', '[$termsJson]');
  }

  /// Build correction examples prompt text for a given entity.
  /// Returns formatted text with examples from the task's category,
  /// or empty string if no examples are available.
  ///
  /// INTENTIONAL: Uses cache-only lookup (no repository fallback) matching
  /// the speech dictionary pattern. If cache is not populated (cold start, tests),
  /// injection returns empty. Tests must stub EntitiesCacheService registration.
  Future<String> _buildCorrectionExamplesPromptText(
      JournalEntity entity) async {
    // Get the task (directly or via linked entity)
    final task = entity is Task ? entity : await _findLinkedTask(entity);
    if (task == null) {
      developer.log(
        'Correction examples: no task found for entity ${entity.id}',
        name: 'PromptBuilderHelper',
      );
      return '';
    }

    // Get the category ID from the task
    final categoryId = task.meta.categoryId;
    if (categoryId == null) {
      developer.log(
        'Correction examples: task ${task.id} has no category',
        name: 'PromptBuilderHelper',
      );
      return '';
    }

    // Get the category from cache service (INTENTIONAL: no repo fallback)
    CategoryDefinition? category;
    try {
      if (getIt.isRegistered<EntitiesCacheService>()) {
        final cache = getIt<EntitiesCacheService>();
        category = cache.getCategoryById(categoryId);
      }
    } catch (e) {
      developer.log(
        'Correction examples: error getting category $categoryId: $e',
        name: 'PromptBuilderHelper',
      );
      return '';
    }

    if (category == null) {
      developer.log(
        'Correction examples: category $categoryId not found in cache',
        name: 'PromptBuilderHelper',
      );
      return '';
    }

    // Get the correction examples
    final examples = category.correctionExamples;
    if (examples == null || examples.isEmpty) {
      developer.log(
        'Correction examples: category "${category.name}" has no examples',
        name: 'PromptBuilderHelper',
      );
      return '';
    }

    // Sort by capturedAt descending (most recent first) and cap at limit
    final sortedExamples = [...examples]..sort((a, b) {
        final aTime = a.capturedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.capturedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime); // Descending (most recent first)
      });
    final cappedExamples =
        sortedExamples.take(_kMaxCorrectionExamples).toList();

    developer.log(
      'Correction examples: injecting ${cappedExamples.length} examples '
      '(of ${examples.length} total) from category "${category.name}"',
      name: 'PromptBuilderHelper',
    );

    // Format examples as "before" -> "after" pairs
    final formattedExamples = cappedExamples.map((e) {
      final escapedBefore = e.before.replaceAll('"', r'\"');
      final escapedAfter = e.after.replaceAll('"', r'\"');
      return '- "$escapedBefore" → "$escapedAfter"';
    }).join('\n');

    return _kCorrectionExamplesPromptTemplate.replaceAll(
      '{examples}',
      formattedExamples,
    );
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

  /// Resolve audio transcript from a JournalAudio entity.
  /// Prioritizes user-edited text over original transcript.
  /// Returns a fallback message if no transcript is available.
  String _resolveAudioTranscript(JournalEntity entity) {
    if (entity is! JournalAudio) {
      return '[Audio entry expected but received ${entity.runtimeType}]';
    }

    // Reuse existing text resolution logic
    final text = _resolveEntryText(entity);
    if (text.isNotEmpty) {
      return text;
    }

    return '[No transcription available]';
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
