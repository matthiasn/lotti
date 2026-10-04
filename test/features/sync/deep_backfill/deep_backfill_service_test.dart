import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/sync_sequence_payload_type.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/deep_backfill/deep_backfill_service.dart';
import 'package:lotti/features/sync/deep_backfill/deep_backfill_store.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

const _me = 'host-me';
const _peer = 'host-peer';
const SyncSequencePayloadType _journal = SyncSequencePayloadType.journalEntity;
const SyncSequencePayloadType _links = SyncSequencePayloadType.entryLink;

/// An in-memory store: rows by id, open conflicts, file sizes, and every
/// resend asked of it.
class _FakeStore extends DeepBackfillStore {
  _FakeStore(
    this.payloadType, {
    Map<String, VectorClock?> rows = const {},
    this.conflicts = const {},
    Map<String, int> media = const {},
  }) : rows = SplayTreeMap.of(rows),
       media = Map.of(media);

  @override
  final SyncSequencePayloadType payloadType;
  final SplayTreeMap<String, VectorClock?> rows;
  final Map<String, List<VectorClock>> conflicts;
  final Map<String, int> media;
  final resent = <({Set<String> ids, Set<String> withMedia})>[];
  final changed = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => changed.stream;

  bool _inRange(String id, String? start, String? end) =>
      (start == null || id.compareTo(start) >= 0) &&
      (end == null || id.compareTo(end) < 0);

  @override
  Future<int> count() async => rows.length;

  @override
  Future<List<DeepBackfillRow>> page({
    required String? after,
    required int limit,
  }) async => [
    for (final MapEntry(key: id, value: clock) in rows.entries)
      if (after == null || id.compareTo(after) > 0) (id: id, clock: clock),
  ].take(limit).toList();

  @override
  Future<Map<String, VectorClock?>> range({
    required String? start,
    required String? end,
  }) async => {
    for (final MapEntry(key: id, value: clock) in rows.entries)
      if (_inRange(id, start, end)) id: clock,
  };

  @override
  Future<Map<String, List<VectorClock>>> openConflicts({
    required String? start,
    required String? end,
  }) async => {
    for (final MapEntry(key: id, value: clocks) in conflicts.entries)
      if (_inRange(id, start, end)) id: clocks,
  };

  @override
  Future<Map<String, int>> mediaSizes({
    required String? start,
    required String? end,
  }) async => {
    for (final MapEntry(key: id, value: size) in media.entries)
      if (_inRange(id, start, end)) id: size,
  };

  @override
  Future<int> enqueueCurrent(
    Set<String> ids, {
    required Set<String> withMedia,
  }) async {
    resent.add((ids: ids, withMedia: withMedia));
    return ids.where(rows.containsKey).length;
  }
}

void main() {
  late SyncDatabase syncDb;
  late MockOutboxService outbox;
  late MockVectorClockService vectorClock;
  late MockDomainLogger logger;
  late DateTime now;

  DeepBackfillService service({
    List<DeepBackfillStore> stores = const [],
    int batchSize = 2,
  }) => DeepBackfillService(
    syncDatabase: syncDb,
    outboxService: outbox,
    vectorClockService: vectorClock,
    loggingService: logger,
    stores: stores,
    now: () => now,
    newRoundId: () => 'round-1',
    batchSize: batchSize,
    requestExpiry: const Duration(hours: 1),
  );

  /// Everything queued through the throwing enqueue: inventory batches and
  /// requests, neither of which may be lost silently.
  List<SyncMessage> queued() => [
    ...verify(
      () => outbox.enqueueMessageOrThrow(captureAny()),
    ).captured.cast<SyncMessage>(),
  ];

  List<SyncDeepBackfillInventory> enqueued() =>
      queued().whereType<SyncDeepBackfillInventory>().toList();

  List<SyncDeepBackfillRequest> requestsSent() =>
      queued().whereType<SyncDeepBackfillRequest>().toList();

  SyncDeepBackfillInventory inventory({
    String hostId = _peer,
    SyncSequencePayloadType payloadType = _journal,
    String? start,
    String? end,
    Map<String, VectorClock> records = const {},
    Map<String, VectorClock> conflicts = const {},
    Map<String, int> mediaSizes = const {},
    String? attachmentEventId,
  }) =>
      SyncMessage.deepBackfillInventory(
            roundId: 'peer-round',
            hostId: hostId,
            payloadType: payloadType,
            batch: 0,
            rangeStart: start,
            rangeEnd: end,
            records: [
              for (final MapEntry(key: id, value: clock) in records.entries)
                DeepBackfillRecord(
                  id: id,
                  vectorClock: clock,
                  mediaSize: mediaSizes[id],
                ),
            ],
            conflicts: [
              for (final MapEntry(key: id, value: clock) in conflicts.entries)
                DeepBackfillRecord(id: id, vectorClock: clock),
            ],
            attachmentEventId: attachmentEventId,
          )
          as SyncDeepBackfillInventory;

  Future<Map<String, List<VectorClock>>> outstandingRows() async => {
    for (final row in await syncDb.deepBackfillRequestsInRange(
      targetHostId: _peer,
      payloadType: _journal,
      start: null,
      end: null,
    ))
      row.entryId: [
        for (final c in jsonDecode(row.vectorClocks) as List<dynamic>)
          VectorClock.fromJson(c as Map<String, dynamic>),
      ],
  };

  setUpAll(registerAllFallbackValues);

  setUp(() {
    syncDb = SyncDatabase(inMemoryDatabase: true);
    outbox = MockOutboxService();
    vectorClock = MockVectorClockService();
    logger = MockDomainLogger();
    now = DateTime(2024, 3, 15, 12);
    when(() => vectorClock.getHost()).thenAnswer((_) async => _me);
    when(() => outbox.enqueueMessage(any())).thenAnswer((_) async {});
    when(() => outbox.enqueueMessageOrThrow(any())).thenAnswer((_) async {});
    when(
      () => logger.log(any(), any(), subDomain: any(named: 'subDomain')),
    ).thenReturn(null);
  });

  tearDown(() => syncDb.close());

  group('runRound', () {
    test('tiles the keyspace: each range starts where the last ended, the '
        'first and last are unbounded', () async {
      final store = _FakeStore(
        _journal,
        rows: {
          'a': const VectorClock({'x': 1}),
          'b': const VectorClock({'x': 2}),
          'c': const VectorClock({'x': 3}),
          'd': const VectorClock({'x': 4}),
          'e': const VectorClock({'x': 5}),
        },
        conflicts: {
          'd': [
            const VectorClock({'y': 1}),
          ],
        },
      );
      final progress = <(int, int)>[];

      final summary = await service(stores: [store]).runRound(
        onProgress: (p) => progress.add((p.records, p.total)),
      );

      final batches = enqueued();
      expect(
        batches.map((b) => (b.batch, b.rangeStart, b.rangeEnd)),
        [(0, null, 'c'), (1, 'c', 'e'), (2, 'e', null)],
      );
      expect(
        batches.map((b) => b.records.map((r) => r.id).toList()),
        [
          ['a', 'b'],
          ['c', 'd'],
          ['e'],
        ],
      );
      expect(batches[1].conflicts.single.id, 'd');
      expect(batches.first.conflicts, isEmpty);
      expect(
        batches.every(
          (b) =>
              b.hostId == _me &&
              b.roundId == 'round-1' &&
              b.payloadType == _journal,
        ),
        isTrue,
      );
      expect(progress, [(2, 5), (4, 5), (5, 5)]);
      expect(summary.batches, 3);
      expect(summary.records, 5);
      expect(summary.recordsByType, {_journal: 5});
    });

    test("lists each live media record's file size next to its clock, and "
        'none for a record without media', () async {
      final store = _FakeStore(
        _journal,
        rows: {
          'image': const VectorClock({'x': 1}),
          'missing': const VectorClock({'x': 2}),
          'text': const VectorClock({'x': 3}),
        },
        media: {'image': 5, 'missing': 0},
      );

      await service(stores: [store], batchSize: 10).runRound();

      expect(
        enqueued().single.records.map((r) => (r.id, r.mediaSize)),
        [('image', 5), ('missing', 0), ('text', null)],
      );
    });

    test('a store without rows still sends one empty batch covering '
        'everything, and each store tiles on its own', () async {
      await service(
        stores: [
          _FakeStore(_journal),
          _FakeStore(
            _links,
            rows: {
              'k': const VectorClock({'x': 1}),
            },
          ),
        ],
      ).runRound();

      final batches = enqueued();
      expect(
        batches.map(
          (b) => (b.payloadType, b.rangeStart, b.rangeEnd, b.records.length),
        ),
        [(_journal, null, null, 0), (_links, null, null, 1)],
      );
    });

    test('names rows without a clock instead of listing them — they cannot '
        'be ordered, but they exist', () async {
      await service(
        stores: [
          _FakeStore(
            _journal,
            rows: {
              'a': null,
              'b': const VectorClock({'x': 1}),
              'c': null,
            },
            media: {'a': 5, 'b': 7},
          ),
        ],
        batchSize: 10,
      ).runRound();

      final batch = enqueued().single;
      expect(batch.records.map((r) => r.id), ['b']);
      expect(batch.unclocked, ['a', 'c']);
      // A legacy row's file is compared like any other: its size travels
      // next to its name. 'c' carries no media.
      expect(batch.unclockedMediaSizes, {'a': 5});
    });

    test("needs this device's host id", () async {
      when(() => vectorClock.getHost()).thenAnswer((_) async => null);

      await expectLater(
        service(stores: [_FakeStore(_journal)]).runRound(),
        throwsStateError,
      );
      verifyNever(() => outbox.enqueueMessageOrThrow(any()));
    });

    test('fails the round when a batch cannot be queued, rather than report '
        'its range as compared', () async {
      when(
        () => outbox.enqueueMessageOrThrow(any()),
      ).thenThrow(StateError('outbox down'));
      final progress = <int>[];

      await expectLater(
        service(
          stores: [
            _FakeStore(
              _journal,
              rows: {
                'a': const VectorClock({'x': 1}),
              },
            ),
          ],
        ).runRound(onProgress: (p) => progress.add(p.records)),
        throwsStateError,
      );
      expect(progress, isEmpty);
    });
  });

  group('handleInventory', () {
    test('requests what it lacks or holds older, pushes what it holds newer '
        'or alone, and records what it asked for', () async {
      final store = _FakeStore(
        _journal,
        rows: {
          'older': const VectorClock({'x': 1}),
          'newer': const VectorClock({'x': 3}),
          'alone': const VectorClock({'x': 1}),
        },
      );

      await service(stores: [store]).handleInventory(
        inventory(
          records: {
            'absent': const VectorClock({'x': 1}),
            'older': const VectorClock({'x': 2}),
            'newer': const VectorClock({'x': 2}),
          },
        ),
      );

      final request = requestsSent().single;
      expect(request.requesterId, _me);
      expect(request.targetHostId, _peer);
      expect(request.payloadType, _journal);
      expect(
        {for (final r in request.records) r.id: r.absent},
        {'absent': true, 'older': false},
      );
      expect(await outstandingRows(), {
        'absent': [
          const VectorClock({'x': 1}),
        ],
        'older': [
          const VectorClock({'x': 2}),
        ],
      });
      expect(store.resent.single.ids, {'newer', 'alone'});
      expect(store.resent.single.withMedia, {'alone'});
    });

    test('does not ask again while a request is outstanding, and settles it '
        'once the local row covers the version asked for', () async {
      final store = _FakeStore(_journal);
      final svc = service(stores: [store]);
      final batch = inventory(
        records: {
          'r': const VectorClock({'x': 2}),
        },
      );

      await svc.handleInventory(batch);
      await svc.handleInventory(batch);
      expect(requestsSent(), hasLength(1));

      // The answer arrives — from whichever device — and is stored.
      store.rows['r'] = const VectorClock({'x': 2});
      await svc.handleInventory(batch);

      expect(await outstandingRows(), isEmpty);
      verifyNever(() => outbox.enqueueMessageOrThrow(any()));
    });

    test(
      'does not push back a record the advertiser holds without a clock',
      () async {
        final store = _FakeStore(_journal, rows: {'old': null});

        await service(stores: [store]).handleInventory(
          const SyncMessage.deepBackfillInventory(
                roundId: 'peer-round',
                hostId: _peer,
                payloadType: _journal,
                batch: 0,
                unclocked: ['old'],
              )
              as SyncDeepBackfillInventory,
        );

        expect(store.resent, isEmpty);
        verifyNever(() => outbox.enqueueMessageOrThrow(any()));
      },
    );

    test(
      'asks for a clockless record it lacks, and settles on any row',
      () async {
        final store = _FakeStore(_journal);
        final svc = service(stores: [store]);
        const batch =
            SyncMessage.deepBackfillInventory(
                  roundId: 'peer-round',
                  hostId: _peer,
                  payloadType: _journal,
                  batch: 0,
                  unclocked: ['old'],
                )
                as SyncDeepBackfillInventory;

        await svc.handleInventory(batch);
        final asked = requestsSent().single.records.single;
        expect(asked.id, 'old');
        expect(asked.absent, isTrue);

        store.rows['old'] = null;
        await svc.handleInventory(batch);
        expect(await outstandingRows(), isEmpty);
      },
    );

    test('keeps a request open when a version arrives that does not cover '
        'it', () async {
      final store = _FakeStore(_journal);
      final svc = service(stores: [store]);
      final batch = inventory(
        records: {
          'r': const VectorClock({'x': 2}),
        },
      );

      await svc.handleInventory(batch);
      store.rows['r'] = const VectorClock({'x': 1});
      await svc.handleInventory(batch);

      expect(requestsSent(), hasLength(1));
      expect((await outstandingRows()).keys, ['r']);
    });

    test('asks again once a request has expired', () async {
      final svc = service(stores: [_FakeStore(_journal)]);
      final batch = inventory(
        records: {
          'r': const VectorClock({'x': 2}),
        },
      );

      await svc.handleInventory(batch);
      now = now.add(const Duration(hours: 1, minutes: 1));
      await svc.handleInventory(batch);

      expect(requestsSent(), hasLength(2));
    });

    test("settles only the outstanding rows in the batch's range", () async {
      final svc = service(
        stores: [
          _FakeStore(
            _journal,
            rows: {
              'm': const VectorClock({'x': 9}),
            },
          ),
        ],
      );
      await svc.handleInventory(
        inventory(
          records: {
            'a': const VectorClock({'x': 1}),
            'm': const VectorClock({'x': 10}),
          },
        ),
      );

      now = now.add(const Duration(hours: 2));
      await svc.handleInventory(inventory(start: 'b', end: 'z'));

      expect((await outstandingRows()).keys, ['a']);
    });

    test('forgets the recorded rows when the request cannot be queued, so the '
        'next round asks again', () async {
      when(
        () => outbox.enqueueMessageOrThrow(any()),
      ).thenThrow(StateError('outbox down'));
      final svc = service(stores: [_FakeStore(_journal)]);

      await expectLater(
        svc.handleInventory(
          inventory(
            records: {
              'r': const VectorClock({'x': 2}),
            },
          ),
        ),
        throwsStateError,
      );
      expect(await outstandingRows(), isEmpty);
    });

    test('still pushes what the advertiser is owed when the request cannot '
        'be queued', () async {
      when(
        () => outbox.enqueueMessageOrThrow(any()),
      ).thenThrow(StateError('outbox down'));
      final store = _FakeStore(
        _journal,
        rows: {
          'mine': const VectorClock({'x': 1}),
        },
      );

      await expectLater(
        service(stores: [store]).handleInventory(
          inventory(
            records: {
              'theirs': const VectorClock({'x': 1}),
            },
          ),
        ),
        throwsStateError,
      );
      expect(store.resent.single.ids, {'mine'});
    });

    test('ignores its own inventory, lists never loaded from their '
        'attachment, and payload types it has no store for', () async {
      final store = _FakeStore(
        _journal,
        rows: {
          'r': const VectorClock({'x': 1}),
        },
      );
      final svc = service(stores: [store]);
      final records = {
        'z': const VectorClock({'x': 1}),
      };

      await svc.handleInventory(inventory(hostId: _me, records: records));
      await svc.handleInventory(
        inventory(records: records, attachmentEventId: r'$unresolved'),
      );
      await svc.handleInventory(
        inventory(payloadType: _links, records: records),
      );

      verifyNever(() => outbox.enqueueMessageOrThrow(any()));
      expect(store.resent, isEmpty);
    });
  });

  group('handleInventory — files', () {
    const clock = VectorClock({'x': 1});

    test('asks for a missing or truncated file at equal clocks, and pushes a '
        'larger one back with its file', () async {
      final store = _FakeStore(
        _journal,
        rows: {'missing': clock, 'short': clock, 'long': clock, 'same': clock},
        media: {'missing': 0, 'short': 2, 'long': 9, 'same': 4},
      );

      await service(stores: [store]).handleInventory(
        inventory(
          records: {
            'missing': clock,
            'short': clock,
            'long': clock,
            'same': clock,
          },
          mediaSizes: {'missing': 7, 'short': 10, 'long': 3, 'same': 4},
        ),
      );

      expect(requestsSent().single.records, [
        const DeepBackfillRequestRecord(id: 'missing', media: true),
        const DeepBackfillRequestRecord(id: 'short', media: true),
      ]);
      final rows = await syncDb.deepBackfillRequestsInRange(
        targetHostId: _peer,
        payloadType: _journal,
        start: null,
        end: null,
      );
      expect(rows.map((r) => (r.entryId, r.vectorClocks, r.mediaSize)), [
        ('missing', '[]', 7),
        ('short', '[]', 10),
      ]);
      expect(store.resent.single.ids, {'long'});
      expect(store.resent.single.withMedia, {'long'});
    });

    test('keeps a file request open until the local copy is as large as the '
        'one asked for, then asks nothing more', () async {
      final store = _FakeStore(
        _journal,
        rows: {'r': clock},
        media: {'r': 0},
      );
      final svc = service(stores: [store]);
      final batch = inventory(records: {'r': clock}, mediaSizes: {'r': 10});

      await svc.handleInventory(batch);
      // A truncated copy arrives from somewhere: not enough.
      store.media['r'] = 4;
      await svc.handleInventory(batch);
      expect(requestsSent(), hasLength(1));
      expect((await outstandingRows()).keys, ['r']);

      store.media['r'] = 10;
      await svc.handleInventory(batch);
      expect(await outstandingRows(), isEmpty);
      verifyNever(() => outbox.enqueueMessageOrThrow(any()));
    });

    test('asks for the file of a clockless record both devices hold', () async {
      final store = _FakeStore(
        _journal,
        rows: {'old': null},
        media: {'old': 3},
      );

      await service(stores: [store]).handleInventory(
        const SyncMessage.deepBackfillInventory(
              roundId: 'peer-round',
              hostId: _peer,
              payloadType: _journal,
              batch: 0,
              unclocked: ['old'],
              unclockedMediaSizes: {'old': 10},
            )
            as SyncDeepBackfillInventory,
      );

      expect(requestsSent().single.records, [
        const DeepBackfillRequestRecord(id: 'old', media: true),
      ]);
    });

    test('compares no files with a peer that lists no sizes', () async {
      final store = _FakeStore(
        _journal,
        rows: {'r': clock},
        media: {'r': 0},
      );

      await service(stores: [store]).handleInventory(
        inventory(records: {'r': clock}),
      );

      verifyNever(() => outbox.enqueueMessageOrThrow(any()));
      expect(store.resent, isEmpty);
    });
  });

  group('handleRequest', () {
    SyncDeepBackfillRequest request({
      String target = _me,
      SyncSequencePayloadType payloadType = _journal,
      String? attachmentEventId,
    }) =>
        SyncMessage.deepBackfillRequest(
              requesterId: _peer,
              targetHostId: target,
              payloadType: payloadType,
              records: const [
                DeepBackfillRequestRecord(id: 'a', absent: true),
                DeepBackfillRequestRecord(id: 'b'),
              ],
              attachmentEventId: attachmentEventId,
            )
            as SyncDeepBackfillRequest;

    test('resends the current version of each record, with media where the '
        'requester has none', () async {
      final store = _FakeStore(_journal, rows: {'a': null, 'b': null});

      await service(stores: [store]).handleRequest(request());

      expect(store.resent.single.ids, {'a', 'b'});
      expect(store.resent.single.withMedia, {'a'});
    });

    test('answers a request for a file with the file, whatever the '
        'resend-attachments setting says', () async {
      final store = _FakeStore(_journal, rows: {'a': null, 'b': null});

      await service(stores: [store]).handleRequest(
        const SyncMessage.deepBackfillRequest(
              requesterId: _peer,
              targetHostId: _me,
              payloadType: _journal,
              records: [
                DeepBackfillRequestRecord(id: 'a', media: true),
                DeepBackfillRequestRecord(id: 'b'),
              ],
            )
            as SyncDeepBackfillRequest,
      );

      // The store enqueues with includeAttachments, which the attachment
      // policy honours without consulting the flag.
      expect(store.resent.single.withMedia, {'a'});
    });

    test('answers only requests addressed to this device, with loaded lists, '
        'for a type it has a store for', () async {
      final store = _FakeStore(_journal);
      final svc = service(stores: [store]);

      await svc.handleRequest(request(target: 'someone-else'));
      await svc.handleRequest(request(attachmentEventId: r'$unresolved'));
      await svc.handleRequest(request(payloadType: _links));

      expect(store.resent, isEmpty);
    });
  });

  test(
    'recordCounts counts each registered type, deletions included',
    () async {
      final counts = await service(
        stores: [
          _FakeStore(
            _journal,
            rows: {
              'a': const VectorClock({'x': 1}),
              'b': null,
            },
          ),
          _FakeStore(_links),
        ],
      ).recordCounts();

      expect(counts, {_journal: 2, _links: 0});
    },
  );

  test('recordCounts with only counts just those types', () async {
    final links = _FakeStore(_links, rows: {'l': null});
    final svc = service(stores: [_FakeStore(_journal), links]);

    expect(await svc.recordCounts(only: {_links}), {_links: 1});
    expect(await svc.recordCounts(only: const {}), isEmpty);
  });

  test('recordChanges names the type of each store whose table changed', () {
    fakeAsync((async) {
      final journal = _FakeStore(_journal);
      final links = _FakeStore(_links);
      final seen = <SyncSequencePayloadType>[];
      service(stores: [journal, links]).recordChanges.listen(seen.add);

      links.changed.add(null);
      journal.changed.add(null);
      links.changed.add(null);
      async.flushMicrotasks();

      expect(seen, [_links, _journal, _links]);
    });
  });
}
