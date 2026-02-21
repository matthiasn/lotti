import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/sync/vector_clock.dart';

void main() {
  final createdAt = DateTime(2026, 2, 20);
  final updatedAt = DateTime(2026, 2, 20, 12);
  const vectorClock = VectorClock({'host-a': 2, 'host-b': 5});

  AgentLink roundtrip(AgentLink original) {
    final json =
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>;
    return AgentLink.fromJson(json);
  }

  /// Shared link field assertions to avoid repetition across variants.
  void expectLinkFieldsMatch(AgentLink roundtripped, AgentLink original) {
    expect(roundtripped.id, equals(original.id));
    expect(roundtripped.fromId, equals(original.fromId));
    expect(roundtripped.toId, equals(original.toId));
    expect(roundtripped.createdAt, equals(original.createdAt));
    expect(roundtripped.updatedAt, equals(original.updatedAt));
    expect(roundtripped.vectorClock, equals(original.vectorClock));
    expect(roundtripped.deletedAt, equals(original.deletedAt));
  }

  group('AgentLink serialization roundtrip', () {
    group('BasicAgentLink (basic variant)', () {
      test('roundtrips all fields with vectorClock', () {
        final original = AgentLink.basic(
          id: 'link-basic-001',
          fromId: 'from-001',
          toId: 'to-001',
          createdAt: createdAt,
          updatedAt: updatedAt,
          vectorClock: vectorClock,
        );

        final roundtripped = roundtrip(original);

        expect(roundtripped, equals(original));
        expect(roundtripped, isA<BasicAgentLink>());
        expectLinkFieldsMatch(roundtripped, original);
      });

      test('roundtrips with null vectorClock and deletedAt set', () {
        final original = AgentLink.basic(
          id: 'link-basic-002',
          fromId: 'from-002',
          toId: 'to-002',
          createdAt: createdAt,
          updatedAt: updatedAt,
          vectorClock: null,
          deletedAt: DateTime(2026, 2, 20, 22),
        );

        final roundtripped = roundtrip(original);

        expect(roundtripped, equals(original));
        expect(roundtripped.vectorClock, isNull);
        expect(roundtripped.deletedAt, equals(DateTime(2026, 2, 20, 22)));
      });

      test('runtimeType discriminator key is "basic"', () {
        final link = AgentLink.basic(
          id: 'link-basic-003',
          fromId: 'from-003',
          toId: 'to-003',
          createdAt: createdAt,
          updatedAt: updatedAt,
          vectorClock: null,
        );

        final json = link.toJson();
        expect(json['runtimeType'], equals('basic'));
      });
    });

    group('AgentStateLink (agentState variant)', () {
      test('roundtrips all fields', () {
        final original = AgentLink.agentState(
          id: 'link-state-001',
          fromId: 'agent-001',
          toId: 'state-001',
          createdAt: createdAt,
          updatedAt: updatedAt,
          vectorClock: vectorClock,
        );

        final roundtripped = roundtrip(original);

        expect(roundtripped, equals(original));
        expect(roundtripped, isA<AgentStateLink>());
        expectLinkFieldsMatch(roundtripped, original);
      });

      test('runtimeType discriminator key is "agentState"', () {
        final link = AgentLink.agentState(
          id: 'link-state-002',
          fromId: 'agent-001',
          toId: 'state-001',
          createdAt: createdAt,
          updatedAt: updatedAt,
          vectorClock: null,
        );

        final json = link.toJson();
        expect(json['runtimeType'], equals('agentState'));
      });
    });

    group('MessagePrevLink (messagePrev variant)', () {
      test('roundtrips all fields', () {
        final original = AgentLink.messagePrev(
          id: 'link-prev-001',
          fromId: 'msg-002',
          toId: 'msg-001',
          createdAt: createdAt,
          updatedAt: updatedAt,
          vectorClock: vectorClock,
        );

        final roundtripped = roundtrip(original);

        expect(roundtripped, equals(original));
        expect(roundtripped, isA<MessagePrevLink>());
        expectLinkFieldsMatch(roundtripped, original);
      });

      test('runtimeType discriminator key is "messagePrev"', () {
        final link = AgentLink.messagePrev(
          id: 'link-prev-002',
          fromId: 'msg-002',
          toId: 'msg-001',
          createdAt: createdAt,
          updatedAt: updatedAt,
          vectorClock: null,
        );

        final json = link.toJson();
        expect(json['runtimeType'], equals('messagePrev'));
      });
    });

    group('MessagePayloadLink (messagePayload variant)', () {
      test('roundtrips all fields', () {
        final original = AgentLink.messagePayload(
          id: 'link-payload-001',
          fromId: 'msg-001',
          toId: 'payload-001',
          createdAt: createdAt,
          updatedAt: updatedAt,
          vectorClock: const VectorClock({'host-c': 1}),
        );

        final roundtripped = roundtrip(original);

        expect(roundtripped, equals(original));
        expect(roundtripped, isA<MessagePayloadLink>());
        expectLinkFieldsMatch(roundtripped, original);
      });

      test('runtimeType discriminator key is "messagePayload"', () {
        final link = AgentLink.messagePayload(
          id: 'link-payload-002',
          fromId: 'msg-001',
          toId: 'payload-001',
          createdAt: createdAt,
          updatedAt: updatedAt,
          vectorClock: null,
        );

        final json = link.toJson();
        expect(json['runtimeType'], equals('messagePayload'));
      });
    });

    group('ToolEffectLink (toolEffect variant)', () {
      test('roundtrips all fields', () {
        final original = AgentLink.toolEffect(
          id: 'link-effect-001',
          fromId: 'msg-action-001',
          toId: 'journal-entry-001',
          createdAt: createdAt,
          updatedAt: updatedAt,
          vectorClock: vectorClock,
        );

        final roundtripped = roundtrip(original);

        expect(roundtripped, equals(original));
        expect(roundtripped, isA<ToolEffectLink>());
        expectLinkFieldsMatch(roundtripped, original);
      });

      test('runtimeType discriminator key is "toolEffect"', () {
        final link = AgentLink.toolEffect(
          id: 'link-effect-002',
          fromId: 'msg-action-001',
          toId: 'journal-entry-001',
          createdAt: createdAt,
          updatedAt: updatedAt,
          vectorClock: null,
        );

        final json = link.toJson();
        expect(json['runtimeType'], equals('toolEffect'));
      });
    });

    group('AgentTaskLink (agentTask variant)', () {
      test('roundtrips all fields', () {
        final original = AgentLink.agentTask(
          id: 'link-task-001',
          fromId: 'agent-001',
          toId: 'task-001',
          createdAt: createdAt,
          updatedAt: updatedAt,
          vectorClock: vectorClock,
        );

        final roundtripped = roundtrip(original);

        expect(roundtripped, equals(original));
        expect(roundtripped, isA<AgentTaskLink>());
        expectLinkFieldsMatch(roundtripped, original);
      });

      test('roundtrips with deletedAt timestamp', () {
        final original = AgentLink.agentTask(
          id: 'link-task-002',
          fromId: 'agent-002',
          toId: 'task-099',
          createdAt: createdAt,
          updatedAt: updatedAt,
          vectorClock: null,
          deletedAt: DateTime(2026, 2, 20, 17, 45),
        );

        final roundtripped = roundtrip(original);

        expect(roundtripped, equals(original));
        expect(roundtripped.deletedAt, equals(DateTime(2026, 2, 20, 17, 45)));
      });

      test('runtimeType discriminator key is "agentTask"', () {
        final link = AgentLink.agentTask(
          id: 'link-task-003',
          fromId: 'agent-001',
          toId: 'task-001',
          createdAt: createdAt,
          updatedAt: updatedAt,
          vectorClock: null,
        );

        final json = link.toJson();
        expect(json['runtimeType'], equals('agentTask'));
      });
    });

    group('BasicAgentLink fallback for unknown runtimeType', () {
      test('deserializes unknown runtimeType to BasicAgentLink', () {
        // AgentLink uses fallbackUnion: 'basic', so unknown types map to BasicAgentLink.
        final json = <String, dynamic>{
          'runtimeType': 'futureVariantNotYetKnown',
          'id': 'link-unknown-001',
          'fromId': 'from-unknown',
          'toId': 'to-unknown',
          'createdAt': createdAt.toIso8601String(),
          'updatedAt': updatedAt.toIso8601String(),
          'vectorClock': null,
          'deletedAt': null,
        };

        final result = AgentLink.fromJson(json);

        expect(result, isA<BasicAgentLink>());
        expect(result.id, equals('link-unknown-001'));
        expect(result.fromId, equals('from-unknown'));
        expect(result.toId, equals('to-unknown'));
        expect(result.createdAt, equals(createdAt));
        expect(result.updatedAt, equals(updatedAt));
        expect(result.vectorClock, isNull);
        expect(result.deletedAt, isNull);
      });

      test('deserializes missing runtimeType to BasicAgentLink', () {
        final json = <String, dynamic>{
          'id': 'link-no-type-001',
          'fromId': 'from-notype',
          'toId': 'to-notype',
          'createdAt': createdAt.toIso8601String(),
          'updatedAt': updatedAt.toIso8601String(),
          'vectorClock': null,
          'deletedAt': null,
        };

        final result = AgentLink.fromJson(json);

        expect(result, isA<BasicAgentLink>());
        expect(result.id, equals('link-no-type-001'));
      });
    });
  });
}
