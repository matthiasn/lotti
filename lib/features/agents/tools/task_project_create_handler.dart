import 'package:clock/clock.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/tools/change_effect.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/repositories/project_repository.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:uuid/uuid.dart';

/// [raw] as a project title: trimmed, with every run of inner whitespace
/// collapsed to one space, or `null` when nothing is left.
///
/// The user's capitalisation and spelling are kept — the project is named
/// exactly as the user named it.
String? normalizeProjectTitle(Object? raw) {
  if (raw is! String) return null;
  final title = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  return title.isEmpty ? null : title;
}

/// The key two project titles share when they name the same project: the
/// normalized title without case. "Garden  Shed" and "garden shed" share one.
String projectTitleKey(String title) =>
    (normalizeProjectTitle(title) ?? '').toLowerCase();

/// Creates the project a confirmed `create_task_project` names and moves the
/// task into it.
///
/// The project is created in the task's category, with the task's private
/// flag — `ProjectRepository.linkTaskToProject` refuses a link across either —
/// and starts `active`: it is created for a task, so it already has work in
/// it.
///
/// A project with the same title (see [projectTitleKey]) already in the
/// category is used instead of a second one: it can have been created, or
/// synced in, since the proposal was made.
///
/// With an [ChangeEffect] — a confirmed change item — the project's id is
/// derived from the item, so the same item confirmed on two devices creates
/// one project. A dispatch that finds that project already there (written
/// here, synced from the other device) only completes the task's link; one
/// deleted since stays deleted, and nothing is written.
class TaskProjectCreateHandler {
  TaskProjectCreateHandler({
    required this._persistenceLogic,
    required this._journalDb,
    required this._projectRepository,
    this._domainLogger,
  });

  final PersistenceLogic _persistenceLogic;
  final JournalDb _journalDb;
  final ProjectRepository _projectRepository;
  final DomainLogger? _domainLogger;

  static const _uuid = Uuid();
  static const _sub = 'TaskProjectCreateHandler';

  /// The role of the project in its [ChangeEffect]'s derived ids.
  static const projectRole = 'project';

  /// Creates (or finds) the project `args['title']` names in [task]'s
  /// category and moves [task] into it.
  ///
  /// Returns a [ToolExecutionResult] whose `mutatedEntityId` is the project's
  /// id once the task is in it.
  Future<ToolExecutionResult> handle(
    Task task,
    Map<String, dynamic> args, {
    ChangeEffect? effect,
  }) async {
    final title = normalizeProjectTitle(args['title']);
    if (title == null) {
      return const ToolExecutionResult(
        success: false,
        output: 'Error: "title" must be a non-empty string.',
        errorMessage: 'Missing or empty title',
      );
    }

    final categoryId = task.meta.categoryId;
    if (categoryId == null || categoryId.isEmpty) {
      return const ToolExecutionResult(
        success: false,
        output:
            'Error: the task has no category, and a project is created in '
            "the task's category.",
        errorMessage: 'Task has no category',
      );
    }
    final private = task.meta.private ?? false;

    if (effect != null && await effect.created(_journalDb, projectRole)) {
      final earlier = await _createdBefore(effect);
      if (earlier == null || earlier.meta.deletedAt != null) {
        _log('Project of this change was deleted since — nothing applied');
        return ToolExecutionResult(
          success: true,
          output:
              'Nothing applied: project "$title" was created by this change '
              'and deleted since, so it stays deleted.',
        );
      }
      return _moveInto(task, earlier, created: false);
    }

    final existing = await _sameTitled(categoryId, private, title);
    if (existing != null) return _moveInto(task, existing, created: false);

    final now = clock.now();
    final meta = await _persistenceLogic.createMetadata(
      dateFrom: now,
      dateTo: now,
      categoryId: categoryId,
      private: private,
      uuidV5Input: effect?.entityInput(projectRole),
    );
    final project = ProjectEntry(
      meta: meta,
      data: ProjectData(
        title: title,
        status: ProjectStatus.active(
          id: _uuid.v1(),
          createdAt: now,
          utcOffset: now.timeZoneOffset.inMinutes,
        ),
        dateFrom: now,
        dateTo: now,
      ),
    );

    final created = await _projectRepository.createProject(project: project);
    if (created == null) {
      // The insert refuses an id that exists: the other device's project can
      // have arrived between the check above and the write.
      final arrived = await _createdBefore(effect);
      if (arrived != null && arrived.meta.deletedAt == null) {
        return _moveInto(task, arrived, created: false);
      }
      return ToolExecutionResult(
        success: false,
        output: 'Error: failed to create project "$title".',
        errorMessage: 'Project creation failed',
      );
    }

    _log('Created project ${DomainLogger.sanitizeId(created.meta.id)}');
    return _moveInto(task, created, created: true);
  }

  /// The project an earlier application of [effect] created, deleted or not,
  /// or `null` when there is none (or no effect).
  Future<ProjectEntry?> _createdBefore(ChangeEffect? effect) async {
    if (effect == null) return null;
    final entity = await _journalDb.journalEntityById(
      effect.entityId(projectRole),
    );
    return entity is ProjectEntry ? entity : null;
  }

  /// A live project of [categoryId] with [private] whose title shares
  /// [title]'s [projectTitleKey], or `null` when there is none.
  Future<ProjectEntry?> _sameTitled(
    String categoryId,
    bool private,
    String title,
  ) async {
    final key = projectTitleKey(title);
    final projects = await _projectRepository.getProjectsForCategory(
      categoryId,
    );
    return projects
        .where(
          (project) =>
              (project.meta.private ?? false) == private &&
              projectTitleKey(project.data.title) == key,
        )
        .firstOrNull;
  }

  /// Moves [task] into [project] and reports the outcome. A failed move
  /// leaves the project in place: the item goes back to pending, and its
  /// next confirmation finds the project and only retries the move.
  Future<ToolExecutionResult> _moveInto(
    Task task,
    ProjectEntry project, {
    required bool created,
  }) async {
    final projectId = project.meta.id;
    final projectTitle = project.data.title;
    final moved = await _projectRepository.linkTaskToProject(
      projectId: projectId,
      taskId: task.meta.id,
    );
    if (!moved) {
      return ToolExecutionResult(
        success: false,
        output:
            'Error: project "$projectTitle" ($projectId) exists, but the task '
            'could not be moved into it.',
        errorMessage: 'Project link rejected',
      );
    }
    return ToolExecutionResult(
      success: true,
      output: created
          ? 'Created active project "$projectTitle" ($projectId) in the '
                "task's category and moved the task into it."
          : 'Project "$projectTitle" ($projectId) already exists in the '
                "task's category; moved the task into it.",
      mutatedEntityId: projectId,
    );
  }

  void _log(String message) =>
      _domainLogger?.log(LogDomain.agentWorkflow, message, subDomain: _sub);
}
