import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repo_core.dart';
import 'package:lotti/features/agents/database/agent_repo_links.dart';
import 'package:lotti/features/agents/database/agent_repository_exception.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_link.dart' as model;
import 'package:lotti/features/sync/vector_clock.dart';

import '../test_data/entity_factories.dart';
import '../test_data/link_factories.dart';
import '../test_data/wake_factories.dart';

/// Mirror tests for [AgentRepoLinks]. They construct the collaborator directly
/// against a real in-memory [AgentDatabase] and assert on the link CRUD,
/// wake-run log, saga log, and hard-delete behaviour it owns.
void main() {
  late AgentDatabase db;
  late AgentRepoLinks links;
  late AgentRepoCore core;

  final testDate = DateTime(2026, 3, 15);

  setUp(() {
    db = AgentDatabase(inMemoryDatabase: true, background: false);
    links = AgentRepoLinks(db, null);
    core = AgentRepoCore(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('upsertLink / getLinksTo / getLinksFrom', () {
    test('inserts a link and reads it back by both directions', () async {
      final link = makeTestBasicLink(
        id: 'l1',
        fromId: 'from-1',
        toId: 'to-1',
        createdAt: testDate,
        updatedAt: testDate,
      );
      await links.upsertLink(link);

      final to = await links.getLinksTo('to-1');
      final from = await links.getLinksFrom('from-1');
      expect(to.map((l) => l.id), ['l1']);
      expect(from.map((l) => l.id), ['l1']);
    });

    test('typed direction reads use active partial indexes', () async {
      await links.upsertLink(
        makeTestAgentTaskLink(
          id: 'lt-index',
          fromId: 'agent-index',
          toId: 'task-index',
          createdAt: testDate,
          updatedAt: testDate,
        ),
      );

      final from = await links.getLinksFrom(
        'agent-index',
        type: AgentLinkTypes.agentTask,
      );
      final to = await links.getLinksTo(
        'task-index',
        type: AgentLinkTypes.agentTask,
      );
      expect(from.map((link) => link.id), ['lt-index']);
      expect(to.map((link) => link.id), ['lt-index']);

      final fromPlan = await db
          .customSelect(
            '''
              EXPLAIN QUERY PLAN
              SELECT * FROM agent_links
                INDEXED BY idx_agent_links_active_from_type_to
              WHERE from_id = ? AND type = ? AND deleted_at IS NULL
            ''',
            variables: [
              Variable.withString('agent-index'),
              Variable.withString(AgentLinkTypes.agentTask),
            ],
            readsFrom: {db.agentLinks},
          )
          .get();
      final fromDetails = fromPlan
          .map((row) => row.read<String>('detail'))
          .join('\n');
      expect(fromDetails, contains('idx_agent_links_active_from_type_to'));

      final toPlan = await db
          .customSelect(
            '''
              EXPLAIN QUERY PLAN
              SELECT * FROM agent_links
                INDEXED BY idx_agent_links_active_to_type
              WHERE to_id = ? AND type = ? AND deleted_at IS NULL
            ''',
            variables: [
              Variable.withString('task-index'),
              Variable.withString(AgentLinkTypes.agentTask),
            ],
            readsFrom: {db.agentLinks},
          )
          .get();
      final toDetails = toPlan
          .map((row) => row.read<String>('detail'))
          .join('\n');
      expect(toDetails, contains('idx_agent_links_active_to_type'));
    });

    test(
      'getLinksToMultiple buckets links by toId for the requested type',
      () async {
        await links.upsertLink(
          makeTestAgentTaskLink(
            id: 'lt1',
            fromId: 'agent-1',
            toId: 'task-1',
            createdAt: testDate,
            updatedAt: testDate,
          ),
        );
        await links.upsertLink(
          makeTestAgentTaskLink(
            id: 'lt2',
            fromId: 'agent-2',
            toId: 'task-2',
            createdAt: testDate,
            updatedAt: testDate,
          ),
        );

        final byTask = await links.getLinksToMultiple(
          ['task-1', 'task-2', 'task-3'],
          type: AgentLinkTypes.agentTask,
        );
        expect(byTask.keys, containsAll(['task-1', 'task-2']));
        expect(byTask['task-1']!.single.fromId, 'agent-1');
        expect(byTask.containsKey('task-3'), isFalse);
      },
    );
  });

  group('wake run log', () {
    test('insert then status update is observable via getWakeRun', () async {
      await links.insertWakeRun(
        entry: makeTestWakeRun(
          runKey: 'run-1',
          agentId: 'agent-1',
          status: 'running',
          createdAt: testDate,
        ),
      );

      await links.updateWakeRunStatus('run-1', 'completed');
      expect((await getWakeRun(db, 'run-1'))?.status, 'completed');
    });

    test('insertWakeRun throws on a duplicate run key', () async {
      final entry = makeTestWakeRun(
        runKey: 'dup-run',
        agentId: 'agent-1',
        createdAt: testDate,
      );
      await links.insertWakeRun(entry: entry);
      await expectLater(
        () => links.insertWakeRun(entry: entry),
        throwsA(isA<DuplicateInsertException>()),
      );
    });

    test('abandonOrphanedWakeRuns flips running rows to abandoned', () async {
      await links.insertWakeRun(
        entry: makeTestWakeRun(
          runKey: 'orphan',
          agentId: 'agent-1',
          status: 'running',
          createdAt: testDate,
        ),
      );

      final count = await links.abandonOrphanedWakeRuns();
      expect(count, 1);
      expect((await getWakeRun(db, 'orphan'))?.status, 'abandoned');
    });
  });

  group('hardDeleteAgent', () {
    test("removes the agent's links and wake runs", () async {
      await links.upsertLink(
        model.AgentLink.agentTask(
          id: 'l-del',
          fromId: 'agent-del',
          toId: 'task-x',
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: const VectorClock({'node-1': 1}),
        ),
      );
      await links.insertWakeRun(
        entry: makeTestWakeRun(
          runKey: 'run-del',
          agentId: 'agent-del',
          createdAt: testDate,
        ),
      );

      await links.hardDeleteAgent('agent-del');

      expect(await links.getLinksFrom('agent-del'), isEmpty);
      expect(await getWakeRun(db, 'run-del'), isNull);
    });

    test('reports links between two of the agent-owned entities', () async {
      // messagePrev joins two messages, so neither endpoint is the agent id.
      // deleteAgentLinks removes those rows via the agent_entities subquery,
      // so the reported ids must cover them too — otherwise the rows go and
      // their sidecars are left on disk forever, unreferenced and unreachable.
      for (final id in ['m-1', 'm-2']) {
        await core.upsertEntity(
          makeTestMessage(id: id, agentId: 'agent-del', createdAt: testDate),
        );
      }
      await links.upsertLink(
        model.AgentLink.messagePrev(
          id: 'l-prev',
          fromId: 'm-2',
          toId: 'm-1',
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: const VectorClock({'node-1': 1}),
        ),
      );

      final removed = await links.hardDeleteAgent('agent-del');

      expect(removed.linkIds, contains('l-prev'));
      expect(
        await links.getLinksFrom('m-2'),
        isEmpty,
        reason:
            'The row is deleted either way; the question is whether the '
            'caller is told, so it can reclaim the sidecar.',
      );
    });
  });
}
