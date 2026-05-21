import 'dart:async';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value, Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

Event _buildSyncEvent({
  required String eventId,
  required String roomId,
  required int originTsMs,
  String type = EventTypes.Message,
  Map<String, dynamic>? content,
}) {
  final event = MockEvent();
  final eventContent = content ?? <String, dynamic>{'msgtype': syncMessageType};
  when(() => event.eventId).thenReturn(eventId);
  when(() => event.roomId).thenReturn(roomId);
  when(() => event.type).thenReturn(type);
  when(() => event.content).thenReturn(eventContent);
  when(() => event.text).thenReturn('stub text');
  when(
    () => event.originServerTs,
  ).thenReturn(DateTime.fromMillisecondsSinceEpoch(originTsMs));
  when(event.toJson).thenReturn(<String, dynamic>{
    'event_id': eventId,
    'room_id': roomId,
    'origin_server_ts': originTsMs,
    'type': type,
    'content': eventContent,
  });
  return event;
}

Event _buildGeneratedBatchEvent(
  _GeneratedBatchEventRow row, {
  required String roomId,
}) {
  switch (row.kind) {
    case _GeneratedBatchEventKind.encrypted:
      return _buildSyncEvent(
        eventId: row.eventId,
        roomId: roomId,
        originTsMs: row.originTsMs,
        type: EventTypes.Encrypted,
        content: <String, dynamic>{
          'algorithm': 'm.megolm.v1.aes-sha2',
          'msgtype': syncMessageType,
        },
      );
    case _GeneratedBatchEventKind.nonPayload:
      return _buildSyncEvent(
        eventId: row.eventId,
        roomId: roomId,
        originTsMs: row.originTsMs,
        type: EventTypes.RoomName,
        content: <String, dynamic>{'name': 'generated room'},
      );
    case _GeneratedBatchEventKind.syncPayload:
      final content = <String, dynamic>{'msgtype': syncMessageType};
      switch (row.pathShape) {
        case _GeneratedJsonPathShape.none:
          break;
        case _GeneratedJsonPathShape.jsonPath:
          content['jsonPath'] = row.rawPath;
        case _GeneratedJsonPathShape.jsonPathSnake:
          content['json_path'] = row.rawPath;
      }
      return _buildSyncEvent(
        eventId: row.eventId,
        roomId: roomId,
        originTsMs: row.originTsMs,
        content: content,
      );
  }
}

enum _GeneratedTerminalAction { commit, skip }

class _GeneratedInboundQueueRow {
  const _GeneratedInboundQueueRow({
    required this.timestampBucket,
    required this.processingBucket,
    required this.terminalAction,
  });

  final int timestampBucket;
  final int processingBucket;
  final _GeneratedTerminalAction terminalAction;

  int get originTsMs => 1000 + timestampBucket;

  @override
  String toString() {
    return '_GeneratedInboundQueueRow('
        'timestampBucket: $timestampBucket, '
        'processingBucket: $processingBucket, '
        'terminalAction: $terminalAction'
        ')';
  }
}

class _GeneratedInboundQueueMarkerScenario {
  const _GeneratedInboundQueueMarkerScenario({required this.rows});

  final List<_GeneratedInboundQueueRow> rows;

  String eventIdFor(int index) => '\$generated-marker-$index';

  Map<String, _GeneratedTerminalAction> get actionByEventId => {
    for (var index = 0; index < rows.length; index++)
      eventIdFor(index): rows[index].terminalAction,
  };

  List<int> processingOrder() {
    final indexed =
        <({int index, _GeneratedInboundQueueRow row})>[
          for (var index = 0; index < rows.length; index++)
            (index: index, row: rows[index]),
        ]..sort((a, b) {
          final bucketCompare = a.row.processingBucket.compareTo(
            b.row.processingBucket,
          );
          if (bucketCompare != 0) return bucketCompare;
          return a.index.compareTo(b.index);
        });

    return [for (final item in indexed) item.index];
  }

  @override
  String toString() {
    return '_GeneratedInboundQueueMarkerScenario(rows: $rows)';
  }
}

class _GeneratedResurrectionRow {
  const _GeneratedResurrectionRow({
    required this.pathSlot,
    required this.timestampBucket,
    required this.withLeadingSlash,
  });

  final int pathSlot;
  final int timestampBucket;
  final bool withLeadingSlash;

  int get originTsMs => 2000 + timestampBucket;

  String get canonicalPath => '/generated/path-$pathSlot.json';

  String get rawPath =>
      withLeadingSlash ? canonicalPath : canonicalPath.substring(1);

  @override
  String toString() {
    return '_GeneratedResurrectionRow('
        'pathSlot: $pathSlot, '
        'timestampBucket: $timestampBucket, '
        'withLeadingSlash: $withLeadingSlash'
        ')';
  }
}

class _GeneratedResurrectionScenario {
  const _GeneratedResurrectionScenario({
    required this.targetSlot,
    required this.rows,
  });

  final int targetSlot;
  final List<_GeneratedResurrectionRow> rows;

  String get targetPath => '/generated/path-$targetSlot.json';

  String eventIdFor(int index) => '\$generated-resurrect-$index';

  List<String> expectedResurrectedEventIds() {
    final indexed =
        <({int index, _GeneratedResurrectionRow row})>[
          for (var index = 0; index < rows.length; index++)
            (index: index, row: rows[index]),
        ]..sort((a, b) {
          final tsCompare = a.row.originTsMs.compareTo(b.row.originTsMs);
          if (tsCompare != 0) return tsCompare;
          return a.index.compareTo(b.index);
        });

    return [
      for (final item in indexed)
        if (item.row.canonicalPath == targetPath) eventIdFor(item.index),
    ];
  }

  @override
  String toString() {
    return '_GeneratedResurrectionScenario('
        'targetSlot: $targetSlot, '
        'rows: $rows'
        ')';
  }
}

enum _GeneratedBatchEventKind {
  syncPayload,
  nonPayload,
  encrypted,
}

enum _GeneratedJsonPathShape {
  none,
  jsonPath,
  jsonPathSnake,
}

class _GeneratedBatchEventRow {
  const _GeneratedBatchEventRow({
    required this.eventSlot,
    required this.timestampBucket,
    required this.kind,
    required this.pathShape,
    required this.pathSlot,
    required this.withLeadingSlash,
  });

  final int eventSlot;
  final int timestampBucket;
  final _GeneratedBatchEventKind kind;
  final _GeneratedJsonPathShape pathShape;
  final int pathSlot;
  final bool withLeadingSlash;

  String get eventId =>
      r'$generated-batch-'
      '$eventSlot';

  int get originTsMs => 3000 + timestampBucket;

  String get canonicalPath => '/generated/batch-$pathSlot.json';

  String get rawPath =>
      withLeadingSlash ? canonicalPath : canonicalPath.substring(1);

  String? get expectedStoredPath =>
      pathShape == _GeneratedJsonPathShape.none ? null : canonicalPath;

  @override
  String toString() {
    return '_GeneratedBatchEventRow('
        'eventSlot: $eventSlot, '
        'timestampBucket: $timestampBucket, '
        'kind: $kind, '
        'pathShape: $pathShape, '
        'pathSlot: $pathSlot, '
        'withLeadingSlash: $withLeadingSlash'
        ')';
  }
}

class _GeneratedBatchAccountingScenario {
  const _GeneratedBatchAccountingScenario({required this.rows});

  final List<_GeneratedBatchEventRow> rows;

  _ExpectedBatchAccounting expected() {
    final accepted = <String, _ExpectedAcceptedBatchRow>{};
    var duplicates = 0;
    var filtered = 0;
    var deferred = 0;
    var oldest = 0;
    var newest = 0;

    for (final row in rows) {
      switch (row.kind) {
        case _GeneratedBatchEventKind.encrypted:
          deferred++;
        case _GeneratedBatchEventKind.nonPayload:
          filtered++;
        case _GeneratedBatchEventKind.syncPayload:
          if (accepted.containsKey(row.eventId)) {
            duplicates++;
            continue;
          }
          accepted[row.eventId] = _ExpectedAcceptedBatchRow(
            originTsMs: row.originTsMs,
            jsonPath: row.expectedStoredPath,
          );
          if (oldest == 0 || row.originTsMs < oldest) oldest = row.originTsMs;
          if (row.originTsMs > newest) newest = row.originTsMs;
      }
    }

    return _ExpectedBatchAccounting(
      acceptedByEventId: accepted,
      duplicates: duplicates,
      filtered: filtered,
      deferred: deferred,
      oldest: oldest,
      newest: newest,
    );
  }

  @override
  String toString() => '_GeneratedBatchAccountingScenario(rows: $rows)';
}

class _ExpectedAcceptedBatchRow {
  const _ExpectedAcceptedBatchRow({
    required this.originTsMs,
    required this.jsonPath,
  });

  final int originTsMs;
  final String? jsonPath;
}

class _ExpectedBatchAccounting {
  const _ExpectedBatchAccounting({
    required this.acceptedByEventId,
    required this.duplicates,
    required this.filtered,
    required this.deferred,
    required this.oldest,
    required this.newest,
  });

  final Map<String, _ExpectedAcceptedBatchRow> acceptedByEventId;
  final int duplicates;
  final int filtered;
  final int deferred;
  final int oldest;
  final int newest;
}

class _ExpectedQueueMarker {
  int lastAppliedTs = 0;
  String? lastAppliedEventId;
  int lastAppliedCommitSeq = 0;

  void process(
    InboundQueueEntry entry,
    Iterable<InboundQueueEntry> activeAfter,
  ) {
    int? oldestActiveTs;
    for (final active in activeAfter) {
      if (oldestActiveTs == null || active.originTs < oldestActiveTs) {
        oldestActiveTs = active.originTs;
      }
    }

    final candidateTs = oldestActiveTs == null
        ? entry.originTs
        : entry.originTs < oldestActiveTs
        ? entry.originTs
        : oldestActiveTs - 1;

    final shouldAdvance =
        lastAppliedTs == 0 ||
        candidateTs > lastAppliedTs ||
        (candidateTs == entry.originTs &&
            entry.originTs == lastAppliedTs &&
            (lastAppliedEventId == null ||
                entry.eventId.compareTo(lastAppliedEventId!) > 0));

    if (!shouldAdvance) return;

    if (candidateTs == entry.originTs && entry.eventId.startsWith(r'$')) {
      lastAppliedEventId = entry.eventId;
    }
    lastAppliedTs = candidateTs;
    lastAppliedCommitSeq++;
  }
}

extension _AnyInboundQueueScenario on glados.Any {
  glados.Generator<_GeneratedTerminalAction> get terminalAction =>
      glados.AnyUtils(this).choose(_GeneratedTerminalAction.values);

  glados.Generator<_GeneratedInboundQueueRow> get inboundQueueRow =>
      glados.CombinableAny(this).combine3(
        glados.IntAnys(this).intInRange(0, 5),
        glados.IntAnys(this).intInRange(0, 7),
        terminalAction,
        (
          int timestampBucket,
          int processingBucket,
          _GeneratedTerminalAction terminalAction,
        ) => _GeneratedInboundQueueRow(
          timestampBucket: timestampBucket,
          processingBucket: processingBucket,
          terminalAction: terminalAction,
        ),
      );

  glados.Generator<_GeneratedInboundQueueMarkerScenario>
  get inboundQueueMarkerScenario =>
      glados.ListAnys(
            this,
          )
          .listWithLengthInRange(1, 8, inboundQueueRow)
          .map(
            (rows) => _GeneratedInboundQueueMarkerScenario(rows: rows),
          );

  glados.Generator<_GeneratedResurrectionRow> get resurrectionRow =>
      glados.CombinableAny(this).combine3(
        glados.IntAnys(this).intInRange(0, 3),
        glados.IntAnys(this).intInRange(0, 8),
        glados.BoolAny(this).bool,
        (
          int pathSlot,
          int timestampBucket,
          bool withLeadingSlash,
        ) => _GeneratedResurrectionRow(
          pathSlot: pathSlot,
          timestampBucket: timestampBucket,
          withLeadingSlash: withLeadingSlash,
        ),
      );

  glados.Generator<_GeneratedResurrectionScenario> get resurrectionScenario =>
      glados.CombinableAny(this).combine2(
        glados.IntAnys(this).intInRange(0, 3),
        glados.ListAnys(this).listWithLengthInRange(1, 10, resurrectionRow),
        (int targetSlot, List<_GeneratedResurrectionRow> rows) =>
            _GeneratedResurrectionScenario(
              targetSlot: targetSlot,
              rows: rows,
            ),
      );

  glados.Generator<_GeneratedBatchEventKind> get batchEventKind =>
      glados.AnyUtils(this).choose(_GeneratedBatchEventKind.values);

  glados.Generator<_GeneratedJsonPathShape> get jsonPathShape =>
      glados.AnyUtils(this).choose(_GeneratedJsonPathShape.values);

  glados.Generator<_GeneratedBatchEventRow> get batchEventRow =>
      glados.CombinableAny(this).combine6(
        glados.IntAnys(this).intInRange(0, 5),
        glados.IntAnys(this).intInRange(0, 9),
        batchEventKind,
        jsonPathShape,
        glados.IntAnys(this).intInRange(0, 4),
        glados.BoolAny(this).bool,
        (
          int eventSlot,
          int timestampBucket,
          _GeneratedBatchEventKind kind,
          _GeneratedJsonPathShape pathShape,
          int pathSlot,
          bool withLeadingSlash,
        ) => _GeneratedBatchEventRow(
          eventSlot: eventSlot,
          timestampBucket: timestampBucket,
          kind: kind,
          pathShape: pathShape,
          pathSlot: pathSlot,
          withLeadingSlash: withLeadingSlash,
        ),
      );

  glados.Generator<_GeneratedBatchAccountingScenario>
  get batchAccountingScenario =>
      glados.ListAnys(
            this,
          )
          .listWithLengthInRange(
            1,
            14,
            batchEventRow,
          )
          .map((rows) => _GeneratedBatchAccountingScenario(rows: rows));
}

Future<void> _withFreshInboundQueue(
  Future<void> Function(SyncDatabase db, InboundQueue queue) body,
) async {
  final db = SyncDatabase(inMemoryDatabase: true);
  final queue = InboundQueue(
    db: db,
    logging: MockLoggingService(),
    leaseDuration: const Duration(seconds: 1),
  );

  try {
    await body(db, queue);
  } finally {
    await queue.dispose();
    await db.close();
  }
}

void main() {
  late SyncDatabase db;
  late MockLoggingService logging;
  late InboundQueue queue;
  const roomA = '!roomA:example.org';
  const roomB = '!roomB:example.org';

  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
  });

  setUp(() {
    db = SyncDatabase(inMemoryDatabase: true);
    logging = MockLoggingService();
    queue = InboundQueue(
      db: db,
      logging: logging,
      leaseDuration: const Duration(seconds: 1),
    );
  });

  tearDown(() async {
    await queue.dispose();
    await db.close();
  });

  group('enqueue', () {
    test('single live event inserted and counted', () async {
      final event = _buildSyncEvent(
        eventId: r'$e1',
        roomId: roomA,
        originTsMs: 1000,
      );
      final result = await queue.enqueueLive(event);
      expect(result.accepted, 1);
      expect(result.duplicatesDropped, 0);
      expect(result.filteredOutByType, 0);
      final stats = await queue.stats();
      expect(stats.total, 1);
      expect(stats.byProducer[InboundEventProducer.live], 1);
    });

    test('duplicate eventId silently dropped on insert', () async {
      final event = _buildSyncEvent(
        eventId: r'$dup',
        roomId: roomA,
        originTsMs: 2000,
      );
      await queue.enqueueLive(event);
      final result = await queue.enqueueLive(event);
      expect(result.accepted, 0);
      expect(result.duplicatesDropped, 1);
      final stats = await queue.stats();
      expect(stats.total, 1);
    });

    test(
      'non-payload events filtered out (F4)',
      () async {
        final event = _buildSyncEvent(
          eventId: r'$state',
          roomId: roomA,
          originTsMs: 3000,
          type: EventTypes.RoomName,
          content: <String, dynamic>{'name': 'Renamed'},
        );
        final result = await queue.enqueueLive(event);
        expect(result.accepted, 0);
        expect(result.filteredOutByType, 1);
        final stats = await queue.stats();
        expect(stats.total, 0);
      },
    );

    test(
      'encrypted events deferred — not enqueued (F3)',
      () async {
        final event = _buildSyncEvent(
          eventId: r'$enc',
          roomId: roomA,
          originTsMs: 4000,
          type: EventTypes.Encrypted,
          content: <String, dynamic>{
            'msgtype': syncMessageType,
            'algorithm': 'm.megolm.v1.aes-sha2',
          },
        );
        final result = await queue.enqueueLive(event);
        expect(result.accepted, 0);
        expect(result.deferredPendingDecryption, 1);
        final stats = await queue.stats();
        expect(stats.total, 0);
      },
    );

    test('batch insert attributes producer correctly', () async {
      final events = [
        _buildSyncEvent(eventId: r'$a', roomId: roomA, originTsMs: 100),
        _buildSyncEvent(eventId: r'$b', roomId: roomA, originTsMs: 200),
        _buildSyncEvent(eventId: r'$c', roomId: roomA, originTsMs: 300),
      ];
      final result = await queue.enqueueBatch(
        events,
        producer: InboundEventProducer.bridge,
      );
      expect(result.accepted, 3);
      final stats = await queue.stats();
      expect(stats.byProducer[InboundEventProducer.bridge], 3);
    });
  });

  group('peekBatchReady', () {
    test('returns entries in origin_ts ascending order', () async {
      await queue.enqueueBatch(
        [
          _buildSyncEvent(eventId: r'$late', roomId: roomA, originTsMs: 3000),
          _buildSyncEvent(eventId: r'$early', roomId: roomA, originTsMs: 1000),
          _buildSyncEvent(eventId: r'$mid', roomId: roomA, originTsMs: 2000),
        ],
        producer: InboundEventProducer.live,
      );
      final batch = await queue.peekBatchReady();
      expect(batch.map((e) => e.eventId).toList(), [
        r'$early',
        r'$mid',
        r'$late',
      ]);
    });

    test(
      'stamps lease — peek twice returns empty until lease expires',
      () async {
        final frozen = DateTime.fromMillisecondsSinceEpoch(50_000);
        await withClock(Clock.fixed(frozen), () async {
          await queue.enqueueLive(
            _buildSyncEvent(eventId: r'$e', roomId: roomA, originTsMs: 1),
          );
          final first = await queue.peekBatchReady();
          expect(first, hasLength(1));
          final second = await queue.peekBatchReady();
          expect(second, isEmpty);
        });
        // Fast-forward past the 1s lease duration.
        await withClock(
          Clock.fixed(frozen.add(const Duration(seconds: 2))),
          () async {
            final third = await queue.peekBatchReady();
            expect(third, hasLength(1));
          },
        );
      },
    );
  });

  group('waitForDrainAtMostTo', () {
    test(
      'completes immediately when current depth already satisfies the '
      'threshold (no wait, no subscription leak)',
      () async {
        // Empty queue; depth is 0 <= 1.
        await queue.waitForDrainAtMostTo(1);
      },
    );

    test(
      'completes without a timeout once a depth signal drops total to the '
      'threshold — exercises the non-timeout completer.future await path',
      () async {
        await queue.enqueueBatch(
          [
            _buildSyncEvent(eventId: r'$a', roomId: roomA, originTsMs: 1),
            _buildSyncEvent(eventId: r'$b', roomId: roomA, originTsMs: 2),
          ],
          producer: InboundEventProducer.live,
        );
        // Start the waiter (target depth 0) without a timeout, then
        // drain the queue so a depthChanges signal unblocks it.
        final drainFuture = queue.waitForDrainAtMostTo(0);
        final batch = await queue.peekBatchReady();
        for (final entry in batch) {
          await queue.commitApplied(entry);
        }
        await drainFuture;
      },
    );

    test(
      'times out when the queue never drains below the threshold',
      () async {
        await queue.enqueueLive(
          _buildSyncEvent(
            eventId: r'$stuck',
            roomId: roomA,
            originTsMs: 1,
          ),
        );
        await expectLater(
          queue.waitForDrainAtMostTo(
            0,
            timeout: const Duration(milliseconds: 50),
          ),
          throwsA(isA<TimeoutException>()),
        );
      },
    );
  });

  group('earliestReadyAt', () {
    test(
      'returns null on an empty queue and the next max(nextDueAt, '
      'leaseUntil) when rows exist',
      () async {
        expect(await queue.earliestReadyAt(), isNull);
        await queue.enqueueLive(
          _buildSyncEvent(eventId: r'$now', roomId: roomA, originTsMs: 1),
        );
        // Fresh enqueue: nextDueAt=0, leaseUntil=0 → readyAt=0.
        expect(await queue.earliestReadyAt(), 0);
        // Peek stamps a lease; earliestReadyAt should now reflect it.
        final batch = await queue.peekBatchReady();
        expect(batch, hasLength(1));
        final ready = await queue.earliestReadyAt();
        expect(ready, isNotNull);
        expect(ready, greaterThan(0));
      },
    );
  });

  group('marker-clamp planner alignment', () {
    test(
      'oldest-active-origin probe uses the active-room partial index '
      'rather than falling back to a rowid scan — the 2026-05-12 '
      'desktop super-slow log captured the parameterised form as '
      'SEARCH inbound_event_queue (no index name) at up to 862 ms per '
      'call before the literal-IN rewrite',
      () async {
        // Seed enough rows to make the planner cost a SCAN higher than
        // the partial-index walk. Without rows the planner sometimes
        // picks any usable path; with a few hundred actionable rows the
        // chosen plan is the steady-state plan.
        await queue.enqueueBatch(
          [
            for (var i = 0; i < 200; i++)
              _buildSyncEvent(
                eventId: '\$bulk-$i',
                roomId: roomA,
                originTsMs: 1000 + i,
              ),
          ],
          producer: InboundEventProducer.live,
        );

        final rows = await db
            .customSelect(
              'EXPLAIN QUERY PLAN '
              'SELECT MIN(origin_ts) FROM inbound_event_queue '
              'WHERE room_id = ? '
              "AND status IN ('enqueued','leased','retrying') "
              'AND NOT (queue_id = ?)',
              variables: [Variable.withString(roomA), Variable.withInt(-1)],
            )
            .get();
        final plan = rows.map((r) => r.data.toString()).join('\n');

        expect(
          plan,
          contains('idx_inbound_event_queue_active_room_ts'),
          reason:
              'literal status IN must let the planner match the partial '
              'index (idx_inbound_event_queue_active_room_ts, declared '
              "WHERE status IN ('enqueued','leased','retrying')) — "
              'otherwise this query degenerates to a rowid scan on '
              'every commit/abandon',
        );
      },
    );
  });

  group('_advanceMarkerIfNewer tie-breaker', () {
    test(
      'equal timestamps: a lex-greater durable eventId advances the '
      'marker (covers the compareTo > 0 branch)',
      () async {
        // First commit: $aaa at ts=1000.
        await queue.enqueueLive(
          _buildSyncEvent(eventId: r'$aaa', roomId: roomA, originTsMs: 1000),
        );
        await queue.commitApplied((await queue.peekBatchReady()).single);

        // Second commit: $zzz at the same ts=1000. With equal ts and
        // $zzz.compareTo($aaa) > 0, the marker must advance to $zzz.
        await queue.enqueueLive(
          _buildSyncEvent(eventId: r'$zzz', roomId: roomA, originTsMs: 1000),
        );
        await queue.commitApplied((await queue.peekBatchReady()).single);

        final marker = await (db.select(
          db.queueMarkers,
        )..where((t) => t.roomId.equals(roomA))).getSingle();
        expect(marker.lastAppliedEventId, r'$zzz');
        expect(marker.lastAppliedTs, 1000);
        expect(marker.lastAppliedCommitSeq, 2);
      },
    );
  });

  group('generated queue ledger properties', () {
    glados.Glados(
      glados.any.inboundQueueMarkerScenario,
    ).test(
      'marker clamping matches the model for generated commit/skip order',
      (scenario) async {
        await _withFreshInboundQueue((db, queue) async {
          await queue.enqueueBatch(
            [
              for (var index = 0; index < scenario.rows.length; index++)
                _buildSyncEvent(
                  eventId: scenario.eventIdFor(index),
                  roomId: roomA,
                  originTsMs: scenario.rows[index].originTsMs,
                ),
            ],
            producer: InboundEventProducer.live,
          );

          final batch = await queue.peekBatchReady(
            maxBatch: scenario.rows.length,
          );
          expect(batch, hasLength(scenario.rows.length));

          final actionByEventId = scenario.actionByEventId;
          final activeByEventId = {
            for (final entry in batch) entry.eventId: entry,
          };
          final expectedMarker = _ExpectedQueueMarker();
          var expectedApplied = 0;
          var expectedAbandoned = 0;

          final processOrder = scenario.processingOrder();

          for (final index in processOrder) {
            final entry = batch[index];
            final action = actionByEventId[entry.eventId]!;

            activeByEventId.remove(entry.eventId);
            expectedMarker.process(entry, activeByEventId.values);

            switch (action) {
              case _GeneratedTerminalAction.commit:
                await queue.commitApplied(entry);
                expectedApplied++;
              case _GeneratedTerminalAction.skip:
                await queue.markSkipped(entry, reason: 'generatedSkip');
                expectedAbandoned++;
            }
          }

          final marker = await (db.select(
            db.queueMarkers,
          )..where((t) => t.roomId.equals(roomA))).getSingle();
          expect(marker.lastAppliedTs, expectedMarker.lastAppliedTs);
          expect(
            marker.lastAppliedEventId,
            expectedMarker.lastAppliedEventId,
          );
          expect(
            marker.lastAppliedCommitSeq,
            expectedMarker.lastAppliedCommitSeq,
          );

          final stats = await queue.stats();
          expect(stats.total, 0);
          expect(stats.applied, expectedApplied);
          expect(stats.abandoned, expectedAbandoned);
        });
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.resurrectionScenario,
    ).test(
      'resurrectByPath only reopens generated abandoned rows for that path',
      (scenario) async {
        await _withFreshInboundQueue((_, queue) async {
          await queue.enqueueBatch(
            [
              for (var index = 0; index < scenario.rows.length; index++)
                _buildSyncEvent(
                  eventId: scenario.eventIdFor(index),
                  roomId: roomA,
                  originTsMs: scenario.rows[index].originTsMs,
                  content: <String, dynamic>{
                    'msgtype': syncMessageType,
                    'jsonPath': scenario.rows[index].rawPath,
                  },
                ),
            ],
            producer: InboundEventProducer.live,
          );

          final batch = await queue.peekBatchReady(
            maxBatch: scenario.rows.length,
          );
          for (final entry in batch) {
            await queue.markSkipped(entry, reason: 'pendingAttachmentTimeout');
          }

          final expectedEventIds = scenario.expectedResurrectedEventIds();
          final resurrected = await queue.resurrectByPath(scenario.targetPath);

          expect(resurrected, expectedEventIds.length);

          final stats = await queue.stats();
          expect(stats.total, expectedEventIds.length);
          expect(stats.readyNow, expectedEventIds.length);
          expect(
            stats.abandoned,
            scenario.rows.length - expectedEventIds.length,
          );

          final ready = await queue.peekBatchReady(
            maxBatch: scenario.rows.length,
          );
          expect(
            ready.map((entry) => entry.eventId).toList(),
            expectedEventIds,
          );
        });
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.batchAccountingScenario,
      glados.ExploreConfig(numRuns: 140),
    ).test(
      'enqueueBatch generated accounting partitions every input event',
      (scenario) async {
        await _withFreshInboundQueue((db, queue) async {
          final result = await queue.enqueueBatch(
            [
              for (final row in scenario.rows)
                _buildGeneratedBatchEvent(row, roomId: roomA),
            ],
            producer: InboundEventProducer.live,
          );
          final expected = scenario.expected();

          expect(
            result.accepted +
                result.duplicatesDropped +
                result.filteredOutByType +
                result.deferredPendingDecryption,
            scenario.rows.length,
          );
          expect(result.accepted, expected.acceptedByEventId.length);
          expect(result.duplicatesDropped, expected.duplicates);
          expect(result.filteredOutByType, expected.filtered);
          expect(result.deferredPendingDecryption, expected.deferred);
          expect(result.oldestTsAccepted, expected.oldest);
          expect(result.newestTsAccepted, expected.newest);

          final stored = await db.select(db.inboundEventQueue).get();
          expect(stored, hasLength(expected.acceptedByEventId.length));
          for (final row in stored) {
            final expectedRow = expected.acceptedByEventId[row.eventId]!;
            expect(row.originTs, expectedRow.originTsMs);
            expect(row.jsonPath, expectedRow.jsonPath);
          }
        });
      },
      tags: 'glados',
    );
  });

  group('InboundQueueEntry.toEvent', () {
    test(
      'materialises the stored rawJson into an Event against the given '
      'room so the worker-side apply path has the SDK object it needs',
      () async {
        final room = MockRoom();
        when(() => room.id).thenReturn(roomA);
        final original = MockEvent();
        final content = <String, dynamic>{'msgtype': syncMessageType};
        when(() => original.eventId).thenReturn(r'$mat');
        when(() => original.roomId).thenReturn(roomA);
        when(() => original.type).thenReturn(EventTypes.Message);
        when(() => original.content).thenReturn(content);
        when(() => original.text).thenReturn('stub');
        when(
          () => original.originServerTs,
        ).thenReturn(DateTime.fromMillisecondsSinceEpoch(4242));
        when(original.toJson).thenReturn(<String, dynamic>{
          'event_id': r'$mat',
          'room_id': roomA,
          'origin_server_ts': 4242,
          'type': EventTypes.Message,
          // Event.fromJson requires a non-null sender field.
          'sender': '@alice:example.org',
          'content': content,
        });
        await queue.enqueueLive(original);
        final batch = await queue.peekBatchReady();
        final rehydrated = batch.single.toEvent(room);
        expect(rehydrated.eventId, r'$mat');
        expect(rehydrated.roomId, roomA);
        expect(
          rehydrated.originServerTs.millisecondsSinceEpoch,
          4242,
        );
        expect(rehydrated.senderId, '@alice:example.org');
      },
    );
  });

  group('commitApplied (F2 + F5)', () {
    test('deletes row and advances marker on newer timestamp', () async {
      await queue.enqueueLive(
        _buildSyncEvent(eventId: r'$a', roomId: roomA, originTsMs: 1000),
      );
      final batch = await queue.peekBatchReady();
      await queue.commitApplied(batch.single);
      final stats = await queue.stats();
      expect(stats.total, 0);
      final marker = await (db.select(
        db.queueMarkers,
      )..where((t) => t.roomId.equals(roomA))).getSingle();
      expect(marker.lastAppliedEventId, r'$a');
      expect(marker.lastAppliedTs, 1000);
      expect(marker.lastAppliedCommitSeq, 1);
    });

    test(
      'does not regress marker on out-of-order apply (F2)',
      () async {
        // Apply a newer event first, then an older one (live + bridge race).
        await queue.enqueueLive(
          _buildSyncEvent(eventId: r'$newer', roomId: roomA, originTsMs: 5000),
        );
        final firstBatch = await queue.peekBatchReady();
        await queue.commitApplied(firstBatch.single);

        await queue.enqueueBatch(
          [
            _buildSyncEvent(
              eventId: r'$older',
              roomId: roomA,
              originTsMs: 1000,
            ),
          ],
          producer: InboundEventProducer.bridge,
        );
        final secondBatch = await queue.peekBatchReady();
        await queue.commitApplied(secondBatch.single);

        final marker = await (db.select(
          db.queueMarkers,
        )..where((t) => t.roomId.equals(roomA))).getSingle();
        expect(marker.lastAppliedEventId, r'$newer');
        expect(marker.lastAppliedTs, 5000);
        // _advanceMarkerIfNewer leaves lastAppliedCommitSeq untouched
        // when the monotonic guard rejects the candidate, so the
        // counter reflects only the first (newer) commit.
        expect(marker.lastAppliedCommitSeq, 1);
      },
    );

    test(
      'non-durable (placeholder) eventId does not overwrite last_applied_event_id',
      () async {
        // First commit a server-assigned event.
        await queue.enqueueLive(
          _buildSyncEvent(eventId: r'$real', roomId: roomA, originTsMs: 1000),
        );
        final first = await queue.peekBatchReady();
        await queue.commitApplied(first.single);

        // Then a placeholder-id event with a newer timestamp.
        await queue.enqueueLive(
          _buildSyncEvent(
            eventId: 'lotti-placeholder-42',
            roomId: roomA,
            originTsMs: 2000,
          ),
        );
        final second = await queue.peekBatchReady();
        await queue.commitApplied(second.single);

        final marker = await (db.select(
          db.queueMarkers,
        )..where((t) => t.roomId.equals(roomA))).getSingle();
        // Timestamp advances...
        expect(marker.lastAppliedTs, 2000);
        // ...but last_applied_event_id keeps the durable server id.
        expect(marker.lastAppliedEventId, r'$real');
      },
    );
  });

  group('markSkipped', () {
    test(
      'advances the per-room marker past the skipped event so a poison '
      'event cannot be refetched indefinitely',
      () async {
        await queue.enqueueLive(
          _buildSyncEvent(eventId: r'$poison', roomId: roomA, originTsMs: 7000),
        );
        final batch = await queue.peekBatchReady();
        final entry = batch.single;

        await queue.markSkipped(entry, reason: 'permanentSkip');

        final marker = await (db.select(
          db.queueMarkers,
        )..where((t) => t.roomId.equals(roomA))).getSingle();
        expect(marker.lastAppliedEventId, r'$poison');
        expect(marker.lastAppliedTs, 7000);
        // Row is gone too.
        final stats = await queue.stats();
        expect(stats.total, 0);
      },
    );

    test(
      'does not regress the marker when the skipped event is older than '
      'the stored marker',
      () async {
        await queue.enqueueLive(
          _buildSyncEvent(eventId: r'$newer', roomId: roomA, originTsMs: 5000),
        );
        final firstBatch = await queue.peekBatchReady();
        await queue.commitApplied(firstBatch.single);

        await queue.enqueueBatch(
          [
            _buildSyncEvent(
              eventId: r'$old',
              roomId: roomA,
              originTsMs: 1000,
            ),
          ],
          producer: InboundEventProducer.bridge,
        );
        final secondBatch = await queue.peekBatchReady();
        await queue.markSkipped(secondBatch.single, reason: 'permanentSkip');

        final marker = await (db.select(
          db.queueMarkers,
        )..where((t) => t.roomId.equals(roomA))).getSingle();
        // Marker must still point at the newer event.
        expect(marker.lastAppliedEventId, r'$newer');
        expect(marker.lastAppliedTs, 5000);
      },
    );
  });

  group('scheduleRetry', () {
    test(
      'bumps attempts, pushes nextDueAt, releases lease',
      () async {
        final frozen = DateTime.fromMillisecondsSinceEpoch(100_000);
        await withClock(Clock.fixed(frozen), () async {
          await queue.enqueueLive(
            _buildSyncEvent(eventId: r'$r1', roomId: roomA, originTsMs: 1),
          );
          final batch = await queue.peekBatchReady();
          final entry = batch.single;
          await queue.scheduleRetry(
            entry,
            const Duration(seconds: 3),
            reason: RetryReason.retriable,
          );
          final row = await (db.select(
            db.inboundEventQueue,
          )..where((t) => t.queueId.equals(entry.queueId))).getSingle();
          expect(row.attempts, 1);
          expect(
            row.nextDueAt,
            frozen.millisecondsSinceEpoch + 3000,
          );
          expect(row.leaseUntil, 0);
        });
      },
    );
  });

  group('pruneStrandedEntries (F6)', () {
    test('deletes rows whose roomId does not match the current room', () async {
      await queue.enqueueLive(
        _buildSyncEvent(eventId: r'$a', roomId: roomA, originTsMs: 1),
      );
      await queue.enqueueLive(
        _buildSyncEvent(eventId: r'$b', roomId: roomB, originTsMs: 2),
      );
      final removed = await queue.pruneStrandedEntries(roomA);
      expect(removed, 1);
      final stats = await queue.stats();
      expect(stats.total, 1);
    });

    test(
      'planner uses the active status/room partial index for stranded-room '
      'maintenance',
      () async {
        await queue.enqueueBatch(
          [
            for (var i = 0; i < 200; i++)
              _buildSyncEvent(
                eventId: '\$stranded-plan-$i',
                roomId: i.isEven ? roomA : roomB,
                originTsMs: 1000 + i,
              ),
          ],
          producer: InboundEventProducer.live,
        );
        await db.customStatement('ANALYZE');

        final planRows = await db
            .customSelect(
              'EXPLAIN QUERY PLAN '
              'UPDATE inbound_event_queue '
              "SET status = 'abandoned', "
              '    abandoned_at = 0, '
              "    last_error_reason = 'strandedRoom', "
              '    lease_until = 0 '
              'WHERE room_id != ? '
              "  AND status IN ('enqueued', 'leased', 'retrying')",
              variables: [Variable.withString(roomA)],
            )
            .get();
        final plan = planRows.map((row) => row.data.toString()).join('\n');

        expect(
          plan,
          contains('idx_inbound_event_queue_active_status_room'),
          reason:
              'the stranded-room UPDATE should scan only active queue rows '
              'instead of walking the full applied/abandoned ledger',
        );
      },
    );
  });

  group('depthChanges', () {
    test(
      'emits after enqueue, commit, and prune — all three paths hit the '
      'depth stream so the worker wakes on any queue-level change',
      () async {
        final depths = <int>[];
        final sub = queue.depthChanges.listen((s) => depths.add(s.total));

        // Enqueue: depth should rise to >= 1.
        await queue.enqueueLive(
          _buildSyncEvent(
            eventId: r'$depth',
            roomId: roomA,
            originTsMs: 1,
          ),
        );
        // Commit: depth drops back to 0.
        final batch = await queue.peekBatchReady();
        await queue.commitApplied(batch.single);

        // Re-populate with a cross-room entry so prune has something
        // to delete and the prune-triggered emission is observable.
        await queue.enqueueLive(
          _buildSyncEvent(
            eventId: r'$stranded',
            roomId: roomB,
            originTsMs: 2,
          ),
        );
        final pruned = await queue.pruneStrandedEntries(roomA);
        expect(pruned, 1);

        // Pump microtasks so the fire-and-forget `_emitDepth` futures
        // complete before we inspect the depth history.
        await pumpEventQueue();
        await sub.cancel();
        expect(depths, isNotEmpty);
        expect(depths.last, 0);
        // We expect at least three emissions: enqueue, commit, prune.
        expect(depths.length, greaterThanOrEqualTo(3));
      },
    );

    test(
      'scheduleRetry emits a depth signal so subscribers waiting on '
      'leased→retrying transitions wake up without polling',
      () async {
        await queue.enqueueLive(
          _buildSyncEvent(eventId: r'$retry', roomId: roomA, originTsMs: 1),
        );
        final batch = await queue.peekBatchReady();
        // Drain the enqueue emission so the assertion below isolates the
        // signal triggered by scheduleRetry alone.
        await pumpEventQueue();

        var signalCount = 0;
        final sub = queue.depthChanges.listen((_) => signalCount++);

        await queue.scheduleRetry(
          batch.single,
          const Duration(seconds: 30),
          reason: RetryReason.pendingAttachment,
        );
        await pumpEventQueue();
        await sub.cancel();

        // The depth signal itself does not carry the retrying count, so
        // assert that a signal fired and that stats() now reflects the
        // transition — together that is the contract the worker pipeline
        // relies on (signal-then-poll).
        expect(signalCount, greaterThanOrEqualTo(1));
        final stats = await queue.stats();
        expect(stats.retrying, 1);
      },
    );
  });

  group('ledger lifecycle (v13)', () {
    // Helper that reads the raw `status` column for a queue row so tests
    // assert against the persisted state rather than inferring through
    // peek filters.
    Future<String?> statusOf(int queueId) async {
      final row = await (db.select(
        db.inboundEventQueue,
      )..where((t) => t.queueId.equals(queueId))).getSingleOrNull();
      return row?.status;
    }

    test(
      'commitApplied flips the row to status=applied, keeps it in the '
      'table for the ledger, and advances the marker',
      () async {
        await queue.enqueueLive(
          _buildSyncEvent(eventId: r'$a', roomId: roomA, originTsMs: 100),
        );
        final batch = await queue.peekBatchReady();
        expect(batch, hasLength(1));
        expect(await statusOf(batch.first.queueId), 'leased');

        await queue.commitApplied(batch.first);
        expect(await statusOf(batch.first.queueId), 'applied');

        // Row is retained in the ledger so diagnostics + replay paths
        // can read it later.
        final rows = await db.select(db.inboundEventQueue).get();
        expect(rows, hasLength(1));

        final stats = await queue.stats();
        expect(stats.total, 0); // no active rows
        expect(stats.applied, 1);
        expect(stats.abandoned, 0);

        final marker = await (db.select(
          db.queueMarkers,
        )..where((t) => t.roomId.equals(roomA))).getSingleOrNull();
        expect(marker?.lastAppliedTs, 100);
      },
    );

    test(
      'markSkipped flips the row to status=abandoned and preserves it '
      '— the marker advances normally because the clamp ignores the '
      'abandoned row (forward progress is not held hostage by a '
      'single failing event)',
      () async {
        await queue.enqueueLive(
          _buildSyncEvent(eventId: r'$poison', roomId: roomA, originTsMs: 50),
        );
        final batch = await queue.peekBatchReady();
        await queue.markSkipped(batch.first, reason: 'maxAttempts(retriable)');

        expect(await statusOf(batch.first.queueId), 'abandoned');

        // A subsequent successful commit for a NEWER row advances the
        // marker past the abandoned timestamp — the canonical "don't
        // stall on poison" invariant.
        await queue.enqueueLive(
          _buildSyncEvent(eventId: r'$b', roomId: roomA, originTsMs: 200),
        );
        final next = await queue.peekBatchReady();
        await queue.commitApplied(next.first);

        final marker = await (db.select(
          db.queueMarkers,
        )..where((t) => t.roomId.equals(roomA))).getSingleOrNull();
        expect(marker?.lastAppliedTs, 200);

        final stats = await queue.stats();
        expect(stats.abandoned, 1);
        expect(stats.applied, 1);
      },
    );

    test(
      'the marker clamp pins forward progress behind an older row that '
      'is still in-flight (enqueued/leased/retrying) — the exact '
      'invariant that makes backfill self-healing for rows we have '
      'not yet given up on',
      () async {
        // Older row first; will remain enqueued.
        await queue.enqueueLive(
          _buildSyncEvent(eventId: r'$old', roomId: roomA, originTsMs: 10),
        );
        // Newer row applies successfully.
        await queue.enqueueLive(
          _buildSyncEvent(eventId: r'$new', roomId: roomA, originTsMs: 100),
        );
        // Peek + commit only the newer one (filter by eventId).
        final batch = await queue.peekBatchReady();
        final newer = batch.firstWhere((e) => e.eventId == r'$new');
        await queue.commitApplied(newer);

        final marker = await (db.select(
          db.queueMarkers,
        )..where((t) => t.roomId.equals(roomA))).getSingleOrNull();
        // Clamped to oldestActive (10) − 1 = 9 rather than 100.
        expect(marker?.lastAppliedTs, 9);
      },
    );

    test(
      'resurrectByPath flips abandoned rows whose json_path matches '
      'back to enqueued and re-zeroes attempts so the worker picks '
      'them up immediately on the next drain cycle',
      () async {
        const path = '/audio/2026-04-21/foo.m4a.json';
        final event = _buildSyncEvent(
          eventId: r'$waitsForAudio',
          roomId: roomA,
          originTsMs: 500,
          content: <String, dynamic>{
            'msgtype': syncMessageType,
            'jsonPath': path,
          },
        );
        await queue.enqueueLive(event);
        final batch = await queue.peekBatchReady();
        await queue.markSkipped(
          batch.first,
          reason: 'maxAttempts(pendingAttachment)',
        );
        expect(await statusOf(batch.first.queueId), 'abandoned');

        final resurrected = await queue.resurrectByPath(path);
        expect(resurrected, 1);
        expect(await statusOf(batch.first.queueId), 'enqueued');

        final row = await (db.select(
          db.inboundEventQueue,
        )..where((t) => t.queueId.equals(batch.first.queueId))).getSingle();
        expect(row.attempts, 0);
        expect(row.nextDueAt, 0);
        expect(row.lastErrorReason, isNull);
        expect(row.abandonedAt, isNull);
        expect(row.resurrectionCount, 1);
      },
    );

    test(
      'resurrection resets enqueued_at so pendingAttachment retries '
      'on the resurrected row get a fresh wall-clock deadline window',
      () async {
        const path = '/audio/2026-04-21/late.m4a.json';
        final original = DateTime(2026, 4, 21, 12);
        final resurrectAt = original.add(const Duration(hours: 2));

        // Enqueue at t=0 and abandon — anchors enqueuedAt to `original`.
        final batch = await withClock(Clock(() => original), () async {
          await queue.enqueueLive(
            _buildSyncEvent(
              eventId: r'$lateAudio',
              roomId: roomA,
              originTsMs: 700,
              content: <String, dynamic>{
                'msgtype': syncMessageType,
                'jsonPath': path,
              },
            ),
          );
          final pending = await queue.peekBatchReady();
          await queue.markSkipped(
            pending.first,
            reason: 'pendingAttachmentTimeout',
          );
          return pending;
        });

        final originalRow = await (db.select(
          db.inboundEventQueue,
        )..where((t) => t.queueId.equals(batch.first.queueId))).getSingle();
        expect(originalRow.enqueuedAt, original.millisecondsSinceEpoch);

        // Resurrect 2 hours later — the elapsed grace window measured
        // from the original enqueueAt would already exceed the worker's
        // 10-minute deadline, so the row must adopt the resurrection
        // timestamp instead.
        await withClock(Clock(() => resurrectAt), () async {
          final resurrected = await queue.resurrectByPath(path);
          expect(resurrected, 1);
        });

        final resurrectedRow = await (db.select(
          db.inboundEventQueue,
        )..where((t) => t.queueId.equals(batch.first.queueId))).getSingle();
        expect(resurrectedRow.enqueuedAt, resurrectAt.millisecondsSinceEpoch);
        expect(resurrectedRow.resurrectionCount, 1);
      },
    );

    test(
      'resurrectByPath respects the hard cap so a poison row that '
      'keeps failing to apply cannot thrash the worker forever',
      () async {
        const path = '/audio/2026-04-21/poison.m4a.json';
        await queue.enqueueLive(
          _buildSyncEvent(
            eventId: r'$poisonAudio',
            roomId: roomA,
            originTsMs: 600,
            content: <String, dynamic>{
              'msgtype': syncMessageType,
              'jsonPath': path,
            },
          ),
        );
        final batch = await queue.peekBatchReady();
        await queue.markSkipped(batch.first, reason: 'maxAttempts');

        // Simulate the row hitting the cap already.
        await (db.update(
          db.inboundEventQueue,
        )..where((t) => t.queueId.equals(batch.first.queueId))).write(
          const InboundEventQueueCompanion(resurrectionCount: Value(50)),
        );

        // ignore: avoid_redundant_argument_values
        final resurrected = await queue.resurrectByPath(path, hardCap: 50);
        expect(resurrected, 0);
        expect(await statusOf(batch.first.queueId), 'abandoned');
      },
    );

    test(
      'resurrectByPaths flips every abandoned row whose json_path '
      'is in the supplied set back to enqueued in a single SELECT + '
      'UPDATE round-trip — folds a burst of pathRecorded events into '
      'one DB call instead of N independent transactions',
      () async {
        const pathA = '/audio/2026-04-21/foo.m4a.json';
        const pathB = '/images/2026-04-21/bar.jpg.json';
        const pathC = '/audio/2026-04-21/baz.m4a.json';

        Future<int> abandonWithPath(String eventId, String path, int ts) async {
          await queue.enqueueLive(
            _buildSyncEvent(
              eventId: eventId,
              roomId: roomA,
              originTsMs: ts,
              content: <String, dynamic>{
                'msgtype': syncMessageType,
                'jsonPath': path,
              },
            ),
          );
          final batch = await queue.peekBatchReady();
          final target = batch.firstWhere((b) => b.eventId == eventId);
          await queue.markSkipped(
            target,
            reason: 'maxAttempts(pendingAttachment)',
          );
          return target.queueId;
        }

        final idA = await abandonWithPath(r'$a', pathA, 100);
        final idB = await abandonWithPath(r'$b', pathB, 200);
        final idC = await abandonWithPath(r'$c', pathC, 300);

        // Bulk call flips both pathA and pathB rows but leaves pathC
        // untouched, mirroring how a debounced burst from
        // `pathRecorded` should fan into one DB call rather than
        // three independent SELECT + UPDATE pairs.
        final resurrected = await queue.resurrectByPaths({pathA, pathB});
        expect(resurrected, 2);
        expect(await statusOf(idA), 'enqueued');
        expect(await statusOf(idB), 'enqueued');
        expect(await statusOf(idC), 'abandoned');
      },
    );

    test(
      'resurrectByPaths returns 0 on an empty set without touching the '
      'database — the debouncer drains a no-op tick when no path '
      'has been seen since the last flush',
      () async {
        final count = await queue.resurrectByPaths(const <String>{});
        expect(count, 0);
      },
    );

    test(
      'resurrectByPaths deduplicates the input set so a caller passing '
      'the same path twice never inflates the IN-list',
      () async {
        const path = '/audio/2026-04-21/dup.m4a.json';
        await queue.enqueueLive(
          _buildSyncEvent(
            eventId: r'$dup',
            roomId: roomA,
            originTsMs: 500,
            content: <String, dynamic>{
              'msgtype': syncMessageType,
              'jsonPath': path,
            },
          ),
        );
        final batch = await queue.peekBatchReady();
        await queue.markSkipped(batch.first, reason: 'pendingAttachment');

        final resurrected = await queue.resurrectByPaths([path, path, path]);
        expect(resurrected, 1);
        expect(await statusOf(batch.first.queueId), 'enqueued');
      },
    );

    test(
      'resurrectByPaths chunks the IN-list past 900 entries so a very '
      'large catch-up batch (initial sync downloading thousands of '
      'attachments) cannot trip SQLite SQLITE_MAX_VARIABLE_NUMBER '
      '(default 999)',
      () async {
        const realPath = '/audio/2026-04-21/real.m4a.json';
        await queue.enqueueLive(
          _buildSyncEvent(
            eventId: r'$real',
            roomId: roomA,
            originTsMs: 500,
            content: <String, dynamic>{
              'msgtype': syncMessageType,
              'jsonPath': realPath,
            },
          ),
        );
        final batch = await queue.peekBatchReady();
        await queue.markSkipped(batch.first, reason: 'pendingAttachment');

        // 1 800 synthetic paths = two full chunks at the 900-cap, plus
        // one real path embedded so we can confirm the row actually
        // flips. The crucial guard is that the call completes — a
        // pre-chunking version would raise SqliteException.
        final manyPaths = <String>[
          for (var i = 0; i < 1800; i++) '/synthetic/$i.json',
          realPath,
        ];

        final resurrected = await queue.resurrectByPaths(manyPaths);
        expect(resurrected, 1);
        expect(await statusOf(batch.first.queueId), 'enqueued');
      },
    );

    test(
      'resurrectAll flips every abandoned row under the hard cap back '
      'to enqueued — the "Retry all" Sync-Settings action',
      () async {
        await queue.enqueueLive(
          _buildSyncEvent(eventId: r'$a', roomId: roomA, originTsMs: 10),
        );
        await queue.enqueueLive(
          _buildSyncEvent(eventId: r'$b', roomId: roomA, originTsMs: 20),
        );
        final batch = await queue.peekBatchReady();
        for (final entry in batch) {
          await queue.markSkipped(entry, reason: 'user');
        }
        final resurrected = await queue.resurrectAll();
        expect(resurrected, 2);
        for (final entry in batch) {
          expect(await statusOf(entry.queueId), 'enqueued');
        }
      },
    );

    test(
      'resurrectByReason targets only abandoned rows whose last '
      'retry reason matches — the coordinator calls this on every '
      'journal update to un-park missingBase rows',
      () async {
        await queue.enqueueLive(
          _buildSyncEvent(
            eventId: r'$needsBase',
            roomId: roomA,
            originTsMs: 10,
          ),
        );
        await queue.enqueueLive(
          _buildSyncEvent(
            eventId: r'$needsAudio',
            roomId: roomA,
            originTsMs: 20,
          ),
        );
        final batch = await queue.peekBatchReady();
        final needsBase = batch.firstWhere((e) => e.eventId == r'$needsBase');
        final needsAudio = batch.firstWhere((e) => e.eventId == r'$needsAudio');
        await queue.markSkipped(needsBase, reason: 'missingBase');
        await queue.markSkipped(
          needsAudio,
          reason: 'maxAttempts(pendingAttachment)',
        );

        final resurrected = await queue.resurrectByReason('missingBase');
        expect(resurrected, 1);
        expect(await statusOf(needsBase.queueId), 'enqueued');
        expect(await statusOf(needsAudio.queueId), 'abandoned');
      },
    );

    test(
      'pruneStrandedEntries abandons stray rooms instead of deleting, '
      'so the ledger retains them for diagnostics while the worker no '
      'longer sees them as drainable',
      () async {
        await queue.enqueueLive(
          _buildSyncEvent(eventId: r'$keep', roomId: roomA, originTsMs: 1),
        );
        await queue.enqueueLive(
          _buildSyncEvent(eventId: r'$strand', roomId: roomB, originTsMs: 2),
        );
        final moved = await queue.pruneStrandedEntries(roomA);
        expect(moved, 1);

        final strandedRow = await (db.select(
          db.inboundEventQueue,
        )..where((t) => t.eventId.equals(r'$strand'))).getSingle();
        expect(strandedRow.status, 'abandoned');
        expect(strandedRow.lastErrorReason, 'strandedRoom');

        final stats = await queue.stats();
        expect(stats.total, 1);
        expect(stats.abandoned, 1);
      },
    );
  });
}
