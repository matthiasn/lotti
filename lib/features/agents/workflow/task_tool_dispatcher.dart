import 'dart:convert';
import 'dart:developer' as developer;

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/service/task_agent_service.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/tools/attention_request_handler.dart';
import 'package:lotti/features/agents/tools/checklist_migration_handler.dart';
import 'package:lotti/features/agents/tools/follow_up_task_handler.dart';
import 'package:lotti/features/agents/tools/running_timer_update_handler.dart';
import 'package:lotti/features/agents/tools/task_label_handler.dart';
import 'package:lotti/features/agents/tools/task_language_handler.dart';
import 'package:lotti/features/agents/tools/task_status_handler.dart';
import 'package:lotti/features/agents/tools/task_title_handler.dart';
import 'package:lotti/features/agents/tools/time_entry_handler.dart';
import 'package:lotti/features/agents/tools/time_entry_update_handler.dart';
import 'package:lotti/features/agents/workflow/task_agent_workflow.dart'
    show TaskAgentWorkflow;
import 'package:lotti/features/ai/functions/lotti_batch_checklist_handler.dart';
import 'package:lotti/features/ai/functions/lotti_checklist_update_handler.dart';
import 'package:lotti/features/ai/functions/task_due_date_handler.dart';
import 'package:lotti/features/ai/functions/task_estimate_handler.dart';
import 'package:lotti/features/ai/functions/task_priority_handler.dart';
import 'package:lotti/features/ai/services/auto_checklist_service.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/labels/services/label_assignment_processor.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/time_service.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:uuid/uuid.dart';

part 'task_tool_handlers.dart';

const _uuid = Uuid();

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

    switch (toolName) {
      case TaskAgentToolNames.setTaskTitle:
        return _handleSetTaskTitle(taskEntity, args, taskId);

      case TaskAgentToolNames.updateTaskEstimate:
        return _handleProcessToolCall(taskEntity, toolName, args, taskId);

      case TaskAgentToolNames.updateTaskDueDate:
        return _handleProcessToolCall(taskEntity, toolName, args, taskId);

      case TaskAgentToolNames.updateTaskPriority:
        return _handleProcessToolCall(taskEntity, toolName, args, taskId);

      case TaskAgentToolNames.addChecklistItem:
        return _handleBatchChecklist(
          taskEntity,
          TaskAgentToolNames.addMultipleChecklistItems,
          {
            'items': [args],
          },
          taskId,
        );

      case TaskAgentToolNames.addMultipleChecklistItems:
        return _handleBatchChecklist(taskEntity, toolName, args, taskId);

      case TaskAgentToolNames.updateChecklistItem:
        return _handleChecklistUpdate(
          taskEntity,
          TaskAgentToolNames.updateChecklistItems,
          {
            'items': [args],
          },
          taskId,
        );

      case TaskAgentToolNames.updateChecklistItems:
        return _handleChecklistUpdate(taskEntity, toolName, args, taskId);

      case TaskAgentToolNames.assignTaskLabel:
        return _handleAssignLabels(
          taskEntity,
          {
            'labels': [args],
          },
          taskId,
        );

      case TaskAgentToolNames.assignTaskLabels:
        return _handleAssignLabels(taskEntity, args, taskId);

      case TaskAgentToolNames.setTaskLanguage:
        return _handleSetLanguage(taskEntity, args, taskId);

      case TaskAgentToolNames.setTaskStatus:
        return _handleSetStatus(taskEntity, args, taskId);

      case TaskAgentToolNames.createFollowUpTask:
        return _handleCreateFollowUpTask(args, taskId);

      case TaskAgentToolNames.migrateChecklistItem:
      case TaskAgentToolNames.migrateChecklistItems:
        return _handleMigrateChecklistItem(args, taskId);

      case TaskAgentToolNames.createTimeEntry:
        return _handleCreateTimeEntry(args, taskId);

      case TaskAgentToolNames.updateTimeEntry:
        return _handleUpdateTimeEntry(args, taskId);

      case TaskAgentToolNames.updateRunningTimer:
        return _handleUpdateRunningTimer(args, taskId);

      case TaskAgentToolNames.requestAttention:
        return _handleRequestAttention(taskEntity, args);

      case TaskAgentToolNames.resolveAttentionRequest:
        return _handleResolveAttentionRequest(taskEntity, args);

      default:
        return ToolExecutionResult(
          success: false,
          output: 'Unknown tool: $toolName',
          errorMessage: 'Tool $toolName is not registered for the Task Agent',
        );
    }
  }
}
