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
import 'package:openai_dart/openai_dart.dart';
import 'package:uuid/uuid.dart';

export 'package:lotti/features/agents/model/observation_record.dart'
    show ObservationRecord;

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
        developer.log(
          'Failed to parse tool call arguments for $toolName: $e\n'
          'Raw arguments: ${call.function.arguments}',
          name: 'TaskAgentStrategy',
        );
        final errorMsg =
            'Error: invalid arguments format — expected a JSON object. '
            'Detail: $e';
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
              'Use a DIFFERENT tool or call update_report to finish.';
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
    return 'Continue. If you have finished your analysis, call `update_report` '
        'with the full updated report.';
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

  // ── Internal handlers ──────────────────────────────────────────────────

  /// Handles the `update_report` tool call by capturing the one-liner, TLDR,
  /// and content.
  ///
  /// If the LLM calls this more than once per wake, the last call wins — the
  /// previous content is silently replaced. This is by design: the agent
  /// contract requires exactly one call, so multiple calls indicate an LLM
  /// error and the latest version is the most refined.
  Future<void> _handleUpdateReport(
    Map<String, dynamic> args,
    String callId,
    ConversationManager manager,
  ) async {
    final contentArg = args['content'];
    final rawTldr = args['tldr'];
    final rawOneLiner = args['oneLiner'];
    final tldr = (rawTldr is String && rawTldr.trim().isNotEmpty)
        ? rawTldr.trim()
        : null;
    final oneLiner = (rawOneLiner is String && rawOneLiner.trim().isNotEmpty)
        ? rawOneLiner.trim()
        : null;

    if (contentArg is String && contentArg.trim().isNotEmpty) {
      final missingFields = <String>[
        if (tldr == null) 'tldr',
        if (oneLiner == null) 'oneLiner',
      ];

      if (missingFields.isNotEmpty) {
        final errorMsg =
            'Error: ${missingFields.map((f) => '"$f"').join(' and ')} '
            'must be a non-empty string.';
        manager.addToolResponse(
          toolCallId: callId,
          response: errorMsg,
        );

        await _recordToolResultMessage(
          toolName: reportToolName,
          errorMessage: errorMsg,
        );
        return;
      }

      _reportContent = contentArg.trim();
      _reportTldr = tldr;
      _reportOneLiner = oneLiner;

      developer.log(
        'Report updated (${_reportContent!.length} chars, '
        'tldr=${_reportTldr != null ? "${_reportTldr!.length} chars" : "none"}, '
        'oneLiner=${_reportOneLiner != null ? "${_reportOneLiner!.length} chars" : "none"})',
        name: 'TaskAgentStrategy',
      );

      manager.addToolResponse(
        toolCallId: callId,
        response: 'Report updated.',
      );

      await _recordToolResultMessage(toolName: reportToolName);
    } else {
      const errorMsg = 'Error: "content" must be a non-empty string.';
      manager.addToolResponse(
        toolCallId: callId,
        response: errorMsg,
      );

      await _recordToolResultMessage(
        toolName: reportToolName,
        errorMessage: errorMsg,
      );
    }
  }

  /// Handles the `record_observations` tool call by accumulating observations
  /// and sending an acknowledgement back to the conversation.
  ///
  /// Accepts both legacy bare-string items and new structured items with
  /// `text`, `priority`, and `category` fields. Legacy items default to
  /// [ObservationPriority.routine] / [ObservationCategory.operational].
  Future<void> _handleRecordObservations(
    Map<String, dynamic> args,
    String callId,
    ConversationManager manager,
  ) async {
    final rawList = args['observations'];
    if (rawList is List) {
      var count = 0;
      for (final item in rawList) {
        final record = _parseObservationItem(item);
        if (record != null) {
          _observations.add(record);
          count++;
        }
      }

      developer.log(
        'Recorded $count observations',
        name: 'TaskAgentStrategy',
      );

      manager.addToolResponse(
        toolCallId: callId,
        response: 'Recorded $count observation(s).',
      );

      await _recordToolResultMessage(toolName: observationToolName);
    } else {
      const errorMsg = 'Error: "observations" must be an array.';
      manager.addToolResponse(
        toolCallId: callId,
        response: errorMsg,
      );

      await _recordToolResultMessage(
        toolName: observationToolName,
        errorMessage: errorMsg,
      );
    }
  }

  /// Handles the read-only related-task drill-down tool.
  Future<void> _handleRelatedTaskDetails(
    Map<String, dynamic> args,
    String callId,
    ConversationManager manager,
  ) async {
    final rawTaskId = args['taskId'];
    final requestedTaskId = rawTaskId is String ? rawTaskId.trim() : '';

    String? errorMessage;
    if (requestedTaskId.isEmpty) {
      errorMessage = 'Error: "taskId" must be a non-empty string.';
    } else if (requestedTaskId == taskId) {
      errorMessage =
          'Error: get_related_task_details cannot be used for the current '
          'task. Choose another task from the related-tasks directory.';
    } else if (!allowedRelatedTaskIds.contains(requestedTaskId)) {
      errorMessage =
          'Error: taskId "$requestedTaskId" is not available in the current '
          'related-tasks directory. Only inspect sibling task IDs that were '
          'included in this wake context.';
    }

    if (errorMessage != null) {
      manager.addToolResponse(toolCallId: callId, response: errorMessage);
      await _recordToolResultMessage(
        toolName: relatedTaskDetailsToolName,
        errorMessage: errorMessage,
      );
      return;
    }

    final resolver = resolveRelatedTaskDetails;
    String? response;
    try {
      response = resolver != null ? await resolver(requestedTaskId) : null;
    } catch (error, stackTrace) {
      developer.log(
        'Failed to resolve related task details for $requestedTaskId',
        name: 'TaskAgentStrategy',
        error: error,
        stackTrace: stackTrace,
      );
    }
    if (response == null || response.trim().isEmpty) {
      final toolError =
          'Error: related task details could not be resolved for '
          '"$requestedTaskId".';
      manager.addToolResponse(toolCallId: callId, response: toolError);
      await _recordToolResultMessage(
        toolName: relatedTaskDetailsToolName,
        errorMessage: toolError,
      );
      return;
    }

    manager.addToolResponse(toolCallId: callId, response: response);
    await _recordToolResultMessage(toolName: relatedTaskDetailsToolName);
  }

  /// Handles the `retract_suggestions` tool call: parses the proposals
  /// array, dispatches each retraction to [SuggestionRetractionService],
  /// and feeds a per-entry outcome report back to the LLM.
  Future<void> _handleRetractSuggestions(
    Map<String, dynamic> args,
    String callId,
    ConversationManager manager,
  ) async {
    final service = retractionService;
    if (service == null) {
      const errorMsg =
          'Error: retract_suggestions is not wired up for this agent.';
      manager.addToolResponse(toolCallId: callId, response: errorMsg);
      await _recordToolResultMessage(
        toolName: retractSuggestionsToolName,
        errorMessage: errorMsg,
      );
      return;
    }

    final rawProposals = args['proposals'];
    if (rawProposals is! List || rawProposals.isEmpty) {
      const errorMsg =
          'Error: "proposals" must be a non-empty array of '
          '{fingerprint, reason} objects.';
      manager.addToolResponse(toolCallId: callId, response: errorMsg);
      await _recordToolResultMessage(
        toolName: retractSuggestionsToolName,
        errorMessage: errorMsg,
      );
      return;
    }

    final requests = <RetractionRequest>[];
    final parseErrors = <String>[];
    for (var i = 0; i < rawProposals.length; i++) {
      final entry = rawProposals[i];
      if (entry is! Map) {
        parseErrors.add('proposals[$i] is not an object');
        continue;
      }
      final fp = entry['fingerprint'];
      final reason = entry['reason'];
      if (fp is! String || fp.trim().isEmpty) {
        parseErrors.add('proposals[$i].fingerprint missing or empty');
        continue;
      }
      if (reason is! String || reason.trim().isEmpty) {
        parseErrors.add('proposals[$i].reason missing or empty');
        continue;
      }
      requests.add(
        RetractionRequest(fingerprint: fp.trim(), reason: reason.trim()),
      );
    }

    if (requests.isEmpty) {
      final errorMsg =
          'Error: no valid proposals to retract. '
          '${parseErrors.join('; ')}';
      manager.addToolResponse(toolCallId: callId, response: errorMsg);
      await _recordToolResultMessage(
        toolName: retractSuggestionsToolName,
        errorMessage: errorMsg,
      );
      return;
    }

    final results = await service.retract(
      agentId: agentId,
      taskId: taskId,
      requests: requests,
    );

    final response = StringBuffer('Retraction results:');
    for (final r in results) {
      final label = switch (r.outcome) {
        RetractionOutcome.retracted => 'retracted',
        RetractionOutcome.notOpen => 'not_open (already resolved)',
        RetractionOutcome.notFound => 'not_found',
      };
      final summary = r.humanSummary?.trim();
      final detail = (summary != null && summary.isNotEmpty)
          ? ' — "$summary"'
          : (r.toolName != null ? ' — ${r.toolName}' : '');
      response.writeln('\n- [fp=${r.fingerprint}] $label$detail');
    }
    if (parseErrors.isNotEmpty) {
      response
        ..writeln()
        ..writeln('Skipped malformed entries: ${parseErrors.join('; ')}');
    }

    manager.addToolResponse(
      toolCallId: callId,
      response: response.toString().trim(),
    );
    await _recordToolResultMessage(toolName: retractSuggestionsToolName);
  }

  /// Parses a single observation item from the tool call arguments.
  ///
  /// Handles both legacy bare strings and new structured objects.
  static ObservationRecord? _parseObservationItem(Object? item) {
    // Legacy format: bare string.
    if (item is String) {
      final trimmed = item.trim();
      if (trimmed.isNotEmpty) {
        return ObservationRecord(text: trimmed);
      }
    }

    // New structured format: {text, priority?, category?, target?}.
    if (item is Map<String, dynamic>) {
      final rawText = item['text'];
      if (rawText is String) {
        final text = rawText.trim();
        if (text.isEmpty) return null;
        final rawPriority = item['priority'];
        final rawCategory = item['category'];
        final rawTarget = item['target'];
        return ObservationRecord(
          text: text,
          priority:
              parseEnumByName(
                ObservationPriority.values,
                rawPriority is String ? rawPriority : null,
              ) ??
              ObservationPriority.routine,
          category:
              parseEnumByName(
                ObservationCategory.values,
                rawCategory is String ? rawCategory : null,
              ) ??
              ObservationCategory.operational,
          target:
              parseEnumByName(
                ObservationTarget.values,
                rawTarget is String ? rawTarget : null,
              ) ??
              ObservationTarget.template,
        );
      }
    }

    return null;
  }

  // ── Argument parsing ───────────────────────────────────────────────────

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

    // All recovery attempts failed — throw with the original raw value.
    throw FormatException('Could not extract a JSON object from: $raw');
  }

  // ── Change set helpers ──────────────────────────────────────────────────

  /// Route a deferred tool call to the change set builder.
  ///
  /// Batch tools (listed in [AgentToolRegistry.explodedBatchTools]) are
  /// exploded into individual items; all others are added as a single item.
  ///
  /// Returns a response string for the LLM. For batch tools with skipped
  /// items, the response includes a warning.
  Future<String> _addToChangeSet(
    ChangeSetBuilder csBuilder,
    String toolName,
    Map<String, dynamic> args,
  ) async {
    // Route create_follow_up_task to the dedicated builder method that
    // injects a placeholder ID and returns it for migrate_checklist_items.
    if (toolName == TaskAgentToolNames.createFollowUpTask) {
      final placeholderId = await csBuilder.addFollowUpTask(
        args: args,
        humanSummary: _generateHumanSummary(toolName, args),
      );

      developer.log(
        'Deferred tool $toolName to change set '
        '(${csBuilder.items.length} items total)',
        name: 'TaskAgentStrategy',
      );

      return 'Proposal queued for user review. '
          'Use targetTaskId: "$placeholderId" for migrate_checklist_items.';
    }

    final batchKey = AgentToolRegistry.explodedBatchTools[toolName];
    String response;
    if (batchKey != null) {
      var effectiveArgs = args;

      // For migrate_checklist_items, replace the LLM's targetTaskId with the
      // real placeholder from the builder. The LLM often hallucinate its own
      // placeholder string (e.g. "placeholder_targetTaskId_1") instead of
      // using the UUID v5 we returned.
      if (toolName == TaskAgentToolNames.migrateChecklistItems) {
        final realPlaceholder = csBuilder.followUpPlaceholderId;
        if (realPlaceholder != null) {
          effectiveArgs = {...args, 'targetTaskId': realPlaceholder};
        }
      }

      final groupId = toolName == TaskAgentToolNames.migrateChecklistItems
          ? effectiveArgs['targetTaskId'] as String?
          : null;
      final result = await csBuilder.addBatchItem(
        toolName: toolName,
        args: effectiveArgs,
        summaryPrefix: _humanToolPrefix(toolName),
        groupId: groupId,
      );
      response = ChangeProposalFilter.formatBatchResponse(result);
    } else {
      // Check for redundancy on non-batch deferred tools.
      final redundancyMsg = await _checkTaskMetadataRedundancy(toolName, args);
      if (redundancyMsg != null) {
        response = redundancyMsg;
      } else {
        final addRedundancy = await csBuilder.addItem(
          toolName: toolName,
          args: args,
          humanSummary: _generateHumanSummary(toolName, args),
        );
        if (addRedundancy != null) {
          response = 'Skipped: $addRedundancy';
        } else {
          final remaining = _remainingDeferredToolHint(toolName);
          response =
              'OK — $toolName proposal recorded successfully. '
              'Do NOT call $toolName again.$remaining';
        }
      }
    }

    developer.log(
      'Deferred tool $toolName to change set '
      '(${csBuilder.items.length} items total)',
      name: 'TaskAgentStrategy',
    );

    return response;
  }

  /// Generate a human-readable summary for a single (non-batch) tool call.
  static String _generateHumanSummary(
    String toolName,
    Map<String, dynamic> args,
  ) {
    return switch (toolName) {
      TaskAgentToolNames.setTaskTitle =>
        'Set title to "${args['title'] ?? ''}"',
      TaskAgentToolNames.updateTaskEstimate =>
        'Set estimate to ${args['minutes'] ?? '?'} minutes',
      TaskAgentToolNames.updateTaskDueDate =>
        'Set due date to ${args['dueDate'] ?? '?'}',
      TaskAgentToolNames.updateTaskPriority =>
        'Set priority to ${args['priority'] ?? '?'}',
      TaskAgentToolNames.setTaskStatus =>
        'Set status to ${args['status'] ?? '?'}',
      TaskAgentToolNames.setTaskLanguage =>
        'Set language to "${args['languageCode'] ?? '?'}"',
      TaskAgentToolNames.assignTaskLabels => () {
        final labels = args['labels'];
        final count = labels is List ? labels.length : 0;
        return 'Assign $count label(s)';
      }(),
      TaskAgentToolNames.createFollowUpTask =>
        'Create follow-up task: "${args['title'] ?? ''}"',
      TaskAgentToolNames.createTimeEntry => () {
        final startRaw = args['startTime'] is String
            ? args['startTime'] as String
            : null;
        final hasEndTime = args.containsKey('endTime');
        final endRaw = args['endTime'] is String
            ? args['endTime'] as String
            : null;
        final summary = args['summary'] is String
            ? (args['summary'] as String).trim()
            : '';
        final start = startRaw != null
            ? parseTimeEntryLocalDateTime(startRaw)
            : null;
        final end = endRaw != null ? parseTimeEntryLocalDateTime(endRaw) : null;
        final startStr = start != null
            ? formatTimeEntryHhMm(start)
            : (startRaw ?? '?');
        final endStr = end != null ? formatTimeEntryHhMm(end) : (endRaw ?? '?');
        final timeRange = hasEndTime ? '$startStr–$endStr' : 'from $startStr';
        return 'Time entry $timeRange: "$summary"';
      }(),
      _ => '$toolName(${args.keys.join(", ")})',
    };
  }

  /// Generate a human-readable prefix for batch tool explosion summaries.
  static String _humanToolPrefix(String toolName) {
    return switch (toolName) {
      TaskAgentToolNames.addMultipleChecklistItems => 'Checklist',
      TaskAgentToolNames.updateChecklistItems => 'Checklist update',
      TaskAgentToolNames.assignTaskLabels => 'Label',
      TaskAgentToolNames.migrateChecklistItems => 'Migrate to follow-up',
      _ => toolName,
    };
  }

  /// Check whether a non-batch deferred tool proposal is redundant against
  /// the current task metadata.
  ///
  /// Returns a feedback message for the LLM if the proposal is redundant,
  /// or `null` if the proposal should be kept.
  ///
  /// The snapshot is resolved once and cached for the lifetime of this
  /// strategy instance to avoid repeated DB lookups when the LLM proposes
  /// multiple deferred tools in the same wake.
  Future<String?> _checkTaskMetadataRedundancy(
    String toolName,
    Map<String, dynamic> args,
  ) async {
    final resolver = resolveTaskMetadata;
    if (resolver == null) return null;

    if (!_taskMetadataResolved) {
      _taskMetadataResolved = true;
      try {
        _cachedTaskMetadata = await resolver();
      } catch (e) {
        // Conservative: if we can't resolve, keep the proposal.
        _cachedTaskMetadata = null;
      }
    }

    final snapshot = _cachedTaskMetadata;
    if (snapshot == null) return null;

    return ChangeProposalFilter.checkTaskMetadataRedundancy(
      toolName,
      args,
      snapshot,
    );
  }

  /// Builds a hint string listing remaining non-batch deferred tools that
  /// haven't been used yet, guiding the model to call different tools.
  String _remainingDeferredToolHint(String justUsed) {
    // Derive single-use tools dynamically: all deferred tools minus batch
    // ones and minus tools that legitimately support multiple calls.
    final singleUseTools = AgentToolRegistry.deferredTools
        .where(
          (tool) =>
              !AgentToolRegistry.explodedBatchTools.containsKey(tool) &&
              tool != TaskAgentToolNames.createFollowUpTask,
        )
        .toSet();

    final remaining = singleUseTools.difference(_usedDeferredTools).difference({
      justUsed,
    });

    if (remaining.isEmpty) {
      return ' Call update_report when your analysis is complete.';
    }

    final toolList = remaining.toList()..sort();
    return ' Consider using: ${toolList.join(', ')} — '
        'or call update_report when done.';
  }

  // ── Persistence helpers ──────────────────────────────────────────────────

  /// Records an action message for a locally-handled tool call.
  ///
  /// The [AgentToolExecutor] creates these automatically for tools it handles,
  /// but locally-handled tools (update_report, record_observations) must
  /// create their own action messages so the conversation log tool-call count
  /// is accurate.
  Future<void> _recordActionMessage({
    required String toolName,
    required Map<String, dynamic> args,
  }) async {
    final now = clock.now();
    final payloadId = _uuid.v4();

    await syncService.upsertEntity(
      AgentDomainEntity.agentMessagePayload(
        id: payloadId,
        agentId: agentId,
        createdAt: now,
        vectorClock: null,
        content: <String, Object?>{'text': jsonEncode(args)},
      ),
    );

    await syncService.upsertEntity(
      AgentDomainEntity.agentMessage(
        id: _uuid.v4(),
        agentId: agentId,
        threadId: threadId,
        kind: AgentMessageKind.action,
        createdAt: now,
        vectorClock: null,
        contentEntryId: payloadId,
        metadata: AgentMessageMetadata(
          runKey: runKey,
          toolName: toolName,
        ),
      ),
    );
  }

  /// Records an assistant message (with or without tool calls) to the agent
  /// message log.
  Future<void> _recordAssistantMessage({
    List<ChatCompletionMessageToolCall>? toolCalls,
  }) async {
    final now = clock.now();
    final toolNames =
        toolCalls?.map((tc) => tc.function.name).toList() ?? <String>[];

    await syncService.upsertEntity(
      AgentDomainEntity.agentMessage(
        id: _uuid.v4(),
        agentId: agentId,
        threadId: threadId,
        kind: AgentMessageKind.thought,
        createdAt: now,
        vectorClock: null,
        metadata: AgentMessageMetadata(
          runKey: runKey,
          toolName: toolNames.isNotEmpty ? toolNames.join(',') : null,
        ),
      ),
    );
  }

  /// Records a tool result message to the agent message log.
  Future<void> _recordToolResultMessage({
    required String toolName,
    String? errorMessage,
  }) async {
    final now = clock.now();
    await syncService.upsertEntity(
      AgentDomainEntity.agentMessage(
        id: _uuid.v4(),
        agentId: agentId,
        threadId: threadId,
        kind: AgentMessageKind.toolResult,
        createdAt: now,
        vectorClock: null,
        metadata: AgentMessageMetadata(
          runKey: runKey,
          toolName: toolName,
          errorMessage: errorMessage,
        ),
      ),
    );
  }
}
