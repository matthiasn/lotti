import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repo_core.dart';
import 'package:lotti/features/agents/database/agent_repo_retention.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';

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

  /// Writes an observation as the workflow does: a payload row carrying the
  /// text plus a message row pointing at it.
  Future<void> writeObservation({
    required String agentId,
    required String id,
    required DateTime createdAt,
  }) async {
    await core.upsertEntity(
      AgentDomainEntity.agentMessagePayload(
        id: 'payload-$id',
        agentId: agentId,
        createdAt: createdAt,
        vectorClock: null,
        content: {'text': 'observation $id'},
      ),
    );
    await core.upsertEntity(
      AgentDomainEntity.agentMessage(
        id: id,
        agentId: agentId,
        threadId: 'thread-1',
        kind: AgentMessageKind.observation,
        createdAt: createdAt,
        vectorClock: null,
        contentEntryId: 'payload-$id',
        metadata: const AgentMessageMetadata(),
      ),
    );
  }

  Future<List<String>> idsOfType(String type) async {
    final rows = await db
        .customSelect(
          'SELECT id FROM agent_entities WHERE type = ?1 ORDER BY id',
          variables: [Variable<String>(type)],
        )
        .get();
    return [for (final row in rows) row.read<String>('id')];
  }

  group('pruneObservationsBeyond', () {
    test('keeps the newest N per agent and deletes their payloads with '
        'them', () async {
      for (var i = 0; i < 6; i++) {
        await writeObservation(
          agentId: 'coordinator',
          id: 'obs-$i',
          createdAt: now.subtract(Duration(days: 6 - i)),
        );
      }

      final pruned = await retention.pruneObservations(
        keepPerAgent: 2,
        cutoff: DateTime(2000),
        batchSize: 10,
        maxBatches: 5,
      );

      expect(pruned, 4);
      expect(
        await idsOfType('agentMessage'),
        ['obs-4', 'obs-5'],
        reason: 'Newest by (created_at, id) — the same order reads use.',
      );
      expect(
        await idsOfType('agentMessagePayload'),
        ['payload-obs-4', 'payload-obs-5'],
        reason:
            'The payload carries the text and is the larger row. Leaving it '
            'behind would be retention that grows the store.',
      );
    });

    test('the keep count is per agent, not global', () async {
      for (final agentId in ['coordinator', 'day_agent:2026-08-01']) {
        for (var i = 0; i < 3; i++) {
          await writeObservation(
            agentId: agentId,
            id: '$agentId-obs-$i',
            createdAt: now.subtract(Duration(days: 3 - i)),
          );
        }
      }

      await retention.pruneObservations(
        keepPerAgent: 2,
        cutoff: DateTime(2000),
        batchSize: 10,
        maxBatches: 5,
      );

      final survivors = await idsOfType('agentMessage');
      expect(survivors, hasLength(4));
      expect(
        survivors.where((id) => id.startsWith('coordinator')),
        hasLength(2),
        reason:
            'A busy coordinator must not evict a quiet day agent — otherwise '
            'the bound depends on which agents happened to write recently.',
      );
    });

    test('leaves non-observation messages alone', () async {
      await core.upsertEntity(
        AgentDomainEntity.agentMessage(
          id: 'a-summary',
          agentId: 'coordinator',
          threadId: 'thread-1',
          kind: AgentMessageKind.summary,
          createdAt: now.subtract(const Duration(days: 900)),
          vectorClock: null,
          metadata: const AgentMessageMetadata(),
        ),
      );
      for (var i = 0; i < 3; i++) {
        await writeObservation(
          agentId: 'coordinator',
          id: 'obs-$i',
          createdAt: now.subtract(Duration(days: 3 - i)),
        );
      }

      await retention.pruneObservations(
        keepPerAgent: 1,
        cutoff: DateTime(2000),
        batchSize: 10,
        maxBatches: 5,
      );

      expect(await idsOfType('agentMessage'), contains('a-summary'));
    });

    test('is bounded by maxBatches and resumes on the next sweep', () async {
      for (var i = 0; i < 10; i++) {
        await writeObservation(
          agentId: 'coordinator',
          id: 'obs-${i.toString().padLeft(2, '0')}',
          createdAt: now.subtract(Duration(days: 10 - i)),
        );
      }

      final first = await retention.pruneObservations(
        keepPerAgent: 2,
        cutoff: DateTime(2000),
        batchSize: 3,
        maxBatches: 1,
      );

      expect(first, 3, reason: 'One batch of three, then stop.');
      expect(await idsOfType('agentMessage'), hasLength(7));

      final second = await retention.pruneObservations(
        keepPerAgent: 2,
        cutoff: DateTime(2000),
        batchSize: 3,
        maxBatches: 5,
      );

      expect(second, 5);
      expect(
        await idsOfType('agentMessage'),
        ['obs-08', 'obs-09'],
        reason: 'An interrupted sweep leaves the rest for the next one.',
      );
    });

    test('a second sweep with nothing to do removes nothing', () async {
      for (var i = 0; i < 3; i++) {
        await writeObservation(
          agentId: 'coordinator',
          id: 'obs-$i',
          createdAt: now.subtract(Duration(days: 3 - i)),
        );
      }
      await retention.pruneObservations(
        keepPerAgent: 2,
        cutoff: DateTime(2000),
        batchSize: 10,
        maxBatches: 5,
      );

      expect(
        await retention.pruneObservations(
          keepPerAgent: 2,
          cutoff: DateTime(2000),
          batchSize: 10,
          maxBatches: 5,
        ),
        0,
        reason: 'Idempotent, which is what makes interruption harmless.',
      );
    });

    test(
      'the age ceiling reaps cold per-day agents the count cannot',
      () async {
        // Daily OS writes observations under a fresh day_agent:<dayId> identity
        // every day and each goes cold permanently, so a per-agent count alone
        // lets one more agent — with a full quota of its own — appear forever.
        for (var day = 0; day < 5; day++) {
          await writeObservation(
            agentId: 'day_agent:2025-0$day',
            id: 'cold-$day',
            createdAt: now.subtract(Duration(days: 200 + day)),
          );
        }
        await writeObservation(
          agentId: 'daily_os_planner',
          id: 'warm',
          createdAt: now.subtract(const Duration(days: 3)),
        );

        final pruned = await retention.pruneObservations(
          keepPerAgent: 200,
          cutoff: now.subtract(const Duration(days: 120)),
          batchSize: 10,
          maxBatches: 5,
        );

        expect(pruned, 5);
        expect(
          await idsOfType('agentMessage'),
          ['warm'],
          reason:
              'Every cold agent was inside its own per-agent quota; only the '
              'age ceiling can reach them.',
        );
        expect(await idsOfType('agentMessagePayload'), ['payload-warm']);
      },
    );

    test('the causal links of pruned observations go with them', () async {
      for (var i = 0; i < 3; i++) {
        await writeObservation(
          agentId: 'coordinator',
          id: 'obs-$i',
          createdAt: now.subtract(Duration(days: 3 - i)),
        );
        await db.customUpdate(
          'INSERT INTO agent_links (id, from_id, to_id, type, created_at, '
          'updated_at, serialized) VALUES (?1, ?2, ?3, ?4, ?5, ?5, ?6)',
          variables: [
            Variable<String>('link-$i'),
            Variable<String>('obs-$i'),
            Variable<String>('payload-obs-$i'),
            const Variable<String>('message_payload'),
            Variable<DateTime>(now),
            const Variable<String>('{}'),
          ],
        );
      }

      await retention.pruneObservations(
        keepPerAgent: 1,
        cutoff: DateTime(2000),
        batchSize: 10,
        maxBatches: 5,
      );

      final links = await db
          .customSelect('SELECT id FROM agent_links ORDER BY id')
          .get();
      expect(
        [for (final row in links) row.read<String>('id')],
        ['link-2'],
        reason:
            'Leaving the links behind would keep that table growing exactly '
            'as the entity table stopped, and leave the fork projection '
            'walking edges whose ends no longer exist.',
      );
    });
  });

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
