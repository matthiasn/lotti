import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/service/project_agent_mutation_coordinator.dart';
import 'package:lotti/features/projects/model/projects_overview_models.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/utils/file_utils.dart';

/// Repository for project CRUD and task-project linking.
///
/// Projects are [JournalEntity.project] entities stored in the journal table.
/// Tasks are linked to projects via [EntryLink.project] in linked_entries.
/// A task can belong to at most one project (enforced here).
class ProjectRepository {
  ProjectRepository({
    required this._journalDb,
    required this._entitiesCacheService,
    required this._persistenceLogic,
    required this._updateNotifications,
    required this._vectorClockService,
    this.projectHasActiveAgent,
    ProjectAgentMutationCoordinator? mutationCoordinator,
    this.projectsOverviewRefetchDebounce = const Duration(milliseconds: 300),
  }) : _mutationCoordinator =
           mutationCoordinator ?? ProjectAgentMutationCoordinator();

  final ProjectAgentMutationCoordinator _mutationCoordinator;
  final JournalDb _journalDb;
  final EntitiesCacheService _entitiesCacheService;
  final PersistenceLogic _persistenceLogic;
  final UpdateNotifications _updateNotifications;
  final VectorClockService _vectorClockService;
  final Future<bool> Function(String projectId)? projectHasActiveAgent;

  /// Debounce window applied to notification-driven `watchProjectsOverview`
  /// refetches. Each refetch reruns the project rollup aggregate, so a burst
  /// of project/task notifications (e.g. during sync) would otherwise rebuild
  /// the whole overview once per batch. Injectable so tests can collapse it to
  /// `Duration.zero`.
  final Duration projectsOverviewRefetchDebounce;

  SyncSequenceLogService? get _sequenceLogService =>
      getIt.isRegistered<SyncSequenceLogService>()
      ? getIt<SyncSequenceLogService>()
      : null;

  Future<void> _recordLinkSequence(
    EntryLink link, {
    required String subDomain,
  }) async {
    final service = _sequenceLogService;
    final vectorClock = link.vectorClock;
    if (service == null || vectorClock == null) return;
    try {
      await service.recordSentEntryLink(
        linkId: link.id,
        vectorClock: vectorClock,
      );
    } catch (error, stackTrace) {
      getIt<DomainLogger>().error(
        LogDomain.sync,
        error,
        message:
            'sequence record failed after project link write; VC already committed',
        stackTrace: stackTrace,
        subDomain: subDomain,
      );
    }
  }

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
  ///
  /// Honors the private gate: a project hidden by it resolves to null. That is
  /// right for display and wrong for integrity work — see
  /// [getLinkedProjectForTask].
  Future<ProjectEntry?> getProjectForTask(String taskId) {
    return _journalDb.getProjectForTask(taskId);
  }

  /// Returns the project a task is linked to **regardless of the private
  /// gate**, or null if unlinked.
  ///
  /// [getProjectForTask] reads the denormalized `project_id` through a
  /// privacy-filtered bulk fetch, so a private project resolves to null while
  /// private entries are hidden. A caller deciding whether a link is still
  /// valid must not read that as "no link": it would skip the very row it
  /// exists to remove, and the stale link would reappear the moment private
  /// entries were shown again. This resolves the live `ProjectLink` and its
  /// project entity directly, neither of which is privacy-filtered.
  Future<ProjectEntry?> getLinkedProjectForTask(String taskId) async {
    final link = await _journalDb.getProjectLinkForTask(taskId);
    if (link == null) return null;
    return getProjectById(link.fromId);
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
    Timer? refetchDebounce;
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
            // Debounce so a burst of relevant notifications collapses into a
            // single rollup refetch; the initial fetch below stays immediate.
            refetchDebounce?.cancel();
            refetchDebounce = Timer(projectsOverviewRefetchDebounce, doFetch);
          }
        });
        doFetch();
      },
      onCancel: () async {
        refetchDebounce?.cancel();
        refetchDebounce = null;
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
  /// Bumps vector clock and enqueues sync via [PersistenceLogic]. A project
  /// with linked tasks or an active project agent cannot change category
  /// because both membership and agent permissions are category-scoped;
  /// callers must unlink the tasks and retire the agent first.
  ///
  /// [PersistenceLogic.updateDbEntity] can report failure after the journal
  /// row committed (for example when a later search-index update fails), so a
  /// negative result is verified against the stored project before this method
  /// reports failure.
  Future<bool> updateProject(
    ProjectEntry project,
  ) => _mutationCoordinator.run(project.id, () async {
    ProjectEntry? updated;
    final committed = await _journalDb.transaction<bool>(() async {
      final persistedRow = await _journalDb.entityById(project.id);
      final persisted = persistedRow == null
          ? null
          : fromDbEntity(persistedRow);
      if (persisted is! ProjectEntry) return false;
      if (persisted.meta.categoryId != project.meta.categoryId) {
        if ((await _journalDb.getTaskIdsForProjects({project.id})).isNotEmpty) {
          return false;
        }
        final hasActiveAgent = projectHasActiveAgent;
        if (hasActiveAgent != null && await hasActiveAgent(project.id)) {
          return false;
        }
      }

      final updatedMeta = await _persistenceLogic.updateMetadata(project.meta);
      updated = project.copyWith(meta: updatedMeta);
      final result = await _persistenceLogic.updateDbEntity(updated!);
      if (result ?? false) return true;

      final committedRow = await _journalDb.entityById(project.id);
      final committedProject = committedRow == null
          ? null
          : fromDbEntity(committedRow);
      return committedProject == updated;
    });
    if (committed) {
      _updateNotifications.notify({
        projectEntityUpdateNotification(updated!.id),
      });
    }
    return committed;
  });

  /// Soft-deletes [project] and emits the same scoped notification as an
  /// ordinary project update so list/detail providers reconcile immediately.
  Future<bool> deleteProject(
    ProjectEntry project, {
    required DateTime deletedAt,
  }) async {
    final updatedMeta = await _persistenceLogic.updateMetadata(
      project.meta,
      deletedAt: deletedAt,
    );
    final deleted = project.copyWith(meta: updatedMeta);
    final result = await _persistenceLogic.updateDbEntity(deleted);
    final committed =
        (result ?? false) || await getProjectById(project.id) == null;
    if (committed) {
      _updateNotifications.notify({
        projectEntityUpdateNotification(deleted.id),
      });
    }
    return committed;
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
    // This read chooses the mutation shape and reserves the right number of
    // vector clocks. Every branch re-reads both entities and this link inside
    // the write transaction before it commits, so a sync update between this
    // snapshot and the mutation can only reject the operation, never create a
    // category/privacy-invalid link.
    final existingLink = await _journalDb.getProjectLinkForTask(taskId);
    if (existingLink != null) {
      if (existingLink.fromId == projectId) {
        return _existingProjectLinkIsStillValid(
          existingLink: existingLink,
          projectId: projectId,
          taskId: taskId,
        );
      }
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

        final committed = await _journalDb.transaction(() async {
          if (!await _projectLinkInputsAreValid(
            projectId: projectId,
            taskId: taskId,
          )) {
            return false;
          }
          if (await _journalDb.getProjectLinkForTask(taskId) != null) {
            return false;
          }
          return await _journalDb.upsertEntryLink(link) != 0;
        });
        if (!committed) return false;
        await _recordLinkSequence(
          link,
          subDomain: 'linkTaskToProject.recordSent',
        );
        // Wrap the per-project update token with [propagatedNotification]
        // so the wake orchestrator can tell "a task was linked under this
        // project" apart from "the project itself was edited" — only
        // direct project edits should burn LLM tokens immediately. Bare
        // tokens are kept alongside so UI providers reacting to the
        // legacy form continue to refresh.
        _updateNotifications.notify({
          projectId,
          taskId,
          projectNotification,
          projectEntityUpdateNotification(projectId),
          propagatedNotification(projectEntityUpdateNotification(projectId)),
        });
        try {
          await _enqueueLinkSync(link, SyncEntryStatus.initial);
        } catch (error, stackTrace) {
          // Commit-on-write invariant: the link row is already persisted, so
          // the VC counter is claimed on disk — an outbox failure must not
          // release the reservation.
          getIt<DomainLogger>().error(
            LogDomain.sync,
            error,
            message:
                'outbox enqueue failed after linkTaskToProject; '
                'VC already committed',
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
  /// was removed. Privacy cleanup rechecks both entries and the membership
  /// inside the deletion transaction so concurrent sync edits are preserved.
  Future<bool> unlinkTaskFromProject(
    String taskId, {
    bool onlyIfPrivacyMismatched = false,
  }) async {
    final existingLink = await _journalDb.getProjectLinkForTask(taskId);
    if (existingLink == null) return false;
    return _softDeleteLink(
      existingLink,
      onlyIfPrivacyMismatched: onlyIfPrivacyMismatched,
    );
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

  // ── Link mutation helpers ──────────────────────────────────────────────────
  // Private helpers behind the public link/unlink methods. (Previously the
  // `_ProjectLinkHelpers` part-file extension.)

  /// Reads link invariants directly from the transaction's journal snapshot.
  ///
  /// The public `journalEntityById` read is intentionally microtask-coalesced;
  /// using `entityById` here prevents this integrity check from joining a read
  /// wave created outside the active write transaction.
  Future<bool> _projectLinkInputsAreValid({
    required String projectId,
    required String taskId,
  }) async {
    final projectRow = await _journalDb.entityById(projectId);
    final taskRow = await _journalDb.entityById(taskId);
    final project = projectRow == null ? null : fromDbEntity(projectRow);
    final task = taskRow == null ? null : fromDbEntity(taskRow);
    if (project is! ProjectEntry || task is! Task) return false;
    if (project.meta.categoryId != task.meta.categoryId) return false;
    return (project.meta.private ?? false) == (task.meta.private ?? false);
  }

  Future<bool> _existingProjectLinkIsStillValid({
    required EntryLink existingLink,
    required String projectId,
    required String taskId,
  }) {
    return _journalDb.transaction(() async {
      if (!await _projectLinkInputsAreValid(
        projectId: projectId,
        taskId: taskId,
      )) {
        return false;
      }
      final currentLink = await _journalDb.getProjectLinkForTask(taskId);
      return currentLink == existingLink;
    });
  }

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

        // The final invariant reads and both writes share one transaction. If
        // sync changed either entity or the old link after the shape-selection
        // snapshot, reject instead of committing stale validation.
        var success = false;
        try {
          success = await _journalDb.transaction(() async {
            if (!await _projectLinkInputsAreValid(
              projectId: projectId,
              taskId: taskId,
            )) {
              return false;
            }
            final currentLink = await _journalDb.getProjectLinkForTask(taskId);
            if (currentLink != oldLink) return false;
            final deleteRes = await _journalDb.upsertEntryLink(deletedLink);
            if (deleteRes == 0) return false;
            final insertRes = await _journalDb.upsertEntryLink(newLink);
            if (insertRes == 0) throw const _RelinkInsertFailed();
            return true;
          });
        } on _RelinkInsertFailed {
          // Throwing from the Drift transaction is what rolls the already-
          // written tombstone back. Translate the private sentinel only after
          // the transaction has restored the old link.
          success = false;
        }

        if (!success) return false;
        await _recordLinkSequence(
          deletedLink,
          subDomain: '_relinkTask.recordDeletedSent',
        );
        await _recordLinkSequence(
          newLink,
          subDomain: '_relinkTask.recordNewSent',
        );

        // Same propagation tagging as [linkTaskToProject]: relinking is a
        // task-link side-effect, not a direct project edit.
        _updateNotifications.notify({
          oldLink.fromId,
          oldLink.toId,
          projectId,
          taskId,
          projectNotification,
          projectEntityUpdateNotification(oldLink.fromId),
          projectEntityUpdateNotification(projectId),
          propagatedNotification(
            projectEntityUpdateNotification(oldLink.fromId),
          ),
          propagatedNotification(projectEntityUpdateNotification(projectId)),
        });
        try {
          await _enqueueLinkSync(deletedLink, SyncEntryStatus.update);
          await _enqueueLinkSync(newLink, SyncEntryStatus.initial);
        } catch (error, stackTrace) {
          getIt<DomainLogger>().error(
            LogDomain.sync,
            error,
            message:
                'outbox enqueue failed after _relinkTask; VCs already committed',
            stackTrace: stackTrace,
            subDomain: '_relinkTask.enqueue',
          );
        }
        return true;
      },
      commitWhen: (ok) => ok,
    );
  }

  Future<bool> _softDeleteLink(
    EntryLink link, {
    bool onlyIfPrivacyMismatched = false,
  }) async {
    return _vectorClockService.withVcScope<bool>(
      () async {
        final now = DateTime.now();
        final deleted = await _prepareDeletedLink(link, now);
        final res = await _journalDb.transaction(() async {
          final currentLink = await _journalDb.getProjectLinkForTask(link.toId);
          if (currentLink != link) return 0;
          if (onlyIfPrivacyMismatched) {
            final taskRow = await _journalDb.entityById(link.toId);
            final projectRow = await _journalDb.entityById(link.fromId);
            final task = taskRow == null ? null : fromDbEntity(taskRow);
            final project = projectRow == null
                ? null
                : fromDbEntity(projectRow);
            if (task is! Task ||
                project is! ProjectEntry ||
                (task.meta.private ?? false) ==
                    (project.meta.private ?? false)) {
              return 0;
            }
          }
          return _journalDb.upsertEntryLink(deleted);
        });
        if (res == 0) return false;
        await _recordLinkSequence(
          deleted,
          subDomain: '_softDeleteLink.recordSent',
        );
        // Same propagation tagging as [linkTaskToProject]: unlinking is a
        // task-link side-effect, not a direct project edit.
        _updateNotifications.notify({
          link.fromId,
          link.toId,
          projectNotification,
          projectEntityUpdateNotification(link.fromId),
          propagatedNotification(projectEntityUpdateNotification(link.fromId)),
        });
        try {
          await _enqueueLinkSync(deleted, SyncEntryStatus.update);
        } catch (error, stackTrace) {
          getIt<DomainLogger>().error(
            LogDomain.sync,
            error,
            message:
                'outbox enqueue failed after _softDeleteLink; VC already committed',
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

class _RelinkInsertFailed implements Exception {
  const _RelinkInsertFailed();
}

const Set<String> _overviewNotificationTokens = {
  projectNotification,
  taskNotification,
  categoriesNotification,
  privateToggleNotification,
};

/// Kept-alive provider for the singleton [ProjectRepository], wired to the
/// app's database, caches, persistence, and update-notification services from
/// `getIt`. Every project provider in this feature reads through here.
final projectRepositoryProvider = Provider<ProjectRepository>(
  projectRepository,
  name: 'projectRepositoryProvider',
);
ProjectRepository projectRepository(Ref ref) {
  return ProjectRepository(
    journalDb: getIt<JournalDb>(),
    entitiesCacheService: getIt<EntitiesCacheService>(),
    persistenceLogic: getIt<PersistenceLogic>(),
    updateNotifications: getIt<UpdateNotifications>(),
    vectorClockService: getIt<VectorClockService>(),
    projectHasActiveAgent: projectHasActiveAgent,
    mutationCoordinator: ref.watch(projectAgentMutationCoordinatorProvider),
  );
}

/// Returns whether [projectId] still owns a non-destroyed project agent.
///
/// Project and agent state live in separate databases, so the repository takes
/// this as an injected integrity guard. The production provider resolves it
/// directly from the agent store; tests can supply a deterministic callback.
Future<bool> projectHasActiveAgent(String projectId) async {
  if (!getIt.isRegistered<AgentDatabase>()) return false;
  final repository = AgentRepository(getIt<AgentDatabase>());
  final links = await repository.getLinksTo(
    projectId,
    type: AgentLinkTypes.agentProject,
  );
  if (links.isEmpty) return false;
  final entities = await repository.getEntitiesByIds(
    links.map((link) => link.fromId).toSet(),
  );
  return entities.values.any(
    (entity) =>
        entity is AgentIdentityEntity &&
        entity.kind == AgentKinds.projectAgent &&
        entity.lifecycle != AgentLifecycle.destroyed,
  );
}
