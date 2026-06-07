part of 'prompt_builder_helper.dart';

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

/// Placeholder-resolution helpers split out of [PromptBuilderHelper] purely
/// for file size; they run in the same library via `part`, so private
/// members stay accessible from `buildPromptWithData`. The mocked public
/// surface (`getSpeechDictionaryTerms` & friends) stays on the class.
extension _PromptPlaceholderResolvers on PromptBuilderHelper {
  /// Get task JSON for a given entity
  /// For images and audio, looks for linked tasks
  /// For tasks, directly gets the task JSON
  Future<String?> _getTaskJsonForEntity(JournalEntity entity) async {
    if (entity is Task) {
      // Direct task entity
      return this.aiInputRepository.buildTaskDetailsJson(id: entity.id);
    } else if (entity is JournalImage || entity is JournalAudio) {
      // For images and audio, check if they are linked to a task
      final linkedTask = await _findLinkedTask(entity);
      if (linkedTask != null) {
        final json = await this.aiInputRepository.buildTaskDetailsJson(
          id: linkedTask.id,
        );
        return json;
      }
    }
    return null;
  }

  /// Find a task that this entity is linked to.
  ///
  /// Links can exist in either direction depending on how the entry was created:
  /// 1. `entry → task` (entry links TO task) - when entry explicitly references a task
  /// 2. `task → entry` (task links TO entry) - when entry is added as a child of task
  ///
  /// We check both directions, preferring direction 1 when available to avoid
  /// picking the wrong task when multiple tasks link to the same entry.
  Future<Task?> _findLinkedTask(JournalEntity entity) async {
    // First, try to find tasks that this entry links TO (entry → task).
    // This is the preferred direction as it's an explicit reference.
    final linkedEntities = await this.journalRepository.getLinkedEntities(
      linkedTo: entity.id,
    );
    final task =
        linkedEntities.firstWhereOrNull(
              (linked) => linked is Task,
            )
            as Task?;

    if (task != null) return task;

    // Fallback: find tasks that link TO this entry (task → entry).
    // This handles the case where entry was added as a child of a task.
    final fallbackEntities = await this.journalRepository.getLinkedToEntities(
      linkedTo: entity.id,
    );
    return fallbackEntities.firstWhereOrNull(
          (linked) => linked is Task,
        )
        as Task?;
  }

  /// Get language code for a given entity.
  /// For tasks, returns the task's language code directly.
  /// For images and audio, looks for a linked task and returns its language code.
  Future<String?> _getLanguageCodeForEntity(JournalEntity entity) async {
    final task = entity is Task ? entity : await _findLinkedTask(entity);
    return task?.data.languageCode;
  }

  /// Build speech dictionary prompt text for a given entity.
  /// Returns formatted text with dictionary terms from the entity's category
  /// (or linked task's category), or empty string if no dictionary is available.
  Future<String> _buildSpeechDictionaryPromptText(JournalEntity entity) async {
    final dictionary = await getSpeechDictionaryTerms(entity);
    if (dictionary.isEmpty) return '';

    // Format the dictionary terms as prompt text
    // Escape quotes, backslashes, and newlines for safety
    String escapeForJson(String s) => s
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n');
    final termsJson = dictionary.map((t) => '"${escapeForJson(t)}"').join(', ');

    return _kSpeechDictionaryPromptTemplate.replaceAll(
      '{terms}',
      '[$termsJson]',
    );
  }

  /// Build correction examples prompt text for a given entity.
  /// Returns formatted text with examples from the task's category,
  /// or empty string if no examples are available.
  ///
  /// INTENTIONAL: Uses cache-only lookup (no repository fallback) matching
  /// the speech dictionary pattern. If cache is not populated (cold start, tests),
  /// injection returns empty. Tests must stub EntitiesCacheService registration.
  Future<String> _buildCorrectionExamplesPromptText(
    JournalEntity entity,
  ) async {
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
    final sortedExamples = [...examples]
      ..sort((a, b) {
        final aTime = a.capturedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.capturedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime); // Descending (most recent first)
      });
    final cappedExamples = sortedExamples
        .take(_kMaxCorrectionExamples)
        .toList();

    developer.log(
      'Correction examples: injecting ${cappedExamples.length} examples '
      '(of ${examples.length} total) from category "${category.name}"',
      name: 'PromptBuilderHelper',
    );

    // Format examples as "before" -> "after" pairs
    final formattedExamples = cappedExamples
        .map((e) {
          final escapedBefore = e.before.replaceAll('"', r'\"');
          final escapedAfter = e.after.replaceAll('"', r'\"');
          return '- "$escapedBefore" → "$escapedAfter"';
        })
        .join('\n');

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
    _loggingService?.error(
      LogDomain.ai,
      'Failed to inject {{$placeholder}} for entity=${entity.id}$suffix: $error',
      stackTrace: stackTrace,
      subDomain: 'placeholder_injection',
    );
  }
}
