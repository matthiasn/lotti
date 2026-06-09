import 'dart:convert';
import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/observation_record.dart';
import 'package:lotti/features/agents/service/suggestion_retraction_service.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/time_entry_datetime.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/workflow/change_proposal_filter.dart';
import 'package:lotti/features/agents/workflow/change_set_builder.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:meta/meta.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:uuid/uuid.dart';

export 'package:lotti/features/agents/model/observation_record.dart'
    show ObservationRecord;

part 'task_agent_tool_handlers.dart';
part 'task_agent_change_handlers.dart';

/// Callback that resolves a journal entity's category ID from its entity ID.
typedef ResolveCategoryId = Future<String?> Function(String entityId);

/// Callback that reads the current vector clock of a journal entity.
typedef ReadVectorClock = Future<VectorClock?> Function(String entityId);

/// Callback that executes a tool handler and returns a [ToolExecutionResult].
///
/// The callback receives the tool name, decoded arguments map, and the
/// [ConversationManager] (so the handler can add tool responses to the
/// conversation history). It must return a [ToolExecutionResult] with at
/// minimum the [ToolExecutionResult.success] and [ToolExecutionResult.output]
/// fields populated.
typedef ExecuteToolHandler =
    Future<ToolExecutionResult> Function(
      String toolName,
      Map<String, dynamic> args,
      ConversationManager manager,
    );

/// [ConversationStrategy] implementation for the Task Agent.
///
/// Dispatches tool calls to existing journal-domain handlers wrapped by
/// [AgentToolExecutor] for category enforcement, audit logging, and
/// self-notification suppression. Two tools are handled locally:
///
/// - `update_report` — the LLM publishes its report via this tool call;
///   the markdown is accumulated and retrieved via [extractReportContent].
///   The compact subtitle/tagline is retrieved via [extractReportOneLiner].
/// - `record_observations` — private notes for future wakes; accumulated
///   and retrieved via [extractObservations].
///
/// Each message (assistant response, tool call, tool result) is persisted to
/// `agent.sqlite` as an [AgentMessageEntity].
///
/// After the conversation completes, callers use [extractReportContent] and
/// [extractObservations] to obtain the LLM's output. The final assistant text
/// response (which may contain `<think>` tags or other reasoning) is captured
/// separately via [recordFinalResponse] and can be persisted as a thought.
class TaskAgentStrategy extends ConversationStrategy {
  TaskAgentStrategy({
    required this.executor,
    required this.syncService,
    required this.agentId,
    required this.threadId,
    required this.runKey,
    required this.taskId,
    required this.resolveCategoryId,
    required this.readVectorClock,
    required this.executeToolHandler,
    this.changeSetBuilder,
    this.retractionService,
    this.resolveTaskMetadata,
    this.resolveRelatedTaskDetails,
    this.allowedRelatedTaskIds = const <String>{},
    this.resolveEditableTimeEntryIds,
    this.resolveRunningTimerId,
  });

  /// The [AgentToolExecutor] that wraps handler calls with enforcement and
  /// audit logging.
  final AgentToolExecutor executor;

  /// Sync-aware write service for persisting messages. All writes go through
  /// this so they are automatically enqueued for cross-device sync.
  final AgentSyncService syncService;

  /// The agent's stable ID.
  final String agentId;

  /// The conversation thread ID for the current wake.
  final String threadId;

  /// The run key for the current wake cycle.
  final String runKey;

  /// The journal-domain task ID this agent is working on.
  final String taskId;

  /// Resolves a journal entity's category ID.
  final ResolveCategoryId resolveCategoryId;

  /// Reads the current vector clock of a journal entity.
  final ReadVectorClock readVectorClock;

  /// Executes a named tool handler with arguments.
  final ExecuteToolHandler executeToolHandler;

  /// Optional builder for accumulating deferred tool calls into a change set.
  ///
  /// When provided, tools listed in [AgentToolRegistry.deferredTools] are
  /// routed to the builder instead of being executed immediately. The change
  /// set is persisted at the end of the wake via [ChangeSetBuilder.build].
  final ChangeSetBuilder? changeSetBuilder;

  /// Optional service for handling agent-autonomous `retract_suggestions`
  /// tool calls. When omitted, the tool call is rejected with an error
  /// response — retraction is always available to the LLM as part of the
  /// task-agent tool surface, but tests / specialized strategies may elect
  /// to leave the wiring off.
  final SuggestionRetractionService? retractionService;

  /// Optional resolver for the current task metadata. Used to detect and
  /// suppress redundant non-batch tool proposals (e.g. setting priority to
  /// the value it already has).
  final ResolveTaskMetadata? resolveTaskMetadata;

  /// Optional read-only resolver for sibling-task drill-down context.
  final Future<String?> Function(String requestedTaskId)?
  resolveRelatedTaskDetails;

  /// Allowlist of sibling task IDs exposed in the current wake payload.
  final Set<String> allowedRelatedTaskIds;

  /// Optional resolver for the set of completed time-entry ids linked to this
  /// task — the only ids `update_time_entry` may target. When provided, an
  /// `entryId` outside this set is rejected as a hallucinated id rather than
  /// queued as a proposal that could not be applied. A transient resolver
  /// failure keeps the proposal (we cannot prove the id is fake).
  final Future<Set<String>> Function()? resolveEditableTimeEntryIds;

  /// Optional resolver for the id of the timer currently running for THIS
  /// task, or null when no such timer is running. When provided,
  /// `update_running_timer` is rejected unless its `timerId` matches.
  final Future<String?> Function()? resolveRunningTimerId;

  String? _reportContent;
  String? _reportTldr;
  String? _reportOneLiner;
  String? _finalResponse;
  final _observations = <ObservationRecord>[];
  TaskMetadataSnapshot? _cachedTaskMetadata;
  bool _taskMetadataResolved = false;

  /// Tracks deferred tool names that have already been successfully queued
  /// in this wake. Prevents smaller models from burning all turns on a
  /// single tool (e.g. calling `set_task_title` 4 times).
  final _usedDeferredTools = <String>{};

  /// Retractions the agent requested via `retract_suggestions` this wake.
  ///
  /// They are validated immediately (so the LLM gets accurate per-entry
  /// feedback) but their persistence is deferred to the end of the wake so it
  /// commits atomically with the new proposals — otherwise the suggestion list
  /// flashes empty for the seconds between a mid-wake retraction write and the
  /// end-of-wake proposal write. Applied by the workflow via
  /// [SuggestionRetractionService.applyStaged].
  final _stagedRetractions = <StagedRetraction>[];

  /// Target item keys (`'<changeSetId>:<itemIndex>'`) already staged this wake,
  /// so repeated `retract_suggestions` calls don't stage the same item twice
  /// (nothing is persisted between calls, so the item still reads as pending).
  final _stagedRetractionKeys = <String>{};

  static const _uuid = Uuid();

  /// Tool name for the report publishing tool.
  static const String reportToolName = TaskAgentToolNames.updateReport;

  /// Tool name for the observation recording tool.
  static const String observationToolName =
      TaskAgentToolNames.recordObservations;

  /// Tool name for the read-only related-task drill-down tool.
  static const String relatedTaskDetailsToolName =
      TaskAgentToolNames.getRelatedTaskDetails;

  /// Tool name for the agent-autonomous retraction tool.
  static const String retractSuggestionsToolName =
      TaskAgentToolNames.retractSuggestions;

  @override
  Future<ConversationAction> processToolCalls({
    required List<ChatCompletionMessageToolCall> toolCalls,
    required ConversationManager manager,
  }) async {
    // Persist the assistant message (the one that requested tool calls).
    await _recordAssistantMessage(toolCalls: toolCalls);

    for (final call in toolCalls) {
      final toolName = call.function.name;

      Map<String, dynamic> args;
      try {
        args = _parseToolArguments(call.function.arguments);
      } catch (e) {
        final rawBytes = utf8.encode(call.function.arguments).length;
        developer.log(
          'Failed to parse tool call arguments for $toolName '
          '(rawBytes=$rawBytes, errorType=${e.runtimeType})',
          name: 'TaskAgentStrategy',
        );
        final errorMsg =
            'Error: invalid arguments format — expected a JSON object. '
            'Detail: ${e.runtimeType}';
        manager.addToolResponse(toolCallId: call.id, response: errorMsg);
        await _recordToolResultMessage(
          toolName: toolName,
          errorMessage: errorMsg,
        );
        continue;
      }

      final argsBytes = utf8.encode(jsonEncode(args)).length;
      developer.log(
        'Processing tool call: $toolName ($argsBytes bytes)',
        name: 'TaskAgentStrategy',
      );

      // Handle update_report and record_observations locally — they don't
      // modify journal entities so they don't need category enforcement,
      // but we still persist audit messages for completeness.
      if (toolName == reportToolName) {
        await _recordActionMessage(toolName: toolName, args: args);
        await _handleUpdateReport(args, call.id, manager);
        continue;
      }
      if (toolName == observationToolName) {
        await _recordActionMessage(toolName: toolName, args: args);
        await _handleRecordObservations(args, call.id, manager);
        continue;
      }
      if (toolName == relatedTaskDetailsToolName) {
        await _recordActionMessage(toolName: toolName, args: args);
        await _handleRelatedTaskDetails(args, call.id, manager);
        continue;
      }
      if (toolName == retractSuggestionsToolName) {
        await _recordActionMessage(toolName: toolName, args: args);
        await _handleRetractSuggestions(args, call.id, manager);
        continue;
      }

      // Initial-title carve-out: when the task has no title yet, apply
      // set_task_title immediately rather than queuing it for user
      // confirmation. The "empty item in the list until I confirm"
      // friction the user sees during dictation goes away, and title
      // renames on existing tasks still flow through the deferred path
      // below (existing redundancy filters in ChangeProposalFilter also
      // still apply once a title is present).
      //
      // The language carve-out mirrors the same logic: the very first
      // `set_task_language` on a task with no language yet is applied
      // immediately, while language changes on tasks that already have
      // one continue to require user confirmation.
      final canUseInitialAutoApply = !_usedDeferredTools.contains(toolName);
      final autoApplyInitial =
          canUseInitialAutoApply &&
          ((toolName == TaskAgentToolNames.setTaskTitle &&
                  await _shouldAutoApplyInitialField((s) => s.title)) ||
              (toolName == TaskAgentToolNames.setTaskLanguage &&
                  await _shouldAutoApplyInitialField((s) => s.languageCode)));
      if (autoApplyInitial) {
        await _recordActionMessage(toolName: toolName, args: args);
        final result = await executor.execute(
          toolName: toolName,
          args: args,
          targetEntityId: taskId,
          resolveCategoryId: resolveCategoryId,
          executeHandler: () => executeToolHandler(toolName, args, manager),
          readVectorClock: readVectorClock,
        );
        // The initial-field shortcut is still an autonomous write. If the
        // category policy blocks it, keep the user path alive by converting
        // the same tool call into the normal confirmable proposal.
        final policyFallbackBuilder = changeSetBuilder;
        if (result.policyDenied &&
            policyFallbackBuilder != null &&
            AgentToolRegistry.deferredTools.contains(toolName)) {
          final csBuilder = policyFallbackBuilder;
          _taskMetadataResolved = false;
          _cachedTaskMetadata = null;
          final itemCountBefore = csBuilder.items.length;
          final response = await _addToChangeSet(csBuilder, toolName, args);
          if (csBuilder.items.length > itemCountBefore) {
            _usedDeferredTools.add(toolName);
          }
          manager.addToolResponse(toolCallId: call.id, response: response);
          await _recordToolResultMessage(toolName: toolName);
          continue;
        }
        manager.addToolResponse(toolCallId: call.id, response: result.output);
        if (result.success) {
          // The field is now populated. Prevent a repeat call to the
          // same tool in the same wake from auto-applying over it
          // (smaller models frequently emit duplicate tool calls), and
          // invalidate the cached metadata so later redundancy checks
          // see fresh state.
          _usedDeferredTools.add(toolName);
          _taskMetadataResolved = false;
          _cachedTaskMetadata = null;
        }
        continue;
      }

      // Route deferred tools to the change set builder when available.
      final csBuilder = changeSetBuilder;
      if (csBuilder != null &&
          AgentToolRegistry.deferredTools.contains(toolName)) {
        // Reject repeat calls to the same single-use deferred tool name
        // (even with different args). Smaller models tend to burn all
        // turns on one tool (e.g. calling set_task_title 4 times).
        // Batch tools and create_follow_up_task are excluded — they may
        // legitimately be called multiple times in one wake.
        final isSingleUse =
            !AgentToolRegistry.explodedBatchTools.containsKey(toolName) &&
            toolName != TaskAgentToolNames.createFollowUpTask;
        if (isSingleUse && _usedDeferredTools.contains(toolName)) {
          await _recordActionMessage(toolName: toolName, args: args);
          final errorResponse =
              'ERROR: $toolName was already called this session. '
              'You MUST NOT call the same tool twice. '
              'Use a DIFFERENT tool, call update_report if the report needs '
              'updating, or finish with a brief plain-text note.';
          manager.addToolResponse(
            toolCallId: call.id,
            response: errorResponse,
          );
          await _recordToolResultMessage(
            toolName: toolName,
            errorMessage: errorResponse,
          );
          continue;
        }

        await _recordActionMessage(toolName: toolName, args: args);
        final itemCountBefore = csBuilder.items.length;
        final response = await _addToChangeSet(csBuilder, toolName, args);
        // Only mark as used when an item was actually queued. If metadata
        // redundancy or dedup skipped it, allow the model to retry with
        // different args.
        if (isSingleUse && csBuilder.items.length > itemCountBefore) {
          _usedDeferredTools.add(toolName);
        }
        manager.addToolResponse(
          toolCallId: call.id,
          response: response,
        );
        continue;
      }

      // Delegate to the executor which handles category enforcement, audit
      // logging, saga tracking, and vector-clock capture.
      final result = await executor.execute(
        toolName: toolName,
        args: args,
        targetEntityId: taskId,
        resolveCategoryId: resolveCategoryId,
        executeHandler: () => executeToolHandler(toolName, args, manager),
        readVectorClock: readVectorClock,
      );

      // Feed the result back to the conversation so the LLM sees it on
      // the next turn.
      manager.addToolResponse(
        toolCallId: call.id,
        response: result.output,
      );
    }

    // After processing all tool calls, let the conversation loop continue
    // so the LLM can inspect results and either call more tools or produce
    // its final response.
    return ConversationAction.continueConversation;
  }

  @override
  bool shouldContinue(ConversationManager manager) {
    return manager.canContinue();
  }

  @override
  String? getContinuationPrompt(ConversationManager manager) {
    if (_reportContent != null) {
      // Report already submitted — no further turns needed.
      return null;
    }
    // The report is conditional (a projection of the log, not per-wake
    // ceremony): updating it is only warranted on material change. A
    // plain-text reply ends the wake naturally.
    return 'Continue. If you have finished your analysis, call '
        '`update_report` with the full updated report if it would '
        'materially change; otherwise finish with a brief plain-text note '
        'of what you did.';
  }

  /// Called by the workflow after the conversation loop finishes to capture
  /// the assistant's final text response (for thought persistence).
  void recordFinalResponse(String? content) {
    if (content != null && content.isNotEmpty) {
      _finalResponse = content;
    }
  }

  /// Returns the raw final assistant response for thought persistence.
  ///
  /// This may contain `<think>` tags or other reasoning — it is NOT the
  /// report. The report is captured via the `update_report` tool call.
  String? get finalResponse => _finalResponse;

  /// Extracts the report content published via the `update_report` tool call.
  ///
  /// Returns the markdown string, or empty string if the LLM never called
  /// `update_report`.
  String extractReportContent() => _reportContent ?? '';

  /// Extracts the TLDR published via the `update_report` tool call.
  ///
  /// Returns `null` if the LLM did not provide a TLDR.
  String? extractReportTldr() => _reportTldr;

  /// Extracts the compact one-liner published via the `update_report` tool
  /// call.
  ///
  /// Returns `null` if the LLM did not provide a one-liner.
  String? extractReportOneLiner() => _reportOneLiner;

  /// Returns observations accumulated from `record_observations` tool calls.
  ///
  /// The LLM calls the `record_observations` tool during the conversation
  /// to record private notes for future wakes. Each call may contain
  /// multiple observation items (structured or bare strings), all of which
  /// are accumulated here as [ObservationRecord] instances.
  List<ObservationRecord> extractObservations() =>
      List.unmodifiable(_observations);

  /// Returns the retractions staged via `retract_suggestions` during this wake.
  ///
  /// The workflow applies these at the end of the wake (inside the change-set
  /// transaction) so the retraction and the new proposals land in a single
  /// atomic update, never leaving the suggestion list momentarily empty.
  List<StagedRetraction> extractStagedRetractions() =>
      List.unmodifiable(_stagedRetractions);

  // ── Internal handlers ──────────────────────────────────────────────────

  /// Test seam for the JSON-recovery parser — pure, no I/O.
  @visibleForTesting
  static Map<String, dynamic> debugParseToolArguments(String raw) =>
      _parseToolArguments(raw);

  /// Parses tool call arguments from raw JSON, with resilience for common
  /// local model quirks (markdown fencing, trailing text, etc.).
  static Map<String, dynamic> _parseToolArguments(String raw) {
    // First, try direct parse.
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      throw FormatException(
        'Expected a JSON object, got ${decoded.runtimeType}',
      );
    } on FormatException {
      // Fall through to recovery attempts.
    }

    // Recovery: local models sometimes wrap JSON in markdown code fences
    // or include trailing explanation text. Try to extract the JSON object.
    final trimmed = raw.trim();

    // Strip markdown code fences: ```json\n{...}\n```
    final fencePattern = RegExp(r'```(?:json)?\s*\n?([\s\S]*?)\n?```');
    final fenceMatch = fencePattern.firstMatch(trimmed);
    if (fenceMatch != null) {
      final inner = fenceMatch.group(1)!.trim();
      try {
        final decoded = jsonDecode(inner);
        if (decoded is Map<String, dynamic>) return decoded;
      } on FormatException {
        // Continue to next recovery.
      }
    }

    // Extract the first top-level JSON object by finding balanced braces.
    final braceStart = trimmed.indexOf('{');
    if (braceStart >= 0) {
      var depth = 0;
      var inString = false;
      var escape = false;
      for (var i = braceStart; i < trimmed.length; i++) {
        final c = trimmed[i];
        if (escape) {
          escape = false;
          continue;
        }
        if (c == r'\' && inString) {
          escape = true;
          continue;
        }
        if (c == '"') {
          inString = !inString;
          continue;
        }
        if (!inString) {
          if (c == '{') depth++;
          if (c == '}') {
            depth--;
            if (depth == 0) {
              final candidate = trimmed.substring(braceStart, i + 1);
              try {
                final decoded = jsonDecode(candidate);
                if (decoded is Map<String, dynamic>) return decoded;
              } on FormatException {
                // Candidate wasn't valid JSON; give up.
              }
              break;
            }
          }
        }
      }
    }

    // All recovery attempts failed. Do not include [raw] in the exception:
    // tool arguments may contain user-authored content and exceptions can
    // travel through runtime logs.
    throw const FormatException('Could not extract a JSON object');
  }
}
