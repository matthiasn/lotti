import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/pending_wake_record.dart';

import '../test_data/constants.dart';
import '../test_data/entity_factories.dart';

void main() {
  group('PendingWakeRecord.id', () {
    test('combines agentId, type name, and dueAt ISO-8601 string', () {
      final identity = makeTestIdentity(id: 'agent-42', agentId: 'agent-42');
      final state = makeTestState(agentId: 'agent-42');
      final dueAt = DateTime(2026, 5, 10, 8, 30);

      final record = PendingWakeRecord(
        agent: identity,
        state: state,
        type: PendingWakeType.scheduled,
        dueAt: dueAt,
      );

      expect(record.id, equals('agent-42:scheduled:${dueAt.toIso8601String()}'));
    });

    test('pending type produces "pending" segment', () {
      final identity = makeTestIdentity();
      final state = makeTestState();
      final dueAt = DateTime(2024, 3, 15, 10, 30);

      final record = PendingWakeRecord(
        agent: identity,
        state: state,
        type: PendingWakeType.pending,
        dueAt: dueAt,
      );

      expect(record.id, startsWith('$kTestAgentId:pending:'));
      expect(record.id, endsWith(dueAt.toIso8601String()));
    });

    test('different agentIds produce different ids for same type and dueAt',
        () {
      final identity1 = makeTestIdentity(id: 'agent-1', agentId: 'agent-1');
      final identity2 = makeTestIdentity(id: 'agent-2', agentId: 'agent-2');
      final state1 = makeTestState(agentId: 'agent-1');
      final state2 = makeTestState(agentId: 'agent-2');
      final dueAt = DateTime(2024, 6, 1, 9);

      final r1 = PendingWakeRecord(
        agent: identity1,
        state: state1,
        type: PendingWakeType.pending,
        dueAt: dueAt,
      );
      final r2 = PendingWakeRecord(
        agent: identity2,
        state: state2,
        type: PendingWakeType.pending,
        dueAt: dueAt,
      );

      expect(r1.id, isNot(equals(r2.id)));
    });

    test('different dueAt timestamps produce different ids', () {
      final identity = makeTestIdentity();
      final state = makeTestState();
      final due1 = DateTime(2024, 6, 1, 9);
      final due2 = DateTime(2024, 6, 1, 10);

      final r1 = PendingWakeRecord(
        agent: identity,
        state: state,
        type: PendingWakeType.scheduled,
        dueAt: due1,
      );
      final r2 = PendingWakeRecord(
        agent: identity,
        state: state,
        type: PendingWakeType.scheduled,
        dueAt: due2,
      );

      expect(r1.id, isNot(equals(r2.id)));
    });

    test('different types produce different ids for same agent and dueAt', () {
      final identity = makeTestIdentity();
      final state = makeTestState();
      final dueAt = DateTime(2024, 6, 1, 9);

      final rPending = PendingWakeRecord(
        agent: identity,
        state: state,
        type: PendingWakeType.pending,
        dueAt: dueAt,
      );
      final rScheduled = PendingWakeRecord(
        agent: identity,
        state: state,
        type: PendingWakeType.scheduled,
        dueAt: dueAt,
      );

      expect(rPending.id, isNot(equals(rScheduled.id)));
    });

    test('id contains agentId, type name, and ISO-8601 date segments', () {
      final identity = makeTestIdentity(agentId: 'agent-007');
      final state = makeTestState(agentId: 'agent-007');
      final dueAt = DateTime(2024, 12, 31, 23, 59, 59);

      final record = PendingWakeRecord(
        agent: identity,
        state: state,
        type: PendingWakeType.scheduled,
        dueAt: dueAt,
      );

      // Format: <agentId>:<typeName>:<iso8601>
      // The ISO-8601 string itself contains colons (HH:mm:ss) so there are
      // more than 3 colon-separated tokens, but the key segments are present.
      expect(record.id.split(':').length, greaterThanOrEqualTo(3));
      expect(record.id, contains('agent-007'));
      expect(record.id, contains('scheduled'));
    });
  });
}
