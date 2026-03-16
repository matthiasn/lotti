import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'project_repository.g.dart';

/// Repository for project CRUD and task-project linking.
///
/// Projects are [JournalEntity.project] entities stored in the journal table.
/// Tasks are linked to projects via [EntryLink.project] in linked_entries.
/// A task can belong to at most one project (enforced here).
class ProjectRepository {
  ProjectRepository({
    required JournalDb journalDb,
    required PersistenceLogic persistenceLogic,
    required UpdateNotifications updateNotifications,
  }) : _journalDb = journalDb,
       _persistenceLogic = persistenceLogic,
       _updateNotifications = updateNotifications;

  final JournalDb _journalDb;
  final PersistenceLogic _persistenceLogic;
  final UpdateNotifications _updateNotifications;

  // ── Fetch ──────────────────────────────────────────────────────────────────

  /// Returns a project by its entity ID, or null.
  Future<ProjectEntry?> getProjectById(String id) async {
    final entity = await _journalDb.journalEntityById(id);
    return entity is ProjectEntry ? entity : null;
  }

  /// Returns all non-deleted projects for a category.
  Future<List<ProjectEntry>> getProjectsForCategory(
    String categoryId,
  ) {
    return _journalDb.getProjectsForCategory(categoryId);
  }

  /// Returns all non-deleted tasks linked to a project.
  Future<List<Task>> getTasksForProject(String projectId) {
    return _journalDb.getTasksForProject(projectId);
  }

  /// Returns the project a task belongs to, or null if unlinked.
  Future<ProjectEntry?> getProjectForTask(String taskId) {
    return _journalDb.getProjectForTask(taskId);
  }

  // ── Create ─────────────────────────────────────────────────────────────────

  /// Creates a new project entity.
  ///
  /// The project is persisted via [PersistenceLogic] which handles vector
  /// clocks, sync outbox enqueuing, and notification emission.
  Future<ProjectEntry?> createProject({
    required ProjectEntry project,
  }) async {
    await _persistenceLogic.createDbEntity(project);
    return project;
  }

  // ── Update ─────────────────────────────────────────────────────────────────

  /// Saves an updated project entity.
  ///
  /// Bumps vector clock and enqueues sync via [PersistenceLogic].
  Future<bool> updateProject(ProjectEntry project) async {
    final updatedMeta = await _persistenceLogic.updateMetadata(project.meta);
    final updated = project.copyWith(meta: updatedMeta);
    final result = await _persistenceLogic.updateDbEntity(updated);
    return result ?? false;
  }

  // ── Linking ────────────────────────────────────────────────────────────────

  /// Links a task to a project.
  ///
  /// Enforces the single-project-per-task constraint: if the task already
  /// belongs to a different project, the old link is soft-deleted first.
  ///
  /// Returns `true` if the link was created, `false` if rejected (e.g.,
  /// cross-category linking).
  Future<bool> linkTaskToProject({
    required String projectId,
    required String taskId,
  }) async {
    // Validate same-category constraint
    final project = await getProjectById(projectId);
    final task = await _journalDb.journalEntityById(taskId);
    if (project == null || task == null) return false;
    if (project.meta.categoryId != task.meta.categoryId) return false;

    // Remove existing project link if the task is already in another project
    final existingLink = await _journalDb.getProjectLinkForTask(taskId);
    if (existingLink != null) {
      if (existingLink.fromId == projectId) {
        return true; // already linked to this project
      }
      // Soft-delete the old link
      await _softDeleteLink(existingLink);
    }

    // Create the new project link
    final now = DateTime.now();
    final link = EntryLink.project(
      id: uuid.v1(),
      fromId: projectId,
      toId: taskId,
      createdAt: now,
      updatedAt: now,
      vectorClock: await _nextVectorClock(),
    );

    final res = await _journalDb.upsertEntryLink(link);
    if (res != 0) {
      _updateNotifications.notify({projectId, taskId});
    }
    return res != 0;
  }

  /// Removes a task from its project.
  ///
  /// Soft-deletes the ProjectLink if one exists. Returns `true` if a link
  /// was removed.
  Future<bool> unlinkTaskFromProject(String taskId) async {
    final existingLink = await _journalDb.getProjectLinkForTask(taskId);
    if (existingLink == null) return false;
    await _softDeleteLink(existingLink);
    return true;
  }

  // ── Notifications ──────────────────────────────────────────────────────────

  /// Stream of all update notifications. Filter for [projectNotification]
  /// to react to project changes.
  Stream<Set<String>> get updateStream => _updateNotifications.updateStream;

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<void> _softDeleteLink(EntryLink link) async {
    final now = DateTime.now();
    final deleted = link.map(
      basic: (l) => l.copyWith(deletedAt: now, updatedAt: now),
      rating: (l) => l.copyWith(deletedAt: now, updatedAt: now),
      project: (l) => l.copyWith(deletedAt: now, updatedAt: now),
    );
    await _journalDb.upsertEntryLink(deleted);
    _updateNotifications.notify({link.fromId, link.toId});
  }

  Future<VectorClock> _nextVectorClock() async {
    return getIt<VectorClockService>().getNextVectorClock();
  }
}

@Riverpod(keepAlive: true)
ProjectRepository projectRepository(Ref ref) {
  return ProjectRepository(
    journalDb: getIt<JournalDb>(),
    persistenceLogic: getIt<PersistenceLogic>(),
    updateNotifications: getIt<UpdateNotifications>(),
  );
}
