import 'dart:convert';

import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
import 'package:openai_dart/openai_dart.dart';

/// Immutable report fields produced by a task-agent wake.
class TaskAgentReportDraft {
  const TaskAgentReportDraft({
    required this.oneLiner,
    required this.tldr,
    required this.content,
  });

  final String oneLiner;
  final String tldr;
  final String content;

  bool get isComplete =>
      oneLiner.trim().isNotEmpty &&
      tldr.trim().isNotEmpty &&
      content.trim().isNotEmpty;

  Map<String, String> toJson() => {
    'oneLiner': oneLiner,
    'tldr': tldr,
    'content': content,
  };
}

/// Result of an optional polishing request.
class TaskAgentReportPolishAttempt {
  const TaskAgentReportPolishAttempt({
    required this.usage,
    this.report,
    this.rejectionReason,
    this.skipped = false,
  });

  final TaskAgentReportDraft? report;
  final InferenceUsage? usage;
  final String? rejectionReason;
  final bool skipped;
}

/// Validates that a polished report remains a safe projection of its draft.
class TaskAgentReportPolishValidator {
  const TaskAgentReportPolishValidator();

  String? rejectionReason({
    required TaskAgentReportDraft draft,
    required TaskAgentReportDraft candidate,
    required String sourceContext,
  }) {
    if (!candidate.isComplete) return 'missing report fields';

    final candidateText = _combinedText(candidate);
    final sourceIds = _protectedSourceIds(sourceContext);
    final candidateContentLength = candidate.content.trim().length;
    final draftContentLength = draft.content.trim().length;
    if (candidateContentLength < 40) return 'report content is too short';
    if (candidateContentLength > draftContentLength * 1.25 + 80) {
      return 'report content grew beyond the allowed limit';
    }

    for (final id in sourceIds) {
      if (candidateText.contains(id)) {
        return 'report exposes an internal ID';
      }
    }

    for (final url in _urls(_combinedText(draft))) {
      if (!candidateText.contains(url)) return 'report dropped an external URL';
    }

    final candidateNumbers = _numbers(candidateText);
    var draftFactsText = _combinedText(draft);
    for (final id in sourceIds) {
      draftFactsText = draftFactsText.replaceAll(id, '');
    }
    for (final number in _numbers(draftFactsText)) {
      if (!candidateNumbers.contains(number)) return 'report dropped a number';
    }

    return null;
  }

  static String _combinedText(TaskAgentReportDraft report) =>
      '${report.oneLiner}\n${report.tldr}\n${report.content}';

  static Set<String> _sourceIds(String sourceContext) {
    const idKey = '(?:id|[A-Za-z][A-Za-z0-9_]*Ids?|[A-Za-z][A-Za-z0-9_]*_ids?)';
    final ids = RegExp(
      '"$idKey"\\s*:\\s*"([^"]+)"',
    ).allMatches(sourceContext).map((match) => match.group(1)!).toSet();
    for (final match in RegExp(
      '"$idKey"\\s*:\\s*\\[([^\\]]*)\\]',
    ).allMatches(sourceContext)) {
      ids.addAll(
        RegExp(
          '"([^"]+)"',
        ).allMatches(match.group(1)!).map((item) => item.group(1)!),
      );
    }
    return ids;
  }

  static Set<String> _protectedSourceIds(String sourceContext) => _sourceIds(
    sourceContext,
  ).where((id) => id.length >= 6).toSet();

  static Set<String> _urls(String text) => RegExp(
    r'https?://[^\s)\]"]+',
  ).allMatches(text).map((match) => match.group(0)!).toSet();

  static Set<String> _numbers(String text) => RegExp(
    r'\b\d+(?:[.,]\d+)?\b',
  ).allMatches(text).map((match) => match.group(0)!).toSet();
}

/// Objective signals that justify spending another inference call on a draft.
enum TaskAgentReportPolishWarning {
  /// A source identifier is visible in the user-facing draft.
  internalId('remove visible internal identifiers'),

  /// A Markdown section has no content.
  emptySection('remove empty Markdown sections'),

  /// The same bullet appears more than once.
  duplicateBullet('remove duplicate bullet items'),

  /// The draft describes internal tool or agent mechanics.
  processNarration('remove agent or tool-process narration'),

  /// The draft repeats an idea only to explain that it was excluded.
  excludedIdeaNarration(
    'remove rejected or deferred ideas that are mentioned only as exclusions',
  ),

  /// The compact card tagline has become sentence-like prose.
  longOneLiner('shorten the one-liner while preserving its specific meaning'),

  /// The collapsed summary is too long to scan.
  longTldr('shorten the TLDR while preserving its material facts'),

  /// The expanded report has grown beyond a useful copy-editing budget.
  longContent('remove repetition from the report body');

  const TaskAgentReportPolishWarning(this.instruction);

  /// Focus instruction sent to the isolated copy-editing turn.
  final String instruction;
}

/// Decides whether a completed draft has an objective copy-editing need.
class TaskAgentReportPolishPolicy {
  const TaskAgentReportPolishPolicy();

  static const maxOneLinerWords = 16;
  static const maxTldrWords = 60;
  static const maxContentCharacters = 2400;

  Set<TaskAgentReportPolishWarning> warnings({
    required TaskAgentReportDraft draft,
    required String sourceContext,
  }) {
    final warnings = <TaskAgentReportPolishWarning>{};
    final draftText = TaskAgentReportPolishValidator._combinedText(draft);

    if (TaskAgentReportPolishValidator._protectedSourceIds(
      sourceContext,
    ).any(draftText.contains)) {
      warnings.add(TaskAgentReportPolishWarning.internalId);
    }
    if (_hasEmptyMarkdownSection(draft.content)) {
      warnings.add(TaskAgentReportPolishWarning.emptySection);
    }
    if (_hasDuplicateBullet(draft.content)) {
      warnings.add(TaskAgentReportPolishWarning.duplicateBullet);
    }
    if (_processNarrationPattern.hasMatch(draftText)) {
      warnings.add(TaskAgentReportPolishWarning.processNarration);
    }
    if (_excludedIdeaPattern.hasMatch(draftText)) {
      warnings.add(TaskAgentReportPolishWarning.excludedIdeaNarration);
    }
    if (_wordCount(draft.oneLiner) > maxOneLinerWords) {
      warnings.add(TaskAgentReportPolishWarning.longOneLiner);
    }
    if (_wordCount(draft.tldr) > maxTldrWords) {
      warnings.add(TaskAgentReportPolishWarning.longTldr);
    }
    if (draft.content.length > maxContentCharacters) {
      warnings.add(TaskAgentReportPolishWarning.longContent);
    }

    return warnings;
  }

  static final _processNarrationPattern = RegExp(
    r'(?:(?:\b(?:called|invoked|used|ran)|\b(?:via|through))\s+'
    '`?(?:update_report|record_observations)`?'
    r'|\b(?:tool|function)[ -]calls?\b'
    r'|\bas (?:an ai|the task agent)\b'
    r'|\b(?:internal|private) reasoning\b)',
    caseSensitive: false,
  );

  static final _excludedIdeaPattern = RegExp(
    r'(?:\b(?:explicitly|deliberately) not (?:included|added)\b'
    r'|\b(?:was|were) (?:explicitly )?not (?:included|added)\b'
    r'|\bnoch nicht aufnehmen\b'
    r'|\bnicht aufgenommen\b'
    r'|\bno (?:incluir|se incluyo)\b'
    r'|\bne pas inclure\b'
    r'|\bnu (?:include|a fost inclus)\b'
    r'|\bnezahrnovat\b)',
    caseSensitive: false,
  );

  static bool _hasEmptyMarkdownSection(String content) {
    var inCodeFence = false;
    var insideSection = false;
    var sectionHasContent = false;
    int? sectionLevel;

    for (final line in const LineSplitter().convert(content)) {
      final trimmed = line.trim();
      if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
        if (insideSection) sectionHasContent = true;
        inCodeFence = !inCodeFence;
        continue;
      }
      if (inCodeFence) continue;

      final headingMatch = _sectionHeadingPattern.firstMatch(trimmed);
      if (headingMatch != null) {
        final nextLevel = headingMatch.group(1)!.length;
        if (insideSection && !sectionHasContent && nextLevel <= sectionLevel!) {
          return true;
        }
        insideSection = true;
        sectionHasContent = false;
        sectionLevel = nextLevel;
      } else if (insideSection && trimmed.isNotEmpty) {
        sectionHasContent = true;
      }
    }

    return insideSection && !sectionHasContent;
  }

  static bool _hasDuplicateBullet(String content) {
    final seen = <String>{};
    var inCodeFence = false;
    final bulletPattern = RegExp(
      r'^\s*(?:[-+*]|\d+[.)])\s+(?:\[[ xX]\]\s+)?(.+?)\s*$',
    );

    for (final line in const LineSplitter().convert(content)) {
      final trimmed = line.trim();
      if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
        inCodeFence = !inCodeFence;
        continue;
      }
      if (inCodeFence) continue;

      final match = bulletPattern.firstMatch(line);
      if (match == null) continue;
      final normalized = match
          .group(1)!
          .toLowerCase()
          .replaceAll(
            RegExp(r'\s+'),
            ' ',
          );
      if (!seen.add(normalized)) return true;
    }

    return false;
  }

  static int _wordCount(String text) =>
      text.trim().split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length;

  static final _sectionHeadingPattern = RegExp(r'^(#{2,6})\s+\S');
}

/// Rewrites a completed task-agent report in an isolated report-only call.
class TaskAgentReportPolisher {
  TaskAgentReportPolisher({
    required this.conversationRepository,
    required this.inferenceRepository,
    this.validator = const TaskAgentReportPolishValidator(),
    this.policy = const TaskAgentReportPolishPolicy(),
  });

  final ConversationRepository conversationRepository;
  final InferenceRepositoryInterface inferenceRepository;
  final TaskAgentReportPolishValidator validator;
  final TaskAgentReportPolishPolicy policy;

  Future<TaskAgentReportPolishAttempt> polish({
    required TaskAgentReportDraft draft,
    required String sourceContext,
    required String model,
    required AiConfigInferenceProvider provider,
    required ChatCompletionTool reportTool,
    String? consumptionAgentId,
    String? consumptionTaskId,
    String? consumptionCategoryId,
    String? consumptionWakeRunKey,
    String? consumptionThreadId,
  }) async {
    if (!draft.isComplete) {
      return const TaskAgentReportPolishAttempt(
        usage: null,
        rejectionReason: 'draft report is incomplete',
        skipped: true,
      );
    }

    final warnings = policy.warnings(
      draft: draft,
      sourceContext: sourceContext,
    );
    if (warnings.isEmpty) {
      return const TaskAgentReportPolishAttempt(
        usage: null,
        rejectionReason: 'draft has no copy-editing warnings',
        skipped: true,
      );
    }

    final conversationId = conversationRepository.createConversation(
      systemMessage: _polishSystemPrompt,
      maxTurns: 2,
    );
    final strategy = TaskAgentReportPolishStrategy();
    try {
      final usage = await conversationRepository.sendMessage(
        conversationId: conversationId,
        message: _polishMessage(
          draft: draft,
          warnings: warnings,
          languageCode: _sourceLanguageCode(sourceContext),
        ),
        model: model,
        provider: provider,
        inferenceRepo: inferenceRepository,
        tools: [reportTool],
        toolChoice: const ChatCompletionToolChoiceOption.tool(
          ChatCompletionNamedToolChoice(
            type: ChatCompletionNamedToolChoiceType.function,
            function: ChatCompletionFunctionCallOption(
              name: TaskAgentToolNames.updateReport,
            ),
          ),
        ),
        temperature: 0.2,
        strategy: strategy,
        consumptionAgentId: consumptionAgentId,
        consumptionTaskId: consumptionTaskId,
        consumptionCategoryId: consumptionCategoryId,
        consumptionWakeRunKey: consumptionWakeRunKey,
        consumptionThreadId: consumptionThreadId,
      );
      final candidate = strategy.report;
      if (candidate == null) {
        return TaskAgentReportPolishAttempt(
          usage: usage,
          rejectionReason: 'model did not return a complete report',
        );
      }
      final rejectionReason = validator.rejectionReason(
        draft: draft,
        candidate: candidate,
        sourceContext: sourceContext,
      );
      return TaskAgentReportPolishAttempt(
        usage: usage,
        report: rejectionReason == null ? candidate : null,
        rejectionReason: rejectionReason,
      );
    } finally {
      conversationRepository.deleteConversation(conversationId);
    }
  }

  static String _polishMessage({
    required TaskAgentReportDraft draft,
    required Set<TaskAgentReportPolishWarning> warnings,
    required String? languageCode,
  }) =>
      '''
## Draft report

```json
${jsonEncode(draft.toJson())}
```

${languageCode == null ? '' : 'Task language: `$languageCode`.\n\n'}## Copy-edit focus

${warnings.map((warning) => '- ${warning.instruction}').join('\n')}

Make the smallest useful edit. Preserve every factual number, deadline, owner,
external URL, and intentional Markdown choice. Call `update_report` now.
''';

  static String? _sourceLanguageCode(String sourceContext) => RegExp(
    r'"(?:languageCode|language_code)"\s*:\s*"([^"]+)"',
  ).firstMatch(sourceContext)?.group(1);
}

/// Captures the single report tool call returned by an isolated polish turn.
class TaskAgentReportPolishStrategy extends ConversationStrategy {
  TaskAgentReportDraft? report;

  @override
  Future<ConversationAction> processToolCalls({
    required List<ChatCompletionMessageToolCall> toolCalls,
    required ConversationManager manager,
  }) async {
    for (final call in toolCalls) {
      if (call.function.name != TaskAgentToolNames.updateReport) continue;
      final decoded = jsonDecode(call.function.arguments);
      if (decoded is! Map<String, dynamic>) continue;
      final oneLiner = decoded['oneLiner'];
      final tldr = decoded['tldr'];
      final content = decoded['content'];
      if (oneLiner is String && tldr is String && content is String) {
        final candidate = TaskAgentReportDraft(
          oneLiner: oneLiner.trim(),
          tldr: tldr.trim(),
          content: content.trim(),
        );
        if (candidate.isComplete) report = candidate;
      }
      manager.addToolResponse(
        toolCallId: call.id,
        response: report == null ? 'Invalid report.' : 'Report accepted.',
      );
    }
    return ConversationAction.complete;
  }

  @override
  bool shouldContinue(ConversationManager manager) => false;

  @override
  String? getContinuationPrompt(ConversationManager manager) => null;
}

const _polishSystemPrompt = '''
You minimally copy-edit an existing task report. You cannot change the task,
checklist, or metadata. Your only output is one `update_report` tool call.

Preserve the draft's language, voice, Markdown structure, headings, emojis, and
choice of useful sections unless a listed warning requires a local change. Any
useful Markdown structure is valid; never impose a standard template or add a
section merely to fit one.

Change only what is needed to address the listed warnings. Keep all material
facts, deadlines, owners, decisions, and links. Do not invent work, expose
internal IDs or private reasoning, describe agent/tool activity, or repeat a
rejected or deferred idea merely to explain that it was excluded.
''';
