import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/model/sync_node_profile.dart';
import 'package:lotti/features/sync/outbox/outbox_scheduling.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:lotti/features/sync/vector_clock.dart';

enum _GeneratedPriorityMessageKind {
  journalEntity,
  entityDefinition,
  entryLink,
  aiConfig,
  aiConfigDelete,
  themingSelection,
  backfillRequest,
  backfillResponse,
  agentEntity,
  agentLink,
  agentBundle,
  notification,
  notificationStateUpdate,
  outboxBundle,
  syncNodeProfile,
  configFlag,
}

class _GeneratedPriorityScenario {
  const _GeneratedPriorityScenario({
    required this.kind,
    required this.statusIsUpdate,
    required this.counterSlot,
    required this.deleted,
  });

  final _GeneratedPriorityMessageKind kind;
  final bool statusIsUpdate;
  final int counterSlot;
  final bool deleted;

  SyncEntryStatus get status =>
      statusIsUpdate ? SyncEntryStatus.update : SyncEntryStatus.initial;

  SyncMessage get message {
    final id = 'generated-$counterSlot';
    return switch (kind) {
      _GeneratedPriorityMessageKind.journalEntity => SyncMessage.journalEntity(
        id: id,
        jsonPath: '/entries/$id.json',
        vectorClock: VectorClock({'hostA': counterSlot}),
        status: status,
      ),
      _GeneratedPriorityMessageKind.entityDefinition =>
        SyncMessage.entityDefinition(
          entityDefinition: EntityDefinition.measurableDataType(
            id: id,
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
            displayName: 'Generated',
            description: 'Generated definition',
            unitName: 'count',
            version: 1,
            vectorClock: VectorClock({'hostA': counterSlot}),
          ),
          status: status,
        ),
      _GeneratedPriorityMessageKind.entryLink => SyncMessage.entryLink(
        entryLink: EntryLink.basic(
          id: id,
          fromId: 'from-$counterSlot',
          toId: 'to-$counterSlot',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          vectorClock: VectorClock({'hostA': counterSlot}),
        ),
        status: status,
      ),
      _GeneratedPriorityMessageKind.aiConfig => SyncMessage.aiConfig(
        aiConfig: AiConfig.inferenceProvider(
          id: id,
          name: 'Generated provider',
          apiKey: 'key-$counterSlot',
          baseUrl: 'https://example.invalid/v1',
          createdAt: DateTime(2024),
          inferenceProviderType: InferenceProviderType.genericOpenAi,
        ),
        status: status,
      ),
      _GeneratedPriorityMessageKind.aiConfigDelete =>
        SyncMessage.aiConfigDelete(id: id),
      _GeneratedPriorityMessageKind.themingSelection =>
        SyncMessage.themingSelection(
          lightThemeName: 'light-$counterSlot',
          darkThemeName: 'dark-$counterSlot',
          themeMode: statusIsUpdate ? 'dark' : 'light',
          updatedAt: counterSlot,
          status: status,
        ),
      _GeneratedPriorityMessageKind.backfillRequest =>
        SyncMessage.backfillRequest(
          entries: [
            for (var index = 0; index < counterSlot; index++)
              BackfillRequestEntry(hostId: 'host-$index', counter: index),
          ],
          requesterId: 'requester-$counterSlot',
        ),
      _GeneratedPriorityMessageKind.backfillResponse =>
        SyncMessage.backfillResponse(
          hostId: 'host-$counterSlot',
          counter: counterSlot,
          deleted: deleted,
          entryId: deleted ? null : id,
        ),
      _GeneratedPriorityMessageKind.agentEntity => SyncMessage.agentEntity(
        status: status,
        jsonPath: '/agents/entities/$id.json',
      ),
      _GeneratedPriorityMessageKind.agentLink => SyncMessage.agentLink(
        status: status,
        jsonPath: '/agents/links/$id.json',
      ),
      _GeneratedPriorityMessageKind.agentBundle => SyncMessage.agentBundle(
        agentId: 'agent-$counterSlot',
        wakeRunKey: 'wake-$counterSlot',
      ),
      _GeneratedPriorityMessageKind.notification => SyncMessage.notification(
        id: id,
        jsonPath: '/notifications/$id.json',
        vectorClock: VectorClock({'hostA': counterSlot}),
        originatingHostId: 'hostA',
      ),
      _GeneratedPriorityMessageKind.notificationStateUpdate =>
        SyncMessage.notificationStateUpdate(
          id: id,
          seenAt: deleted ? DateTime(2024) : null,
          vectorClock: VectorClock({'hostA': counterSlot}),
          originatingHostId: 'hostA',
        ),
      _GeneratedPriorityMessageKind.outboxBundle => SyncMessage.outboxBundle(
        children: [SyncMessage.aiConfigDelete(id: id)],
      ),
      _GeneratedPriorityMessageKind.syncNodeProfile =>
        SyncMessage.syncNodeProfile(
          profile: SyncNodeProfile(
            hostId: 'host-$counterSlot',
            displayName: 'Device $counterSlot',
            platform: 'macos',
            capabilities: const [NodeCapability.mlxAudio],
            updatedAt: DateTime.utc(2026, 3, 15, 12, counterSlot),
          ),
        ),
      _GeneratedPriorityMessageKind.configFlag => SyncMessage.configFlag(
        name: 'generated-flag-$counterSlot',
        description: 'Generated flag',
        status: statusIsUpdate,
      ),
    };
  }

  int get expectedPriority {
    return switch (kind) {
      _GeneratedPriorityMessageKind.journalEntity ||
      _GeneratedPriorityMessageKind.entryLink => OutboxPriority.high.index,
      _GeneratedPriorityMessageKind.backfillRequest ||
      _GeneratedPriorityMessageKind.backfillResponse ||
      _GeneratedPriorityMessageKind.agentEntity ||
      _GeneratedPriorityMessageKind.agentLink ||
      _GeneratedPriorityMessageKind.agentBundle ||
      _GeneratedPriorityMessageKind.notification ||
      _GeneratedPriorityMessageKind.notificationStateUpdate ||
      _GeneratedPriorityMessageKind.themingSelection ||
      _GeneratedPriorityMessageKind.configFlag ||
      _GeneratedPriorityMessageKind.outboxBundle => OutboxPriority.normal.index,
      _GeneratedPriorityMessageKind.entityDefinition ||
      _GeneratedPriorityMessageKind.aiConfig ||
      _GeneratedPriorityMessageKind.aiConfigDelete ||
      _GeneratedPriorityMessageKind.syncNodeProfile => OutboxPriority.low.index,
    };
  }

  @override
  String toString() {
    return '_GeneratedPriorityScenario('
        'kind: $kind, '
        'statusIsUpdate: $statusIsUpdate, '
        'counterSlot: $counterSlot, '
        'deleted: $deleted'
        ')';
  }
}

extension _AnyGeneratedPriorityScenario on glados.Any {
  glados.Generator<_GeneratedPriorityMessageKind> get priorityMessageKind =>
      glados.AnyUtils(this).choose(_GeneratedPriorityMessageKind.values);

  glados.Generator<_GeneratedPriorityScenario> get priorityScenario =>
      glados.CombinableAny(this).combine4(
        priorityMessageKind,
        glados.BoolAny(this).bool,
        glados.IntAnys(this).intInRange(0, 5),
        glados.BoolAny(this).bool,
        (
          _GeneratedPriorityMessageKind kind,
          bool statusIsUpdate,
          int counterSlot,
          bool deleted,
        ) => _GeneratedPriorityScenario(
          kind: kind,
          statusIsUpdate: statusIsUpdate,
          counterSlot: counterSlot,
          deleted: deleted,
        ),
      );
}

void main() {
  group('priorityForMessage', () {
    glados.Glados(
      glados.any.priorityScenario,
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'priority classification is stable across message shapes and json round-trips',
      (scenario) {
        final message = scenario.message;
        final roundTrip = SyncMessage.fromJson(
          jsonDecode(jsonEncode(message)) as Map<String, dynamic>,
        );
        expect(priorityForMessage(message), scenario.expectedPriority);
        expect(priorityForMessage(roundTrip), scenario.expectedPriority);
      },
      tags: 'glados',
    );

    test(
      'maps SyncOutboxBundle to normal priority — bundles are never enqueued in production but the lookup stays total',
      () {
        expect(
          priorityForMessage(const SyncMessage.outboxBundle(children: [])),
          OutboxPriority.normal.index,
        );
      },
    );
  });

  final now = DateTime(2024, 3, 15, 12);

  group('resolveEnqueueDelay', () {
    test('negative requested delay clamps to zero when no gate is set', () {
      expect(
        resolveEnqueueDelay(
          requested: const Duration(seconds: -5),
          nextAllowedAt: null,
          now: now,
        ),
        Duration.zero,
      );
    });

    test('a gate in the past leaves the clamped request unchanged', () {
      expect(
        resolveEnqueueDelay(
          requested: const Duration(seconds: 5),
          nextAllowedAt: now.subtract(const Duration(seconds: 1)),
          now: now,
        ),
        const Duration(seconds: 5),
      );
    });

    test('a future gate stretches a smaller request to reach it', () {
      expect(
        resolveEnqueueDelay(
          requested: const Duration(seconds: 1),
          nextAllowedAt: now.add(const Duration(seconds: 10)),
          now: now,
        ),
        const Duration(seconds: 10),
      );
    });

    test('a nearer future gate keeps the larger request', () {
      expect(
        resolveEnqueueDelay(
          requested: const Duration(seconds: 5),
          nextAllowedAt: now.add(const Duration(seconds: 2)),
          now: now,
        ),
        const Duration(seconds: 5),
      );
    });
  });

  group('extendBackoffGate', () {
    test('a non-positive delay leaves the gate unchanged', () {
      expect(
        extendBackoffGate(delay: Duration.zero, current: null, now: now),
        isNull,
      );
      final gate = now.add(const Duration(minutes: 5));
      expect(
        extendBackoffGate(
          delay: const Duration(seconds: -3),
          current: gate,
          now: now,
        ),
        gate,
      );
    });

    test('advances the gate from null to now + delay', () {
      expect(
        extendBackoffGate(
          delay: const Duration(minutes: 1),
          current: null,
          now: now,
        ),
        now.add(const Duration(minutes: 1)),
      );
    });

    test(
      'is monotonic: a later existing gate wins over a nearer candidate',
      () {
        final later = now.add(const Duration(minutes: 30));
        expect(
          extendBackoffGate(
            delay: const Duration(minutes: 1),
            current: later,
            now: now,
          ),
          later,
        );
      },
    );

    test('advances when the candidate is later than the current gate', () {
      final earlier = now.add(const Duration(minutes: 1));
      expect(
        extendBackoffGate(
          delay: const Duration(minutes: 30),
          current: earlier,
          now: now,
        ),
        now.add(const Duration(minutes: 30)),
      );
    });
  });
}
