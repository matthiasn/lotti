import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
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
