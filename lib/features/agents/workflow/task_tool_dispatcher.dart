import 'package:lotti/classes/agents/retired_tool_calls.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/agents/agent_repository.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/service/task_agent_service.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/tools/change_effect.dart';
import 'package:lotti/features/agents/workflow/change_proposal_filter.dart';
import 'package:lotti/features/agents/workflow/task_agent_workflow.dart'
    show TaskAgentWorkflow;
import 'package:lotti/features/agents/workflow/task_tool_handlers.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/repositories/checklist_repository.dart';
import 'package:lotti/logic/repositories/journal_repository.dart';
import 'package:lotti/logic/repositories/project_repository.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/time_service.dart';

/// Dispatches tool calls from the Task Agent to the appropriate journal-domain
/// handlers.
///
/// Extracted from [TaskAgentWorkflow] to reduce file size and improve
/// testability of tool dispatch logic independently of the wake cycle.
class TaskToolDispatcher {
  TaskToolDispatcher({
    required this.journalDb,
    required this.journalRepository,
    required this.checklistRepository,
    required this.labelsRepository,
    required this.persistenceLogic,
    required this.timeService,
    required this.domainLogger,
    this.taskAgentService,
    this.projectRepository,
    this.agentRepository,
    this.syncService,
    this.requestingAgentId,
  });

  final JournalDb journalDb;
  final JournalRepository journalRepository;
  final ChecklistRepository checklistRepository;
  final LabelsRepository labelsRepository;
  final PersistenceLogic persistenceLogic;
  final TimeService timeService;
  final DomainLogger domainLogger;
  final TaskAgentService? taskAgentService;
  final ProjectRepository? projectRepository;
  final AgentRepository? agentRepository;
  final AgentSyncService? syncService;
  final String? requestingAgentId;

  /// Human confirmation supplies this receipt separately from untrusted args.
  Future<ToolExecutionResult> dispatchApproved(
    String name,
    Map<String, dynamic> args,
    String taskId,
    ChecklistItemProvenance? approval,
  ) => dispatch(name, args, taskId, approval: approval);

  /// Executes a tool handler by delegating to the appropriate existing
  /// journal-domain handler.
  ///
  /// Each tool call returns a [ToolExecutionResult] that the
  /// [AgentToolExecutor] wraps with audit logging and policy enforcement.
  Future<ToolExecutionResult> dispatch(
    String toolName,
    Map<String, dynamic> args,
    String taskId, {
    ChecklistItemProvenance? approval,
  }) async {
    domainLogger.log(
      LogDomain.agentWorkflow,
      'Dispatching tool handler: $toolName',
      subDomain: 'TaskToolDispatcher',
    );

    // A confirmed change item names its effect; no handler sees the reserved
    // arguments that carry it.
    final (:effect, args: toolArgs) = ChangeEffect.takeFrom(args);

    // A retired name is rewritten, not rejected: proposals persisted under it
    // (or synced from an older build) must still apply once confirmed.
    final call = upgradeRetiredTaskAgentToolCall(
      resolveTaskAgentToolAlias(toolName),
      decodeStringifiedJsonArguments(toolArgs),
    );
    final resolvedName = call.toolName;
    final normalizedArgs = call.args;
    if (resolvedName != toolName) {
      domainLogger.log(
        LogDomain.agentWorkflow,
        'Resolved tool alias $toolName -> $resolvedName',
        subDomain: 'TaskToolDispatcher',
      );
    }

    // Deliberately reload the task from the database on every tool call.
    // This guarantees each handler sees the committed state left by the
    // previous handler (e.g. a title change is visible to the next tool).
    // A local SQLite read by primary key is negligible cost, and caching
    // in memory would add complexity with risk of stale state.
    final storedTask = await journalDb.journalEntityById(taskId);
    if (storedTask is! Task) {
      // A task deleted since the proposal was made can never take it, here
      // or on any device: the failure is final, so the item is retracted
      // instead of going back to pending, where every confirmation would
      // fail again and the suggestion would stay counted forever. The
      // second read must still find the tombstone: a task restored between
      // the two reads is live, and its failure stays retryable.
      final tombstone = storedTask == null
          ? await journalDb.journalEntityByIdIncludingDeleted(taskId)
          : null;
      final deleted = tombstone is Task && tombstone.meta.deletedAt != null;
      return deleted
          ? ToolExecutionResult(
              success: false,
              output: 'Task $taskId was deleted',
              errorMessage: 'Task deleted',
              nonRetryable: true,
            )
          : ToolExecutionResult(
              success: false,
              output: 'Task $taskId not found or is not a Task entity',
              errorMessage: 'Task lookup failed',
            );
    }

    // A field proposal applies once. The tool records the change's effect key
    // on the task in the very write that sets the field, so the record syncs
    // with the value; a task that records it had the change applied —
    // here, or on the device it synced from — and whatever the field holds
    // now, the base value the user restored included, stands (ADR 0098).
    final fieldEffect = taskFieldSetBy(resolvedName) != null ? effect : null;
    if (fieldEffect != null && fieldEffect.recordedOn(storedTask)) {
      return const ToolExecutionResult(
        success: true,
        output:
            'Nothing applied: this change was applied to the task already, '
            'so the field stays as it is now.',
      );
    }
    final taskEntity = fieldEffect?.recordOn(storedTask) ?? storedTask;

    // A field proposal applies only while the task still holds the value it
    // was made against. Anything else means it was applied already — on
    // another device that confirmed the same item — or edited since, and
    // either way the newer value stands. That is not a failure: a failure
    // would put the item back to pending, or retract it over a confirm that
    // did land elsewhere.
    final changedField = effect?.changedField(
      ChangeProposalFilter.taskMetadataFields(
        ChangeProposalFilter.taskMetadataOf(taskEntity),
      ),
    );
    if (changedField != null) {
      return ChangeEffect.notApplied('task', changedField);
    }
    // The same for a proposal that edits a checklist item or a time entry
    // rather than the task (ADR 0097).
    if (await _targetMovedOn(resolvedName, normalizedArgs, effect)
        case final ToolExecutionResult notApplied) {
      return notApplied;
    }

    switch (resolvedName) {
      case TaskAgentToolNames.setTaskTitle:
        return handleSetTaskTitle(taskEntity, normalizedArgs, taskId);

      case TaskAgentToolNames.updateTaskEstimate:
        return handleProcessToolCall(
          taskEntity,
          resolvedName,
          normalizedArgs,
          taskId,
        );

      case TaskAgentToolNames.updateTaskDueDate:
        return handleProcessToolCall(
          taskEntity,
          resolvedName,
          normalizedArgs,
          taskId,
        );

      case TaskAgentToolNames.updateTaskPriority:
        return handleProcessToolCall(
          taskEntity,
          resolvedName,
          normalizedArgs,
          taskId,
        );

      case TaskAgentToolNames.addChecklistItem:
        return handleBatchChecklist(
          taskEntity,
          TaskAgentToolNames.addMultipleChecklistItems,
          {
            'items': [normalizedArgs],
          },
          taskId,
          approval: approval,
          effect: effect,
        );

      case TaskAgentToolNames.addMultipleChecklistItems:
        return handleBatchChecklist(
          taskEntity,
          resolvedName,
          normalizedArgs,
          taskId,
          approval: approval,
          effect: effect,
        );

      case TaskAgentToolNames.updateChecklistItem:
        return handleChecklistUpdate(
          taskEntity,
          TaskAgentToolNames.updateChecklistItems,
          {
            'items': [normalizedArgs],
          },
          taskId,
          approval: approval,
        );

      case TaskAgentToolNames.updateChecklistItems:
        return handleChecklistUpdate(
          taskEntity,
          resolvedName,
          normalizedArgs,
          taskId,
          approval: approval,
        );

      case TaskAgentToolNames.assignTaskLabel:
        return handleAssignLabels(
          taskEntity,
          {
            'labels': [normalizedArgs],
          },
          taskId,
        );

      case TaskAgentToolNames.assignTaskLabels:
        return handleAssignLabels(taskEntity, normalizedArgs, taskId);

      case TaskAgentToolNames.setTaskLanguage:
        return handleSetLanguage(taskEntity, normalizedArgs, taskId);

      case TaskAgentToolNames.setTaskStatus:
        return handleSetStatus(taskEntity, normalizedArgs, taskId);

      case TaskAgentToolNames.createFollowUpTask:
        return handleCreateFollowUpTask(normalizedArgs, taskId, effect: effect);

      case TaskAgentToolNames.migrateChecklistItem:
      case TaskAgentToolNames.migrateChecklistItems:
        return handleMigrateChecklistItem(
          normalizedArgs,
          taskId,
          approval: approval,
          effect: effect,
        );

      case TaskAgentToolNames.linkTask:
        return handleLinkTask(normalizedArgs, taskId);

      case TaskAgentToolNames.createTimeEntry:
        return handleCreateTimeEntry(normalizedArgs, taskId, effect: effect);

      case TaskAgentToolNames.updateTimeEntry:
        return handleUpdateTimeEntry(normalizedArgs, taskId);

      case TaskAgentToolNames.requestAttention:
        return handleRequestAttention(taskEntity, normalizedArgs);

      case TaskAgentToolNames.resolveAttentionRequest:
        return handleResolveAttentionRequest(taskEntity, normalizedArgs);

      default:
        return ToolExecutionResult(
          success: false,
          output: 'Unknown tool: $toolName',
          errorMessage: 'Tool $toolName is not registered for the Task Agent',
        );
    }
  }

  /// What [effect]'s dispatch reports when the checklist item or time entry
  /// [toolName] edits no longer holds the fields the proposal was made
  /// against (`ChangeItem.targetBase`), or `null` when it holds them, when
  /// nothing was recorded, or when the entity cannot be read — the handler
  /// then reports that as it always has.
  Future<ToolExecutionResult?> _targetMovedOn(
    String toolName,
    Map<String, dynamic> args,
    ChangeEffect? effect,
  ) async {
    if (effect == null || effect.targetBase == null) return null;
    Future<JournalEntity?> read(Object? id) async =>
        id is String ? journalDb.journalEntityById(id.trim()) : null;
    final String what;
    final Map<String, Object?>? fields;
    switch (toolName) {
      case TaskAgentToolNames.updateChecklistItem:
        what = 'checklist item';
        final item = await read(args['id']);
        fields = item is ChecklistItem ? checklistItemFields(item.data) : null;
      case TaskAgentToolNames.updateTimeEntry:
        what = 'time entry';
        final entry = await read(args['entryId']);
        fields = entry is JournalEntry ? timeEntryFields(entry) : null;
      default:
        return null;
    }
    if (fields == null) return null;
    final changed = effect.changedIn(fields);
    return changed == null ? null : ChangeEffect.notApplied(what, changed);
  }
}
