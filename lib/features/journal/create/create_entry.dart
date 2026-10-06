import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/features/agents/service/event_agent_service.dart';
import 'package:lotti/features/agents/service/task_agent_assignment.dart';
import 'package:lotti/features/agents/service/task_agent_service.dart';
import 'package:lotti/features/agents/state/event_agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/image_analysis_trigger.dart';
import 'package:lotti/logic/image_import.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/repositories/checklist_repository.dart';
import 'package:lotti/logic/repositories/journal_repository.dart';
import 'package:lotti/logic/repositories/project_repository.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/utils/screenshots.dart';

Future<JournalEntity?> createTextEntry({
  String? linkedId,
  String? categoryId,
}) async {
  final entry = await JournalRepository.createTextEntry(
    const EntryText(plainText: ''),
    linkedId: linkedId,
    categoryId: categoryId,
    started: DateTime.now(),
  );

  if (linkedId == null) {
    beamToNamed('/journal/${entry?.meta.id}');
  }
  return entry;
}

Future<JournalEntity?> createChecklist({
  required Task task,
  required WidgetRef ref,
}) async {
  final result = await ref
      .read(checklistRepositoryProvider)
      .createChecklist(
        taskId: task.id,
      );

  return result.checklist;
}

/// Creates a blank task and applies any unambiguous creation context.
///
/// Category, labels, status, and [title] are part of the initial entity write.
/// An explicit [projectId] is validated before that write, its category is
/// authoritative, and the project is linked before this future completes.
/// Invalid projects return `null` before task persistence. A failed explicit
/// link soft-deletes the just-created task before returning `null`, so a
/// project race cannot leave an orphaned blank task. Without these optional
/// values, the existing open, uncategorized, unlabeled, project-free defaults
/// are kept.
///
/// [title] defaults to empty, which is what every caller that opens the new
/// task for editing wants. Callers that already know the title — the link
/// picker, where the search query the user typed *is* the title — pass it so
/// the task is never briefly nameless; a non-empty title is also indexed for
/// full-text search here, which nothing on the create path otherwise does.
///
/// An explicit [projectId] makes that project's category and privacy
/// authoritative for the new task. A [linkedId] with conflicting privacy is
/// rejected before persistence rather than silently changing either context.
/// Otherwise, [inheritContextFrom] names a
/// parent task whose project *and* privacy the new task adopts, without
/// writing a link to it. [linkedId] does both together; callers that own their
/// own linking (the link picker writes one typed edge) would otherwise have to
/// unpick a plain link to get the context across.
///
/// Failures along the way (project lookup, project link, title indexing) are
/// reported to [domainLogger].
Future<Task?> createTask({
  required DomainLogger domainLogger,
  String? linkedId,
  String? categoryId,
  String? projectId,
  List<String>? labelIds,
  String? status,
  DateTime? due,
  String title = '',
  String? inheritContextFrom,
}) async {
  final now = DateTime.now();
  final projectRepository = projectId != null
      ? _createProjectRepository()
      : null;
  var effectiveCategoryId = categoryId;
  bool? inheritedPrivate;
  final nonEmptyLabelIds = labelIds
      ?.where((id) => id.isNotEmpty)
      .toList(growable: false);

  // Project links require tasks and projects to share category and privacy.
  // Resolve the project before creating the task and treat both fields as
  // authoritative, including when the filter context supplies a conflicting
  // category.
  if (projectId != null) {
    ProjectEntry? project;
    try {
      project = await projectRepository!.getProjectById(projectId);
    } catch (error, stackTrace) {
      domainLogger.error(
        LogDomain.persistence,
        error,
        stackTrace: stackTrace,
        subDomain: 'createTask',
        message: 'Failed to resolve category for project $projectId',
      );
      return null;
    }
    if (project == null) {
      domainLogger.log(
        LogDomain.persistence,
        'Could not resolve project $projectId before task creation',
        subDomain: 'createTask',
        level: InsightLevel.warn,
      );
      return null;
    }
    effectiveCategoryId = project.meta.categoryId;
    inheritedPrivate = project.meta.private;
    if (linkedId != null) {
      final linked = await getIt<JournalDb>().journalEntityById(linkedId);
      if (linked != null &&
          (linked.meta.private ?? false) != (inheritedPrivate ?? false)) {
        return null;
      }
    }
  }

  // Look up category defaults for profile inheritance.
  final category = effectiveCategoryId != null
      ? getIt<EntitiesCacheService>().getCategoryById(effectiveCategoryId)
      : null;

  // Without an explicit project, privacy travels with a link-free context too.
  // With a `linkedId`,
  // `createDbEntity` copies it off the linked entity; without one the new task
  // persists as public, so a task created from inside a *private* task's
  // picker would expose it.
  if (projectId == null && inheritContextFrom != null) {
    final parent = await getIt<JournalDb>().journalEntityById(
      inheritContextFrom,
    );
    inheritedPrivate = parent?.meta.private;
  }

  final task = await getIt<PersistenceLogic>().createTaskEntry(
    data: TaskData(
      status: taskStatusFromString(status ?? ''),
      title: title,
      statusHistory: [],
      dateTo: now,
      dateFrom: now,
      estimate: Duration.zero,
      due: due,
      profileId: category?.defaultProfileId,
    ),
    entryText: const EntryText(plainText: ''),
    linkedId: linkedId,
    categoryId: effectiveCategoryId,
    private: inheritedPrivate,
    labelIds: nonEmptyLabelIds == null || nonEmptyLabelIds.isEmpty
        ? null
        : nonEmptyLabelIds,
  );

  if (task != null && projectId != null) {
    final assigned = await _assignProjectToTask(
      domainLogger: domainLogger,
      projectRepository: projectRepository!,
      projectId: projectId,
      taskId: task.meta.id,
    );
    if (!assigned) {
      final cleanedUp = await _softDeleteFailedProjectTask(task);
      if (!cleanedUp) {
        throw StateError(
          'Project assignment failed and the created task could not be '
          'soft-deleted: ${task.meta.id}',
        );
      }
      return null;
    }
  } else if (task != null && (linkedId ?? inheritContextFrom) != null) {
    // Inherit project from the parent task when no explicit project was
    // requested by the creation context.
    //
    // [inheritContextFrom] names that parent *without* writing a link to it.
    // A caller that owns the linking itself — the link picker, which writes
    // one typed edge with the relation the user already chose — must not pass
    // `linkedId` just to get the project across, because that writes a plain
    // link it would then have to unpick. Without either, the new task is
    // linked to its parent but absent from that parent's project lists and
    // rollups.
    await _inheritProjectFromLinkedTask(
      domainLogger: domainLogger,
      linkedId: (linkedId ?? inheritContextFrom)!,
      newTaskId: task.meta.id,
    );
  }

  // Index the initial title. `createDbEntity` does not touch FTS5 — only the
  // update path and the manual rebuild do — so a task created *with* a title
  // and never edited stayed permanently unsearchable. That is load-bearing
  // here: the link picker's duplicate check falls back to full text once a
  // task drops out of the 200-row prefetch, and an unindexed title reads as
  // "does not exist" and offers to create it again.
  if (task != null && title.isNotEmpty) {
    try {
      await getIt<Fts5Db>().insertText(task);
    } catch (error, stackTrace) {
      domainLogger.error(
        LogDomain.persistence,
        error,
        stackTrace: stackTrace,
        subDomain: 'createTask',
        message: 'Failed to index title for task ${task.meta.id}',
      );
    }
  }

  return task;
}

Future<bool> _softDeleteFailedProjectTask(Task task) async {
  final persistenceLogic = getIt<PersistenceLogic>();
  final deletedMetadata = await persistenceLogic.updateMetadata(
    task.meta,
    deletedAt: DateTime.now(),
  );
  final updated = await persistenceLogic.updateDbEntity(
    task.copyWith(meta: deletedMetadata),
  );
  if (updated ?? false) return true;
  // Ordinary by-id reads exclude tombstones; verify the raw persisted row.
  final db = getIt<JournalDb>();
  final committed = await (db.select(
    db.journal,
  )..where((row) => row.id.equals(task.id))).getSingleOrNull();
  return committed?.deleted == true;
}

/// Copies the project assignment from [linkedId] to [newTaskId] via
/// [ProjectRepository.inheritProjectFromTask]. Best-effort: failures are
/// caught and reported to [domainLogger] so they never prevent task creation
/// from succeeding.
Future<void> _inheritProjectFromLinkedTask({
  required DomainLogger domainLogger,
  required String linkedId,
  required String newTaskId,
}) async {
  try {
    final inherited = await _createProjectRepository().inheritProjectFromTask(
      sourceTaskId: linkedId,
      newTaskId: newTaskId,
    );
    if (!inherited) {
      domainLogger.log(
        LogDomain.persistence,
        'No project to inherit for task $newTaskId from $linkedId',
        subDomain: 'createTask',
      );
    }
  } catch (e, stackTrace) {
    domainLogger.error(
      LogDomain.persistence,
      e,
      stackTrace: stackTrace,
      subDomain: 'createTask',
      message: 'Failed to inherit project for task $newTaskId from $linkedId',
    );
  }
}

/// Assigns the explicitly inherited project to a newly created task.
///
/// Returns whether the link succeeded so [createTask] can surface explicit
/// assignment failures. Repository exceptions are logged to [domainLogger]
/// and return `false`.
Future<bool> _assignProjectToTask({
  required DomainLogger domainLogger,
  required ProjectRepository projectRepository,
  required String projectId,
  required String taskId,
}) async {
  try {
    final assigned = await projectRepository.linkTaskToProject(
      projectId: projectId,
      taskId: taskId,
    );
    if (!assigned) {
      domainLogger.log(
        LogDomain.persistence,
        'Could not assign project $projectId to task $taskId',
        subDomain: 'createTask',
        level: InsightLevel.warn,
      );
    }
    return assigned;
  } catch (error, stackTrace) {
    domainLogger.error(
      LogDomain.persistence,
      error,
      stackTrace: stackTrace,
      subDomain: 'createTask',
      message: 'Failed to assign project $projectId to task $taskId',
    );
    return false;
  }
}

ProjectRepository _createProjectRepository() {
  if (getIt.isRegistered<ProjectRepository>()) {
    return getIt<ProjectRepository>();
  }

  return ProjectRepository(
    journalDb: getIt<JournalDb>(),
    entitiesCacheService: getIt<EntitiesCacheService>(),
    persistenceLogic: getIt<PersistenceLogic>(),
    updateNotifications: getIt<UpdateNotifications>(),
    vectorClockService: getIt<VectorClockService>(),
    projectHasActiveAgent: projectHasActiveAgent,
  );
}

/// Auto-creates an agent for [task] if the task's category has a
/// `defaultTemplateId` set. The agent is created in content-awaiting mode
/// so it won't run until the task has meaningful content.
///
/// Call this after [createTask] from contexts that have Riverpod [WidgetRef].
Future<void> autoAssignCategoryAgent(WidgetRef ref, Task task) =>
    autoAssignCategoryAgentWith(
      ref.read(taskAgentServiceProvider),
      task,
      domainLogger: ref.read(domainLoggerProvider),
    );

/// Core of [autoAssignCategoryAgent].
///
/// Accepts a [TaskAgentService] and [domainLogger] directly so callers can
/// capture both before an async gap (avoiding post-await [WidgetRef] usage)
/// and tests can call it without needing a [WidgetRef]. A failed assignment
/// is reported to [domainLogger].
Future<void> autoAssignCategoryAgentWith(
  TaskAgentService service,
  Task task, {
  required DomainLogger domainLogger,
}) async {
  final categoryId = task.meta.categoryId;
  final category = categoryId == null
      ? null
      : getIt<EntitiesCacheService>().getCategoryById(categoryId);
  final result = await assignCategoryDefaultTaskAgent(
    service: service,
    task: task,
    category: category,
  );
  if (result.status == TaskAgentAssignmentStatus.failed) {
    domainLogger.error(
      LogDomain.agentWorkflow,
      result.error ?? 'task agent assignment failed',
      stackTrace: result.stackTrace,
      subDomain: 'autoAssignCategoryAgent',
      message: 'Failed to auto-assign agent for task ${task.meta.id}',
    );
  }
}

/// Auto-creates an event agent for [event] if the event's category has a
/// `defaultEventTemplateId` set. The agent is created in content-awaiting mode
/// so it won't narrate until the event has real content (a photo/note).
///
/// Call this after [createEvent] from contexts that have Riverpod [WidgetRef].
Future<void> autoAssignCategoryEventAgent(WidgetRef ref, JournalEvent event) =>
    autoAssignCategoryEventAgentWith(
      ref.read(eventAgentServiceProvider),
      event,
      domainLogger: ref.read(domainLoggerProvider),
    );

/// Core of [autoAssignCategoryEventAgent].
///
/// Accepts an [EventAgentService] and [domainLogger] directly so callers can
/// capture both before an async gap (avoiding post-await [WidgetRef] usage)
/// and tests can call it without needing a [WidgetRef]. A failure is reported
/// to [domainLogger].
Future<void> autoAssignCategoryEventAgentWith(
  EventAgentService service,
  JournalEvent event, {
  required DomainLogger domainLogger,
}) async {
  try {
    final categoryId = event.meta.categoryId;
    if (categoryId == null) return;

    final category = getIt<EntitiesCacheService>().getCategoryById(categoryId);
    if (category == null) return;

    final templateId = category.defaultEventTemplateId;
    if (templateId == null) return;

    await service.createEventAgent(
      eventId: event.meta.id,
      templateId: templateId,
      profileId: category.defaultProfileId,
      allowedCategoryIds: {categoryId},
    );
  } catch (e, stackTrace) {
    domainLogger.error(
      LogDomain.agentWorkflow,
      e,
      stackTrace: stackTrace,
      subDomain: 'autoAssignCategoryEventAgent',
      message: 'Failed to auto-assign event agent for event ${event.meta.id}',
    );
  }
}

Future<JournalEvent?> createEvent({String? linkedId, String? categoryId}) =>
    getIt<PersistenceLogic>().createEventEntry(
      data: const EventData(
        status: EventStatus.tentative,
        title: '',
        stars: 0,
      ),
      entryText: const EntryText(plainText: ''),
      linkedId: linkedId,
      categoryId: categoryId,
    );

/// Captures and persists a screenshot, optionally linking it to another entry.
/// [capture] supplies the platform capture boundary.
Future<JournalEntity?> createScreenshot({
  String? linkedId,
  String? categoryId,
  ImageAnalysisTrigger? analysisTrigger,
  Future<ImageData> Function() capture = takeScreenshot,
}) async {
  final persistenceLogic = getIt<PersistenceLogic>();
  final imageData = await capture();
  final entry = await JournalRepository.createImageEntry(
    imageData,
    linkedId: linkedId,
    categoryId: categoryId,
    onCreated: createAnalysisCallback(analysisTrigger, linkedId),
  );

  if (entry != null) {
    persistenceLogic.addGeolocation(entry.meta.id);
  }

  return entry;
}
