import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/sync/matrix/pipeline/agent_vc_dominance_check.dart';
import 'package:lotti/features/sync/vector_clock.dart';

/// Unit tests for the standalone VC-dominance check. The class is
/// performance-critical — it runs once per incoming agent attachment
/// and the hot path was previously a 36 ms per-call `SELECT *` that
/// fired 1600+ times per hour during a sync drain. The tests cover:
///
///   * every early-exit shape the caller relies on to stay
///     conservative (null incoming VC, unparseable path, no local
///     row, malformed local VC JSON, concurrent clocks — all should
///     return false so the ingestor proceeds with the download),
///   * the cache invariants (hit, TTL expiry, capacity eviction),
///   * the three `VclockStatus` outcomes that `VectorClock.compare`
///     can return, pinned to the "skip download" vs "proceed" bit
///     the caller keys on.
void main() {
  late AgentDatabase db;

  setUp(() {
    db = AgentDatabase(inMemoryDatabase: true, background: false);
  });

  tearDown(() async => db.close());

  Future<void> insertEntityWithVc({
    required String id,
    required Map<String, dynamic> vc,
    String type = 'agent',
  }) async {
    final now = DateTime.now().toIso8601String();
    final serialized =
        '{"id":"$id","vectorClock":${_jsonVc(vc)},"deletedAt":null}';
    await db.customStatement(
      'INSERT INTO agent_entities '
      '(id, agent_id, type, created_at, updated_at, serialized, schema_version) '
      'VALUES (?, ?, ?, ?, ?, ?, 1)',
      [id, id, type, now, now, serialized],
    );
  }

  Future<void> insertEntityWithRawSerialized({
    required String id,
    required String serialized,
  }) async {
    final now = DateTime.now().toIso8601String();
    await db.customStatement(
      'INSERT INTO agent_entities '
      '(id, agent_id, type, created_at, updated_at, serialized, schema_version) '
      'VALUES (?, ?, ?, ?, ?, ?, 1)',
      [id, id, 'agent', now, now, serialized],
    );
  }

  Future<void> insertLinkWithVc({
    required String id,
    required Map<String, dynamic> vc,
    String fromId = 'f',
    String toId = 't',
    String type = 'agent_state',
  }) async {
    final now = DateTime.now().toIso8601String();
    final serialized =
        '{"id":"$id","vectorClock":${_jsonVc(vc)},"deletedAt":null}';
    await db.customStatement(
      'INSERT INTO agent_links '
      '(id, from_id, to_id, type, created_at, updated_at, serialized, schema_version) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, 1)',
      [id, fromId, toId, type, now, now, serialized],
    );
  }

  group('idFromPath', () {
    test(
      'extracts the `<uuid>` part of `/agent_entities/<uuid>.json`',
      () {
        expect(
          AgentVcDominanceCheck.idFromPath(
            '/agent_entities/abc-123.json',
          ),
          'abc-123',
        );
      },
    );

    test('extracts the id from an agent_links path', () {
      expect(
        AgentVcDominanceCheck.idFromPath('/agent_links/link-42.json'),
        'link-42',
      );
    });

    test('returns null when the path does not end in .json', () {
      expect(
        AgentVcDominanceCheck.idFromPath('/agent_entities/abc-123'),
        isNull,
      );
    });

    test('returns null on an empty path', () {
      expect(AgentVcDominanceCheck.idFromPath(''), isNull);
    });
  });

  group('check — conservative early exits', () {
    test('returns false when the incoming VC is null', () async {
      final c = AgentVcDominanceCheck(agentDb: db);
      expect(await c.check('/agent_entities/x.json', null), isFalse);
    });

    test('returns false for paths that are neither entity nor link', () async {
      final c = AgentVcDominanceCheck(agentDb: db);
      expect(
        await c.check('/somewhere-else/x.json', const VectorClock({'h': 1})),
        isFalse,
      );
    });

    test(
      'returns false when the path has the agent_entities prefix but the '
      'filename does not end in .json — idFromPath yields null and we '
      'cannot look anything up',
      () async {
        final c = AgentVcDominanceCheck(agentDb: db);
        expect(
          await c.check(
            '/agent_entities/no-extension',
            const VectorClock({'h': 1}),
          ),
          isFalse,
        );
      },
    );

    test('returns false when no local row exists', () async {
      final c = AgentVcDominanceCheck(agentDb: db);
      expect(
        await c.check(
          '/agent_entities/missing.json',
          const VectorClock({'h': 1}),
        ),
        isFalse,
      );
    });
  });

  group('check — VC comparison outcomes', () {
    test(
      'returns true when local VC dominates (a_gt_b) — caller skips '
      'the download because the on-disk file is already newer',
      () async {
        await insertEntityWithVc(id: 'e1', vc: {'h': 5});
        final c = AgentVcDominanceCheck(agentDb: db);
        expect(
          await c.check(
            '/agent_entities/e1.json',
            const VectorClock({'h': 3}),
          ),
          isTrue,
        );
      },
    );

    test(
      'returns true when local VC equals incoming VC — the file on '
      'disk is identical, so downloading again is wasted bytes',
      () async {
        await insertEntityWithVc(id: 'e2', vc: {'h': 5});
        final c = AgentVcDominanceCheck(agentDb: db);
        expect(
          await c.check(
            '/agent_entities/e2.json',
            const VectorClock({'h': 5}),
          ),
          isTrue,
        );
      },
    );

    test(
      'returns false when incoming VC dominates (b_gt_a) — the peer '
      'has a newer version so we must download',
      () async {
        await insertEntityWithVc(id: 'e3', vc: {'h': 5});
        final c = AgentVcDominanceCheck(agentDb: db);
        expect(
          await c.check(
            '/agent_entities/e3.json',
            const VectorClock({'h': 9}),
          ),
          isFalse,
        );
      },
    );

    test(
      'returns false when clocks are concurrent (neither dominates) — '
      'cannot infer local is sufficient, so proceed with download',
      () async {
        await insertEntityWithVc(id: 'e4', vc: {'alice': 3});
        final c = AgentVcDominanceCheck(agentDb: db);
        expect(
          await c.check(
            '/agent_entities/e4.json',
            const VectorClock({'bob': 3}),
          ),
          isFalse,
        );
      },
    );

    test(
      'agent_links path resolves through the link table (symmetric to '
      'agent_entities) — proves both caches are wired',
      () async {
        await insertLinkWithVc(id: 'l1', vc: {'h': 7});
        final c = AgentVcDominanceCheck(agentDb: db);
        expect(
          await c.check(
            '/agent_links/l1.json',
            const VectorClock({'h': 7}),
          ),
          isTrue,
        );
      },
    );
  });

  group('check — malformed DB JSON', () {
    test(
      'returns false when the stored serialized JSON does not contain a '
      'vectorClock at all — readNullable yields null, we skip gracefully',
      () async {
        await insertEntityWithRawSerialized(
          id: 'eNoVc',
          serialized: '{"id":"eNoVc"}',
        );
        final c = AgentVcDominanceCheck(agentDb: db);
        expect(
          await c.check(
            '/agent_entities/eNoVc.json',
            const VectorClock({'h': 1}),
          ),
          isFalse,
        );
      },
    );

    test(
      'returns false when the vectorClock JSON is structurally invalid — '
      'jsonDecode throws, the catch swallows, download proceeds',
      () async {
        // json_extract will return the string value "nope" (not a JSON
        // object). jsonDecode then succeeds but produces a non-Map,
        // which fails the Map<String, dynamic> type check.
        await insertEntityWithRawSerialized(
          id: 'eBadVc',
          serialized: '{"id":"eBadVc","vectorClock":"nope"}',
        );
        final c = AgentVcDominanceCheck(agentDb: db);
        expect(
          await c.check(
            '/agent_entities/eBadVc.json',
            const VectorClock({'h': 1}),
          ),
          isFalse,
        );
      },
    );
  });

  group('cache behaviour', () {
    test(
      'second lookup for the same id hits the cache — the DB loader is '
      'not invoked again within the TTL window',
      () async {
        await insertEntityWithVc(id: 'cached', vc: {'h': 5});
        var now = DateTime(2026, 4, 23, 10);
        final c = AgentVcDominanceCheck(
          agentDb: db,
          now: () => now,
          cacheTtl: const Duration(seconds: 30),
        );
        const incoming = VectorClock({'h': 3});

        // First call — populates the cache. Purely a correctness
        // anchor; the observable cache check is the later mutation.
        expect(
          await c.check('/agent_entities/cached.json', incoming),
          isTrue,
        );

        // Mutate the row directly in SQL so if the DB is hit again we
        // see a DIFFERENT answer (local would now be b_gt_a → false).
        // A cache hit masks the mutation → the check still returns
        // true, proving the loader was not invoked.
        await db.customStatement(
          'UPDATE agent_entities SET serialized = ? WHERE id = ?',
          [
            '{"id":"cached","vectorClock":${_jsonVc({'h': 1})},"deletedAt":null}',
            'cached',
          ],
        );

        // Still within TTL → cached answer returned (true), even
        // though the DB now says local VC is older than incoming.
        now = now.add(const Duration(seconds: 5));
        expect(
          await c.check('/agent_entities/cached.json', incoming),
          isTrue,
        );
      },
    );

    test(
      'cache entries expire after cacheTtl so a subsequent lookup '
      'picks up the mutated DB state — stale hits never persist',
      () async {
        await insertEntityWithVc(id: 'expire', vc: {'h': 5});
        var now = DateTime(2026, 4, 23, 10);
        final c = AgentVcDominanceCheck(
          agentDb: db,
          now: () => now,
        );
        const incoming = VectorClock({'h': 3});
        expect(
          await c.check('/agent_entities/expire.json', incoming),
          isTrue,
        );

        await db.customStatement(
          'UPDATE agent_entities SET serialized = ? WHERE id = ?',
          [
            '{"id":"expire","vectorClock":${_jsonVc({'h': 1})},"deletedAt":null}',
            'expire',
          ],
        );

        // Advance past the TTL.
        now = now.add(const Duration(seconds: 6));
        expect(
          await c.check('/agent_entities/expire.json', incoming),
          isFalse,
        );
      },
    );

    test(
      'cache capacity cap evicts the oldest entry (FIFO) when the cap '
      'is exceeded — protects against memory growth on a long run',
      () async {
        await insertEntityWithVc(id: 'first', vc: {'h': 5});
        await insertEntityWithVc(id: 'second', vc: {'h': 5});
        final c = AgentVcDominanceCheck(
          agentDb: db,
          cacheCapacity: 1,
          cacheTtl: const Duration(hours: 1),
        );
        const incoming = VectorClock({'h': 3});

        expect(
          await c.check('/agent_entities/first.json', incoming),
          isTrue,
        );
        // Second lookup evicts `first` — capacity is 1.
        expect(
          await c.check('/agent_entities/second.json', incoming),
          isTrue,
        );

        // Mutate `first` to make the DB disagree with any stale cache.
        await db.customStatement(
          'UPDATE agent_entities SET serialized = ? WHERE id = ?',
          [
            '{"id":"first","vectorClock":${_jsonVc({'h': 1})},"deletedAt":null}',
            'first',
          ],
        );
        // Cache entry for `first` was evicted, so the next lookup hits
        // the DB and sees the mutated row (local now b_gt_a → false).
        expect(
          await c.check('/agent_entities/first.json', incoming),
          isFalse,
        );
      },
    );
  });
}

String _jsonVc(Map<String, dynamic> vc) {
  final entries = vc.entries.map((e) => '"${e.key}":${e.value}').join(',');
  return '{$entries}';
}
