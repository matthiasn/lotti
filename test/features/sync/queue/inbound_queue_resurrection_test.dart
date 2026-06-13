import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/queue/inbound_queue_models.dart';
import 'package:lotti/features/sync/queue/inbound_queue_resurrection.dart';
import 'package:lotti/services/logging_domains.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import 'test_utils.dart';

const _roomA = '!roomA:example.org';
final _frozenNow = DateTime(2024, 3, 15, 12);

void main() {
  late SyncDatabase db;
  late MockDomainLogger logging;
  late int depthChangedCalls;
  late InboundQueueResurrection resurrection;

  setUp(() {
    db = SyncDatabase(inMemoryDatabase: true);
    logging = MockDomainLogger();
    depthChangedCalls = 0;
    resurrection = InboundQueueResurrection(
      db: db,
      logging: logging,
      onDepthChanged: () => depthChangedCalls++,
    );
  });

  tearDown(() async {
    await db.close();
  });

  var rowSeq = 0;
  Future<int> insertRow({
    String status = InboundQueueStatuses.abandoned,
    String? jsonPath,
    String? lastErrorReason = 'missingBase',
    int resurrectionCount = 0,
  }) {
    rowSeq++;
    return db
        .into(db.inboundEventQueue)
        .insert(
          InboundEventQueueCompanion.insert(
            eventId: '\$row-$rowSeq',
            roomId: _roomA,
            originTs: rowSeq * 1000,
            producer: InboundEventProducer.live.name,
            rawJson: '{}',
            enqueuedAt: 1000,
            attempts: const Value(5),
            nextDueAt: const Value(99999),
            leaseUntil: const Value(88888),
            status: Value(status),
            abandonedAt: const Value(2000),
            lastErrorReason: Value(lastErrorReason),
            resurrectionCount: Value(resurrectionCount),
            jsonPath: Value(jsonPath),
          ),
        );
  }

  Future<InboundEventQueueItem> readRow(int queueId) => (db.select(
    db.inboundEventQueue,
  )..where((t) => t.queueId.equals(queueId))).getSingle();

  group('resurrectByPath', () {
    test(
      'flips the matching abandoned row back to a fresh enqueued state',
      () async {
        final queueId = await insertRow(jsonPath: '/a/b.json');
        await insertRow(jsonPath: '/other.json');

        final count = await withClock(
          Clock.fixed(_frozenNow),
          () => resurrection.resurrectByPath('/a/b.json'),
        );

        expect(count, 1);
        expect(depthChangedCalls, 1);
        final row = await readRow(queueId);
        expect(row.status, InboundQueueStatuses.enqueued);
        expect(row.resurrectionCount, 1);
        expect(row.attempts, 0);
        expect(row.nextDueAt, 0);
        expect(row.leaseUntil, 0);
        // Fresh wall-clock deadline for pendingAttachment retries.
        expect(row.enqueuedAt, _frozenNow.millisecondsSinceEpoch);
        expect(row.lastErrorReason, isNull);
        expect(row.abandonedAt, isNull);
        verify(
          () => logging.log(
            LogDomain.sync,
            any(that: contains('path=/a/b.json')),
            subDomain: 'queue.resurrect',
          ),
        ).called(1);
      },
    );

    test('non-matching path resurrects nothing and stays silent', () async {
      final otherId = await insertRow(jsonPath: '/other.json');
      final count = await resurrection.resurrectByPath('/missing.json');
      expect(count, 0);
      expect(depthChangedCalls, 0);
      expect(
        (await readRow(otherId)).status,
        InboundQueueStatuses.abandoned,
      );
    });

    test('rows at or above the hard cap are skipped', () async {
      final cappedId = await insertRow(
        jsonPath: '/p.json',
        resurrectionCount: 2,
      );
      final eligibleId = await insertRow(
        jsonPath: '/p.json',
        resurrectionCount: 1,
      );

      final count = await resurrection.resurrectByPath('/p.json', hardCap: 2);

      expect(count, 1);
      expect(
        (await readRow(cappedId)).status,
        InboundQueueStatuses.abandoned,
      );
      expect(
        (await readRow(eligibleId)).status,
        InboundQueueStatuses.enqueued,
      );
    });

    test('only abandoned rows are eligible — active rows stay put', () async {
      final activeId = await insertRow(
        status: InboundQueueStatuses.retrying,
        jsonPath: '/p.json',
      );
      final count = await resurrection.resurrectByPath('/p.json');
      expect(count, 0);
      final row = await readRow(activeId);
      expect(row.status, InboundQueueStatuses.retrying);
      expect(row.resurrectionCount, 0);
    });
  });

  group('resurrectByPaths', () {
    test('empty input returns 0 without signalling', () async {
      expect(await resurrection.resurrectByPaths(const []), 0);
      expect(depthChangedCalls, 0);
      verifyNever(
        () => logging.log(
          any(),
          any(),
          subDomain: any(named: 'subDomain'),
        ),
      );
    });

    test('duplicate paths are deduplicated before querying', () async {
      final queueId = await insertRow(jsonPath: '/dup.json');
      final count = await resurrection.resurrectByPaths(
        ['/dup.json', '/dup.json', '/dup.json'],
      );
      expect(count, 1);
      expect((await readRow(queueId)).resurrectionCount, 1);
      expect(depthChangedCalls, 1);
    });

    test(
      'a batch above the 900-path chunk size resurrects every row '
      'across two round-trips',
      () async {
        const pathCount = 901;
        final paths = <String>[];
        for (var i = 0; i < pathCount; i++) {
          final path = '/chunk/$i.json';
          paths.add(path);
          await insertRow(jsonPath: path);
        }

        final count = await resurrection.resurrectByPaths(paths);

        expect(count, pathCount);
        // One depth signal per non-empty chunk pins the 900-row
        // chunking boundary (901 paths → 2 chunks).
        expect(depthChangedCalls, 2);
        final remaining =
            await (db.select(db.inboundEventQueue)..where(
                  (t) => t.status.equals(InboundQueueStatuses.abandoned),
                ))
                .get();
        expect(remaining, isEmpty);
      },
    );
  });

  group('resurrectAll', () {
    test('flips every eligible abandoned row regardless of path', () async {
      await insertRow(jsonPath: '/a.json');
      await insertRow(lastErrorReason: 'retriable');
      final cappedId = await insertRow(resurrectionCount: 50);
      final appliedId = await insertRow(status: InboundQueueStatuses.applied);

      final count = await resurrection.resurrectAll();

      expect(count, 2);
      expect(depthChangedCalls, 1);
      expect(
        (await readRow(cappedId)).status,
        InboundQueueStatuses.abandoned,
      );
      expect((await readRow(appliedId)).status, InboundQueueStatuses.applied);
    });
  });

  group('resurrectByReason', () {
    test('only rows with the matching last error reason flip', () async {
      final matchingId = await insertRow();
      final otherId = await insertRow(lastErrorReason: 'retriable');

      final count = await resurrection.resurrectByReason('missingBase');

      expect(count, 1);
      expect(
        (await readRow(matchingId)).status,
        InboundQueueStatuses.enqueued,
      );
      expect(
        (await readRow(otherId)).status,
        InboundQueueStatuses.abandoned,
      );
    });
  });

  group('extractJsonPath', () {
    test('reads jsonPath and json_path keys from sync content', () {
      expect(
        extractJsonPath(
          buildSyncEvent(
            eventId: r'$camel',
            roomId: _roomA,
            originTsMs: 1000,
            content: const {'msgtype': 'm.text', 'jsonPath': '/x/y.json'},
          ),
        ),
        '/x/y.json',
      );
      expect(
        extractJsonPath(
          buildSyncEvent(
            eventId: r'$snake',
            roomId: _roomA,
            originTsMs: 1000,
            content: const {'msgtype': 'm.text', 'json_path': '/s.json'},
          ),
        ),
        '/s.json',
      );
    });

    test('normalises a missing leading slash', () {
      expect(
        extractJsonPath(
          buildSyncEvent(
            eventId: r'$rel',
            roomId: _roomA,
            originTsMs: 1000,
            content: const {'jsonPath': 'relative/p.json'},
          ),
        ),
        '/relative/p.json',
      );
    });

    test('returns null for absent, empty, or non-string paths', () {
      for (final content in <Map<String, dynamic>>[
        const {'msgtype': 'm.text'},
        const {'jsonPath': ''},
        const {'jsonPath': 42},
        const {'json_path': null},
      ]) {
        expect(
          extractJsonPath(
            buildSyncEvent(
              eventId: r'$none',
              roomId: _roomA,
              originTsMs: 1000,
              content: content,
            ),
          ),
          isNull,
          reason: 'content=$content',
        );
      }
    });

    test('a throwing content getter is swallowed defensively', () {
      final event = MockEvent();
      when(() => event.content).thenThrow(StateError('shape drift'));
      expect(extractJsonPath(event), isNull);
    });
  });

  glados.Glados(
    glados.any.letterOrDigits,
    glados.ExploreConfig(numRuns: 120),
  ).test(
    'extractJsonPath always yields a slash-anchored copy of the raw path',
    (
      rawPath,
    ) {
      final extracted = extractJsonPath(
        buildSyncEvent(
          eventId: r'$gen',
          roomId: _roomA,
          originTsMs: 1000,
          content: {'jsonPath': rawPath},
        ),
      );
      if (rawPath.isEmpty) {
        expect(extracted, isNull, reason: 'rawPath=<empty>');
      } else {
        expect(
          extracted,
          rawPath.startsWith('/') ? rawPath : '/$rawPath',
          reason: 'rawPath=$rawPath',
        );
        expect(extracted, startsWith('/'), reason: 'rawPath=$rawPath');
      }
    },
    tags: 'glados',
  );
}
