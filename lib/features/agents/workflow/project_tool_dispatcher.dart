import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/service/task_agent_service.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/tools/change_effect.dart';
import 'package:lotti/features/agents/tools/project_tool_definitions.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/repositories/project_repository.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:uuid/uuid.dart';

/// Dispatches confirmed project-agent change-set items to project-domain
/// mutations.
///
/// A confirmed change item names its effect ([ChangeEffect]), so the same
/// proposal confirmed on two devices before they sync changes the journal
/// once (ADR 0097): `create_task` derives the task's id from the item, and
/// `update_project_status` applies only while the project still holds the
/// status the proposal was made against.
class ProjectToolDispatcher {
  ProjectToolDispatcher({
    required this.projectRepository,
    required this.persistenceLogic,
    required this.entitiesCacheService,
    required this.journalDb,
    this.domainLogger,
    this.taskAgentService,
  });

  final ProjectRepository projectRepository;
  final PersistenceLogic persistenceLogic;
  final EntitiesCacheService entitiesCacheService;
  final JournalDb journalDb;
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

    // A confirmed change item names its effect; no handler sees the reserved
    // arguments that carry it.
    final (:effect, args: toolArgs) = ChangeEffect.takeFrom(args);

    switch (toolName) {
      case ProjectAgentToolNames.recommendNextSteps:
        return _handleRecommendNextSteps(toolArgs);
      case ProjectAgentToolNames.updateProjectStatus:
        return _handleUpdateProjectStatus(toolArgs, projectId, effect);
      case ProjectAgentToolNames.createTask:
        return _handleCreateTask(toolArgs, projectId, effect);
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
    ChangeEffect? effect,
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
    final parsedStatus = parseProjectStatus(
      statusValue,
      reason: reason,
      now: now,
    );
    if (parsedStatus == null) {
      return ToolExecutionResult(
        success: false,
        output:
            'Error: unsupported project status "$statusValue". '
            'Use open, active, monitoring, on_hold, completed, or '
            'archived.',
        errorMessage: 'Invalid project status',
      );
    }

    // A status that moved on from the one the proposal was made against was
    // applied already — on another device that confirmed the same item — or
    // set since, and either way it stands.
    if (effect?.changedIn(projectFields(project.data.status))
        case final field?) {
      return ChangeEffect.notApplied('project', field);
    }

    if (isSameSemanticStatus(project.data.status, parsedStatus)) {
      return ToolExecutionResult(
        success: true,
        output: 'Project already has status ${parsedStatus.label}',
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
      output: 'Updated project status to ${parsedStatus.label}',
      mutatedEntityId: projectId,
    );
  }

  /// Creates a task in the project. With an [effect] — a confirmed change
  /// item — the task's id is derived from the item, so the same item
  /// confirmed on two devices creates one task: when it already exists
  /// (written here, synced from the other device, or deleted since), nothing
  /// is written and its id is returned.
  Future<ToolExecutionResult> _handleCreateTask(
    Map<String, dynamic> args,
    String projectId,
    ChangeEffect? effect,
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
    final priority = parseTaskPriority(rawPriority);
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

    if (await _createdBefore(effect, title, projectId, categoryId)
        case final existing?) {
      return existing;
    }

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
      private: project.meta.private,
      uuidV5Input: effect?.entityInput(_taskRole),
    );

    if (task == null) {
      // The insert refuses an id that exists: the other device's task can
      // have arrived between the check above and the write.
      if (await _createdBefore(effect, title, projectId, categoryId)
          case final existing?) {
        return existing;
      }
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
      // A derived id stays spent once rolled back: a retry would find its
      // tombstone and create nothing, so with an effect the failure is final.
      return ToolExecutionResult(
        success: false,
        nonRetryable: !rolledBack || effect != null,
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

  /// The role of the task in its [ChangeEffect]'s derived ids.
  static const _taskRole = 'task';

  /// The result for a task an earlier application of [effect] created, or
  /// `null` when there is none (or no effect).
  ///
  /// That application can have stopped after the task — the app died before
  /// its project link or agent were written — or run on another device. So
  /// a live task that is in no project is linked to [projectId], and one
  /// without an agent gets its agent (`specs/tla/ChangeDispatchRecovery.tla`,
  /// TailOnRerun). The link takes the id derived from its triple, so it
  /// converges with the creator's own; a task filed elsewhere since, or
  /// deleted, is left as it is, and a link that fails is reported, never
  /// rolled back over the existing task.
  Future<ToolExecutionResult?> _createdBefore(
    ChangeEffect? effect,
    String title,
    String projectId,
    String? categoryId,
  ) async {
    if (effect == null || !await effect.created(journalDb, _taskRole)) {
      return null;
    }
    final taskId = effect.entityId(_taskRole);
    final warnings = <String>[];
    final task = await journalDb.journalEntityById(taskId);
    if (task is Task) {
      if (await projectRepository.getProjectForTask(taskId) == null &&
          !await projectRepository.linkTaskToProject(
            projectId: projectId,
            taskId: taskId,
          )) {
        warnings.add('failed to link the task to the project');
      }
      await _tryAutoAssignTaskAgent(
        task,
        categoryId: categoryId,
        warnings: warnings,
      );
    }
    final warningMessage = warnings.isEmpty ? null : warnings.join('; ');
    return ToolExecutionResult(
      success: true,
      output: warningMessage == null
          ? 'Task "$title" already exists ($taskId)'
          : 'Task "$title" already exists ($taskId). Warning: $warningMessage',
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
    } catch (error, stackTrace) {
      domainLogger?.error(
        LogDomain.agentWorkflow,
        error,
        message:
            'Failed to roll back created task '
            '${DomainLogger.sanitizeId(task.meta.id)}',
        stackTrace: stackTrace,
        subDomain: _sub,
      );
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
      // A task that has its agent — assigned by an earlier application of
      // this change — keeps it.
      if (await service.getTaskAgentForTask(task.meta.id) != null) return;
      await service.createTaskAgent(
        taskId: task.meta.id,
        templateId: templateId,
        profileId: category.defaultProfileId,
        allowedCategoryIds: {categoryId},
        awaitContent: true,
        automaticUpdatesEnabled: category.automaticAgentWakesEnabledEffective,
      );
    } catch (error, stackTrace) {
      domainLogger?.error(
        LogDomain.agentWorkflow,
        error,
        message:
            'Failed to auto-assign task agent for project-created task '
            '${DomainLogger.sanitizeId(task.meta.id)}',
        stackTrace: stackTrace,
        subDomain: _sub,
      );
      warnings.add('failed to auto-assign a task agent');
    }
  }

  static ProjectStatus? parseProjectStatus(
    String rawStatus, {
    required String? reason,
    required DateTime now,
  }) {
    // Alias normalization is shared with the render-time proposal summary,
    // which shows the same canonical status this will set.
    return switch (canonicalProjectStatus(rawStatus)) {
      'open' => ProjectStatus.open(
        id: _uuid.v1(),
        createdAt: now,
        utcOffset: now.timeZoneOffset.inMinutes,
      ),
      'active' => ProjectStatus.active(
        id: _uuid.v1(),
        createdAt: now,
        utcOffset: now.timeZoneOffset.inMinutes,
      ),
      'monitoring' => ProjectStatus.monitoring(
        id: _uuid.v1(),
        createdAt: now,
        utcOffset: now.timeZoneOffset.inMinutes,
      ),
      'on_hold' => ProjectStatus.onHold(
        id: _uuid.v1(),
        createdAt: now,
        utcOffset: now.timeZoneOffset.inMinutes,
        reason: (reason == null || reason.trim().isEmpty)
            ? 'No reason provided'
            : reason.trim(),
      ),
      'completed' => ProjectStatus.completed(
        id: _uuid.v1(),
        createdAt: now,
        utcOffset: now.timeZoneOffset.inMinutes,
      ),
      'archived' => ProjectStatus.archived(
        id: _uuid.v1(),
        createdAt: now,
        utcOffset: now.timeZoneOffset.inMinutes,
      ),
      _ => null,
    };
  }

  static bool isSameSemanticStatus(
    ProjectStatus current,
    ProjectStatus next,
  ) {
    return switch ((current, next)) {
      (ProjectOpen(), ProjectOpen()) => true,
      (ProjectActive(), ProjectActive()) => true,
      (ProjectMonitoring(), ProjectMonitoring()) => true,
      (ProjectCompleted(), ProjectCompleted()) => true,
      (ProjectArchived(), ProjectArchived()) => true,
      (ProjectOnHold(:final reason), ProjectOnHold(reason: final nextReason)) =>
        reason == nextReason,
      _ => false,
    };
  }
}
