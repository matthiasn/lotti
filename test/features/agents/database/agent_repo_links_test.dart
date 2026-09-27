import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_db_conversions.dart';
import 'package:lotti/features/agents/database/agent_repo_core.dart';
import 'package:lotti/features/agents/database/agent_repo_links.dart';
import 'package:lotti/features/agents/database/agent_repository_exception.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_link.dart' as model;
import 'package:lotti/features/agents/model/agent_link.dart'
    show AgentLinkSoftDelete;
import 'package:lotti/features/agents/model/agent_link_slot.dart';
import 'package:lotti/features/sync/vector_clock.dart';

import '../test_data/entity_factories.dart';
import '../test_data/link_factories.dart';
import '../test_data/soul_factories.dart';
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

  group('getLinksTouchingIncludingDeleted', () {
    test(
      'returns links of the type from or to the ids, tombstones included',
      () async {
        final removed = makeTestSoulAssignmentLink(
          id: 'soul-removed',
          fromId: 'template-1',
          toId: 'soul-old',
        ).copyWith(deletedAt: testDate);
        for (final link in <model.AgentLink>[
          makeTestSoulAssignmentLink(
            id: 'soul-live',
            fromId: 'template-1',
            toId: 'soul-new',
          ),
          removed,
          makeTestSoulAssignmentLink(
            id: 'soul-other-template',
            fromId: 'template-2',
            toId: 'soul-new',
          ),
          makeTestTemplateAssignmentLink(
            id: 'template-assignment',
            fromId: 'template-1',
            toId: 'agent-1',
          ),
        ]) {
          await links.upsertLink(link);
        }

        final found = await links.getLinksTouchingIncludingDeleted({
          'template-1',
        }, type: AgentLinkTypes.soulAssignment);
        expect(
          found.map((l) => l.id),
          unorderedEquals(['soul-live', 'soul-removed']),
        );
        expect(
          found.singleWhere((l) => l.id == 'soul-removed').deletedAt,
          testDate,
        );

        // Either end matches.
        expect(
          (await links.getLinksTouchingIncludingDeleted({
            'soul-new',
          }, type: AgentLinkTypes.soulAssignment)).map((l) => l.id),
          unorderedEquals(['soul-live', 'soul-other-template']),
        );
        expect(
          await links.getLinksTouchingIncludingDeleted(
            const <String>{},
            type: AgentLinkTypes.soulAssignment,
          ),
          isEmpty,
        );
      },
    );
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

  group('upsertLink: a seeded soul assignment yields (ADR 0100)', () {
    final seedId = seededSoulAssignmentLinkId('template-1');
    model.AgentLink seed() => makeTestSoulAssignmentLink(
      id: seedId,
      fromId: 'template-1',
      toId: 'soul-default',
      createdAt: agentSeedInstant,
      updatedAt: agentSeedInstant,
    );

    test('is not stored where the template has a removed assignment', () async {
      final legacy = makeTestSoulAssignmentLink(
        id: 'legacy',
        fromId: 'template-1',
        toId: 'soul-default',
        createdAt: testDate,
        updatedAt: testDate,
      );
      await links.upsertLink(legacy);
      await links.upsertLink(legacy.softDeleted(testDate));

      await links.upsertLink(seed());

      expect(
        await links.getLinksFrom(
          'template-1',
          type: AgentLinkTypes.soulAssignment,
        ),
        isEmpty,
      );
    });

    test(
      'is retired at the seed instant by any other assignment row',
      () async {
        await links.upsertLink(seed());
        expect(
          (await links.getLinksFrom('template-1')).map((l) => l.id),
          [seedId],
        );

        // A removal made under another id — an older build's — retires it.
        await links.upsertLink(
          makeTestSoulAssignmentLink(
            id: 'legacy',
            fromId: 'template-1',
            toId: 'soul-other',
            createdAt: testDate,
            updatedAt: testDate,
          ).softDeleted(testDate),
        );

        final stored = AgentDbConversions.fromLinkRow(
          await (db.select(
            db.agentLinks,
          )..where((t) => t.id.equals(seedId))).getSingle(),
        );
        expect(stored.deletedAt, agentSeedInstant);
        expect(stored.updatedAt, agentSeedInstant);
      },
    );
  });

  test(
    "a seed retired by the user's assignment stays retired when the slot "
    'ranking loses that assignment (ADR 0099 with ADR 0100)',
    () async {
      final seedId = seededSoulAssignmentLinkId('template-1');
      await links.upsertLink(
        makeTestSoulAssignmentLink(
          id: seedId,
          fromId: 'template-1',
          toId: 'soul-default',
          createdAt: agentSeedInstant,
          updatedAt: agentSeedInstant,
        ),
      );
      final mine = makeTestSoulAssignmentLink(
        id: 'mine',
        fromId: 'template-1',
        toId: 'soul-mine',
        createdAt: testDate,
        updatedAt: testDate,
      );
      await links.upsertLink(mine);
      expect(
        (await links.getLinksFrom(
          'template-1',
          type: AgentLinkTypes.soulAssignment,
        )).map((l) => l.toId),
        ['soul-mine'],
      );

      // With nothing live left in the slot, the ranking must not surface the
      // default soul the user replaced.
      await links.upsertLink(mine.softDeleted(testDate));

      expect(
        await links.getLinksFrom(
          'template-1',
          type: AgentLinkTypes.soulAssignment,
        ),
        isEmpty,
      );
      final slot = await links.getSlotLinks(
        const AgentLinkSlot.soul('template-1'),
      );
      expect(
        slot.singleWhere((l) => l.id == seedId).deletedAt,
        agentSeedInstant,
      );
    },
  );

  group('hasAnyLinkFrom', () {
    test(
      'counts a removed link, and only links of the type from the id',
      () async {
        expect(
          await links.hasAnyLinkFrom(
            'template-1',
            type: AgentLinkTypes.soulAssignment,
          ),
          isFalse,
        );

        final assignment = makeTestSoulAssignmentLink(
          id: 'sa-1',
          fromId: 'template-1',
          toId: 'soul-1',
          createdAt: testDate,
          updatedAt: testDate,
        );
        await links.upsertLink(assignment);
        await links.upsertLink(assignment.softDeleted(testDate));
        // A link of another type from the same id, and one of the same type
        // from another id, are not the template's soul assignment.
        await links.upsertLink(
          makeTestBasicLink(
            id: 'basic-1',
            fromId: 'template-2',
            toId: 'soul-1',
            createdAt: testDate,
            updatedAt: testDate,
          ),
        );

        expect(
          await links.getLinksFrom(
            'template-1',
            type: AgentLinkTypes.soulAssignment,
          ),
          isEmpty,
          reason: 'the typed read hides the removal',
        );
        expect(
          await links.hasAnyLinkFrom(
            'template-1',
            type: AgentLinkTypes.soulAssignment,
          ),
          isTrue,
        );
        expect(
          await links.hasAnyLinkFrom('template-1', type: AgentLinkTypes.basic),
          isFalse,
        );
        expect(
          await links.hasAnyLinkFrom(
            'template-2',
            type: AgentLinkTypes.soulAssignment,
          ),
          isFalse,
        );
      },
    );
  });

  group('slot links (ADR 0099)', () {
    final early = DateTime(2026, 3, 15, 9);
    final late = DateTime(2026, 3, 15, 10);

    model.AgentLink soul(String id, String soulId, DateTime at) =>
        makeTestSoulAssignmentLink(
          id: id,
          fromId: 'tpl-1',
          toId: soulId,
          createdAt: at,
          updatedAt: at,
        );

    Future<List<String>> visibleSouls(AgentRepoLinks repo) async => [
      for (final link in await repo.getLinksFrom(
        'tpl-1',
        type: AgentLinkTypes.soulAssignment,
      ))
        link.toId,
    ];

    test(
      'two devices that reassign one soul concurrently both show the '
      'higher-ranked assignment, not each other',
      () async {
        final otherDb = AgentDatabase(
          inMemoryDatabase: true,
          background: false,
        );
        addTearDown(otherDb.close);
        final deviceB = AgentRepoLinks(otherDb, null);

        final onA = soul('link-a', 'soul-a', late);
        final onB = soul('link-b', 'soul-b', early);
        await links.upsertLink(onA);
        await deviceB.upsertLink(onB);

        // Each receives the other's assignment.
        await links.upsertLink(onB);
        await deviceB.upsertLink(onA);

        // Before ADR 0099 each arrival tombstoned the local assignment:
        // A showed soul-b and B showed soul-a.
        expect(await visibleSouls(links), ['soul-a']);
        expect(await visibleSouls(deviceB), ['soul-a']);
      },
    );

    test(
      'every arrival order of two assignments and a removal shows the '
      'same soul and keeps the same versions',
      () async {
        final versions = [
          soul('link-a', 'soul-a', early),
          soul('link-b', 'soul-b', late),
          soul('link-b', 'soul-b', late).softDeleted(late),
        ];
        final orders = [
          [0, 1, 2],
          [0, 2, 1],
          [1, 0, 2],
          [1, 2, 0],
          [2, 0, 1],
          [2, 1, 0],
        ];
        for (final order in orders) {
          final replicaDb = AgentDatabase(
            inMemoryDatabase: true,
            background: false,
          );
          final replica = AgentRepoLinks(replicaDb, null);
          for (final index in order) {
            final version = versions[index];
            // The receive keeps a tombstone over its own live copy.
            final stored = (await replica.getSlotLinks(
              const AgentLinkSlot.soul('tpl-1'),
            )).where((link) => link.id == version.id).firstOrNull;
            if (stored?.deletedAt != null) continue;
            await replica.upsertLink(version);
          }
          expect(await visibleSouls(replica), ['soul-a'], reason: '$order');
          final stored = await replica.getSlotLinks(
            const AgentLinkSlot.soul('tpl-1'),
          );
          expect(
            {for (final link in stored) link.id: link.deletedAt != null},
            {'link-a': false, 'link-b': true},
            reason: '$order',
          );
          await replicaDb.close();
        }
      },
    );

    test(
      'a lower-ranked live assignment is hidden, not deleted: its serialized '
      'version stays live and it shows once the winner is removed',
      () async {
        final loser = soul('link-a', 'soul-a', early);
        final winner = soul('link-b', 'soul-b', late);
        await links.upsertLink(winner);
        await links.upsertLink(loser);

        expect(await visibleSouls(links), ['soul-b']);
        final raw = await db
            .customSelect(
              'SELECT deleted_at FROM agent_links WHERE id = ?',
              variables: [Variable.withString('link-a')],
            )
            .getSingle();
        expect(raw.data['deleted_at'], isNotNull);
        final slot = await links.getSlotLinks(
          const AgentLinkSlot.soul('tpl-1'),
        );
        expect(slot.singleWhere((l) => l.id == 'link-a'), loser);

        await links.upsertLink(winner.softDeleted(late));
        expect(await visibleSouls(links), ['soul-a']);
      },
    );

    test(
      'two assignments of the same soul under different ids are both kept',
      () async {
        await links.upsertLink(soul('link-a', 'soul-a', early));
        await links.upsertLink(soul('link-b', 'soul-a', late));

        final stored = await links.getSlotLinks(
          const AgentLinkSlot.soul('tpl-1'),
        );
        // Before ADR 0099 the second write hard-deleted the first row.
        expect(stored.map((l) => l.id).toSet(), {'link-a', 'link-b'});
        expect(
          (await links.getLinksFrom(
            'tpl-1',
            type: AgentLinkTypes.soulAssignment,
          )).map((l) => l.id),
          ['link-b'],
        );
      },
    );

    test('the improver slot is keyed by the template in toId', () async {
      await links.upsertLink(
        makeTestImproverTargetLink(
          id: 'imp-a',
          fromId: 'improver-a',
          toId: 'tpl-1',
          createdAt: late,
          updatedAt: late,
        ),
      );
      await links.upsertLink(
        makeTestImproverTargetLink(
          id: 'imp-b',
          fromId: 'improver-b',
          toId: 'tpl-1',
          createdAt: early,
          updatedAt: early,
        ),
      );
      // Another template's improver is a different slot.
      await links.upsertLink(
        makeTestImproverTargetLink(
          id: 'imp-c',
          fromId: 'improver-b',
          toId: 'tpl-2',
          createdAt: early,
          updatedAt: early,
        ),
      );

      final visible = await links.getLinksTo(
        'tpl-1',
        type: AgentLinkTypes.improverTarget,
      );
      expect(visible.map((l) => l.id), ['imp-a']);
      expect(
        (await links.getSlotLinks(
          const AgentLinkSlot.improver('tpl-1'),
        )).map((l) => l.id).toSet(),
        {'imp-a', 'imp-b'},
      );
      expect(
        (await links.getLinksTo(
          'tpl-2',
          type: AgentLinkTypes.improverTarget,
        )).map((l) => l.id),
        ['imp-c'],
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
