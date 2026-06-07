import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:json_annotation/json_annotation.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/sync/g_counter.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/model/sync_node_profile.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/vector_clock.dart';

// ---------------------------------------------------------------------------
// Glados helpers — top-level so they are accessible inside main()
// ---------------------------------------------------------------------------

class _GeneratedThemingSelection {
  const _GeneratedThemingSelection({
    required this.lightThemeName,
    required this.darkThemeName,
    required this.themeMode,
    required this.updatedAt,
    required this.status,
  });

  final String lightThemeName;
  final String darkThemeName;
  final String themeMode;
  final int updatedAt;
  final SyncEntryStatus status;

  @override
  String toString() =>
      '_GeneratedThemingSelection('
      'lightThemeName: $lightThemeName, '
      'darkThemeName: $darkThemeName, '
      'themeMode: $themeMode, '
      'updatedAt: $updatedAt, '
      'status: $status'
      ')';
}

class _GeneratedBackfillRequest {
  _GeneratedBackfillRequest({
    required this.requesterId,
    required this.entries,
  });

  final String requesterId;
  final List<BackfillRequestEntry> entries;

  @override
  String toString() =>
      '_GeneratedBackfillRequest('
      'requesterId: $requesterId, '
      'entries: $entries'
      ')';
}

class _GeneratedBackfillResponse {
  const _GeneratedBackfillResponse({
    required this.hostId,
    required this.counter,
    required this.deleted,
    required this.unresolvable,
    required this.payloadType,
  });

  final String hostId;
  final int counter;
  final bool deleted;
  final bool unresolvable;
  final SyncSequencePayloadType? payloadType;

  @override
  String toString() =>
      '_GeneratedBackfillResponse('
      'hostId: $hostId, '
      'counter: $counter, '
      'deleted: $deleted, '
      'unresolvable: $unresolvable, '
      'payloadType: $payloadType'
      ')';
}

class _GeneratedAiConfigDelete {
  const _GeneratedAiConfigDelete({required this.id});

  final String id;

  @override
  String toString() => '_GeneratedAiConfigDelete(id: $id)';
}

extension _AnySyncMessageGlados on glados.Any {
  glados.Generator<String> get _twoCharId =>
      glados.CombinableAny(this).combine2(
        glados.any.letterOrDigits,
        glados.any.letterOrDigits,
        (String a, String b) => '$a$b',
      );

  glados.Generator<SyncEntryStatus> get _syncEntryStatus =>
      glados.AnyUtils(this).choose(SyncEntryStatus.values);

  glados.Generator<SyncSequencePayloadType?> get _optionalPayloadType =>
      glados.CombinableAny(this).combine2(
        glados.BoolAny(this).bool,
        glados.AnyUtils(this).choose(SyncSequencePayloadType.values),
        (bool include, SyncSequencePayloadType t) => include ? t : null,
      );

  glados.Generator<_GeneratedThemingSelection> get generatedThemingSelection =>
      glados.CombinableAny(this).combine5(
        _twoCharId,
        _twoCharId,
        glados.AnyUtils(this).choose(
          const <String>['light', 'dark', 'system'],
        ),
        glados.IntAnys(this).intInRange(0, 999999999),
        _syncEntryStatus,
        (
          String light,
          String dark,
          String mode,
          int ts,
          SyncEntryStatus status,
        ) => _GeneratedThemingSelection(
          lightThemeName: light,
          darkThemeName: dark,
          themeMode: mode,
          updatedAt: ts,
          status: status,
        ),
      );

  glados.Generator<_GeneratedAiConfigDelete> get generatedAiConfigDelete =>
      _twoCharId.map((String id) => _GeneratedAiConfigDelete(id: id));

  glados.Generator<BackfillRequestEntry> get _backfillEntry =>
      glados.CombinableAny(this).combine2(
        _twoCharId,
        glados.IntAnys(this).intInRange(1, 9999),
        (String hostId, int counter) =>
            BackfillRequestEntry(hostId: hostId, counter: counter),
      );

  glados.Generator<_GeneratedBackfillRequest> get generatedBackfillRequest =>
      glados.CombinableAny(this).combine2(
        _twoCharId,
        glados.ListAnys(this).listWithLengthInRange(0, 6, _backfillEntry),
        (String requesterId, List<BackfillRequestEntry> entries) =>
            _GeneratedBackfillRequest(
              requesterId: requesterId,
              entries: entries,
            ),
      );

  glados.Generator<_GeneratedBackfillResponse> get generatedBackfillResponse =>
      glados.CombinableAny(this).combine5(
        _twoCharId,
        glados.IntAnys(this).intInRange(1, 9999),
        glados.BoolAny(this).bool,
        glados.BoolAny(this).bool,
        _optionalPayloadType,
        (
          String hostId,
          int counter,
          bool deleted,
          bool unresolvable,
          SyncSequencePayloadType? payloadType,
        ) => _GeneratedBackfillResponse(
          hostId: hostId,
          counter: counter,
          deleted: deleted,
          unresolvable: unresolvable,
          payloadType: payloadType,
        ),
      );
}

SyncMessage _roundTripSyncMessage(SyncMessage msg) => SyncMessage.fromJson(
  jsonDecode(jsonEncode(msg.toJson())) as Map<String, dynamic>,
);

/// Round-trips an agentEntity message and unwraps the decoded entity,
/// asserting the envelope type and status on the way.
AgentDomainEntity _roundTripAgentEntity(
  SyncMessage msg, {
  required SyncEntryStatus expectStatus,
}) {
  final decoded = _roundTripSyncMessage(msg);
  expect(decoded, isA<SyncAgentEntity>());
  final decodedMsg = decoded as SyncAgentEntity;
  expect(decodedMsg.status, expectStatus);
  return decodedMsg.agentEntity!;
}

/// Round-trips an agentLink message and unwraps the decoded link,
/// asserting the envelope type and status on the way.
AgentLink _roundTripAgentLink(
  SyncMessage msg, {
  required SyncEntryStatus expectStatus,
}) {
  final decoded = _roundTripSyncMessage(msg);
  expect(decoded, isA<SyncAgentLink>());
  final decodedMsg = decoded as SyncAgentLink;
  expect(decodedMsg.status, expectStatus);
  return decodedMsg.agentLink!;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

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

      final decodedEntity = _roundTripAgentEntity(
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

      final decodedEntity = _roundTripAgentEntity(
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

      final decodedEntity = _roundTripAgentEntity(
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

      final decodedEntity = _roundTripAgentEntity(
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

      final decodedEntity = _roundTripAgentEntity(
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

      final decodedEntity = _roundTripAgentEntity(
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
          _roundTripAgentEntity(
                msg,
                expectStatus: SyncEntryStatus.update,
              )
              as AgentIdentityEntity;
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

      final decodedLink = _roundTripAgentLink(
        msg,
        expectStatus: SyncEntryStatus.update,
      );
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

      final decodedLink = _roundTripAgentLink(
        msg,
        expectStatus: SyncEntryStatus.update,
      );
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

      final decodedLink = _roundTripAgentLink(
        msg,
        expectStatus: SyncEntryStatus.update,
      );
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

      final decodedLink = _roundTripAgentLink(
        msg,
        expectStatus: SyncEntryStatus.update,
      );
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

      final decodedLink = _roundTripAgentLink(
        msg,
        expectStatus: SyncEntryStatus.update,
      );
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

      final decodedLink = _roundTripAgentLink(
        msg,
        expectStatus: SyncEntryStatus.update,
      );
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

      final decodedLink = _roundTripAgentLink(
        msg,
        expectStatus: SyncEntryStatus.update,
      );
      expect(decodedLink.vectorClock, isNull);
    });
  });

  group('SyncAgentEntity descriptor-only (jsonPath)', () {
    test('round-trips descriptor-only message with jsonPath', () {
      const msg = SyncMessage.agentEntity(
        status: SyncEntryStatus.update,
        jsonPath: '/agent_entities/agent-1.json',
      );

      final encoded = jsonEncode(msg.toJson());
      final decoded = SyncMessage.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );

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
      final decoded = SyncMessage.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );

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
      final decoded = SyncMessage.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );

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
      final decoded = SyncMessage.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );

      final decodedMsg = decoded as SyncAgentLink;
      expect(decodedMsg.agentLink, isNotNull);
      expect(decodedMsg.jsonPath, isNull);
    });
  });

  group('SyncAgentBundle serialization', () {
    test('round-trips inline child messages', () {
      final testDate = DateTime(2024, 3, 15);
      final entity = AgentDomainEntity.agentState(
        id: 'state-1',
        agentId: 'agent-1',
        revision: 2,
        slots: const AgentSlots(),
        updatedAt: testDate,
        vectorClock: const VectorClock({'host-a': 10}),
      );
      final link = AgentLink.basic(
        id: 'link-1',
        fromId: 'agent-1',
        toId: 'state-1',
        createdAt: testDate,
        updatedAt: testDate,
        vectorClock: const VectorClock({'host-a': 11}),
      );

      final msg = SyncMessage.agentBundle(
        agentId: 'agent-1',
        wakeRunKey: 'run-1',
        originatingHostId: 'host-a',
        entities: [
          SyncMessage.agentEntity(
                status: SyncEntryStatus.update,
                agentEntity: entity,
                originatingHostId: 'host-a',
              )
              as SyncAgentEntity,
        ],
        links: [
          SyncMessage.agentLink(
                status: SyncEntryStatus.update,
                agentLink: link,
                originatingHostId: 'host-a',
              )
              as SyncAgentLink,
        ],
      );

      final encoded = jsonEncode(msg.toJson());
      final decoded = SyncMessage.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );

      expect(decoded, isA<SyncAgentBundle>());
      final bundle = decoded as SyncAgentBundle;
      expect(bundle.agentId, 'agent-1');
      expect(bundle.wakeRunKey, 'run-1');
      expect(bundle.originatingHostId, 'host-a');
      expect(bundle.entities.single.agentEntity, entity);
      expect(bundle.links.single.agentLink, link);
    });

    test('round-trips descriptor-only bundle with jsonPath', () {
      const msg = SyncMessage.agentBundle(
        agentId: 'agent-1',
        wakeRunKey: 'run-1',
        jsonPath: '/agent_bundles/run-1.json',
      );

      final encoded = jsonEncode(msg.toJson());
      final decoded = SyncMessage.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );

      expect(decoded, isA<SyncAgentBundle>());
      final bundle = decoded as SyncAgentBundle;
      expect(bundle.entities, isEmpty);
      expect(bundle.links, isEmpty);
      expect(bundle.jsonPath, '/agent_bundles/run-1.json');
    });
  });

  // -------------------------------------------------------------------------
  // Glados — generative JSON round-trip properties
  // -------------------------------------------------------------------------

  group('SyncMessage — Glados JSON round-trip', () {
    glados.Glados(
      glados.any.generatedThemingSelection,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'themingSelection round-trip preserves all scalar fields',
      (gen) {
        final msg = SyncMessage.themingSelection(
          lightThemeName: gen.lightThemeName,
          darkThemeName: gen.darkThemeName,
          themeMode: gen.themeMode,
          updatedAt: gen.updatedAt,
          status: gen.status,
        );
        final decoded = _roundTripSyncMessage(msg) as SyncThemingSelection;
        expect(decoded.lightThemeName, gen.lightThemeName, reason: '$gen');
        expect(decoded.darkThemeName, gen.darkThemeName, reason: '$gen');
        expect(decoded.themeMode, gen.themeMode, reason: '$gen');
        expect(decoded.updatedAt, gen.updatedAt, reason: '$gen');
        expect(decoded.status, gen.status, reason: '$gen');
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.generatedThemingSelection,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'themingSelection runtimeType discriminator is stable across variants',
      (gen) {
        final msg = SyncMessage.themingSelection(
          lightThemeName: gen.lightThemeName,
          darkThemeName: gen.darkThemeName,
          themeMode: gen.themeMode,
          updatedAt: gen.updatedAt,
          status: gen.status,
        );
        final json =
            jsonDecode(jsonEncode(msg.toJson())) as Map<String, dynamic>;
        expect(json['runtimeType'], 'themingSelection', reason: '$gen');
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.generatedAiConfigDelete,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'aiConfigDelete round-trip preserves id',
      (gen) {
        final msg = SyncMessage.aiConfigDelete(id: gen.id);
        final decoded = _roundTripSyncMessage(msg) as SyncAiConfigDelete;
        expect(decoded.id, gen.id, reason: '$gen');
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.generatedBackfillRequest,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'backfillRequest round-trip preserves requester and entry list',
      (gen) {
        final msg = SyncMessage.backfillRequest(
          entries: gen.entries,
          requesterId: gen.requesterId,
        );
        final decoded = _roundTripSyncMessage(msg) as SyncBackfillRequest;
        expect(decoded.requesterId, gen.requesterId, reason: '$gen');
        expect(decoded.entries.length, gen.entries.length, reason: '$gen');
        for (var i = 0; i < gen.entries.length; i++) {
          expect(
            decoded.entries[i].hostId,
            gen.entries[i].hostId,
            reason: 'entry[$i] $gen',
          );
          expect(
            decoded.entries[i].counter,
            gen.entries[i].counter,
            reason: 'entry[$i] $gen',
          );
        }
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.generatedBackfillResponse,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'backfillResponse round-trip preserves all fields',
      (gen) {
        final msg = SyncMessage.backfillResponse(
          hostId: gen.hostId,
          counter: gen.counter,
          deleted: gen.deleted,
          unresolvable: gen.unresolvable,
          payloadType: gen.payloadType,
        );
        final decoded = _roundTripSyncMessage(msg) as SyncBackfillResponse;
        expect(decoded.hostId, gen.hostId, reason: '$gen');
        expect(decoded.counter, gen.counter, reason: '$gen');
        expect(decoded.deleted, gen.deleted, reason: '$gen');
        expect(decoded.unresolvable, gen.unresolvable, reason: '$gen');
        expect(decoded.payloadType, gen.payloadType, reason: '$gen');
      },
      tags: 'glados',
    );
  });
  group('forward compatibility', () {
    test('an unknown runtimeType from a newer peer throws on fromJson', () {
      // Pins the current contract: freezed unions have no fallback case, so
      // a message type this build does not know fails deserialization. The
      // sync inbound pipeline treats that as a per-message error rather
      // than a crash; if a silent-skip fallback is ever desired, add a
      // fallback union case and update this test.
      expect(
        () => SyncMessage.fromJson(const {
          'runtimeType': 'unknownFutureVariant',
          'somePayload': 42,
        }),
        throwsA(isA<CheckedFromJsonException>()),
      );
    });
  });
}
