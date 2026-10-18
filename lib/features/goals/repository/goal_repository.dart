import 'package:clock/clock.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/goals/logic/goal_charter.dart';
import 'package:lotti/features/goals/model/goal_checkin_source.dart';
import 'package:lotti/features/goals/model/goal_entry_ids.dart';
import 'package:lotti/features/goals/workflow/goal_criterion_names.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/services/metadata_service.dart';

/// Journal-side persistence for goals: the durable, user-authored half of a
/// goal, independent of whether its coaching agent still exists.
///
/// Every write here is **idempotent by construction**. Both entry points are
/// reached from paths that legitimately run more than once — the startup
/// backfill on every device that syncs a goal, and goal creation retried after
/// a deferred outbox flush failed — so the ids are derived (see
/// [goalEntryUuidV5Input]) and an existing row is updated rather than
/// duplicated.
class GoalRepository {
  GoalRepository({
    required this._journalDb,
    required this._persistenceLogic,
    required this._metadataService,
  });

  final JournalDb _journalDb;
  final PersistenceLogic _persistenceLogic;

  /// Used only for its pure [MetadataService.generateId]. Resolving an id has
  /// to stay free of side effects: `createMetadata` reserves AND commits a
  /// vector-clock counter, so computing an id through it — just to look the
  /// row up and find it already there — would burn a counter on every startup
  /// backfill, on every device.
  final MetadataService _metadataService;

  /// The journal id of the goal coached by [agentId].
  ///
  /// Pure and side-effect free, so callers can address a goal before it
  /// exists — which is what lets a spec snapshot name its goal in the same
  /// transaction that creates it.
  String goalIdForAgent(String agentId) =>
      _metadataService.generateId(uuidV5Input: goalEntryUuidV5Input(agentId));

  /// The goal coached by [agentId], or null when it has no journal entry yet.
  Future<GoalEntry?> getGoalForAgent(String agentId) async {
    final id = goalIdForAgent(agentId);
    final entity = await _journalDb.journalEntityById(id);
    return entity is GoalEntry && !entity.isDeleted ? entity : null;
  }

  /// Every goal, newest first. Spec snapshots are excluded.
  Future<List<GoalEntry>> getGoals() => _journalDb.getGoals();

  /// The immutable spec snapshots of [goalId], newest version first.
  Future<List<GoalEntry>> getSpecSnapshots(String goalId) =>
      _journalDb.getSpecSnapshotsForGoal(goalId);

  /// Display names for the habits and measurables a goal's criteria refer
  /// to, keyed by id — the [GoalCriterionNameReader] the agent workflow
  /// names an untitled criterion with. An id with no definition behind it
  /// is simply absent from the result.
  Future<Map<String, String>> criterionNames(GoalCriterionEntityIds ids) async {
    final names = <String, String>{};
    for (final habitId in ids.habitIds) {
      final habit = await _journalDb.getHabitById(habitId);
      if (habit != null) names[habitId] = habit.name;
    }
    for (final dataTypeId in ids.dataTypeIds) {
      final dataType = await _journalDb.getMeasurableDataTypeById(dataTypeId);
      if (dataType != null) names[dataTypeId] = dataType.displayName;
    }
    return names;
  }

  /// The check-ins linked to [agentId]'s goal that carry words.
  ///
  /// Lives here rather than in a provider closure because this is journal
  /// access, and the repository is what owns it — a closure reaching into the
  /// service locator for a query builder cannot be tested at all.
  ///
  /// A recording with no transcript yet is deliberately absent: it is saved
  /// before it is transcribed, and compacting silence would produce a summary
  /// of nothing.
  Future<List<GoalCheckInSource>> checkInSources(String agentId) async {
    final links = await _journalDb.linksFromIds([
      goalIdForAgent(agentId),
    ]).get();
    final ids = links.map((link) => link.toId).toSet();
    if (ids.isEmpty) return const [];
    final entities = await _journalDb.getJournalEntitiesForIds(ids);
    return [
      for (final entity in entities)
        if (!entity.isDeleted &&
            (entity is JournalAudio || entity is JournalEntry))
          if (entity.entryText?.plainText.trim() ?? '' case final text
              when text.isNotEmpty)
            GoalCheckInSource(
              entryId: entity.meta.id,
              recordedAt: entity.meta.dateFrom,
              text: text,
            ),
    ];
  }

  /// The goal's charter (ADR 0140): the live text entries linked into
  /// [agentId]'s goal row by a charter link, in the order they were written.
  ///
  /// A charter link points from the entry to the goal — the reverse of a
  /// check-in's — so nothing here can surface a check-in, and no check-in
  /// reader can surface a charter entry.
  Future<List<JournalEntry>> charterEntries(String agentId) async {
    final links = await _journalDb.charterLinksToGoal(goalIdForAgent(agentId));
    final ids = links.map((link) => link.fromId).toSet();
    if (ids.isEmpty) return const [];
    final entities = await _journalDb.getJournalEntitiesForIds(ids);
    return [
      for (final entity in entities)
        if (entity is JournalEntry &&
            !entity.isDeleted &&
            (entity.entryText?.plainText.trim() ?? '').isNotEmpty)
          entity,
    ]..sort((a, b) {
      final byDate = a.meta.dateFrom.compareTo(b.meta.dateFrom);
      return byDate != 0 ? byDate : a.meta.id.compareTo(b.meta.id);
    });
  }

  /// [charterEntries] in the plain shape the headless workflow reads — the
  /// [GoalCharterReader] the agent wakes with.
  Future<List<GoalCharterEntry>> charter(String agentId) async => [
    for (final entry in await charterEntries(agentId))
      GoalCharterEntry(
        entryId: entry.meta.id,
        writtenAt: entry.meta.dateFrom,
        text: entry.entryText!.plainText.trim(),
      ),
  ];

  /// Writes [text] as a new charter entry of [agentId]'s goal, in the goal's
  /// category and privacy. Returns null when nothing was written: blank
  /// words, a goal with no journal row yet, or a refused write. An entry
  /// whose charter link is refused is deleted again, so a retry cannot leave
  /// a stray copy the goal page never shows.
  Future<JournalEntry?> createCharterEntry({
    required String agentId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    final goal = await getGoalForAgent(agentId);
    if (goal == null) return null;
    final entry =
        JournalEntity.journalEntry(
              entryText: EntryText(plainText: trimmed),
              meta: await _persistenceLogic.createMetadata(
                dateFrom: clock.now(),
                categoryId: goal.meta.categoryId,
                private: goal.meta.private,
              ),
            )
            as JournalEntry;
    if (!(await _persistenceLogic.createDbEntity(entry) ?? false)) {
      return null;
    }
    bool linked;
    try {
      linked = await _persistenceLogic.createLink(
        fromId: entry.meta.id,
        toId: goal.meta.id,
        linkType: EntryLinkType.charter,
      );
    } catch (_) {
      // A link write that throws is as refused as one that answers false.
      linked = false;
    }
    if (linked) return entry;
    await _deleteEntry(entry, goalId: goal.meta.id);
    return null;
  }

  /// Saves new words for the charter entry [entry] of [agentId]'s goal.
  /// Blank words are refused: an entry emptied in its sheet is deleted there.
  Future<bool> updateCharterEntry(
    JournalEntry entry, {
    required String agentId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    final result = await _persistenceLogic.updateDbEntity(
      entry.copyWith(
        entryText: EntryText(plainText: trimmed),
        meta: await _persistenceLogic.updateMetadata(entry.meta),
      ),
      // The goal is not the entry's parent — the link points the other way —
      // so it is named here, or its page and its stale report never hear of
      // the edit.
      linkedId: goalIdForAgent(agentId),
    );
    return result ?? false;
  }

  /// Deletes the charter entry [entry] of [agentId]'s goal. The link stays,
  /// as links to deleted entries do; [charterEntries] skips the entry.
  Future<bool> deleteCharterEntry(
    JournalEntry entry, {
    required String agentId,
  }) => _deleteEntry(entry, goalId: goalIdForAgent(agentId));

  Future<bool> _deleteEntry(
    JournalEntry entry, {
    required String goalId,
  }) async {
    final result = await _persistenceLogic.updateDbEntity(
      entry.copyWith(
        meta: await _persistenceLogic.updateMetadata(
          entry.meta,
          deletedAt: clock.now(),
        ),
      ),
      linkedId: goalId,
    );
    return result ?? false;
  }

  /// Writes (or refreshes) the stable goal row for [agentId] and returns it.
  ///
  /// The row's id never changes across revisions, so links from its check-ins
  /// survive every change to the criteria — which is the reason the version
  /// history lives in separate snapshot rows rather than in this one.
  Future<GoalEntry?> upsertGoal({
    required String agentId,
    required String title,
    required String statement,
    required GoalCriterion criteria,
    required int specVersion,
    required String specVersionId,
    DateTime? startDate,
    DateTime? targetDate,
    String? rationale,
    String? categoryId,
  }) async {
    final data = GoalData(
      title: title,
      statement: statement,
      criteria: criteria,
      specVersion: specVersion,
      specVersionId: specVersionId,
      startDate: startDate,
      targetDate: targetDate,
      rationale: rationale,
    );
    return _upsert(
      uuidV5Input: goalEntryUuidV5Input(agentId),
      data: data,
      categoryId: categoryId,
      // The goal's own start is its position in time, so it sorts among the
      // user's entries where they would look for it rather than at whatever
      // moment the backfill happened to run.
      dateFrom: startDate,
    );
  }

  /// Writes the immutable snapshot of one spec version, if it is not already
  /// stored, and returns it.
  ///
  /// Never rewrites an existing snapshot: a version is immutable by
  /// definition, and a re-run that "refreshed" one would silently rewrite
  /// history that registers and reflections are pinned to.
  Future<GoalEntry?> ensureSpecSnapshot({
    required String goalId,
    required String specVersionId,
    required String title,
    required String statement,
    required GoalCriterion criteria,
    required int specVersion,
    required DateTime createdAt,
    DateTime? startDate,
    DateTime? targetDate,
    String? rationale,
    String? categoryId,
  }) async {
    final id = _metadataService.generateId(
      uuidV5Input: goalSpecSnapshotUuidV5Input(specVersionId),
    );
    final existing = await _journalDb.journalEntityById(id);
    if (existing is GoalEntry) return existing;

    return _upsert(
      uuidV5Input: goalSpecSnapshotUuidV5Input(specVersionId),
      data: GoalData(
        title: title,
        statement: statement,
        criteria: criteria,
        specVersion: specVersion,
        specVersionId: specVersionId,
        startDate: startDate,
        targetDate: targetDate,
        rationale: rationale,
        snapshotOf: goalId,
      ),
      categoryId: categoryId,
      // A snapshot is dated when the version was authored, so the history
      // reads in the order the goal actually changed.
      dateFrom: createdAt,
    );
  }

  Future<GoalEntry?> _upsert({
    required String uuidV5Input,
    required GoalData data,
    String? categoryId,
    DateTime? dateFrom,
  }) async {
    // Look the row up by its DERIVED id first. Creating metadata up front to
    // learn the id would commit a vector-clock counter every time an existing
    // goal was merely refreshed.
    final id = _metadataService.generateId(uuidV5Input: uuidV5Input);
    final existing = await _journalDb.journalEntityById(id);

    if (existing is GoalEntry) {
      final updatedMeta = await _persistenceLogic.updateMetadata(existing.meta);
      final updated = existing.copyWith(meta: updatedMeta, data: data);
      final saved = await _persistenceLogic.updateDbEntity(updated);
      return (saved ?? false) ? updated : null;
    }

    final meta = await _persistenceLogic.createMetadata(
      uuidV5Input: uuidV5Input,
      categoryId: categoryId,
      dateFrom: dateFrom,
      dateTo: dateFrom,
    );
    final created = JournalEntity.goal(meta: meta, data: data) as GoalEntry;
    final saved = await _persistenceLogic.createDbEntity(created);
    return (saved ?? false) ? created : null;
  }
}
