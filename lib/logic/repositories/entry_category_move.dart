import 'dart:async';

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
/// the record removed once every write is confirmed. An app that dies in
/// between, or a write that does not land, finishes the move at the next
/// start ([replay]) — every write is a no-op where it landed — so a task is
/// never left in its new category with its entries, checklists or project
/// in the old one (`specs/tla/TaskCategoryMove.tla`; ADR 0122). Moves of
/// one entry run one at a time.
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

  /// The move of each entry in flight, which a later move of the same entry
  /// waits for: the record is per entry, and an earlier move clearing it, or
  /// landing its writes, after a later one began would undo the later one.
  final Map<String, Future<void>> _inFlight = {};

  static const _sub = 'EntryCategoryMove';

  /// Moves [entryId] to [categoryId] — `null` clears its category — with
  /// everything that belongs to it. Returns whether the entry holds
  /// [categoryId] afterwards; when it does not (the entry is gone, or the
  /// write was refused) nothing else is moved.
  ///
  /// A follower that did not take the category, or a failure after the
  /// entry's write, keeps the move recorded for the next start, and is
  /// logged: the entry has moved, and the rest follows then.
  Future<bool> move(String entryId, String? categoryId) =>
      _oneAtATime(entryId, () async {
        await _intents.record(entryId, categoryId);
        if (!await _holds(entryId, categoryId, write: true)) {
          await _intents.clear(entryId);
          return false;
        }
        await _finish(entryId, categoryId, during: 'move');
        return true;
      });

  /// Finishes every move the app died in the middle of. A recorded move is
  /// finished while its entry holds the recorded category — the entry's own
  /// write landed — and dropped otherwise: one never begun, or overtaken by
  /// a later move of the entry, here or on another device, which a replay
  /// must not undo. A replay that does not complete keeps its record for the
  /// next start. Runs once at startup.
  Future<void> replay() async {
    for (final MapEntry(key: entryId, value: move)
        in (await _intents.pending()).entries) {
      await _oneAtATime(entryId, () async {
        if (move == null || !await _holds(entryId, move.categoryId)) {
          await _intents.clear(entryId);
          return;
        }
        await _finish(entryId, move.categoryId, during: 'replay');
      });
    }
  }

  Future<T> _oneAtATime<T>(String entryId, Future<T> Function() action) async {
    final previous = _inFlight[entryId];
    final done = Completer<void>();
    _inFlight[entryId] = done.future;
    try {
      if (previous != null) await previous;
      return await action();
    } finally {
      done.complete();
      if (identical(_inFlight[entryId], done.future)) {
        final _ = _inFlight.remove(entryId);
      }
    }
  }

  /// Runs the rest of the move and clears its record once every write is
  /// confirmed; keeps the record, and logs, when one is not.
  Future<void> _finish(
    String entryId,
    String? categoryId, {
    required String during,
  }) async {
    try {
      if (await _follow(entryId, categoryId)) {
        await _intents.clear(entryId);
        return;
      }
      _domainLogger.log(
        LogDomain.persistence,
        'Category $during of ${DomainLogger.sanitizeId(entryId)}: a write '
        'did not land — left for the next start',
        subDomain: _sub,
      );
    } catch (error, stackTrace) {
      _domainLogger.error(
        LogDomain.persistence,
        error,
        message:
            'Category $during of ${DomainLogger.sanitizeId(entryId)} '
            'left for the next start',
        subDomain: _sub,
        stackTrace: stackTrace,
      );
    }
  }

  /// Writes [categoryId] on everything that follows [entryId], each write
  /// skipped where the row already holds it, then drops the project links
  /// the move left across categories. Whether every row that is still
  /// there took the category.
  Future<bool> _follow(String entryId, String? categoryId) async {
    var complete = true;
    final entry = await _journalDb.journalEntityById(entryId);
    final tasks = <Task>[if (entry is Task) entry];
    for (final linked in await _journalRepository.getLinkedEntities(
      linkedTo: entryId,
    )) {
      switch (await _setCategory(linked, categoryId)) {
        case true:
          if (linked is Task) tasks.add(linked);
        case false:
          complete = false;
        // Deleted since: nothing to move, and no project to sweep.
        case null:
      }
    }
    for (final task in tasks) {
      if (!await _checklistsFollow(task, categoryId)) complete = false;
    }
    for (final task in tasks) {
      await _dropCrossCategoryProject(task, categoryId);
    }
    return complete;
  }

  /// Moves [task]'s checklists and their items to [categoryId]; whether
  /// each took it. A checklist another task shows too stays where it is, and
  /// so does an item any such checklist lists: it belongs to both.
  Future<bool> _checklistsFollow(Task task, String? categoryId) async {
    final moving = <Checklist>[];
    for (final checklistId in task.data.checklistIds ?? const <String>[]) {
      final checklist = await _journalDb.journalEntityById(checklistId);
      if (checklist is Checklist &&
          checklist.data.linkedTasks.every((id) => id == task.id)) {
        moving.add(checklist);
      }
    }
    final movingIds = {for (final checklist in moving) checklist.meta.id};
    var complete = true;
    for (final checklist in moving) {
      if (await _setCategory(checklist, categoryId) == false) complete = false;
      for (final itemId in checklist.data.linkedChecklistItems) {
        final item = await _journalDb.journalEntityById(itemId);
        if (item is! ChecklistItem ||
            !item.data.linkedChecklists.every(movingIds.contains)) {
          continue;
        }
        if (await _setCategory(item, categoryId) == false) complete = false;
      }
    }
    return complete;
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

  /// Writes [categoryId] on [entity] unless it holds it. Whether the row
  /// holds it afterwards; `null` when the row is gone.
  Future<bool?> _setCategory(JournalEntity entity, String? categoryId) async {
    if (entity.meta.categoryId == categoryId) return true;
    if (await _journalRepository.updateCategoryId(
      entity.id,
      categoryId: categoryId,
    )) {
      return true;
    }
    final stored = await _journalDb.journalEntityById(entity.id);
    return stored == null ? null : stored.meta.categoryId == categoryId;
  }

  /// Whether the entry [entryId] holds [categoryId] — after writing it, with
  /// [write]. A write reported as failed can have committed (the write
  /// answers false too when work after its commit throws), so the stored
  /// row decides.
  Future<bool> _holds(
    String entryId,
    String? categoryId, {
    bool write = false,
  }) async {
    if (write &&
        await _journalRepository.updateCategoryId(
          entryId,
          categoryId: categoryId,
        )) {
      return true;
    }
    final stored = await _journalDb.journalEntityById(entryId);
    return stored != null && stored.meta.categoryId == categoryId;
  }
}

/// The app's [EntryCategoryMove], over the journal, the project links and
/// the settings database the moves are recorded in. Kept for the app's life,
/// so moves of one entry from anywhere run one at a time.
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
