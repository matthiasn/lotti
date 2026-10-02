import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/service/project_update_cadence.dart';
import 'package:lotti/features/agents/wake/project_update_slots.dart';

import '../../../helpers/fallbacks.dart';
import '../agent_test_device.dart';
import '../test_data/entity_factories.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  const agentId = 'project-agent-cadence';
  final now = DateTime(2026, 10, 2, 10, 25);

  AgentIdentityEntity identity({
    bool automatic = true,
    int? intervalMinutes,
    AgentLifecycle lifecycle = AgentLifecycle.active,
    String kind = AgentKinds.projectAgent,
  }) => makeTestIdentity(
    id: agentId,
    agentId: agentId,
    kind: kind,
    lifecycle: lifecycle,
    currentStateId: 'state-$agentId',
    config: AgentConfig(
      automaticUpdatesEnabled: automatic,
      updateIntervalMinutes: intervalMinutes,
    ),
  );

  AgentStateEntity state({DateTime? staleAt, DateTime? freshAt}) =>
      makeTestState(id: 'state-$agentId', agentId: agentId).copyWith(
        reportStaleAt: staleAt,
        reportFreshAt: freshAt,
      );

  Future<({AgentTestDevice device, ProjectUpdateCadence cadence})> setUpDevice(
    AgentIdentityEntity agent,
    AgentStateEntity agentState,
  ) async {
    final device = AgentTestDevice('host-a');
    addTearDown(device.close);
    await device.repository.upsertEntity(agent);
    await device.repository.upsertEntity(agentState);
    return (
      device: device,
      cadence: ProjectUpdateCadence(
        repository: device.repository,
        syncService: device.sync,
      ),
    );
  }

  final stale = state(staleAt: DateTime(2026, 10, 2, 10));

  group('arm', () {
    test('arms the next slot of a stale report and syncs it', () async {
      await withClock(Clock.fixed(now), () async {
        final setup = await setUpDevice(identity(), stale);

        final armed = await setup.cadence.arm(agentId);

        expect(armed, isNotNull);
        final slot = DateTime(2026, 10, 2, 11);
        expect(armed!.id, projectUpdateSlotRecordId(agentId, slot));
        expect(armed.scheduledAt, slot.toUtc());
        expect(armed.status, ScheduledWakeStatus.pending);
        expect(armed.reason, WakeReason.scheduled.name);
        expect(armed.triggerTokens, [ProjectUpdateSlots.triggerToken]);
        expect(isProjectUpdateWorkspace(armed.workspaceKey), isTrue);
        expect(
          setup.device.sentEntities.whereType<ScheduledWakeEntity>(),
          [armed],
        );
      });
    });

    test('keeps one pending slot however often it is asked', () async {
      await withClock(Clock.fixed(now), () async {
        final setup = await setUpDevice(identity(), stale);

        final first = await setup.cadence.arm(agentId);
        final second = await withClock(
          Clock.fixed(now.add(const Duration(hours: 2))),
          () => setup.cadence.arm(agentId),
        );

        expect(second, first);
        expect(await setup.cadence.pendingSlots(agentId), [first]);
      });
    });

    test('follows the agent interval', () async {
      await withClock(Clock.fixed(now), () async {
        final setup = await setUpDevice(identity(intervalMinutes: 480), stale);

        final armed = await setup.cadence.arm(agentId);

        expect(armed!.scheduledAt, DateTime(2026, 10, 2, 14).toUtc());
      });
    });

    test('skips a slot already consumed, rather than reviving it', () async {
      await withClock(Clock.fixed(now), () async {
        final setup = await setUpDevice(identity(), stale);
        final first = await setup.cadence.arm(agentId);
        await setup.cadence.consumeAll(agentId);

        final next = await setup.cadence.arm(agentId);

        expect(next!.scheduledAt, DateTime(2026, 10, 2, 12).toUtc());
        final consumed = await setup.device.repository.getEntity(first!.id);
        expect(
          (consumed! as ScheduledWakeEntity).status,
          ScheduledWakeStatus.consumed,
        );
      });
    });

    test('arms nothing for a fresh report, automation off, a paused agent '
        'or another kind', () async {
      await withClock(Clock.fixed(now), () async {
        final cases = <(AgentIdentityEntity, AgentStateEntity)>[
          (
            identity(),
            state(
              staleAt: DateTime(2026, 10, 2, 9),
              freshAt: DateTime(2026, 10, 2, 10),
            ),
          ),
          (identity(), state()),
          (identity(automatic: false), stale),
          (identity(lifecycle: AgentLifecycle.dormant), stale),
          (identity(kind: AgentKinds.taskAgent), stale),
        ];
        for (final (agent, agentState) in cases) {
          final setup = await setUpDevice(agent, agentState);
          expect(await setup.cadence.arm(agentId), isNull);
          expect(await setup.cadence.pendingSlots(agentId), isEmpty);
        }
      });
    });

    test('two devices arming the same change arm the same record', () async {
      await withClock(Clock.fixed(now), () async {
        final a = await setUpDevice(identity(), stale);
        final b = await setUpDevice(identity(), stale);

        final onA = await a.cadence.arm(agentId);
        final onB = await b.cadence.arm(agentId);
        await b.device.receiveEntity(onA!);

        expect(onA.id, onB!.id);
        expect(await b.cadence.pendingSlots(agentId), hasLength(1));
      });
    });
  });

  group('replan', () {
    test(
      'moves a pending slot to the new grid when the interval changes',
      () async {
        await withClock(Clock.fixed(now), () async {
          final setup = await setUpDevice(identity(), stale);
          final hourly = await setup.cadence.arm(agentId);
          expect(hourly!.scheduledAt, DateTime(2026, 10, 2, 11).toUtc());
          await setup.device.repository.upsertEntity(
            identity(intervalMinutes: 480),
          );

          final replanned = await setup.cadence.replan(agentId);

          expect(replanned!.scheduledAt, DateTime(2026, 10, 2, 14).toUtc());
          expect(await setup.cadence.pendingSlots(agentId), [replanned]);
          final old = await setup.device.repository.getEntity(hourly.id);
          expect(
            (old! as ScheduledWakeEntity).status,
            ScheduledWakeStatus.consumed,
          );
        });
      },
    );

    test('keeps a pending slot already at the grid\'s next start', () async {
      await withClock(Clock.fixed(now), () async {
        final setup = await setUpDevice(identity(), stale);
        final armed = await setup.cadence.arm(agentId);

        final replanned = await setup.cadence.replan(agentId);

        expect(replanned, armed);
        expect(await setup.cadence.pendingSlots(agentId), [armed]);
      });
    });

    test(
      'consumes the old slot and arms nothing once the report is fresh',
      () async {
        await withClock(Clock.fixed(now), () async {
          final setup = await setUpDevice(identity(), stale);
          await setup.cadence.arm(agentId);
          await setup.device.repository.upsertEntity(
            identity(intervalMinutes: 480),
          );
          await setup.device.repository.upsertEntity(
            state(
              staleAt: DateTime(2026, 10, 2, 10),
              freshAt: DateTime(2026, 10, 2, 10, 20),
            ),
          );

          expect(await setup.cadence.replan(agentId), isNull);
          expect(await setup.cadence.pendingSlots(agentId), isEmpty);
        });
      },
    );

    test('touches nothing for another kind of agent', () async {
      await withClock(Clock.fixed(now), () async {
        final setup = await setUpDevice(
          identity(kind: AgentKinds.taskAgent),
          stale,
        );

        expect(await setup.cadence.replan(agentId), isNull);
        expect(setup.device.sentEntities, isEmpty);
      });
    });
  });

  group('consumeAll', () {
    test('consumes every pending slot of the agent and only those', () async {
      await withClock(Clock.fixed(now), () async {
        final setup = await setUpDevice(identity(), stale);
        final mine = await setup.cadence.arm(agentId);
        // A second pending slot, as two devices arming different slots for
        // one change leave behind.
        final later = mine!.copyWith(
          id: projectUpdateSlotRecordId(agentId, DateTime(2026, 10, 2, 12)),
          scheduledAt: DateTime(2026, 10, 2, 12).toUtc(),
          workspaceKey: projectUpdateWorkspaceKey(DateTime(2026, 10, 2, 12)),
        );
        final otherAgent = mine.copyWith(
          id: 'scheduled_wake:other:project_update:x',
          agentId: 'other',
        );
        await setup.device.repository.upsertEntity(later);
        await setup.device.repository.upsertEntity(otherAgent);

        expect(await setup.cadence.consumeAll(agentId), 2);

        expect(await setup.cadence.pendingSlots(agentId), isEmpty);
        expect(await setup.cadence.pendingSlots('other'), [otherAgent]);
      });
    });
  });
}
