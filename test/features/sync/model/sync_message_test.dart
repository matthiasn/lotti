import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/vector_clock.dart';

void main() {
  group('SyncMessage.themingSelection', () {
    test('serializes to JSON correctly', () {
      const message = SyncMessage.themingSelection(
        lightThemeName: 'Indigo',
        darkThemeName: 'Shark',
        themeMode: 'dark',
        updatedAt: 1234567890,
        status: SyncEntryStatus.update,
      );

      final json = message.toJson();

      expect(json['runtimeType'], 'themingSelection');
      expect(json['lightThemeName'], 'Indigo');
      expect(json['darkThemeName'], 'Shark');
      expect(json['themeMode'], 'dark');
      expect(json['updatedAt'], 1234567890);
      expect(json['status'], 'update');
    });

    test('deserializes from JSON correctly', () {
      final json = {
        'runtimeType': 'themingSelection',
        'lightThemeName': 'Indigo',
        'darkThemeName': 'Shark',
        'themeMode': 'dark',
        'updatedAt': 1234567890,
        'status': 'update',
      };

      final message = SyncMessage.fromJson(json) as SyncThemingSelection;

      expect(message.lightThemeName, 'Indigo');
      expect(message.darkThemeName, 'Shark');
      expect(message.themeMode, 'dark');
      expect(message.updatedAt, 1234567890);
      expect(message.status, SyncEntryStatus.update);
    });

    test('round-trip preserves all fields', () {
      const original = SyncMessage.themingSelection(
        lightThemeName: 'Indigo',
        darkThemeName: 'Shark',
        themeMode: 'light',
        updatedAt: 9876543210,
        status: SyncEntryStatus.initial,
      ) as SyncThemingSelection;

      final json = original.toJson();
      final decoded = SyncMessage.fromJson(json) as SyncThemingSelection;

      expect(decoded.lightThemeName, original.lightThemeName);
      expect(decoded.darkThemeName, original.darkThemeName);
      expect(decoded.themeMode, original.themeMode);
      expect(decoded.updatedAt, original.updatedAt);
      expect(decoded.status, original.status);
    });

    test('handles extra JSON fields gracefully', () {
      final json = {
        'runtimeType': 'themingSelection',
        'lightThemeName': 'Indigo',
        'darkThemeName': 'Shark',
        'themeMode': 'dark',
        'updatedAt': 1234567890,
        'status': 'update',
        'extraField': 'should be ignored',
      };

      final message = SyncMessage.fromJson(json) as SyncThemingSelection;

      expect(message.lightThemeName, 'Indigo');
      expect(message.darkThemeName, 'Shark');
    });
  });

  group('SyncAgentEntity serialization', () {
    final testDate = DateTime(2024, 3, 15);
    const testVectorClock = VectorClock({'host-a': 1, 'host-b': 2});

    test('round-trips agent identity entity', () {
      final entity = AgentDomainEntity.agent(
        id: 'agent-1',
        agentId: 'agent-1',
        kind: 'task_agent',
        displayName: 'Test Agent',
        lifecycle: AgentLifecycle.active,
        mode: AgentInteractionMode.autonomous,
        allowedCategoryIds: const {'cat-1'},
        currentStateId: 'state-1',
        config: const AgentConfig(),
        createdAt: testDate,
        updatedAt: testDate,
        vectorClock: testVectorClock,
      );

      final msg = SyncMessage.agentEntity(
        agentEntity: entity,
        status: SyncEntryStatus.update,
      );

      final json = jsonEncode(msg.toJson());
      final decoded =
          SyncMessage.fromJson(jsonDecode(json) as Map<String, dynamic>);

      expect(decoded, isA<SyncAgentEntity>());
      final decodedMsg = decoded as SyncAgentEntity;
      expect(decodedMsg.status, SyncEntryStatus.update);

      final decodedEntity = decodedMsg.agentEntity!;
      expect(decodedEntity, isA<AgentIdentityEntity>());
      final identity = decodedEntity as AgentIdentityEntity;
      expect(identity.id, 'agent-1');
      expect(identity.kind, 'task_agent');
      expect(identity.displayName, 'Test Agent');
      expect(identity.lifecycle, AgentLifecycle.active);
      expect(identity.allowedCategoryIds, {'cat-1'});
      expect(identity.vectorClock?.vclock, testVectorClock.vclock);
    });

    test('round-trips agent state entity', () {
      final entity = AgentDomainEntity.agentState(
        id: 'state-1',
        agentId: 'agent-1',
        revision: 5,
        slots: const AgentSlots(),
        updatedAt: testDate,
        vectorClock: testVectorClock,
        wakeCounter: 42,
      );

      final msg = SyncMessage.agentEntity(
        agentEntity: entity,
        status: SyncEntryStatus.initial,
      );

      final json = jsonEncode(msg.toJson());
      final decoded =
          SyncMessage.fromJson(jsonDecode(json) as Map<String, dynamic>);

      expect(decoded, isA<SyncAgentEntity>());
      final decodedMsg = decoded as SyncAgentEntity;
      expect(decodedMsg.status, SyncEntryStatus.initial);

      final decodedEntity = decodedMsg.agentEntity!;
      expect(decodedEntity, isA<AgentStateEntity>());
      final state = decodedEntity as AgentStateEntity;
      expect(state.revision, 5);
      expect(state.wakeCounter, 42);
    });

    test('round-trips agent message entity', () {
      final entity = AgentDomainEntity.agentMessage(
        id: 'msg-1',
        agentId: 'agent-1',
        threadId: 'thread-1',
        kind: AgentMessageKind.thought,
        createdAt: testDate,
        vectorClock: testVectorClock,
        metadata: const AgentMessageMetadata(),
        tokensApprox: 100,
      );

      final msg = SyncMessage.agentEntity(
        agentEntity: entity,
        status: SyncEntryStatus.update,
      );

      final json = jsonEncode(msg.toJson());
      final decoded =
          SyncMessage.fromJson(jsonDecode(json) as Map<String, dynamic>);

      final decodedMsg = decoded as SyncAgentEntity;
      final decodedEntity = decodedMsg.agentEntity!;
      expect(decodedEntity, isA<AgentMessageEntity>());
      final message = decodedEntity as AgentMessageEntity;
      expect(message.threadId, 'thread-1');
      expect(message.kind, AgentMessageKind.thought);
      expect(message.tokensApprox, 100);
    });

    test('round-trips agent message payload entity', () {
      final entity = AgentDomainEntity.agentMessagePayload(
        id: 'payload-1',
        agentId: 'agent-1',
        createdAt: testDate,
        vectorClock: testVectorClock,
        content: const {'text': 'hello world', 'role': 'assistant'},
      );

      final msg = SyncMessage.agentEntity(
        agentEntity: entity,
        status: SyncEntryStatus.update,
      );

      final json = jsonEncode(msg.toJson());
      final decoded =
          SyncMessage.fromJson(jsonDecode(json) as Map<String, dynamic>);

      final decodedMsg = decoded as SyncAgentEntity;
      final decodedEntity = decodedMsg.agentEntity!;
      expect(decodedEntity, isA<AgentMessagePayloadEntity>());
      final payload = decodedEntity as AgentMessagePayloadEntity;
      expect(payload.content['text'], 'hello world');
      expect(payload.content['role'], 'assistant');
    });

    test('round-trips agent report entity', () {
      final entity = AgentDomainEntity.agentReport(
        id: 'report-1',
        agentId: 'agent-1',
        scope: 'current',
        createdAt: testDate,
        vectorClock: testVectorClock,
        content: 'The agent observed changes in 3 tasks.',
        confidence: 0.85,
      );

      final msg = SyncMessage.agentEntity(
        agentEntity: entity,
        status: SyncEntryStatus.update,
      );

      final json = jsonEncode(msg.toJson());
      final decoded =
          SyncMessage.fromJson(jsonDecode(json) as Map<String, dynamic>);

      final decodedMsg = decoded as SyncAgentEntity;
      final decodedEntity = decodedMsg.agentEntity!;
      expect(decodedEntity, isA<AgentReportEntity>());
      final report = decodedEntity as AgentReportEntity;
      expect(report.scope, 'current');
      expect(report.content, 'The agent observed changes in 3 tasks.');
      expect(report.confidence, 0.85);
    });

    test('round-trips agent report head entity', () {
      final entity = AgentDomainEntity.agentReportHead(
        id: 'head-1',
        agentId: 'agent-1',
        scope: 'current',
        reportId: 'report-1',
        updatedAt: testDate,
        vectorClock: testVectorClock,
      );

      final msg = SyncMessage.agentEntity(
        agentEntity: entity,
        status: SyncEntryStatus.update,
      );

      final json = jsonEncode(msg.toJson());
      final decoded =
          SyncMessage.fromJson(jsonDecode(json) as Map<String, dynamic>);

      final decodedMsg = decoded as SyncAgentEntity;
      final decodedEntity = decodedMsg.agentEntity!;
      expect(decodedEntity, isA<AgentReportHeadEntity>());
      final head = decodedEntity as AgentReportHeadEntity;
      expect(head.scope, 'current');
      expect(head.reportId, 'report-1');
    });

    test('round-trips with null vectorClock', () {
      final entity = AgentDomainEntity.agent(
        id: 'agent-1',
        agentId: 'agent-1',
        kind: 'task_agent',
        displayName: 'Test Agent',
        lifecycle: AgentLifecycle.active,
        mode: AgentInteractionMode.autonomous,
        allowedCategoryIds: const {},
        currentStateId: 'state-1',
        config: const AgentConfig(),
        createdAt: testDate,
        updatedAt: testDate,
        vectorClock: null,
      );

      final msg = SyncMessage.agentEntity(
        agentEntity: entity,
        status: SyncEntryStatus.update,
      );

      final json = jsonEncode(msg.toJson());
      final decoded =
          SyncMessage.fromJson(jsonDecode(json) as Map<String, dynamic>);

      final decodedMsg = decoded as SyncAgentEntity;
      final identity = decodedMsg.agentEntity! as AgentIdentityEntity;
      expect(identity.vectorClock, isNull);
    });
  });

  group('SyncAgentLink serialization', () {
    final testDate = DateTime(2024, 3, 15);
    const testVectorClock = VectorClock({'host-a': 1, 'host-b': 2});

    test('round-trips basic link', () {
      final link = AgentLink.basic(
        id: 'link-1',
        fromId: 'agent-1',
        toId: 'state-1',
        createdAt: testDate,
        updatedAt: testDate,
        vectorClock: testVectorClock,
      );

      final msg = SyncMessage.agentLink(
        agentLink: link,
        status: SyncEntryStatus.update,
      );

      final json = jsonEncode(msg.toJson());
      final decoded =
          SyncMessage.fromJson(jsonDecode(json) as Map<String, dynamic>);

      expect(decoded, isA<SyncAgentLink>());
      final decodedMsg = decoded as SyncAgentLink;
      expect(decodedMsg.status, SyncEntryStatus.update);

      final decodedLink = decodedMsg.agentLink!;
      expect(decodedLink, isA<BasicAgentLink>());
      expect(decodedLink.id, 'link-1');
      expect(decodedLink.fromId, 'agent-1');
      expect(decodedLink.toId, 'state-1');
      expect(decodedLink.vectorClock?.vclock, testVectorClock.vclock);
    });

    test('round-trips agentState link', () {
      final link = AgentLink.agentState(
        id: 'link-2',
        fromId: 'agent-1',
        toId: 'state-1',
        createdAt: testDate,
        updatedAt: testDate,
        vectorClock: testVectorClock,
      );

      final msg = SyncMessage.agentLink(
        agentLink: link,
        status: SyncEntryStatus.update,
      );

      final json = jsonEncode(msg.toJson());
      final decoded =
          SyncMessage.fromJson(jsonDecode(json) as Map<String, dynamic>);

      final decodedLink = (decoded as SyncAgentLink).agentLink!;
      expect(decodedLink, isA<AgentStateLink>());
    });

    test('round-trips messagePrev link', () {
      final link = AgentLink.messagePrev(
        id: 'link-3',
        fromId: 'msg-2',
        toId: 'msg-1',
        createdAt: testDate,
        updatedAt: testDate,
        vectorClock: testVectorClock,
      );

      final msg = SyncMessage.agentLink(
        agentLink: link,
        status: SyncEntryStatus.update,
      );

      final json = jsonEncode(msg.toJson());
      final decoded =
          SyncMessage.fromJson(jsonDecode(json) as Map<String, dynamic>);

      final decodedLink = (decoded as SyncAgentLink).agentLink!;
      expect(decodedLink, isA<MessagePrevLink>());
    });

    test('round-trips messagePayload link', () {
      final link = AgentLink.messagePayload(
        id: 'link-4',
        fromId: 'msg-1',
        toId: 'payload-1',
        createdAt: testDate,
        updatedAt: testDate,
        vectorClock: testVectorClock,
      );

      final msg = SyncMessage.agentLink(
        agentLink: link,
        status: SyncEntryStatus.update,
      );

      final json = jsonEncode(msg.toJson());
      final decoded =
          SyncMessage.fromJson(jsonDecode(json) as Map<String, dynamic>);

      final decodedLink = (decoded as SyncAgentLink).agentLink!;
      expect(decodedLink, isA<MessagePayloadLink>());
    });

    test('round-trips toolEffect link', () {
      final link = AgentLink.toolEffect(
        id: 'link-5',
        fromId: 'msg-1',
        toId: 'entry-1',
        createdAt: testDate,
        updatedAt: testDate,
        vectorClock: testVectorClock,
      );

      final msg = SyncMessage.agentLink(
        agentLink: link,
        status: SyncEntryStatus.update,
      );

      final json = jsonEncode(msg.toJson());
      final decoded =
          SyncMessage.fromJson(jsonDecode(json) as Map<String, dynamic>);

      final decodedLink = (decoded as SyncAgentLink).agentLink!;
      expect(decodedLink, isA<ToolEffectLink>());
    });

    test('round-trips agentTask link', () {
      final link = AgentLink.agentTask(
        id: 'link-6',
        fromId: 'agent-1',
        toId: 'task-1',
        createdAt: testDate,
        updatedAt: testDate,
        vectorClock: testVectorClock,
      );

      final msg = SyncMessage.agentLink(
        agentLink: link,
        status: SyncEntryStatus.update,
      );

      final json = jsonEncode(msg.toJson());
      final decoded =
          SyncMessage.fromJson(jsonDecode(json) as Map<String, dynamic>);

      final decodedLink = (decoded as SyncAgentLink).agentLink!;
      expect(decodedLink, isA<AgentTaskLink>());
    });

    test('round-trips with null vectorClock', () {
      final link = AgentLink.basic(
        id: 'link-1',
        fromId: 'agent-1',
        toId: 'state-1',
        createdAt: testDate,
        updatedAt: testDate,
        vectorClock: null,
      );

      final msg = SyncMessage.agentLink(
        agentLink: link,
        status: SyncEntryStatus.update,
      );

      final json = jsonEncode(msg.toJson());
      final decoded =
          SyncMessage.fromJson(jsonDecode(json) as Map<String, dynamic>);

      final decodedLink = (decoded as SyncAgentLink).agentLink;
      expect(decodedLink, isNotNull);
      expect(decodedLink!.vectorClock, isNull);
    });
  });

  group('SyncAgentEntity descriptor-only (jsonPath)', () {
    test('round-trips descriptor-only message with jsonPath', () {
      const msg = SyncMessage.agentEntity(
        status: SyncEntryStatus.update,
        jsonPath: '/agent_entities/agent-1.json',
      );

      final encoded = jsonEncode(msg.toJson());
      final decoded =
          SyncMessage.fromJson(jsonDecode(encoded) as Map<String, dynamic>);

      expect(decoded, isA<SyncAgentEntity>());
      final decodedMsg = decoded as SyncAgentEntity;
      expect(decodedMsg.agentEntity, isNull);
      expect(decodedMsg.jsonPath, '/agent_entities/agent-1.json');
      expect(decodedMsg.status, SyncEntryStatus.update);
    });

    test('backward compat: inline entity with null jsonPath', () {
      final entity = AgentDomainEntity.agent(
        id: 'agent-1',
        agentId: 'agent-1',
        kind: 'task_agent',
        displayName: 'Test',
        lifecycle: AgentLifecycle.active,
        mode: AgentInteractionMode.autonomous,
        allowedCategoryIds: const {},
        currentStateId: 'state-1',
        config: const AgentConfig(),
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
      );

      final msg = SyncMessage.agentEntity(
        agentEntity: entity,
        status: SyncEntryStatus.update,
      );

      final encoded = jsonEncode(msg.toJson());
      final decoded =
          SyncMessage.fromJson(jsonDecode(encoded) as Map<String, dynamic>);

      final decodedMsg = decoded as SyncAgentEntity;
      expect(decodedMsg.agentEntity, isNotNull);
      expect(decodedMsg.jsonPath, isNull);
    });
  });

  group('SyncAgentLink descriptor-only (jsonPath)', () {
    test('round-trips descriptor-only message with jsonPath', () {
      const msg = SyncMessage.agentLink(
        status: SyncEntryStatus.update,
        jsonPath: '/agent_links/link-1.json',
      );

      final encoded = jsonEncode(msg.toJson());
      final decoded =
          SyncMessage.fromJson(jsonDecode(encoded) as Map<String, dynamic>);

      expect(decoded, isA<SyncAgentLink>());
      final decodedMsg = decoded as SyncAgentLink;
      expect(decodedMsg.agentLink, isNull);
      expect(decodedMsg.jsonPath, '/agent_links/link-1.json');
      expect(decodedMsg.status, SyncEntryStatus.update);
    });

    test('backward compat: inline link with null jsonPath', () {
      final link = AgentLink.basic(
        id: 'link-1',
        fromId: 'agent-1',
        toId: 'state-1',
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
      );

      final msg = SyncMessage.agentLink(
        agentLink: link,
        status: SyncEntryStatus.update,
      );

      final encoded = jsonEncode(msg.toJson());
      final decoded =
          SyncMessage.fromJson(jsonDecode(encoded) as Map<String, dynamic>);

      final decodedMsg = decoded as SyncAgentLink;
      expect(decodedMsg.agentLink, isNotNull);
      expect(decodedMsg.jsonPath, isNull);
    });
  });
}
