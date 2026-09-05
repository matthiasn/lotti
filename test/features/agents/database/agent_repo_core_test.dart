import 'dart:convert';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/database/agent_attention_projection.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_db_conversions.dart';
import 'package:lotti/features/agents/database/agent_proposal_ledger.dart';
import 'package:lotti/features/agents/database/agent_repo_core.dart';
import 'package:lotti/features/agents/database/agent_repo_evolution.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/attention_negotiation.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

import '../test_data/entity_factories.dart';
import '../test_data/soul_factories.dart';

/// Mirror tests for [AgentRepoCore]. They construct the collaborator directly
/// against a real in-memory [AgentDatabase] (wired to a real
/// [AgentAttentionProjection], exactly as the facade does) and assert on the
/// entity-CRUD and shared batched-read behaviour it owns.
void main() {
  late AgentDatabase db;
  late AgentRepoCore core;

  final testDate = DateTime(2026, 3, 15);

  setUp(() {
    db = AgentDatabase(inMemoryDatabase: true, background: false);
    core = AgentRepoCore(db);
    // Wire the Core ↔ projection cycle the same way [AgentRepository] does so
    // upsertEntity has a live projection collaborator.
    core.projection = AgentAttentionProjection(db, core);
  });

  tearDown(() async {
    await db.close();
  });

  group('getEntity coalescing', () {
    // getEntity folds concurrent single-id reads into one batched
    // `id IN (…)` query (AgentEntityByIdCoalescer). These tests run against a
    // real database to pin the two properties that batching could break:
    // identical results, and read-your-writes inside a transaction — drift
    // resolves the executor from Zone.current, so a batch that escaped the
    // transaction zone would read pre-transaction state.

    test(
      'concurrent getEntity calls return the same rows as serial ones',
      () async {
        for (var i = 0; i < 5; i++) {
          await core.upsertEntity(
            makeTestIdentity(
              id: 'coalesce-$i',
              agentId: 'agent-$i',
              displayName: 'Agent $i',
              createdAt: testDate,
              updatedAt: testDate,
            ),
          );
        }

        final concurrent = await Future.wait([
          for (var i = 0; i < 5; i++) core.getEntity('coalesce-$i'),
          core.getEntity('coalesce-does-not-exist'),
        ]);

        expect(
          concurrent
              .take(5)
              .map((e) => (e! as AgentIdentityEntity).displayName),
          ['Agent 0', 'Agent 1', 'Agent 2', 'Agent 3', 'Agent 4'],
        );
        expect(
          concurrent.last,
          isNull,
          reason: 'absent id still resolves null',
        );
      },
    );

    test('sees its own write when read inside the same transaction', () async {
      await core.runInTransaction(() async {
        await core.upsertEntity(
          makeTestIdentity(
            id: 'txn-entity',
            agentId: 'txn-agent',
            displayName: 'Written in txn',
            createdAt: testDate,
            updatedAt: testDate,
          ),
        );

        final readBack = await core.getEntity('txn-entity');
        expect(
          readBack,
          isNotNull,
          reason:
              'the coalesced read must run on the transaction executor, '
              'not the root one, or it would not see the uncommitted write',
        );
        expect(
          (readBack! as AgentIdentityEntity).displayName,
          'Written in txn',
        );
      });

      expect(await core.getEntity('txn-entity'), isNotNull);
    });

    test(
      'concurrent reads inside a transaction see the uncommitted write',
      () async {
        await core.runInTransaction(() async {
          await core.upsertEntity(
            makeTestIdentity(
              id: 'txn-batch-a',
              agentId: 'txn-a',
              displayName: 'A',
              createdAt: testDate,
              updatedAt: testDate,
            ),
          );
          await core.upsertEntity(
            makeTestIdentity(
              id: 'txn-batch-b',
              agentId: 'txn-b',
              displayName: 'B',
              createdAt: testDate,
              updatedAt: testDate,
            ),
          );

          // Both loads join one batch; that batch must still run inside the
          // transaction.
          final both = await Future.wait([
            core.getEntity('txn-batch-a'),
            core.getEntity('txn-batch-b'),
          ]);

          expect(
            both.map((e) => (e! as AgentIdentityEntity).displayName),
            ['A', 'B'],
          );
        });
      },
    );

    test(
      'rolls back cleanly when the transaction fails after a read',
      () async {
        await expectLater(
          core.runInTransaction(() async {
            await core.upsertEntity(
              makeTestIdentity(
                id: 'txn-rollback',
                agentId: 'txn-rollback',
                displayName: 'Doomed',
                createdAt: testDate,
                updatedAt: testDate,
              ),
            );
            expect(await core.getEntity('txn-rollback'), isNotNull);
            throw StateError('abort');
          }),
          throwsA(isA<StateError>()),
        );

        expect(
          await core.getEntity('txn-rollback'),
          isNull,
          reason:
              'the aborted write must not survive, and the post-rollback '
              'read must not be served from a stale coalesced batch',
        );
      },
    );
  });

  group('getAgentStatesWithPendingWakes', () {
    // The pending-wakes screen used to load every agent's latest state and
    // discard the ones with no wake. The filter now runs in SQL. These tests
    // pin the two things that could go wrong: filtering must happen AFTER the
    // per-agent ranking, and agents whose wake lives in a separate
    // ScheduledWakeEntity row must still be hydrated.
    //
    // `created_at` for an AgentStateEntity is its `updatedAt`
    // (AgentDbConversions.entityCreatedAt), which is what the ranking orders by.

    Future<void> putState(
      String agentId,
      String stateId, {
      DateTime? nextWakeAt,
      DateTime? scheduledWakeAt,
      DateTime? at,
    }) async {
      await core.upsertEntity(
        makeTestState(
          id: stateId,
          agentId: agentId,
          nextWakeAt: nextWakeAt,
          scheduledWakeAt: scheduledWakeAt,
          updatedAt: at ?? testDate,
        ),
      );
    }

    test('returns only agents with a pending or scheduled wake', () async {
      await putState('a-wake', 'st-a', nextWakeAt: testDate);
      await putState('a-sched', 'st-b', scheduledWakeAt: testDate);
      await putState('a-idle', 'st-c');

      final states = await core.getAgentStatesWithPendingWakes([
        'a-wake',
        'a-sched',
        'a-idle',
      ]);

      expect(
        states.keys.toSet(),
        {'a-wake', 'a-sched'},
        reason: 'the idle agent must not be decoded or returned',
      );
    });

    test('a cleared wake on the newest state excludes the agent', () async {
      // The correctness trap: filtering inside the ranked subquery would
      // promote the older row that still has a wake, resurrecting it.
      await putState(
        'a-1',
        'st-1-old',
        nextWakeAt: testDate,
        at: DateTime(2026, 3, 14),
      );
      await putState('a-1', 'st-1-new', at: DateTime(2026, 3, 16));

      final states = await core.getAgentStatesWithPendingWakes(['a-1']);

      expect(
        states,
        isEmpty,
        reason: 'the newest state cleared the wake, so the agent is excluded',
      );
    });

    test('a newly-set wake on the newest state includes the agent', () async {
      await putState('a-2', 'st-2-old', at: DateTime(2026, 3, 14));
      await putState(
        'a-2',
        'st-2-new',
        nextWakeAt: testDate,
        at: DateTime(2026, 3, 16),
      );

      final states = await core.getAgentStatesWithPendingWakes(['a-2']);

      expect(states.keys, ['a-2']);
      expect(states['a-2']!.nextWakeAt, isNotNull);
    });

    test('alsoIncludeAgentIds hydrates agents with no wake field', () async {
      // ScheduledWakeEntity rows carry the wake instead of the state, so those
      // agents must survive the filter when named explicitly.
      await putState('a-wake', 'st-a', nextWakeAt: testDate);
      await putState('a-workspace', 'st-b');
      await putState('a-idle', 'st-c');

      final states = await core.getAgentStatesWithPendingWakes(
        ['a-wake', 'a-workspace', 'a-idle'],
        alsoIncludeAgentIds: ['a-workspace'],
      );

      expect(
        states.keys.toSet(),
        {'a-wake', 'a-workspace'},
        reason: 'named agent included, unnamed idle agent still filtered out',
      );
    });

    test('a large inclusion list does not overflow the bind budget', () async {
      // The inclusion list is read as its own chunked query rather than bound
      // into every primary chunk, so it cannot share — and overflow — the
      // statement's variable budget no matter how large it gets.
      await putState('a-wake', 'st-a', nextWakeAt: testDate);
      for (var i = 0; i < 1200; i++) {
        await putState('inc-$i', 'st-inc-$i');
      }

      final states = await core.getAgentStatesWithPendingWakes(
        ['a-wake', for (var i = 0; i < 1200; i++) 'inc-$i'],
        alsoIncludeAgentIds: [for (var i = 0; i < 1200; i++) 'inc-$i'],
      );

      expect(states.keys, hasLength(1201));
      expect(states.keys, contains('a-wake'));
      expect(states.keys, contains('inc-1199'));
    });

    test('spans multiple id chunks and still resolves inclusions', () async {
      // The agent-id list is chunked (900 per statement) while
      // alsoIncludeAgentIds is bound into every chunk. This exercises the
      // multi-chunk path end to end: results must be merged across chunks and
      // the inclusion list must apply in each one.
      await putState('a-wake', 'st-a', nextWakeAt: testDate);
      await putState('a-workspace', 'st-b');

      final manyIds = [for (var i = 0; i < 1500; i++) 'filler-$i'];

      final states = await core.getAgentStatesWithPendingWakes(
        ['a-wake', 'a-workspace', ...manyIds],
        alsoIncludeAgentIds: ['a-workspace'],
      );

      expect(
        states.keys.toSet(),
        {'a-wake', 'a-workspace'},
        reason: 'merged across chunks, inclusion honoured, fillers excluded',
      );
    });

    test('omitting alsoIncludeAgentIds leaves valid SQL', () async {
      // The `OR agent_id IN (...)` clause is appended only when ids are given;
      // the default path must not emit a dangling `IN ()`.
      await putState('a-wake', 'st-a', nextWakeAt: testDate);
      await putState('a-idle', 'st-b');

      final states = await core.getAgentStatesWithPendingWakes([
        'a-wake',
        'a-idle',
      ]);

      expect(states.keys, ['a-wake']);
    });
  });

  group('agent identity cache', () {
    // The cache and its invalidation live on AgentRepoCore, so the tests do
    // too; AgentRepoEvolution.getAllAgentIdentities is only the reader that
    // populates it, wired here exactly as AgentRepository wires it.
    late AgentRepoEvolution evolution;

    setUp(() {
      evolution = AgentRepoEvolution(db, core, AgentProposalLedger(db));
    });

    // The list is cached between identity writes. A cache is only as good as
    // its invalidation, so these tests exercise the write paths that must
    // drop it — including soft delete, which is an upsert with deletedAt set.
    //
    // Bypassing the repository (writing straight to the table) is how each
    // test proves the *cached* value is being served rather than a fresh read.

    Future<void> insertIdentityBypassingCache(String id) async {
      await db
          .into(db.agentEntities)
          .insertOnConflictUpdate(
            AgentDbConversions.toEntityCompanion(
              makeTestIdentity(id: id, agentId: id, displayName: id),
            ),
          );
    }

    test('serves a cached list on repeated reads', () async {
      await core.upsertEntity(
        makeTestIdentity(id: 'a-1', agentId: 'a-1', displayName: 'First'),
      );
      expect(await evolution.getAllAgentIdentities(), hasLength(1));

      await insertIdentityBypassingCache('a-2');

      expect(
        await evolution.getAllAgentIdentities(),
        hasLength(1),
        reason: 'the second read is served from cache, not the table',
      );
    });

    test('an identity write invalidates the cache', () async {
      await core.upsertEntity(
        makeTestIdentity(id: 'a-1', agentId: 'a-1', displayName: 'First'),
      );
      expect(await evolution.getAllAgentIdentities(), hasLength(1));

      await core.upsertEntity(
        makeTestIdentity(id: 'a-2', agentId: 'a-2', displayName: 'Second'),
      );

      expect(
        (await evolution.getAllAgentIdentities()).map((a) => a.agentId).toSet(),
        {'a-1', 'a-2'},
        reason: 'writing an identity must drop the cached list',
      );
    });

    test('an identity rename is visible after the write', () async {
      await core.upsertEntity(
        makeTestIdentity(id: 'a-1', agentId: 'a-1', displayName: 'Before'),
      );
      expect(
        (await evolution.getAllAgentIdentities()).single.displayName,
        'Before',
      );

      await core.upsertEntity(
        makeTestIdentity(id: 'a-1', agentId: 'a-1', displayName: 'After'),
      );

      expect(
        (await evolution.getAllAgentIdentities()).single.displayName,
        'After',
        reason: 'an in-place update must not serve the stale name',
      );
    });

    test('a soft delete invalidates the cache', () async {
      await core.upsertEntity(
        makeTestIdentity(id: 'a-1', agentId: 'a-1', displayName: 'Doomed'),
      );
      expect(await evolution.getAllAgentIdentities(), hasLength(1));

      await core.upsertEntity(
        makeTestIdentity(
          id: 'a-1',
          agentId: 'a-1',
          displayName: 'Doomed',
        ).copyWith(deletedAt: testDate),
      );

      expect(
        await evolution.getAllAgentIdentities(),
        isEmpty,
        reason: 'a soft-deleted identity must disappear from the cached list',
      );
    });

    test('a write during an in-flight load is not overwritten by it', () async {
      // The load captures a generation before querying and compares it after.
      // Without that, a write landing mid-flight is silently undone: the
      // pre-write list gets installed and served until the *next* write.
      await core.upsertEntity(
        makeTestIdentity(id: 'a-1', agentId: 'a-1', displayName: 'First'),
      );

      final inFlight = evolution.getAllAgentIdentities();
      // Lands while the query above is still awaiting.
      await core.upsertEntity(
        makeTestIdentity(id: 'a-2', agentId: 'a-2', displayName: 'Second'),
      );
      await inFlight;

      expect(
        (await evolution.getAllAgentIdentities()).map((a) => a.agentId).toSet(),
        {'a-1', 'a-2'},
        reason: 'the stale in-flight result must not have been cached',
      );
    });

    test('a transaction without an identity write keeps the cache', () async {
      // AgentSyncService routes every message and state write through
      // runInTransaction. Invalidating on any transaction would clear the cache
      // continuously during a wake — exactly when identities are read most —
      // so only a transaction that actually wrote an identity may invalidate.
      await core.upsertEntity(
        makeTestIdentity(id: 'a-1', agentId: 'a-1', displayName: 'First'),
      );
      expect(await evolution.getAllAgentIdentities(), hasLength(1));

      await insertIdentityBypassingCache('a-2');
      await core.runInTransaction(() async {
        await core.upsertEntity(makeTestState(id: 'st-1', agentId: 'a-1'));
      });

      expect(
        await evolution.getAllAgentIdentities(),
        hasLength(1),
        reason: 'a state-only transaction must not drop the cached list',
      );
    });

    test(
      'a transaction that writes an identity invalidates on commit',
      () async {
        await core.upsertEntity(
          makeTestIdentity(id: 'a-1', agentId: 'a-1', displayName: 'First'),
        );
        expect(await evolution.getAllAgentIdentities(), hasLength(1));

        await core.runInTransaction(() async {
          await core.upsertEntity(
            makeTestIdentity(id: 'a-2', agentId: 'a-2', displayName: 'Second'),
          );
        });

        expect(
          (await evolution.getAllAgentIdentities())
              .map((a) => a.agentId)
              .toSet(),
          {'a-1', 'a-2'},
        );
      },
    );

    test('a rolled-back transaction does not leave a cached row', () async {
      // A transaction can write an identity, read the list back, then roll
      // back. Caching that read would publish a row the database no longer has.
      await expectLater(
        core.runInTransaction(() async {
          await core.upsertEntity(
            makeTestIdentity(id: 'a-doomed', agentId: 'a-doomed'),
          );
          expect(await evolution.getAllAgentIdentities(), hasLength(1));
          throw StateError('abort');
        }),
        throwsA(isA<StateError>()),
      );

      expect(
        await evolution.getAllAgentIdentities(),
        isEmpty,
        reason: 'the transaction-local read must not have populated the cache',
      );
    });

    test('a non-identity write leaves the cache in place', () async {
      await core.upsertEntity(
        makeTestIdentity(id: 'a-1', agentId: 'a-1', displayName: 'First'),
      );
      expect(await evolution.getAllAgentIdentities(), hasLength(1));

      await insertIdentityBypassingCache('a-2');
      await core.upsertEntity(makeTestState(id: 'st-1', agentId: 'a-1'));

      expect(
        await evolution.getAllAgentIdentities(),
        hasLength(1),
        reason: 'only identity writes need to invalidate; states do not',
      );
    });
  });

  group('upsertEntity / getEntity', () {
    test('inserts then updates a non-projection entity in place', () async {
      final identity = makeTestIdentity(
        id: 'agent-entity-1',
        agentId: 'agent-1',
        displayName: 'Original',
        createdAt: testDate,
        updatedAt: testDate,
      );
      await core.upsertEntity(identity);

      final fetched = await core.getEntity('agent-entity-1');
      expect(fetched, isA<AgentIdentityEntity>());
      expect((fetched! as AgentIdentityEntity).displayName, 'Original');

      await core.upsertEntity(
        makeTestIdentity(
          id: 'agent-entity-1',
          agentId: 'agent-1',
          displayName: 'Renamed',
          createdAt: testDate,
          updatedAt: testDate,
        ),
      );

      final updated =
          await core.getEntity('agent-entity-1') as AgentIdentityEntity?;
      expect(updated!.displayName, 'Renamed');
    });

    test('getEntity returns null for an unknown id', () async {
      expect(await core.getEntity('missing'), isNull);
    });

    test(
      'capture parse completion survives a legacy whole-row rewrite',
      () async {
        final completedAt = DateTime(2026, 3, 15, 10);
        final capture =
            AgentDomainEntity.capture(
                  id: 'capture-1',
                  agentId: 'agent-1',
                  transcript: 'Original transcript',
                  capturedAt: testDate,
                  createdAt: testDate,
                  vectorClock: const VectorClock({'modern': 1}),
                  parseCompletedAt: completedAt,
                )
                as CaptureEntity;
        await core.upsertEntity(capture);

        await core.upsertEntity(
          capture.copyWith(
            transcript: 'Rewritten by a legacy peer',
            vectorClock: const VectorClock({'legacy': 2}),
            parseCompletedAt: null,
          ),
        );

        final persisted = await core.getEntity(capture.id) as CaptureEntity?;
        expect(persisted!.transcript, 'Rewritten by a legacy peer');
        expect(persisted.parseCompletedAt, completedAt);
        expect(persisted.vectorClock, const VectorClock({'legacy': 2}));
      },
    );

    test('capture day survives a legacy whole-row rewrite', () async {
      final capture =
          AgentDomainEntity.capture(
                id: 'capture-stable-day',
                agentId: 'agent-1',
                transcript: 'Original transcript',
                capturedAt: DateTime(2026, 3, 15, 0, 30),
                createdAt: testDate,
                vectorClock: const VectorClock({'modern': 1}),
                dayId: 'dayplan-2026-03-14',
              )
              as CaptureEntity;
      await core.upsertEntity(capture);

      await core.upsertEntity(
        capture.copyWith(
          transcript: 'Rewritten by a legacy peer after a timezone change',
          vectorClock: const VectorClock({'legacy': 2}),
          dayId: '',
        ),
      );

      final persisted = await core.getEntity(capture.id) as CaptureEntity?;
      expect(persisted!.dayId, 'dayplan-2026-03-14');
      final subtype = await db
          .customSelect(
            'SELECT subtype FROM agent_entities WHERE id = ?1',
            variables: [Variable.withString(capture.id)],
          )
          .getSingle();
      expect(
        subtype.readNullable<String>('subtype'),
        'dayplan-2026-03-14',
      );
    });

    test(
      'upsertEntity of an attention request populates the claim projection',
      () async {
        final claim =
            AgentDomainEntity.attentionRequest(
                  id: 'claim-1',
                  agentId: 'agent-1',
                  kind: AttentionRequestKind.task,
                  title: 'Focus block',
                  categoryId: 'work',
                  requestedMinutes: 30,
                  impact: 3,
                  urgency: 3,
                  energyFit: AttentionEnergyFit.neutral,
                  evidenceRefs: const [],
                  scopeKind: AttentionClaimScopeKind.dateRange,
                  rangeStart: DateTime(2026, 3, 15, 9),
                  rangeEnd: DateTime(2026, 3, 15, 12),
                  targetId: 'task-1',
                  targetKind: 'task',
                  createdAt: testDate,
                  vectorClock: const VectorClock({'node-1': 1}),
                )
                as AttentionRequestEntity;

        await core.upsertEntity(claim);

        // The projection row is the read path; if upsertEntity wired it,
        // the window query (which reads only the index) returns the claim.
        final claims = await core.projection.getAttentionClaimsForWindow(
          start: DateTime(2026, 3, 15, 8),
          end: DateTime(2026, 3, 15, 13),
        );
        expect(claims.map((c) => c.id), ['claim-1']);
      },
    );
  });

  group('getEntitiesByIds', () {
    test('returns matched entities keyed by id and omits the rest', () async {
      await core.upsertEntity(
        makeTestIdentity(id: 'e1', agentId: 'a1', createdAt: testDate),
      );
      await core.upsertEntity(
        makeTestIdentity(id: 'e2', agentId: 'a2', createdAt: testDate),
      );

      final result = await core.getEntitiesByIds(['e1', 'e2', 'missing']);
      expect(result.keys, containsAll(['e1', 'e2']));
      expect(result.containsKey('missing'), isFalse);
      expect(result['e1'], isA<AgentIdentityEntity>());
    });

    test('empty input returns an empty map without a query', () async {
      expect(await core.getEntitiesByIds(const []), isEmpty);
    });

    test(
      'tombstoned rows are hidden from getEntitiesByIds but returned by '
      'getEntitiesByIdsIncludingDeleted',
      () async {
        await core.upsertEntity(
          makeTestIdentity(id: 'live', agentId: 'a1', createdAt: testDate),
        );
        await core.upsertEntity(
          makeTestIdentity(
            id: 'gone',
            agentId: 'a2',
            createdAt: testDate,
          ).copyWith(deletedAt: testDate),
        );

        final filtered = await core.getEntitiesByIds(['live', 'gone']);
        expect(filtered.keys, ['live']);

        final all = await core.getEntitiesByIdsIncludingDeleted([
          'live',
          'gone',
        ]);
        expect(all.keys, containsAll(['live', 'gone']));
        expect(
          all['gone']!.deletedAt,
          testDate,
          reason:
              'The tombstone must be visible to callers whose write '
              'decision depends on it (week-rollup resurrection guard).',
        );
      },
    );
  });

  group('latestEntitiesByAgentIds', () {
    for (final subtype in [null, 'state']) {
      test(
        'uses indexed newer-row checks without a window with subtype $subtype',
        () async {
          await core.upsertEntity(
            makeTestState(
              id: 'winner',
              agentId: 'agent',
              updatedAt: testDate,
            ),
          );
          await db.customStatement(
            "UPDATE agent_entities SET subtype = 'state'",
          );
          final forwardingDb = MockAgentDatabase();
          when(() => forwardingDb.agentEntities).thenReturn(db.agentEntities);
          late String query;
          late List<Variable> variables;
          when(
            () => forwardingDb.customSelect(
              any(),
              variables: any(named: 'variables'),
              readsFrom: any(named: 'readsFrom'),
            ),
          ).thenAnswer((invocation) {
            query = invocation.positionalArguments.single as String;
            variables = invocation.namedArguments[#variables] as List<Variable>;
            return db.customSelect(
              query,
              variables: variables,
              readsFrom: {db.agentEntities},
            );
          });
          final rows = await AgentRepoCore(forwardingDb)
              .latestEntitiesByAgentIds(
                agentIds: ['agent', 'missing'],
                type: AgentEntityTypes.agentState,
                subtype: subtype,
              );
          expect(rows.single.id, 'winner');
          final plan = await db
              .customSelect('EXPLAIN QUERY PLAN $query', variables: variables)
              .get();
          final details = plan
              .map((row) => row.read<String>('detail'))
              .join('\n');
          // Execute and explain the actual repository statement, not a copied
          // query. Indexed searches alone are insufficient: the old window also
          // used this index but carried historical payloads through ranking.
          expect(details, contains('CORRELATED SCALAR SUBQUERY'));
          expect(
            details,
            contains(
              subtype == null
                  ? 'idx_agent_entities_active_agent_type_created_id'
                  : 'idx_agent_entities_active_agent_type_sub_created_id',
            ),
          );
          expect(details, isNot(contains('SCAN (subquery-')));
        },
      );
    }

    test(
      'preserves ties, tombstones, missing agents and outer filters',
      () async {
        for (final agentId in ['agent-b', 'agent-a']) {
          for (final (id, revision, date) in [
            ('old', 1, DateTime(2026, 3, 14)),
            ('tie-a', 2, testDate),
            ('tie-z', 3, testDate),
          ]) {
            await core.upsertEntity(
              makeTestState(
                id: '$agentId-$id',
                agentId: agentId,
                revision: revision,
                updatedAt: date,
              ),
            );
          }
        }
        await core.upsertEntity(
          makeTestState(
            id: 'deleted-newer',
            agentId: 'agent-a',
            updatedAt: DateTime(2026, 3, 16),
          ),
        );
        await db.customStatement(
          "UPDATE agent_entities SET deleted_at = 1 WHERE id = 'deleted-newer'",
        );
        final latest = await core.latestEntitiesByAgentIds(
          agentIds: ['agent-b', 'missing', 'agent-a', 'agent-a'],
          type: AgentEntityTypes.agentState,
        );
        expect(latest.map((entity) => entity.id), [
          'agent-a-tie-z',
          'agent-b-tie-z',
        ]);
        // The current winners do not satisfy the predicate. Older matching
        // states must not be promoted into the result.
        expect(
          await core.latestEntitiesByAgentIds(
            agentIds: ['agent-b', 'agent-a'],
            type: AgentEntityTypes.agentState,
            outerPredicate: r"AND json_extract(serialized, '$.revision') = 1",
          ),
          isEmpty,
        );
      },
    );

    test('latest reads observe transaction writes and rollback', () async {
      await core.upsertEntity(
        makeTestState(
          id: 'committed',
          agentId: 'agent',
          updatedAt: testDate,
        ),
      );
      await expectLater(
        core.runInTransaction(() async {
          await core.upsertEntity(
            makeTestState(
              id: 'uncommitted',
              agentId: 'agent',
              updatedAt: DateTime(2026, 3, 16),
            ),
          );
          final inside = await core.latestEntitiesByAgentIds(
            agentIds: ['agent'],
            type: AgentEntityTypes.agentState,
          );
          expect(inside.single.id, 'uncommitted');
          throw StateError('rollback');
        }),
        throwsStateError,
      );
      final outside = await core.latestEntitiesByAgentIds(
        agentIds: ['agent'],
        type: AgentEntityTypes.agentState,
      );
      expect(outside.single.id, 'committed');
    });

    test(
      'newer rows from other types or subtypes do not hide the winner',
      () async {
        await core.upsertEntity(
          makeTestState(
            id: 'wanted',
            agentId: 'agent',
            updatedAt: testDate,
          ),
        );
        await core.upsertEntity(
          makeTestState(
            id: 'other-subtype',
            agentId: 'agent',
            updatedAt: DateTime(2026, 3, 16),
          ),
        );
        await core.upsertEntity(
          makeTestIdentity(
            id: 'other-type',
            agentId: 'agent',
            createdAt: DateTime(2026, 3, 17),
          ),
        );
        await db.customStatement(
          "UPDATE agent_entities SET subtype = 'wanted' WHERE id = 'wanted'",
        );
        final filtered = await core.latestEntitiesByAgentIds(
          agentIds: ['agent'],
          type: AgentEntityTypes.agentState,
          subtype: 'wanted',
        );
        expect(filtered.single.id, 'wanted');
        final unfiltered = await core.latestEntitiesByAgentIds(
          agentIds: ['agent'],
          type: AgentEntityTypes.agentState,
        );
        expect(unfiltered.single.id, 'other-subtype');
      },
    );

    test('keeps only the newest row per agent', () async {
      // AgentStateEntity has no `createdAt`; the row's `created_at` column is
      // written from `updatedAt`, which is what the newest-row ordering uses.
      await core.upsertEntity(
        makeTestState(
          id: 'state-old',
          agentId: 'agent-1',
          updatedAt: DateTime(2026, 3, 14),
        ),
      );
      await core.upsertEntity(
        makeTestState(
          id: 'state-new',
          agentId: 'agent-1',
          revision: 2,
          updatedAt: DateTime(2026, 3, 16),
        ),
      );

      final latest = await core.latestEntitiesByAgentIds(
        agentIds: ['agent-1'],
        type: AgentEntityTypes.agentState,
      );
      expect(latest.map((e) => e.id), ['state-new']);
    });
  });

  group('getAgentStatesByAgentIds', () {
    test('maps each agent to its latest state, omitting stateless', () async {
      await core.upsertEntity(
        makeTestState(id: 's1', agentId: 'agent-1', updatedAt: testDate),
      );

      final states = await core.getAgentStatesByAgentIds([
        'agent-1',
        'agent-2',
      ]);
      expect(states.keys, ['agent-1']);
      expect(states['agent-1']!.id, 's1');
    });
  });

  group('getActiveSoulDocumentVersionsBySoulIds', () {
    test('resolves the active version via the head pointer', () async {
      await core.upsertEntity(
        makeTestSoulDocumentVersion(
          id: 'soul-ver-1',
          agentId: 'soul-1',
          createdAt: testDate,
        ),
      );
      await core.upsertEntity(
        makeTestSoulDocumentHead(
          id: 'soul-head-1',
          agentId: 'soul-1',
          versionId: 'soul-ver-1',
          updatedAt: testDate,
        ),
      );

      final versions = await core.getActiveSoulDocumentVersionsBySoulIds([
        'soul-1',
      ]);
      expect(versions['soul-1']!.id, 'soul-ver-1');
    });

    test('returns empty for souls without a head', () async {
      expect(
        await core.getActiveSoulDocumentVersionsBySoulIds(['none']),
        isEmpty,
      );
    });
  });

  group('getCaptureEventMetaForDay', () {
    test('returns only day-scoped metadata without content', () async {
      await core.upsertEntity(
        makeTestCapture(
          id: 'cap-1',
          agentId: 'agent-1',
          createdAt: testDate,
          capturedAt: DateTime(2026, 3, 15, 10),
        ),
      );
      await core.upsertEntity(
        makeTestCapture(
          id: 'cap-other-day',
          agentId: 'agent-1',
          createdAt: DateTime(2026, 3, 16),
          capturedAt: DateTime(2026, 3, 16, 10),
        ),
      );

      final metas = await core.getCaptureEventMetaForDay(
        agentId: 'agent-1',
        dayId: 'dayplan-2026-03-15',
      );
      expect(metas, hasLength(1));
      expect(metas.single.id, 'cap-1');
      expect(metas.single.dayId, 'dayplan-2026-03-15');
      expect(metas.single.capturedAt, DateTime(2026, 3, 15, 10));
    });
  });

  group('day-scoped subtype reads (ADR 0044 follow-up)', () {
    test('returns only the requested day and skips the rest', () async {
      for (final day in ['dayplan-2026-05-25', 'dayplan-2026-05-26']) {
        for (var i = 0; i < 2; i++) {
          await core.upsertEntity(
            AgentDomainEntity.capture(
              id: 'capture-$day-$i',
              agentId: 'daily_os_planner',
              transcript: 'note $i',
              capturedAt: DateTime(2026, 5, 25, 9),
              createdAt: DateTime(2026, 5, 25, 9),
              dayId: day,
              vectorClock: null,
            ),
          );
        }
      }

      final rows = await core.getEntitiesByAgentIdAndSubtype(
        'daily_os_planner',
        type: AgentEntityTypes.capture,
        subtype: 'dayplan-2026-05-25',
      );

      expect(
        rows.whereType<CaptureEntity>().map((c) => c.id),
        unorderedEquals([
          'capture-dayplan-2026-05-25-0',
          'capture-dayplan-2026-05-25-1',
        ]),
      );
    });

    test('finds a legacy capture by its derived day', () async {
      // No explicit dayId: the stored subtype is derived from capturedAt, so
      // a day-scoped read still finds it without a Dart-side fallback scan.
      await core.upsertEntity(
        AgentDomainEntity.capture(
          id: 'capture-legacy',
          agentId: 'daily_os_planner',
          transcript: 'from an old peer',
          capturedAt: DateTime(2026, 5, 25, 9),
          createdAt: DateTime(2026, 5, 25, 9),
          vectorClock: null,
        ),
      );

      final rows = await core.getEntitiesByAgentIdAndSubtype(
        'daily_os_planner',
        type: AgentEntityTypes.capture,
        subtype: 'dayplan-2026-05-25',
      );

      expect(rows.whereType<CaptureEntity>().single.id, 'capture-legacy');
    });
  });

  group('multi-subtype reads', () {
    Future<void> seedPlan(String dayId) => core.upsertEntity(
      makeTestDayPlan(
        id: 'day_agent_plan:$dayId',
        agentId: 'daily_os_planner',
        dayId: dayId,
        planDate: DateTime.parse(dayId.substring('dayplan-'.length)),
      ),
    );

    test(
      'returns every requested day and nothing outside the window',
      () async {
        for (final day in const [
          'dayplan-2026-05-23',
          'dayplan-2026-05-24',
          'dayplan-2026-05-25',
          'dayplan-2026-05-26',
        ]) {
          await seedPlan(day);
        }

        final rows = await core.getEntitiesByAgentIdAndSubtypes(
          'daily_os_planner',
          type: AgentEntityTypes.dayPlan,
          subtypes: const ['dayplan-2026-05-24', 'dayplan-2026-05-25'],
        );

        expect(
          rows.whereType<DayPlanEntity>().map((p) => p.dayId),
          unorderedEquals(['dayplan-2026-05-24', 'dayplan-2026-05-25']),
        );
      },
    );

    test('an empty subtype set matches nothing', () async {
      await seedPlan('dayplan-2026-05-25');

      final rows = await core.getEntitiesByAgentIdAndSubtypes(
        'daily_os_planner',
        type: AgentEntityTypes.dayPlan,
        subtypes: const <String>[],
      );

      expect(rows, isEmpty);
    });

    test('excludes soft-deleted rows', () async {
      await seedPlan('dayplan-2026-05-25');
      await core.upsertEntity(
        makeTestDayPlan(
          id: 'day_agent_plan:dayplan-2026-05-25',
          agentId: 'daily_os_planner',
          planDate: DateTime(2026, 5, 25),
        ).copyWith(deletedAt: DateTime(2026, 5, 25, 12)),
      );

      final rows = await core.getEntitiesByAgentIdAndSubtypes(
        'daily_os_planner',
        type: AgentEntityTypes.dayPlan,
        subtypes: const ['dayplan-2026-05-25'],
      );

      expect(rows, isEmpty);
    });
  });

  group('schema v17 day-subtype backfill', () {
    /// Writes a row straight to the table with a pre-v17 subtype, bypassing
    /// the conversion layer that would now derive the day.
    Future<void> insertStale({
      required String id,
      required String type,
      required String subtype,
      required String serialized,
    }) => db.customInsert(
      'INSERT INTO agent_entities '
      '(id, agent_id, type, subtype, created_at, updated_at, serialized) '
      'VALUES (?1, ?2, ?3, ?4, ?5, ?5, ?6)',
      variables: [
        Variable.withString(id),
        Variable.withString('daily_os_planner'),
        Variable.withString(type),
        Variable.withString(subtype),
        Variable.withDateTime(DateTime(2026, 5, 25, 9)),
        Variable.withString(serialized),
      ],
    );

    Future<String?> subtypeOf(String id) async {
      final rows = await db
          .customSelect(
            'SELECT subtype FROM agent_entities WHERE id = ?1',
            variables: [Variable.withString(id)],
          )
          .get();
      return rows.single.readNullable<String>('subtype');
    }

    test('rewrites a capture from its own id to its day', () async {
      final capture = AgentDomainEntity.capture(
        id: 'capture-1',
        agentId: 'daily_os_planner',
        transcript: 'note',
        capturedAt: DateTime(2026, 5, 25, 9),
        createdAt: DateTime(2026, 5, 25, 9),
        dayId: 'dayplan-2026-05-25',
        vectorClock: null,
      );
      await insertStale(
        id: 'capture-1',
        type: AgentEntityTypes.capture,
        subtype: 'capture-1',
        serialized: jsonEncode(capture.toJson()),
      );

      await db.backfillDayScopedSubtypes();

      expect(await subtypeOf('capture-1'), 'dayplan-2026-05-25');
      // And the point of the rewrite: the day-scoped read now finds it.
      final rows = await core.getEntitiesByAgentIdAndSubtype(
        'daily_os_planner',
        type: AgentEntityTypes.capture,
        subtype: 'dayplan-2026-05-25',
      );
      expect(rows.single.id, 'capture-1');
    });

    test('derives the day for a legacy capture with no dayId', () async {
      final capture = AgentDomainEntity.capture(
        id: 'capture-legacy',
        agentId: 'daily_os_planner',
        transcript: 'from an old peer',
        capturedAt: DateTime(2026, 5, 25, 9),
        createdAt: DateTime(2026, 5, 25, 9),
        vectorClock: null,
      );
      await insertStale(
        id: 'capture-legacy',
        type: AgentEntityTypes.capture,
        subtype: 'capture-legacy',
        serialized: jsonEncode(capture.toJson()),
      );

      await db.backfillDayScopedSubtypes();

      expect(await subtypeOf('capture-legacy'), 'dayplan-2026-05-25');
    });

    test('rewrites a status event from its status name to its day', () async {
      final event = makeTestDayStatusEvent(createdAt: DateTime(2026, 5, 25, 9));
      await insertStale(
        id: event.id,
        type: AgentEntityTypes.dayStatusEvent,
        subtype: 'attentionNeeded',
        serialized: jsonEncode(event.toJson()),
      );

      await db.backfillDayScopedSubtypes();

      expect(await subtypeOf(event.id), 'dayplan-2026-05-25');
    });

    test('skips an undecodable row instead of aborting the upgrade', () async {
      final capture = AgentDomainEntity.capture(
        id: 'capture-ok',
        agentId: 'daily_os_planner',
        transcript: 'note',
        capturedAt: DateTime(2026, 5, 25, 9),
        createdAt: DateTime(2026, 5, 25, 9),
        dayId: 'dayplan-2026-05-25',
        vectorClock: null,
      );
      await insertStale(
        id: 'capture-broken',
        type: AgentEntityTypes.capture,
        subtype: 'capture-broken',
        serialized: 'not json',
      );
      await insertStale(
        id: 'capture-ok',
        type: AgentEntityTypes.capture,
        subtype: 'capture-ok',
        serialized: jsonEncode(capture.toJson()),
      );

      await db.backfillDayScopedSubtypes();

      // One unreadable row must not cost every other row its index entry.
      expect(await subtypeOf('capture-ok'), 'dayplan-2026-05-25');
      expect(await subtypeOf('capture-broken'), 'capture-broken');
    });

    test('leaves types it does not own alone', () async {
      final plan = makeTestDayPlan(
        id: 'day_agent_plan:dayplan-2026-05-25',
        agentId: 'daily_os_planner',
      );
      await core.upsertEntity(plan);

      await db.backfillDayScopedSubtypes();

      expect(
        await subtypeOf(plan.id),
        'dayplan-2026-05-25',
        reason: 'dayPlan already stored the day and is not rewritten',
      );
    });
  });
}
