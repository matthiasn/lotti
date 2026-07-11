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
  });

  final TaskAgentReportDraft? report;
  final InferenceUsage? usage;
  final String? rejectionReason;
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
    final candidateContentLength = candidate.content.trim().length;
    final draftContentLength = draft.content.trim().length;
    if (candidateContentLength < 40) return 'report content is too short';
    if (candidateContentLength > draftContentLength * 1.25 + 80) {
      return 'report content grew beyond the allowed limit';
    }

    for (final id in _sourceIds(sourceContext)) {
      if (id.length >= 6 && candidateText.contains(id)) {
        return 'report exposes an internal ID';
      }
    }

    for (final url in _urls(_combinedText(draft))) {
      if (!candidateText.contains(url)) return 'report dropped an external URL';
    }

    final candidateNumbers = _numbers(candidateText);
    for (final number in _numbers(_combinedText(draft))) {
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

  static Set<String> _urls(String text) => RegExp(
    r'https?://[^\s)\]"]+',
  ).allMatches(text).map((match) => match.group(0)!).toSet();

  static Set<String> _numbers(String text) => RegExp(
    r'\b\d+(?:[.,]\d+)?\b',
  ).allMatches(text).map((match) => match.group(0)!).toSet();
}

/// Rewrites a completed task-agent report in an isolated report-only call.
class TaskAgentReportPolisher {
  TaskAgentReportPolisher({
    required this.conversationRepository,
    required this.inferenceRepository,
    this.validator = const TaskAgentReportPolishValidator(),
  });

  final ConversationRepository conversationRepository;
  final InferenceRepositoryInterface inferenceRepository;
  final TaskAgentReportPolishValidator validator;

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
        message: _polishMessage(draft: draft, sourceContext: sourceContext),
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
    required String sourceContext,
  }) =>
      '''
## Task context

$sourceContext

## Draft report

```json
${jsonEncode(draft.toJson())}
```

Rewrite only the draft report. Preserve every factual number, deadline, owner,
and external URL. Call `update_report` now.
''';
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
You edit an existing task report. You cannot change the task, checklist, or
metadata. Your only output is one `update_report` tool call.

Write the report in the task's language. Keep it concise and factual. Do not add
a title, emojis, empty sections, internal IDs, private reasoning, rejected or
deferred ideas, invented work, or descriptions of agent/tool activity.

Use only useful, non-empty sections:
- `## Progress` for meaningful completed outcomes.
- `## Next actions` for the few pending actions that matter now.
- `## Blockers` for active blockers or delivery risks.
- `## Decisions` for durable deadlines, owners, or constraints.
- `## Links` for real external URLs using descriptive Markdown links.

The `oneLiner` is a specific current-state tagline of at most 12 words. The
`tldr` is one or two sentences covering the current outcome and most important
next action, deadline, or blocker. Do not repeat the one-liner.
''';
