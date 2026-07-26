import 'package:clock/clock.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/service/task_agent_service.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/tools/task_link_tool_definitions.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/features/tasks/model/directed_relation.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

/// Creates a follow-up task linked to the source task.
///
/// Used by the task agent's split workflow: the agent identifies a new task
/// from user audio/notes, calls `create_follow_up_task`, and the handler
/// creates the task entity plus exactly one link from source to new task.
///
/// Without a `relation` argument that link is a plain `BasicLink` from
/// source to new task (the historic behavior). With a `relation` — one of
/// the directed wire phrases from `DirectedRelation.wireNames`, read with
/// the SOURCE task as subject ("this task is_blocked_by the new task") —
/// the single edge is typed, and inverse phrases swap `fromId`/`toId` so
/// the canonical stored direction matches the UI's (ADR 0042).
///
/// The new task inherits the source task's category and project. Priority
/// defaults to P2 if not specified.
class FollowUpTaskHandler {
  FollowUpTaskHandler({
    required this._persistenceLogic,
    required this._journalDb,
    this._domainLogger,
    this._taskAgentService,
    this._projectRepository,
  });

  final PersistenceLogic _persistenceLogic;
  final JournalDb _journalDb;
  final DomainLogger? _domainLogger;
  final TaskAgentService? _taskAgentService;
  final ProjectRepository? _projectRepository;

  static const _uuid = Uuid();
  static const _sub = 'FollowUpTaskHandler';
  static final _dateOnly = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  /// Creates a follow-up task and links it to the source task.
  ///
  /// Returns a [ToolExecutionResult] with `mutatedEntityId` set to the new
  /// task's ID on success.
  Future<ToolExecutionResult> handle(
    String sourceTaskId,
    Map<String, dynamic> args,
  ) async {
    final title = args['title'];
    if (title is! String || title.trim().isEmpty) {
      return const ToolExecutionResult(
        success: false,
        output: 'Error: "title" must be a non-empty string',
        errorMessage: 'Missing or empty title',
      );
    }

    // Read source task to inherit category.
    final sourceEntity = await _journalDb.journalEntityById(sourceTaskId);
    if (sourceEntity is! Task) {
      return ToolExecutionResult(
        success: false,
        output: 'Error: source task $sourceTaskId not found or not a Task',
        errorMessage: 'Source task lookup failed',
      );
    }

    final categoryId = sourceEntity.meta.categoryId;
    final now = clock.now();

    // Parse optional fields.
    final rawPriority = args['priority'];
    final priority = parsePriority(rawPriority);
    if (rawPriority != null && priority == null) {
      return const ToolExecutionResult(
        success: false,
        output: 'Error: "priority" must be one of P0, P1, P2, P3',
        errorMessage: 'Invalid priority',
      );
    }
    final rawDueDate = args['dueDate'];
    final dueDate = _parseDueDate(rawDueDate);
    if (rawDueDate != null && dueDate == null) {
      return const ToolExecutionResult(
        success: false,
        output: 'Error: "dueDate" must be a valid YYYY-MM-DD date',
        errorMessage: 'Invalid dueDate',
      );
    }
    // Validated before any write so an invalid relation cannot leave an
    // orphaned task behind.
    final rawRelation = args['relation'];
    final relation = rawRelation is String
        ? DirectedRelation.fromWireName(rawRelation)
        : null;
    if (rawRelation != null && relation == null) {
      return ToolExecutionResult(
        success: false,
        output:
            'Error: "relation" must be one of '
            '${taskRelationWireNames.join(', ')}',
        errorMessage: 'Invalid relation',
      );
    }
    final description = args['description'];

    // Look up category defaults for profile inheritance.
    final category = categoryId != null
        ? getIt<EntitiesCacheService>().getCategoryById(categoryId)
        : null;

    // Build task data.
    final taskData = TaskData(
      status: TaskStatus.open(
        id: _uuid.v1(),
        createdAt: now,
        utcOffset: now.timeZoneOffset.inMinutes,
      ),
      dateFrom: now,
      dateTo: now,
      statusHistory: [],
      title: title.trim(),
      priority: priority!,
      due: dueDate,
      profileId: category?.defaultProfileId,
    );

    final entryText = EntryText(
      plainText: description is String ? description : '',
    );

    // Create the task entry.
    final newTask = await _persistenceLogic.createTaskEntry(
      data: taskData,
      entryText: entryText,
      categoryId: categoryId,
    );

    if (newTask == null) {
      return const ToolExecutionResult(
        success: false,
        output: 'Error: failed to create follow-up task',
        errorMessage: 'Task creation failed',
      );
    }

    final newTaskId = newTask.meta.id;

    // Verify the task is actually persisted and readable.
    final verifyTask = await _journalDb.journalEntityById(newTaskId);
    _domainLogger?.log(
      LogDomain.agentWorkflow,
      'Created task ${DomainLogger.sanitizeId(newTaskId)} — verify lookup: '
      '${verifyTask?.runtimeType} (found: ${verifyTask != null})',
      subDomain: _sub,
    );

    final warnings = <String>[];

    // Link source task ↔ new task. Without a relation this is the historic
    // plain link from source to new task; with one, the single edge is typed
    // and canonically directed (mirroring the UI's LinkTaskModal create
    // path, which never writes a basic edge alongside a typed one).
    // Persisted BEFORE the agent auto-assignment below: creating the agent
    // enqueues its creation wake immediately, and that first wake must see
    // the relationship (and inherited project) or its first report describes
    // a task without the very context the user just dictated.
    // Wrapped in try-catch so a link failure does not lose the
    // already-created task ID. Also checks the bool return value since
    // PersistenceLogic.createLink reports some failures that way.
    try {
      final bool linked;
      if (relation == null) {
        linked = await _persistenceLogic.createLink(
          fromId: sourceTaskId,
          toId: newTaskId,
        );
      } else {
        final endpoints = relation.canonicalEndpoints(
          anchorId: sourceTaskId,
          otherId: newTaskId,
        );
        linked = await _persistenceLogic.createLink(
          fromId: endpoints.fromId,
          toId: endpoints.toId,
          linkType: relation.type,
        );
      }
      if (!linked) {
        warnings.add(_linkFailureWarning(relation));
      }
    } catch (e) {
      _domainLogger?.error(
        LogDomain.agentWorkflow,
        e,
        message:
            'Failed to link source ${DomainLogger.sanitizeId(sourceTaskId)} → '
            '${DomainLogger.sanitizeId(newTaskId)}',
        subDomain: _sub,
      );
      warnings.add(_linkFailureWarning(relation));
    }

    // Inherit project from source task.
    await _tryInheritProject(sourceTaskId, newTaskId, warnings);

    // Auto-assign an agent from the category's default template, matching
    // the behavior of UI-created tasks in create_entry.dart. Runs last so
    // the creation wake it enqueues sees the link and project written above.
    await _tryAutoAssignAgent(
      newTask,
      categoryId: categoryId,
      category: category,
      warnings: warnings,
    );

    final output = StringBuffer('Created follow-up task "$title" ($newTaskId)');
    if (relation != null) {
      output.write(' — this task ${relation.englishPhrase} it');
    }
    for (final w in warnings) {
      output.write('. $w');
    }

    return ToolExecutionResult(
      success: true,
      output: output.toString(),
      mutatedEntityId: newTaskId,
    );
  }

  /// The warning for a failed source↔new-task link.
  ///
  /// Task creation is the primary outcome and stays a success — a
  /// compensating delete would destroy the task the user asked for, and a
  /// failure result would make a retried confirmation create a second task.
  /// A typed relationship is load-bearing though, so its warning names
  /// exactly what is missing instead of a generic "failed to link".
  static String _linkFailureWarning(DirectedRelation? relation) =>
      relation == null
      ? 'Warning: failed to link source task'
      : 'Warning: the task was created but the '
            '"${relation.englishPhrase}" relationship could not be recorded '
            '— link the tasks manually';

  /// Parses a priority string. Returns `null` if the value is present but
  /// not a recognized priority string (caller should reject).
  /// Absent/null values return `p2Medium` as default.
  @visibleForTesting
  static TaskPriority? parsePriority(Object? value) {
    if (value == null) return TaskPriority.p2Medium;
    if (value is! String) return null;
    final parsed = taskPriorityFromString(value);
    // taskPriorityFromString returns fallback for unknown values — detect that
    // by checking if the input (case-insensitive) matches a known priority.
    final upper = value.trim().toUpperCase();
    if (!const {'P0', 'P1', 'P2', 'P3'}.contains(upper)) return null;
    return parsed;
  }

  static DateTime? _parseDueDate(Object? value) {
    if (value is! String || value.isEmpty) return null;

    final match = _dateOnly.firstMatch(value);
    if (match == null) return null;

    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);

    if (month < 1 || month > 12) return null;
    if (day < 1 || day > _daysInMonth(year, month)) return null;

    return DateTime(year, month, day);
  }

  static int _daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;

  /// Inherits the project from [sourceTaskId] by linking [newTaskId] to the
  /// same project via [ProjectRepository.inheritProjectFromTask]. Failures are
  /// captured as warnings so they never prevent the follow-up task from being
  /// returned to the caller.
  Future<void> _tryInheritProject(
    String sourceTaskId,
    String newTaskId,
    List<String> warnings,
  ) async {
    final repo = _projectRepository;
    if (repo == null) return;

    try {
      final inherited = await repo.inheritProjectFromTask(
        sourceTaskId: sourceTaskId,
        newTaskId: newTaskId,
      );
      if (!inherited) {
        _domainLogger?.log(
          LogDomain.agentWorkflow,
          'No project to inherit from '
          '${DomainLogger.sanitizeId(sourceTaskId)} for '
          '${DomainLogger.sanitizeId(newTaskId)}',
          subDomain: _sub,
        );
      }
    } catch (e) {
      _domainLogger?.error(
        LogDomain.agentWorkflow,
        e,
        message:
            'Failed to inherit project from '
            '${DomainLogger.sanitizeId(sourceTaskId)} → '
            '${DomainLogger.sanitizeId(newTaskId)}',
        subDomain: _sub,
      );
      warnings.add('Warning: failed to inherit project');
    }
  }

  /// Auto-assigns an agent from the category's default template.
  ///
  /// Mirrors the logic in `autoAssignCategoryAgentWith` from
  /// `create_entry.dart`. Failures are captured as warnings so they
  /// never prevent the follow-up task from being returned to the caller.
  Future<void> _tryAutoAssignAgent(
    Task newTask, {
    required String? categoryId,
    required CategoryDefinition? category,
    required List<String> warnings,
  }) async {
    final service = _taskAgentService;
    if (service == null || categoryId == null || category == null) return;

    final templateId = category.defaultTemplateId;
    if (templateId == null) return;

    try {
      await service.createTaskAgent(
        taskId: newTask.meta.id,
        templateId: templateId,
        profileId: category.defaultProfileId,
        allowedCategoryIds: {categoryId},
        awaitContent: true,
        automaticUpdatesEnabled: category.automaticAgentWakesEnabledEffective,
      );
    } catch (e) {
      _domainLogger?.error(
        LogDomain.agentWorkflow,
        e,
        message:
            'Failed to auto-assign agent for follow-up '
            '${DomainLogger.sanitizeId(newTask.meta.id)}',
        subDomain: _sub,
      );
      warnings.add('Warning: failed to auto-assign agent');
    }
  }
}
