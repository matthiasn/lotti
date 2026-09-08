import 'package:clock/clock.dart';
import 'package:lotti/classes/change_source.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/plaza/data/task_projection.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/utils/image_utils.dart';

/// One privacy-filtered project snapshot, independent of the GPU scene.
class ProjectPlazaData {
  const ProjectPlazaData({
    required this.project,
    required this.tasks,
    required this.dependencyIds,
    this.category,
  });

  final ProjectEntry project;
  final CategoryDefinition? category;
  final List<PlazaTask> tasks;

  /// Includes unresolved child IDs so a later sync arrival refreshes the world.
  final Set<String> dependencyIds;
}

/// Category navigation needs task facts, but no checklist or image payloads.
class PlazaProjectSummary {
  const PlazaProjectSummary({required this.project, required this.tasks});

  final ProjectEntry project;
  final List<PlazaTask> tasks;
}

class CategoryPlazaData {
  const CategoryPlazaData({
    required this.category,
    required this.projects,
    required this.dependencyIds,
  });

  final CategoryDefinition category;
  final List<PlazaProjectSummary> projects;
  final Set<String> dependencyIds;
}

/// Bulk projection of journal entities into a project world.
///
/// Every entity read uses the journal's private-status filter. Links are kept
/// only when both endpoints belong to the visible project; a hidden or deleted
/// link cannot pull another project's data into this scene.
class PlazaRepository {
  PlazaRepository({
    required this.db,
    required this.cache,
    required this.persistence,
  });

  final JournalDb db;
  final EntitiesCacheService cache;
  final PersistenceLogic persistence;

  /// Reads exactly one category, including its completed projects. Full child
  /// content is loaded only when the user enters an individual project world.
  Future<CategoryPlazaData?> loadCategory(String categoryId) async {
    final category = cache.getCategoryById(categoryId);
    if (category == null ||
        category.deletedAt != null ||
        cache.lockedCategoryIds.contains(categoryId)) {
      return null;
    }
    final projects = await db.getProjectsForCategory(categoryId);
    final summaries = <PlazaProjectSummary>[];
    final dependencies = <String>{categoryId};
    for (final project in projects) {
      if (project.isDeleted || project.meta.categoryId != categoryId) continue;
      dependencies.add(project.id);
      final members = await db.getTasksForProject(project.id);
      dependencies.addAll(members.map((task) => task.id));
      summaries.add(
        PlazaProjectSummary(
          project: project,
          tasks: List.unmodifiable([
            for (final task in members)
              if (_belongsTo(task, project))
                projectPlazaTask(
                  task: task,
                  checklistItems: const [],
                  linkedTaskIds: const [],
                  categoryColor: _categoryColor(categoryId),
                ),
          ]),
        ),
      );
    }
    // A lock arriving during the read must not publish the former scope.
    if (cache.lockedCategoryIds.contains(categoryId)) return null;
    return CategoryPlazaData(
      category: category,
      projects: List.unmodifiable(summaries),
      dependencyIds: Set.unmodifiable(dependencies),
    );
  }

  bool _belongsTo(Task task, ProjectEntry project) =>
      !task.isDeleted &&
      task.meta.categoryId == project.meta.categoryId &&
      (task.meta.private ?? false) == (project.meta.private ?? false) &&
      !cache.lockedCategoryIds.contains(task.meta.categoryId);

  int _categoryColor(String? categoryId) => colorFromCssHex(
    cache.getCategoryById(categoryId)?.color ?? defaultCategoryColorHex,
    substitute: colorFromCssHex(defaultCategoryColorHex),
  ).toARGB32();

  /// Re-reads membership and item data before writing so a displayed preview
  /// cannot overwrite a concurrent rename or check an item moved elsewhere.
  Future<bool> setChecklistItemChecked({
    required String projectId,
    required String taskId,
    required String itemId,
    required bool checked,
  }) async {
    final entries = await db.getJournalEntitiesForIds({taskId, itemId});
    final task = entries
        .whereType<Task>()
        .where((entry) => entry.id == taskId)
        .firstOrNull;
    final item = entries
        .whereType<ChecklistItem>()
        .where((entry) => entry.id == itemId)
        .firstOrNull;
    if (task == null ||
        item == null ||
        task.isDeleted ||
        item.isDeleted ||
        item.data.isArchived ||
        cache.lockedCategoryIds.contains(task.meta.categoryId)) {
      return false;
    }
    final project = await db.getProjectForTask(taskId);
    if (project == null ||
        project.id != projectId ||
        !_belongsTo(task, project)) {
      return false;
    }
    final checklists = await _readEntities({...?task.data.checklistIds});
    if (!checklists.whereType<Checklist>().any(
      (checklist) =>
          !checklist.isDeleted &&
          checklist.data.linkedChecklistItems.contains(itemId),
    )) {
      return false;
    }
    if (item.data.isChecked == checked) return true;
    final updated = item.copyWith(
      meta: await persistence.updateMetadata(item.meta),
      data: item.data.copyWith(
        isChecked: checked,
        checkedBy: ChangeSource.user,
        checkedAt: clock.now(),
      ),
    );
    return await persistence.updateDbEntity(updated, linkedId: taskId) == true;
  }

  Future<ProjectPlazaData?> loadProject(String projectId) async {
    final roots = await db.getJournalEntitiesForIds({projectId});
    final project = roots.whereType<ProjectEntry>().firstOrNull;
    if (project == null || project.meta.deletedAt != null) return null;
    final category = cache.getCategoryById(project.meta.categoryId);
    if (cache.lockedCategoryIds.contains(project.meta.categoryId)) return null;

    final members = await db.getTasksForProject(projectId);
    final tasks = members.where((task) => _belongsTo(task, project)).toList();
    final taskIds = {for (final task in tasks) task.meta.id};
    final checklistIds = {
      for (final task in tasks) ...?task.data.checklistIds,
    };
    final coverIds = {for (final task in tasks) ?task.data.coverArtId};
    final related = await _readEntities({...checklistIds, ...coverIds});
    final checklists = {
      for (final entity in related.whereType<Checklist>())
        if (entity.meta.deletedAt == null) entity.meta.id: entity,
    };
    final covers = {
      for (final entity in related.whereType<JournalImage>())
        if (entity.meta.deletedAt == null) entity.meta.id: entity,
    };
    final itemIds = {
      for (final checklist in checklists.values)
        ...checklist.data.linkedChecklistItems,
    };
    final items = {
      for (final entity in (await _readEntities(
        itemIds,
      )).whereType<ChecklistItem>())
        entity.meta.id: entity,
    };
    final linksByTask = <String, Set<String>>{};
    final dependencyIds = {
      projectId,
      ?project.meta.categoryId,
      for (final task in members) task.meta.id,
      ...checklistIds,
      ...coverIds,
      ...itemIds,
    };
    // Bound SQLite's parameter count for large categories/projects.
    final ids = taskIds.toList();
    for (var offset = 0; offset < ids.length; offset += _batchSize) {
      final batch = ids.skip(offset).take(_batchSize).toSet();
      for (final link in await db.linksForEntryIdsBidirectional(batch)) {
        dependencyIds.add(link.id);
        if (link.hidden == true || link.deletedAt != null) continue;
        if (!taskIds.contains(link.fromId) || !taskIds.contains(link.toId)) {
          continue;
        }
        linksByTask.putIfAbsent(link.fromId, () => {}).add(link.toId);
        linksByTask.putIfAbsent(link.toId, () => {}).add(link.fromId);
      }
    }
    return ProjectPlazaData(
      project: project,
      category: category,
      dependencyIds: Set.unmodifiable(dependencyIds),
      tasks: List.unmodifiable([
        for (final task in tasks)
          projectPlazaTask(
            task: task,
            checklistItems: [
              for (final checklistId in task.data.checklistIds ?? <String>[])
                for (final itemId
                    in checklists[checklistId]?.data.linkedChecklistItems ??
                        <String>[])
                  ?items[itemId],
            ],
            linkedTaskIds: linksByTask[task.meta.id] ?? const {},
            categoryColor: _categoryColor(task.meta.categoryId),
            coverImageUrl: switch (covers[task.data.coverArtId]) {
              final cover? => Uri.file(getFullImagePath(cover)).toString(),
              _ => null,
            },
          ),
      ]),
    );
  }

  static const _batchSize = 400;

  Future<List<JournalEntity>> _readEntities(Set<String> ids) async {
    final result = <JournalEntity>[];
    final list = ids.toList();
    for (var offset = 0; offset < list.length; offset += _batchSize) {
      result.addAll(
        await db.getJournalEntitiesForIds(
          list.skip(offset).take(_batchSize).toSet(),
        ),
      );
    }
    return result
        .where(
          (entity) => !cache.lockedCategoryIds.contains(entity.meta.categoryId),
        )
        .toList();
  }
}
