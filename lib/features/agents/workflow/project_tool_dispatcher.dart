import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/service/task_agent_service.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/tools/project_tool_definitions.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:uuid/uuid.dart';

/// Dispatches confirmed project-agent change-set items to project-domain
/// mutations.
class ProjectToolDispatcher {
  ProjectToolDispatcher({
    required this.projectRepository,
    required this.persistenceLogic,
    required this.entitiesCacheService,
    this.domainLogger,
    this.taskAgentService,
  });

  final ProjectRepository projectRepository;
  final PersistenceLogic persistenceLogic;
  final EntitiesCacheService entitiesCacheService;
  final DomainLogger? domainLogger;
  final TaskAgentService? taskAgentService;

  static const _uuid = Uuid();
  static const _sub = 'ProjectToolDispatcher';

  Future<ToolExecutionResult> dispatch(
    String toolName,
    Map<String, dynamic> args,
    String projectId,
  ) async {
    developer.log(
      'Dispatching project tool handler: $toolName',
      name: 'ProjectToolDispatcher',
    );

    switch (toolName) {
      case ProjectAgentToolNames.recommendNextSteps:
        return _handleRecommendNextSteps(args);
      case ProjectAgentToolNames.updateProjectStatus:
        return _handleUpdateProjectStatus(args, projectId);
      case ProjectAgentToolNames.createTask:
        return _handleCreateTask(args, projectId);
      default:
        return ToolExecutionResult(
          success: false,
          output: 'Unknown tool: $toolName',
          errorMessage:
              'Tool $toolName is not registered for the Project Agent',
        );
    }
  }

  Future<ToolExecutionResult> _handleRecommendNextSteps(
    Map<String, dynamic> args,
  ) async {
    final steps = args['steps'];
    if (steps is! List || steps.isEmpty) {
      return const ToolExecutionResult(
        success: false,
        output: 'Error: "steps" must be a non-empty array',
        errorMessage: 'Type validation failed for steps',
      );
    }

    return ToolExecutionResult(
      success: true,
      output: 'Accepted ${steps.length} recommended next step(s)',
    );
  }

  Future<ToolExecutionResult> _handleUpdateProjectStatus(
    Map<String, dynamic> args,
    String projectId,
  ) async {
    final statusValue = args['status'];
    if (statusValue is! String || statusValue.trim().isEmpty) {
      return const ToolExecutionResult(
        success: false,
        output: 'Error: "status" must be a non-empty string',
        errorMessage: 'Type validation failed for status',
      );
    }

    final project = await projectRepository.getProjectById(projectId);
    if (project == null) {
      return ToolExecutionResult(
        success: false,
        output: 'Project $projectId not found',
        errorMessage: 'Project lookup failed',
      );
    }

    final reason = args['reason'] as String?;
    final now = clock.now();
    final parsedStatus = _parseProjectStatus(
      statusValue,
      reason: reason,
      now: now,
    );
    if (parsedStatus == null) {
      return ToolExecutionResult(
        success: false,
        output:
            'Error: unsupported project status "$statusValue". '
            'Use open, active, on_hold, completed, or archived.',
        errorMessage: 'Invalid project status',
      );
    }

    if (_isSameSemanticStatus(project.data.status, parsedStatus)) {
      return ToolExecutionResult(
        success: true,
        output: 'Project already has status ${_statusLabel(parsedStatus)}',
      );
    }

    final updated = project.copyWith(
      data: project.data.copyWith(
        status: parsedStatus,
        statusHistory: [...project.data.statusHistory, project.data.status],
      ),
    );

    final success = await projectRepository.updateProject(updated);
    if (!success) {
      return const ToolExecutionResult(
        success: false,
        output: 'Error: failed to update project status',
        errorMessage: 'Project update failed',
      );
    }

    return ToolExecutionResult(
      success: true,
      output: 'Updated project status to ${_statusLabel(parsedStatus)}',
      mutatedEntityId: projectId,
    );
  }

  Future<ToolExecutionResult> _handleCreateTask(
    Map<String, dynamic> args,
    String projectId,
  ) async {
    final title = args['title'];
    if (title is! String || title.trim().isEmpty) {
      return const ToolExecutionResult(
        success: false,
        output: 'Error: "title" must be a non-empty string',
        errorMessage: 'Missing or empty title',
      );
    }

    final project = await projectRepository.getProjectById(projectId);
    if (project == null) {
      return ToolExecutionResult(
        success: false,
        output: 'Project $projectId not found',
        errorMessage: 'Project lookup failed',
      );
    }

    final now = clock.now();
    final rawPriority = args['priority'];
    final priority = _parseTaskPriority(rawPriority);
    if (rawPriority != null && priority == null) {
      return const ToolExecutionResult(
        success: false,
        output:
            'Error: "priority" must be one of CRITICAL, HIGH, MEDIUM, LOW, '
            'P0, P1, P2, or P3',
        errorMessage: 'Invalid priority',
      );
    }

    final categoryId = project.meta.categoryId;
    final category = entitiesCacheService.getCategoryById(categoryId);
    final entryText = EntryText(
      plainText: args['description'] is String
          ? args['description'] as String
          : '',
    );

    final task = await persistenceLogic.createTaskEntry(
      data: TaskData(
        status: TaskStatus.open(
          id: _uuid.v1(),
          createdAt: now,
          utcOffset: now.timeZoneOffset.inMinutes,
        ),
        dateFrom: now,
        dateTo: now,
        statusHistory: const [],
        title: title.trim(),
        priority: priority ?? TaskPriority.p2Medium,
        profileId: category?.defaultProfileId,
      ),
      entryText: entryText,
      categoryId: categoryId,
    );

    if (task == null) {
      return const ToolExecutionResult(
        success: false,
        output: 'Error: failed to create task',
        errorMessage: 'Task creation failed',
      );
    }

    final warnings = <String>[];
    final taskId = task.meta.id;

    final linked = await projectRepository.linkTaskToProject(
      projectId: projectId,
      taskId: taskId,
    );
    if (!linked) {
      final rolledBack = await _rollbackCreatedTask(task);
      return ToolExecutionResult(
        success: false,
        output: rolledBack
            ? 'Error: failed to link task "$title" to the project. '
                  'Rolled back the created task.'
            : 'Error: failed to link task "$title" to the project. '
                  'Rollback failed; manual cleanup may be required for $taskId.',
        errorMessage: rolledBack
            ? 'Failed to link the new task to the project'
            : 'Failed to link the new task to the project; '
                  'rollback failed for $taskId',
      );
    }

    await _tryAutoAssignTaskAgent(
      task,
      categoryId: categoryId,
      warnings: warnings,
    );

    final warningMessage = warnings.isEmpty ? null : warnings.join('; ');
    final output = StringBuffer('Created task "$title" ($taskId)');
    if (warningMessage != null) {
      output.write('. Warning: $warningMessage');
    }

    return ToolExecutionResult(
      success: true,
      output: output.toString(),
      mutatedEntityId: taskId,
      errorMessage: warningMessage,
    );
  }

  Future<bool> _rollbackCreatedTask(Task task) async {
    try {
      final deletedMeta = await persistenceLogic.updateMetadata(
        task.meta,
        deletedAt: clock.now(),
      );
      final deletedTask = task.copyWith(meta: deletedMeta);
      return (await persistenceLogic.updateDbEntity(deletedTask)) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _tryAutoAssignTaskAgent(
    Task task, {
    required String? categoryId,
    required List<String> warnings,
  }) async {
    final service = taskAgentService;
    if (service == null || categoryId == null) return;

    final category = entitiesCacheService.getCategoryById(categoryId);
    final templateId = category?.defaultTemplateId;
    if (category == null || templateId == null) return;

    try {
      await service.createTaskAgent(
        taskId: task.meta.id,
        templateId: templateId,
        profileId: category.defaultProfileId,
        allowedCategoryIds: {categoryId},
        awaitContent: true,
      );
    } catch (error, stackTrace) {
      domainLogger?.error(
        LogDomains.agentWorkflow,
        'Failed to auto-assign task agent for project-created task '
        '${task.meta.id}',
        error: error,
        stackTrace: stackTrace,
        subDomain: _sub,
      );
      warnings.add('failed to auto-assign a task agent');
    }
  }

  static TaskPriority? _parseTaskPriority(Object? rawPriority) {
    if (rawPriority == null) return TaskPriority.p2Medium;
    if (rawPriority is! String) return null;

    return switch (rawPriority.trim().toUpperCase()) {
      'CRITICAL' || 'P0' => TaskPriority.p0Urgent,
      'HIGH' || 'P1' => TaskPriority.p1High,
      'MEDIUM' || 'P2' => TaskPriority.p2Medium,
      'LOW' || 'P3' => TaskPriority.p3Low,
      _ => null,
    };
  }

  static ProjectStatus? _parseProjectStatus(
    String rawStatus, {
    required String? reason,
    required DateTime now,
  }) {
    final normalized = rawStatus
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');

    return switch (normalized) {
      'open' => ProjectStatus.open(
        id: _uuid.v1(),
        createdAt: now,
        utcOffset: now.timeZoneOffset.inMinutes,
      ),
      'active' || 'on_track' || 'in_progress' => ProjectStatus.active(
        id: _uuid.v1(),
        createdAt: now,
        utcOffset: now.timeZoneOffset.inMinutes,
      ),
      'on_hold' || 'hold' || 'blocked' || 'at_risk' => ProjectStatus.onHold(
        id: _uuid.v1(),
        createdAt: now,
        utcOffset: now.timeZoneOffset.inMinutes,
        reason: (reason == null || reason.trim().isEmpty)
            ? 'No reason provided'
            : reason.trim(),
      ),
      'completed' || 'complete' || 'done' => ProjectStatus.completed(
        id: _uuid.v1(),
        createdAt: now,
        utcOffset: now.timeZoneOffset.inMinutes,
      ),
      'archived' ||
      'archive' ||
      'cancelled' ||
      'canceled' => ProjectStatus.archived(
        id: _uuid.v1(),
        createdAt: now,
        utcOffset: now.timeZoneOffset.inMinutes,
      ),
      _ => null,
    };
  }

  static bool _isSameSemanticStatus(
    ProjectStatus current,
    ProjectStatus next,
  ) {
    return switch ((current, next)) {
      (ProjectOpen(), ProjectOpen()) => true,
      (ProjectActive(), ProjectActive()) => true,
      (ProjectCompleted(), ProjectCompleted()) => true,
      (ProjectArchived(), ProjectArchived()) => true,
      (ProjectOnHold(:final reason), ProjectOnHold(reason: final nextReason)) =>
        reason == nextReason,
      _ => false,
    };
  }

  static String _statusLabel(ProjectStatus status) {
    return switch (status) {
      ProjectOpen() => 'Open',
      ProjectActive() => 'Active',
      ProjectOnHold() => 'On Hold',
      ProjectCompleted() => 'Completed',
      ProjectArchived() => 'Archived',
    };
  }
}
