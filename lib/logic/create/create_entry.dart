import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/service/event_agent_service.dart';
import 'package:lotti/features/agents/service/task_agent_service.dart';
import 'package:lotti/features/agents/state/event_agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/ai/helpers/automatic_image_analysis_trigger.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/create/task_agent_assignment.dart';
import 'package:lotti/logic/image_import.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/screenshots.dart';

Future<JournalEntity?> createTextEntry({
  String? linkedId,
  String? categoryId,
}) async {
  final entry = await JournalRepository.createTextEntry(
    const EntryText(plainText: ''),
    id: uuid.v1(),
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
/// Category, labels, and status are part of the initial entity write. An
/// explicit [projectId] is linked before this future completes; if no
/// [categoryId] is supplied, the project's category is used to satisfy the
/// same-category project invariant. Without these optional values, the
/// existing open, uncategorized, unlabeled, project-free defaults are kept.
Future<Task?> createTask({
  String? linkedId,
  String? categoryId,
  String? projectId,
  List<String>? labelIds,
  String? status,
  DateTime? due,
}) async {
  final now = DateTime.now();
  final projectRepository = projectId != null
      ? _createProjectRepository()
      : null;
  var effectiveCategoryId = categoryId;
  final nonEmptyLabelIds = labelIds
      ?.where((id) => id.isNotEmpty)
      .toList(growable: false);

  // Project links require tasks and projects to share a category. A project
  // filter on its own therefore supplies the project's category implicitly.
  if (projectId != null && effectiveCategoryId == null) {
    try {
      effectiveCategoryId = (await projectRepository!.getProjectById(
        projectId,
      ))?.meta.categoryId;
    } catch (error) {
      developer.log(
        'Failed to resolve category for project $projectId: $error',
        name: 'createTask',
      );
    }
  }

  // Look up category defaults for profile inheritance.
  final category = effectiveCategoryId != null
      ? getIt<EntitiesCacheService>().getCategoryById(effectiveCategoryId)
      : null;

  final task = await getIt<PersistenceLogic>().createTaskEntry(
    data: TaskData(
      status: taskStatusFromString(status ?? ''),
      title: '',
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
    labelIds: nonEmptyLabelIds == null || nonEmptyLabelIds.isEmpty
        ? null
        : nonEmptyLabelIds,
  );

  if (task != null && projectId != null) {
    await _assignProjectToTask(
      projectRepository: projectRepository!,
      projectId: projectId,
      taskId: task.meta.id,
    );
  } else if (task != null && linkedId != null) {
    // Inherit project from the linked parent task when no explicit project was
    // requested by the creation context.
    await _inheritProjectFromLinkedTask(
      linkedId: linkedId,
      newTaskId: task.meta.id,
    );
  }

  return task;
}

/// Copies the project assignment from [linkedId] to [newTaskId] via
/// [ProjectRepository.inheritProjectFromTask]. Best-effort: failures are
/// caught so they never prevent task creation from succeeding.
Future<void> _inheritProjectFromLinkedTask({
  required String linkedId,
  required String newTaskId,
}) async {
  try {
    final inherited = await _createProjectRepository().inheritProjectFromTask(
      sourceTaskId: linkedId,
      newTaskId: newTaskId,
    );
    if (!inherited) {
      developer.log(
        'No project to inherit for task $newTaskId from $linkedId',
        name: 'createTask',
      );
    }
  } catch (e) {
    developer.log(
      'Failed to inherit project for task $newTaskId from $linkedId: $e',
      name: 'createTask',
    );
  }
}

/// Assigns the explicitly inherited project to a newly created task.
///
/// Best-effort like linked-parent project inheritance: project persistence
/// failures are logged without discarding the task itself.
Future<void> _assignProjectToTask({
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
      developer.log(
        'Could not assign project $projectId to task $taskId',
        name: 'createTask',
      );
    }
  } catch (error) {
    developer.log(
      'Failed to assign project $projectId to task $taskId: $error',
      name: 'createTask',
    );
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
  );
}

/// Auto-creates an agent for [task] if the task's category has a
/// `defaultTemplateId` set. The agent is created in content-awaiting mode
/// so it won't run until the task has meaningful content.
///
/// Call this after [createTask] from contexts that have Riverpod [WidgetRef].
Future<void> autoAssignCategoryAgent(WidgetRef ref, Task task) =>
    autoAssignCategoryAgentWith(ref.read(taskAgentServiceProvider), task);

/// Core of [autoAssignCategoryAgent].
///
/// Accepts a [TaskAgentService] directly so callers can capture the service
/// before an async gap (avoiding post-await [WidgetRef] usage) and tests
/// can call it without needing a [WidgetRef].
Future<void> autoAssignCategoryAgentWith(
  TaskAgentService service,
  Task task,
) async {
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
    developer.log(
      'Failed to auto-assign agent for task ${task.meta.id}: '
      '${result.error}',
      name: 'autoAssignCategoryAgent',
      error: result.error,
      stackTrace: result.stackTrace,
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
    );

/// Core of [autoAssignCategoryEventAgent].
///
/// Accepts an [EventAgentService] directly so callers can capture the service
/// before an async gap (avoiding post-await [WidgetRef] usage) and tests can
/// call it without needing a [WidgetRef].
Future<void> autoAssignCategoryEventAgentWith(
  EventAgentService service,
  JournalEvent event,
) async {
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
    developer.log(
      'Failed to auto-assign event agent for event ${event.meta.id}: $e',
      name: 'autoAssignCategoryEventAgent',
      error: e,
      stackTrace: stackTrace,
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

Future<JournalEntity?> createScreenshot({
  String? linkedId,
  String? categoryId,
  AutomaticImageAnalysisTrigger? analysisTrigger,
}) async {
  final persistenceLogic = getIt<PersistenceLogic>();
  final imageData = await takeScreenshot();
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
