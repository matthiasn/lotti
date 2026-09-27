import 'package:drift/drift.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_db_conversions.dart';
import 'package:lotti/features/agents/database/agent_repo_internals.dart';
import 'package:lotti/features/agents/database/agent_repository.dart'
    show AgentRepository;
import 'package:lotti/features/agents/database/agent_repository_exception.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart' as model;
import 'package:lotti/features/agents/model/agent_link.dart'
    show AgentLinkSelection;
import 'package:lotti/features/agents/model/agent_link_slot.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;

/// Link CRUD, wake-run log, saga log, and hard-delete operations for
/// [AgentRepository]. Collaborator extracted from the former `_AgentRepoLinks`
/// mixin; the repository keeps thin delegators so mocks keep intercepting.
class AgentRepoLinks {
  AgentRepoLinks(this._db, this._domainLogger);

  final AgentDatabase _db;
  final DomainLogger? _domainLogger;

  /// Writes [link], locally made or received.
  ///
  /// A soul assignment the seeding made
  /// ([seededSoulAssignmentLinkId]) yields to every other assignment of its
  /// template (ADR 0100). A live seed that arrives where the template has
  /// another assignment row — live or removed, for instance one an older
  /// build made under a random id and the user then removed or replaced — is
  /// not stored; and any other assignment row that is written retires a live
  /// seed of the same template, stamping its removal at [agentSeedInstant]
  /// so every device that retires it stores the same row. Without this, a
  /// device that seeded afresh would put the default soul back over the
  /// user's choice on a device that made that choice before the seed had a
  /// fixed id.
  ///
  /// The seed is settled first, so the slot ranking [_upsertLinkRow] runs
  /// next (ADR 0099) never sees a live seed beside another assignment.
  Future<void> upsertLink(model.AgentLink link) async {
    if (AgentDbConversions.linkType(link) != AgentLinkTypes.soulAssignment) {
      return _upsertLinkRow(link);
    }
    await _db.transaction(() async {
      final seedId = seededSoulAssignmentLinkId(link.fromId);
      if (link.id != seedId) {
        await _retireSeededSoulAssignment(link.fromId, seedId);
      } else if (link.deletedAt == null &&
          await _hasSoulAssignmentOtherThan(link.fromId, seedId)) {
        return;
      }
      await _upsertLinkRow(link);
    });
  }

  Future<bool> _hasSoulAssignmentOtherThan(String fromId, String id) async {
    final row = await _db
        .customSelect(
          'SELECT 1 FROM agent_links '
          'INDEXED BY idx_agent_links_from '
          "WHERE from_id = ? AND type = 'soul_assignment' AND id != ? "
          'LIMIT 1',
          variables: [Variable.withString(fromId), Variable.withString(id)],
          readsFrom: {_db.agentLinks},
        )
        .getSingleOrNull();
    return row != null;
  }

  Future<void> _retireSeededSoulAssignment(String fromId, String seedId) async {
    final iso = agentSeedInstant.toIso8601String();
    final seconds = agentSeedInstant.millisecondsSinceEpoch ~/ 1000;
    await _db.customStatement(
      'UPDATE agent_links '
      'SET deleted_at = ?, updated_at = ?, '
      '    serialized = json_set(serialized, '
      r"      '$.deletedAt', ?, "
      r"      '$.updatedAt', ?) "
      'WHERE id = ? AND from_id = ? AND deleted_at IS NULL',
      [seconds, seconds, iso, iso, seedId, fromId],
    );
  }

  /// Persist [link] under its id.
  ///
  /// A link that fills an [AgentLinkSlot] — a template's soul or improver —
  /// is stored exactly as it arrived, like any other, and then the slot is
  /// re-ranked: of its live links, only the one [AgentLinkSelection] ranks
  /// first stays visible to reads (`deleted_at IS NULL`); the others keep
  /// their live serialized version but get the SQL `deleted_at` column set,
  /// which hides them without deleting them. Nothing about the slot is
  /// written as a new version, so every replica that holds the same versions
  /// shows the same assignment whichever order they arrived in (ADR 0099,
  /// `specs/tla/AgentLinks.tla`).
  ///
  /// Before ADR 0099 a live assignment tombstoned the slot's other live rows
  /// in place, with no clock and no sync message, and hard-deleted a row with
  /// the same `(from_id, to_id, type)`. Two devices that reassigned one slot
  /// concurrently each kept the other's link: the assignments swapped.
  Future<void> _upsertLinkRow(model.AgentLink link) async {
    final slot = AgentLinkSlot.of(link);
    if (slot == null) {
      await _db
          .into(_db.agentLinks)
          .insertOnConflictUpdate(AgentDbConversions.toLinkCompanion(link));
      return;
    }
    await _db.transaction(() => _upsertSlotLink(link, slot));
  }

  Future<void> _upsertSlotLink(
    model.AgentLink link,
    AgentLinkSlot slot,
  ) async {
    final others = [
      for (final row in await _slotRows(slot))
        if (row.id != link.id)
          (row: row, link: AgentDbConversions.fromLinkRow(row)),
    ];
    final contenders = [
      for (final other in others)
        if (other.link.deletedAt == null) other.link,
      if (link.deletedAt == null) link,
    ];
    final winnerId = contenders.isEmpty ? null : contenders.selectPrimary().id;

    // Hide the losers first: the partial unique index on the slot admits one
    // visible row, and the incoming link may be the new winner.
    for (final other in others) {
      if (other.link.deletedAt == null &&
          other.link.id != winnerId &&
          other.row.deletedAt == null) {
        await _setHidden(other.row.id, hidden: true);
      }
    }

    final companion = AgentDbConversions.toLinkCompanion(link);
    await _db
        .into(_db.agentLinks)
        .insertOnConflictUpdate(
          link.deletedAt == null && link.id != winnerId
              ? companion.copyWith(deletedAt: Value(link.updatedAt))
              : companion,
        );

    for (final other in others) {
      if (other.link.id == winnerId && other.row.deletedAt != null) {
        await _setHidden(other.row.id, hidden: false);
      }
    }
  }

  /// Every row stored in [slot], tombstones and hidden links included.
  Future<List<AgentLink>> _slotRows(AgentLinkSlot slot) {
    final key = slot.keyedByFromId ? 'from_id' : 'to_id';
    return _db
        .customSelect(
          'SELECT * FROM agent_links WHERE type = ? AND $key = ?',
          variables: [
            Variable.withString(slot.type),
            Variable.withString(slot.keyId),
          ],
          readsFrom: {_db.agentLinks},
        )
        .asyncMap(_db.agentLinks.mapFromRow)
        .get();
  }

  /// Shows or hides a live slot link from reads. Only the SQL `deleted_at`
  /// column changes: `serialized` keeps the version as it was written, which
  /// is what sync sends on and what the slot ranks.
  Future<void> _setHidden(String id, {required bool hidden}) {
    return _db.customStatement(
      hidden
          ? 'UPDATE agent_links SET deleted_at = updated_at WHERE id = ?'
          : 'UPDATE agent_links SET deleted_at = NULL WHERE id = ?',
      [id],
    );
  }

  /// Every version stored in [slot], as written: the visible link, the live
  /// links the slot ranks below it, and tombstones.
  ///
  /// A writer that reassigns or clears the slot removes every live link here,
  /// not only the visible one, so a hidden assignment does not surface when
  /// the one above it is removed; and it stamps a new assignment's
  /// `createdAt` above all of them.
  Future<List<model.AgentLink>> getSlotLinks(AgentLinkSlot slot) async {
    final rows = await _slotRows(slot);
    return rows.map(AgentDbConversions.fromLinkRow).toList();
  }

  /// Fetch non-deleted links originating from [fromId], optionally filtered
  /// by [type] (the string stored in the `agent_links.type` column, e.g.
  /// `'agent_state'`).
  Future<List<model.AgentLink>> getLinksFrom(
    String fromId, {
    String? type,
  }) async {
    final List<AgentLink> rows;
    if (type != null) {
      rows = await _db
          .customSelect(
            'SELECT * FROM agent_links '
            'INDEXED BY idx_agent_links_active_from_type_to '
            'WHERE from_id = ? AND type = ? AND deleted_at IS NULL',
            variables: [
              Variable.withString(fromId),
              Variable.withString(type),
            ],
            readsFrom: {_db.agentLinks},
          )
          .asyncMap(_db.agentLinks.mapFromRow)
          .get();
    } else {
      rows = await _db.getAgentLinksByFromId(fromId).get();
    }
    return rows.map(AgentDbConversions.fromLinkRow).toList();
  }

  /// Whether any link of [type] originates from [fromId], **a removed one
  /// included**: a seeding pass that asks whether the user has ever had one
  /// must not read a removal as never having had it (ADR 0100).
  Future<bool> hasAnyLinkFrom(String fromId, {required String type}) async {
    final row = await _db
        .customSelect(
          'SELECT 1 FROM agent_links '
          'INDEXED BY idx_agent_links_from '
          'WHERE from_id = ? AND type = ? LIMIT 1',
          variables: [Variable.withString(fromId), Variable.withString(type)],
          readsFrom: {_db.agentLinks},
        )
        .getSingleOrNull();
    return row != null;
  }

  /// Fetch non-deleted links pointing to [toId], optionally filtered by
  /// [type].
  Future<List<model.AgentLink>> getLinksTo(
    String toId, {
    String? type,
  }) async {
    final List<AgentLink> rows;
    if (type != null) {
      rows = await _db
          .customSelect(
            'SELECT * FROM agent_links '
            'INDEXED BY idx_agent_links_active_to_type '
            'WHERE to_id = ? AND type = ? AND deleted_at IS NULL',
            variables: [
              Variable.withString(toId),
              Variable.withString(type),
            ],
            readsFrom: {_db.agentLinks},
          )
          .asyncMap(_db.agentLinks.mapFromRow)
          .get();
    } else {
      rows = await _db.getAgentLinksByToId(toId).get();
    }
    return rows.map(AgentDbConversions.fromLinkRow).toList();
  }

  /// Every link of [type] from or to any of [ids], removed ones included: a
  /// removal is a write, and a reader comparing vector clocks must see it.
  Future<List<model.AgentLink>> getLinksTouchingIncludingDeleted(
    Iterable<String> ids, {
    required String type,
  }) async {
    final result = <model.AgentLink>[];
    for (final chunk in sqliteInClauseChunks(ids.toSet().toList())) {
      final placeholders = List.filled(chunk.length, '?').join(', ');
      final rows = await _db
          .customSelect(
            'SELECT * FROM agent_links WHERE type = ? '
            'AND (from_id IN ($placeholders) OR to_id IN ($placeholders))',
            variables: [
              Variable.withString(type),
              ...chunk.map(Variable.withString),
              ...chunk.map(Variable.withString),
            ],
            readsFrom: {_db.agentLinks},
          )
          .get();
      for (final row in rows) {
        result.add(
          AgentDbConversions.fromLinkRow(await _db.agentLinks.mapFromRow(row)),
        );
      }
    }
    return result;
  }

  /// Batch-fetch non-deleted links pointing to any of [toIds] with a given
  /// [type], returned as a map from `toId` → links.
  ///
  /// Issues chunked `IN (...)` queries instead of N separate lookups. IDs not
  /// present in the result map have no matching links.
  Future<Map<String, List<model.AgentLink>>> getLinksToMultiple(
    List<String> toIds, {
    required String type,
  }) async {
    final result = <String, List<model.AgentLink>>{};
    for (final chunk in sqliteInClauseChunks(toIds)) {
      final placeholders = List.filled(chunk.length, '?').join(', ');
      final rows = await _db
          .customSelect(
            'SELECT * FROM agent_links '
            'WHERE to_id IN ($placeholders) '
            'AND type = ? AND deleted_at IS NULL',
            variables: [
              ...chunk.map(Variable.withString),
              Variable.withString(type),
            ],
            readsFrom: {_db.agentLinks},
          )
          .get();

      for (final row in rows) {
        final link = AgentDbConversions.fromLinkRow(
          await _db.agentLinks.mapFromRow(row),
        );
        (result[link.toId] ??= []).add(link);
      }
    }
    return result;
  }

  /// Batch-fetch non-deleted links originating from any of [fromIds] with a
  /// given [type], returned as a map from `fromId` → links.
  ///
  /// This is the `from_id` companion to [getLinksToMultiple]. It is used by
  /// list hydration paths that need template → soul assignment links without
  /// issuing one `SELECT * FROM agent_links WHERE from_id = ? ...` per row.
  Future<Map<String, List<model.AgentLink>>> getLinksFromMultiple(
    List<String> fromIds, {
    required String type,
  }) async {
    final result = <String, List<model.AgentLink>>{};
    for (final chunk in sqliteInClauseChunks(fromIds)) {
      final placeholders = List.filled(chunk.length, '?').join(', ');
      final rows = await _db
          .customSelect(
            'SELECT * FROM agent_links '
            'WHERE from_id IN ($placeholders) '
            'AND type = ? AND deleted_at IS NULL',
            variables: [
              ...chunk.map(Variable.withString),
              Variable.withString(type),
            ],
            readsFrom: {_db.agentLinks},
          )
          .get();

      for (final row in rows) {
        final link = AgentDbConversions.fromLinkRow(
          await _db.agentLinks.mapFromRow(row),
        );
        (result[link.fromId] ??= []).add(link);
      }
    }
    return result;
  }

  /// Fetch agent links (including soft-deleted) whose serialized
  /// `vectorClock` is null, ordered by `created_at` ascending.
  ///
  /// Used by the backfill maintenance step to stamp vector clocks on links
  /// created before the clock-stamping fix. Includes tombstones so that
  /// deletes are also propagated to other devices.
  Future<List<model.AgentLink>> getLinksWithNullVectorClock() async {
    final rows = await _db.getAgentLinksWithNullVectorClock().get();
    return rows.map(AgentDbConversions.fromLinkRow).toList();
  }

  /// Returns the set of journal task IDs that have a non-deleted `agent_task`
  /// link. Used by the task filter to distinguish assigned vs unassigned tasks.
  Future<Set<String>> getTaskIdsWithAgentLink() async {
    final rows = await _db.getAgentTaskLinkToIds().get();
    return rows.toSet();
  }

  /// Count agent links (including soft-deleted) whose serialized
  /// `vectorClock` is null.
  Future<int> countLinksWithNullVectorClock() {
    return _db.countAgentLinksWithNullVectorClock().getSingle();
  }

  /// Fetches agent links (including soft-deleted) updated in the
  /// half-open interval [start, end), paginated.
  Future<List<model.AgentLink>> getLinksInInterval({
    required DateTime start,
    required DateTime end,
    required int limit,
    required int offset,
  }) async {
    final rows = await _db
        .getAgentLinksInInterval(start, end, limit, offset)
        .get();
    return rows.map(AgentDbConversions.fromLinkRow).toList();
  }

  /// Fetches undecoded agent-link rows for item-isolated historical sync.
  ///
  /// The caller can decode each row inside its own retry boundary instead of
  /// losing the rest of a page when one serialized payload is malformed.
  Future<List<AgentLink>> getLinkRowsInInterval({
    required DateTime start,
    required DateTime end,
    required int limit,
    required int offset,
  }) {
    return _db.getAgentLinksInInterval(start, end, limit, offset).get();
  }

  /// Counts agent links (including soft-deleted) updated in the
  /// half-open interval [start, end).
  Future<int> countLinksInInterval({
    required DateTime start,
    required DateTime end,
  }) {
    return _db.countAgentLinksInInterval(start, end).getSingle();
  }

  // ── Wake run log ───────────────────────────────────────────────────────────

  /// Insert a new [WakeRunLogData] entry.
  ///
  /// Throws [DuplicateInsertException] if the run key already exists.
  Future<void> insertWakeRun({required WakeRunLogData entry}) async {
    try {
      await _db.into(_db.wakeRunLog).insert(entry.toCompanion(true));
    } on SqliteException catch (e, st) {
      if (e.resultCode == 19) {
        _domainLogger?.error(
          LogDomain.agentRuntime,
          e,
          message:
              'wake_run_log unique constraint violated for '
              'runKey=${DomainLogger.sanitizeId(entry.runKey)}',
          stackTrace: st,
          subDomain: 'AgentRepository.insertWakeRun',
        );
        throw DuplicateInsertException('wake_run_log', entry.runKey);
      }
      rethrow;
    }
  }

  /// Update the [status], and optionally [startedAt], [completedAt] and
  /// [errorMessage], for the wake run identified by [runKey].
  ///
  /// Fire-and-forget on a missing [runKey]: the update silently writes zero
  /// rows. This is deliberate — status transitions are emitted from runtime
  /// paths (timeouts, error handlers, shutdown hooks) that may race run-log
  /// cleanup, and a late transition for a vanished run must not crash the
  /// caller. Contrast with `updateWakeRunTemplate`, which throws
  /// [StateError] because template resolution happens once, early, where a
  /// missing row indicates a real bug.
  Future<void> updateWakeRunStatus(
    String runKey,
    String status, {
    DateTime? startedAt,
    DateTime? completedAt,
    String? errorMessage,
  }) async {
    await (_db.update(
      _db.wakeRunLog,
    )..where((t) => t.runKey.equals(runKey))).write(
      WakeRunLogCompanion(
        status: Value(status),
        startedAt: startedAt != null ? Value(startedAt) : const Value.absent(),
        completedAt: completedAt != null
            ? Value(completedAt)
            : const Value.absent(),
        errorMessage: errorMessage != null
            ? Value(errorMessage)
            : const Value.absent(),
      ),
    );
  }

  /// Fetch wake-run entries for a specific template, ordered by
  /// `created_at DESC`, capped at [limit] rows.
  Future<List<WakeRunLogData>> getWakeRunsForTemplate(
    String templateId, {
    int limit = 500,
  }) async {
    return _db.getWakeRunsByTemplateId(templateId, limit).get();
  }

  /// Count all wake runs for [templateId] with no presentation cap.
  Future<int> countWakeRunsForTemplate(String templateId) {
    return _db.countWakeRunsByTemplateId(templateId).getSingle();
  }

  /// Aggregate wake-run metrics (success/failure counts, duration stats,
  /// first/last timestamps) for [templateId] in a single SQL query.
  Future<AggregateWakeRunMetricsByTemplateIdResult> aggregateWakeRunMetrics(
    String templateId,
  ) {
    return _db.aggregateWakeRunMetricsByTemplateId(templateId).getSingle();
  }

  /// Sum token usage (input, output, thoughts) for all instances of
  /// [templateId] in a single SQL query.
  Future<SumTokenUsageByTemplateResult> sumTokenUsageForTemplate(
    String templateId,
  ) {
    return _db.sumTokenUsageByTemplate(templateId).getSingle();
  }

  /// Sum token usage for all instances of [templateId] created on or
  /// after [since].
  Future<SumTokenUsageByTemplateSinceResult> sumTokenUsageForTemplateSince(
    String templateId, {
    required DateTime since,
  }) {
    return _db.sumTokenUsageByTemplateSince(templateId, since).getSingle();
  }

  /// Fetch wake runs for [templateId] within the inclusive window.
  Future<List<WakeRunLogData>> getWakeRunsForTemplateInWindow(
    String templateId, {
    required DateTime since,
    required DateTime until,
  }) {
    return _db.getWakeRunsByTemplateInWindow(templateId, since, until).get();
  }

  /// Fetch the most recent wake-run entry for [agentId] and [threadId],
  /// or `null`.
  Future<WakeRunLogData?> getWakeRunByThreadId(
    String agentId,
    String threadId,
  ) async {
    final rows = await _db.getWakeRunByThreadId(agentId, threadId).get();
    if (rows.isEmpty) return null;
    return rows.first;
  }

  /// Fetch token usage records for [agentId], ordered most-recent first.
  ///
  /// Returns deserialized `WakeTokenUsageEntity` records from the
  /// `agent_entities` table.
  Future<List<WakeTokenUsageEntity>> getTokenUsageForAgent(
    String agentId, {
    int limit = 500,
  }) async {
    final rows = await _db.getTokenUsageByAgentId(agentId, limit).get();
    return rows
        .map(AgentDbConversions.fromEntityRow)
        .whereType<WakeTokenUsageEntity>()
        .toList();
  }

  /// Fetch token usage records for all instances of [templateId].
  ///
  /// Uses a SQL JOIN via `template_assignment` links — same pattern as
  /// `getRecentReportsByTemplate`.
  Future<List<WakeTokenUsageEntity>> getTokenUsageForTemplate(
    String templateId, {
    int limit = 10000,
  }) async {
    final rows = await _db.getTokenUsageByTemplateId(templateId, limit).get();
    return rows
        .map(AgentDbConversions.fromEntityRow)
        .whereType<WakeTokenUsageEntity>()
        .toList();
  }

  /// Mark any wake runs still in `running` status as `abandoned`.
  ///
  /// Called on startup to clean up runs left behind by a hot restart or crash.
  /// Returns the number of rows updated.
  Future<int> abandonOrphanedWakeRuns() async {
    return (_db.update(_db.wakeRunLog)..where(
          (t) => t.status.equals(WakeRunStatus.running.name),
        ))
        .write(
          WakeRunLogCompanion(
            status: Value(WakeRunStatus.abandoned.name),
            errorMessage: const Value(
              'Marked as abandoned on startup (orphaned run)',
            ),
          ),
        );
  }

  // ── Hard delete ─────────────────────────────────────────────────────────

  /// Permanently delete **all** data for [agentId]: entities, links, saga ops,
  /// and wake-run log entries.
  ///
  /// This is irreversible. Only call for agents whose lifecycle is
  /// [AgentLifecycle.destroyed].
  /// Returns the entity and link ids that were removed, so the caller can
  /// reclaim their JSON sidecars — the database rows are only half of what a
  /// synced agent leaves behind.
  Future<({List<String> entityIds, List<String> linkIds})> hardDeleteAgent(
    String agentId,
  ) async {
    return _db.transaction(() async {
      // Read the ids inside the transaction, before the deletes that make
      // them unrecoverable.
      final entityIds = [
        for (final row
            in await _db
                .customSelect(
                  'SELECT id FROM agent_entities WHERE agent_id = ?1',
                  variables: [Variable<String>(agentId)],
                  readsFrom: {_db.agentEntities},
                )
                .get())
          row.read<String>('id'),
      ];
      // Mirrors `deleteAgentLinks` exactly. A link between two of the agent's
      // own entities — `messagePrev`, `messagePayload` — has neither endpoint
      // equal to the agent id, so a narrower select would let those rows be
      // deleted while their sidecars were never reported and so never
      // reclaimed.
      final linkIds = [
        for (final row
            in await _db
                .customSelect(
                  'SELECT id FROM agent_links WHERE from_id = ?1 OR to_id = ?1 '
                  'OR from_id IN (SELECT id FROM agent_entities '
                  'WHERE agent_id = ?1) '
                  'OR to_id IN (SELECT id FROM agent_entities '
                  'WHERE agent_id = ?1)',
                  variables: [Variable<String>(agentId)],
                  readsFrom: {_db.agentLinks, _db.agentEntities},
                )
                .get())
          row.read<String>('id'),
      ];
      // Saga ops reference wake_run_log via run_key, so delete them first.
      await _db.deleteAgentSagaOps(agentId);
      await _db.deleteAgentWakeRuns(agentId);
      await _db.deleteAgentLinks(agentId);
      await _db.deleteAgentEntities(agentId);
      return (entityIds: entityIds, linkIds: linkIds);
    });
  }
}
