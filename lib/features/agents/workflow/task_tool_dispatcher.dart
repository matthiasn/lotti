import 'dart:developer' as developer;

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/service/task_agent_service.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/workflow/task_agent_workflow.dart'
    show TaskAgentWorkflow;
import 'package:lotti/features/agents/workflow/task_tool_handlers.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/logic/persistence_logic.dart';
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
    this.domainLogger,
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
  final DomainLogger? domainLogger;
  final TaskAgentService? taskAgentService;
  final ProjectRepository? projectRepository;
  final AgentRepository? agentRepository;
  final AgentSyncService? syncService;
  final String? requestingAgentId;

  /// Executes a tool handler by delegating to the appropriate existing
  /// journal-domain handler.
  ///
  /// Each tool call returns a [ToolExecutionResult] that the
  /// [AgentToolExecutor] wraps with audit logging and policy enforcement.
  Future<ToolExecutionResult> dispatch(
    String toolName,
    Map<String, dynamic> args,
    String taskId,
  ) async {
    developer.log(
      'Dispatching tool handler: $toolName',
      name: 'TaskToolDispatcher',
    );

    final resolvedName = resolveTaskAgentToolAlias(toolName);
    if (resolvedName != toolName) {
      developer.log(
        'Resolved tool alias $toolName -> $resolvedName',
        name: 'TaskToolDispatcher',
      );
    }
    final normalizedArgs = decodeStringifiedJsonArguments(args);

    // Deliberately reload the task from the database on every tool call.
    // This guarantees each handler sees the committed state left by the
    // previous handler (e.g. a title change is visible to the next tool).
    // A local SQLite read by primary key is negligible cost, and caching
    // in memory would add complexity with risk of stale state.
    final taskEntity = await journalDb.journalEntityById(taskId);
    if (taskEntity is! Task) {
      return ToolExecutionResult(
        success: false,
        output: 'Task $taskId not found or is not a Task entity',
        errorMessage: 'Task lookup failed',
      );
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
        );

      case TaskAgentToolNames.addMultipleChecklistItems:
        return handleBatchChecklist(
          taskEntity,
          resolvedName,
          normalizedArgs,
          taskId,
        );

      case TaskAgentToolNames.updateChecklistItem:
        return handleChecklistUpdate(
          taskEntity,
          TaskAgentToolNames.updateChecklistItems,
          {
            'items': [normalizedArgs],
          },
          taskId,
        );

      case TaskAgentToolNames.updateChecklistItems:
        return handleChecklistUpdate(
          taskEntity,
          resolvedName,
          normalizedArgs,
          taskId,
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
        return handleCreateFollowUpTask(normalizedArgs, taskId);

      case TaskAgentToolNames.migrateChecklistItem:
      case TaskAgentToolNames.migrateChecklistItems:
        return handleMigrateChecklistItem(normalizedArgs, taskId);

      case TaskAgentToolNames.linkTask:
        return handleLinkTask(normalizedArgs, taskId);

      case TaskAgentToolNames.createTimeEntry:
        return handleCreateTimeEntry(normalizedArgs, taskId);

      case TaskAgentToolNames.updateTimeEntry:
        return handleUpdateTimeEntry(normalizedArgs, taskId);

      case TaskAgentToolNames.updateRunningTimer:
        return handleUpdateRunningTimer(normalizedArgs, taskId);

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
}
