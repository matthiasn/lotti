import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/database/agent_entity_by_id_coalescer.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';

import '../test_data/entity_factories.dart';

/// Tests for [AgentEntityByIdCoalescer].
///
/// The coalescer's whole purpose is to change *how many* batched reads happen
/// for a given pattern of `load` calls, so every test here asserts on the
/// recorded batches — the id sets actually handed to the loader — rather than
/// only on the returned values. A test that checked values alone would pass
/// just as happily with the coalescing removed.
void main() {
  /// Records every batch the coalescer dispatches so tests can assert on
  /// round-trip count and batch composition.
  late List<List<String>> batches;
  late Map<String, AgentDomainEntity> table;

  AgentEntityByIdCoalescer build({
    Future<void> Function()? gate,
    Object? throwError,
  }) {
    return AgentEntityByIdCoalescer((ids) async {
      batches.add(ids.toList());
      if (gate != null) await gate();
      if (throwError != null) {
        // ignore: only_throw_errors
        throw throwError;
      }
      return {
        for (final id in ids)
          if (table.containsKey(id)) id: table[id]!,
      };
    });
  }

  setUp(() {
    batches = <List<String>>[];
    table = {
      'a': makeTestIdentity(id: 'a', agentId: 'a', displayName: 'Agent A'),
      'b': makeTestIdentity(id: 'b', agentId: 'b', displayName: 'Agent B'),
      'c': makeTestIdentity(id: 'c', agentId: 'c', displayName: 'Agent C'),
    };
  });

  test(
    'folds concurrent loads in one turn into a single batched read',
    () async {
      final coalescer = build();

      final results = await Future.wait([
        coalescer.load('a'),
        coalescer.load('b'),
        coalescer.load('c'),
      ]);

      expect(
        batches,
        hasLength(1),
        reason: '3 concurrent loads must cost 1 round trip, not 3',
      );
      expect(batches.single, containsAll(<String>['a', 'b', 'c']));
      expect(
        results.map((e) => (e! as AgentIdentityEntity).displayName),
        ['Agent A', 'Agent B', 'Agent C'],
        reason: 'each caller must still receive the entity for its own id',
      );
    },
  );

  test(
    'scales: 600 concurrent loads still cost exactly one round trip',
    () async {
      // Mirrors the production burst that motivated this class — 606 single-id
      // reads dispatched inside one second.
      table = {
        for (var i = 0; i < 600; i++)
          'id-$i': makeTestIdentity(id: 'id-$i', agentId: 'id-$i'),
      };
      final coalescer = build();

      final results = await Future.wait([
        for (var i = 0; i < 600; i++) coalescer.load('id-$i'),
      ]);

      expect(batches, hasLength(1));
      expect(batches.single, hasLength(600));
      expect(results.where((e) => e != null), hasLength(600));
    },
  );

  test('deduplicates repeated ids but completes every caller', () async {
    final coalescer = build();

    final results = await Future.wait([
      coalescer.load('a'),
      coalescer.load('a'),
      coalescer.load('b'),
    ]);

    expect(batches.single, <String>['a', 'b'], reason: 'id "a" queried once');
    expect(results, hasLength(3));
    expect(
      results[0],
      same(results[1]),
      reason: 'both "a" callers share a row',
    );
    expect((results[2]! as AgentIdentityEntity).displayName, 'Agent B');
  });

  test('sequentially awaited loads land in separate batches', () async {
    final coalescer = build();

    await coalescer.load('a');
    await coalescer.load('b');

    expect(
      batches,
      [
        ['a'],
        ['b'],
      ],
      reason: 'awaited calls are not concurrent and must not be merged',
    );
  });

  test('loads issued while a batch is in flight form a new batch', () async {
    final gate = Completer<void>();
    // Signalled by the loader itself the moment the first batch is dispatched,
    // so the test waits on an actual event rather than on event-loop timing.
    final dispatched = Completer<void>();
    final coalescer = AgentEntityByIdCoalescer((ids) async {
      batches.add(ids.toList());
      if (!dispatched.isCompleted) dispatched.complete();
      await gate.future;
      return {
        for (final id in ids)
          if (table.containsKey(id)) id: table[id]!,
      };
    });

    final first = coalescer.load('a');
    await dispatched.future;
    expect(batches, hasLength(1));

    final second = coalescer.load('b');
    gate.complete();
    await Future.wait([first, second]);

    expect(
      batches,
      [
        ['a'],
        ['b'],
      ],
      reason: 'the in-flight batch was already dispatched and cannot be joined',
    );
  });

  test('returns null for ids with no row, without failing the batch', () async {
    final coalescer = build();

    final results = await Future.wait([
      coalescer.load('a'),
      coalescer.load('missing'),
    ]);

    expect(batches.single, containsAll(<String>['a', 'missing']));
    expect(results[0], isNotNull);
    expect(results[1], isNull);
  });

  test('propagates a persistent failure to every caller', () async {
    // When the failure is not row-specific (the database is simply
    // unavailable), the per-id fallback fails too and every caller sees the
    // error — the same outcome each would have had issuing its own read.
    final coalescer = build(throwError: StateError('db down'));

    final a = coalescer.load('a');
    final b = coalescer.load('b');

    await Future.wait([
      expectLater(a, throwsA(isA<StateError>())),
      expectLater(b, throwsA(isA<StateError>())),
    ]);
    expect(
      batches,
      hasLength(3),
      reason: 'one batch attempt, then one single-id retry per waiter',
    );
  });

  test('one undecodable row does not poison the rest of the batch', () async {
    // Before coalescing, a row whose serialized payload fails to decode failed
    // only its own getEntity call. The batched read maps the whole result set
    // at once, so without isolation one bad row would fail every waiter that
    // happened to share its microtask.
    final coalescer = AgentEntityByIdCoalescer((ids) async {
      batches.add(ids.toList());
      if (ids.contains('poison') && ids.length > 1) {
        throw const FormatException('undecodable row in batch');
      }
      if (ids.single == 'poison') {
        throw const FormatException('undecodable row');
      }
      return {
        for (final id in ids)
          if (table.containsKey(id)) id: table[id]!,
      };
    });

    final good = coalescer.load('a');
    final bad = coalescer.load('poison');
    final alsoGood = coalescer.load('b');
    // Attach the error expectation immediately: `bad` completes with an error
    // while the other two are still being awaited, and an error delivered to a
    // future that has no listener yet is reported as unhandled.
    final badExpectation = expectLater(
      bad,
      throwsA(isA<FormatException>()),
      reason: 'only the offending id sees the error',
    );

    expect(
      await good,
      isA<AgentIdentityEntity>(),
      reason: 'an unrelated id must still resolve',
    );
    expect(await alsoGood, isA<AgentIdentityEntity>());
    await badExpectation;

    expect(
      batches.first,
      containsAll(<String>['a', 'poison', 'b']),
      reason: 'the fast path still attempts one batch first',
    );
    expect(
      batches.length,
      4,
      reason:
          'batch attempt + one single-id retry per waiter on the error path',
    );
  });

  test('a transient batch failure is rescued by the per-id retry', () async {
    var shouldFail = true;
    final coalescer = AgentEntityByIdCoalescer((ids) async {
      batches.add(ids.toList());
      if (shouldFail) {
        shouldFail = false;
        throw StateError('transient');
      }
      return {
        for (final id in ids)
          if (table.containsKey(id)) id: table[id]!,
      };
    });

    expect(
      await coalescer.load('a'),
      isNotNull,
      reason: 'the batch attempt failed; the single-id retry succeeded',
    );
    expect(batches, hasLength(2));

    // And the coalescer is back on the fast path afterwards.
    expect(await coalescer.load('b'), isNotNull);
    expect(batches, hasLength(3));
  });

  group('zone isolation (drift transaction safety)', () {
    // Drift resolves the executor from Zone.current, so a batch must never
    // merge calls made inside a transaction zone with calls made outside it.
    // These tests pin that property directly, since violating it would swap
    // the executor a query runs on and silently break read-your-writes.

    test('loads from different zones do not share a batch', () async {
      final coalescer = build();

      final outer = coalescer.load('a');
      final inner = runZoned(() => coalescer.load('b'));

      await Future.wait([outer, inner]);

      expect(
        batches,
        hasLength(2),
        reason: 'each zone must get its own batch and its own round trip',
      );
      expect(batches.map((b) => b.single), containsAll(<String>['a', 'b']));
    });

    test('the flush runs in the zone that requested it', () async {
      final flushZones = <Object?>[];
      final coalescer = AgentEntityByIdCoalescer((ids) async {
        flushZones.add(Zone.current[#testZoneMarker]);
        return const <String, AgentDomainEntity>{};
      });

      await runZoned(
        () => coalescer.load('a'),
        zoneValues: {#testZoneMarker: 'transaction'},
      );

      expect(
        flushZones,
        ['transaction'],
        reason:
            'the batched query must execute in the requesting zone so drift '
            'resolves the transaction executor, not the root one',
      );
    });

    test('loads within one zone still coalesce', () async {
      final coalescer = build();

      await runZoned(
        () => Future.wait([coalescer.load('a'), coalescer.load('b')]),
      );

      expect(batches, hasLength(1));
      expect(batches.single, containsAll(<String>['a', 'b']));
    });
  });
}
