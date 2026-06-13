import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:json_annotation/json_annotation.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'sync_message_test_helpers.dart';

void main() {
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

      final decodedLink = hRoundTripAgentLink(
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

      final decodedLink = hRoundTripAgentLink(
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

      final decodedLink = hRoundTripAgentLink(
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

      final decodedLink = hRoundTripAgentLink(
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

      final decodedLink = hRoundTripAgentLink(
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

      final decodedLink = hRoundTripAgentLink(
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

      final decodedLink = hRoundTripAgentLink(
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
        final decoded = hRoundTripSyncMessage(msg) as SyncThemingSelection;
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
        final decoded = hRoundTripSyncMessage(msg) as SyncAiConfigDelete;
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
        final decoded = hRoundTripSyncMessage(msg) as SyncBackfillRequest;
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
        final decoded = hRoundTripSyncMessage(msg) as SyncBackfillResponse;
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
