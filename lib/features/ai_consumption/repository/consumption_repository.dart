import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:lotti/features/ai_consumption/database/consumption_database.dart';
import 'package:lotti/features/ai_consumption/database/consumption_db_conversions.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_event.dart';
import 'package:lotti/features/ai_consumption/model/consumption_aggregation_models.dart';
import 'package:lotti/features/sync/vector_clock.dart';

/// Raw persistence for [AiConsumptionEvent]s, over [ConsumptionDatabase].
///
/// Writes are append-only and idempotent: [upsertEvent] uses `id` as the
/// conflict target, so a replayed sync event (same id) is a no-op rather than a
/// duplicate. The sync-aware write path (`ConsumptionSyncService`) wraps this to
/// stamp vector clocks and enqueue outbound messages; the inbound sync path
/// writes here directly to avoid an echo loop.
class ConsumptionRepository {
  ConsumptionRepository(this._db);

  final ConsumptionDatabase _db;

  /// Insert or replace an event by `id` (ON CONFLICT DO UPDATE).
  Future<void> upsertEvent(AiConsumptionEvent event) => _db
      .into(_db.consumptionEvents)
      .insertOnConflictUpdate(ConsumptionDbConversions.toCompanion(event));

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
          'SELECT created_at, category_id, input_tokens, output_tokens, '
          'cached_input_tokens, thoughts_tokens, total_tokens, credits, '
          'energy_kwh, carbon_g_co2, water_liters '
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
        ),
    ];
  }

  /// All events whose serialized clock is null — used to backfill vector clocks
  /// into the sync sequence log.
  Future<List<AiConsumptionEvent>> eventsWithNullVectorClock() async {
    final rows = await _db.getConsumptionEventsWithNullVectorClock().get();
    return rows.map(ConsumptionDbConversions.fromRow).toList();
  }

  /// Run [action] inside a database transaction.
  Future<T> runInTransaction<T>(Future<T> Function() action) =>
      _db.transaction(action);
}
