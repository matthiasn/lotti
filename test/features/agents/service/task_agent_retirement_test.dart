import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/service/agent_service.dart';
import 'package:lotti/features/agents/service/task_agent_retirement.dart';
import 'package:lotti/features/agents/service/task_agent_service.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../agent_test_device.dart';
import '../sync/agent_replica_bench.dart';
import '../test_utils.dart';

part 'task_agent_retirement_model_conformance.dart';

const _taskId = 'task-1';
final _t0 = DateTime(2026, 9, 27, 9);

/// A mock orchestrator that accepts every call the task-agent services make.
MockWakeOrchestrator _permissiveOrchestrator() {
  final orchestrator = MockWakeOrchestrator();
  when(() => orchestrator.addSubscription(any())).thenReturn(null);
  when(() => orchestrator.removeSubscriptions(any())).thenReturn(null);
  when(
    () => orchestrator.enableAutomaticUpdatesRuntime(any()),
  ).thenReturn(null);
  when(
    () => orchestrator.disableAutomaticUpdatesRuntime(any()),
  ).thenReturn(null);
  when(
    () => orchestrator.setAwaitingContent(
      any(),
      awaiting: any(named: 'awaiting'),
    ),
  ).thenReturn(null);
  when(
    () => orchestrator.enqueueManualWake(
      agentId: any(named: 'agentId'),
      reason: any(named: 'reason'),
      triggerTokens: any(named: 'triggerTokens'),
      workspaceKey: any(named: 'workspaceKey'),
      supersede: any(named: 'supersede'),
      initiator: any(named: 'initiator'),
    ),
  ).thenReturn('run-key');
  return orchestrator;
}

void main() {
  setUpAll(registerAllFallbackValues);

  late AgentTestDevice device;
  late MockWakeOrchestrator orchestrator;
  late MockUpdateNotifications notifications;
  late MockDomainLogger logger;
  late TaskAgentRetirement retirement;

  setUp(() {
    device = AgentTestDevice('host-a', background: false);
    addTearDown(device.close);
    orchestrator = _permissiveOrchestrator();
    notifications = MockUpdateNotifications();
    when(() => notifications.notifyUiOnly(any())).thenReturn(null);
    logger = MockDomainLogger();
    retirement = TaskAgentRetirement(
      repository: device.repository,
      syncService: device.sync,
      orchestrator: orchestrator,
      updateNotifications: notifications,
      domainLogger: logger,
    );
  });

  /// Writes a task agent the way `createTaskAgent` leaves it: the identity
  /// and its `agent_task` link, the link created at [linkedAt].
  Future<void> seedAgent(
    String agentId, {
    required DateTime linkedAt,
    String taskId = _taskId,
    AgentLifecycle lifecycle = AgentLifecycle.active,
    bool withIdentity = true,
  }) async {
    if (withIdentity) {
      await device.repository.upsertEntity(
        makeTestIdentity(
          id: agentId,
          agentId: agentId,
          lifecycle: lifecycle,
          createdAt: linkedAt,
          updatedAt: linkedAt,
        ),
      );
    }
    await device.repository.upsertLink(
      AgentLink.agentTask(
        id: 'link-$agentId-$taskId',
        fromId: agentId,
        toId: taskId,
        createdAt: linkedAt,
        updatedAt: linkedAt,
        vectorClock: null,
      ),
    );
  }

  Future<AgentLifecycle?> lifecycleOf(String agentId) async {
    final entity = await device.repository.getEntity(agentId);
    return (entity as AgentIdentityEntity?)?.lifecycle;
  }

  group('retireSuperseded', () {
    test('keeps the agent of the newest link and destroys the other, as a '
        'synced write', () async {
      await seedAgent('agent-old', linkedAt: _t0);
      await seedAgent(
        'agent-new',
        linkedAt: _t0.add(const Duration(seconds: 1)),
      );
      final at = _t0.add(const Duration(hours: 1));

      final retired = await withClock(
        Clock.fixed(at),
        () => retirement.retireSuperseded(_taskId),
      );

      expect(retired, {'agent-old'});
      final loser =
          (await device.repository.getEntity('agent-old'))!
              as AgentIdentityEntity;
      expect(loser.lifecycle, AgentLifecycle.destroyed);
      expect(loser.destroyedAt, at);
      expect(loser.updatedAt, at);
      expect(await lifecycleOf('agent-new'), AgentLifecycle.active);
      // The retirement syncs: every other device learns it once.
      final sent = device.sentEntities.whereType<AgentIdentityEntity>();
      expect(
        sent.map((e) => (e.agentId, e.lifecycle)),
        [('agent-old', AgentLifecycle.destroyed)],
      );
      verify(() => orchestrator.removeSubscriptions('agent-old')).called(1);
      verifyNever(() => orchestrator.removeSubscriptions('agent-new'));
      verify(
        () => notifications.notifyUiOnly({
          'agent-old',
          _taskId,
          agentNotification,
        }),
      ).called(1);
    });

    test('keeps the agent the task card shows: a createdAt tie goes to the '
        'larger link id, as selectPrimary breaks it', () async {
      await seedAgent('agent-a', linkedAt: _t0);
      await seedAgent('agent-b', linkedAt: _t0);
      final links = await device.repository.getLinksTo(
        _taskId,
        type: AgentLinkTypes.agentTask,
      );

      final retired = await retirement.retireSuperseded(_taskId);

      expect(links.selectPrimary().fromId, 'agent-b');
      expect(retired, {'agent-a'});
      expect(await lifecycleOf('agent-b'), AgentLifecycle.active);
    });

    test('retires every live agent below the first, a paused one included, '
        'and leaves an already destroyed one unwritten', () async {
      await seedAgent('agent-1', linkedAt: _t0);
      await seedAgent(
        'agent-2',
        linkedAt: _t0.add(const Duration(seconds: 1)),
        lifecycle: AgentLifecycle.dormant,
      );
      await seedAgent(
        'agent-3',
        linkedAt: _t0.add(const Duration(seconds: 2)),
        lifecycle: AgentLifecycle.destroyed,
      );
      await seedAgent('agent-4', linkedAt: _t0.add(const Duration(seconds: 3)));

      final retired = await retirement.retireSuperseded(_taskId);

      expect(retired, {'agent-1', 'agent-2'});
      expect(await lifecycleOf('agent-4'), AgentLifecycle.active);
      expect(
        device.sentEntities.map((e) => e.agentId).toSet(),
        {'agent-1', 'agent-2'},
      );
    });

    test(
      'a destroyed first-ranked agent still retires the live ones below '
      'it: the card shows the destroyed agent, so nothing works unseen',
      () async {
        await seedAgent('agent-live', linkedAt: _t0);
        await seedAgent(
          'agent-destroyed',
          linkedAt: _t0.add(const Duration(seconds: 1)),
          lifecycle: AgentLifecycle.destroyed,
        );

        final retired = await retirement.retireSuperseded(_taskId);

        expect(retired, {'agent-live'});
        expect(await lifecycleOf('agent-live'), AgentLifecycle.destroyed);
      },
    );

    test('a link whose identity has not arrived does not rank until it '
        'does', () async {
      await seedAgent('agent-here', linkedAt: _t0);
      await seedAgent(
        'agent-coming',
        linkedAt: _t0.add(const Duration(seconds: 1)),
        withIdentity: false,
      );

      expect(await retirement.retireSuperseded(_taskId), isEmpty);
      expect(await lifecycleOf('agent-here'), AgentLifecycle.active);

      await device.repository.upsertEntity(
        makeTestIdentity(id: 'agent-coming', agentId: 'agent-coming'),
      );

      expect(await retirement.retireSuperseded(_taskId), {'agent-here'});
    });

    test('a removed link does not rank, and neither does another kind of '
        'agent', () async {
      await seedAgent('agent-kept', linkedAt: _t0);
      await device.repository.upsertLink(
        AgentLink.agentTask(
          id: 'link-removed',
          fromId: 'agent-removed',
          toId: _taskId,
          createdAt: _t0.add(const Duration(seconds: 1)),
          updatedAt: _t0.add(const Duration(seconds: 1)),
          deletedAt: _t0.add(const Duration(seconds: 1)),
          vectorClock: null,
        ),
      );
      await device.repository.upsertEntity(
        makeTestIdentity(id: 'agent-removed', agentId: 'agent-removed'),
      );
      await seedAgent(
        'agent-project',
        linkedAt: _t0.add(const Duration(days: 1)),
      );
      await device.repository.upsertEntity(
        makeTestIdentity(
          id: 'agent-project',
          agentId: 'agent-project',
          kind: AgentKinds.projectAgent,
        ),
      );

      expect(await retirement.retireSuperseded(_taskId), isEmpty);
      expect(await lifecycleOf('agent-kept'), AgentLifecycle.active);
      expect(device.sentEntities, isEmpty);
      verifyNever(() => notifications.notifyUiOnly(any()));
    });

    test('a single agent is left alone', () async {
      await seedAgent('agent-only', linkedAt: _t0);

      expect(await retirement.retireSuperseded(_taskId), isEmpty);
      expect(device.sentEntities, isEmpty);
      verifyNever(() => orchestrator.removeSubscriptions(any()));
    });

    test('a failed write rolls the whole pass back', () async {
      await seedAgent('agent-1', linkedAt: _t0);
      await seedAgent('agent-2', linkedAt: _t0.add(const Duration(seconds: 1)));
      await seedAgent('agent-3', linkedAt: _t0.add(const Duration(seconds: 2)));
      device.failClockFor = 'agent-2';

      await expectLater(
        retirement.retireSuperseded(_taskId),
        throwsStateError,
      );

      expect(await lifecycleOf('agent-1'), AgentLifecycle.active);
      expect(await lifecycleOf('agent-2'), AgentLifecycle.active);
      expect(device.sentEntities, isEmpty);
      verifyNever(() => orchestrator.removeSubscriptions(any()));
    });
  });

  group('retireIfSuperseded', () {
    test('retires and stops the loser, lets the task agent run', () async {
      await seedAgent('agent-loser', linkedAt: _t0);
      await seedAgent(
        'agent-winner',
        linkedAt: _t0.add(const Duration(seconds: 1)),
      );

      expect(await retirement.retireIfSuperseded('agent-winner'), isFalse);
      expect(await lifecycleOf('agent-loser'), AgentLifecycle.destroyed);
      expect(await retirement.retireIfSuperseded('agent-loser'), isFalse);

      await seedAgent(
        'agent-late',
        linkedAt: _t0.subtract(const Duration(days: 1)),
      );
      expect(await retirement.retireIfSuperseded('agent-late'), isTrue);
      expect(await lifecycleOf('agent-late'), AgentLifecycle.destroyed);
    });

    test('an agent without a task link runs', () async {
      await device.repository.upsertEntity(
        makeTestIdentity(id: 'agent-free', agentId: 'agent-free'),
      );

      expect(await retirement.retireIfSuperseded('agent-free'), isFalse);
    });
  });

  group('retireSupersededEverywhere', () {
    test('retires on every task with several agents, leaves the others and '
        'logs a task whose pass fails', () async {
      await seedAgent('a-old', linkedAt: _t0, taskId: 'task-a');
      await seedAgent(
        'a-new',
        linkedAt: _t0.add(const Duration(seconds: 1)),
        taskId: 'task-a',
      );
      await seedAgent('b-old', linkedAt: _t0, taskId: 'task-b');
      await seedAgent(
        'b-new',
        linkedAt: _t0.add(const Duration(seconds: 1)),
        taskId: 'task-b',
      );
      await seedAgent('c-only', linkedAt: _t0, taskId: 'task-c');
      device.failClockFor = 'a-old';

      await retirement.retireSupersededEverywhere();

      expect(await lifecycleOf('a-old'), AgentLifecycle.active);
      expect(await lifecycleOf('b-old'), AgentLifecycle.destroyed);
      expect(await lifecycleOf('b-new'), AgentLifecycle.active);
      expect(await lifecycleOf('c-only'), AgentLifecycle.active);
      verify(
        () => logger.error(
          LogDomain.agentRuntime,
          any<Object>(),
          message: any(named: 'message', that: contains('task-a')),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'lifecycle',
        ),
      ).called(1);
    });
  });

  _registerTaskAgentAssignmentConformance();
}
