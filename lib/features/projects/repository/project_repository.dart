import 'dart:async';

import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/projects/model/projects_overview_models.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/entities_cache_service.dart';
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
    required EntitiesCacheService entitiesCacheService,
    required PersistenceLogic persistenceLogic,
    required UpdateNotifications updateNotifications,
    required VectorClockService vectorClockService,
  }) : _journalDb = journalDb,
       _entitiesCacheService = entitiesCacheService,
       _persistenceLogic = persistenceLogic,
       _updateNotifications = updateNotifications,
       _vectorClockService = vectorClockService;

  final JournalDb _journalDb;
  final EntitiesCacheService _entitiesCacheService;
  final PersistenceLogic _persistenceLogic;
  final UpdateNotifications _updateNotifications;
  final VectorClockService _vectorClockService;

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

  /// Resolves project IDs affected by a local update batch.
  ///
  /// This includes:
  /// - project IDs that were updated directly
  /// - project IDs linked to any updated task IDs
  ///
  /// The task lookup relies on the denormalized `project_id` column, so child
  /// entry updates that bubble up to their parent task IDs also mark the owning
  /// project as stale.
  Future<Set<String>> resolveAffectedProjectIds(Set<String> affectedIds) async {
    final normalized = affectedIds.map((id) {
      return id.startsWith(projectEntityUpdatePrefix)
          ? id.substring(projectEntityUpdatePrefix.length)
          : id;
    }).toSet();

    final (directProjectIds, taskProjectIds) = await (
      _journalDb.getExistingProjectIds(normalized),
      _journalDb.getProjectIdsForTaskIds(normalized),
    ).wait;
    return {...directProjectIds, ...taskProjectIds};
  }

  /// Returns the grouped overview snapshot used by the top-level projects tab.
  Future<ProjectsOverviewSnapshot> getProjectsOverview({
    required ProjectsQuery query,
  }) async {
    final projects = await _journalDb.getVisibleProjects();
    final scopedProjects = projects
        .where((project) => query.matchesCategory(project.meta.categoryId))
        .toList();
    final taskRollups = await _journalDb.getProjectTaskRollups(
      scopedProjects.map((project) => project.meta.id).toSet(),
    );
    final categoriesById = _entitiesCacheService.categoriesById;
    final sortedCategoryIds = _entitiesCacheService.sortedCategories
        .map((category) => category.id)
        .toList(growable: false);
    final groupedProjects = <String?, List<ProjectListItemData>>{};

    for (final project in scopedProjects) {
      final categoryId = project.meta.categoryId;
      groupedProjects
          .putIfAbsent(categoryId, () => <ProjectListItemData>[])
          .add(
            ProjectListItemData(
              project: project,
              category: categoriesById[categoryId],
              taskRollup: switch (taskRollups[project.meta.id]) {
                final ProjectTaskRollupCounts rollup => ProjectTaskRollupData(
                  totalTaskCount: rollup.totalTaskCount,
                  completedTaskCount: rollup.completedTaskCount,
                  blockedTaskCount: rollup.blockedTaskCount,
                ),
                null => const ProjectTaskRollupData(),
              },
            ),
          );
    }

    final extraCategoryIds =
        groupedProjects.keys
            .whereType<String>()
            .where((categoryId) => !sortedCategoryIds.contains(categoryId))
            .toList()
          ..sort((left, right) {
            final leftName =
                categoriesById[left]?.name.toLowerCase() ?? left.toLowerCase();
            final rightName =
                categoriesById[right]?.name.toLowerCase() ??
                right.toLowerCase();
            return leftName.compareTo(rightName);
          });

    final orderedCategoryIds = <String?>[
      ...sortedCategoryIds.where(groupedProjects.containsKey),
      ...extraCategoryIds,
      if (groupedProjects.containsKey(null)) null,
    ];

    final groups = orderedCategoryIds
        .map((categoryId) {
          final projectsForCategory = groupedProjects[categoryId];
          if (projectsForCategory == null || projectsForCategory.isEmpty) {
            return null;
          }

          return ProjectCategoryGroup(
            categoryId: categoryId,
            category: categoriesById[categoryId],
            projects: List<ProjectListItemData>.unmodifiable(
              projectsForCategory,
            ),
          );
        })
        .whereType<ProjectCategoryGroup>()
        .toList(growable: false);

    return ProjectsOverviewSnapshot(groups: groups);
  }

  /// Watches the grouped overview snapshot for project-relevant updates.
  ///
  /// Refreshes on the broad project/task/category/private notification tokens
  /// and also on concrete project/category IDs already present in the current
  /// snapshot so status edits cannot leave the list stale.
  Stream<ProjectsOverviewSnapshot> watchProjectsOverview({
    required ProjectsQuery query,
  }) {
    late StreamController<ProjectsOverviewSnapshot> controller;
    StreamSubscription<Set<String>>? subscription;
    var fetching = false;
    var pendingRefetch = false;
    ProjectsOverviewSnapshot? currentSnapshot;

    Future<void> doFetch() async {
      if (fetching) {
        pendingRefetch = true;
        return;
      }

      fetching = true;
      try {
        final snapshot = await getProjectsOverview(query: query);
        currentSnapshot = snapshot;
        if (!controller.isClosed) {
          controller.add(snapshot);
        }
      } catch (error, stackTrace) {
        if (!controller.isClosed) {
          controller.addError(error, stackTrace);
        }
      } finally {
        fetching = false;
        if (pendingRefetch && !controller.isClosed) {
          pendingRefetch = false;
          await doFetch();
        }
      }
    }

    controller = StreamController<ProjectsOverviewSnapshot>.broadcast(
      onListen: () {
        subscription = _updateNotifications.updateStream.listen((affectedIds) {
          final snapshot = currentSnapshot;
          if (snapshot == null ||
              _projectsOverviewNeedsRefresh(affectedIds, snapshot)) {
            doFetch();
          }
        });
        doFetch();
      },
      onCancel: () async {
        await subscription?.cancel();
        subscription = null;
      },
    );

    return controller.stream;
  }

  // ── Create ─────────────────────────────────────────────────────────────────

  /// Creates a new project entity.
  ///
  /// The project is persisted via [PersistenceLogic] which handles vector
  /// clocks, sync outbox enqueuing, and notification emission.
  Future<ProjectEntry?> createProject({
    required ProjectEntry project,
  }) async {
    final success = await _persistenceLogic.createDbEntity(project);
    return (success ?? false) ? project : null;
  }

  // ── Update ─────────────────────────────────────────────────────────────────

  /// Saves an updated project entity.
  ///
  /// Bumps vector clock and enqueues sync via [PersistenceLogic].
  Future<bool> updateProject(ProjectEntry project) async {
    final updatedMeta = await _persistenceLogic.updateMetadata(project.meta);
    final updated = project.copyWith(meta: updatedMeta);
    final result = await _persistenceLogic.updateDbEntity(updated);
    if (result ?? false) {
      _updateNotifications.notify({
        projectEntityUpdateNotification(updated.id),
      });
    }
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
    // Validate same-category constraint (parallel fetch)
    final results = await Future.wait([
      getProjectById(projectId),
      _journalDb.journalEntityById(taskId),
    ]);
    final project = results[0] as ProjectEntry?;
    final task = results[1];
    if (project == null || task is! Task) return false;
    if (project.meta.categoryId != task.meta.categoryId) return false;

    // Remove existing project link if the task is already in another project
    final existingLink = await _journalDb.getProjectLinkForTask(taskId);
    if (existingLink != null) {
      if (existingLink.fromId == projectId) {
        return true; // already linked to this project
      }
      // Atomically soft-delete old link + create new link
      return _relinkTask(
        oldLink: existingLink,
        projectId: projectId,
        taskId: taskId,
      );
    }

    // No existing link — just create the new project link.
    //
    // Wrapped in a VC scope: if [upsertEntryLink] returns 0 (no-op / unchanged
    // row) the scope releases, the burn handler broadcasts a proactive
    // `SyncBackfillResponse(unresolvable=true)`, and peers close the gap on
    // the live event stream. Without this wrap, the reserved counter would
    // burn silently and receivers would only converge via reactive backfill.
    return _vectorClockService.withVcScope<bool>(
      () async {
        final now = DateTime.now();
        final link = EntryLink.project(
          id: uuid.v1(),
          fromId: projectId,
          toId: taskId,
          createdAt: now,
          updatedAt: now,
          vectorClock: await _vectorClockService.getNextVectorClock(),
        );

        final res = await _journalDb.upsertEntryLink(link);
        if (res == 0) return false;
        _updateNotifications.notify({
          projectId,
          taskId,
          projectNotification,
          projectEntityUpdateNotification(projectId),
        });
        try {
          await _enqueueLinkSync(link, SyncEntryStatus.initial);
        } catch (error, stackTrace) {
          // Commit-on-write invariant: the link row is already persisted, so
          // the VC counter is claimed on disk — an outbox failure must not
          // release the reservation.
          getIt<DomainLogger>().error(
            LogDomains.sync,
            'outbox enqueue failed after linkTaskToProject; '
            'VC already committed',
            error: error,
            stackTrace: stackTrace,
            subDomain: 'linkTaskToProject.enqueue',
          );
        }
        return true;
      },
      commitWhen: (ok) => ok,
    );
  }

  /// Removes a task from its project.
  ///
  /// Soft-deletes the ProjectLink if one exists. Returns `true` if a link
  /// was removed.
  Future<bool> unlinkTaskFromProject(String taskId) async {
    final existingLink = await _journalDb.getProjectLinkForTask(taskId);
    if (existingLink == null) return false;
    return _softDeleteLink(existingLink);
  }

  /// Copies the project assignment from [sourceTaskId] to [newTaskId].
  ///
  /// Returns `true` if a project was inherited successfully, `false` if the
  /// source task has no project or the link could not be created.
  Future<bool> inheritProjectFromTask({
    required String sourceTaskId,
    required String newTaskId,
  }) async {
    final project = await getProjectForTask(sourceTaskId);
    if (project == null) return false;
    return linkTaskToProject(projectId: project.meta.id, taskId: newTaskId);
  }

  // ── Notifications ──────────────────────────────────────────────────────────

  /// Stream of all update notifications. Filter for [projectNotification]
  /// to react to project changes.
  Stream<Set<String>> get updateStream => _updateNotifications.updateStream;

  bool _projectsOverviewNeedsRefresh(
    Set<String> affectedIds,
    ProjectsOverviewSnapshot currentSnapshot,
  ) {
    if (affectedIds.any(_overviewNotificationTokens.contains)) {
      return true;
    }

    final normalizedAffectedIds = affectedIds.map((id) {
      return id.startsWith(projectEntityUpdatePrefix)
          ? id.substring(projectEntityUpdatePrefix.length)
          : id;
    }).toSet();

    final projectIds = currentSnapshot.groups
        .expand((group) => group.projects)
        .map((project) => project.project.meta.id)
        .toSet();
    if (normalizedAffectedIds.any(projectIds.contains)) {
      return true;
    }

    final categoryIds = currentSnapshot.groups
        .map((group) => group.categoryId)
        .whereType<String>()
        .toSet();

    return normalizedAffectedIds.any(categoryIds.contains);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Atomically soft-deletes an old project link and creates a new one
  /// within a single DB transaction. Notifications and sync enqueuing are
  /// deferred until after the transaction commits.
  Future<bool> _relinkTask({
    required EntryLink oldLink,
    required String projectId,
    required String taskId,
  }) async {
    // Wrap BOTH reservations (delete-link VC + new-link VC) in a single
    // scope so a rolled-back transaction releases both. Nested reservations
    // from [_prepareDeletedLink] attach automatically via the zone-local
    // scope.
    return _vectorClockService.withVcScope<bool>(
      () async {
        final now = DateTime.now();
        final deletedLink = await _prepareDeletedLink(oldLink, now);
        final newLink = EntryLink.project(
          id: uuid.v1(),
          fromId: projectId,
          toId: taskId,
          createdAt: now,
          updatedAt: now,
          vectorClock: await _vectorClockService.getNextVectorClock(),
        );

        // Both writes in one transaction — if either fails, both roll back.
        final success = await _journalDb.transaction(() async {
          final deleteRes = await _journalDb.upsertEntryLink(deletedLink);
          if (deleteRes == 0) return false;
          final insertRes = await _journalDb.upsertEntryLink(newLink);
          return insertRes != 0;
        });

        if (!success) return false;

        _updateNotifications.notify({
          oldLink.fromId,
          oldLink.toId,
          projectId,
          taskId,
          projectNotification,
          projectEntityUpdateNotification(oldLink.fromId),
          projectEntityUpdateNotification(projectId),
        });
        try {
          await _enqueueLinkSync(deletedLink, SyncEntryStatus.update);
          await _enqueueLinkSync(newLink, SyncEntryStatus.initial);
        } catch (error, stackTrace) {
          getIt<DomainLogger>().error(
            LogDomains.sync,
            'outbox enqueue failed after _relinkTask; VCs already committed',
            error: error,
            stackTrace: stackTrace,
            subDomain: '_relinkTask.enqueue',
          );
        }
        return true;
      },
      commitWhen: (ok) => ok,
    );
  }

  Future<bool> _softDeleteLink(EntryLink link) async {
    return _vectorClockService.withVcScope<bool>(
      () async {
        final now = DateTime.now();
        final deleted = await _prepareDeletedLink(link, now);
        final res = await _journalDb.upsertEntryLink(deleted);
        if (res == 0) return false;
        _updateNotifications.notify({
          link.fromId,
          link.toId,
          projectNotification,
          projectEntityUpdateNotification(link.fromId),
        });
        try {
          await _enqueueLinkSync(deleted, SyncEntryStatus.update);
        } catch (error, stackTrace) {
          getIt<DomainLogger>().error(
            LogDomains.sync,
            'outbox enqueue failed after _softDeleteLink; VC already committed',
            error: error,
            stackTrace: stackTrace,
            subDomain: '_softDeleteLink.enqueue',
          );
        }
        return true;
      },
      commitWhen: (ok) => ok,
    );
  }

  /// Reserves a VC for the soft-deleted link. Callers invoke this inside a
  /// [VectorClockService.withVcScope] so the reservation is bound to the
  /// enclosing write outcome.
  Future<EntryLink> _prepareDeletedLink(EntryLink link, DateTime now) async {
    return link.copyWith(
      deletedAt: now,
      updatedAt: now,
      hidden: true,
      vectorClock: await _vectorClockService.getNextVectorClock(),
    );
  }

  Future<void> _enqueueLinkSync(
    EntryLink link,
    SyncEntryStatus status,
  ) async {
    await getIt<OutboxService>().enqueueMessage(
      SyncMessage.entryLink(
        entryLink: link,
        status: status,
      ),
    );
  }
}

const Set<String> _overviewNotificationTokens = {
  projectNotification,
  taskNotification,
  categoriesNotification,
  privateToggleNotification,
};

@Riverpod(keepAlive: true)
ProjectRepository projectRepository(Ref ref) {
  return ProjectRepository(
    journalDb: getIt<JournalDb>(),
    entitiesCacheService: getIt<EntitiesCacheService>(),
    persistenceLogic: getIt<PersistenceLogic>(),
    updateNotifications: getIt<UpdateNotifications>(),
    vectorClockService: getIt<VectorClockService>(),
  );
}
