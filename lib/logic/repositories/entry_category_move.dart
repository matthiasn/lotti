import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/logic/repositories/category_move_intents.dart';
import 'package:lotti/logic/repositories/journal_repository.dart';
import 'package:lotti/logic/repositories/project_repository.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';

/// Moves an entry to another category with everything that belongs to it,
/// across a crash.
///
/// The category is on every row, so a move is several writes, in this
/// order: the entry; every entry linked from it — its timers, recordings
/// and images, and any task it links to; each moved task's checklists and
/// their items; and last the project link of each moved task whose project
/// is no longer in its category (`ProjectRepository.linkTaskToProject`
/// refuses a cross-category link, but nothing re-checked one afterwards).
///
/// The move is recorded before its first write ([CategoryMoveIntents]) and
/// the record removed after the last one. An app that dies in between
/// finishes the move at the next start ([replay]) — every write is a no-op
/// where it landed — so a task is never left in its new category with its
/// entries, checklists or project in the old one
/// (`specs/tla/TaskCategoryMove.tla`; ADR 0122).
class EntryCategoryMove {
  EntryCategoryMove({
    required this._journalRepository,
    required this._journalDb,
    required this._projectRepository,
    required this._intents,
    required this._domainLogger,
  });

  final JournalRepository _journalRepository;
  final JournalDb _journalDb;
  final ProjectRepository _projectRepository;
  final CategoryMoveIntents _intents;
  final DomainLogger _domainLogger;

  static const _sub = 'EntryCategoryMove';

  /// Moves [entryId] to [categoryId] — `null` clears its category — with
  /// everything that belongs to it. Returns whether the entry's own write
  /// landed; when it did not (the entry is gone, or the write was refused)
  /// nothing else is moved.
  ///
  /// A failure after the entry's write is logged and the move kept recorded
  /// for the next start: the entry has moved, and the rest follows then.
  Future<bool> move(String entryId, String? categoryId) async {
    await _intents.record(entryId, categoryId);
    final moved = await _journalRepository.updateCategoryId(
      entryId,
      categoryId: categoryId,
    );
    if (!moved) {
      await _intents.clear(entryId);
      return false;
    }
    try {
      await _follow(entryId, categoryId);
      await _intents.clear(entryId);
    } catch (error, stackTrace) {
      _domainLogger.error(
        LogDomain.persistence,
        error,
        message:
            'Category move of ${DomainLogger.sanitizeId(entryId)} '
            'left for the next start',
        subDomain: _sub,
        stackTrace: stackTrace,
      );
    }
    return true;
  }

  /// Finishes every move the app died in the middle of. A recorded move is
  /// finished while its entry holds the recorded category — the entry's own
  /// write landed — and dropped otherwise: one never begun, or overtaken by
  /// a later move of the entry, here or on another device, which a replay
  /// must not undo. A replay that throws keeps its record for the next
  /// start. Runs once at startup.
  Future<void> replay() async {
    for (final MapEntry(key: entryId, value: move)
        in (await _intents.pending()).entries) {
      try {
        if (move != null) {
          final entry = await _journalDb.journalEntityById(entryId);
          if (entry != null && entry.meta.categoryId == move.categoryId) {
            await _follow(entryId, move.categoryId);
          }
        }
        await _intents.clear(entryId);
      } catch (error, stackTrace) {
        _domainLogger.error(
          LogDomain.persistence,
          error,
          message:
              'Replaying the category move of '
              '${DomainLogger.sanitizeId(entryId)} failed',
          subDomain: _sub,
          stackTrace: stackTrace,
        );
      }
    }
  }

  /// Writes [categoryId] on everything that follows [entryId], each write
  /// skipped where the row already holds it, then drops the project links
  /// the move left across categories.
  Future<void> _follow(String entryId, String? categoryId) async {
    final entry = await _journalDb.journalEntityById(entryId);
    final tasks = <Task>[if (entry is Task) entry];
    for (final linked in await _journalRepository.getLinkedEntities(
      linkedTo: entryId,
    )) {
      // A write that did not land leaves the entry where it was — deleted
      // since, or never there — and its project is still the right one.
      if (await _setCategory(linked, categoryId) && linked is Task) {
        tasks.add(linked);
      }
    }
    for (final task in tasks) {
      await _checklistsFollow(task, categoryId);
    }
    for (final task in tasks) {
      await _dropCrossCategoryProject(task, categoryId);
    }
  }

  /// Moves [task]'s checklists and their items to [categoryId]. A checklist
  /// another task shows too, or an item another task's checklist lists,
  /// stays where it is: it belongs to both.
  Future<void> _checklistsFollow(Task task, String? categoryId) async {
    final checklistIds = task.data.checklistIds ?? const <String>[];
    for (final checklistId in checklistIds) {
      final checklist = await _journalDb.journalEntityById(checklistId);
      if (checklist is! Checklist ||
          checklist.data.linkedTasks.any((id) => id != task.id)) {
        continue;
      }
      await _setCategory(checklist, categoryId);
      for (final itemId in checklist.data.linkedChecklistItems) {
        final item = await _journalDb.journalEntityById(itemId);
        if (item is! ChecklistItem ||
            item.data.linkedChecklists.any(
              (id) => !checklistIds.contains(id),
            )) {
          continue;
        }
        await _setCategory(item, categoryId);
      }
    }
  }

  /// Unlinks [task] from its project when that project is not in
  /// [categoryId].
  ///
  /// Comparing against the project's category rather than the task's former
  /// one keeps a project a re-pick of the same category did not leave, and
  /// clearing the category drops a project that has one while keeping an
  /// uncategorized one — the pairings `linkTaskToProject` accepts. The
  /// lookup is unfiltered by privacy: a private project hidden from view
  /// still holds the task.
  Future<void> _dropCrossCategoryProject(Task task, String? categoryId) async {
    final project = await _projectRepository.getLinkedProjectForTask(task.id);
    if (project == null || project.meta.categoryId == categoryId) return;
    await _projectRepository.unlinkTaskFromProject(task.id);
  }

  /// Writes [categoryId] on [entity] unless it holds it; whether it holds it
  /// afterwards.
  Future<bool> _setCategory(JournalEntity entity, String? categoryId) async =>
      entity.meta.categoryId == categoryId ||
      await _journalRepository.updateCategoryId(
        entity.id,
        categoryId: categoryId,
      );
}

/// The app's [EntryCategoryMove], over the journal, the project links and
/// the settings database the moves are recorded in.
final entryCategoryMoveProvider = Provider<EntryCategoryMove>(
  (ref) => EntryCategoryMove(
    journalRepository: ref.watch(journalRepositoryProvider),
    journalDb: ref.watch(journalDbProvider),
    projectRepository: ref.watch(projectRepositoryProvider),
    intents: CategoryMoveIntents(settingsDb: ref.watch(settingsDbProvider)),
    domainLogger: ref.watch(domainLoggerProvider),
  ),
  name: 'entryCategoryMoveProvider',
);
