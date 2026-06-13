import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/sync/g_counter.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/model/sync_node_profile.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'sync_message_test_helpers.dart';

void main() {
  group('SyncMessage.configFlag', () {
    test('round-trips a config flag through JSON', () {
      const flag = ConfigFlag(
        name: 'enableDailyOs',
        description: 'Enable DailyOS Page?',
        status: true,
      );
      final message = SyncMessage.configFlag(
        name: flag.name,
        description: flag.description,
        status: flag.status,
        originatingHostId: 'host-a',
      );

      final decoded = SyncMessage.fromJson(message.toJson()) as SyncConfigFlag;

      expect(decoded.name, flag.name);
      expect(decoded.description, flag.description);
      expect(decoded.status, flag.status);
      expect(decoded.originatingHostId, 'host-a');
      expect(decoded.toJson()['runtimeType'], 'configFlag');
    });
  });

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
      const original =
          SyncMessage.themingSelection(
                lightThemeName: 'Indigo',
                darkThemeName: 'Shark',
                themeMode: 'light',
                updatedAt: 9876543210,
                status: SyncEntryStatus.initial,
              )
              as SyncThemingSelection;

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

  group('SyncMessage.syncNodeProfile', () {
    final updatedAt = DateTime.utc(2026, 3, 15, 12, 30);

    test('round-trips a node profile through JSON', () {
      final profile = SyncNodeProfile(
        hostId: 'host-uuid-abc',
        displayName: 'Studio Mac',
        platform: 'macos',
        cpuModel: 'Apple M4 Max',
        ramMb: 65536,
        capabilities: const [
          NodeCapability.mlxAudio,
          NodeCapability.ollamaLlm,
        ],
        updatedAt: updatedAt,
      );

      final message = SyncMessage.syncNodeProfile(profile: profile);

      final json = jsonEncode(message.toJson());
      final decoded =
          SyncMessage.fromJson(jsonDecode(json) as Map<String, dynamic>)
              as SyncSyncNodeProfile;

      expect(decoded.profile.hostId, 'host-uuid-abc');
      expect(decoded.profile.displayName, 'Studio Mac');
      expect(decoded.profile.platform, 'macos');
      expect(decoded.profile.cpuModel, 'Apple M4 Max');
      expect(decoded.profile.ramMb, 65536);
      expect(decoded.profile.capabilities, [
        NodeCapability.mlxAudio,
        NodeCapability.ollamaLlm,
      ]);
      expect(decoded.profile.updatedAt, updatedAt);
    });

    test('emits a stable runtimeType discriminator', () {
      final profile = SyncNodeProfile(
        hostId: 'h',
        displayName: 'A',
        platform: 'macos',
        capabilities: const [NodeCapability.mlxAudio],
        updatedAt: updatedAt,
      );

      final json = SyncMessage.syncNodeProfile(profile: profile).toJson();

      expect(json['runtimeType'], 'syncNodeProfile');
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

      final decodedEntity = hRoundTripAgentEntity(
        msg,
        expectStatus: SyncEntryStatus.update,
      );
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
        wakeCounter: const GCounter({'host-a': 41, 'host-b': 1}),
      );

      final msg = SyncMessage.agentEntity(
        agentEntity: entity,
        status: SyncEntryStatus.initial,
      );

      final decodedEntity = hRoundTripAgentEntity(
        msg,
        expectStatus: SyncEntryStatus.initial,
      );
      expect(decodedEntity, isA<AgentStateEntity>());
      final state = decodedEntity as AgentStateEntity;
      expect(state.revision, 5);
      // Full per-host equality, not just the sum — proves the by-host map
      // survives the JSON round-trip rather than being flattened to a value.
      expect(state.wakeCounter, const GCounter({'host-a': 41, 'host-b': 1}));
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

      final decodedEntity = hRoundTripAgentEntity(
        msg,
        expectStatus: SyncEntryStatus.update,
      );
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

      final decodedEntity = hRoundTripAgentEntity(
        msg,
        expectStatus: SyncEntryStatus.update,
      );
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

      final decodedEntity = hRoundTripAgentEntity(
        msg,
        expectStatus: SyncEntryStatus.update,
      );
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

      final decodedEntity = hRoundTripAgentEntity(
        msg,
        expectStatus: SyncEntryStatus.update,
      );
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

      final identity =
          hRoundTripAgentEntity(
                msg,
                expectStatus: SyncEntryStatus.update,
              )
              as AgentIdentityEntity;
      expect(identity.vectorClock, isNull);
    });
  });
}
