import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/service/project_agent_service.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';

/// Moves a project, its linked tasks, and their directly linked entries to one
/// category while keeping project membership and project-agent scope intact.
///
/// Journal entries and agent identities live in separate stores, so the move
/// is compensating rather than a single database transaction. Every forward
/// step is serialized with project-agent provisioning/deletion; on failure the
/// service removes any newly restored links, restores entry categories and
/// agent scopes, restores the original project, and finally recreates the
/// original task memberships.
class ProjectCategoryMigrationService {
  ProjectCategoryMigrationService(
    this._projectRepository,
    this._journalRepository,
    this._projectAgentService,
    this._mutationCoordinator,
  );

  final ProjectRepository _projectRepository;
  final JournalRepository _journalRepository;
  final ProjectAgentService _projectAgentService;
  final ProjectAgentMutationCoordinator _mutationCoordinator;

  /// Persists [requested], migrating category-scoped dependants when needed.
  Future<bool> save(ProjectEntry requested) {
    return _mutationCoordinator.run(requested.id, () async {
      final original = await _projectRepository.getProjectById(requested.id);
      if (original == null) return false;
      if (original.meta.categoryId == requested.meta.categoryId) {
        return _projectRepository.updateProject(requested);
      }

      final tasks = await _projectRepository.getTasksForProjectUnfiltered(
        requested.id,
      );
      final originalCategories = await _captureEntryCategories(tasks);
      final unlinkedTaskIds = <String>[];
      final relinkedTaskIds = <String>[];
      var previousAgentScopes = const <String, Set<String>>{};
      var projectMoved = false;

      try {
        for (final task in tasks) {
          final unlinked = await _projectRepository.unlinkTaskFromProject(
            task.id,
          );
          if (!unlinked) {
            throw StateError('Could not unlink task ${task.id}');
          }
          unlinkedTaskIds.add(task.id);
        }

        previousAgentScopes = await _projectAgentService
            .updateProjectAgentScopes(
              projectId: requested.id,
              allowedCategoryIds: _scopeFor(requested.meta.categoryId),
            );

        projectMoved = await _projectRepository.updateProject(requested);
        if (!projectMoved) {
          throw StateError('Could not persist the project category');
        }

        for (final entryId in originalCategories.keys) {
          if (!await _updateAndVerifyCategory(
            entryId,
            requested.meta.categoryId,
          )) {
            throw StateError('Could not move linked entry $entryId');
          }
        }

        for (final task in tasks) {
          final linked = await _projectRepository.linkTaskToProject(
            projectId: requested.id,
            taskId: task.id,
          );
          if (!linked) {
            throw StateError('Could not restore task ${task.id}');
          }
          relinkedTaskIds.add(task.id);
        }
        return true;
      } catch (error, stackTrace) {
        developer.log(
          'Project category migration failed; restoring prior state',
          name: 'ProjectCategoryMigrationService',
          error: error,
          stackTrace: stackTrace,
        );
        await _restore(
          original: original,
          originalCategories: originalCategories,
          originalTaskIds: tasks.map((task) => task.id).toList(),
          unlinkedTaskIds: unlinkedTaskIds,
          relinkedTaskIds: relinkedTaskIds,
          previousAgentScopes: previousAgentScopes,
          projectMoved: projectMoved,
        );
        return false;
      }
    });
  }

  Future<Map<String, String?>> _captureEntryCategories(
    List<Task> tasks,
  ) async {
    final categories = <String, String?>{};
    for (final task in tasks) {
      categories[task.id] = task.meta.categoryId;
      final linked = await _journalRepository.getLinkedEntities(
        linkedTo: task.id,
      );
      for (final entry in linked) {
        categories.putIfAbsent(entry.id, () => entry.meta.categoryId);
      }
    }
    return categories;
  }

  Future<bool> _updateAndVerifyCategory(
    String entryId,
    String? categoryId,
  ) async {
    final updated = await _journalRepository.updateCategoryId(
      entryId,
      categoryId: categoryId,
    );
    if (!updated) return false;
    final persisted = await _journalRepository.getJournalEntityById(entryId);
    return persisted?.meta.categoryId == categoryId;
  }

  Future<void> _restore({
    required ProjectEntry original,
    required Map<String, String?> originalCategories,
    required List<String> originalTaskIds,
    required List<String> unlinkedTaskIds,
    required List<String> relinkedTaskIds,
    required Map<String, Set<String>> previousAgentScopes,
    required bool projectMoved,
  }) async {
    for (final taskId in relinkedTaskIds.reversed) {
      try {
        await _projectRepository.unlinkTaskFromProject(taskId);
      } catch (_) {
        // Continue compensating the remaining state.
      }
    }
    for (final entry in originalCategories.entries) {
      try {
        await _updateAndVerifyCategory(entry.key, entry.value);
      } catch (_) {
        // Best-effort compensation continues below.
      }
    }
    try {
      await _projectAgentService.restoreProjectAgentScopes(
        projectId: original.id,
        scopesByAgentId: previousAgentScopes,
      );
    } catch (_) {
      // Continue with journal-domain restoration.
    }
    if (projectMoved) {
      try {
        await _projectRepository.updateProject(original);
      } catch (_) {
        // Membership restoration below is still worth attempting.
      }
    }
    for (final taskId in originalTaskIds) {
      if (!unlinkedTaskIds.contains(taskId)) continue;
      try {
        await _projectRepository.linkTaskToProject(
          projectId: original.id,
          taskId: taskId,
        );
      } catch (_) {
        // The caller receives false; every independent compensation is tried.
      }
    }
  }
}

Set<String> _scopeFor(String? categoryId) => {?categoryId};

final projectCategoryMigrationServiceProvider =
    Provider<ProjectCategoryMigrationService>(
      (ref) => ProjectCategoryMigrationService(
        ref.watch(projectRepositoryProvider),
        ref.watch(journalRepositoryProvider),
        ref.watch(projectAgentServiceProvider),
        ref.watch(
          projectAgentMutationCoordinatorProvider,
        ),
      ),
      name: 'projectCategoryMigrationServiceProvider',
    );
