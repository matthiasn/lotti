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

    test('never touches the day plan the events describe', () async {
      final plan = makeTestDayPlan(
        id: 'day_agent_plan:dayplan-2020-01-01',
        dayId: 'dayplan-2020-01-01',
        planDate: DateTime(2020),
        createdAt: DateTime(2020),
      );
      await core.upsertEntity(plan);
      await core.upsertEntity(
        makeTestDayStatusEvent(
          id: 'ancient',
          raisedAt: DateTime(2020),
          createdAt: DateTime(2020),
        ),
      );

      await retention.pruneDayStatusEventsBefore(
        now,
        batchSize: 10,
        maxBatches: 5,
      );

      expect(await idsOfType('day_status_event'), isEmpty);
      expect(
        await idsOfType('day_plan'),
        [plan.id],
        reason: "A day plan is the user's own material and never expires.",
      );
    });
  });
}
