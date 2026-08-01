import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/database/agent_database.dart'
    hide AgentLink;
import 'package:lotti/features/agents/database/agent_repo_core.dart';
import 'package:lotti/features/agents/database/agent_repo_links.dart';
import 'package:lotti/features/agents/database/agent_repo_observation_retention.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
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
      retention.pruneThread(
        agentId: agentId,
        threadId: threadId,
        cutoff: cutoff,
        limit: limit,
        maxMessages: 1000,
      );

  group('pruneThread', () {
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

    test('skips a thread longer than the read bound', () async {
      await seedChain();

      final result = await retention.pruneThread(
        agentId: agentId,
        threadId: threadId,
        cutoff: cutoff,
        limit: 100,
        maxMessages: 2,
      );

      expect(
        result.isEmpty,
        isTrue,
        reason:
            'A truncated view would hide the parents that block a delete, so '
            'the thread is left for a sweep that can read all of it.',
      );
      expect(await messageIds(), ['a', 'b', 'c', 'tip']);
    });
  });

  group('threadsWithAgedObservations', () {
    test('finds only threads with an aged observation', () async {
      await seedMessage('a', oldest);
      await core.upsertEntity(
        makeTestMessage(
          id: 'young-obs',
          agentId: agentId,
          threadId: 'thread-young',
          kind: AgentMessageKind.observation,
          createdAt: young,
        ),
      );
      await core.upsertEntity(
        makeTestMessage(
          id: 'old-thought',
          agentId: agentId,
          threadId: 'thread-thought',
          createdAt: oldest,
        ),
      );

      final threads = await retention.threadsWithAgedObservations(
        cutoff,
        limit: 10,
      );

      expect(
        [for (final thread in threads) thread.threadId],
        [threadId],
        reason:
            'A young observation and an old non-observation are both ineligible.',
      );
    });

    test('respects the thread cap', () async {
      for (var i = 0; i < 5; i++) {
        await core.upsertEntity(
          makeTestMessage(
            id: 'obs-$i',
            agentId: agentId,
            threadId: 'thread-$i',
            kind: AgentMessageKind.observation,
            createdAt: oldest,
          ),
        );
      }

      expect(
        (await retention.threadsWithAgedObservations(cutoff, limit: 3)).length,
        3,
      );
    });
  });
}
