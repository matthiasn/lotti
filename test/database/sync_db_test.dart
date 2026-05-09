// ignore_for_file: avoid_redundant_argument_values
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:glados/glados.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';

OutboxCompanion _buildOutbox({
  required OutboxStatus status,
  required DateTime createdAt,
  int retries = 0,
  String subject = 'subject',
  String message = '{}',
  String? filePath,
}) {
  return OutboxCompanion(
    status: Value(status.index),
    subject: Value(subject),
    message: Value(message),
    createdAt: Value(createdAt),
    updatedAt: Value(createdAt),
    retries: Value(retries),
    filePath: filePath == null
        ? const Value.absent()
        : Value<String?>(filePath),
  );
}

enum _GeneratedOutboxStatus {
  pending,
  expiredSending,
  activeSending,
  sent,
  error,
}

class _OutboxClaimRowSpec {
  const _OutboxClaimRowSpec({
    required this.createdMinute,
    required this.hasMedia,
    required this.status,
  });

  final int createdMinute;
  final bool hasMedia;
  final _GeneratedOutboxStatus status;

  DateTime createdAt(DateTime base) =>
      base.add(Duration(minutes: createdMinute));

  OutboxStatus get dbStatus => switch (status) {
    _GeneratedOutboxStatus.pending => OutboxStatus.pending,
    _GeneratedOutboxStatus.expiredSending => OutboxStatus.sending,
    _GeneratedOutboxStatus.activeSending => OutboxStatus.sending,
    _GeneratedOutboxStatus.sent => OutboxStatus.sent,
    _GeneratedOutboxStatus.error => OutboxStatus.error,
  };

  DateTime updatedAt(DateTime base, DateTime now) => switch (status) {
    _GeneratedOutboxStatus.expiredSending => now.subtract(
      const Duration(minutes: 10),
    ),
    _GeneratedOutboxStatus.activeSending => now,
    _ => createdAt(base),
  };
}

class _OutboxClaimScenario {
  const _OutboxClaimScenario({
    required this.maxSize,
    required this.rows,
  });

  final int maxSize;
  final List<_OutboxClaimRowSpec> rows;
}

/// Position of a row's `updated_at` relative to the prune cutoff.
/// `pruneSentOutboxItemsChunked` deletes rows where
/// `updated_at < cutoff`, so `atCutoff` rows are intentionally kept —
/// the strict-less-than is the bit the property test exercises.
enum _GeneratedOutboxAge { fresh, atCutoff, old }

class _PruneRowSpec {
  const _PruneRowSpec({
    required this.status,
    required this.age,
  });

  final _GeneratedOutboxStatus status;
  final _GeneratedOutboxAge age;

  /// Only `(sent, old)` rows are eligible for pruning. Live state
  /// (pending / sending) is never touched regardless of age, error
  /// rows are forensic and kept forever, fresh/atCutoff sent rows are
  /// inside the retention window.
  bool isPrunable({required Duration retention, required DateTime now}) {
    return status == _GeneratedOutboxStatus.sent &&
        age == _GeneratedOutboxAge.old;
  }

  /// `expiredSending` and `activeSending` both map to the
  /// `OutboxStatus.sending` literal in the table — the prune predicate
  /// only inspects `status` and `updated_at`, so this collapse loses no
  /// information.
  OutboxStatus get dbStatus => switch (status) {
    _GeneratedOutboxStatus.pending => OutboxStatus.pending,
    _GeneratedOutboxStatus.expiredSending => OutboxStatus.sending,
    _GeneratedOutboxStatus.activeSending => OutboxStatus.sending,
    _GeneratedOutboxStatus.sent => OutboxStatus.sent,
    _GeneratedOutboxStatus.error => OutboxStatus.error,
  };

  DateTime updatedAtValue({
    required Duration retention,
    required DateTime now,
  }) {
    final cutoff = now.subtract(retention);
    return switch (age) {
      _GeneratedOutboxAge.fresh => now.subtract(const Duration(hours: 1)),
      _GeneratedOutboxAge.atCutoff => cutoff,
      _GeneratedOutboxAge.old => cutoff.subtract(const Duration(days: 1)),
    };
  }

  @override
  String toString() => '_PruneRowSpec(status: $status, age: $age)';
}

class _PruneScenario {
  const _PruneScenario({
    required this.rows,
    required this.chunkSize,
    required this.retentionDays,
  });

  static final now = DateTime(2026, 5, 9, 12);

  final List<_PruneRowSpec> rows;
  final int chunkSize;
  final int retentionDays;

  Duration get retention => Duration(days: retentionDays);

  int get expectedDeleted => rows
      .where((row) => row.isPrunable(retention: retention, now: now))
      .length;

  /// `pruneSentOutboxItemsChunked` calls `onProgress` exactly once per
  /// loop iteration — including the terminating pass whose chunk
  /// returns `< chunkSize`. So the number of emissions is
  /// `(deleted ~/ chunkSize) + 1`, and emission `i` carries
  /// `min((i + 1) * chunkSize, deleted)` as the running total.
  List<int> get expectedProgress {
    final emissions = (expectedDeleted ~/ chunkSize) + 1;
    return [
      for (var i = 0; i < emissions; i++)
        if ((i + 1) * chunkSize < expectedDeleted)
          (i + 1) * chunkSize
        else
          expectedDeleted,
    ];
  }

  @override
  String toString() =>
      '_PruneScenario('
      'rows: $rows, '
      'chunkSize: $chunkSize, '
      'retentionDays: $retentionDays'
      ')';
}

enum _GeneratedSequenceLifecycleOperation {
  resetKnown,
  resetAll,
  retireExhausted,
  retireAgedOut,
}

enum _GeneratedSequenceLifecycleStatus {
  absent,
  received,
  missing,
  requested,
  backfilled,
  deleted,
  unresolvable,
}

enum _GeneratedRequestTimestamp { absent, fresh, atCutoff, old }

enum _GeneratedUpdatedTimestamp { fresh, atCutoff, old }

class _SequenceLifecycleRowSpec {
  const _SequenceLifecycleRowSpec({
    required this.status,
    required this.payloadType,
    required this.hasEntryId,
    required this.requestCount,
    required this.lastRequestedAt,
    required this.updatedAt,
  });

  final _GeneratedSequenceLifecycleStatus status;
  final SyncSequencePayloadType payloadType;
  final bool hasEntryId;
  final int requestCount;
  final _GeneratedRequestTimestamp lastRequestedAt;
  final _GeneratedUpdatedTimestamp updatedAt;

  bool get isStored => status != _GeneratedSequenceLifecycleStatus.absent;

  bool get isMissingOrRequested =>
      status == _GeneratedSequenceLifecycleStatus.missing ||
      status == _GeneratedSequenceLifecycleStatus.requested;

  bool get isResolvedWatermark =>
      status == _GeneratedSequenceLifecycleStatus.received ||
      status == _GeneratedSequenceLifecycleStatus.backfilled ||
      status == _GeneratedSequenceLifecycleStatus.deleted ||
      status == _GeneratedSequenceLifecycleStatus.unresolvable;

  SyncSequenceStatus get syncStatus {
    return switch (status) {
      _GeneratedSequenceLifecycleStatus.received => SyncSequenceStatus.received,
      _GeneratedSequenceLifecycleStatus.missing => SyncSequenceStatus.missing,
      _GeneratedSequenceLifecycleStatus.requested =>
        SyncSequenceStatus.requested,
      _GeneratedSequenceLifecycleStatus.backfilled =>
        SyncSequenceStatus.backfilled,
      _GeneratedSequenceLifecycleStatus.deleted => SyncSequenceStatus.deleted,
      _GeneratedSequenceLifecycleStatus.unresolvable =>
        SyncSequenceStatus.unresolvable,
      _GeneratedSequenceLifecycleStatus.absent => throw StateError(
        'Absent lifecycle rows do not have a sync status',
      ),
    };
  }

  String? entryId(int counter) =>
      isStored && hasEntryId ? 'generated-lifecycle-entry-$counter' : null;

  DateTime createdAt(DateTime now) => now.subtract(const Duration(days: 30));

  DateTime updatedAtValue(DateTime now) {
    return switch (updatedAt) {
      _GeneratedUpdatedTimestamp.fresh => now.subtract(
        const Duration(days: 1),
      ),
      _GeneratedUpdatedTimestamp.atCutoff => now.subtract(
        _SequenceLifecycleScenario.amnestyWindow,
      ),
      _GeneratedUpdatedTimestamp.old => now.subtract(
        const Duration(days: 10),
      ),
    };
  }

  DateTime? lastRequestedAtValue(DateTime now) {
    return switch (lastRequestedAt) {
      _GeneratedRequestTimestamp.absent => null,
      _GeneratedRequestTimestamp.fresh => now.subtract(
        const Duration(minutes: 1),
      ),
      _GeneratedRequestTimestamp.atCutoff => now.subtract(
        _SequenceLifecycleScenario.grace,
      ),
      _GeneratedRequestTimestamp.old => now.subtract(
        const Duration(minutes: 10),
      ),
    };
  }

  @override
  String toString() {
    return '_SequenceLifecycleRowSpec('
        'status: $status, '
        'payloadType: $payloadType, '
        'hasEntryId: $hasEntryId, '
        'requestCount: $requestCount, '
        'lastRequestedAt: $lastRequestedAt, '
        'updatedAt: $updatedAt'
        ')';
  }
}

class _SequenceLifecycleExpectedRow {
  const _SequenceLifecycleExpectedRow({
    required this.status,
    required this.entryId,
    required this.requestCount,
    required this.lastRequestedCleared,
    required this.payloadType,
  });

  final SyncSequenceStatus? status;
  final String? entryId;
  final int? requestCount;
  final bool lastRequestedCleared;
  final SyncSequencePayloadType? payloadType;
}

class _SequenceLifecycleScenario {
  const _SequenceLifecycleScenario({
    required this.operation,
    required this.rows,
  });

  static final now = DateTime(2026, 5, 6, 12);
  static const hostId = 'generated-lifecycle-host';
  static const maxRequestCount = 5;
  static const grace = Duration(minutes: 5);
  static const amnestyWindow = Duration(days: 7);

  final _GeneratedSequenceLifecycleOperation operation;
  final List<_SequenceLifecycleRowSpec> rows;

  int get expectedAffectedCount {
    return [
      for (var index = 0; index < rows.length; index++)
        if (_changesRow(rows[index], index + 1)) rows[index],
    ].length;
  }

  _SequenceLifecycleExpectedRow expectedRow(int counter) {
    final row = rows[counter - 1];
    if (!row.isStored) {
      return const _SequenceLifecycleExpectedRow(
        status: null,
        entryId: null,
        requestCount: null,
        lastRequestedCleared: false,
        payloadType: null,
      );
    }

    final changes = _changesRow(row, counter);
    final status = changes
        ? switch (operation) {
            _GeneratedSequenceLifecycleOperation.resetKnown ||
            _GeneratedSequenceLifecycleOperation.resetAll =>
              SyncSequenceStatus.missing,
            _GeneratedSequenceLifecycleOperation.retireExhausted ||
            _GeneratedSequenceLifecycleOperation.retireAgedOut =>
              SyncSequenceStatus.unresolvable,
          }
        : row.syncStatus;

    return _SequenceLifecycleExpectedRow(
      status: status,
      entryId: row.entryId(counter),
      requestCount:
          changes &&
              (operation == _GeneratedSequenceLifecycleOperation.resetKnown ||
                  operation == _GeneratedSequenceLifecycleOperation.resetAll)
          ? 0
          : row.requestCount,
      lastRequestedCleared:
          changes &&
          (operation == _GeneratedSequenceLifecycleOperation.resetKnown ||
              operation == _GeneratedSequenceLifecycleOperation.resetAll),
      payloadType: row.payloadType,
    );
  }

  int? get expectedWatermark {
    if (!rows.any((row) => row.isStored)) return null;

    var prefix = 0;
    for (var counter = 1; counter <= rows.length; counter++) {
      final expected = expectedRow(counter);
      if (expected.status == null || !expected.status!.isResolvedWatermark) {
        break;
      }
      prefix++;
    }
    return prefix;
  }

  bool _changesRow(_SequenceLifecycleRowSpec row, int counter) {
    if (!row.isStored) return false;

    return switch (operation) {
      _GeneratedSequenceLifecycleOperation.resetKnown =>
        row.status == _GeneratedSequenceLifecycleStatus.unresolvable &&
            row.entryId(counter) != null,
      _GeneratedSequenceLifecycleOperation.resetAll =>
        row.status == _GeneratedSequenceLifecycleStatus.unresolvable,
      _GeneratedSequenceLifecycleOperation.retireExhausted =>
        row.isMissingOrRequested &&
            row.requestCount >= maxRequestCount &&
            row.lastRequestedAtValue(now) != null &&
            row
                .lastRequestedAtValue(
                  now,
                )!
                .isBefore(now.subtract(grace)),
      _GeneratedSequenceLifecycleOperation.retireAgedOut =>
        row.isMissingOrRequested &&
            row.updatedAtValue(now).isBefore(now.subtract(amnestyWindow)),
    };
  }

  @override
  String toString() {
    return '_SequenceLifecycleScenario('
        'operation: $operation, '
        'rows: $rows'
        ')';
  }
}

extension _SyncSequenceStatusModelX on SyncSequenceStatus {
  bool get isResolvedWatermark =>
      this == SyncSequenceStatus.received ||
      this == SyncSequenceStatus.backfilled ||
      this == SyncSequenceStatus.deleted ||
      this == SyncSequenceStatus.unresolvable;
}

class _OutboxClaimModelRow {
  const _OutboxClaimModelRow({
    required this.id,
    required this.spec,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final _OutboxClaimRowSpec spec;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isPending => spec.status == _GeneratedOutboxStatus.pending;

  bool get isExpiredSending =>
      spec.status == _GeneratedOutboxStatus.expiredSending;

  bool get hasMedia => spec.hasMedia;
}

extension _AnyOutboxClaimScenario on Any {
  Generator<_GeneratedOutboxStatus> get generatedOutboxStatus =>
      choose(_GeneratedOutboxStatus.values);

  Generator<SyncSequencePayloadType> get generatedPayloadType =>
      choose(SyncSequencePayloadType.values);

  Generator<_GeneratedSequenceLifecycleOperation>
  get generatedSequenceLifecycleOperation =>
      choose(_GeneratedSequenceLifecycleOperation.values);

  Generator<_GeneratedSequenceLifecycleStatus>
  get generatedSequenceLifecycleStatus =>
      choose(_GeneratedSequenceLifecycleStatus.values);

  Generator<_GeneratedRequestTimestamp> get generatedRequestTimestamp =>
      choose(_GeneratedRequestTimestamp.values);

  Generator<_GeneratedUpdatedTimestamp> get generatedUpdatedTimestamp =>
      choose(_GeneratedUpdatedTimestamp.values);

  Generator<_OutboxClaimRowSpec> get outboxClaimRowSpec => combine3(
    intInRange(0, 6),
    any.bool,
    generatedOutboxStatus,
    (int createdMinute, bool hasMedia, _GeneratedOutboxStatus status) =>
        _OutboxClaimRowSpec(
          createdMinute: createdMinute,
          hasMedia: hasMedia,
          status: status,
        ),
  );

  Generator<_OutboxClaimScenario> get outboxClaimScenario => combine2(
    intInRange(0, 8),
    listWithLengthInRange(0, 12, outboxClaimRowSpec),
    (int maxSize, List<_OutboxClaimRowSpec> rows) => _OutboxClaimScenario(
      maxSize: maxSize,
      rows: rows,
    ),
  );

  Generator<_GeneratedOutboxAge> get generatedOutboxAge =>
      choose(_GeneratedOutboxAge.values);

  Generator<_PruneRowSpec> get pruneRowSpec => combine2(
    generatedOutboxStatus,
    generatedOutboxAge,
    (_GeneratedOutboxStatus status, _GeneratedOutboxAge age) =>
        _PruneRowSpec(status: status, age: age),
  );

  /// Scenario space for `pruneSentOutboxItemsChunked`. `chunkSize`
  /// stays small (1–6) so generated row counts realistically straddle
  /// chunk boundaries — the loop's terminator condition (`n < chunkSize`)
  /// is the bit most likely to harbor an off-by-one. `retentionDays`
  /// covers the realistic configured-retention window from
  /// `SyncTuning.outboxSentRetention` and a few neighbours.
  Generator<_PruneScenario> get pruneScenario => combine3(
    listWithLengthInRange(0, 14, pruneRowSpec),
    intInRange(1, 6),
    intInRange(1, 7),
    (List<_PruneRowSpec> rows, int chunkSize, int retentionDays) =>
        _PruneScenario(
          rows: rows,
          chunkSize: chunkSize,
          retentionDays: retentionDays,
        ),
  );

  Generator<_SequenceLifecycleRowSpec> get sequenceLifecycleRowSpec => combine6(
    generatedSequenceLifecycleStatus,
    generatedPayloadType,
    any.bool,
    intInRange(0, 8),
    generatedRequestTimestamp,
    generatedUpdatedTimestamp,
    (
      _GeneratedSequenceLifecycleStatus status,
      SyncSequencePayloadType payloadType,
      bool hasEntryId,
      int requestCount,
      _GeneratedRequestTimestamp lastRequestedAt,
      _GeneratedUpdatedTimestamp updatedAt,
    ) => _SequenceLifecycleRowSpec(
      status: status,
      payloadType: payloadType,
      hasEntryId: hasEntryId,
      requestCount: requestCount,
      lastRequestedAt: lastRequestedAt,
      updatedAt: updatedAt,
    ),
  );

  Generator<_SequenceLifecycleScenario> get sequenceLifecycleScenario =>
      combine2(
        generatedSequenceLifecycleOperation,
        listWithLengthInRange(0, 14, sequenceLifecycleRowSpec),
        (
          _GeneratedSequenceLifecycleOperation operation,
          List<_SequenceLifecycleRowSpec> rows,
        ) => _SequenceLifecycleScenario(
          operation: operation,
          rows: rows,
        ),
      );
}

List<_OutboxClaimModelRow> _expectedClaimedRows({
  required List<_OutboxClaimModelRow> rows,
  required int maxSize,
}) {
  if (maxSize <= 0) return const [];

  int compareByCreatedAtThenId(
    _OutboxClaimModelRow a,
    _OutboxClaimModelRow b,
  ) {
    final created = a.createdAt.compareTo(b.createdAt);
    if (created != 0) return created;
    return a.id.compareTo(b.id);
  }

  final pendingRows = rows.where((row) => row.isPending).toList()
    ..sort(compareByCreatedAtThenId);
  final expiredSendingRows = rows.where((row) => row.isExpiredSending).toList()
    ..sort(compareByCreatedAtThenId);

  final candidates = <_OutboxClaimModelRow>[
    ...pendingRows.take(maxSize),
    ...expiredSendingRows.take(maxSize),
  ]..sort(compareByCreatedAtThenId);
  if (candidates.length > maxSize) {
    candidates.removeRange(maxSize, candidates.length);
  }
  if (candidates.isEmpty) return const [];

  if (candidates.first.hasMedia) return [candidates.first];

  final stopAt = candidates.indexWhere((row) => row.hasMedia);
  return stopAt == -1 ? candidates : candidates.sublist(0, stopAt);
}

void main() {
  SyncDatabase? db;

  group('Sync Database Tests - ', () {
    setUp(() async {
      db = SyncDatabase(inMemoryDatabase: true);
    });
    tearDown(() async {
      await db?.close();
    });

    test(
      'empty database',
      () async {
        expect(
          await db?.watchOutboxCount().first,
          0,
        );

        expect(
          await db?.watchOutboxItems().first,
          <OutboxItem>[],
        );

        expect(
          await db?.oldestOutboxItems(100),
          <OutboxItem>[],
        );
      },
    );

    test(
      'add items to database',
      () async {
        final outboxItem1 = OutboxCompanion(
          status: Value(OutboxStatus.sent.index),
          subject: const Value('subject'),
          message: const Value('jsonString'),
          createdAt: Value(DateTime(2022, 7, 7, 13)),
          updatedAt: Value(DateTime(2022, 7, 7, 13)),
          retries: const Value(2),
        );

        final outboxItem2 = OutboxCompanion(
          status: Value(OutboxStatus.pending.index),
          subject: const Value('subject'),
          message: const Value('jsonString'),
          createdAt: Value(DateTime(2022, 7, 7, 14)),
          updatedAt: Value(DateTime(2022, 7, 7, 14)),
          retries: const Value(0),
        );

        await db?.addOutboxItem(outboxItem1);
        await db?.addOutboxItem(outboxItem2);

        expect(
          await db?.watchOutboxCount().first,
          1,
        );

        expect(
          await db?.watchOutboxItems(statuses: [OutboxStatus.pending]).first,
          <OutboxItem>[
            OutboxItem(
              id: 2,
              createdAt: DateTime(2022, 7, 7, 14),
              updatedAt: DateTime(2022, 7, 7, 14),
              status: OutboxStatus.pending.index,
              retries: 0,
              message: 'jsonString',
              subject: 'subject',
              priority: OutboxPriority.low.index,
            ),
          ],
        );

        expect(
          await db?.oldestOutboxItems(100),
          <OutboxItem>[
            OutboxItem(
              id: 2,
              createdAt: DateTime(2022, 7, 7, 14),
              updatedAt: DateTime(2022, 7, 7, 14),
              status: OutboxStatus.pending.index,
              retries: 0,
              message: 'jsonString',
              subject: 'subject',
              priority: OutboxPriority.low.index,
            ),
          ],
        );
      },
    );

    test(
      'update item in database',
      () async {
        final outboxItem = OutboxCompanion(
          status: Value(OutboxStatus.pending.index),
          subject: const Value('subject'),
          message: const Value('jsonString'),
          createdAt: Value(DateTime(2022, 7, 7, 14)),
          updatedAt: Value(DateTime(2022, 7, 7, 14)),
          retries: const Value(0),
        );

        await db?.addOutboxItem(outboxItem);

        expect(
          await db?.watchOutboxCount().first,
          1,
        );

        expect(
          await db?.watchOutboxItems(statuses: [OutboxStatus.pending]).first,
          <OutboxItem>[
            OutboxItem(
              id: 1,
              createdAt: DateTime(2022, 7, 7, 14),
              updatedAt: DateTime(2022, 7, 7, 14),
              status: OutboxStatus.pending.index,
              retries: 0,
              message: 'jsonString',
              subject: 'subject',
              priority: OutboxPriority.low.index,
            ),
          ],
        );

        expect(
          await db?.oldestOutboxItems(100),
          <OutboxItem>[
            OutboxItem(
              id: 1,
              createdAt: DateTime(2022, 7, 7, 14),
              updatedAt: DateTime(2022, 7, 7, 14),
              status: OutboxStatus.pending.index,
              retries: 0,
              message: 'jsonString',
              subject: 'subject',
              priority: OutboxPriority.low.index,
            ),
          ],
        );

        await db?.updateOutboxItem(
          const OutboxCompanion(
            id: Value(1),
            retries: Value(1),
          ),
        );

        expect(
          await db?.oldestOutboxItems(100),
          <OutboxItem>[
            OutboxItem(
              id: 1,
              createdAt: DateTime(2022, 7, 7, 14),
              updatedAt: DateTime(2022, 7, 7, 14),
              status: OutboxStatus.pending.index,
              retries: 1,
              message: 'jsonString',
              subject: 'subject',
              priority: OutboxPriority.low.index,
            ),
          ],
        );

        await db?.updateOutboxItem(
          OutboxCompanion(
            id: const Value(1),
            status: Value(OutboxStatus.sent.index),
          ),
        );

        expect(
          await db?.watchOutboxCount().first,
          0,
        );

        expect(
          await db?.oldestOutboxItems(100),
          <OutboxItem>[],
        );
      },
    );

    test('watchOutboxItems filters by provided statuses', () async {
      final database = db!;
      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 1, 1),
          subject: 'pending',
        ),
      );
      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.error,
          createdAt: DateTime(2024, 1, 2),
          subject: 'error',
        ),
      );
      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.sent,
          createdAt: DateTime(2024, 1, 3),
          subject: 'sent',
        ),
      );

      final results = await database
          .watchOutboxItems(
            statuses: [
              OutboxStatus.pending,
              OutboxStatus.error,
            ],
          )
          .first;

      expect(results, hasLength(2));
      expect(
        results.map((item) => item.status).toSet(),
        {OutboxStatus.pending.index, OutboxStatus.error.index},
      );
    });

    test(
      'oldestOutboxItems returns pending items in ascending order',
      () async {
        final database = db!;
        await database.addOutboxItem(
          _buildOutbox(
            status: OutboxStatus.pending,
            createdAt: DateTime(2024, 3, 10),
          ),
        );
        await database.addOutboxItem(
          _buildOutbox(
            status: OutboxStatus.pending,
            createdAt: DateTime(2024, 3, 8),
          ),
        );
        await database.addOutboxItem(
          _buildOutbox(
            status: OutboxStatus.pending,
            createdAt: DateTime(2024, 3, 9),
          ),
        );

        final results = await database.oldestOutboxItems(3);
        expect(
          results.map((item) => item.createdAt),
          [
            DateTime(2024, 3, 8),
            DateTime(2024, 3, 9),
            DateTime(2024, 3, 10),
          ],
        );
      },
    );

    test('oldestOutboxItems respects requested limit', () async {
      final database = db!;
      for (var i = 0; i < 5; i++) {
        await database.addOutboxItem(
          _buildOutbox(
            status: OutboxStatus.pending,
            createdAt: DateTime(2024, 4, 1 + i),
          ),
        );
      }

      final results = await database.oldestOutboxItems(2);
      expect(results, hasLength(2));
      expect(results.first.createdAt, DateTime(2024, 4, 1));
      expect(results.last.createdAt, DateTime(2024, 4, 2));
    });

    test('oldestOutboxItems avoids a full table scan', () async {
      final plan = await db!
          .customSelect(
            '''
        EXPLAIN QUERY PLAN
        SELECT * FROM outbox
        WHERE status = ?1
        ORDER BY created_at ASC
        LIMIT 1
        ''',
            variables: [Variable<int>(OutboxStatus.pending.index)],
          )
          .get();

      final details = plan.map((row) => row.read<String>('detail')).join(' ');
      expect(details, isNot(contains('SCAN outbox')));
    });

    test('claimNextOutboxItem claims oldest eligible item', () async {
      final database = db!;
      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.pending,
          subject: 'newest',
          message: '{"id":"newest"}',
          createdAt: DateTime(2024, 1, 3),
        ),
      );
      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.pending,
          subject: 'oldest',
          message: '{"id":"oldest"}',
          createdAt: DateTime(2024, 1, 1),
        ),
      );
      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.sent,
          subject: 'ignored',
          message: '{"id":"ignored"}',
          createdAt: DateTime(2024, 1, 2),
        ),
      );

      final claimed = await database.claimNextOutboxItem();

      expect(claimed, isNotNull);
      expect(claimed?.id, 2);
      final refreshed = await database.getOutboxItemById(2);
      expect(refreshed?.status, OutboxStatus.sending.index);
      expect(refreshed?.updatedAt.isAfter(DateTime(2024, 1, 1)), isTrue);
    });

    test(
      'claimNextOutboxItem skips in-flight rows with active leases',
      () async {
        final now = DateTime(2024, 1, 2, 12);
        final database = db!;
        await database.addOutboxItem(
          OutboxCompanion(
            status: Value(OutboxStatus.sending.index),
            subject: const Value('inFlight'),
            message: const Value('{"id":"inFlight"}'),
            createdAt: Value(now),
            updatedAt: Value(now),
            retries: const Value(0),
          ),
        );
        await database.addOutboxItem(
          _buildOutbox(
            status: OutboxStatus.pending,
            subject: 'pending',
            message: '{"id":"pending"}',
            createdAt: DateTime(2024, 1, 2),
          ),
        );

        final claimed = await database.claimNextOutboxItem(
          leaseDuration: const Duration(minutes: 5),
          now: now,
        );

        expect(claimed, isNotNull);
        expect(claimed?.id, 2);
        expect(claimed?.status, OutboxStatus.sending.index);
        final first = await database.getOutboxItemById(1);
        expect(first?.status, OutboxStatus.sending.index);
      },
    );

    test('claimNextOutboxItem reclaims stale in-flight rows', () async {
      final now = DateTime(2024, 1, 1, 12);
      final stale = now.subtract(const Duration(minutes: 10));
      final database = db!;
      await database.addOutboxItem(
        OutboxCompanion(
          status: Value(OutboxStatus.sending.index),
          subject: const Value('stale'),
          message: const Value('{"id":"stale"}'),
          createdAt: Value(stale),
          updatedAt: Value(stale),
          retries: const Value(0),
        ),
      );
      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.pending,
          subject: 'newer',
          message: '{"id":"newer"}',
          createdAt: DateTime(2024, 1, 2),
        ),
      );

      final claimed = await database.claimNextOutboxItem(
        leaseDuration: const Duration(minutes: 5),
        now: now,
      );

      expect(claimed, isNotNull);
      expect(claimed?.id, 1);
      expect(claimed?.status, OutboxStatus.sending.index);
    });

    group('claimNextOutboxBatch', () {
      test('returns [] for an empty queue', () async {
        final database = db!;
        final batch = await database.claimNextOutboxBatch(maxSize: 50);
        expect(batch, isEmpty);
      });

      test('returns [] when maxSize is zero', () async {
        final database = db!;
        await database.addOutboxItem(
          _buildOutbox(
            status: OutboxStatus.pending,
            createdAt: DateTime(2024),
          ),
        );
        final batch = await database.claimNextOutboxBatch(maxSize: 0);
        expect(batch, isEmpty);
        // The row is untouched.
        final refreshed = await database.getOutboxItemById(1);
        expect(refreshed?.status, OutboxStatus.pending.index);
      });

      test(
        'claims up to maxSize consecutive text rows in createdAt order '
        'and transitions each to sending',
        () async {
          final database = db!;
          for (var i = 0; i < 5; i++) {
            await database.addOutboxItem(
              _buildOutbox(
                status: OutboxStatus.pending,
                createdAt: DateTime(2024, 1, 1).add(Duration(minutes: i)),
                subject: 'row-$i',
                message: '{"i":$i}',
              ),
            );
          }

          final batch = await database.claimNextOutboxBatch(maxSize: 3);

          expect(batch, hasLength(3));
          expect(batch.map((r) => r.id).toList(), [1, 2, 3]);
          for (final row in batch) {
            expect(row.status, OutboxStatus.sending.index);
          }
          // Untouched leftovers stay pending.
          for (final id in [4, 5]) {
            final refreshed = await database.getOutboxItemById(id);
            expect(refreshed?.status, OutboxStatus.pending.index);
          }
        },
      );

      test(
        'returns the head row alone when it is a media attachment, even when '
        'maxSize would allow more',
        () async {
          final database = db!;
          await database.addOutboxItem(
            _buildOutbox(
              status: OutboxStatus.pending,
              createdAt: DateTime(2024, 1, 1, 0, 0),
              filePath: 'audio/1.aac',
              subject: 'attachment-head',
            ),
          );
          await database.addOutboxItem(
            _buildOutbox(
              status: OutboxStatus.pending,
              createdAt: DateTime(2024, 1, 1, 0, 1),
              subject: 'text-1',
            ),
          );
          await database.addOutboxItem(
            _buildOutbox(
              status: OutboxStatus.pending,
              createdAt: DateTime(2024, 1, 1, 0, 2),
              subject: 'text-2',
            ),
          );

          final batch = await database.claimNextOutboxBatch(maxSize: 50);

          expect(batch, hasLength(1));
          expect(batch.single.id, 1);
          expect(batch.single.filePath, 'audio/1.aac');
          // The text rows after the attachment remain pending — the next
          // drain pass will batch them.
          for (final id in [2, 3]) {
            final refreshed = await database.getOutboxItemById(id);
            expect(refreshed?.status, OutboxStatus.pending.index);
          }
        },
      );

      test(
        'stops the bundle one row before the first media attachment',
        () async {
          final database = db!;
          for (var i = 0; i < 3; i++) {
            await database.addOutboxItem(
              _buildOutbox(
                status: OutboxStatus.pending,
                createdAt: DateTime(2024, 1, 1).add(Duration(minutes: i)),
                subject: 'text-$i',
              ),
            );
          }
          // Position 4 carries a media attachment.
          await database.addOutboxItem(
            _buildOutbox(
              status: OutboxStatus.pending,
              createdAt: DateTime(2024, 1, 1, 0, 3),
              filePath: 'images/1.jpg',
              subject: 'media',
            ),
          );

          final batch = await database.claimNextOutboxBatch(maxSize: 50);

          expect(batch.map((r) => r.id).toList(), [1, 2, 3]);
          // The media row is left pending so the next pass sends it alone.
          final media = await database.getOutboxItemById(4);
          expect(media?.status, OutboxStatus.pending.index);
          expect(media?.filePath, 'images/1.jpg');
        },
      );

      test(
        'bundles in createdAt order regardless of priority tier',
        () async {
          final database = db!;
          await database.addOutboxItem(
            OutboxCompanion(
              status: Value(OutboxStatus.pending.index),
              subject: const Value('high-1'),
              message: const Value('{}'),
              createdAt: Value(DateTime(2024, 1, 1, 0, 0)),
              updatedAt: Value(DateTime(2024, 1, 1, 0, 0)),
              retries: const Value(0),
              priority: Value(OutboxPriority.high.index),
            ),
          );
          await database.addOutboxItem(
            OutboxCompanion(
              status: Value(OutboxStatus.pending.index),
              subject: const Value('normal-1'),
              message: const Value('{}'),
              createdAt: Value(DateTime(2024, 1, 1, 0, 1)),
              updatedAt: Value(DateTime(2024, 1, 1, 0, 1)),
              retries: const Value(0),
              priority: Value(OutboxPriority.normal.index),
            ),
          );

          final batch = await database.claimNextOutboxBatch(maxSize: 50);

          expect(batch.map((r) => r.id).toList(), [1, 2]);
          expect(batch.first.priority, OutboxPriority.high.index);
          expect(batch.last.priority, OutboxPriority.normal.index);
        },
      );

      test(
        'reclaims expired sending rows just like the single-claim path',
        () async {
          final now = DateTime(2024, 1, 1, 12);
          final stale = now.subtract(const Duration(minutes: 10));
          final database = db!;
          await database.addOutboxItem(
            OutboxCompanion(
              status: Value(OutboxStatus.sending.index),
              subject: const Value('stale'),
              message: const Value('{}'),
              createdAt: Value(stale),
              updatedAt: Value(stale),
              retries: const Value(0),
            ),
          );
          await database.addOutboxItem(
            _buildOutbox(
              status: OutboxStatus.pending,
              createdAt: now,
              subject: 'fresh',
            ),
          );

          final batch = await database.claimNextOutboxBatch(
            maxSize: 50,
            leaseDuration: const Duration(minutes: 5),
            now: now,
          );

          expect(batch.map((r) => r.id).toList(), [1, 2]);
          for (final row in batch) {
            expect(row.status, OutboxStatus.sending.index);
            expect(row.updatedAt, now);
          }
        },
      );

      test(
        'leaves rows whose lease is still active untouched',
        () async {
          final now = DateTime(2024, 1, 2, 12);
          final database = db!;
          await database.addOutboxItem(
            OutboxCompanion(
              status: Value(OutboxStatus.sending.index),
              subject: const Value('active'),
              message: const Value('{}'),
              createdAt: Value(now),
              updatedAt: Value(now),
              retries: const Value(0),
            ),
          );
          await database.addOutboxItem(
            _buildOutbox(
              status: OutboxStatus.pending,
              createdAt: DateTime(2024, 1, 2),
              subject: 'pending',
            ),
          );

          final batch = await database.claimNextOutboxBatch(
            maxSize: 50,
            leaseDuration: const Duration(minutes: 5),
            now: now,
          );

          // Only the pending row, since the in-flight lease is still valid.
          expect(batch.map((r) => r.id).toList(), [2]);
        },
      );

      test('caps the result at maxSize even for an all-text queue', () async {
        final database = db!;
        for (var i = 0; i < 7; i++) {
          await database.addOutboxItem(
            _buildOutbox(
              status: OutboxStatus.pending,
              createdAt: DateTime(2024, 1, 1).add(Duration(minutes: i)),
              subject: 'row-$i',
            ),
          );
        }

        final batch = await database.claimNextOutboxBatch(maxSize: 5);

        expect(batch, hasLength(5));
        expect(batch.map((r) => r.id).toList(), [1, 2, 3, 4, 5]);
        // The remaining 2 rows still claimable on the next call.
        final next = await database.claimNextOutboxBatch(maxSize: 5);
        expect(next.map((r) => r.id).toList(), [6, 7]);
      });

      Glados(any.outboxClaimScenario, ExploreConfig(numRuns: 40)).test(
        'claims the modelled eligible media-bounded prefix',
        (scenario) async {
          final database = SyncDatabase(inMemoryDatabase: true);
          final base = DateTime(2024, 1);
          final now = DateTime(2024, 1, 1, 12);
          const leaseDuration = Duration(minutes: 5);
          final modelRows = <_OutboxClaimModelRow>[];

          try {
            for (var i = 0; i < scenario.rows.length; i++) {
              final spec = scenario.rows[i];
              final createdAt = spec.createdAt(base);
              final updatedAt = spec.updatedAt(base, now);
              final id = await database.addOutboxItem(
                OutboxCompanion(
                  status: Value(spec.dbStatus.index),
                  subject: Value('row-$i'),
                  message: Value('{"row":$i}'),
                  createdAt: Value(createdAt),
                  updatedAt: Value(updatedAt),
                  retries: const Value(0),
                  filePath: spec.hasMedia
                      ? Value<String?>('media-$i.bin')
                      : const Value.absent(),
                ),
              );
              modelRows.add(
                _OutboxClaimModelRow(
                  id: id,
                  spec: spec,
                  createdAt: createdAt,
                  updatedAt: updatedAt,
                ),
              );
            }

            final expected = _expectedClaimedRows(
              rows: modelRows,
              maxSize: scenario.maxSize,
            );

            final claimed = await database.claimNextOutboxBatch(
              maxSize: scenario.maxSize,
              leaseDuration: leaseDuration,
              now: now,
            );

            expect(
              claimed.map((row) => row.id).toList(),
              expected.map((row) => row.id).toList(),
            );

            final selectedIds = expected.map((row) => row.id).toSet();
            final storedRows = {
              for (final row in await database.allOutboxItems) row.id: row,
            };

            for (final row in modelRows) {
              final stored = storedRows[row.id]!;
              if (selectedIds.contains(row.id)) {
                expect(stored.status, OutboxStatus.sending.index);
                expect(stored.updatedAt, now);
              } else {
                expect(stored.status, row.spec.dbStatus.index);
                expect(stored.updatedAt, row.updatedAt);
              }
            }
          } finally {
            await database.close();
          }
        },
      );
    });

    test('updateOutboxItem can set status to error', () async {
      final database = db!;
      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 5, 1),
        ),
      );

      await database.updateOutboxItem(
        OutboxCompanion(
          id: const Value(1),
          status: Value(OutboxStatus.error.index),
        ),
      );

      final errorItems = await database
          .watchOutboxItems(statuses: [OutboxStatus.error])
          .first;
      expect(errorItems.single.status, OutboxStatus.error.index);
      expect(await database.watchOutboxCount().first, 0);
    });

    test('watchOutboxCount counts only pending items', () async {
      final database = db!;
      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.error,
          createdAt: DateTime(2024, 5, 2),
        ),
      );
      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.sent,
          createdAt: DateTime(2024, 5, 3),
        ),
      );
      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 5, 4),
        ),
      );

      expect(await database.watchOutboxCount().first, 1);
    });

    test('getPendingOutboxCount returns count of pending items', () async {
      final database = db!;
      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.error,
          createdAt: DateTime(2024, 5, 2),
        ),
      );
      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 5, 3),
        ),
      );
      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 5, 4),
        ),
      );

      expect(await database.getPendingOutboxCount(), 2);
    });

    test('updateOutboxItem increments retry count', () async {
      final database = db!;
      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 6, 1),
          retries: 0,
        ),
      );

      await database.updateOutboxItem(
        const OutboxCompanion(
          id: Value(1),
          retries: Value(3),
        ),
      );

      final items = await database.oldestOutboxItems(1);
      expect(items.single.retries, 3);
    });

    test('updateOutboxItem updates multiple fields atomically', () async {
      final database = db!;
      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 7, 1),
        ),
      );

      final updatedAt = DateTime(2024, 7, 2);
      await database.updateOutboxItem(
        OutboxCompanion(
          id: const Value(1),
          status: Value(OutboxStatus.sent.index),
          retries: const Value(5),
          updatedAt: Value(updatedAt),
        ),
      );

      final rows = await database.allOutboxItems;
      expect(rows.single.status, OutboxStatus.sent.index);
      expect(rows.single.retries, 5);
      expect(rows.single.updatedAt, updatedAt);
    });

    test('updateOutboxItem returns 0 for unknown id', () async {
      final database = db!;
      final result = await database.updateOutboxItem(
        const OutboxCompanion(
          id: Value(99),
          retries: Value(1),
        ),
      );
      expect(result, 0);
    });

    test('watchOutboxItems emits when new item is added', () async {
      final database = db!;
      final updates = database.watchOutboxItems(
        statuses: [OutboxStatus.pending],
      );
      final expectation = expectLater(
        updates,
        emitsThrough(
          isA<List<OutboxItem>>()
              .having((items) => items.length, 'length', 1)
              .having((items) => items.single.subject, 'subject', 'new-item'),
        ),
      );

      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 8, 10),
          subject: 'new-item',
        ),
      );

      await expectation;
    });

    test('addOutboxItem persists optional fields', () async {
      final database = db!;
      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 8, 1),
          retries: 2,
          subject: 'with-file',
          message: '{"payload":true}',
          filePath: '/tmp/outbox.json',
        ),
      );

      final stored = await database.allOutboxItems;
      final item = stored.single;
      expect(item.retries, 2);
      expect(item.filePath, '/tmp/outbox.json');
      expect(item.message, '{"payload":true}');
      expect(item.subject, 'with-file');
    });

    test('deleteOutboxItemById removes specific item', () async {
      final database = db!;
      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 9, 1),
          subject: 'item-1',
        ),
      );
      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.error,
          createdAt: DateTime(2024, 9, 2),
          subject: 'item-2',
        ),
      );
      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.sent,
          createdAt: DateTime(2024, 9, 3),
          subject: 'item-3',
        ),
      );

      expect(await database.allOutboxItems, hasLength(3));

      // Delete item with id 2
      final deletedCount = await database.deleteOutboxItemById(2);
      expect(deletedCount, 1);

      final remaining = await database.allOutboxItems;
      expect(remaining, hasLength(2));
      expect(remaining.map((e) => e.subject).toSet(), {'item-1', 'item-3'});
    });

    test('deleteOutboxItemById returns 0 for non-existent id', () async {
      final database = db!;
      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 9, 1),
        ),
      );

      final deletedCount = await database.deleteOutboxItemById(999);
      expect(deletedCount, 0);

      expect(await database.allOutboxItems, hasLength(1));
    });

    test(
      'pruneSentOutboxItems deletes only `sent` rows older than retention, '
      'keeps `error` forever (regardless of age), and leaves pending/sending '
      'untouched',
      () async {
        final database = db!;
        final now = DateTime(2026, 4, 22, 12);
        final old = now.subtract(const Duration(days: 10));
        final fresh = now.subtract(const Duration(days: 2));

        // Old sent — must be pruned.
        await database.addOutboxItem(
          _buildOutbox(
            status: OutboxStatus.sent,
            createdAt: old,
            subject: 'old-sent',
          ),
        );
        // Fresh sent — within retention, must stay.
        await database.addOutboxItem(
          _buildOutbox(
            status: OutboxStatus.sent,
            createdAt: fresh,
            subject: 'fresh-sent',
          ),
        );
        // Old error — kept forever for forensic inspection.
        await database.addOutboxItem(
          _buildOutbox(
            status: OutboxStatus.error,
            createdAt: old,
            subject: 'old-error',
          ),
        );
        // Old pending — never pruned (live state).
        await database.addOutboxItem(
          _buildOutbox(
            status: OutboxStatus.pending,
            createdAt: old,
            subject: 'old-pending',
          ),
        );
        // Old sending — never pruned (live state).
        await database.addOutboxItem(
          _buildOutbox(
            status: OutboxStatus.sending,
            createdAt: old,
            subject: 'old-sending',
          ),
        );

        final deleted = await database.pruneSentOutboxItems(
          retention: const Duration(days: 7),
          now: now,
        );
        expect(deleted, 1);

        final remaining = await database.allOutboxItems;
        expect(
          remaining.map((e) => e.subject).toSet(),
          {'fresh-sent', 'old-error', 'old-pending', 'old-sending'},
        );
      },
    );

    test(
      'pruneSentOutboxItems uses updated_at (send time), not created_at '
      '(enqueue time) — a row enqueued 10 days ago but sent today must not '
      'be pruned',
      () async {
        final database = db!;
        final now = DateTime(2026, 4, 22, 12);
        final oldCreated = now.subtract(const Duration(days: 10));
        final recentlySent = now.subtract(const Duration(hours: 6));

        // Enqueued 10 days ago, sent 6 hours ago. Pruning by created_at
        // would delete this row; pruning by updated_at (the send time
        // stamped by markSent) keeps it.
        await database.addOutboxItem(
          OutboxCompanion(
            status: Value(OutboxStatus.sent.index),
            subject: const Value('stuck-then-recently-sent'),
            message: const Value('{}'),
            createdAt: Value(oldCreated),
            updatedAt: Value(recentlySent),
            retries: const Value(0),
          ),
        );

        // An actually-old sent row (control): enqueued AND sent 10 days
        // ago — this one should be deleted.
        await database.addOutboxItem(
          OutboxCompanion(
            status: Value(OutboxStatus.sent.index),
            subject: const Value('actually-old'),
            message: const Value('{}'),
            createdAt: Value(oldCreated),
            updatedAt: Value(oldCreated),
            retries: const Value(0),
          ),
        );

        final deleted = await database.pruneSentOutboxItems(
          retention: const Duration(days: 7),
          now: now,
        );
        expect(deleted, 1);

        final remaining = await database.allOutboxItems;
        expect(remaining.map((e) => e.subject).toSet(), {
          'stuck-then-recently-sent',
        });
      },
    );

    test(
      'pruneSentOutboxItems returns 0 when there is nothing to prune',
      () async {
        final database = db!;
        final now = DateTime(2026, 4, 22);
        await database.addOutboxItem(
          _buildOutbox(
            status: OutboxStatus.sent,
            createdAt: now.subtract(const Duration(days: 2)),
            subject: 'recent-sent',
          ),
        );

        final deleted = await database.pruneSentOutboxItems(
          retention: const Duration(days: 7),
          now: now,
        );
        expect(deleted, 0);
        expect(await database.allOutboxItems, hasLength(1));
      },
    );

    test(
      'pruneSentOutboxItemsChunked deletes the same rows as the unbounded '
      'variant but in bounded passes — onProgress reports the running total '
      'after each chunk and the loop terminates when a pass deletes fewer '
      'rows than chunkSize',
      () async {
        final database = db!;
        final now = DateTime(2026, 5, 9, 12);
        // 12 stale `sent` rows + 1 fresh `sent` + 1 `pending` + 1 `error`.
        // With chunkSize = 5 the chunked loop must run 3 passes
        // (5 + 5 + 2); the third pass is the natural terminator (n <
        // chunkSize), so progress should be [5, 10, 12].
        for (var i = 0; i < 12; i++) {
          await database.addOutboxItem(
            _buildOutbox(
              status: OutboxStatus.sent,
              createdAt: now.subtract(const Duration(days: 30)),
              subject: 'stale-sent-$i',
            ),
          );
        }
        await database.addOutboxItem(
          _buildOutbox(
            status: OutboxStatus.sent,
            createdAt: now,
            subject: 'fresh-sent',
          ),
        );
        await database.addOutboxItem(
          _buildOutbox(
            status: OutboxStatus.pending,
            createdAt: now.subtract(const Duration(days: 30)),
            subject: 'old-pending',
          ),
        );
        await database.addOutboxItem(
          _buildOutbox(
            status: OutboxStatus.error,
            createdAt: now.subtract(const Duration(days: 30)),
            subject: 'old-error',
          ),
        );

        final progress = <int>[];
        final deleted = await database.pruneSentOutboxItemsChunked(
          retention: const Duration(days: 7),
          chunkSize: 5,
          now: now,
          onProgress: progress.add,
        );

        expect(deleted, 12);
        expect(progress, [5, 10, 12]);
        final remaining = await database.allOutboxItems;
        expect(
          remaining.map((e) => e.subject).toSet(),
          {'fresh-sent', 'old-pending', 'old-error'},
        );
      },
    );

    test(
      'pruneSentOutboxItemsChunked stops on the first pass when the eligible '
      'set fits in one chunk',
      () async {
        final database = db!;
        final now = DateTime(2026, 5, 9);
        for (var i = 0; i < 3; i++) {
          await database.addOutboxItem(
            _buildOutbox(
              status: OutboxStatus.sent,
              createdAt: now.subtract(const Duration(days: 30)),
              subject: 'stale-$i',
            ),
          );
        }

        final progress = <int>[];
        final deleted = await database.pruneSentOutboxItemsChunked(
          retention: const Duration(days: 7),
          chunkSize: 100,
          now: now,
          onProgress: progress.add,
        );

        expect(deleted, 3);
        expect(progress, [3]);
        expect(await database.allOutboxItems, isEmpty);
      },
    );

    Glados(any.pruneScenario, ExploreConfig(numRuns: 80)).test(
      'pruneSentOutboxItemsChunked invariants — for any (rows, chunkSize, '
      'retention): only (sent, old) rows are deleted; live state and forensic '
      'rows survive; progress is monotonic non-decreasing, ends at the return '
      'value, and the emission count obeys (deleted ~/ chunkSize) + 1',
      (scenario) async {
        final database = SyncDatabase(inMemoryDatabase: true);
        try {
          // Seed in scenario order so the auto-increment id's encode the
          // generator's row index — makes failing-shrink scenarios easier
          // to reason about by row.
          for (final row in scenario.rows) {
            await database.addOutboxItem(
              OutboxCompanion(
                status: Value(row.dbStatus.index),
                subject: const Value('s'),
                message: const Value('{}'),
                createdAt: Value(
                  row.updatedAtValue(
                    retention: scenario.retention,
                    now: _PruneScenario.now,
                  ),
                ),
                updatedAt: Value(
                  row.updatedAtValue(
                    retention: scenario.retention,
                    now: _PruneScenario.now,
                  ),
                ),
                retries: const Value(0),
              ),
            );
          }

          final progress = <int>[];
          final deleted = await database.pruneSentOutboxItemsChunked(
            retention: scenario.retention,
            chunkSize: scenario.chunkSize,
            now: _PruneScenario.now,
            onProgress: progress.add,
          );

          // Return value matches the model.
          expect(deleted, scenario.expectedDeleted);

          // Surviving rows are exactly the non-prunable subset, in any
          // order. Compare a sorted (status, updatedAt) projection so
          // the assertion is independent of insertion order.
          final remaining = await database.allOutboxItems;
          List<(int, int)> projection(Iterable<OutboxItem> items) =>
              [
                for (final item in items)
                  (item.status, item.updatedAt.microsecondsSinceEpoch),
              ]..sort((a, b) {
                final s = a.$1.compareTo(b.$1);
                return s != 0 ? s : a.$2.compareTo(b.$2);
              });
          final expectedSurvivors = scenario.rows.where(
            (r) => !r.isPrunable(
              retention: scenario.retention,
              now: _PruneScenario.now,
            ),
          );
          expect(
            projection(remaining),
            projection([
              for (final r in expectedSurvivors)
                OutboxItem(
                  id: 0,
                  status: r.dbStatus.index,
                  subject: 's',
                  message: '{}',
                  createdAt: r.updatedAtValue(
                    retention: scenario.retention,
                    now: _PruneScenario.now,
                  ),
                  updatedAt: r.updatedAtValue(
                    retention: scenario.retention,
                    now: _PruneScenario.now,
                  ),
                  retries: 0,
                  priority: OutboxPriority.low.index,
                ),
            ]),
          );

          // Progress sequence matches the model: monotonic non-decreasing,
          // terminates at `deleted`, with `(deleted ~/ chunkSize) + 1`
          // emissions including the terminator pass.
          expect(progress, scenario.expectedProgress);
          expect(progress.last, deleted);
          for (var i = 1; i < progress.length; i++) {
            expect(
              progress[i] >= progress[i - 1],
              isTrue,
              reason: 'progress must be monotonic non-decreasing',
            );
          }
        } finally {
          await database.close();
        }
      },
    );

    test(
      'pruneSentOutboxItemsChunked returns 0 and never invokes onProgress '
      'when there is nothing to prune',
      () async {
        final database = db!;
        final now = DateTime(2026, 5, 9);
        await database.addOutboxItem(
          _buildOutbox(
            status: OutboxStatus.sent,
            createdAt: now.subtract(const Duration(days: 1)),
            subject: 'recent-sent',
          ),
        );

        final progress = <int>[];
        final deleted = await database.pruneSentOutboxItemsChunked(
          retention: const Duration(days: 7),
          chunkSize: 10,
          now: now,
          onProgress: progress.add,
        );

        // The first pass deletes 0 rows (nothing eligible) and that is
        // already < chunkSize, so the loop exits after one iteration.
        // The progress callback fires exactly once with the running
        // total of zero — callers can rely on the final progress value
        // matching the return value.
        expect(deleted, 0);
        expect(progress, [0]);
        expect(await database.allOutboxItems, hasLength(1));
      },
    );
  });

  group('SyncSequenceLog Tests', () {
    setUp(() async {
      db = SyncDatabase(inMemoryDatabase: true);
    });
    tearDown(() async {
      await db?.close();
    });

    test('recordSequenceEntry inserts new entry', () async {
      final database = db!;
      const hostId = 'host-1';
      const counter = 5;
      final now = DateTime(2024, 1, 1);

      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(counter),
          entryId: const Value('entry-1'),
          status: Value(SyncSequenceStatus.received.index),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      final entry = await database.getEntryByHostAndCounter(hostId, counter);
      expect(entry, isNotNull);
      expect(entry!.hostId, hostId);
      expect(entry.counter, counter);
      expect(entry.entryId, 'entry-1');
      expect(entry.status, SyncSequenceStatus.received.index);
    });

    test('recordSequenceEntry updates existing entry', () async {
      final database = db!;
      const hostId = 'host-1';
      const counter = 5;

      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(counter),
          status: Value(SyncSequenceStatus.missing.index),
          createdAt: Value(DateTime(2024, 1, 1)),
          updatedAt: Value(DateTime(2024, 1, 1)),
        ),
      );

      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(counter),
          entryId: const Value('entry-1'),
          status: Value(SyncSequenceStatus.backfilled.index),
          createdAt: Value(DateTime(2024, 1, 2)),
          updatedAt: Value(DateTime(2024, 1, 2)),
        ),
      );

      final entry = await database.getEntryByHostAndCounter(hostId, counter);
      expect(entry!.status, SyncSequenceStatus.backfilled.index);
      expect(entry.entryId, 'entry-1');
    });

    test(
      'getLastCounterForHost returns highest contiguous resolved counter',
      () async {
        final database = db!;
        const hostId = 'host-1';

        for (var i = 1; i <= 5; i++) {
          await database.recordSequenceEntry(
            SyncSequenceLogCompanion(
              hostId: const Value(hostId),
              counter: Value(i),
              status: Value(SyncSequenceStatus.received.index),
              createdAt: Value(DateTime(2024, 1, i)),
              updatedAt: Value(DateTime(2024, 1, i)),
            ),
          );
        }

        final lastCounter = await database.getLastCounterForHost(hostId);
        expect(lastCounter, 5);
      },
    );

    test('getLastCounterForHost stops at first unresolved gap', () async {
      final database = db!;
      const hostId = 'host-1';

      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(1),
          status: Value(SyncSequenceStatus.received.index),
          createdAt: Value(DateTime(2024, 1, 1)),
          updatedAt: Value(DateTime(2024, 1, 1)),
        ),
      );
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(2),
          status: Value(SyncSequenceStatus.backfilled.index),
          createdAt: Value(DateTime(2024, 1, 2)),
          updatedAt: Value(DateTime(2024, 1, 2)),
        ),
      );
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(3),
          status: Value(SyncSequenceStatus.missing.index),
          createdAt: Value(DateTime(2024, 1, 3)),
          updatedAt: Value(DateTime(2024, 1, 3)),
        ),
      );
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(4),
          status: Value(SyncSequenceStatus.received.index),
          createdAt: Value(DateTime(2024, 1, 4)),
          updatedAt: Value(DateTime(2024, 1, 4)),
        ),
      );

      final lastCounter = await database.getLastCounterForHost(hostId);
      expect(lastCounter, 2);
    });

    test('getLastCounterForHost returns null for unknown host', () async {
      final database = db!;
      final lastCounter = await database.getLastCounterForHost('unknown');
      expect(lastCounter, isNull);
    });

    test(
      'getLastCounterForHost returns 0 when host rows start above counter 1',
      () async {
        final database = db!;
        const hostId = 'host-1';

        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value(hostId),
            counter: const Value(5),
            status: Value(SyncSequenceStatus.received.index),
            createdAt: Value(DateTime(2024, 1, 5)),
            updatedAt: Value(DateTime(2024, 1, 5)),
          ),
        );

        final lastCounter = await database.getLastCounterForHost(hostId);
        expect(lastCounter, 0);
      },
    );

    test(
      'getCountersForHostInRange returns only counters inside range',
      () async {
        final database = db!;
        const hostId = 'host-1';

        for (final counter in [1, 3, 5]) {
          await database.recordSequenceEntry(
            SyncSequenceLogCompanion(
              hostId: const Value(hostId),
              counter: Value(counter),
              status: Value(SyncSequenceStatus.received.index),
              createdAt: Value(DateTime(2024, 1, counter)),
              updatedAt: Value(DateTime(2024, 1, counter)),
            ),
          );
        }

        final counters = await database.getCountersForHostInRange(hostId, 2, 4);
        expect(counters, {3});
      },
    );

    test(
      'getCountersForHostInRange returns empty set for invalid range',
      () async {
        final database = db!;

        final counters = await database.getCountersForHostInRange(
          'host-1',
          5,
          4,
        );
        expect(counters, isEmpty);
      },
    );

    test('getMissingEntries returns only missing/requested entries', () async {
      final database = db!;
      const hostId = 'host-1';

      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(1),
          status: Value(SyncSequenceStatus.received.index),
          createdAt: Value(DateTime(2024, 1, 1)),
          updatedAt: Value(DateTime(2024, 1, 1)),
        ),
      );
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(2),
          status: Value(SyncSequenceStatus.missing.index),
          createdAt: Value(DateTime(2024, 1, 2)),
          updatedAt: Value(DateTime(2024, 1, 2)),
        ),
      );
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(3),
          status: Value(SyncSequenceStatus.requested.index),
          createdAt: Value(DateTime(2024, 1, 3)),
          updatedAt: Value(DateTime(2024, 1, 3)),
        ),
      );

      final missing = await database.getMissingEntries();
      expect(missing, hasLength(2));
      expect(missing.map((e) => e.counter).toSet(), {2, 3});
    });

    test('getMissingEntries respects maxRequestCount', () async {
      final database = db!;
      const hostId = 'host-1';

      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(1),
          status: Value(SyncSequenceStatus.missing.index),
          requestCount: const Value(5),
          createdAt: Value(DateTime(2024, 1, 1)),
          updatedAt: Value(DateTime(2024, 1, 1)),
        ),
      );
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(2),
          status: Value(SyncSequenceStatus.missing.index),
          requestCount: const Value(15),
          createdAt: Value(DateTime(2024, 1, 2)),
          updatedAt: Value(DateTime(2024, 1, 2)),
        ),
      );

      final missing = await database.getMissingEntries(maxRequestCount: 10);
      expect(missing, hasLength(1));
      expect(missing.first.counter, 1);
    });

    test(
      'getMissingEntries honors minAge — rows created more recently '
      'than now-minAge are held back so a short-lived gap caused by '
      'out-of-order priority messages can resolve via standard sync '
      'before backfill fires',
      () async {
        final database = db!;
        const hostId = 'host-1';
        final now = DateTime(2024, 1, 2, 12);

        // Fresh: 1 minute old — within the 10-minute debounce window.
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value(hostId),
            counter: const Value(1),
            status: Value(SyncSequenceStatus.missing.index),
            createdAt: Value(now.subtract(const Duration(minutes: 1))),
            updatedAt: Value(now.subtract(const Duration(minutes: 1))),
          ),
        );
        // Ripe: 15 minutes old — past the window.
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value(hostId),
            counter: const Value(2),
            status: Value(SyncSequenceStatus.missing.index),
            createdAt: Value(now.subtract(const Duration(minutes: 15))),
            updatedAt: Value(now.subtract(const Duration(minutes: 15))),
          ),
        );

        final ripe = await database.getMissingEntries(
          minAge: const Duration(minutes: 10),
          now: now,
        );
        expect(ripe, hasLength(1));
        expect(ripe.single.counter, 2);

        // Without debounce, both rows are eligible. Ordering is by
        // created_at ASC, so the older row (counter 2) comes first.
        final all = await database.getMissingEntries(now: now);
        expect(all.map((e) => e.counter), [2, 1]);
      },
    );

    test(
      'getMissingEntriesWithLimits honors minAge alongside the maxAge / '
      'maxPerHost gates',
      () async {
        final database = db!;
        const hostId = 'host-1';
        final now = DateTime(2024, 1, 2, 12);

        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value(hostId),
            counter: const Value(1),
            status: Value(SyncSequenceStatus.missing.index),
            createdAt: Value(now.subtract(const Duration(minutes: 1))),
            updatedAt: Value(now.subtract(const Duration(minutes: 1))),
          ),
        );
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value(hostId),
            counter: const Value(2),
            status: Value(SyncSequenceStatus.missing.index),
            createdAt: Value(now.subtract(const Duration(minutes: 15))),
            updatedAt: Value(now.subtract(const Duration(minutes: 15))),
          ),
        );

        final ripe = await database.getMissingEntriesWithLimits(
          minAge: const Duration(minutes: 10),
          now: now,
        );
        expect(ripe, hasLength(1));
        expect(ripe.single.counter, 2);
      },
    );

    test('updateSequenceStatus updates status', () async {
      final database = db!;
      const hostId = 'host-1';
      const counter = 1;

      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(counter),
          status: Value(SyncSequenceStatus.missing.index),
          createdAt: Value(DateTime(2024, 1, 1)),
          updatedAt: Value(DateTime(2024, 1, 1)),
        ),
      );

      await database.updateSequenceStatus(
        hostId,
        counter,
        SyncSequenceStatus.deleted,
      );

      final entry = await database.getEntryByHostAndCounter(hostId, counter);
      expect(entry!.status, SyncSequenceStatus.deleted.index);
    });

    test('getSequenceLogCount returns total count of entries', () async {
      final database = db!;

      // Initial count should be 0
      expect(await database.getSequenceLogCount(), 0);

      // Add entries with various statuses
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value('host-1'),
          counter: const Value(1),
          status: Value(SyncSequenceStatus.received.index),
          createdAt: Value(DateTime(2024, 1, 1)),
          updatedAt: Value(DateTime(2024, 1, 1)),
        ),
      );
      expect(await database.getSequenceLogCount(), 1);

      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value('host-1'),
          counter: const Value(2),
          status: Value(SyncSequenceStatus.missing.index),
          createdAt: Value(DateTime(2024, 1, 2)),
          updatedAt: Value(DateTime(2024, 1, 2)),
        ),
      );
      expect(await database.getSequenceLogCount(), 2);

      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value('host-2'),
          counter: const Value(1),
          status: Value(SyncSequenceStatus.backfilled.index),
          createdAt: Value(DateTime(2024, 1, 3)),
          updatedAt: Value(DateTime(2024, 1, 3)),
        ),
      );
      expect(await database.getSequenceLogCount(), 3);
    });
  });

  group('HostActivity Tests', () {
    setUp(() async {
      db = SyncDatabase(inMemoryDatabase: true);
    });
    tearDown(() async {
      await db?.close();
    });

    test('updateHostActivity inserts new host', () async {
      final database = db!;
      const hostId = 'host-1';
      final now = DateTime(2024, 1, 1);

      await database.updateHostActivity(hostId, now);

      final lastSeen = await database.getHostLastSeen(hostId);
      expect(lastSeen, now);
    });

    test('updateHostActivity updates existing host', () async {
      final database = db!;
      const hostId = 'host-1';

      await database.updateHostActivity(hostId, DateTime(2024, 1, 1));
      await database.updateHostActivity(hostId, DateTime(2024, 2, 1));

      final lastSeen = await database.getHostLastSeen(hostId);
      expect(lastSeen, DateTime(2024, 2, 1));
    });

    test('getHostLastSeen returns null for unknown host', () async {
      final database = db!;
      final lastSeen = await database.getHostLastSeen('unknown');
      expect(lastSeen, isNull);
    });
  });

  group('getBackfillStats Tests', () {
    setUp(() async {
      db = SyncDatabase(inMemoryDatabase: true);
    });
    tearDown(() async {
      await db?.close();
    });

    test('returns empty stats when no entries', () async {
      final database = db!;
      final stats = await database.getBackfillStats();

      expect(stats.hostStats, isEmpty);
      expect(stats.totalReceived, 0);
      expect(stats.totalMissing, 0);
      expect(stats.totalRequested, 0);
      expect(stats.totalBackfilled, 0);
      expect(stats.totalDeleted, 0);
    });

    test('counts entries by status for single host', () async {
      final database = db!;
      const hostId = 'host-1';

      // Add entries with different statuses
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(1),
          status: Value(SyncSequenceStatus.received.index),
          createdAt: Value(DateTime(2024, 1, 1)),
          updatedAt: Value(DateTime(2024, 1, 1)),
        ),
      );
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(2),
          status: Value(SyncSequenceStatus.received.index),
          createdAt: Value(DateTime(2024, 1, 2)),
          updatedAt: Value(DateTime(2024, 1, 2)),
        ),
      );
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(3),
          status: Value(SyncSequenceStatus.missing.index),
          createdAt: Value(DateTime(2024, 1, 3)),
          updatedAt: Value(DateTime(2024, 1, 3)),
        ),
      );
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(4),
          status: Value(SyncSequenceStatus.backfilled.index),
          createdAt: Value(DateTime(2024, 1, 4)),
          updatedAt: Value(DateTime(2024, 1, 4)),
        ),
      );

      final stats = await database.getBackfillStats();

      expect(stats.hostStats, hasLength(1));
      expect(stats.hostStats.first.receivedCount, 2);
      expect(stats.hostStats.first.missingCount, 1);
      expect(stats.hostStats.first.backfilledCount, 1);

      expect(stats.totalReceived, 2);
      expect(stats.totalMissing, 1);
      expect(stats.totalBackfilled, 1);
    });

    test('counts entries across multiple hosts', () async {
      final database = db!;

      // Host 1: 2 received
      for (var i = 1; i <= 2; i++) {
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value('host-1'),
            counter: Value(i),
            status: Value(SyncSequenceStatus.received.index),
            createdAt: Value(DateTime(2024, 1, i)),
            updatedAt: Value(DateTime(2024, 1, i)),
          ),
        );
      }

      // Host 2: 3 missing
      for (var i = 1; i <= 3; i++) {
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value('host-2'),
            counter: Value(i),
            status: Value(SyncSequenceStatus.missing.index),
            createdAt: Value(DateTime(2024, 2, i)),
            updatedAt: Value(DateTime(2024, 2, i)),
          ),
        );
      }

      final stats = await database.getBackfillStats();

      expect(stats.hostStats, hasLength(2));
      expect(stats.totalReceived, 2);
      expect(stats.totalMissing, 3);
      expect(stats.totalEntries, 5);
    });

    test('includes host activity lastSeenAt', () async {
      final database = db!;
      const hostId = 'host-1';
      final lastSeen = DateTime(2024, 5, 15);

      await database.updateHostActivity(hostId, lastSeen);
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(1),
          status: Value(SyncSequenceStatus.received.index),
          createdAt: Value(DateTime(2024, 1, 1)),
          updatedAt: Value(DateTime(2024, 1, 1)),
        ),
      );

      final stats = await database.getBackfillStats();

      expect(stats.hostStats.first.lastSeenAt, lastSeen);
    });

    test('counts unresolvable entries correctly', () async {
      final database = db!;
      const hostId = 'host-1';

      // Add entries with different statuses including unresolvable
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(1),
          status: Value(SyncSequenceStatus.received.index),
          createdAt: Value(DateTime(2024, 1, 1)),
          updatedAt: Value(DateTime(2024, 1, 1)),
        ),
      );
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(2),
          status: Value(SyncSequenceStatus.unresolvable.index),
          createdAt: Value(DateTime(2024, 1, 2)),
          updatedAt: Value(DateTime(2024, 1, 2)),
        ),
      );
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(3),
          status: Value(SyncSequenceStatus.unresolvable.index),
          createdAt: Value(DateTime(2024, 1, 3)),
          updatedAt: Value(DateTime(2024, 1, 3)),
        ),
      );
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(4),
          status: Value(SyncSequenceStatus.deleted.index),
          createdAt: Value(DateTime(2024, 1, 4)),
          updatedAt: Value(DateTime(2024, 1, 4)),
        ),
      );

      final stats = await database.getBackfillStats();

      expect(stats.hostStats, hasLength(1));
      expect(stats.hostStats.first.receivedCount, 1);
      expect(stats.hostStats.first.unresolvableCount, 2);
      expect(stats.hostStats.first.deletedCount, 1);
      expect(stats.totalUnresolvable, 2);
      expect(stats.totalDeleted, 1);
    });
  });

  group('getMissingEntriesWithLimits Tests', () {
    setUp(() async {
      db = SyncDatabase(inMemoryDatabase: true);
    });
    tearDown(() async {
      await db?.close();
    });

    test('returns missing entries without limits', () async {
      final database = db!;
      const hostId = 'host-1';

      for (var i = 1; i <= 5; i++) {
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value(hostId),
            counter: Value(i),
            status: Value(SyncSequenceStatus.missing.index),
            createdAt: Value(DateTime(2024, 1, i)),
            updatedAt: Value(DateTime(2024, 1, i)),
          ),
        );
      }

      final missing = await database.getMissingEntriesWithLimits();
      expect(missing, hasLength(5));
    });

    test('respects maxAge limit', () async {
      final database = db!;
      const hostId = 'host-1';
      final now = DateTime(2024, 1, 3, 12);

      // Entry from 2 hours ago (should be included with 1 day limit)
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(1),
          status: Value(SyncSequenceStatus.missing.index),
          createdAt: Value(now.subtract(const Duration(hours: 2))),
          updatedAt: Value(now.subtract(const Duration(hours: 2))),
        ),
      );

      // Entry from 2 days ago (should be excluded with 1 day limit)
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(2),
          status: Value(SyncSequenceStatus.missing.index),
          createdAt: Value(now.subtract(const Duration(days: 2))),
          updatedAt: Value(now.subtract(const Duration(days: 2))),
        ),
      );

      final missing = await database.getMissingEntriesWithLimits(
        maxAge: const Duration(days: 1),
        now: now,
      );
      expect(missing, hasLength(1));
      expect(missing.first.counter, 1);
    });

    test('respects maxPerHost limit', () async {
      final database = db!;

      // Add 5 entries for host-1
      for (var i = 1; i <= 5; i++) {
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value('host-1'),
            counter: Value(i),
            status: Value(SyncSequenceStatus.missing.index),
            createdAt: Value(DateTime(2024, 1, i)),
            updatedAt: Value(DateTime(2024, 1, i)),
          ),
        );
      }

      // Add 5 entries for host-2
      for (var i = 1; i <= 5; i++) {
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value('host-2'),
            counter: Value(i),
            status: Value(SyncSequenceStatus.missing.index),
            createdAt: Value(DateTime(2024, 2, i)),
            updatedAt: Value(DateTime(2024, 2, i)),
          ),
        );
      }

      final missing = await database.getMissingEntriesWithLimits(
        maxPerHost: 2,
      );
      // 2 from host-1 + 2 from host-2 = 4
      expect(missing, hasLength(4));

      // Check we got 2 from each host
      final host1Entries = missing.where((e) => e.hostId == 'host-1').toList();
      final host2Entries = missing.where((e) => e.hostId == 'host-2').toList();
      expect(host1Entries, hasLength(2));
      expect(host2Entries, hasLength(2));
    });

    test('respects overall limit', () async {
      final database = db!;
      const hostId = 'host-1';

      for (var i = 1; i <= 10; i++) {
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value(hostId),
            counter: Value(i),
            status: Value(SyncSequenceStatus.missing.index),
            createdAt: Value(DateTime(2024, 1, i)),
            updatedAt: Value(DateTime(2024, 1, i)),
          ),
        );
      }

      final missing = await database.getMissingEntriesWithLimits(limit: 3);
      expect(missing, hasLength(3));
    });

    test('supports offset after filtering', () async {
      final database = db!;
      const hostId = 'host-1';

      for (var i = 1; i <= 5; i++) {
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value(hostId),
            counter: Value(i),
            status: Value(SyncSequenceStatus.missing.index),
            createdAt: Value(DateTime(2024, 1, i)),
            updatedAt: Value(DateTime(2024, 1, i)),
          ),
        );
      }

      final missing = await database.getMissingEntriesWithLimits(
        limit: 2,
        offset: 2,
      );
      expect(missing.map((e) => e.counter).toList(), [3, 4]);
    });

    test('respects maxRequestCount', () async {
      final database = db!;
      const hostId = 'host-1';

      // Entry with low request count (should be included)
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(1),
          status: Value(SyncSequenceStatus.missing.index),
          requestCount: const Value(2),
          createdAt: Value(DateTime(2024, 1, 1)),
          updatedAt: Value(DateTime(2024, 1, 1)),
        ),
      );

      // Entry with high request count (should be excluded)
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(2),
          status: Value(SyncSequenceStatus.missing.index),
          requestCount: const Value(15),
          createdAt: Value(DateTime(2024, 1, 2)),
          updatedAt: Value(DateTime(2024, 1, 2)),
        ),
      );

      final missing = await database.getMissingEntriesWithLimits(
        maxRequestCount: 10,
      );
      expect(missing, hasLength(1));
      expect(missing.first.counter, 1);
    });

    test('combines all limits correctly', () async {
      final database = db!;
      final now = DateTime(2024, 1, 3, 12);

      // Recent entries for host-1 (10 entries)
      for (var i = 1; i <= 10; i++) {
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value('host-1'),
            counter: Value(i),
            status: Value(SyncSequenceStatus.missing.index),
            createdAt: Value(now.subtract(Duration(hours: i))),
            updatedAt: Value(now.subtract(Duration(hours: i))),
          ),
        );
      }

      // Old entries for host-2 (should be filtered by maxAge)
      for (var i = 1; i <= 5; i++) {
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value('host-2'),
            counter: Value(i),
            status: Value(SyncSequenceStatus.missing.index),
            createdAt: Value(now.subtract(const Duration(days: 5))),
            updatedAt: Value(now.subtract(const Duration(days: 5))),
          ),
        );
      }

      final missing = await database.getMissingEntriesWithLimits(
        limit: 5,
        maxAge: const Duration(days: 1),
        maxPerHost: 3,
        now: now,
      );

      // Only host-1 entries (maxAge filters host-2)
      // maxPerHost limits to 3
      // overall limit is 5 but maxPerHost restricts to 3
      expect(missing, hasLength(3));
      expect(missing.every((e) => e.hostId == 'host-1'), isTrue);
    });
  });

  group('Batch Operations Tests', () {
    setUp(() async {
      db = SyncDatabase(inMemoryDatabase: true);
    });
    tearDown(() async {
      await db?.close();
    });

    test('batchInsertSequenceEntries inserts multiple entries', () async {
      final database = db!;
      final now = DateTime(2024, 1, 1);

      final entries = [
        SyncSequenceLogCompanion(
          hostId: const Value('host-1'),
          counter: const Value(1),
          status: Value(SyncSequenceStatus.received.index),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
        SyncSequenceLogCompanion(
          hostId: const Value('host-1'),
          counter: const Value(2),
          status: Value(SyncSequenceStatus.received.index),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
        SyncSequenceLogCompanion(
          hostId: const Value('host-2'),
          counter: const Value(1),
          status: Value(SyncSequenceStatus.received.index),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      ];

      await database.batchInsertSequenceEntries(entries);

      final host1Entry1 = await database.getEntryByHostAndCounter('host-1', 1);
      final host1Entry2 = await database.getEntryByHostAndCounter('host-1', 2);
      final host2Entry1 = await database.getEntryByHostAndCounter('host-2', 1);

      expect(host1Entry1, isNotNull);
      expect(host1Entry2, isNotNull);
      expect(host2Entry1, isNotNull);
    });

    test('batchInsertSequenceEntries ignores duplicates', () async {
      final database = db!;
      final now = DateTime(2024, 1, 1);

      // Insert initial entry
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value('host-1'),
          counter: const Value(1),
          entryId: const Value('original-entry'),
          status: Value(SyncSequenceStatus.received.index),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      // Batch insert with duplicate
      final entries = [
        SyncSequenceLogCompanion(
          hostId: const Value('host-1'),
          counter: const Value(1),
          entryId: const Value('duplicate-entry'),
          status: Value(SyncSequenceStatus.missing.index),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      ];

      await database.batchInsertSequenceEntries(entries);

      // Original entry should be unchanged
      final entry = await database.getEntryByHostAndCounter('host-1', 1);
      expect(entry!.entryId, 'original-entry');
      expect(entry.status, SyncSequenceStatus.received.index);
    });

    test('getCountersForHost returns all counters', () async {
      final database = db!;
      const hostId = 'host-1';
      final now = DateTime(2024, 1, 1);

      for (final i in [1, 3, 5, 7]) {
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value(hostId),
            counter: Value(i),
            status: Value(SyncSequenceStatus.received.index),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
      }

      final counters = await database.getCountersForHost(hostId);
      expect(counters, {1, 3, 5, 7});
    });

    test('getCountersForHost returns empty set for unknown host', () async {
      final database = db!;
      final counters = await database.getCountersForHost('unknown');
      expect(counters, isEmpty);
    });
  });

  group('getPendingBackfillEntries Tests', () {
    // Subject prefix that production `_enqueueBackfillRequest` stamps on
    // every backfill outbox row. `getPendingBackfillEntries` filters on
    // `subject LIKE 'backfillRequest:%'` at the SQL level so it can skip
    // JSON-decoding unrelated pending rows on a million-row outbox.
    const backfillSubject = 'backfillRequest:batch:1';

    setUp(() async {
      db = SyncDatabase(inMemoryDatabase: true);
    });
    tearDown(() async {
      await db?.close();
    });

    test('returns empty set when no outbox items', () async {
      final database = db!;
      final entries = await database.getPendingBackfillEntries();
      expect(entries, isEmpty);
    });

    test('returns empty set when no backfill request messages', () async {
      final database = db!;

      // Add a regular message (not backfill request)
      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 1, 1),
          subject: 'journalEntity',
          message: '{"runtimeType":"journalEntity","id":"test-1"}',
        ),
      );

      final entries = await database.getPendingBackfillEntries();
      expect(entries, isEmpty);
    });

    test(
      'excludes pending rows whose subject does not match the backfill prefix',
      () async {
        final database = db!;

        // Backfill-shaped JSON but a non-backfill subject — the SQL
        // prefilter must drop this row before it ever reaches JSON
        // decode. Production has no path that produces this combination
        // (`_enqueueBackfillRequest` is the only writer of this JSON
        // shape and it always stamps the matching subject), but the
        // filter is what makes the rewritten query cheap on huge
        // outboxes, so verify it is doing real work.
        await database.addOutboxItem(
          _buildOutbox(
            status: OutboxStatus.pending,
            createdAt: DateTime(2024, 1, 1),
            subject: 'something-else',
            message: '''
{
  "runtimeType": "backfillRequest",
  "entries": [{"hostId": "host-1", "counter": 5}],
  "requesterId": "req-1"
}
''',
          ),
        );

        final entries = await database.getPendingBackfillEntries();
        expect(entries, isEmpty);
      },
    );

    test('extracts entries from pending backfill request messages', () async {
      final database = db!;

      // Add a backfill request message with entries
      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 1, 1),
          subject: backfillSubject,
          message: '''
{
  "runtimeType": "backfillRequest",
  "entries": [
    {"hostId": "host-1", "counter": 5},
    {"hostId": "host-1", "counter": 6},
    {"hostId": "host-2", "counter": 10}
  ],
  "requesterId": "requester-1"
}
''',
        ),
      );

      final entries = await database.getPendingBackfillEntries();

      expect(entries, hasLength(3));
      expect(
        entries,
        containsAll([
          (hostId: 'host-1', counter: 5),
          (hostId: 'host-1', counter: 6),
          (hostId: 'host-2', counter: 10),
        ]),
      );
    });

    test('ignores sent backfill request messages', () async {
      final database = db!;

      // Add a sent (not pending) backfill request message
      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.sent,
          createdAt: DateTime(2024, 1, 1),
          subject: backfillSubject,
          message: '''
{
  "runtimeType": "backfillRequest",
  "entries": [{"hostId": "host-1", "counter": 5}],
  "requesterId": "requester-1"
}
''',
        ),
      );

      final entries = await database.getPendingBackfillEntries();
      expect(entries, isEmpty);
    });

    test('includes sending backfill request messages', () async {
      final database = db!;

      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.sending,
          createdAt: DateTime(2024, 1, 1),
          subject: backfillSubject,
          message: '''
{
  "runtimeType": "backfillRequest",
  "entries": [{"hostId": "host-1", "counter": 5}],
  "requesterId": "requester-1"
}
''',
        ),
      );

      final entries = await database.getPendingBackfillEntries();
      expect(entries, {(hostId: 'host-1', counter: 5)});
    });

    test('ignores error backfill request messages', () async {
      final database = db!;

      // Add an error (not pending) backfill request message
      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.error,
          createdAt: DateTime(2024, 1, 1),
          subject: backfillSubject,
          message: '''
{
  "runtimeType": "backfillRequest",
  "entries": [{"hostId": "host-1", "counter": 5}],
  "requesterId": "requester-1"
}
''',
        ),
      );

      final entries = await database.getPendingBackfillEntries();
      expect(entries, isEmpty);
    });

    test('handles malformed JSON gracefully', () async {
      final database = db!;

      // Add a malformed message — but with the backfill subject so the
      // SQL prefilter does not exclude it. The Dart-side try/catch is
      // what guards against a bad message body slipping past.
      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 1, 1),
          subject: backfillSubject,
          message: 'not valid json',
        ),
      );

      // Should not throw, just return empty
      final entries = await database.getPendingBackfillEntries();
      expect(entries, isEmpty);
    });

    test('handles missing entries array gracefully', () async {
      final database = db!;

      // Add a backfill request without entries array
      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 1, 1),
          subject: backfillSubject,
          message: '{"runtimeType": "backfillRequest", "requesterId": "req-1"}',
        ),
      );

      final entries = await database.getPendingBackfillEntries();
      expect(entries, isEmpty);
    });

    test('handles invalid entry format gracefully', () async {
      final database = db!;

      // Add a backfill request with invalid entry format
      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 1, 1),
          subject: backfillSubject,
          message: '''
{
  "runtimeType": "backfillRequest",
  "entries": [
    {"hostId": "host-1"},
    {"counter": 5},
    "invalid",
    null,
    {"hostId": "host-2", "counter": 10}
  ],
  "requesterId": "requester-1"
}
''',
        ),
      );

      final entries = await database.getPendingBackfillEntries();

      // Only the valid entry should be extracted
      expect(entries, hasLength(1));
      expect(entries.first, (hostId: 'host-2', counter: 10));
    });

    test('combines entries from multiple pending backfill requests', () async {
      final database = db!;

      // Add first backfill request
      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 1, 1),
          subject: backfillSubject,
          message: '''
{
  "runtimeType": "backfillRequest",
  "entries": [{"hostId": "host-1", "counter": 1}],
  "requesterId": "req-1"
}
''',
        ),
      );

      // Add second backfill request
      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 1, 2),
          subject: 'backfillRequest:batch:2',
          message: '''
{
  "runtimeType": "backfillRequest",
  "entries": [{"hostId": "host-2", "counter": 2}],
  "requesterId": "req-2"
}
''',
        ),
      );

      final entries = await database.getPendingBackfillEntries();

      expect(entries, hasLength(2));
      expect(
        entries,
        containsAll([
          (hostId: 'host-1', counter: 1),
          (hostId: 'host-2', counter: 2),
        ]),
      );
    });

    test('deduplicates identical entries', () async {
      final database = db!;

      // Add backfill request with duplicate entries
      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.pending,
          createdAt: DateTime(2024, 1, 1),
          subject: backfillSubject,
          message: '''
{
  "runtimeType": "backfillRequest",
  "entries": [
    {"hostId": "host-1", "counter": 5},
    {"hostId": "host-1", "counter": 5}
  ],
  "requesterId": "req-1"
}
''',
        ),
      );

      final entries = await database.getPendingBackfillEntries();

      // Set automatically deduplicates
      expect(entries, hasLength(1));
      expect(entries.first, (hostId: 'host-1', counter: 5));
    });
  });

  group('getRequestedEntries Tests', () {
    setUp(() async {
      db = SyncDatabase(inMemoryDatabase: true);
    });
    tearDown(() async {
      await db?.close();
    });

    test('returns only entries with requested status', () async {
      final database = db!;
      const hostId = 'host-1';

      // Add entries with different statuses
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(1),
          status: Value(SyncSequenceStatus.received.index),
          createdAt: Value(DateTime(2024, 1, 1)),
          updatedAt: Value(DateTime(2024, 1, 1)),
        ),
      );
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(2),
          status: Value(SyncSequenceStatus.requested.index),
          createdAt: Value(DateTime(2024, 1, 2)),
          updatedAt: Value(DateTime(2024, 1, 2)),
        ),
      );
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(3),
          status: Value(SyncSequenceStatus.missing.index),
          createdAt: Value(DateTime(2024, 1, 3)),
          updatedAt: Value(DateTime(2024, 1, 3)),
        ),
      );
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(4),
          status: Value(SyncSequenceStatus.requested.index),
          createdAt: Value(DateTime(2024, 1, 4)),
          updatedAt: Value(DateTime(2024, 1, 4)),
        ),
      );

      final requested = await database.getRequestedEntries();
      expect(requested, hasLength(2));
      expect(requested.map((e) => e.counter).toSet(), {2, 4});
    });

    test('respects limit parameter', () async {
      final database = db!;
      const hostId = 'host-1';

      // Add 5 requested entries
      for (var i = 1; i <= 5; i++) {
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value(hostId),
            counter: Value(i),
            status: Value(SyncSequenceStatus.requested.index),
            createdAt: Value(DateTime(2024, 1, i)),
            updatedAt: Value(DateTime(2024, 1, i)),
          ),
        );
      }

      final requested = await database.getRequestedEntries(limit: 2);
      expect(requested, hasLength(2));
    });

    test('supports offset parameter', () async {
      final database = db!;
      const hostId = 'host-1';

      for (var i = 1; i <= 5; i++) {
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value(hostId),
            counter: Value(i),
            status: Value(SyncSequenceStatus.requested.index),
            createdAt: Value(DateTime(2024, 1, i)),
            updatedAt: Value(DateTime(2024, 1, i)),
          ),
        );
      }

      final requested = await database.getRequestedEntries(limit: 2, offset: 2);
      expect(requested.map((e) => e.counter).toList(), [3, 4]);
    });

    test('returns empty list when no requested entries', () async {
      final database = db!;

      // Only add received entries
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value('host-1'),
          counter: const Value(1),
          status: Value(SyncSequenceStatus.received.index),
          createdAt: Value(DateTime(2024, 1, 1)),
          updatedAt: Value(DateTime(2024, 1, 1)),
        ),
      );

      final requested = await database.getRequestedEntries();
      expect(requested, isEmpty);
    });

    test('orders by createdAt ascending', () async {
      final database = db!;
      const hostId = 'host-1';

      // Add entries in reverse order
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(3),
          status: Value(SyncSequenceStatus.requested.index),
          createdAt: Value(DateTime(2024, 1, 30)),
          updatedAt: Value(DateTime(2024, 1, 30)),
        ),
      );
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(1),
          status: Value(SyncSequenceStatus.requested.index),
          createdAt: Value(DateTime(2024, 1, 10)),
          updatedAt: Value(DateTime(2024, 1, 10)),
        ),
      );
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(2),
          status: Value(SyncSequenceStatus.requested.index),
          createdAt: Value(DateTime(2024, 1, 20)),
          updatedAt: Value(DateTime(2024, 1, 20)),
        ),
      );

      final requested = await database.getRequestedEntries();
      expect(requested, hasLength(3));
      expect(requested[0].counter, 1); // Oldest first
      expect(requested[1].counter, 2);
      expect(requested[2].counter, 3); // Newest last
    });

    test('ignores maxRequestCount - returns all requested entries', () async {
      final database = db!;
      const hostId = 'host-1';

      // Add entry with high request count
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(1),
          status: Value(SyncSequenceStatus.requested.index),
          requestCount: const Value(100), // Very high count
          createdAt: Value(DateTime(2024, 1, 1)),
          updatedAt: Value(DateTime(2024, 1, 1)),
        ),
      );

      // Should still return the entry regardless of request count
      final requested = await database.getRequestedEntries();
      expect(requested, hasLength(1));
      expect(requested.first.requestCount, 100);
    });
  });

  group('resetRequestCounts Tests', () {
    setUp(() async {
      db = SyncDatabase(inMemoryDatabase: true);
    });
    tearDown(() async {
      await db?.close();
    });

    test('resets request count to zero', () async {
      final database = db!;
      const hostId = 'host-1';
      const counter = 1;

      // Add entry with high request count
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(counter),
          status: Value(SyncSequenceStatus.requested.index),
          requestCount: const Value(10),
          lastRequestedAt: Value(DateTime(2024, 1, 1)),
          createdAt: Value(DateTime(2024, 1, 1)),
          updatedAt: Value(DateTime(2024, 1, 1)),
        ),
      );

      await database.resetRequestCounts([
        (hostId: hostId, counter: counter),
      ]);

      final entry = await database.getEntryByHostAndCounter(hostId, counter);
      expect(entry!.requestCount, 0);
      expect(entry.lastRequestedAt, isNull);
    });

    test('resets multiple entries', () async {
      final database = db!;
      const hostId = 'host-1';

      // Add multiple entries with request counts
      for (var i = 1; i <= 3; i++) {
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value(hostId),
            counter: Value(i),
            status: Value(SyncSequenceStatus.requested.index),
            requestCount: Value(i * 5), // Different counts
            lastRequestedAt: Value(DateTime(2024, 1, i)),
            createdAt: Value(DateTime(2024, 1, i)),
            updatedAt: Value(DateTime(2024, 1, i)),
          ),
        );
      }

      await database.resetRequestCounts([
        (hostId: hostId, counter: 1),
        (hostId: hostId, counter: 2),
        (hostId: hostId, counter: 3),
      ]);

      for (var i = 1; i <= 3; i++) {
        final entry = await database.getEntryByHostAndCounter(hostId, i);
        expect(entry!.requestCount, 0);
        expect(entry.lastRequestedAt, isNull);
      }
    });

    test('handles empty list gracefully', () async {
      final database = db!;

      // Should not throw
      await database.resetRequestCounts([]);
    });

    test('updates updatedAt timestamp', () async {
      final database = db!;
      const hostId = 'host-1';
      const counter = 1;
      final originalDate = DateTime(2024, 1, 1);

      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(counter),
          status: Value(SyncSequenceStatus.requested.index),
          requestCount: const Value(5),
          createdAt: Value(originalDate),
          updatedAt: Value(originalDate),
        ),
      );

      await database.resetRequestCounts([
        (hostId: hostId, counter: counter),
      ]);

      final entry = await database.getEntryByHostAndCounter(hostId, counter);
      expect(entry!.updatedAt.isAfter(originalDate), isTrue);
    });

    test('does not affect other entries', () async {
      final database = db!;
      const hostId = 'host-1';

      // Add two entries
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(1),
          status: Value(SyncSequenceStatus.requested.index),
          requestCount: const Value(10),
          createdAt: Value(DateTime(2024, 1, 1)),
          updatedAt: Value(DateTime(2024, 1, 1)),
        ),
      );
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(2),
          status: Value(SyncSequenceStatus.requested.index),
          requestCount: const Value(20),
          createdAt: Value(DateTime(2024, 1, 2)),
          updatedAt: Value(DateTime(2024, 1, 2)),
        ),
      );

      // Only reset counter 1
      await database.resetRequestCounts([
        (hostId: hostId, counter: 1),
      ]);

      final entry1 = await database.getEntryByHostAndCounter(hostId, 1);
      final entry2 = await database.getEntryByHostAndCounter(hostId, 2);

      expect(entry1!.requestCount, 0);
      expect(entry2!.requestCount, 20); // Unchanged
    });
  });

  group('batchIncrementRequestCounts Tests', () {
    setUp(() async {
      db = SyncDatabase(inMemoryDatabase: true);
    });
    tearDown(() async {
      await db?.close();
    });

    test('increments request count for single entry', () async {
      final database = db!;
      const hostId = 'host-1';
      const counter = 1;

      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(counter),
          status: Value(SyncSequenceStatus.missing.index),
          requestCount: const Value(0),
          createdAt: Value(DateTime(2024, 1, 1)),
          updatedAt: Value(DateTime(2024, 1, 1)),
        ),
      );

      await database.batchIncrementRequestCounts([
        (hostId: hostId, counter: counter),
      ]);

      final entry = await database.getEntryByHostAndCounter(hostId, counter);
      expect(entry!.requestCount, 1);
      expect(entry.status, SyncSequenceStatus.requested.index);
      expect(entry.lastRequestedAt, isNotNull);
    });

    test('increments multiple entries in single batch', () async {
      final database = db!;
      const hostId = 'host-1';

      // Add multiple entries
      for (var i = 1; i <= 3; i++) {
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value(hostId),
            counter: Value(i),
            status: Value(SyncSequenceStatus.missing.index),
            requestCount: const Value(0),
            createdAt: Value(DateTime(2024, 1, i)),
            updatedAt: Value(DateTime(2024, 1, i)),
          ),
        );
      }

      await database.batchIncrementRequestCounts([
        (hostId: hostId, counter: 1),
        (hostId: hostId, counter: 2),
        (hostId: hostId, counter: 3),
      ]);

      for (var i = 1; i <= 3; i++) {
        final entry = await database.getEntryByHostAndCounter(hostId, i);
        expect(entry!.requestCount, 1);
        expect(entry.status, SyncSequenceStatus.requested.index);
        expect(entry.lastRequestedAt, isNotNull);
      }
    });

    test('increments different hosts in single batch', () async {
      final database = db!;

      // Add entries for different hosts
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value('host-1'),
          counter: const Value(1),
          status: Value(SyncSequenceStatus.missing.index),
          requestCount: const Value(5),
          createdAt: Value(DateTime(2024, 1, 1)),
          updatedAt: Value(DateTime(2024, 1, 1)),
        ),
      );
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value('host-2'),
          counter: const Value(1),
          status: Value(SyncSequenceStatus.missing.index),
          requestCount: const Value(3),
          createdAt: Value(DateTime(2024, 1, 1)),
          updatedAt: Value(DateTime(2024, 1, 1)),
        ),
      );

      await database.batchIncrementRequestCounts([
        (hostId: 'host-1', counter: 1),
        (hostId: 'host-2', counter: 1),
      ]);

      final entry1 = await database.getEntryByHostAndCounter('host-1', 1);
      final entry2 = await database.getEntryByHostAndCounter('host-2', 1);
      expect(entry1!.requestCount, 6); // 5 + 1
      expect(entry2!.requestCount, 4); // 3 + 1
    });

    test('handles empty list gracefully', () async {
      final database = db!;

      // Should not throw
      await database.batchIncrementRequestCounts([]);
    });

    test('does not affect other entries', () async {
      final database = db!;
      const hostId = 'host-1';

      // Add two entries
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(1),
          status: Value(SyncSequenceStatus.missing.index),
          requestCount: const Value(5),
          createdAt: Value(DateTime(2024, 1, 1)),
          updatedAt: Value(DateTime(2024, 1, 1)),
        ),
      );
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(2),
          status: Value(SyncSequenceStatus.missing.index),
          requestCount: const Value(10),
          createdAt: Value(DateTime(2024, 1, 2)),
          updatedAt: Value(DateTime(2024, 1, 2)),
        ),
      );

      // Only increment counter 1
      await database.batchIncrementRequestCounts([
        (hostId: hostId, counter: 1),
      ]);

      final entry1 = await database.getEntryByHostAndCounter(hostId, 1);
      final entry2 = await database.getEntryByHostAndCounter(hostId, 2);

      expect(entry1!.requestCount, 6); // 5 + 1
      expect(entry2!.requestCount, 10); // Unchanged
      expect(entry2.status, SyncSequenceStatus.missing.index); // Unchanged
    });

    test('updates updatedAt and lastRequestedAt timestamps', () async {
      final database = db!;
      const hostId = 'host-1';
      const counter = 1;
      final originalDate = DateTime(2024, 1, 1);

      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(counter),
          status: Value(SyncSequenceStatus.missing.index),
          requestCount: const Value(0),
          createdAt: Value(originalDate),
          updatedAt: Value(originalDate),
        ),
      );

      await database.batchIncrementRequestCounts([
        (hostId: hostId, counter: counter),
      ]);

      final entry = await database.getEntryByHostAndCounter(hostId, counter);
      expect(entry!.updatedAt.isAfter(originalDate), isTrue);
      expect(entry.lastRequestedAt, isNotNull);
      expect(entry.lastRequestedAt!.isAfter(originalDate), isTrue);
    });
  });

  group('getNearestCoveringEntry Tests', () {
    late SyncDatabase database;

    setUp(() async {
      db = SyncDatabase(inMemoryDatabase: true);
      database = db!;
    });

    tearDown(() async {
      await db?.close();
    });

    test('returns null when no entries exist', () async {
      final result = await database.getNearestCoveringEntry('host-1', 5);
      expect(result, isNull);
    });

    test(
      'returns entry with counter >= requested and received status',
      () async {
        await database.batchInsertSequenceEntries([
          SyncSequenceLogCompanion(
            hostId: const Value('host-1'),
            counter: const Value(7),
            status: Value(SyncSequenceStatus.received.index),
            entryId: const Value('entry-7'),
            payloadType: Value(SyncSequencePayloadType.journalEntity.index),
            createdAt: Value(DateTime(2024, 3, 15)),
            updatedAt: Value(DateTime(2024, 3, 15)),
          ),
        ]);

        final result = await database.getNearestCoveringEntry('host-1', 5);
        expect(result, isNotNull);
        expect(result!.counter, 7);
        expect(result.entryId, 'entry-7');
      },
    );

    test('returns entry with backfilled status', () async {
      await database.batchInsertSequenceEntries([
        SyncSequenceLogCompanion(
          hostId: const Value('host-1'),
          counter: const Value(10),
          status: Value(SyncSequenceStatus.backfilled.index),
          entryId: const Value('entry-10'),
          payloadType: Value(SyncSequencePayloadType.journalEntity.index),
          createdAt: Value(DateTime(2024, 3, 15)),
          updatedAt: Value(DateTime(2024, 3, 15)),
        ),
      ]);

      final result = await database.getNearestCoveringEntry('host-1', 5);
      expect(result, isNotNull);
      expect(result!.counter, 10);
      expect(result.entryId, 'entry-10');
    });

    test('skips hint-only requested rows', () async {
      // A requested row with entryId is a hint — payload may not exist locally
      await database.batchInsertSequenceEntries([
        SyncSequenceLogCompanion(
          hostId: const Value('host-1'),
          counter: const Value(7),
          status: Value(SyncSequenceStatus.requested.index),
          entryId: const Value('hint-entry'),
          payloadType: Value(SyncSequencePayloadType.journalEntity.index),
          createdAt: Value(DateTime(2024, 3, 15)),
          updatedAt: Value(DateTime(2024, 3, 15)),
        ),
      ]);

      final result = await database.getNearestCoveringEntry('host-1', 5);
      expect(result, isNull);
    });

    test('skips missing rows with entryId', () async {
      await database.batchInsertSequenceEntries([
        SyncSequenceLogCompanion(
          hostId: const Value('host-1'),
          counter: const Value(7),
          status: Value(SyncSequenceStatus.missing.index),
          entryId: const Value('hint-entry'),
          payloadType: Value(SyncSequencePayloadType.journalEntity.index),
          createdAt: Value(DateTime(2024, 3, 15)),
          updatedAt: Value(DateTime(2024, 3, 15)),
        ),
      ]);

      final result = await database.getNearestCoveringEntry('host-1', 5);
      expect(result, isNull);
    });

    test('skips rows without entryId', () async {
      await database.batchInsertSequenceEntries([
        SyncSequenceLogCompanion(
          hostId: const Value('host-1'),
          counter: const Value(7),
          status: Value(SyncSequenceStatus.received.index),
          payloadType: Value(SyncSequencePayloadType.journalEntity.index),
          createdAt: Value(DateTime(2024, 3, 15)),
          updatedAt: Value(DateTime(2024, 3, 15)),
        ),
      ]);

      final result = await database.getNearestCoveringEntry('host-1', 5);
      expect(result, isNull);
    });

    test('returns nearest (lowest counter) covering entry', () async {
      await database.batchInsertSequenceEntries([
        SyncSequenceLogCompanion(
          hostId: const Value('host-1'),
          counter: const Value(10),
          status: Value(SyncSequenceStatus.received.index),
          entryId: const Value('entry-10'),
          payloadType: Value(SyncSequencePayloadType.journalEntity.index),
          createdAt: Value(DateTime(2024, 3, 15)),
          updatedAt: Value(DateTime(2024, 3, 15)),
        ),
        SyncSequenceLogCompanion(
          hostId: const Value('host-1'),
          counter: const Value(7),
          status: Value(SyncSequenceStatus.received.index),
          entryId: const Value('entry-7'),
          payloadType: Value(SyncSequencePayloadType.journalEntity.index),
          createdAt: Value(DateTime(2024, 3, 15)),
          updatedAt: Value(DateTime(2024, 3, 15)),
        ),
      ]);

      final result = await database.getNearestCoveringEntry('host-1', 5);
      expect(result, isNotNull);
      expect(result!.counter, 7);
      expect(result.entryId, 'entry-7');
    });

    test('does not return entry for different host', () async {
      await database.batchInsertSequenceEntries([
        SyncSequenceLogCompanion(
          hostId: const Value('host-2'),
          counter: const Value(7),
          status: Value(SyncSequenceStatus.received.index),
          entryId: const Value('entry-7'),
          payloadType: Value(SyncSequencePayloadType.journalEntity.index),
          createdAt: Value(DateTime(2024, 3, 15)),
          updatedAt: Value(DateTime(2024, 3, 15)),
        ),
      ]);

      final result = await database.getNearestCoveringEntry('host-1', 5);
      expect(result, isNull);
    });

    test('does not return entry with counter below requested', () async {
      await database.batchInsertSequenceEntries([
        SyncSequenceLogCompanion(
          hostId: const Value('host-1'),
          counter: const Value(3),
          status: Value(SyncSequenceStatus.received.index),
          entryId: const Value('entry-3'),
          payloadType: Value(SyncSequencePayloadType.journalEntity.index),
          createdAt: Value(DateTime(2024, 3, 15)),
          updatedAt: Value(DateTime(2024, 3, 15)),
        ),
      ]);

      final result = await database.getNearestCoveringEntry('host-1', 5);
      expect(result, isNull);
    });

    test('skips lower requested row and returns higher received row', () async {
      await database.batchInsertSequenceEntries([
        SyncSequenceLogCompanion(
          hostId: const Value('host-1'),
          counter: const Value(7),
          status: Value(SyncSequenceStatus.requested.index),
          entryId: const Value('hint-entry'),
          payloadType: Value(SyncSequencePayloadType.journalEntity.index),
          createdAt: Value(DateTime(2024, 3, 15)),
          updatedAt: Value(DateTime(2024, 3, 15)),
        ),
        SyncSequenceLogCompanion(
          hostId: const Value('host-1'),
          counter: const Value(10),
          status: Value(SyncSequenceStatus.received.index),
          entryId: const Value('real-entry'),
          payloadType: Value(SyncSequencePayloadType.journalEntity.index),
          createdAt: Value(DateTime(2024, 3, 15)),
          updatedAt: Value(DateTime(2024, 3, 15)),
        ),
      ]);

      final result = await database.getNearestCoveringEntry('host-1', 5);
      expect(result, isNotNull);
      expect(result!.counter, 10);
      expect(result.entryId, 'real-entry');
    });
  });

  group('getPendingEntriesByPayloadId Tests', () {
    setUp(() async {
      db = SyncDatabase(inMemoryDatabase: true);
    });
    tearDown(() async {
      await db?.close();
    });

    test('returns empty list when no entries exist', () async {
      final database = db!;
      final entries = await database.getPendingEntriesByPayloadId(
        payloadType: SyncSequencePayloadType.journalEntity,
        payloadId: 'non-existent',
      );
      expect(entries, isEmpty);
    });

    test(
      'returns pending entries matching payloadType and payloadId',
      () async {
        final database = db!;
        const entryId = 'test-entry';
        final now = DateTime(2024, 1, 1);

        // Add pending entry with matching payload
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value('host-1'),
            counter: const Value(1),
            entryId: const Value(entryId),
            payloadType: Value(SyncSequencePayloadType.journalEntity.index),
            status: Value(SyncSequenceStatus.requested.index),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

        final entries = await database.getPendingEntriesByPayloadId(
          payloadType: SyncSequencePayloadType.journalEntity,
          payloadId: entryId,
        );
        expect(entries, hasLength(1));
        expect(entries.first.entryId, entryId);
      },
    );

    test('filters by payloadType - journalEntity vs entryLink', () async {
      final database = db!;
      const payloadId = 'shared-id';
      final now = DateTime(2024, 1, 1);

      // Add journalEntity entry
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value('host-1'),
          counter: const Value(1),
          entryId: const Value(payloadId),
          payloadType: Value(SyncSequencePayloadType.journalEntity.index),
          status: Value(SyncSequenceStatus.missing.index),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      // Add entryLink entry with same payloadId
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value('host-2'),
          counter: const Value(1),
          entryId: const Value(payloadId),
          payloadType: Value(SyncSequencePayloadType.entryLink.index),
          status: Value(SyncSequenceStatus.missing.index),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      // Query for journalEntity
      final journalEntries = await database.getPendingEntriesByPayloadId(
        payloadType: SyncSequencePayloadType.journalEntity,
        payloadId: payloadId,
      );
      expect(journalEntries, hasLength(1));
      expect(journalEntries.first.hostId, 'host-1');

      // Query for entryLink
      final linkEntries = await database.getPendingEntriesByPayloadId(
        payloadType: SyncSequencePayloadType.entryLink,
        payloadId: payloadId,
      );
      expect(linkEntries, hasLength(1));
      expect(linkEntries.first.hostId, 'host-2');
    });

    test('returns only missing or requested status entries', () async {
      final database = db!;
      const payloadId = 'test-entry';
      final now = DateTime(2024, 1, 1);

      // Add received entry (should not be returned)
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value('host-1'),
          counter: const Value(1),
          entryId: const Value(payloadId),
          payloadType: Value(SyncSequencePayloadType.journalEntity.index),
          status: Value(SyncSequenceStatus.received.index),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      // Add missing entry (should be returned)
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value('host-2'),
          counter: const Value(1),
          entryId: const Value(payloadId),
          payloadType: Value(SyncSequencePayloadType.journalEntity.index),
          status: Value(SyncSequenceStatus.missing.index),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      // Add requested entry (should be returned)
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value('host-3'),
          counter: const Value(1),
          entryId: const Value(payloadId),
          payloadType: Value(SyncSequencePayloadType.journalEntity.index),
          status: Value(SyncSequenceStatus.requested.index),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      // Add backfilled entry (should not be returned)
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value('host-4'),
          counter: const Value(1),
          entryId: const Value(payloadId),
          payloadType: Value(SyncSequencePayloadType.journalEntity.index),
          status: Value(SyncSequenceStatus.backfilled.index),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      // Add deleted entry (should not be returned)
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value('host-5'),
          counter: const Value(1),
          entryId: const Value(payloadId),
          payloadType: Value(SyncSequencePayloadType.journalEntity.index),
          status: Value(SyncSequenceStatus.deleted.index),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      final entries = await database.getPendingEntriesByPayloadId(
        payloadType: SyncSequencePayloadType.journalEntity,
        payloadId: payloadId,
      );
      expect(entries, hasLength(2));
      expect(
        entries.map((e) => e.hostId).toSet(),
        {'host-2', 'host-3'},
      );
    });

    test('returns multiple entries across different hosts', () async {
      final database = db!;
      const payloadId = 'link-id';
      final now = DateTime(2024, 1, 1);

      // Add entries from multiple hosts for the same payload
      for (var i = 1; i <= 3; i++) {
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: Value('host-$i'),
            counter: Value(i * 10),
            entryId: const Value(payloadId),
            payloadType: Value(SyncSequencePayloadType.entryLink.index),
            status: Value(SyncSequenceStatus.missing.index),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
      }

      final entries = await database.getPendingEntriesByPayloadId(
        payloadType: SyncSequencePayloadType.entryLink,
        payloadId: payloadId,
      );
      expect(entries, hasLength(3));
      expect(
        entries.map((e) => e.hostId).toSet(),
        {'host-1', 'host-2', 'host-3'},
      );
    });
  });

  group('Outbox Deduplication Methods', () {
    setUp(() async {
      db = SyncDatabase(inMemoryDatabase: true);
    });
    tearDown(() async {
      await db?.close();
    });

    test('findPendingByEntryId returns pending item for entry', () async {
      final database = db!;
      final now = DateTime(2024, 1, 1);

      // Add a pending item with entryId
      await database.addOutboxItem(
        OutboxCompanion(
          status: Value(OutboxStatus.pending.index),
          message: const Value('{"test": true}'),
          subject: const Value('test-subject'),
          createdAt: Value(now),
          updatedAt: Value(now),
          outboxEntryId: const Value('entry-123'),
        ),
      );

      final result = await database.findPendingByEntryId('entry-123');
      expect(result, isNotNull);
      expect(result!.outboxEntryId, 'entry-123');
      expect(result.message, '{"test": true}');
    });

    test('findPendingByEntryId returns null when no matching entry', () async {
      final database = db!;
      final now = DateTime(2024, 1, 1);

      // Add a pending item with different entryId
      await database.addOutboxItem(
        OutboxCompanion(
          status: Value(OutboxStatus.pending.index),
          message: const Value('{"test": true}'),
          subject: const Value('test-subject'),
          createdAt: Value(now),
          updatedAt: Value(now),
          outboxEntryId: const Value('entry-456'),
        ),
      );

      final result = await database.findPendingByEntryId('entry-123');
      expect(result, isNull);
    });

    test(
      'findPendingByEntryId returns null when entry is not pending',
      () async {
        final database = db!;
        final now = DateTime(2024, 1, 1);

        // Add a sent (non-pending) item with entryId
        await database.addOutboxItem(
          OutboxCompanion(
            status: Value(OutboxStatus.sent.index),
            message: const Value('{"test": true}'),
            subject: const Value('test-subject'),
            createdAt: Value(now),
            updatedAt: Value(now),
            outboxEntryId: const Value('entry-123'),
          ),
        );

        final result = await database.findPendingByEntryId('entry-123');
        expect(result, isNull);
      },
    );

    test(
      'findPendingByEntryId returns most recent when multiple exist',
      () async {
        final database = db!;

        // Add older item
        await database.addOutboxItem(
          OutboxCompanion(
            status: Value(OutboxStatus.pending.index),
            message: const Value('{"version": 1}'),
            subject: const Value('test-subject-old'),
            createdAt: Value(DateTime(2024, 1, 1)),
            updatedAt: Value(DateTime(2024, 1, 1)),
            outboxEntryId: const Value('entry-123'),
          ),
        );

        // Add newer item
        await database.addOutboxItem(
          OutboxCompanion(
            status: Value(OutboxStatus.pending.index),
            message: const Value('{"version": 2}'),
            subject: const Value('test-subject-new'),
            createdAt: Value(DateTime(2024, 1, 2)),
            updatedAt: Value(DateTime(2024, 1, 2)),
            outboxEntryId: const Value('entry-123'),
          ),
        );

        final result = await database.findPendingByEntryId('entry-123');
        expect(result, isNotNull);
        expect(result!.message, '{"version": 2}');
        expect(result.subject, 'test-subject-new');
      },
    );

    test('updateOutboxMessage updates message and subject', () async {
      final database = db!;
      final now = DateTime(2024, 1, 1);

      // Add an item
      final id = await database.addOutboxItem(
        OutboxCompanion(
          status: Value(OutboxStatus.pending.index),
          message: const Value('{"original": true}'),
          subject: const Value('original-subject'),
          createdAt: Value(now),
          updatedAt: Value(now),
          outboxEntryId: const Value('entry-123'),
        ),
      );

      // Update the item
      final rowsAffected = await database.updateOutboxMessage(
        itemId: id,
        newMessage: '{"updated": true}',
        newSubject: 'updated-subject',
      );

      expect(rowsAffected, 1);

      // Verify the update
      final items = await database.allOutboxItems;
      expect(items, hasLength(1));
      expect(items.first.message, '{"updated": true}');
      expect(items.first.subject, 'updated-subject');
      // updatedAt should be changed
      expect(items.first.updatedAt.isAfter(now), isTrue);
    });

    test('updateOutboxMessage returns 0 when item not found', () async {
      final database = db!;

      final rowsAffected = await database.updateOutboxMessage(
        itemId: 999,
        newMessage: '{"new": true}',
        newSubject: 'new-subject',
      );

      expect(rowsAffected, 0);
    });

    test('updateOutboxMessage updates payloadSize when provided', () async {
      final database = db!;
      final now = DateTime(2025, 3, 15, 10);

      await database.addOutboxItem(
        _buildOutbox(
          status: OutboxStatus.pending,
          createdAt: now,
          message: '{"data": "test"}',
        ),
      );

      final items = await database.allOutboxItems;
      expect(items, hasLength(1));

      await database.updateOutboxMessage(
        itemId: items.first.id,
        newMessage: '{"data": "updated"}',
        newSubject: 'updated',
        payloadSize: 12345,
      );

      final updatedItems = await database.allOutboxItems;
      expect(updatedItems.first.payloadSize, 12345);
    });
  });

  group('Payload size tracking -', () {
    setUp(() async {
      db = SyncDatabase(inMemoryDatabase: true);
    });
    tearDown(() async {
      await db?.close();
    });

    test('stores and retrieves payloadSize on outbox items', () async {
      final database = db!;
      final now = DateTime(2025, 3, 15, 10);

      await database.addOutboxItem(
        OutboxCompanion(
          status: Value(OutboxStatus.pending.index),
          subject: const Value('subject'),
          message: const Value('{"test": true}'),
          createdAt: Value(now),
          updatedAt: Value(now),
          payloadSize: const Value(4096),
        ),
      );

      final items = await database.allOutboxItems;
      expect(items, hasLength(1));
      expect(items.first.payloadSize, 4096);
    });

    test('payloadSize defaults to null when not provided', () async {
      final database = db!;
      final now = DateTime(2025, 3, 15, 10);

      await database.addOutboxItem(
        _buildOutbox(status: OutboxStatus.pending, createdAt: now),
      );

      final items = await database.allOutboxItems;
      expect(items, hasLength(1));
      expect(items.first.payloadSize, isNull);
    });

    test('getDailyOutboxVolume returns empty for no sent items', () async {
      final database = db!;
      final now = DateTime(2025, 3, 15, 10);

      final volumes = await database.getDailyOutboxVolume(now: now);
      expect(volumes, isEmpty);
    });

    test('getDailyOutboxVolume aggregates sent items by day', () async {
      final database = db!;
      final day1 = DateTime.utc(2025, 3, 14, 10);
      final day2 = DateTime.utc(2025, 3, 15, 8);
      final day2b = DateTime.utc(2025, 3, 15, 14);
      final now = DateTime.utc(2025, 3, 16);

      // Day 1: one item, 1000 bytes
      await database.addOutboxItem(
        OutboxCompanion(
          status: Value(OutboxStatus.sent.index),
          subject: const Value('s1'),
          message: const Value('m1'),
          createdAt: Value(day1),
          updatedAt: Value(day1),
          payloadSize: const Value(1000),
        ),
      );

      // Day 2: two items, 2000 + 3000 bytes
      await database.addOutboxItem(
        OutboxCompanion(
          status: Value(OutboxStatus.sent.index),
          subject: const Value('s2'),
          message: const Value('m2'),
          createdAt: Value(day2),
          updatedAt: Value(day2),
          payloadSize: const Value(2000),
        ),
      );
      await database.addOutboxItem(
        OutboxCompanion(
          status: Value(OutboxStatus.sent.index),
          subject: const Value('s3'),
          message: const Value('m3'),
          createdAt: Value(day2b),
          updatedAt: Value(day2b),
          payloadSize: const Value(3000),
        ),
      );

      final volumes = await database.getDailyOutboxVolume(now: now);
      expect(volumes, hasLength(2));

      // Day 1: 1 item, 1000 bytes
      expect(volumes[0].itemCount, 1);
      expect(volumes[0].totalBytes, 1000);

      // Day 2: 2 items, 5000 bytes
      expect(volumes[1].itemCount, 2);
      expect(volumes[1].totalBytes, 5000);
    });

    test('getDailyOutboxVolume excludes non-sent items', () async {
      final database = db!;
      final day = DateTime.utc(2025, 3, 15, 10);
      final now = DateTime.utc(2025, 3, 16);

      // Pending item - should not be included
      await database.addOutboxItem(
        OutboxCompanion(
          status: Value(OutboxStatus.pending.index),
          subject: const Value('s1'),
          message: const Value('m1'),
          createdAt: Value(day),
          updatedAt: Value(day),
          payloadSize: const Value(1000),
        ),
      );

      // Sent item - should be included
      await database.addOutboxItem(
        OutboxCompanion(
          status: Value(OutboxStatus.sent.index),
          subject: const Value('s2'),
          message: const Value('m2'),
          createdAt: Value(day),
          updatedAt: Value(day),
          payloadSize: const Value(2000),
        ),
      );

      final volumes = await database.getDailyOutboxVolume(now: now);
      expect(volumes, hasLength(1));
      expect(volumes.first.totalBytes, 2000);
      expect(volumes.first.itemCount, 1);
    });

    test('getDailyOutboxVolume respects days parameter', () async {
      final database = db!;
      final now = DateTime.utc(2025, 3, 20);
      final recent = DateTime.utc(2025, 3, 19, 10);
      final old = DateTime.utc(2025, 3, 10, 10);

      // Old item - outside 7-day window
      await database.addOutboxItem(
        OutboxCompanion(
          status: Value(OutboxStatus.sent.index),
          subject: const Value('old'),
          message: const Value('m'),
          createdAt: Value(old),
          updatedAt: Value(old),
          payloadSize: const Value(1000),
        ),
      );

      // Recent item - within 7-day window
      await database.addOutboxItem(
        OutboxCompanion(
          status: Value(OutboxStatus.sent.index),
          subject: const Value('recent'),
          message: const Value('m'),
          createdAt: Value(recent),
          updatedAt: Value(recent),
          payloadSize: const Value(2000),
        ),
      );

      final volumes = await database.getDailyOutboxVolume(now: now);
      expect(volumes, hasLength(1));
      expect(volumes.first.totalBytes, 2000);

      // With larger window, both should appear
      final allVolumes = await database.getDailyOutboxVolume(
        days: 30,
        now: now,
      );
      expect(allVolumes, hasLength(2));
    });

    test('getDailyOutboxVolume treats null payloadSize as zero', () async {
      final database = db!;
      final day = DateTime.utc(2025, 3, 15, 10);
      final now = DateTime.utc(2025, 3, 16);

      await database.addOutboxItem(
        OutboxCompanion(
          status: Value(OutboxStatus.sent.index),
          subject: const Value('s1'),
          message: const Value('m1'),
          createdAt: Value(day),
          updatedAt: Value(day),
          // No payloadSize - should be treated as 0
        ),
      );

      final volumes = await database.getDailyOutboxVolume(now: now);
      expect(volumes, hasLength(1));
      expect(volumes.first.totalBytes, 0);
      expect(volumes.first.itemCount, 1);
    });

    test('OutboxDailyVolume totalMegabytes computes correctly', () async {
      final database = db!;
      final day = DateTime.utc(2025, 3, 15, 10);
      final now = DateTime.utc(2025, 3, 16);

      await database.addOutboxItem(
        OutboxCompanion(
          status: Value(OutboxStatus.sent.index),
          subject: const Value('s1'),
          message: const Value('m1'),
          createdAt: Value(day),
          updatedAt: Value(day),
          payloadSize: const Value(1048576), // exactly 1 MB
        ),
      );

      final volumes = await database.getDailyOutboxVolume(now: now);
      expect(volumes.first.totalMegabytes, closeTo(1.0, 0.001));
    });
  });

  group('Payload size column behavior -', () {
    late SyncDatabase db;

    setUp(() async {
      db = SyncDatabase(inMemoryDatabase: true);
    });
    tearDown(() async {
      await db.close();
    });

    test('payloadSize defaults to null when omitted', () async {
      final now = DateTime(2025, 3, 15, 10);
      await db.addOutboxItem(
        OutboxCompanion(
          status: Value(OutboxStatus.pending.index),
          subject: const Value('subject'),
          message: const Value('{"old": true}'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      final items = await db.allOutboxItems;
      expect(items, hasLength(1));
      expect(items.first.payloadSize, isNull);
    });

    test('updateOutboxMessage writes payloadSize to existing row', () async {
      final now = DateTime(2025, 3, 15, 10);
      await db.addOutboxItem(
        OutboxCompanion(
          status: Value(OutboxStatus.pending.index),
          subject: const Value('subject'),
          message: const Value('{"old": true}'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      final items = await db.allOutboxItems;
      await db.updateOutboxMessage(
        itemId: items.first.id,
        newMessage: '{"updated": true}',
        newSubject: 'updated-subject',
        payloadSize: 9999,
      );

      final updated = await db.allOutboxItems;
      expect(updated.first.payloadSize, 9999);
    });

    test('schema version is 17', () {
      expect(db.schemaVersion, 19);
    });

    test(
      'OutboxStatus indices used by the partial-index annotation '
      'on the Outbox table stay aligned with the enum — `@TableIndex.sql` '
      'is a const-string annotation that cannot reference the enum at '
      'compile time, so the literals (0, 3) used in '
      '`idx_outbox_actionable_priority_created_at` would silently '
      'index the wrong rows if `OutboxStatus` were ever reordered. '
      'This guard fails loudly instead.',
      () {
        expect(
          OutboxStatus.pending.index,
          0,
          reason:
              'pending must be index 0 — used as a literal in the '
              'partial-index WHERE clause.',
        );
        expect(
          OutboxStatus.sending.index,
          3,
          reason:
              'sending must be index 3 — used as a literal in the '
              'partial-index WHERE clause and as `_outboxSendingStatus` '
              'in sync_db.dart.',
        );
      },
    );
  });

  group('Outbox Polling Ordering - ', () {
    late SyncDatabase database;

    setUp(() async {
      database = SyncDatabase(inMemoryDatabase: true);
    });

    tearDown(() async {
      await database.close();
    });

    test(
      'oldestOutboxItems returns items in createdAt order regardless of priority',
      () async {
        // Insert low-priority item first (older)
        await database.addOutboxItem(
          OutboxCompanion(
            status: Value(OutboxStatus.pending.index),
            subject: const Value('low-old'),
            message: const Value('{}'),
            createdAt: Value(DateTime(2024, 1, 1, 10)),
            updatedAt: Value(DateTime(2024, 1, 1, 10)),
            priority: Value(OutboxPriority.low.index),
          ),
        );

        // Insert high-priority item second (newer)
        await database.addOutboxItem(
          OutboxCompanion(
            status: Value(OutboxStatus.pending.index),
            subject: const Value('high-new'),
            message: const Value('{}'),
            createdAt: Value(DateTime(2024, 1, 1, 12)),
            updatedAt: Value(DateTime(2024, 1, 1, 12)),
            priority: Value(OutboxPriority.high.index),
          ),
        );

        // Insert normal-priority item (middle time)
        await database.addOutboxItem(
          OutboxCompanion(
            status: Value(OutboxStatus.pending.index),
            subject: const Value('normal-mid'),
            message: const Value('{}'),
            createdAt: Value(DateTime(2024, 1, 1, 11)),
            updatedAt: Value(DateTime(2024, 1, 1, 11)),
            priority: Value(OutboxPriority.normal.index),
          ),
        );

        final items = await database.oldestOutboxItems(10);
        expect(items, hasLength(3));
        expect(items[0].subject, 'low-old');
        expect(items[1].subject, 'normal-mid');
        expect(items[2].subject, 'high-new');
      },
    );

    test(
      'claimNextOutboxItem claims oldest item first regardless of priority',
      () async {
        // Insert low-priority item first (older)
        await database.addOutboxItem(
          OutboxCompanion(
            status: Value(OutboxStatus.pending.index),
            subject: const Value('low-old'),
            message: const Value('{}'),
            createdAt: Value(DateTime(2024, 1, 1, 10)),
            updatedAt: Value(DateTime(2024, 1, 1, 10)),
            priority: Value(OutboxPriority.low.index),
          ),
        );

        // Insert high-priority item second (newer)
        await database.addOutboxItem(
          OutboxCompanion(
            status: Value(OutboxStatus.pending.index),
            subject: const Value('high-new'),
            message: const Value('{}'),
            createdAt: Value(DateTime(2024, 1, 1, 12)),
            updatedAt: Value(DateTime(2024, 1, 1, 12)),
            priority: Value(OutboxPriority.high.index),
          ),
        );

        final claimed = await database.claimNextOutboxItem(
          now: DateTime(2024, 1, 1, 13),
        );

        expect(claimed, isNotNull);
        expect(claimed!.subject, 'low-old');
      },
    );

    test('within same priority, oldest item is processed first', () async {
      await database.addOutboxItem(
        OutboxCompanion(
          status: Value(OutboxStatus.pending.index),
          subject: const Value('normal-newer'),
          message: const Value('{}'),
          createdAt: Value(DateTime(2024, 1, 1, 12)),
          updatedAt: Value(DateTime(2024, 1, 1, 12)),
          priority: Value(OutboxPriority.normal.index),
        ),
      );

      await database.addOutboxItem(
        OutboxCompanion(
          status: Value(OutboxStatus.pending.index),
          subject: const Value('normal-older'),
          message: const Value('{}'),
          createdAt: Value(DateTime(2024, 1, 1, 10)),
          updatedAt: Value(DateTime(2024, 1, 1, 10)),
          priority: Value(OutboxPriority.normal.index),
        ),
      );

      final items = await database.oldestOutboxItems(10);
      expect(items, hasLength(2));
      expect(items[0].subject, 'normal-older');
      expect(items[1].subject, 'normal-newer');
    });

    test('default priority is low when not specified', () async {
      await database.addOutboxItem(
        OutboxCompanion(
          status: Value(OutboxStatus.pending.index),
          subject: const Value('default-priority'),
          message: const Value('{}'),
          createdAt: Value(DateTime(2024, 1, 1)),
          updatedAt: Value(DateTime(2024, 1, 1)),
        ),
      );

      final items = await database.oldestOutboxItems(10);
      expect(items, hasLength(1));
      expect(items.first.priority, OutboxPriority.low.index);
    });

    test(
      'watchOutboxItems sorts by priority then newest within priority',
      () async {
        // Add items in mixed order
        await database.addOutboxItem(
          OutboxCompanion(
            status: Value(OutboxStatus.pending.index),
            subject: const Value('low-1'),
            message: const Value('{}'),
            createdAt: Value(DateTime(2024, 1, 1, 10)),
            updatedAt: Value(DateTime(2024, 1, 1, 10)),
            priority: Value(OutboxPriority.low.index),
          ),
        );
        await database.addOutboxItem(
          OutboxCompanion(
            status: Value(OutboxStatus.pending.index),
            subject: const Value('high-1'),
            message: const Value('{}'),
            createdAt: Value(DateTime(2024, 1, 1, 11)),
            updatedAt: Value(DateTime(2024, 1, 1, 11)),
            priority: Value(OutboxPriority.high.index),
          ),
        );
        await database.addOutboxItem(
          OutboxCompanion(
            status: Value(OutboxStatus.pending.index),
            subject: const Value('high-2'),
            message: const Value('{}'),
            createdAt: Value(DateTime(2024, 1, 1, 12)),
            updatedAt: Value(DateTime(2024, 1, 1, 12)),
            priority: Value(OutboxPriority.high.index),
          ),
        );

        final items = await database.watchOutboxItems().first;
        expect(items, hasLength(3));
        // High priority first, newest within priority (DESC)
        expect(items[0].subject, 'high-2');
        expect(items[1].subject, 'high-1');
        expect(items[2].subject, 'low-1');
      },
    );

    test('health query helpers return correct counts', () async {
      // Add sequence log entries with various statuses
      final now = DateTime(2024, 1, 1, 12);
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value('host-a'),
          counter: const Value(1),
          status: Value(SyncSequenceStatus.missing.index),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value('host-a'),
          counter: const Value(2),
          status: Value(SyncSequenceStatus.missing.index),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value('host-a'),
          counter: const Value(3),
          status: Value(SyncSequenceStatus.requested.index),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value('host-a'),
          counter: const Value(4),
          status: Value(SyncSequenceStatus.received.index),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      expect(await database.getMissingSequenceCount(), 2);
      expect(await database.getRequestedSequenceCount(), 1);

      // Add sent outbox item
      await database.addOutboxItem(
        OutboxCompanion(
          status: Value(OutboxStatus.sent.index),
          subject: const Value('sent-item'),
          message: const Value('{}'),
          createdAt: Value(DateTime(2024, 1, 1, 11)),
          updatedAt: Value(DateTime(2024, 1, 1, 11, 30)),
        ),
      );

      final sentCount = await database.getSentCountSince(
        DateTime(2024, 1, 1, 11),
      );
      expect(sentCount, 1);

      final sentCountNone = await database.getSentCountSince(
        DateTime(2024, 1, 1, 12),
      );
      expect(sentCountNone, 0);
    });
  });

  group('resetUnresolvableWithKnownPayload', () {
    late SyncDatabase database;

    setUp(() async {
      database = SyncDatabase(inMemoryDatabase: true);
    });

    tearDown(() async {
      await database.close();
    });

    test('resets unresolvable entries with known entryId to missing', () async {
      final now = DateTime(2024, 3, 15);

      // Insert an unresolvable entry WITH entryId (should be reset)
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value('host-a'),
          counter: const Value(5),
          entryId: const Value('known-entry'),
          payloadType: Value(SyncSequencePayloadType.journalEntity.index),
          status: Value(SyncSequenceStatus.unresolvable.index),
          createdAt: Value(now),
          updatedAt: Value(now),
          requestCount: const Value(3),
        ),
      );

      // Insert an unresolvable entry WITHOUT entryId (should NOT be reset)
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value('host-a'),
          counter: const Value(6),
          payloadType: Value(SyncSequencePayloadType.journalEntity.index),
          status: Value(SyncSequenceStatus.unresolvable.index),
          createdAt: Value(now),
          updatedAt: Value(now),
          requestCount: const Value(2),
        ),
      );

      // Insert a received entry (should NOT be affected)
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value('host-a'),
          counter: const Value(7),
          entryId: const Value('another-entry'),
          payloadType: Value(SyncSequencePayloadType.journalEntity.index),
          status: Value(SyncSequenceStatus.received.index),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      final resetCount = await database.resetUnresolvableWithKnownPayload();

      expect(resetCount, 1);

      // Verify the reset entry
      final resetEntry = await database.getEntryByHostAndCounter('host-a', 5);
      expect(resetEntry, isNotNull);
      expect(resetEntry!.status, SyncSequenceStatus.missing.index);
      expect(resetEntry.requestCount, 0);

      // Verify the unresolvable without entryId was NOT reset
      final unchanged = await database.getEntryByHostAndCounter('host-a', 6);
      expect(unchanged, isNotNull);
      expect(unchanged!.status, SyncSequenceStatus.unresolvable.index);

      // Verify the received entry was NOT affected
      final received = await database.getEntryByHostAndCounter('host-a', 7);
      expect(received, isNotNull);
      expect(received!.status, SyncSequenceStatus.received.index);
    });

    test('returns 0 when no unresolvable entries exist', () async {
      final database = SyncDatabase(inMemoryDatabase: true);
      addTearDown(database.close);

      final resetCount = await database.resetUnresolvableWithKnownPayload();
      expect(resetCount, 0);
    });
  });

  group('resetAllUnresolvableEntries', () {
    late SyncDatabase database;

    setUp(() async {
      database = SyncDatabase(inMemoryDatabase: true);
    });

    tearDown(() async {
      await database.close();
    });

    test(
      'resets every unresolvable entry back to missing, including rows '
      'without entryId — the key case where the originating host is dead '
      'but currently-alive peers may still have the payload',
      () async {
        final now = DateTime(2026, 4, 22);
        final old = now.subtract(const Duration(days: 30));

        // Unresolvable WITHOUT entryId — resetUnresolvableWithKnownPayload
        // skips this; this method must flip it.
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value('dead-host'),
            counter: const Value(1),
            payloadType: Value(SyncSequencePayloadType.journalEntity.index),
            status: Value(SyncSequenceStatus.unresolvable.index),
            createdAt: Value(old),
            updatedAt: Value(old),
            requestCount: const Value(2),
            lastRequestedAt: Value(old),
          ),
        );

        // Unresolvable WITH entryId — also flipped (for completeness;
        // this is the superset of resetUnresolvableWithKnownPayload).
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value('dead-host'),
            counter: const Value(2),
            entryId: const Value('known-entry'),
            payloadType: Value(SyncSequencePayloadType.journalEntity.index),
            status: Value(SyncSequenceStatus.unresolvable.index),
            createdAt: Value(old),
            updatedAt: Value(old),
            requestCount: const Value(5),
          ),
        );

        // Received entry must NOT be touched.
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value('dead-host'),
            counter: const Value(3),
            entryId: const Value('received-entry'),
            payloadType: Value(SyncSequencePayloadType.journalEntity.index),
            status: Value(SyncSequenceStatus.received.index),
            createdAt: Value(old),
            updatedAt: Value(old),
          ),
        );

        final reset = await database.resetAllUnresolvableEntries();
        expect(reset, 2);

        final r1 = await database.getEntryByHostAndCounter('dead-host', 1);
        expect(r1!.status, SyncSequenceStatus.missing.index);
        expect(r1.requestCount, 0);
        expect(r1.lastRequestedAt, isNull);

        final r2 = await database.getEntryByHostAndCounter('dead-host', 2);
        expect(r2!.status, SyncSequenceStatus.missing.index);
        expect(r2.requestCount, 0);

        final r3 = await database.getEntryByHostAndCounter('dead-host', 3);
        expect(r3!.status, SyncSequenceStatus.received.index);
      },
    );

    test('returns 0 when no unresolvable rows exist', () async {
      final reset = await database.resetAllUnresolvableEntries();
      expect(reset, 0);
    });
  });

  group('retireExhaustedRequestedEntries', () {
    late SyncDatabase database;

    setUp(() async {
      database = SyncDatabase(inMemoryDatabase: true);
    });

    tearDown(() async {
      await database.close();
    });

    test(
      'retires missing and requested rows at or above the request-count cap '
      'whose last backfill request is older than the grace window, and '
      'leaves other statuses untouched',
      () async {
        final now = DateTime(2024, 3, 15);
        final longAgo = now.subtract(const Duration(hours: 1));

        // Missing at the cap, last request comfortably past the grace
        // window — should retire.
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value('host-a'),
            counter: const Value(1),
            payloadType: Value(SyncSequencePayloadType.journalEntity.index),
            status: Value(SyncSequenceStatus.missing.index),
            createdAt: Value(now),
            updatedAt: Value(now),
            requestCount: const Value(10),
            lastRequestedAt: Value(longAgo),
          ),
        );

        // Requested above the cap — should retire.
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value('host-a'),
            counter: const Value(2),
            entryId: const Value('hint-entry'),
            payloadType: Value(SyncSequencePayloadType.journalEntity.index),
            status: Value(SyncSequenceStatus.requested.index),
            createdAt: Value(now),
            updatedAt: Value(now),
            requestCount: const Value(15),
            lastRequestedAt: Value(longAgo),
          ),
        );

        // Missing but below the cap — must stay missing.
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value('host-a'),
            counter: const Value(3),
            payloadType: Value(SyncSequencePayloadType.journalEntity.index),
            status: Value(SyncSequenceStatus.missing.index),
            createdAt: Value(now),
            updatedAt: Value(now),
            requestCount: const Value(4),
            lastRequestedAt: Value(longAgo),
          ),
        );

        // Received row at/above the cap — must not be touched.
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value('host-a'),
            counter: const Value(4),
            entryId: const Value('received-entry'),
            payloadType: Value(SyncSequencePayloadType.journalEntity.index),
            status: Value(SyncSequenceStatus.received.index),
            createdAt: Value(now),
            updatedAt: Value(now),
            requestCount: const Value(20),
            lastRequestedAt: Value(longAgo),
          ),
        );

        final retired = await database.retireExhaustedRequestedEntries(
          now: now,
        );

        expect(retired, 2);
        expect(
          (await database.getEntryByHostAndCounter('host-a', 1))!.status,
          SyncSequenceStatus.unresolvable.index,
        );
        expect(
          (await database.getEntryByHostAndCounter('host-a', 2))!.status,
          SyncSequenceStatus.unresolvable.index,
        );
        expect(
          (await database.getEntryByHostAndCounter('host-a', 3))!.status,
          SyncSequenceStatus.missing.index,
        );
        expect(
          (await database.getEntryByHostAndCounter('host-a', 4))!.status,
          SyncSequenceStatus.received.index,
        );
      },
    );

    test(
      'does not retire a row whose last backfill request is still within '
      'the grace window — the in-flight response deserves a chance to land',
      () async {
        final now = DateTime(2024, 3, 15);

        // At the cap but requested 30s ago, well inside the 5-minute grace.
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value('host-grace'),
            counter: const Value(1),
            payloadType: Value(SyncSequencePayloadType.journalEntity.index),
            status: Value(SyncSequenceStatus.requested.index),
            createdAt: Value(now),
            updatedAt: Value(now),
            requestCount: const Value(10),
            lastRequestedAt: Value(
              now.subtract(const Duration(seconds: 30)),
            ),
          ),
        );

        final retired = await database.retireExhaustedRequestedEntries(
          now: now,
        );

        expect(retired, 0);
        expect(
          (await database.getEntryByHostAndCounter('host-grace', 1))!.status,
          SyncSequenceStatus.requested.index,
        );
      },
    );

    test(
      'retires rows whose last_requested_at was set by '
      'batchIncrementRequestCounts (end-to-end timestamp-encoding regression)',
      () async {
        // Regression for the ms/seconds encoding mismatch:
        // `batchIncrementRequestCounts` used to write raw
        // `millisecondsSinceEpoch`, while `retireExhaustedRequestedEntries`
        // compares against Drift's default seconds-encoded DateTime. The two
        // silently disagreed by a factor of 1000, so rows requested via the
        // real production path could never qualify for retirement regardless
        // of how old they were.
        const hostId = 'host-ms-regression';
        const counter = 1;
        // Seed a missing row that we then drive through the real request
        // path `batchIncrementRequestCounts` exactly as the backfill service
        // does.
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value(hostId),
            counter: const Value(counter),
            payloadType: Value(SyncSequencePayloadType.journalEntity.index),
            status: Value(SyncSequenceStatus.missing.index),
            createdAt: Value(DateTime(2020)),
            updatedAt: Value(DateTime(2020)),
            requestCount: const Value(9),
          ),
        );

        // Bump to request_count == 10 via the production path and stamp
        // last_requested_at with DateTime.now() (the method's own clock).
        await database.batchIncrementRequestCounts([
          (hostId: hostId, counter: counter),
        ]);

        final afterIncrement = await database.getEntryByHostAndCounter(
          hostId,
          counter,
        );
        expect(afterIncrement!.requestCount, 10);
        expect(afterIncrement.status, SyncSequenceStatus.requested.index);
        expect(afterIncrement.lastRequestedAt, isNotNull);
        // The roundtripped value must be readable as a sane 2020-or-later
        // DateTime — if encoding was in ms, Drift's seconds-decoded column
        // would report a year ~53700.
        expect(
          afterIncrement.lastRequestedAt!.year,
          inInclusiveRange(2020, 2100),
        );

        // Advance the caller's clock past the grace window and run retire.
        final futureNow = afterIncrement.lastRequestedAt!.add(
          const Duration(hours: 2),
        );
        final retired = await database.retireExhaustedRequestedEntries(
          now: futureNow,
        );
        expect(retired, 1);
        expect(
          (await database.getEntryByHostAndCounter(hostId, counter))!.status,
          SyncSequenceStatus.unresolvable.index,
        );
      },
    );

    test(
      'does not retire a row with no recorded last_requested_at — we have '
      'no evidence a request ever reached the outbox',
      () async {
        final now = DateTime(2024, 3, 15);

        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value('host-null'),
            counter: const Value(1),
            payloadType: Value(SyncSequencePayloadType.journalEntity.index),
            status: Value(SyncSequenceStatus.missing.index),
            createdAt: Value(now),
            updatedAt: Value(now),
            requestCount: const Value(12),
          ),
        );

        final retired = await database.retireExhaustedRequestedEntries(
          now: now,
        );
        expect(retired, 0);
        expect(
          (await database.getEntryByHostAndCounter('host-null', 1))!.status,
          SyncSequenceStatus.missing.index,
        );
      },
    );

    test(
      'advances the contiguous watermark by retiring pre-history gaps',
      () async {
        final now = DateTime(2024, 3, 15);
        const hostId = 'host-b';

        // Contiguous resolved prefix: counters 1..10 all received.
        for (var i = 1; i <= 10; i++) {
          await database.recordSequenceEntry(
            SyncSequenceLogCompanion(
              hostId: const Value(hostId),
              counter: Value(i),
              entryId: Value('entry-$i'),
              payloadType: Value(SyncSequencePayloadType.journalEntity.index),
              status: Value(SyncSequenceStatus.received.index),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
        }
        // Permanently stuck missing range 11..15, each at the request cap
        // and with a `lastRequestedAt` older than the grace window.
        final longAgo = now.subtract(const Duration(hours: 1));
        for (var i = 11; i <= 15; i++) {
          await database.recordSequenceEntry(
            SyncSequenceLogCompanion(
              hostId: const Value(hostId),
              counter: Value(i),
              payloadType: Value(SyncSequencePayloadType.journalEntity.index),
              status: Value(SyncSequenceStatus.missing.index),
              createdAt: Value(now),
              updatedAt: Value(now),
              requestCount: const Value(10),
              lastRequestedAt: Value(longAgo),
            ),
          );
        }
        // Row beyond the gap, received.
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value(hostId),
            counter: const Value(16),
            entryId: const Value('entry-16'),
            payloadType: Value(SyncSequencePayloadType.journalEntity.index),
            status: Value(SyncSequenceStatus.received.index),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

        expect(await database.getLastCounterForHost(hostId), 10);

        final retired = await database.retireExhaustedRequestedEntries(
          now: now,
        );
        expect(retired, 5);

        // With the stuck missing range flipped to `unresolvable` (a terminal
        // status included in the contiguous-prefix computation), the watermark
        // should now advance all the way past the retired range.
        expect(await database.getLastCounterForHost(hostId), 16);
      },
    );

    test('returns 0 when there is nothing to retire', () async {
      final retired = await database.retireExhaustedRequestedEntries();
      expect(retired, 0);
    });

    test(
      'retires backlogs larger than pageSize across multiple pages — '
      'capping per-transaction lock hold without losing rows',
      () async {
        final now = DateTime(2024, 3, 15);
        final longAgo = now.subtract(const Duration(hours: 1));
        const totalRows = 17;
        for (var counter = 1; counter <= totalRows; counter++) {
          await database.recordSequenceEntry(
            SyncSequenceLogCompanion(
              hostId: const Value('host-bulk'),
              counter: Value(counter),
              payloadType: Value(SyncSequencePayloadType.journalEntity.index),
              status: Value(SyncSequenceStatus.missing.index),
              createdAt: Value(now),
              updatedAt: Value(now),
              requestCount: const Value(10),
              lastRequestedAt: Value(longAgo),
            ),
          );
        }

        final retired = await database.retireExhaustedRequestedEntries(
          now: now,
          pageSize: 5,
        );

        expect(retired, totalRows);
        for (var counter = 1; counter <= totalRows; counter++) {
          expect(
            (await database.getEntryByHostAndCounter(
              'host-bulk',
              counter,
            ))!.status,
            SyncSequenceStatus.unresolvable.index,
            reason: 'row $counter should have been retired',
          );
        }
      },
    );
  });

  group('retireAgedOutRequestedEntries', () {
    late SyncDatabase database;

    setUp(() async {
      database = SyncDatabase(inMemoryDatabase: true);
    });

    tearDown(() async {
      await database.close();
    });

    test(
      'retires missing/requested rows older than amnestyWindow regardless of '
      'request_count, leaving fresh rows and other statuses untouched',
      () async {
        final now = DateTime(2026, 4, 22);
        final longAgo = now.subtract(const Duration(days: 14));
        final recent = now.subtract(const Duration(hours: 6));

        // Aged-out `missing` row with request_count=0 — exactly the case
        // that the exhausted-retire refuses (last_requested_at IS NULL,
        // request_count below cap) and that
        // `getMissingEntriesWithLimits` also ignores (older than
        // maxAge). Must retire here.
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value('host-a'),
            counter: const Value(1),
            payloadType: Value(SyncSequencePayloadType.journalEntity.index),
            status: Value(SyncSequenceStatus.missing.index),
            createdAt: Value(longAgo),
            updatedAt: Value(longAgo),
          ),
        );

        // Aged-out `requested` row born via backfill-response-hint path
        // (request_count > 0 but last_requested_at never set). This
        // reproduces the exact stuck-row profile observed on both
        // desktop and mobile sync DBs.
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value('host-a'),
            counter: const Value(2),
            entryId: const Value('hint-entry'),
            payloadType: Value(SyncSequencePayloadType.journalEntity.index),
            status: Value(SyncSequenceStatus.requested.index),
            createdAt: Value(longAgo),
            updatedAt: Value(longAgo),
            requestCount: const Value(3),
          ),
        );

        // Recent `missing` row — still inside amnesty window, must NOT
        // retire; let the normal backfill sweep handle it.
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value('host-a'),
            counter: const Value(3),
            payloadType: Value(SyncSequencePayloadType.journalEntity.index),
            status: Value(SyncSequenceStatus.missing.index),
            createdAt: Value(recent),
            updatedAt: Value(recent),
          ),
        );

        // Aged-out `received` row — must not be touched, ever.
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value('host-a'),
            counter: const Value(4),
            entryId: const Value('received-entry'),
            payloadType: Value(SyncSequencePayloadType.journalEntity.index),
            status: Value(SyncSequenceStatus.received.index),
            createdAt: Value(longAgo),
            updatedAt: Value(longAgo),
          ),
        );

        // Aged-out `backfilled` row — must not be touched.
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value('host-a'),
            counter: const Value(5),
            entryId: const Value('backfilled-entry'),
            payloadType: Value(SyncSequencePayloadType.journalEntity.index),
            status: Value(SyncSequenceStatus.backfilled.index),
            createdAt: Value(longAgo),
            updatedAt: Value(longAgo),
          ),
        );

        final retired = await database.retireAgedOutRequestedEntries(
          amnestyWindow: const Duration(days: 7),
          now: now,
        );

        expect(retired, 2);
        expect(
          (await database.getEntryByHostAndCounter('host-a', 1))!.status,
          SyncSequenceStatus.unresolvable.index,
        );
        expect(
          (await database.getEntryByHostAndCounter('host-a', 2))!.status,
          SyncSequenceStatus.unresolvable.index,
        );
        expect(
          (await database.getEntryByHostAndCounter('host-a', 3))!.status,
          SyncSequenceStatus.missing.index,
        );
        expect(
          (await database.getEntryByHostAndCounter('host-a', 4))!.status,
          SyncSequenceStatus.received.index,
        );
        expect(
          (await database.getEntryByHostAndCounter('host-a', 5))!.status,
          SyncSequenceStatus.backfilled.index,
        );
      },
    );

    test(
      'unblocks the watermark so getLastCounterForHost advances past the '
      'retired range — the load-bearing reason for this retire path',
      () async {
        final now = DateTime(2026, 4, 22);
        final longAgo = now.subtract(const Duration(days: 14));

        const hostId = 'host-stuck';
        // Counters 1..5 received — contiguous prefix starts here.
        for (var counter = 1; counter <= 5; counter++) {
          await database.recordSequenceEntry(
            SyncSequenceLogCompanion(
              hostId: const Value(hostId),
              counter: Value(counter),
              payloadType: Value(SyncSequencePayloadType.journalEntity.index),
              status: Value(SyncSequenceStatus.received.index),
              createdAt: Value(longAgo),
              updatedAt: Value(longAgo),
            ),
          );
        }
        // Counters 6..8 stuck in `requested` — the watermark-blocking
        // rows observed in the real DBs.
        for (var counter = 6; counter <= 8; counter++) {
          await database.recordSequenceEntry(
            SyncSequenceLogCompanion(
              hostId: const Value(hostId),
              counter: Value(counter),
              payloadType: Value(SyncSequencePayloadType.journalEntity.index),
              status: Value(SyncSequenceStatus.requested.index),
              createdAt: Value(longAgo),
              updatedAt: Value(longAgo),
              requestCount: const Value(3),
            ),
          );
        }
        // Counters 9..12 received — watermark cannot reach these
        // until 6..8 are retired.
        for (var counter = 9; counter <= 12; counter++) {
          await database.recordSequenceEntry(
            SyncSequenceLogCompanion(
              hostId: const Value(hostId),
              counter: Value(counter),
              payloadType: Value(SyncSequencePayloadType.journalEntity.index),
              status: Value(SyncSequenceStatus.received.index),
              createdAt: Value(longAgo),
              updatedAt: Value(longAgo),
            ),
          );
        }

        expect(await database.getLastCounterForHost(hostId), 5);

        final retired = await database.retireAgedOutRequestedEntries(
          amnestyWindow: const Duration(days: 7),
          now: now,
        );
        expect(retired, 3);

        // Watermark now advances through the retired `unresolvable`
        // range (6..8) and onward through the contiguous received prefix
        // (9..12), unblocking gap detection for this host.
        expect(await database.getLastCounterForHost(hostId), 12);
      },
    );

    test(
      'uses updated_at (not created_at) so a row just reopened by '
      'resetAllUnresolvableEntries survives the next retire sweep — '
      'without this the reset→retire cycle races',
      () async {
        final now = DateTime(2026, 4, 22);
        final longAgo = now.subtract(const Duration(days: 30));
        final justReopened = now.subtract(const Duration(hours: 1));

        // Row created 30 days ago but `updated_at` just refreshed
        // (simulating resetAllUnresolvableEntries flipping it back to
        // missing). Must NOT be retired.
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value('host-a'),
            counter: const Value(1),
            payloadType: Value(SyncSequencePayloadType.journalEntity.index),
            status: Value(SyncSequenceStatus.missing.index),
            createdAt: Value(longAgo),
            updatedAt: Value(justReopened),
          ),
        );

        // Control: row created AND last-updated 30 days ago — must retire.
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value('host-a'),
            counter: const Value(2),
            payloadType: Value(SyncSequencePayloadType.journalEntity.index),
            status: Value(SyncSequenceStatus.missing.index),
            createdAt: Value(longAgo),
            updatedAt: Value(longAgo),
          ),
        );

        final retired = await database.retireAgedOutRequestedEntries(
          amnestyWindow: const Duration(days: 7),
          now: now,
        );
        expect(retired, 1);

        final reopened = await database.getEntryByHostAndCounter('host-a', 1);
        expect(reopened!.status, SyncSequenceStatus.missing.index);

        final oldRow = await database.getEntryByHostAndCounter('host-a', 2);
        expect(oldRow!.status, SyncSequenceStatus.unresolvable.index);
      },
    );

    test('returns 0 when there is nothing to retire', () async {
      final retired = await database.retireAgedOutRequestedEntries();
      expect(retired, 0);
    });

    test(
      'retires backlogs larger than pageSize across multiple pages — '
      'capping per-transaction lock hold without losing rows',
      () async {
        final now = DateTime(2026, 4, 22);
        final longAgo = now.subtract(const Duration(days: 14));
        const totalRows = 13;
        for (var counter = 1; counter <= totalRows; counter++) {
          await database.recordSequenceEntry(
            SyncSequenceLogCompanion(
              hostId: const Value('host-bulk'),
              counter: Value(counter),
              payloadType: Value(SyncSequencePayloadType.journalEntity.index),
              status: Value(SyncSequenceStatus.missing.index),
              createdAt: Value(longAgo),
              updatedAt: Value(longAgo),
            ),
          );
        }

        final retired = await database.retireAgedOutRequestedEntries(
          amnestyWindow: const Duration(days: 7),
          now: now,
          pageSize: 4,
        );

        expect(retired, totalRows);
        for (var counter = 1; counter <= totalRows; counter++) {
          expect(
            (await database.getEntryByHostAndCounter(
              'host-bulk',
              counter,
            ))!.status,
            SyncSequenceStatus.unresolvable.index,
            reason: 'row $counter should have been retired',
          );
        }
      },
    );
  });

  group('generated sequence lifecycle operations', () {
    Glados(any.sequenceLifecycleScenario, ExploreConfig(numRuns: 180)).test(
      'match the generated reset and retirement model',
      (scenario) async {
        final database = SyncDatabase(inMemoryDatabase: true);
        try {
          for (var index = 0; index < scenario.rows.length; index++) {
            final counter = index + 1;
            final row = scenario.rows[index];
            if (!row.isStored) continue;

            final entryId = row.entryId(counter);
            final lastRequestedAt = row.lastRequestedAtValue(
              _SequenceLifecycleScenario.now,
            );
            await database.recordSequenceEntry(
              SyncSequenceLogCompanion(
                hostId: const Value(_SequenceLifecycleScenario.hostId),
                counter: Value(counter),
                entryId: entryId == null
                    ? const Value.absent()
                    : Value(entryId),
                payloadType: Value(row.payloadType.index),
                status: Value(row.syncStatus.index),
                createdAt: Value(
                  row.createdAt(_SequenceLifecycleScenario.now),
                ),
                updatedAt: Value(
                  row.updatedAtValue(_SequenceLifecycleScenario.now),
                ),
                requestCount: Value(row.requestCount),
                lastRequestedAt: lastRequestedAt == null
                    ? const Value.absent()
                    : Value(lastRequestedAt),
              ),
            );
          }

          final affected = switch (scenario.operation) {
            _GeneratedSequenceLifecycleOperation.resetKnown =>
              await database.resetUnresolvableWithKnownPayload(),
            _GeneratedSequenceLifecycleOperation.resetAll =>
              await database.resetAllUnresolvableEntries(),
            _GeneratedSequenceLifecycleOperation.retireExhausted =>
              await database.retireExhaustedRequestedEntries(
                maxRequestCount: _SequenceLifecycleScenario.maxRequestCount,
                grace: _SequenceLifecycleScenario.grace,
                now: _SequenceLifecycleScenario.now,
                pageSize: 3,
              ),
            _GeneratedSequenceLifecycleOperation.retireAgedOut =>
              await database.retireAgedOutRequestedEntries(
                amnestyWindow: _SequenceLifecycleScenario.amnestyWindow,
                now: _SequenceLifecycleScenario.now,
                pageSize: 3,
              ),
          };

          expect(affected, scenario.expectedAffectedCount);

          for (var counter = 1; counter <= scenario.rows.length; counter++) {
            final entry = await database.getEntryByHostAndCounter(
              _SequenceLifecycleScenario.hostId,
              counter,
            );
            final expected = scenario.expectedRow(counter);
            if (expected.status == null) {
              expect(entry, isNull, reason: 'counter $counter');
              continue;
            }

            expect(entry, isNotNull, reason: 'counter $counter');
            expect(entry!.status, expected.status!.index);
            expect(entry.entryId, expected.entryId);
            expect(entry.payloadType, expected.payloadType!.index);
            expect(entry.requestCount, expected.requestCount);
            if (expected.lastRequestedCleared) {
              expect(entry.lastRequestedAt, isNull);
            }
          }

          expect(
            await database.getLastCounterForHost(
              _SequenceLifecycleScenario.hostId,
            ),
            scenario.expectedWatermark,
          );
        } finally {
          await database.close();
        }
      },
    );
  });

  group('getLastSentCounterForEntry', () {
    setUp(() async {
      db = SyncDatabase(inMemoryDatabase: true);
    });
    tearDown(() async {
      await db?.close();
    });

    test(
      'returns null when no entries exist for the host/entry pair',
      () async {
        final database = db!;
        final result = await database.getLastSentCounterForEntry(
          'host-1',
          'entry-1',
        );
        expect(result, isNull);
      },
    );

    test('returns the highest counter for a received entry', () async {
      final database = db!;
      const hostId = 'host-1';
      const entryId = 'entry-1';

      // Insert two received entries for the same entryId at different counters
      for (final counter in [10, 15, 20]) {
        await database.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: const Value(hostId),
            counter: Value(counter),
            entryId: const Value(entryId),
            status: Value(SyncSequenceStatus.received.index),
            createdAt: Value(DateTime(2024, 1, counter)),
            updatedAt: Value(DateTime(2024, 1, counter)),
          ),
        );
      }

      final result = await database.getLastSentCounterForEntry(
        hostId,
        entryId,
      );
      expect(result, 20);
    });

    test('includes backfilled entries in the result', () async {
      final database = db!;
      const hostId = 'host-1';
      const entryId = 'entry-1';

      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(10),
          entryId: const Value(entryId),
          status: Value(SyncSequenceStatus.received.index),
          createdAt: Value(DateTime(2024, 1, 1)),
          updatedAt: Value(DateTime(2024, 1, 1)),
        ),
      );
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(25),
          entryId: const Value(entryId),
          status: Value(SyncSequenceStatus.backfilled.index),
          createdAt: Value(DateTime(2024, 1, 2)),
          updatedAt: Value(DateTime(2024, 1, 2)),
        ),
      );

      final result = await database.getLastSentCounterForEntry(
        hostId,
        entryId,
      );
      expect(result, 25);
    });

    test('excludes missing and requested entries', () async {
      final database = db!;
      const hostId = 'host-1';
      const entryId = 'entry-1';

      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(10),
          entryId: const Value(entryId),
          status: Value(SyncSequenceStatus.received.index),
          createdAt: Value(DateTime(2024, 1, 1)),
          updatedAt: Value(DateTime(2024, 1, 1)),
        ),
      );
      // Higher counter but missing — should not be returned
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(30),
          entryId: const Value(entryId),
          status: Value(SyncSequenceStatus.missing.index),
          createdAt: Value(DateTime(2024, 1, 2)),
          updatedAt: Value(DateTime(2024, 1, 2)),
        ),
      );
      // Higher counter but requested — should not be returned
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(40),
          entryId: const Value(entryId),
          status: Value(SyncSequenceStatus.requested.index),
          createdAt: Value(DateTime(2024, 1, 3)),
          updatedAt: Value(DateTime(2024, 1, 3)),
        ),
      );

      final result = await database.getLastSentCounterForEntry(
        hostId,
        entryId,
      );
      expect(result, 10);
    });

    test('does not cross entry boundaries', () async {
      final database = db!;
      const hostId = 'host-1';

      // Entry A at counter 10
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(10),
          entryId: const Value('entry-a'),
          status: Value(SyncSequenceStatus.received.index),
          createdAt: Value(DateTime(2024, 1, 1)),
          updatedAt: Value(DateTime(2024, 1, 1)),
        ),
      );
      // Entry B at counter 50
      await database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: const Value(hostId),
          counter: const Value(50),
          entryId: const Value('entry-b'),
          status: Value(SyncSequenceStatus.received.index),
          createdAt: Value(DateTime(2024, 1, 2)),
          updatedAt: Value(DateTime(2024, 1, 2)),
        ),
      );

      final resultA = await database.getLastSentCounterForEntry(
        hostId,
        'entry-a',
      );
      expect(resultA, 10);

      final resultB = await database.getLastSentCounterForEntry(
        hostId,
        'entry-b',
      );
      expect(resultB, 50);
    });

    test(
      'returns the highest counter even when intervening rows are not '
      'ordered by insertion, exercising the ORDER BY DESC LIMIT 1 path',
      () async {
        final database = db!;
        const hostId = 'host-shuffle';
        const entryId = 'entry-shuffle';

        // Insert out-of-order counters for the same (host, entry) with mixed
        // statuses. The rewritten query must still return the max received
        // counter (33), not the max overall (77 is missing and must not win).
        final rows = <({int counter, SyncSequenceStatus status})>[
          (counter: 12, status: SyncSequenceStatus.received),
          (counter: 33, status: SyncSequenceStatus.backfilled),
          (counter: 5, status: SyncSequenceStatus.received),
          (counter: 77, status: SyncSequenceStatus.missing),
          (counter: 21, status: SyncSequenceStatus.received),
          (counter: 100, status: SyncSequenceStatus.requested),
        ];
        for (final row in rows) {
          await database.recordSequenceEntry(
            SyncSequenceLogCompanion(
              hostId: const Value(hostId),
              counter: Value(row.counter),
              entryId: const Value(entryId),
              status: Value(row.status.index),
              createdAt: Value(DateTime(2024, 6, 1)),
              updatedAt: Value(DateTime(2024, 6, 1)),
            ),
          );
        }

        expect(
          await database.getLastSentCounterForEntry(hostId, entryId),
          33,
        );
      },
    );
  });
}
