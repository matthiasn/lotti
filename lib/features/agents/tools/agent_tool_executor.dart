import 'dart:convert';
import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/wake/run_key_factory.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:uuid/uuid.dart';

/// Result of a single tool execution.
///
/// Carries the success flag, a human-readable output string, and optional
/// fields for the entity that was mutated (used for self-notification
/// suppression) and any error or policy-denial details.
class ToolExecutionResult {
  const ToolExecutionResult({
    required this.success,
    required this.output,
    this.mutatedEntityId,
    this.errorMessage,
    this.policyDenied = false,
    this.denialReason,
  });

  /// Converts a task tool handler result into a [ToolExecutionResult].
  ///
  /// All task tool result types share the same `success`, `message`,
  /// `didWrite`, and `error` fields. This factory provides a single
  /// conversion point used by the dispatcher.
  factory ToolExecutionResult.fromHandlerResult({
    required bool success,
    required String message,
    required bool didWrite,
    String? error,
    String? entityId,
  }) {
    return ToolExecutionResult(
      success: success,
      output: message,
      mutatedEntityId: didWrite ? entityId : null,
      errorMessage: error,
    );
  }

  /// Whether the tool call completed successfully.
  final bool success;

  /// Human-readable description of the outcome.
  final String output;

  /// ID of the journal entity that was mutated, if any.
  final String? mutatedEntityId;

  /// Error description when [success] is false and the failure is not a policy
  /// denial.
  final String? errorMessage;

  /// True when the call was rejected by the category-allowlist policy.
  final bool policyDenied;

  /// Human-readable reason for the policy denial, set when [policyDenied] is
  /// true.
  final String? denialReason;
}

/// Orchestrates tool calls on behalf of an agent with category enforcement
/// and audit logging.
///
/// ## Responsibilities
///
/// 1. **Category enforcement (fail-closed)** — resolves the target entity's
///    category and rejects the call if it is not in [allowedCategoryIds].
/// 2. **Action message** — persists an action-kind entry before the call so
///    the audit log is always consistent even on crashes.
/// 3. **Delegation** — calls the `executeHandler` callback to perform the
///    actual domain mutation.
/// 4. **Result message** — persists a toolResult-kind entry after the call,
///    including any error.
/// 5. **Vector-clock capture** — reads the post-mutation vector clock and
///    stores it in [mutatedEntries] so the caller can suppress self-generated
///    notifications.
///
/// ## Idempotency (planned)
///
/// Each execution is tagged with a deterministic `operationId` derived from the
/// run key, tool name, arguments, and target entity. This ID is persisted in
/// audit messages and is designed to support idempotency checks when wake-retry
/// logic is added. Currently no retry mechanism exists, so the executor does
/// not query for prior completions — but the infrastructure is in place.
///
/// ## Usage
///
/// ```dart
/// final executor = AgentToolExecutor(
///   syncService: agentSyncService,
///   allowedCategoryIds: {'cat-id-1'},
///   runKey: 'abc123',
///   agentId: 'agent-uuid',
///   threadId: 'thread-uuid',
/// );
///
/// final result = await executor.execute(
///   toolName: 'set_task_title',
///   args: {'title': 'New title'},
///   targetEntityId: taskId,
///   resolveCategoryId: (id) => journalRepo.getCategoryId(id),
///   executeHandler: () => titleHandler.handle(taskId, 'New title'),
///   readVectorClock: (id) => journalRepo.getVectorClock(id),
/// );
/// ```
class AgentToolExecutor {
  AgentToolExecutor({
    required this.syncService,
    required this.allowedCategoryIds,
    required this.runKey,
    required this.agentId,
    required this.threadId,
  });

  /// Sync-aware write service for persisting audit messages. All writes go
  /// through this so they are automatically enqueued for cross-device sync.
  final AgentSyncService syncService;

  /// Set of category IDs that this executor is permitted to mutate.
  final Set<String> allowedCategoryIds;

  /// The run key for the current wake cycle.
  final String runKey;

  /// The agent's stable ID.
  final String agentId;

  /// The conversation thread ID for the current wake.
  final String threadId;

  static const _uuid = Uuid();

  final _mutatedEntries = <String, VectorClock>{};

  /// All entities mutated during this execution session, keyed by entity ID.
  ///
  /// Use this map to suppress self-generated change notifications after the
  /// wake completes.
  Map<String, VectorClock> get mutatedEntries =>
      Map.unmodifiable(_mutatedEntries);

  /// Execute a tool call with full agent-domain bookkeeping.
  ///
  /// Steps:
  /// 1. Resolve the target entity's category and enforce the allowlist.
  /// 2. Persist an [AgentMessageKind.action] message.
  /// 3. Call [executeHandler] to perform the domain mutation.
  /// 4. Persist an [AgentMessageKind.toolResult] message.
  /// 5. Capture the post-mutation vector clock via [readVectorClock].
  ///
  /// Parameters:
  /// - [toolName]: The tool being invoked (e.g., `'set_task_title'`).
  /// - [args]: The arguments map passed by the LLM.
  /// - [targetEntityId]: ID of the journal entity being mutated.
  /// - [resolveCategoryId]: Async callback that returns the category ID for a
  ///   given entity ID, or `null` if the entity has no category.
  /// - [executeHandler]: Async callback that performs the actual mutation and
  ///   returns a [ToolExecutionResult].
  /// - [readVectorClock]: Async callback that returns the current vector clock
  ///   for a given entity ID, used after a successful mutation.
  Future<ToolExecutionResult> execute({
    required String toolName,
    required Map<String, dynamic> args,
    required String targetEntityId,
    required Future<String?> Function(String entityId) resolveCategoryId,
    required Future<ToolExecutionResult> Function() executeHandler,
    required Future<VectorClock?> Function(String entityId) readVectorClock,
  }) async {
    final operationId = RunKeyFactory.operationId(
      runKey: runKey,
      actionStableId: RunKeyFactory.actionStableId(
        toolName: toolName,
        args: args,
        targetRefs: [targetEntityId],
      ),
    );

    developer.log(
      'Executing tool $toolName for entity $targetEntityId '
      '(operationId: $operationId)',
      name: 'AgentToolExecutor',
    );

    // 1. Category enforcement (fail-closed).
    final categoryId = await resolveCategoryId(targetEntityId);
    if (categoryId == null || !allowedCategoryIds.contains(categoryId)) {
      final denialReason = categoryId == null
          ? 'Target entity has no category'
          : 'Category $categoryId not in allowed set';

      developer.log(
        'Policy denied for $toolName: $denialReason',
        name: 'AgentToolExecutor',
      );

      // Record the denial in the audit log before returning.
      // Wrapped in try/catch so a recording failure does not leak an
      // exception — the policy decision is already made.
      try {
        await _recordMessage(
          kind: AgentMessageKind.action,
          metadata: AgentMessageMetadata(
            runKey: runKey,
            toolName: toolName,
            operationId: operationId,
            policyDenied: true,
            denialReason: denialReason,
          ),
          payloadText: jsonEncode(args),
        );
      } catch (e, s) {
        developer.log(
          'Failed to persist policy-denial audit message for $toolName '
          '(runKey: $runKey, operationId: $operationId)',
          name: 'AgentToolExecutor',
          error: e,
          stackTrace: s,
        );
      }

      return ToolExecutionResult(
        success: false,
        output: 'Policy denied: $denialReason',
        policyDenied: true,
        denialReason: denialReason,
      );
    }

    // 2. Record action message before executing (crash-safe ordering).
    await _recordMessage(
      kind: AgentMessageKind.action,
      metadata: AgentMessageMetadata(
        runKey: runKey,
        toolName: toolName,
        operationId: operationId,
      ),
      payloadText: jsonEncode(args),
    );

    // 3. Execute the handler.
    try {
      final result = await executeHandler();

      // 4. Capture vector clock for self-notification suppression.
      //    Isolated in its own try/catch so a failure here does not mask the
      //    successful tool execution result.
      if (result.success && result.mutatedEntityId != null) {
        try {
          final vc = await readVectorClock(result.mutatedEntityId!);
          if (vc != null) {
            _mutatedEntries[result.mutatedEntityId!] = vc;
            developer.log(
              'Captured vector clock for ${result.mutatedEntityId}: $vc',
              name: 'AgentToolExecutor',
            );
          }
        } catch (e, s) {
          developer.log(
            'Failed to capture vector clock for ${result.mutatedEntityId} '
            '— self-notification suppression may not work for this entity',
            name: 'AgentToolExecutor',
            error: e,
            stackTrace: s,
          );
        }
      }

      // 5. Record result message.
      //    Isolated in its own try/catch so an audit-write failure does not
      //    mask or alter the original successful ToolExecutionResult.
      try {
        await _recordMessage(
          kind: AgentMessageKind.toolResult,
          metadata: AgentMessageMetadata(
            runKey: runKey,
            toolName: toolName,
            operationId: operationId,
            errorMessage: result.errorMessage,
          ),
          payloadText: result.output,
        );
      } catch (e, s) {
        developer.log(
          'Failed to persist toolResult audit message for $toolName '
          '(runKey: $runKey, operationId: $operationId)',
          name: 'AgentToolExecutor',
          error: e,
          stackTrace: s,
        );
      }

      developer.log(
        'Tool $toolName completed: success=${result.success}',
        name: 'AgentToolExecutor',
      );

      return result;
    } catch (e, s) {
      developer.log(
        'Tool $toolName threw unexpectedly',
        name: 'AgentToolExecutor',
        error: e,
        stackTrace: s,
      );

      final errorResult = ToolExecutionResult(
        success: false,
        output: 'Error: $e',
        errorMessage: e.toString(),
      );

      // Persist the error audit message. Isolated in its own try/catch so
      // an audit-write failure does not mask the original error result.
      try {
        await _recordMessage(
          kind: AgentMessageKind.toolResult,
          metadata: AgentMessageMetadata(
            runKey: runKey,
            toolName: toolName,
            operationId: operationId,
            errorMessage: e.toString(),
          ),
          payloadText: 'Error: $e',
        );
      } catch (auditError, auditStack) {
        developer.log(
          'Failed to persist error toolResult audit message for $toolName '
          '(runKey: $runKey, operationId: $operationId)',
          name: 'AgentToolExecutor',
          error: auditError,
          stackTrace: auditStack,
        );
      }

      return errorResult;
    }
  }

  Future<void> _recordMessage({
    required AgentMessageKind kind,
    required AgentMessageMetadata metadata,
    String? payloadText,
  }) async {
    final now = clock.now();
    String? contentEntryId;

    if (payloadText != null) {
      contentEntryId = _uuid.v4();
      await syncService.upsertEntity(
        AgentDomainEntity.agentMessagePayload(
          id: contentEntryId,
          agentId: agentId,
          createdAt: now,
          vectorClock: null,
          content: <String, Object?>{'text': payloadText},
        ),
      );
    }

    await syncService.upsertEntity(
      AgentDomainEntity.agentMessage(
        id: _uuid.v4(),
        agentId: agentId,
        threadId: threadId,
        kind: kind,
        createdAt: now,
        // Agent messages receive vector clocks at sync time, not at creation.
        vectorClock: null,
        contentEntryId: contentEntryId,
        metadata: metadata,
      ),
    );
  }
}
