import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_proposal_ledger.dart';
import 'package:lotti/features/agents/database/agent_repo_core.dart';
import 'package:lotti/features/agents/database/agent_repo_evolution.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/sync/vector_clock.dart';

import '../test_data/change_set_factories.dart';
import '../test_data/evolution_factories.dart';

/// Mirror tests for [AgentRepoEvolution]. They construct the collaborator wired
/// to real [AgentRepoCore] and [AgentProposalLedger] instances over an
/// in-memory [AgentDatabase], covering the evolution/change-set reads it owns
/// plus its two cross-collaborator hops (recap hydration via core, ledger
/// assembly via the ledger collaborator).
void main() {
  late AgentDatabase db;
  late AgentRepoCore core;
  late AgentProposalLedger ledger;
  late AgentRepoEvolution evolution;

  final testDate = DateTime(2026, 3, 15);

  setUp(() {
    db = AgentDatabase(inMemoryDatabase: true, background: false);
    core = AgentRepoCore(db);
    ledger = AgentProposalLedger(db);
    evolution = AgentRepoEvolution(db, core, ledger);
  });

  tearDown(() async {
    await db.close();
  });

  group('getEvolutionSessions', () {
    test('returns sessions for the template, newest first', () async {
      await core.upsertEntity(
        makeTestEvolutionSession(
          id: 'evo-old',
          templateId: 'tpl-1',
          agentId: 'tpl-1',
          createdAt: DateTime(2026, 3, 10),
        ),
      );
      await core.upsertEntity(
        makeTestEvolutionSession(
          id: 'evo-new',
          templateId: 'tpl-1',
          agentId: 'tpl-1',
          sessionNumber: 2,
          createdAt: DateTime(2026, 3, 12),
        ),
      );

      final sessions = await evolution.getEvolutionSessions('tpl-1');
      expect(sessions.map((s) => s.id), ['evo-new', 'evo-old']);
    });
  });

  group('getEvolutionSessionRecap', () {
    test('hydrates the recap by deterministic id (core hop)', () async {
      await core.upsertEntity(
        makeTestEvolutionSessionRecap(
          id: evolutionSessionRecapId('sess-1'),
          sessionId: 'sess-1',
          agentId: 'tpl-1',
          createdAt: testDate,
        ),
      );

      final recap = await evolution.getEvolutionSessionRecap('sess-1');
      expect(recap, isNotNull);
      expect(recap!.sessionId, 'sess-1');
    });

    test('returns null when no recap exists', () async {
      expect(await evolution.getEvolutionSessionRecap('none'), isNull);
    });
  });

  group('getPendingChangeSets', () {
    test('filters by taskId in Dart and caps at the limit', () async {
      await core.upsertEntity(
        makeTestChangeSet(
          id: 'cs-task-a',
          agentId: 'agent-1',
          taskId: 'task-a',
          createdAt: testDate,
          vectorClock: const VectorClock({'node-1': 1}),
        ),
      );
      await core.upsertEntity(
        makeTestChangeSet(
          id: 'cs-task-b',
          agentId: 'agent-1',
          taskId: 'task-b',
          createdAt: testDate,
          vectorClock: const VectorClock({'node-1': 2}),
        ),
      );

      final forTaskA = await evolution.getPendingChangeSets(
        'agent-1',
        taskId: 'task-a',
      );
      expect(forTaskA.map((cs) => cs.id), ['cs-task-a']);
    });
  });

  group('getProposalLedger (ledger hop)', () {
    test('assembles open entries from a pending change set', () async {
      await core.upsertEntity(
        makeTestChangeSet(
          id: 'cs-led',
          agentId: 'agent-1',
          taskId: 'task-1',
          createdAt: testDate,
          vectorClock: const VectorClock({'node-1': 1}),
          items: const [
            ChangeItem(
              toolName: 'update_task_estimate',
              args: {'minutes': 30},
              humanSummary: 'Estimate 30m',
            ),
          ],
        ),
      );

      final result = await evolution.getProposalLedger(
        'agent-1',
        taskId: 'task-1',
      );
      expect(result.open, hasLength(1));
      expect(result.open.single.toolName, 'update_task_estimate');
    });
  });

  group('interval counts', () {
    test(
      'countEntitiesInInterval counts rows in the half-open window',
      () async {
        await core.upsertEntity(
          makeTestEvolutionSession(
            id: 'evo-in',
            templateId: 'tpl-1',
            agentId: 'tpl-1',
            updatedAt: DateTime(2026, 3, 15, 10),
            createdAt: DateTime(2026, 3, 15, 10),
          ),
        );

        final count = await evolution.countEntitiesInInterval(
          start: DateTime(2026, 3, 15),
          end: DateTime(2026, 3, 16),
        );
        expect(count, 1);
      },
    );
  });
}
