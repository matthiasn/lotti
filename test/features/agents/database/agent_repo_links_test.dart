import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repo_links.dart';
import 'package:lotti/features/agents/database/agent_repository_exception.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_link.dart' as model;
import 'package:lotti/features/sync/vector_clock.dart';

import '../test_data/link_factories.dart';
import '../test_data/wake_factories.dart';

/// Mirror tests for [AgentRepoLinks]. They construct the collaborator directly
/// against a real in-memory [AgentDatabase] and assert on the link CRUD,
/// wake-run log, saga log, and hard-delete behaviour it owns.
void main() {
  late AgentDatabase db;
  late AgentRepoLinks links;

  final testDate = DateTime(2026, 3, 15);

  setUp(() {
    db = AgentDatabase(inMemoryDatabase: true, background: false);
    links = AgentRepoLinks(db, null);
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

  group('insertLinkExclusive', () {
    test('throws DuplicateInsertException on a duplicate id', () async {
      final link = makeTestImproverTargetLink(
        id: 'imp-1',
        fromId: 'improver-1',
        toId: 'template-1',
        createdAt: testDate,
        updatedAt: testDate,
      );
      await links.insertLinkExclusive(link);

      await expectLater(
        () => links.insertLinkExclusive(link),
        throwsA(isA<DuplicateInsertException>()),
      );
    });
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
      final run = await links.getWakeRun('run-1');
      expect(run, isNotNull);
      expect(run!.status, 'completed');
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
      expect((await links.getWakeRun('orphan'))!.status, 'abandoned');
    });
  });

  group('saga log', () {
    test('insert then status update flows through getPendingSagaOps', () async {
      await links.insertSagaOp(
        entry: makeTestSagaOp(operationId: 'op-1', createdAt: testDate),
      );
      expect((await links.getPendingSagaOps()).map((s) => s.operationId), [
        'op-1',
      ]);

      await links.updateSagaStatus('op-1', 'completed');
      expect(await links.getPendingSagaOps(), isEmpty);
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
      expect(await links.getWakeRun('run-del'), isNull);
    });
  });
}
