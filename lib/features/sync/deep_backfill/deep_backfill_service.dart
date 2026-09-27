import 'dart:convert';

import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/deep_backfill/deep_backfill_diff.dart';
import 'package:lotti/features/sync/deep_backfill/deep_backfill_store.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:uuid/uuid.dart';

/// How far a round has got: the batches enqueued so far, per payload type.
class DeepBackfillProgress {
  const DeepBackfillProgress({
    required this.payloadType,
    required this.batches,
    required this.records,
    required this.total,
  });

  /// The payload type being advertised.
  final SyncSequencePayloadType payloadType;

  /// Batches enqueued so far in this round, across all types.
  final int batches;

  /// Records advertised so far in this round, across all types.
  final int records;

  /// Records the round advertises in all, counted when it started.
  final int total;
}

/// What one round advertised.
class DeepBackfillRoundSummary {
  const DeepBackfillRoundSummary({
    required this.roundId,
    required this.batches,
    required this.recordsByType,
  });

  final String roundId;
  final int batches;
  final Map<SyncSequencePayloadType, int> recordsByType;

  int get records => recordsByType.values.fold(0, (a, b) => a + b);
}

/// Deep backfill: a manual maintenance round that repairs history the
/// `(hostId, counter)` sequence log cannot see.
///
/// The protocol is model-checked in `specs/tla/DeepBackfill.tla`; each public
/// method is one of its actions:
///
/// - [runRound] is `StartRound` and `EmitBatch`: every record of every
///   registered store, tombstones included, advertised in batches whose id
///   ranges tile the whole keyspace.
/// - [handleInventory] is `Diff`: one range read per batch, then a request to
///   the advertiser for what this device lacks or holds older or concurrent,
///   and a push of what it holds newer, concurrent, or alone.
/// - [handleRequest] is `Answer`: the current row of each requested record,
///   through the ordinary sync message for its type.
///
/// Received versions go through each type's existing write decision; nothing
/// on the receive side is new.
class DeepBackfillService {
  DeepBackfillService({
    required SyncDatabase syncDatabase,
    required OutboxService outboxService,
    required VectorClockService vectorClockService,
    required DomainLogger loggingService,
    Iterable<DeepBackfillStore> stores = const [],
    DateTime Function()? now,
    String Function()? newRoundId,
    int? batchSize,
    Duration? requestExpiry,
  }) : _syncDb = syncDatabase,
       _outbox = outboxService,
       _vectorClock = vectorClockService,
       _logging = loggingService,
       _now = now ?? DateTime.now,
       _newRoundId = newRoundId ?? const Uuid().v4,
       _batchSize = batchSize ?? SyncTuning.deepBackfillBatchSize,
       _requestExpiry = requestExpiry ?? SyncTuning.deepBackfillRequestExpiry {
    stores.forEach(registerStore);
  }

  final SyncDatabase _syncDb;
  final OutboxService _outbox;
  final VectorClockService _vectorClock;
  final DomainLogger _logging;
  final DateTime Function() _now;
  final String Function() _newRoundId;
  final int _batchSize;
  final Duration _requestExpiry;
  final Map<SyncSequencePayloadType, DeepBackfillStore> _stores = {};

  /// Adds the store for its payload type, replacing an earlier one. Stores
  /// whose database is wired after sync starts (agent records) arrive here.
  void registerStore(DeepBackfillStore store) {
    _stores[store.payloadType] = store;
  }

  /// Removes the store for [payloadType], when its database goes away.
  void unregisterStore(SyncSequencePayloadType payloadType) {
    _stores.remove(payloadType);
  }

  /// The payload types a round advertises and a request can be answered for.
  Set<SyncSequencePayloadType> get payloadTypes => _stores.keys.toSet();

  /// Advertises every record of every store, in batches of the configured
  /// size. A batch's range starts where the previous one ended; the first is
  /// unbounded below, the last unbounded above, and a type without records
  /// still sends one empty batch covering everything, so a record only a
  /// peer holds always lies in some range it can push.
  Future<DeepBackfillRoundSummary> runRound({
    void Function(DeepBackfillProgress progress)? onProgress,
  }) async {
    final host = await _requireHost();
    final roundId = _newRoundId();
    var total = 0;
    for (final store in _stores.values) {
      total += await store.count();
    }
    final recordsByType = <SyncSequencePayloadType, int>{};
    var batches = 0;
    var records = 0;

    for (final store in _stores.values) {
      final type = store.payloadType;
      String? start;
      String? after;
      var index = 0;
      var typeRecords = 0;
      while (true) {
        // One row past the batch names where the next range starts.
        final page = await store.page(after: after, limit: _batchSize + 1);
        final rows = page.length > _batchSize
            ? page.sublist(0, _batchSize)
            : page;
        final end = page.length > _batchSize ? page[_batchSize].id : null;
        final conflicts = await store.openConflicts(start: start, end: end);

        // Throws: a batch that never reached the outbox leaves its range
        // uncompared, and the round must not report success.
        await _outbox.enqueueMessageOrThrow(
          SyncMessage.deepBackfillInventory(
            roundId: roundId,
            hostId: host,
            payloadType: type,
            batch: index,
            rangeStart: start,
            rangeEnd: end,
            records: [
              for (final row in rows)
                // A row without a clock cannot be ordered against anything;
                // it is left out rather than advertised as newest.
                if (row.clock != null)
                  DeepBackfillRecord(id: row.id, vectorClock: row.clock!),
            ],
            conflicts: [
              for (final MapEntry(key: id, value: clocks) in conflicts.entries)
                for (final clock in clocks)
                  DeepBackfillRecord(id: id, vectorClock: clock),
            ],
          ),
        );
        batches++;
        index++;
        records += rows.length;
        typeRecords += rows.length;
        onProgress?.call(
          DeepBackfillProgress(
            payloadType: type,
            batches: batches,
            records: records,
            // Writes during the round can outgrow the starting count.
            total: records > total ? records : total,
          ),
        );
        if (end == null) break;
        start = end;
        after = rows.last.id;
      }
      recordsByType[type] = typeRecords;
    }

    _logging.log(
      LogDomain.sync,
      'deepBackfill.round id=$roundId batches=$batches records=$records',
      subDomain: 'deepBackfill.round',
    );
    return DeepBackfillRoundSummary(
      roundId: roundId,
      batches: batches,
      recordsByType: recordsByType,
    );
  }

  /// Diffs one batch of a peer's inventory against this device's rows in the
  /// batch's range, then requests and pushes what the diff says.
  Future<void> handleInventory(SyncDeepBackfillInventory inventory) async {
    // Lists that were never loaded from their attachment would read as an
    // advertiser holding nothing in the range.
    if (inventory.attachmentEventId != null) return;
    final host = await _vectorClock.getHost();
    if (host == null || inventory.hostId == host) return;
    final store = _stores[inventory.payloadType];
    if (store == null) return;

    final start = inventory.rangeStart;
    final end = inventory.rangeEnd;
    final local = await store.range(start: start, end: end);
    final localConflicts = await store.openConflicts(start: start, end: end);
    final outstanding = await _settleOutstanding(
      advertiser: inventory.hostId,
      payloadType: inventory.payloadType,
      start: start,
      end: end,
      local: local,
      localConflicts: localConflicts,
    );

    final diff = diffDeepBackfillBatch(
      advertised: {
        for (final record in inventory.records) record.id: record.vectorClock,
      },
      advertisedConflicts: _groupById(inventory.conflicts),
      local: local,
      localConflicts: localConflicts,
      outstanding: outstanding,
    );

    // Pushes first: a request that cannot be queued rethrows, and must not
    // hold back what the advertiser is owed.
    if (diff.pushes.isNotEmpty) {
      await store.enqueueCurrent(
        diff.pushes,
        withMedia: diff.advertiserLacks,
      );
    }
    if (diff.requests.isNotEmpty) {
      await _request(inventory: inventory, host: host, diff: diff);
    }
    _logging.log(
      LogDomain.sync,
      'deepBackfill.diff from=${inventory.hostId} '
      'type=${inventory.payloadType.name} batch=${inventory.batch} '
      'advertised=${inventory.records.length} local=${local.length} '
      'requested=${diff.requests.length} pushed=${diff.pushes.length} '
      'outstanding=${outstanding.length} '
      'incomparable=${diff.incomparable.length}',
      subDomain: 'deepBackfill.diff',
    );
  }

  /// Answers a request addressed to this device with the current row of
  /// each record it names.
  Future<void> handleRequest(SyncDeepBackfillRequest request) async {
    if (request.attachmentEventId != null) return;
    final host = await _vectorClock.getHost();
    if (host == null || request.targetHostId != host) return;
    final store = _stores[request.payloadType];
    if (store == null) return;
    final ids = {for (final record in request.records) record.id};
    final withMedia = {
      for (final record in request.records)
        if (record.absent) record.id,
    };
    final sent = await store.enqueueCurrent(ids, withMedia: withMedia);
    _logging.log(
      LogDomain.sync,
      'deepBackfill.answer requester=${request.requesterId} '
      'type=${request.payloadType.name} requested=${ids.length} sent=$sent',
      subDomain: 'deepBackfill.answer',
    );
  }

  /// Drops the outstanding requests to [advertiser] in the range that the
  /// local state now covers, or that expired, and returns the ids still
  /// outstanding. Settling here, right before the diff consults them, gives
  /// the same answer as settling on every receive: the outstanding set only
  /// ever decides whether a record is requested again.
  Future<Set<String>> _settleOutstanding({
    required String advertiser,
    required SyncSequencePayloadType payloadType,
    required String? start,
    required String? end,
    required Map<String, VectorClock?> local,
    required Map<String, List<VectorClock>> localConflicts,
  }) async {
    final rows = await _syncDb.deepBackfillRequestsInRange(
      targetHostId: advertiser,
      payloadType: payloadType,
      start: start,
      end: end,
    );
    final expiredBefore = _now().subtract(_requestExpiry);
    final done = <String>{};
    final open = <String>{};
    for (final row in rows) {
      final asked = _decodeClocks(row.vectorClocks);
      final settled =
          asked == null ||
          row.requestedAt.isBefore(expiredBefore) ||
          deepBackfillRequestSettled(
            asked: asked,
            local: local[row.entryId],
            openConflicts: localConflicts[row.entryId] ?? const [],
          );
      (settled ? done : open).add(row.entryId);
    }
    if (done.isNotEmpty) {
      await _syncDb.removeDeepBackfillRequests(
        targetHostId: advertiser,
        payloadType: payloadType,
        entryIds: done,
      );
    }
    return open;
  }

  /// Records the requests as outstanding, then enqueues them. Recording
  /// first means a crash in between leaves a request recorded but unsent —
  /// held back until it expires — never a request sent twice.
  Future<void> _request({
    required SyncDeepBackfillInventory inventory,
    required String host,
    required DeepBackfillDiff diff,
  }) async {
    final requestedAt = _now();
    await _syncDb.recordDeepBackfillRequests([
      for (final MapEntry(key: id, value: clocks) in diff.requests.entries)
        DeepBackfillRequestsCompanion.insert(
          targetHostId: inventory.hostId,
          payloadType: inventory.payloadType.index,
          entryId: id,
          vectorClocks: jsonEncode([for (final c in clocks) c.toJson()]),
          requestedAt: requestedAt,
        ),
    ]);
    try {
      await _outbox.enqueueMessageOrThrow(
        SyncMessage.deepBackfillRequest(
          requesterId: host,
          targetHostId: inventory.hostId,
          payloadType: inventory.payloadType,
          records: [
            for (final id in diff.requests.keys)
              DeepBackfillRequestRecord(
                id: id,
                absent: diff.absentLocally.contains(id),
              ),
          ],
        ),
      );
    } catch (_) {
      // Nothing went out: forget the rows so the next round asks again.
      await _syncDb.removeDeepBackfillRequests(
        targetHostId: inventory.hostId,
        payloadType: inventory.payloadType,
        entryIds: diff.requests.keys.toSet(),
      );
      rethrow;
    }
  }

  Future<String> _requireHost() async {
    final host = await _vectorClock.getHost();
    if (host == null) {
      throw StateError("deep backfill needs this device's host id");
    }
    return host;
  }

  /// The clocks a request row asked for, or null when the row is unreadable
  /// (it is then dropped, and the record may be asked for again).
  static List<VectorClock>? _decodeClocks(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is! List) return null;
      return [
        for (final item in decoded)
          VectorClock.fromJson(item as Map<String, dynamic>),
      ];
    } on Object {
      return null;
    }
  }

  static Map<String, List<VectorClock>> _groupById(
    Iterable<DeepBackfillRecord> records,
  ) {
    final grouped = <String, List<VectorClock>>{};
    for (final record in records) {
      (grouped[record.id] ??= []).add(record.vectorClock);
    }
    return grouped;
  }
}
