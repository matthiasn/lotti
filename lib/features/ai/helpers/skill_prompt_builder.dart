import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/consts.dart';

/// Assembles final system/user messages from an [AiConfigSkill]'s prose
/// instructions plus runtime context.
///
/// Users never see or edit placeholders — this is the only place they exist.
/// The builder injects them based on `skillType` + `contextPolicy`.
///
/// Context parameters are all optional strings that callers resolve from
/// repositories before calling [build]. This keeps the builder a pure
/// text-assembly layer with no I/O.
class SkillPromptBuilder {
  const SkillPromptBuilder();

  /// Builds the final system and user messages for a skill invocation.
  ///
  /// Returns a [SkillPromptResult] containing both messages ready for the
  /// inference provider.
  ///
  /// [entryContent] is the user-supplied input text for the skill — either
  /// the latest audio transcript (for `JournalAudio` sources) or the typed
  /// note body (for `JournalEntry` sources). Source-agnostic by design.
  SkillPromptResult build({
    required AiConfigSkill skill,
    String? speechDictionary,
    String? taskContext,
    String? linkedTasks,
    String? currentTaskSummary,
    String? entryContent,
    String? languageCode,
    String? correctionExamples,
  }) {
    final systemMessage = _buildSystemMessage(
      skill: skill,
      taskContext: taskContext,
      linkedTasks: linkedTasks,
    );

    final userMessage = _buildUserMessage(
      skill: skill,
      speechDictionary: speechDictionary,
      taskContext: taskContext,
      linkedTasks: linkedTasks,
      currentTaskSummary: currentTaskSummary,
      entryContent: entryContent,
      languageCode: languageCode,
      correctionExamples: correctionExamples,
    );

    return SkillPromptResult(
      systemMessage: systemMessage,
      userMessage: userMessage,
    );
  }

  String _buildSystemMessage({
    required AiConfigSkill skill,
    String? taskContext,
    String? linkedTasks,
  }) {
    final buffer = StringBuffer(skill.systemInstructions);

    // For fullTask context, add task context to system message for
    // image analysis (task context) variant.
    if (skill.contextPolicy == ContextPolicy.fullTask &&
        skill.skillType == SkillType.imageAnalysis &&
        taskContext != null) {
      buffer
        ..writeln()
        ..writeln()
        ..writeln('RELATED TASKS CONTEXT:')
        ..writeln(
          'You may receive a `linked_tasks` object containing related '
          'parent/child tasks.',
        )
        ..writeln(
          'Use this context to better understand what the image might be '
          'showing in relation to the broader project.',
        );
    }

    return buffer.toString();
  }

  String _buildUserMessage({
    required AiConfigSkill skill,
    String? speechDictionary,
    String? taskContext,
    String? linkedTasks,
    String? currentTaskSummary,
    String? entryContent,
    String? languageCode,
    String? correctionExamples,
  }) {
    final buffer = StringBuffer();
    final compactCoverArtPrompt = _usesCompactCoverArtPrompt(skill);

    // Add language code for image analysis (no task context) variant.
    if (skill.skillType == SkillType.imageAnalysis &&
        skill.contextPolicy != ContextPolicy.fullTask &&
        languageCode != null &&
        languageCode.isNotEmpty) {
      buffer
        ..writeln(languageCode)
        ..writeln();
    }

    // Write the skill's user instructions.
    buffer.write(skill.userInstructions);

    // Inject speaker identification rules for transcription skills.
    if (skill.skillType == SkillType.transcription) {
      buffer
        ..writeln()
        ..writeln()
        ..writeln(_speakerIdentificationRules);
    }

    // Inject speech dictionary for transcription skills or dictionaryOnly.
    if (skill.skillType == SkillType.transcription ||
        skill.contextPolicy == ContextPolicy.dictionaryOnly) {
      if (speechDictionary != null && speechDictionary.isNotEmpty) {
        buffer
          ..writeln()
          ..writeln()
          ..writeln(speechDictionary);
      }
    }

    if (compactCoverArtPrompt) {
      _appendCompactCoverArtPrompt(
        buffer,
        entryContent: entryContent,
        currentTaskSummary: currentTaskSummary,
      );
    }

    // Inject task context for fullTask and taskSummary policies.
    if (!compactCoverArtPrompt &&
        (skill.contextPolicy == ContextPolicy.fullTask ||
            skill.contextPolicy == ContextPolicy.taskSummary)) {
      _appendTaskContext(
        buffer,
        skill: skill,
        taskContext: taskContext,
        linkedTasks: linkedTasks,
        currentTaskSummary: currentTaskSummary,
      );
    }

    // Inject the user's entry content (audio transcript or text note) for
    // skills that consume the entry as their main input.
    if (!compactCoverArtPrompt &&
        (skill.skillType == SkillType.promptGeneration ||
            skill.skillType == SkillType.imagePromptGeneration ||
            skill.skillType == SkillType.imageGeneration)) {
      if (entryContent != null && entryContent.isNotEmpty) {
        buffer
          ..writeln()
          ..writeln()
          ..writeln('**Entry Notes:**')
          ..writeln(entryContent);
      }
    }

    // Inject URL formatting rules for image analysis skills.
    if (skill.skillType == SkillType.imageAnalysis) {
      buffer
        ..writeln()
        ..writeln()
        ..writeln(_urlFormattingRules);
    }

    // Inject correction examples for transcription skills.
    if (skill.skillType == SkillType.transcription &&
        correctionExamples != null &&
        correctionExamples.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln()
        ..writeln(correctionExamples);
    }

    return buffer.toString();
  }

  bool _usesCompactCoverArtPrompt(AiConfigSkill skill) {
    return skill.skillType == SkillType.imageGeneration &&
        skill.contextPolicy == ContextPolicy.taskSummary;
  }

  void _appendCompactCoverArtPrompt(
    StringBuffer buffer, {
    String? entryContent,
    String? currentTaskSummary,
  }) {
    final scene = _compactPromptText(entryContent);
    final mood = _compactPromptText(
      currentTaskSummary,
      maxLength: _maxCompactSummaryChars,
    );

    if (scene == null && mood == null) return;

    buffer
      ..writeln()
      ..writeln();

    if (scene != null) {
      buffer.writeln('Scene: $scene');
    }
    if (mood != null) {
      buffer.writeln('Mood and task clues: $mood');
    }
    buffer.writeln(
      'Render this as an image story only: no readable text, captions, UI, '
      'diagrams, logos, or watermark.',
    );
  }

  String? _compactPromptText(
    String? value, {
    int maxLength = _maxCompactSceneChars,
  }) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;

    final bounded = _safeUtf16Prefix(
      trimmed,
      maxLength * _compactPromptNormalizationLookaheadFactor,
    );
    final normalized = bounded.replaceAll(_compactPromptWhitespacePattern, ' ');
    if (normalized.length <= maxLength) return normalized;

    return '${_safeUtf16Prefix(normalized, maxLength).trimRight()}...';
  }

  String _safeUtf16Prefix(String value, int maxLength) {
    if (value.length <= maxLength) return value;

    var end = maxLength;
    if (end > 0 && _isUtf16LeadSurrogate(value.codeUnitAt(end - 1))) {
      end--;
    }
    return value.substring(0, end);
  }

  bool _isUtf16LeadSurrogate(int codeUnit) {
    return codeUnit >= 0xD800 && codeUnit <= 0xDBFF;
  }

  void _appendTaskContext(
    StringBuffer buffer, {
    required AiConfigSkill skill,
    String? taskContext,
    String? linkedTasks,
    String? currentTaskSummary,
  }) {
    // For transcription with task context, inject as terminology reference.
    if (skill.skillType == SkillType.transcription) {
      if (currentTaskSummary != null && currentTaskSummary.isNotEmpty) {
        buffer
          ..writeln()
          ..writeln()
          ..writeln(
            '**Task context (for terminology only, do NOT include in '
            'output):**',
          )
          ..writeln(currentTaskSummary);
      }
      return;
    }

    // taskSummary policy: inject only the current task summary, not the
    // full task JSON or linked tasks.
    if (skill.contextPolicy == ContextPolicy.taskSummary) {
      if (currentTaskSummary != null && currentTaskSummary.isNotEmpty) {
        buffer
          ..writeln()
          ..writeln()
          ..writeln('**Task Summary:**')
          ..writeln(currentTaskSummary);
      }
      return;
    }

    // For other skills, inject full task JSON + linked tasks.
    if (taskContext != null && taskContext.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln()
        ..writeln('**Task Context:**')
        ..writeln('```json')
        ..writeln(taskContext)
        ..writeln('```');
    }

    if (linkedTasks != null && linkedTasks.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('**Related Tasks:**')
        ..writeln('```json')
        ..writeln(linkedTasks)
        ..writeln('```');
    }

    // For image generation, inject current task summary.
    if (skill.skillType == SkillType.imageGeneration &&
        currentTaskSummary != null &&
        currentTaskSummary.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('**Task Summary (includes learnings and annoyances):**')
        ..writeln(currentTaskSummary);
    }
  }
}

/// The result of building a skill prompt, containing both system and user
/// messages ready for the inference provider.
class SkillPromptResult {
  const SkillPromptResult({
    required this.systemMessage,
    required this.userMessage,
  });

  final String systemMessage;
  final String userMessage;
}

/// Speaker identification rules injected into transcription skill prompts.
const _speakerIdentificationRules = '''
SPEAKER IDENTIFICATION RULES (CRITICAL):
- If there is only ONE speaker, do NOT use any speaker labels. Just output the text directly.
- If there are MULTIPLE speakers (2 or more distinct voices), label them as "Speaker 1:", "Speaker 2:", etc.
- NEVER assume or guess speaker identities or names.
- NEVER use names from the dictionary or context to identify speakers.
- You do NOT know who is speaking - only that different voices exist.
- Use ONLY generic numbered labels (e.g., "Speaker 1:", "Speaker 2:", etc.) for speaker changes.''';

/// URL formatting rules injected into image analysis skill prompts.
const _urlFormattingRules = '''
URL FORMATTING RULES:
- Any URL found in the image (e.g., in a browser address bar) MUST be formatted as a Markdown link: [Link Title](URL)
- If the visible URL lacks a protocol (e.g., "github.com/pulls"), prepend https:// — always assume HTTPS unless http:// is explicitly visible.''';

const _maxCompactSceneChars = 700;
const _maxCompactSummaryChars = 500;
const _compactPromptNormalizationLookaheadFactor = 2;
final _compactPromptWhitespacePattern = RegExp(r'\s+');
