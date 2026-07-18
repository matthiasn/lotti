import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:lotti/features/ai_consumption/database/attribution_db_conversions.dart';
import 'package:lotti/features/ai_consumption/database/consumption_database.dart'
    as db;
import 'package:lotti/features/ai_consumption/database/consumption_db_conversions.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_event.dart';
import 'package:lotti/features/ai_consumption/model/consumption_aggregation_models.dart';
import 'package:lotti/features/sync/vector_clock.dart';

/// Raw persistence for [AiConsumptionEvent]s, over [db.ConsumptionDatabase].
///
/// Writes are append-only and idempotent: [upsertEvent] uses `id` as the
/// conflict target, so a replayed sync event (same id) is a no-op rather than a
/// duplicate. The sync-aware write path (`ConsumptionSyncService`) wraps this to
/// stamp vector clocks and enqueue outbound messages; the inbound sync path
/// writes here directly to avoid an echo loop.
class ConsumptionRepository {
  ConsumptionRepository(this._db);

  final db.ConsumptionDatabase _db;

  /// Insert or replace an event by `id` (ON CONFLICT DO UPDATE).
  Future<void> upsertEvent(AiConsumptionEvent event) => _db.transaction(
    () async {
      final payload = event.payload;
      if (payload != null) {
        await _db
            .into(_db.aiInteractionPayloads)
            .insertOnConflictUpdate(
              AttributionDbConversions.payloadToCompanion(payload),
            );
      }
      final cost = event.cost;
      if (cost != null) {
        await _db
            .into(_db.aiInteractionCosts)
            .insertOnConflictUpdate(
              AttributionDbConversions.costToCompanion(cost),
            );
      }
      await _db
          .into(_db.consumptionEvents)
          .insertOnConflictUpdate(ConsumptionDbConversions.toCompanion(event));
    },
  );

  /// Idempotently projects one terminal attribution and its typed links.
  Future<void> upsertAttribution(AiWorkAttribution attribution) =>
      _db.transaction(() async {
        await _db
            .into(_db.aiWorkAttributions)
            .insertOnConflictUpdate(
              AttributionDbConversions.attributionToCompanion(attribution),
            );
        for (final link in attribution.links) {
          if (link.attributionId != attribution.id) {
            throw ArgumentError.value(
              link.attributionId,
              'link.attributionId',
              'must match attribution ${attribution.id}',
            );
          }
          await _db
              .into(_db.aiAttributionLinks)
              .insertOnConflictUpdate(
                AttributionDbConversions.linkToCompanion(link),
              );
        }
      });

  /// Projects a terminal output-carrier envelope idempotently.
  Future<void> projectTerminalEnvelope(
    AiTerminalAttributionEnvelope envelope,
  ) => upsertAttribution(envelope.attribution);

  /// Builds a local, replaceable partial projection from interaction evidence.
  ///
  /// This lets a peer explain an interaction even when the executor vanished
  /// before publishing the output carrier. A later terminal carrier replaces
  /// this projection idempotently with the authoritative final status/links.
  Future<void> projectRecoveryCapsule({
    required AiAttributionRecoveryCapsule capsule,
    required AiConsumptionEvent event,
  }) async {
    final existing = await getAttribution(capsule.attributionId);
    if (existing != null && existing.status != AiWorkStatus.partial) return;

    final links = <AiAttributionLink>[
      for (final output in capsule.intendedOutputs)
        AiAttributionLink(
          id:
              '${capsule.id}|output|${output.type.name}|${output.id}|'
              '${output.subId ?? ''}',
          attributionId: capsule.attributionId,
          role: AiAttributionLinkRole.output,
          artifact: output,
        ),
    ];
    await upsertAttribution(
      AiWorkAttribution(
        id: capsule.attributionId,
        workType: capsule.workType,
        status: AiWorkStatus.partial,
        initiator: capsule.initiator,
        trigger: capsule.trigger,
        executor: capsule.executor,
        privacyClassification: capsule.privacyClassification,
        startedAt: capsule.startedAt,
        completedAt: event.completedAt ?? event.createdAt,
        vectorClock: event.vectorClock,
        links: links,
        parentAttributionId: capsule.parentAttributionId,
        taskId: capsule.taskId,
        categoryId: capsule.categoryId,
        primaryOutput: capsule.intendedOutputs.firstOrNull,
        errorCode: 'terminal_carrier_missing',
      ),
    );
  }

  /// Fetch a terminal attribution by id.
  Future<AiWorkAttribution?> getAttribution(String id) async {
    final row = await (_db.select(
      _db.aiWorkAttributions,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    return row == null
        ? null
        : AttributionDbConversions.attributionFromRow(row);
  }

  /// Reverse lookup from a journal/agent artifact to its attribution.
  Future<AiWorkAttribution?> getAttributionForArtifact(
    AiArtifactReference artifact,
  ) async {
    final link =
        await (_db.select(_db.aiAttributionLinks)
              ..where(
                (table) =>
                    table.artifactType.equals(artifact.type.name) &
                    table.artifactId.equals(artifact.id) &
                    (artifact.subId == null
                        ? table.subId.isNull()
                        : table.subId.equals(artifact.subId!)),
              )
              ..limit(1))
            .getSingleOrNull();
    return link == null ? null : getAttribution(link.attributionId);
  }

  /// Ordered backend interactions used to produce one logical work item.
  Future<List<AiConsumptionEvent>> interactionsForAttribution(
    String attributionId,
  ) async {
    final rows =
        await (_db.select(_db.consumptionEvents)
              ..where((table) => table.attributionId.equals(attributionId))
              ..orderBy([
                (table) => OrderingTerm.asc(table.sequenceIndex),
                (table) => OrderingTerm.asc(table.createdAt),
                (table) => OrderingTerm.asc(table.id),
              ]))
            .get();
    return rows.map(ConsumptionDbConversions.fromRow).toList();
  }

  /// All append-only cost evidence for one interaction.
  Future<List<AiInteractionCost>> costsForInteraction(
    String interactionId,
  ) async {
    final rows =
        await (_db.select(_db.aiInteractionCosts)
              ..where((table) => table.interactionId.equals(interactionId))
              ..orderBy([
                (table) => OrderingTerm.asc(table.assessedAt),
                (table) => OrderingTerm.asc(table.id),
              ]))
            .get();
    return rows.map(AttributionDbConversions.costFromRow).toList();
  }

  /// All cost evidence attached to interactions in one logical work item.
  Future<List<AiInteractionCost>> costsForAttribution(
    String attributionId,
  ) async {
    final rows = await _db
        .customSelect(
          'SELECT c.serialized AS serialized '
          'FROM ai_interaction_costs c '
          'JOIN consumption_events e ON e.id = c.interaction_id '
          'WHERE e.attribution_id = ? '
          'ORDER BY c.assessed_at, c.id',
          variables: [Variable.withString(attributionId)],
          readsFrom: {_db.aiInteractionCosts, _db.consumptionEvents},
        )
        .get();
    return rows
        .map(
          (row) => AiInteractionCost.fromJson(
            jsonDecode(row.read<String>('serialized')) as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  /// Captured sync-safe payload for one interaction, if present.
  Future<AiInteractionPayload?> payloadForInteraction(
    String interactionId,
  ) async {
    final row =
        await (_db.select(
              _db.aiInteractionPayloads,
            )..where((table) => table.interactionId.equals(interactionId)))
            .getSingleOrNull();
    return row == null ? null : AttributionDbConversions.payloadFromRow(row);
  }

  /// Upsert local-only pending saga state.
  Future<void> upsertPendingAttribution(
    AiAttributionPendingSession pending,
  ) => _db
      .into(_db.pendingAiAttributions)
      .insertOnConflictUpdate(
        AttributionDbConversions.pendingToCompanion(pending),
      );

  Future<List<AiAttributionPendingSession>> pendingAttributions() async {
    final rows = await (_db.select(
      _db.pendingAiAttributions,
    )..orderBy([(table) => OrderingTerm.asc(table.startedAt)])).get();
    return rows.map(AttributionDbConversions.pendingFromRow).toList();
  }

  Future<AiAttributionPendingSession?> getPendingAttribution(String id) async {
    final row = await (_db.select(
      _db.pendingAiAttributions,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    return row == null ? null : AttributionDbConversions.pendingFromRow(row);
  }

  Future<void> deletePendingAttribution(String id) async {
    await (_db.delete(
      _db.pendingAiAttributions,
    )..where((row) => row.id.equals(id))).go();
  }

  /// Fetch a single event by [id], or null if absent.
  Future<AiConsumptionEvent?> getEvent(String id) async {
    final rows = await _db.getConsumptionEventById(id).get();
    if (rows.isEmpty) return null;
    return ConsumptionDbConversions.fromRow(rows.first);
  }

  /// The newest events with `start <= createdAt < end`, newest first, capped
  /// at [limit] — the per-call ledger read. Full rows (one page, bounded) are
  /// deserialized; ordering ties on `createdAt` break by `id` so pagination
  /// stays stable across identical timestamps.
  Future<List<AiConsumptionEvent>> newestEventsInRange({
    required DateTime start,
    required DateTime end,
    required int limit,
  }) async {
    final query = _db.select(_db.consumptionEvents)
      ..where(
        (tbl) =>
            tbl.createdAt.isBiggerOrEqualValue(start) &
            tbl.createdAt.isSmallerThanValue(end),
      )
      ..orderBy([
        (tbl) => OrderingTerm.desc(tbl.createdAt),
        (tbl) => OrderingTerm.desc(tbl.id),
      ])
      ..limit(limit);
    final rows = await query.get();
    return rows.map(ConsumptionDbConversions.fromRow).toList();
  }

  /// Read just the vector clock for [id] without deserializing the whole row —
  /// used by the inbound sync dominance check. Returns null when the row is
  /// absent or has no clock.
  Future<VectorClock?> getVectorClock(String id) async {
    final raw = await _db
        .getConsumptionEventVectorClockById(id)
        .getSingleOrNull();
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;
    return VectorClock.fromJson(decoded);
  }

  /// Sum every metric for [taskId] across the task's whole lifetime.
  Future<ConsumptionTotals> totalsForTask(String taskId) async {
    final row = await _db.sumConsumptionByTask(taskId).getSingle();
    return ConsumptionTotals(
      callCount: row.callCount,
      impactCallCount: row.impactCallCount,
      inputTokens: row.inputTokens,
      outputTokens: row.outputTokens,
      cachedInputTokens: row.cachedInputTokens,
      thoughtsTokens: row.thoughtsTokens,
      totalTokens: row.totalTokens,
      credits: row.credits,
      energyKwh: row.energyKwh,
      carbonGCo2: row.carbonGCo2,
      waterLiters: row.waterLiters,
    );
  }

  /// Slim projection of every call in `[start, end)` for time-bucketed
  /// per-category aggregation: only `created_at`, the denormalized
  /// `category_id`, and the metric columns — never the `serialized` blob.
  ///
  /// Guards the two traps the Insights query documents:
  /// - `created_at` is stored as Unix seconds (Drift default), so the range is
  ///   bound with `Variable<DateTime>` and read back with `read<DateTime>`;
  ///   `julianday()` on the epoch int would return NULL and drop every row.
  /// - `category_id` is denormalized on the row, so there is no `linked_entries`
  ///   join and therefore no fan-out double-counting — a call maps to exactly
  ///   one category (its snapshot at call time).
  Future<List<ConsumptionMetricRow>> metricRowsInRange({
    required DateTime start,
    required DateTime end,
  }) async {
    final rows = await _db
        .customSelect(
          'SELECT created_at, category_id, model_id, provider_model_id, '
          'input_tokens, output_tokens, cached_input_tokens, thoughts_tokens, '
          'total_tokens, credits, '
          'energy_kwh, carbon_g_co2, water_liters, renewable_percent, '
          'data_center '
          'FROM consumption_events '
          'WHERE created_at >= ? AND created_at < ?',
          variables: [Variable<DateTime>(start), Variable<DateTime>(end)],
          readsFrom: {_db.consumptionEvents},
        )
        .get();
    return [
      for (final row in rows)
        ConsumptionMetricRow(
          createdAt: row.read<DateTime>('created_at'),
          categoryId: row.read<String?>('category_id'),
          modelId: row.read<String?>('model_id'),
          providerModelId: row.read<String?>('provider_model_id'),
          metrics: ConsumptionMetrics(
            callCount: 1,
            inputTokens: row.read<int?>('input_tokens') ?? 0,
            outputTokens: row.read<int?>('output_tokens') ?? 0,
            cachedInputTokens: row.read<int?>('cached_input_tokens') ?? 0,
            thoughtsTokens: row.read<int?>('thoughts_tokens') ?? 0,
            totalTokens: row.read<int?>('total_tokens') ?? 0,
            credits: row.read<double?>('credits') ?? 0,
            energyKwh: row.read<double?>('energy_kwh') ?? 0,
            carbonGCo2: row.read<double?>('carbon_g_co2') ?? 0,
            waterLiters: row.read<double?>('water_liters') ?? 0,
          ),
          renewablePercent: row.read<double?>('renewable_percent'),
          dataCenter: row.read<String?>('data_center'),
        ),
    ];
  }

  /// All events whose serialized clock is null — used to backfill vector clocks
  /// into the sync sequence log.
  Future<List<AiConsumptionEvent>> eventsWithNullVectorClock() async {
    final rows = await _db.getConsumptionEventsWithNullVectorClock().get();
    return rows.map(ConsumptionDbConversions.fromRow).toList();
  }

  /// Legacy interactions that predate the top-level attribution id.
  Future<List<AiConsumptionEvent>> eventsWithoutAttribution() async {
    final rows = await (_db.select(
      _db.consumptionEvents,
    )..where((table) => table.attributionId.isNull())).get();
    return rows.map(ConsumptionDbConversions.fromRow).toList();
  }

  /// Run [action] inside a database transaction.
  Future<T> runInTransaction<T>(Future<T> Function() action) =>
      _db.transaction(action);
}
