import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/sync/vector_clock.dart';

void main() {
  final createdAt = DateTime(2026, 2, 20);
  final updatedAt = DateTime(2026, 2, 20, 12);
  const vectorClock = VectorClock({'host-a': 3, 'host-b': 1});

  AgentDomainEntity roundtrip(AgentDomainEntity original) {
    final json =
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>;
    return AgentDomainEntity.fromJson(json);
  }

  group('AgentDomainEntity serialization roundtrip', () {
    group('AgentIdentityEntity (agent variant)', () {
      test('roundtrips all fields', () {
        final original = AgentDomainEntity.agent(
          id: 'entity-001',
          agentId: 'agent-001',
          kind: 'journalAssistant',
          displayName: 'Journal Assistant',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: {'cat-001', 'cat-002'},
          currentStateId: 'state-001',
          config: const AgentConfig(
            maxTurnsPerWake: 10,
          ),
          createdAt: createdAt,
          updatedAt: updatedAt,
          vectorClock: vectorClock,
        );

        final roundtripped = roundtrip(original);

        expect(roundtripped, equals(original));
        expect(roundtripped, isA<AgentIdentityEntity>());
      });

      test('roundtrips with optional deletedAt and destroyedAt set', () {
        final original = AgentDomainEntity.agent(
          id: 'entity-002',
          agentId: 'agent-002',
          kind: 'taskPlanner',
          displayName: 'Task Planner',
          lifecycle: AgentLifecycle.destroyed,
          mode: AgentInteractionMode.hybrid,
          allowedCategoryIds: {'cat-010'},
          currentStateId: 'state-002',
          config: const AgentConfig(),
          createdAt: createdAt,
          updatedAt: updatedAt,
          vectorClock: null,
          deletedAt: DateTime(2026, 2, 20, 18),
          destroyedAt: DateTime(2026, 2, 20, 19),
        );

        final roundtripped = roundtrip(original);

        expect(roundtripped, equals(original));
        final identity = roundtripped as AgentIdentityEntity;
        expect(identity.deletedAt, equals(DateTime(2026, 2, 20, 18)));
        expect(identity.destroyedAt, equals(DateTime(2026, 2, 20, 19)));
      });

      test('runtimeType discriminator key is "agent"', () {
        final entity = AgentDomainEntity.agent(
          id: 'entity-003',
          agentId: 'agent-003',
          kind: 'assistant',
          displayName: 'Assistant',
          lifecycle: AgentLifecycle.created,
          mode: AgentInteractionMode.interactive,
          allowedCategoryIds: const {},
          currentStateId: 'state-003',
          config: const AgentConfig(),
          createdAt: createdAt,
          updatedAt: updatedAt,
          vectorClock: null,
        );

        final json = entity.toJson();
        expect(json['runtimeType'], equals('agent'));
      });
    });

    group('AgentStateEntity (agentState variant)', () {
      test('roundtrips all fields including optional timestamps', () {
        final original = AgentDomainEntity.agentState(
          id: 'state-001',
          agentId: 'agent-001',
          revision: 7,
          slots: const AgentSlots(activeTaskId: 'task-abc'),
          updatedAt: updatedAt,
          vectorClock: vectorClock,
          lastWakeAt: DateTime(2026, 2, 20, 8),
          nextWakeAt: DateTime(2026, 2, 20, 20),
          sleepUntil: DateTime(2026, 2, 20, 15),
          recentHeadMessageId: 'msg-head-001',
          latestSummaryMessageId: 'msg-summary-001',
          consecutiveFailureCount: 2,
          wakeCounter: 14,
          processedCounterByHost: {'host-a': 5, 'host-b': 9},
        );

        final roundtripped = roundtrip(original);

        expect(roundtripped, equals(original));
        expect(roundtripped, isA<AgentStateEntity>());
      });

      test('roundtrips with defaults for optional int/map fields', () {
        final original = AgentDomainEntity.agentState(
          id: 'state-002',
          agentId: 'agent-001',
          revision: 1,
          slots: const AgentSlots(),
          updatedAt: updatedAt,
          vectorClock: null,
        );

        final roundtripped = roundtrip(original);

        expect(roundtripped, equals(original));
        final state = roundtripped as AgentStateEntity;
        expect(state.consecutiveFailureCount, equals(0));
        expect(state.wakeCounter, equals(0));
        expect(state.processedCounterByHost, isEmpty);
      });

      test('runtimeType discriminator key is "agentState"', () {
        final entity = AgentDomainEntity.agentState(
          id: 'state-003',
          agentId: 'agent-001',
          revision: 0,
          slots: const AgentSlots(),
          updatedAt: updatedAt,
          vectorClock: null,
        );

        final json = entity.toJson();
        expect(json['runtimeType'], equals('agentState'));
      });
    });

    group('AgentMessageEntity (agentMessage variant)', () {
      test('roundtrips all fields', () {
        final original = AgentDomainEntity.agentMessage(
          id: 'msg-001',
          agentId: 'agent-001',
          threadId: 'thread-001',
          kind: AgentMessageKind.action,
          createdAt: createdAt,
          vectorClock: vectorClock,
          prevMessageId: 'msg-000',
          contentEntryId: 'entry-001',
          triggerSourceId: 'trigger-001',
          summaryStartMessageId: 'msg-start-001',
          summaryEndMessageId: 'msg-end-001',
          summaryDepth: 2,
          tokensApprox: 512,
          metadata: const AgentMessageMetadata(
            runKey: 'run-key-001',
            toolName: 'search_journal',
            operationId: 'op-001',
          ),
        );

        final roundtripped = roundtrip(original);

        expect(roundtripped, equals(original));
        expect(roundtripped, isA<AgentMessageEntity>());
      });

      test('roundtrips with policy denied metadata', () {
        final original = AgentDomainEntity.agentMessage(
          id: 'msg-002',
          agentId: 'agent-001',
          threadId: 'thread-001',
          kind: AgentMessageKind.toolResult,
          createdAt: createdAt,
          vectorClock: null,
          metadata: const AgentMessageMetadata(
            policyDenied: true,
            denialReason: 'Access not permitted for category',
          ),
        );

        final roundtripped = roundtrip(original);

        expect(roundtripped, equals(original));
        final msg = roundtripped as AgentMessageEntity;
        expect(msg.metadata.policyDenied, isTrue);
        expect(msg.metadata.denialReason,
            equals('Access not permitted for category'));
      });

      test('roundtrips each AgentMessageKind variant', () {
        for (final kind in AgentMessageKind.values) {
          final original = AgentDomainEntity.agentMessage(
            id: 'msg-kind-${kind.name}',
            agentId: 'agent-001',
            threadId: 'thread-001',
            kind: kind,
            createdAt: createdAt,
            vectorClock: null,
            metadata: const AgentMessageMetadata(),
          );

          final roundtripped = roundtrip(original);

          expect(roundtripped, equals(original), reason: 'kind: $kind');
          expect((roundtripped as AgentMessageEntity).kind, equals(kind));
        }
      });

      test('runtimeType discriminator key is "agentMessage"', () {
        final entity = AgentDomainEntity.agentMessage(
          id: 'msg-003',
          agentId: 'agent-001',
          threadId: 'thread-001',
          kind: AgentMessageKind.user,
          createdAt: createdAt,
          vectorClock: null,
          metadata: const AgentMessageMetadata(),
        );

        final json = entity.toJson();
        expect(json['runtimeType'], equals('agentMessage'));
      });
    });

    group('AgentMessagePayloadEntity (agentMessagePayload variant)', () {
      test('roundtrips all fields with nested content map', () {
        final original = AgentDomainEntity.agentMessagePayload(
          id: 'payload-001',
          agentId: 'agent-001',
          createdAt: createdAt,
          vectorClock: vectorClock,
          content: {
            'role': 'assistant',
            'text': 'Here is my analysis.',
            'tokens': 128,
          },
        );

        final roundtripped = roundtrip(original);

        expect(roundtripped, equals(original));
        expect(roundtripped, isA<AgentMessagePayloadEntity>());
      });

      test('roundtrips with default contentType', () {
        final original = AgentDomainEntity.agentMessagePayload(
          id: 'payload-002',
          agentId: 'agent-001',
          createdAt: createdAt,
          vectorClock: null,
          content: {'key': 'value'},
        );

        final roundtripped = roundtrip(original);

        expect(roundtripped, equals(original));
        expect(
          (roundtripped as AgentMessagePayloadEntity).contentType,
          equals('application/json'),
        );
      });

      test('runtimeType discriminator key is "agentMessagePayload"', () {
        final entity = AgentDomainEntity.agentMessagePayload(
          id: 'payload-003',
          agentId: 'agent-001',
          createdAt: createdAt,
          vectorClock: null,
          content: {},
        );

        final json = entity.toJson();
        expect(json['runtimeType'], equals('agentMessagePayload'));
      });
    });

    group('AgentReportEntity (agentReport variant)', () {
      test('roundtrips all fields', () {
        final original = AgentDomainEntity.agentReport(
          id: 'report-001',
          agentId: 'agent-001',
          scope: 'weekly-summary',
          createdAt: createdAt,
          vectorClock: vectorClock,
          content: {
            'summary': 'Completed 5 tasks this week.',
            'score': 0.87,
          },
          confidence: 0.92,
          provenance: {'model': 'gemini-3.1-pro-preview', 'wakeId': 'wake-042'},
        );

        final roundtripped = roundtrip(original);

        expect(roundtripped, equals(original));
        expect(roundtripped, isA<AgentReportEntity>());
      });

      test('roundtrips with null confidence and empty provenance', () {
        final original = AgentDomainEntity.agentReport(
          id: 'report-002',
          agentId: 'agent-001',
          scope: 'daily',
          createdAt: createdAt,
          vectorClock: null,
          content: {'note': 'nothing to report'},
        );

        final roundtripped = roundtrip(original);

        expect(roundtripped, equals(original));
        final report = roundtripped as AgentReportEntity;
        expect(report.confidence, isNull);
        expect(report.provenance, isEmpty);
      });

      test('runtimeType discriminator key is "agentReport"', () {
        final entity = AgentDomainEntity.agentReport(
          id: 'report-003',
          agentId: 'agent-001',
          scope: 'test',
          createdAt: createdAt,
          vectorClock: null,
          content: {},
        );

        final json = entity.toJson();
        expect(json['runtimeType'], equals('agentReport'));
      });
    });

    group('AgentReportHeadEntity (agentReportHead variant)', () {
      test('roundtrips all fields', () {
        final original = AgentDomainEntity.agentReportHead(
          id: 'head-001',
          agentId: 'agent-001',
          scope: 'weekly-summary',
          reportId: 'report-001',
          updatedAt: updatedAt,
          vectorClock: vectorClock,
        );

        final roundtripped = roundtrip(original);

        expect(roundtripped, equals(original));
        expect(roundtripped, isA<AgentReportHeadEntity>());
      });

      test('roundtrips with deletedAt set', () {
        final original = AgentDomainEntity.agentReportHead(
          id: 'head-002',
          agentId: 'agent-001',
          scope: 'daily',
          reportId: 'report-010',
          updatedAt: updatedAt,
          vectorClock: null,
          deletedAt: DateTime(2026, 2, 20, 23, 59),
        );

        final roundtripped = roundtrip(original);

        expect(roundtripped, equals(original));
        expect(
          (roundtripped as AgentReportHeadEntity).deletedAt,
          equals(DateTime(2026, 2, 20, 23, 59)),
        );
      });

      test('runtimeType discriminator key is "agentReportHead"', () {
        final entity = AgentDomainEntity.agentReportHead(
          id: 'head-003',
          agentId: 'agent-001',
          scope: 'test',
          reportId: 'report-000',
          updatedAt: updatedAt,
          vectorClock: null,
        );

        final json = entity.toJson();
        expect(json['runtimeType'], equals('agentReportHead'));
      });
    });

    group('AgentUnknownEntity fallback (unknown variant)', () {
      test('deserializes unknown runtimeType to AgentUnknownEntity', () {
        final json = <String, dynamic>{
          'runtimeType': 'futureVariantNotYetKnown',
          'id': 'unknown-001',
          'agentId': 'agent-001',
          'createdAt': createdAt.toIso8601String(),
          'vectorClock': null,
          'deletedAt': null,
        };

        final result = AgentDomainEntity.fromJson(json);

        expect(result, isA<AgentUnknownEntity>());
        final unknown = result as AgentUnknownEntity;
        expect(unknown.id, equals('unknown-001'));
        expect(unknown.agentId, equals('agent-001'));
        expect(unknown.createdAt, equals(createdAt));
        expect(unknown.vectorClock, isNull);
        expect(unknown.deletedAt, isNull);
      });

      test('explicit unknown variant roundtrips', () {
        final original = AgentDomainEntity.unknown(
          id: 'unknown-002',
          agentId: 'agent-001',
          createdAt: createdAt,
          vectorClock: vectorClock,
        );

        final roundtripped = roundtrip(original);

        expect(roundtripped, equals(original));
        expect(roundtripped, isA<AgentUnknownEntity>());
      });

      test('unknown variant with vectorClock and deletedAt roundtrips', () {
        final original = AgentDomainEntity.unknown(
          id: 'unknown-003',
          agentId: 'agent-002',
          createdAt: createdAt,
          vectorClock: const VectorClock({'node-x': 7}),
          deletedAt: DateTime(2026, 2, 20, 16, 30),
        );

        final roundtripped = roundtrip(original);

        expect(roundtripped, equals(original));
        final unknown = roundtripped as AgentUnknownEntity;
        expect(unknown.vectorClock, equals(const VectorClock({'node-x': 7})));
        expect(unknown.deletedAt, equals(DateTime(2026, 2, 20, 16, 30)));
      });
    });
  });
}
