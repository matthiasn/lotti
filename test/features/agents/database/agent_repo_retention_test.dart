import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repo_core.dart';
import 'package:lotti/features/agents/database/agent_repo_retention.dart';

import '../test_data/entity_factories.dart';

/// Mirror tests for [AgentRepoRetention]: a real in-memory [AgentDatabase],
/// real rows, and assertions on exactly which ones survive a sweep.
void main() {
  late AgentDatabase db;
  late AgentRepoCore core;
  late AgentRepoRetention retention;

  final now = DateTime(2026, 8);

  setUp(() {
    db = AgentDatabase(inMemoryDatabase: true, background: false);
    core = AgentRepoCore(db);
    retention = AgentRepoRetention(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<List<String>> idsOfType(String type) async {
    final rows = await db
        .customSelect(
          'SELECT id FROM agent_entities WHERE type = ?1 ORDER BY id',
          variables: [Variable<String>(type)],
        )
        .get();
    return [for (final row in rows) row.read<String>('id')];
  }

  group('pruneDayStatusEventsBefore', () {
    test('deletes only events older than the cutoff', () async {
      for (final (id, age) in [('old', 200), ('edge', 91), ('recent', 5)]) {
        await core.upsertEntity(
          makeTestDayStatusEvent(
            id: id,
            raisedAt: now.subtract(Duration(days: age)),
            createdAt: now.subtract(Duration(days: age)),
          ),
        );
      }

      final pruned = await retention.pruneDayStatusEventsBefore(
        now.subtract(const Duration(days: 90)),
        batchSize: 10,
        maxBatches: 5,
      );

      expect(pruned, 2);
      expect(await idsOfType('day_status_event'), ['recent']);
    });

    test('keeps the newest event per agent, not per day alone', () async {
      // Two agents can raise events for the same day. Without agent_id in the
      // correlated lookup, the newer agent's event licenses deleting the
      // other agent's last one — and that day would then be presented from
      // nothing on the second agent's behalf.
      for (final (id, agentId, hours) in [
        ('a-old', 'day_agent:one', 5),
        ('a-newest', 'day_agent:one', 4),
        ('b-only', 'day_agent:two', 1),
      ]) {
        await core.upsertEntity(
          makeTestDayStatusEvent(
            id: id,
            agentId: agentId,
            dayId: 'dayplan-2025-01-01',
            raisedAt: now.subtract(Duration(days: 200, hours: hours)),
            createdAt: now.subtract(Duration(days: 200, hours: hours)),
          ),
        );
      }

      final pruned = await retention.pruneDayStatusEventsBefore(
        now.subtract(const Duration(days: 90)),
        batchSize: 10,
        maxBatches: 5,
      );

      expect(pruned, 1);
      expect(
        await idsOfType('day_status_event'),
        ['a-newest', 'b-only'],
        reason: 'Each agent keeps its own newest event for the day.',
      );
    });

    test(
      "keeps each day's newest event, which decides how it is shown",
      () async {
        // dayAgentPersonaProvider reads the newest event for a day to decide
        // its presentation, so clearing a day entirely changes what the user
        // sees when they scroll back to it.
        for (final (id, hours) in [('old-1', 5), ('old-2', 3), ('newest', 1)]) {
          await core.upsertEntity(
            makeTestDayStatusEvent(
              id: id,
              dayId: 'dayplan-2025-01-01',
              raisedAt: now.subtract(Duration(days: 200, hours: hours)),
              createdAt: now.subtract(Duration(days: 200, hours: hours)),
            ),
          );
        }

        final pruned = await retention.pruneDayStatusEventsBefore(
          now.subtract(const Duration(days: 90)),
          batchSize: 10,
          maxBatches: 5,
        );

        expect(pruned, 2);
        expect(
          await idsOfType('day_status_event'),
          ['newest'],
          reason: 'One row per day is bounded; zero rows per day is lossy.',
        );
      },
    );

    test('never touches the day plan the events describe', () async {
      final plan = makeTestDayPlan(
        id: 'day_agent_plan:dayplan-2020-01-01',
        dayId: 'dayplan-2020-01-01',
        planDate: DateTime(2020),
        createdAt: DateTime(2020),
      );
      await core.upsertEntity(plan);
      // Two, so one is prunable — a day's newest event is kept on purpose.
      for (final (id, hour) in [('ancient', 1), ('ancient-newer', 2)]) {
        await core.upsertEntity(
          makeTestDayStatusEvent(
            id: id,
            raisedAt: DateTime(2020, 1, 1, hour),
            createdAt: DateTime(2020, 1, 1, hour),
          ),
        );
      }

      await retention.pruneDayStatusEventsBefore(
        now,
        batchSize: 10,
        maxBatches: 5,
      );

      expect(await idsOfType('day_status_event'), ['ancient-newer']);
      expect(
        await idsOfType('day_plan'),
        [plan.id],
        reason: "A day plan is the user's own material and never expires.",
      );
    });
  });
}
