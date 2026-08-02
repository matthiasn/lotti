import 'package:drift/drift.dart' show UpdateKind, Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/database/agent_database.dart'
    hide AgentLink;
import 'package:lotti/features/agents/database/agent_repo_core.dart';
import 'package:lotti/features/agents/database/agent_repo_links.dart';
import 'package:lotti/features/agents/database/agent_repo_observation_retention.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/projection/agent_event_adapter.dart';
import 'package:lotti/features/agents/projection/agent_projection.dart';
import 'package:lotti/features/agents/projection/canonical_order.dart';

import '../test_data/constants.dart';
import '../test_data/entity_factories.dart';

/// Mirror tests for [AgentRepoObservationRetention]: a real in-memory
/// database, a real `messagePrev` chain, and assertions on the *projection*
/// the survivors produce — the head set and `viewComplete` are what pruning
/// must not disturb, and only a rebuilt projection can show that.
// ignore_for_file: avoid_redundant_argument_values

void main() {
  late AgentDatabase db;
  late AgentRepoCore core;
  late AgentRepoLinks links;
  late AgentRepoObservationRetention retention;

  const agentId = kTestAgentId;
  const threadId = 'thread-obs';
  final cutoff = DateTime(2026, 6);
  final oldest = DateTime(2026, 3);
  final older = DateTime(2026, 4);
  final old = DateTime(2026, 5);
  final young = DateTime(2026, 7);

  setUp(() {
    db = AgentDatabase(inMemoryDatabase: true, background: false);
    core = AgentRepoCore(db);
    links = AgentRepoLinks(db, null);
    retention = AgentRepoObservationRetention(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> setHead(String id) => core.upsertEntity(
    makeTestState(agentId: agentId).copyWith(recentHeadMessageId: id),
  );

  Future<void> seedMessage(
    String id,
    DateTime createdAt, {
    AgentMessageKind kind = AgentMessageKind.observation,
    String? parentId,
  }) async {
    await core.upsertEntity(
      makeTestMessage(
        id: id,
        agentId: agentId,
        threadId: threadId,
        kind: kind,
        createdAt: createdAt,
      ),
    );
    if (parentId != null) {
      await links.upsertLink(
        AgentLink.messagePrev(
          id: 'link-$id',
          fromId: id,
          toId: parentId,
          createdAt: createdAt,
          updatedAt: createdAt,
          vectorClock: null,
        ),
      );
    }
    // _appendMessage advances the head on every append, so the newest seeded
    // message is the live tip. Without a head the sweep refuses outright.
    await setHead(id);
  }

  /// Seeds `a <- b <- c <- tip`, the shape every guard is about.
  Future<void> seedChain() async {
    await seedMessage('a', oldest);
    await seedMessage('b', older, parentId: 'a');
    await seedMessage('c', old, parentId: 'b');
    await seedMessage('tip', young, parentId: 'c');
  }

  Future<List<String>> messageIds() async {
    final rows = await db
        .customSelect(
          'SELECT id FROM agent_entities WHERE type = ?1 '
          'AND deleted_at IS NULL ORDER BY created_at, id',
          variables: [const Variable<String>(AgentEntityTypes.agentMessage)],
        )
        .get();
    return [for (final row in rows) row.read<String>('id')];
  }

  /// Rebuilds the projection from what is actually left in the database.
  Future<AgentProjection> survivingProjection() async {
    final messages = await core.getAgentMessages(agentId);
    final linkRows = await links.getLinksFromMultiple(
      [for (final message in messages) message.id],
      type: AgentLinkTypes.messagePrev,
    );
    return project(
      canonicalOrder(
        agentEventsFromLog(messages, [
          for (final group in linkRows.values) ...group,
        ]),
      ),
    );
  }

  Future<ObservationSweepResult> sweep({int limit = 100}) =>
      retention.pruneAgent(
        agentId: agentId,
        cutoff: cutoff,
        limit: limit,
        maxMessages: 1000,
      );

  group('pruneAgent', () {
    test('removes the aged prefix and the edge into it', () async {
      await seedChain();

      final result = await sweep();

      expect(result.messageIds, ['a', 'b', 'c']);
      expect(await messageIds(), ['tip']);

      final projection = await survivingProjection();
      expect(projection.headIds, ['tip']);
      expect(
        projection.danglingParentIds,
        isEmpty,
        reason:
            'A surviving edge into a pruned parent would make viewComplete '
            'false forever, disabling fork healing.',
      );
    });

    test('deletes the link rows, not just the messages', () async {
      await seedChain();

      final result = await sweep();

      expect(result.linkIds, containsAll(['link-b', 'link-c', 'link-tip']));
      final remaining = await db
          .customSelect(
            'SELECT id FROM agent_links WHERE deleted_at IS NULL ORDER BY id',
          )
          .get();
      expect(
        [for (final row in remaining) row.read<String>('id')],
        isEmpty,
        reason:
            'Every edge either sat inside the pruned set or crossed into it.',
      );
    });

    test('stops at a summary instead of pruning past it', () async {
      await seedMessage('a', oldest);
      await seedMessage(
        'b',
        older,
        kind: AgentMessageKind.summary,
        parentId: 'a',
      );
      await seedMessage('c', old, parentId: 'b');
      await seedMessage('tip', young, parentId: 'c');

      final result = await sweep();

      expect(result.messageIds, ['a']);
      expect(await messageIds(), ['b', 'c', 'tip']);
      final projection = await survivingProjection();
      expect(
        projection.headIds,
        ['tip'],
        reason: 'Pruning `c` would have stranded the summary as a head.',
      );
      expect(projection.danglingParentIds, isEmpty);
    });

    test('keeps the message agent state points at', () async {
      await seedChain();
      await core.upsertEntity(
        makeTestState(agentId: agentId).copyWith(recentHeadMessageId: 'c'),
      );

      final result = await sweep();

      expect(result.messageIds, ['a', 'b']);
      expect(
        await messageIds(),
        ['c', 'tip'],
        reason:
            'recentHeadMessageId must never point at a row retention deleted.',
      );
    });

    test('prunes nothing when everything is young', () async {
      await seedMessage('a', young);
      await seedMessage('b', young, parentId: 'a');

      expect((await sweep()).isEmpty, isTrue);
      expect(await messageIds(), ['a', 'b']);
    });

    test('a truncated sweep still leaves a sound DAG', () async {
      await seedChain();

      final result = await sweep(limit: 2);

      expect(result.messageIds, ['a', 'b']);
      final projection = await survivingProjection();
      expect(projection.headIds, ['tip']);
      expect(
        projection.danglingParentIds,
        isEmpty,
        reason: 'The boundary edge must go on a partial sweep too.',
      );
    });

    test('skips an agent whose log exceeds the read bound', () async {
      await seedChain();

      final result = await retention.pruneAgent(
        agentId: agentId,
        cutoff: cutoff,
        limit: 100,
        maxMessages: 2,
      );

      expect(
        result.isEmpty,
        isTrue,
        reason:
            'A truncated view would hide the parents that block a delete, so '
            'the agent is left for a sweep that can read all of it.',
      );
      expect(await messageIds(), ['a', 'b', 'c', 'tip']);
    });
  });

  group('repeated sweeps', () {
    /// Seeds the way production appends: **both** the `messagePrev` link and
    /// `prevMessageId` on every message. Fixtures that set only the link hid
    /// the stall this group exists to pin.
    Future<void> seedAsProduction(
      String id,
      DateTime at, {
      String? parent,
      AgentMessageKind kind = AgentMessageKind.observation,
    }) async {
      await core.upsertEntity(
        makeTestMessage(
          id: id,
          agentId: agentId,
          threadId: threadId,
          createdAt: at,
          kind: kind,
          prevMessageId: parent,
        ),
      );
      if (parent != null) {
        await links.upsertLink(
          AgentLink.messagePrev(
            id: 'link-$id',
            fromId: id,
            toId: parent,
            createdAt: at,
            updatedAt: at,
            vectorClock: null,
          ),
        );
      }
      await setHead(id);
    }

    test('successive sweeps keep making progress', () async {
      await seedAsProduction('a', oldest);
      await seedAsProduction('b', older, parent: 'a');
      await seedAsProduction('c', old, parent: 'b');
      await seedAsProduction('tip', young, parent: 'c');

      // One at a time, so a stall shows up as an empty second result rather
      // than being masked by a single generous batch.
      final first = await sweep(limit: 1);
      final second = await sweep(limit: 1);
      final third = await sweep(limit: 1);

      expect(first.messageIds, ['a']);
      expect(
        second.messageIds,
        ['b'],
        reason:
            'The oldest survivor keeps prevMessageId naming the row just '
            'deleted; treating that as an in-flight parent stalls the sweep '
            'permanently after its first pass.',
      );
      expect(third.messageIds, ['c']);
      expect(await messageIds(), ['tip']);

      final projection = await survivingProjection();
      expect(projection.headIds, ['tip']);
      expect(projection.danglingParentIds, isEmpty);
    });

    test(
      'an in-flight parent still blocks, link present but node absent',
      () async {
        // The link synced ahead of its node — the case the absent-parent rule
        // exists for, and the one a blanket "ignore missing parents" would break.
        await seedAsProduction('b', older);
        await links.upsertLink(
          AgentLink.messagePrev(
            id: 'link-b-inflight',
            fromId: 'b',
            toId: 'not-yet-synced',
            createdAt: older,
            updatedAt: older,
            vectorClock: null,
          ),
        );
        await seedAsProduction('tip', young, parent: 'b');

        expect((await sweep()).isEmpty, isTrue);
      },
    );
  });

  group('critical observations', () {
    Future<void> seedObservationWithPriority(
      String id,
      DateTime at,
      String priority, {
      String? parentId,
    }) async {
      final payloadId = 'payload-$id';
      await core.upsertEntity(
        AgentDomainEntity.agentMessagePayload(
          id: payloadId,
          agentId: agentId,
          createdAt: at,
          vectorClock: null,
          content: <String, Object?>{
            'text': 'note',
            'priority': priority,
            'category': 'grievance',
          },
        ),
      );
      await core.upsertEntity(
        makeTestMessage(
          id: id,
          agentId: agentId,
          threadId: threadId,
          kind: AgentMessageKind.observation,
          createdAt: at,
          contentEntryId: payloadId,
        ),
      );
      if (parentId != null) {
        await links.upsertLink(
          AgentLink.messagePrev(
            id: 'link-$id',
            fromId: id,
            toId: parentId,
            createdAt: at,
            updatedAt: at,
            vectorClock: null,
          ),
        );
      }
      await setHead(id);
    }

    test('a critical note is never pruned, however old', () async {
      // ObservationPriority.critical is a user grievance or excellence note
      // that must be reviewed at the next one-on-one. Six months without one
      // is exactly when it matters, and is exactly when the horizon lapses.
      await seedObservationWithPriority('critical-1', oldest, 'critical');
      await seedMessage('tip', young, parentId: 'critical-1');

      expect((await sweep()).isEmpty, isTrue);
      expect(await messageIds(), ['critical-1', 'tip']);
    });

    test('a routine note next to it is still collected', () async {
      await seedObservationWithPriority('routine-1', oldest, 'routine');
      await seedMessage('tip', young, parentId: 'routine-1');

      expect((await sweep()).messageIds, ['routine-1']);
    });

    test('a critical note blocks what follows it, like a summary', () async {
      await seedObservationWithPriority('critical-1', oldest, 'critical');
      await seedMessage('after', older, parentId: 'critical-1');
      await seedMessage('tip', young, parentId: 'after');

      expect(
        (await sweep()).isEmpty,
        isTrue,
        reason: 'Pruning `after` would strand the critical note as a head.',
      );
    });
  });

  group('partial sync', () {
    test('refuses to prune while there is no live head', () async {
      await seedMessage('a', oldest);
      await seedMessage('b', older, parentId: 'a');
      // Sync delivered the chain but not the state row. Pruning now could
      // take the whole chain including its tip, and a later state update
      // would install recentHeadMessageId for a row that no longer exists —
      // a dangling head _appendMessage would then chain off.
      await db.customUpdate(
        'DELETE FROM agent_entities WHERE type = ?1',
        variables: [const Variable<String>(AgentEntityTypes.agentState)],
        updateKind: UpdateKind.delete,
      );

      expect((await sweep()).isEmpty, isTrue);
      expect(await messageIds(), ['a', 'b']);
    });

    test('refuses when the head names a row that has not arrived', () async {
      // protectedIds is non-empty, so the no-head guard passes — but nothing
      // in the loaded set is actually protected, and pruning the chain now
      // would strand the head that is still in flight.
      await seedMessage('a', oldest);
      await seedMessage('b', older, parentId: 'a');
      await core.upsertEntity(
        makeTestState(agentId: agentId).copyWith(
          recentHeadMessageId: 'not-yet-synced',
        ),
      );

      expect((await sweep()).isEmpty, isTrue);
      expect(await messageIds(), ['a', 'b']);
    });

    test('honours prevMessageId when the link has not arrived', () async {
      // The entity carries its parent as well as the separately-synced link.
      // Trusting only the link reads `b` as a root and prunes it, forking the
      // moment the link lands.
      await core.upsertEntity(
        makeTestMessage(
          id: 'summary-a',
          agentId: agentId,
          threadId: threadId,
          kind: AgentMessageKind.summary,
          createdAt: oldest,
        ),
      );
      await core.upsertEntity(
        makeTestMessage(
          id: 'b',
          agentId: agentId,
          threadId: threadId,
          kind: AgentMessageKind.observation,
          createdAt: older,
          // The link row has not synced yet; only the entity knows its parent.
          prevMessageId: 'summary-a',
        ),
      );
      // A separate live tip, so `b` is not protected as the head and its
      // prunability turns purely on whether the parent is seen.
      await seedMessage('tip', young, parentId: 'b');

      expect(
        (await sweep()).isEmpty,
        isTrue,
        reason: 'Pruning `b` would strand the summary as a head.',
      );
      expect(await messageIds(), ['summary-a', 'b', 'tip']);
    });
  });

  group('the chain crosses threads', () {
    Future<void> seedInThread(
      String id,
      DateTime at,
      String thread, {
      String? parentId,
      AgentMessageKind kind = AgentMessageKind.observation,
    }) async {
      await core.upsertEntity(
        makeTestMessage(
          id: id,
          agentId: agentId,
          threadId: thread,
          kind: kind,
          createdAt: at,
        ),
      );
      if (parentId != null) {
        await links.upsertLink(
          AgentLink.messagePrev(
            id: 'link-$id',
            fromId: id,
            toId: parentId,
            createdAt: at,
            updatedAt: at,
            vectorClock: null,
          ),
        );
      }
      await setHead(id);
    }

    test('prunes across the wake boundary, not just within a thread', () async {
      // recentHeadMessageId is per AGENT and each wake's first message chains
      // off the previous wake's tip, so one chain spans thread ids. Planning
      // per thread sees `b`'s parent as absent and — under the rule that an
      // absent parent blocks — refuses to prune it, so retention would stall
      // at the first wake boundary and collect almost nothing.
      await seedInThread('a', oldest, 'wake-1');
      await seedInThread('b', older, 'wake-2', parentId: 'a');
      await seedInThread('tip', young, 'wake-3', parentId: 'b');

      final result = await sweep();

      expect(result.messageIds, ['a', 'b']);
      final projection = await survivingProjection();
      expect(projection.headIds, ['tip']);
      expect(projection.danglingParentIds, isEmpty);
    });

    test('a cross-thread summary still blocks its descendants', () async {
      await seedInThread('a', oldest, 'wake-1');
      await seedInThread(
        'sum',
        older,
        'wake-1',
        parentId: 'a',
        kind: AgentMessageKind.summary,
      );
      await seedInThread('c', old, 'wake-2', parentId: 'sum');

      final result = await sweep();

      expect(
        result.messageIds,
        ['a'],
        reason: 'Pruning `c` would strand the summary as a second head.',
      );
      final projection = await survivingProjection();
      expect(projection.headIds, ['c']);
      expect(projection.danglingParentIds, isEmpty);
    });
  });

  group('agentsWithAgedObservations', () {
    test('finds only agents with an aged observation', () async {
      await seedMessage('a', oldest);
      await core.upsertEntity(
        makeTestMessage(
          id: 'young-obs',
          agentId: 'agent-young',
          threadId: 'thread-young',
          kind: AgentMessageKind.observation,
          createdAt: young,
        ),
      );
      await core.upsertEntity(
        makeTestMessage(
          id: 'old-thought',
          agentId: 'agent-thought',
          threadId: 'thread-thought',
          createdAt: oldest,
        ),
      );

      expect(
        await retention.agentsWithAgedObservations(cutoff, limit: 10),
        [agentId],
        reason:
            'A young observation and an old non-observation are both '
            'ineligible.',
      );
    });

    test('resumes after the cursor rather than repeating the prefix', () async {
      for (final id in ['agent-a', 'agent-b', 'agent-c']) {
        await core.upsertEntity(
          makeTestMessage(
            id: 'obs-$id',
            agentId: id,
            threadId: 'thread-1',
            kind: AgentMessageKind.observation,
            createdAt: oldest,
          ),
        );
      }

      final first = await retention.agentsWithAgedObservations(
        cutoff,
        limit: 2,
      );
      expect(first, ['agent-a', 'agent-b']);

      // Without the cursor this returns the same prefix every start, so an
      // agent that cannot be pruned hides everything behind it forever.
      expect(
        await retention.agentsWithAgedObservations(
          cutoff,
          limit: 2,
          afterAgentId: first.last,
        ),
        ['agent-c'],
      );
    });
  });
}
