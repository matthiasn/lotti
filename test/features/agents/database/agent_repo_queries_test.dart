import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repo_core.dart';
import 'package:lotti/features/agents/database/agent_repo_links.dart';
import 'package:lotti/features/agents/database/agent_repo_queries.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/sync/vector_clock.dart';

import '../test_data/entity_factories.dart';
import '../test_data/link_factories.dart';
import '../test_data/template_factories.dart';

/// Mirror tests for [AgentRepoQueries]. They construct the collaborator wired
/// to real [AgentRepoCore] and [AgentRepoLinks] instances over an in-memory
/// [AgentDatabase], exercising the report/template/soul/message read paths and
/// their cross-collaborator hops (core hydration + link resolution).
void main() {
  late AgentDatabase db;
  late AgentRepoCore core;
  late AgentRepoLinks links;
  late AgentRepoQueries queries;

  final testDate = DateTime(2026, 3, 15);

  setUp(() {
    db = AgentDatabase(inMemoryDatabase: true, background: false);
    core = AgentRepoCore(db);
    links = AgentRepoLinks(db, null);
    queries = AgentRepoQueries(db, core, links);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedReportWithHead({
    required String agentId,
    required String reportId,
    String content = 'report body',
  }) async {
    await core.upsertEntity(
      makeTestReport(
        id: reportId,
        agentId: agentId,
        content: content,
        createdAt: testDate,
      ),
    );
    await core.upsertEntity(
      makeTestReportHead(
        id: 'head-$agentId',
        agentId: agentId,
        reportId: reportId,
        updatedAt: testDate,
      ),
    );
  }

  group('getLatestReport', () {
    test('resolves the report via the head pointer (core hop)', () async {
      await seedReportWithHead(agentId: 'agent-1', reportId: 'rpt-1');

      final report = await queries.getLatestReport(
        'agent-1',
        AgentReportScopes.current,
      );
      expect(report, isNotNull);
      expect(report!.id, 'rpt-1');
    });

    test('returns null when no head exists', () async {
      expect(
        await queries.getLatestReport('nobody', AgentReportScopes.current),
        isNull,
      );
    });
  });

  group('getLatestProjectReportForProjectId', () {
    test('follows the agent_project link to the report (links hop)', () async {
      await seedReportWithHead(agentId: 'proj-agent-1', reportId: 'rpt-proj');
      await links.upsertLink(
        makeTestAgentProjectLink(
          id: 'link-proj',
          fromId: 'proj-agent-1',
          toId: 'project-1',
          createdAt: testDate,
          updatedAt: testDate,
        ),
      );

      final report = await queries.getLatestProjectReportForProjectId(
        'project-1',
      );
      expect(report!.id, 'rpt-proj');
    });

    test('skips a linked agent whose report body is empty', () async {
      await seedReportWithHead(
        agentId: 'empty-agent',
        reportId: 'rpt-empty',
        content: '   ',
      );
      await links.upsertLink(
        makeTestAgentProjectLink(
          id: 'link-empty',
          fromId: 'empty-agent',
          toId: 'project-2',
          createdAt: testDate,
          updatedAt: testDate,
        ),
      );

      expect(
        await queries.getLatestProjectReportForProjectId('project-2'),
        isNull,
      );
    });
  });

  group('getLatestTaskReportsForTaskIds', () {
    test("maps each task to its agent's current report", () async {
      await seedReportWithHead(agentId: 'task-agent-1', reportId: 'rpt-task');
      await links.upsertLink(
        makeTestAgentTaskLink(
          id: 'link-task',
          fromId: 'task-agent-1',
          toId: 'task-1',
          createdAt: testDate,
          updatedAt: testDate,
        ),
      );

      final byTask = await queries.getLatestTaskReportsForTaskIds([
        'task-1',
        'task-unassigned',
      ]);
      expect(byTask.keys, ['task-1']);
      expect(byTask['task-1']!.id, 'rpt-task');
    });

    test('returns empty for an empty task list', () async {
      expect(await queries.getLatestTaskReportsForTaskIds(const []), isEmpty);
    });
  });

  group('template versions', () {
    test(
      'getActiveTemplateVersion resolves through the head (core hop)',
      () async {
        await core.upsertEntity(
          makeTestTemplateVersion(
            id: 'tpl-ver-1',
            agentId: 'tpl-1',
            createdAt: testDate,
          ),
        );
        await core.upsertEntity(
          makeTestTemplateHead(
            id: 'tpl-head-1',
            agentId: 'tpl-1',
            versionId: 'tpl-ver-1',
            updatedAt: testDate,
          ),
        );

        final version = await queries.getActiveTemplateVersion('tpl-1');
        expect(version!.id, 'tpl-ver-1');
      },
    );

    test(
      'getNextTemplateVersionNumber returns max + 1 over existing versions',
      () async {
        await core.upsertEntity(
          makeTestTemplateVersion(
            id: 'tv-1',
            agentId: 'tpl-2',
            createdAt: testDate,
          ),
        );
        await core.upsertEntity(
          makeTestTemplateVersion(
            id: 'tv-3',
            agentId: 'tpl-2',
            version: 3,
            createdAt: testDate,
          ),
        );

        expect(await queries.getNextTemplateVersionNumber('tpl-2'), 4);
      },
    );

    test(
      'getNextSoulDocumentVersionNumber starts at 1 with no versions',
      () async {
        expect(await queries.getNextSoulDocumentVersionNumber('soul-x'), 1);
      },
    );
  });

  group('updateWakeRunTemplate', () {
    test('throws StateError when the run key is unknown', () async {
      await expectLater(
        () => queries.updateWakeRunTemplate('missing', 'tpl', 'ver'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('getMessagesForThread', () {
    test('returns only messages in the requested thread', () async {
      await core.upsertEntity(
        makeTestMessage(
          id: 'm1',
          agentId: 'agent-1',
          threadId: 'thread-a',
          createdAt: testDate,
          vectorClock: const VectorClock({'node-1': 1}),
        ),
      );
      await core.upsertEntity(
        makeTestMessage(
          id: 'm2',
          agentId: 'agent-1',
          threadId: 'thread-b',
          createdAt: testDate,
          vectorClock: const VectorClock({'node-1': 2}),
        ),
      );

      final inThread = await queries.getMessagesForThread(
        'agent-1',
        'thread-a',
      );
      expect(inThread.map((m) => m.id), ['m1']);
    });
  });
}
