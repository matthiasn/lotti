import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/agent_runtime_registry.dart';
import 'package:lotti/features/agents/state/agent_wiring.dart';
import 'package:lotti/features/agents/wake/project_update_slots.dart';
import 'package:lotti/features/agents/wake/wake_audit.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/agents/workflow/wake_result.dart';
import 'package:lotti/providers/agent_repository_providers.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/providers/update_notifications_providers.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../helpers/service_overrides.dart';
import '../../../mocks/mocks.dart';
import '../test_data/entity_factories.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  group('wireWakeExecutor — event agent branch', () {
    late MockAgentService agentService;
    late MockEventAgentWorkflow eventWorkflow;
    late MockTaskAgentWorkflow taskWorkflow;
    late MockAgentTemplateService templateService;
    late MockWakeOrchestrator orchestrator;
    late MockUpdateNotifications notifications;
    late ProviderContainer container;
    late Map<String, AgentWakeRunner> contributedRunners;
    late List<String> gateCalls;
    late Set<String> retiredByGate;
    late MockDomainLogger logger;
    late MockAgentRepository agentRepository;

    setUp(() {
      agentService = MockAgentService();
      eventWorkflow = MockEventAgentWorkflow();
      taskWorkflow = MockTaskAgentWorkflow();
      templateService = MockAgentTemplateService();
      orchestrator = MockWakeOrchestrator();
      notifications = MockUpdateNotifications();
      contributedRunners = {};
      gateCalls = [];
      retiredByGate = {};
      logger = MockDomainLogger();
      agentRepository = MockAgentRepository();
      when(
        () => agentRepository.getLinksFrom(any(), type: any(named: 'type')),
      ).thenAnswer((_) async => []);

      // The orchestrator stores whatever executor is wired into a real field.
      WakeExecutor? wired;
      when(() => orchestrator.wakeExecutor).thenReturn(wired);
      when(() => orchestrator.wakeExecutor = any()).thenAnswer((invocation) {
        wired = invocation.positionalArguments.first as WakeExecutor?;
        when(() => orchestrator.wakeExecutor).thenReturn(wired);
        return null;
      });

      // No template assigned → _notifyWakeCompletion resolves templateId=null.
      when(
        () => templateService.getTemplateForAgent(any()),
      ).thenAnswer((_) async => null);
      when(() => notifications.notifyUiOnly(any())).thenReturn(null);

      container = ProviderContainer(
        overrides: withServiceOverrides([
          agentServiceProvider.overrideWithValue(agentService),
          eventAgentWorkflowProvider.overrideWithValue(eventWorkflow),
          agentTemplateServiceProvider.overrideWithValue(templateService),
          agentWakeRunnersProvider.overrideWithValue(contributedRunners),
          domainLoggerProvider.overrideWithValue(logger),
          agentRepositoryProvider.overrideWithValue(agentRepository),
        ]),
      );
      addTearDown(container.dispose);
    });

    /// Wires the executor and returns the callback the orchestrator captured.
    WakeExecutor wire() {
      wireWakeExecutor(
        container.read(Provider((ref) => ref)),
        orchestrator,
        taskWorkflow,
        notifications,
        retireIfSuperseded: (agentId) async {
          gateCalls.add(agentId);
          return retiredByGate.contains(agentId);
        },
      );
      return orchestrator.wakeExecutor!;
    }

    void stubEventAgent() {
      when(() => agentService.getAgent('event-agent-1')).thenAnswer(
        (_) async => makeTestIdentity(
          id: 'event-agent-1',
          agentId: 'event-agent-1',
          kind: AgentKinds.eventAgent,
        ),
      );
    }

    test(
      'routes an event_agent identity to the event workflow and propagates '
      'its mutated entries',
      () async {
        stubEventAgent();
        const clock = VectorClock({'host-a': 3});
        when(
          () => eventWorkflow.execute(
            agentIdentity: any(named: 'agentIdentity'),
            runKey: any(named: 'runKey'),
            triggerTokens: any(named: 'triggerTokens'),
            threadId: any(named: 'threadId'),
          ),
        ).thenAnswer(
          (_) async => const WakeResult(
            success: true,
            mutatedEntries: {'event-9': clock},
          ),
        );

        final executor = wire();
        final mutated = await executor(
          'event-agent-1',
          'run-key-1',
          {'trigger-event-9'},
          'thread-1',
        );

        // The event workflow received the resolved identity and the wake args.
        final captured = verify(
          () => eventWorkflow.execute(
            agentIdentity: captureAny(named: 'agentIdentity'),
            runKey: captureAny(named: 'runKey'),
            triggerTokens: captureAny(named: 'triggerTokens'),
            threadId: captureAny(named: 'threadId'),
          ),
        ).captured;
        expect((captured[0] as dynamic).id, 'event-agent-1');
        expect(captured[1], 'run-key-1');
        expect(captured[2], {'trigger-event-9'});
        expect(captured[3], 'thread-1');

        // Mutated entries from the workflow are propagated back unchanged.
        expect(mutated, {'event-9': clock});

        // The task workflow must not be involved for an event agent.
        verifyNever(
          () => taskWorkflow.execute(
            agentIdentity: any(named: 'agentIdentity'),
            runKey: any(named: 'runKey'),
            triggerTokens: any(named: 'triggerTokens'),
            threadId: any(named: 'threadId'),
          ),
        );
      },
    );

    test(
      'notifies the UI with the agent id, agent token and trigger tokens '
      'after a successful event wake',
      () async {
        stubEventAgent();
        when(
          () => eventWorkflow.execute(
            agentIdentity: any(named: 'agentIdentity'),
            runKey: any(named: 'runKey'),
            triggerTokens: any(named: 'triggerTokens'),
            threadId: any(named: 'threadId'),
          ),
        ).thenAnswer((_) async => const WakeResult(success: true));

        final executor = wire();
        await executor(
          'event-agent-1',
          'run-key-1',
          {'event-9', 'task-3'},
          'thread-1',
        );

        // extraTokens: triggers — the event branch fans the trigger tokens out
        // so linked detail providers self-invalidate.
        verify(
          () => notifications.notifyUiOnly({
            'event-agent-1',
            agentNotification,
            'event-9',
            'task-3',
          }),
        ).called(1);
      },
    );

    test(
      'throws a WakeFailedException naming the kind and the workflow error '
      'when the event wake fails',
      () async {
        stubEventAgent();
        when(
          () => eventWorkflow.execute(
            agentIdentity: any(named: 'agentIdentity'),
            runKey: any(named: 'runKey'),
            triggerTokens: any(named: 'triggerTokens'),
            threadId: any(named: 'threadId'),
          ),
        ).thenAnswer(
          (_) async => const WakeResult(
            success: false,
            error: 'No active event ID',
          ),
        );

        final executor = wire();

        await expectLater(
          () => executor('event-agent-1', 'run-key-1', const {}, 'thread-1'),
          throwsA(
            isA<WakeFailedException>()
                .having((e) => e.kind, 'kind', 'event')
                .having((e) => e.reason, 'reason', 'No active event ID'),
          ),
        );

        // A failed wake must not emit a completion notification.
        verifyNever(() => notifications.notifyUiOnly(any()));
      },
    );

    group('task agent wake gate (ADR 0104)', () {
      void stubTaskAgent() {
        when(() => agentService.getAgent('task-agent-1')).thenAnswer(
          (_) async => makeTestIdentity(
            id: 'task-agent-1',
            agentId: 'task-agent-1',
          ),
        );
        when(
          () => taskWorkflow.execute(
            agentIdentity: any(named: 'agentIdentity'),
            runKey: any(named: 'runKey'),
            triggerTokens: any(named: 'triggerTokens'),
            threadId: any(named: 'threadId'),
          ),
        ).thenAnswer((_) async => const WakeResult(success: true));
      }

      test('a task agent the gate retires does not run and announces '
          'nothing', () async {
        stubTaskAgent();
        retiredByGate.add('task-agent-1');

        final result = await wire()(
          'task-agent-1',
          'run-key',
          const {'task-1'},
          'thread',
        );

        expect(result, isNull);
        expect(gateCalls, ['task-agent-1']);
        verifyNever(
          () => taskWorkflow.execute(
            agentIdentity: any(named: 'agentIdentity'),
            runKey: any(named: 'runKey'),
            triggerTokens: any(named: 'triggerTokens'),
            threadId: any(named: 'threadId'),
          ),
        );
        verifyNever(() => notifications.notifyUiOnly(any()));
      });

      test('the task agent the gate keeps runs the task workflow', () async {
        stubTaskAgent();

        await wire()('task-agent-1', 'run-key', const {'task-1'}, 'thread');

        expect(gateCalls, ['task-agent-1']);
        verify(
          () => taskWorkflow.execute(
            agentIdentity: any(named: 'agentIdentity'),
            runKey: 'run-key',
            triggerTokens: {'task-1'},
            threadId: 'thread',
          ),
        ).called(1);
      });

      test('a failed token lookup after a task wake is logged with its '
          'stack trace, and the wake still announces itself', () async {
        stubTaskAgent();
        when(
          () => agentRepository.getLinksFrom(any(), type: any(named: 'type')),
        ).thenThrow(StateError('agent db closed'));

        await wire()('task-agent-1', 'run-key', const {'task-1'}, 'thread');

        verify(
          () => logger.error(
            LogDomain.agentRuntime,
            any<Object>(that: isA<StateError>()),
            stackTrace: any(named: 'stackTrace', that: isNotNull),
            subDomain: 'agentInitialization',
            message: 'Failed to resolve task/project wake notification tokens',
          ),
        ).called(1);
        verify(
          () => notifications.notifyUiOnly({'task-agent-1', agentNotification}),
        ).called(1);
      });

      test('a failed template lookup after a task wake is logged with its '
          'stack trace, and the wake still announces itself', () async {
        stubTaskAgent();
        when(
          () => templateService.getTemplateForAgent(any()),
        ).thenThrow(StateError('template db closed'));

        await wire()('task-agent-1', 'run-key', const {'task-1'}, 'thread');

        verify(
          () => logger.error(
            LogDomain.agentRuntime,
            any<Object>(that: isA<StateError>()),
            stackTrace: any(named: 'stackTrace', that: isNotNull),
            subDomain: 'agentInitialization',
            message: 'Failed to resolve template for wake notification',
          ),
        ).called(1);
        verify(
          () => notifications.notifyUiOnly({'task-agent-1', agentNotification}),
        ).called(1);
      });

      test('other kinds never consult the gate', () async {
        stubEventAgent();
        when(
          () => eventWorkflow.execute(
            agentIdentity: any(named: 'agentIdentity'),
            runKey: any(named: 'runKey'),
            triggerTokens: any(named: 'triggerTokens'),
            threadId: any(named: 'threadId'),
          ),
        ).thenAnswer((_) async => const WakeResult(success: true));

        await wire()('event-agent-1', 'run-key', const {}, 'thread');

        expect(gateCalls, isEmpty);
      });
    });

    test('does nothing when the agent cannot be resolved', () async {
      when(
        () => agentService.getAgent('missing'),
      ).thenAnswer((_) async => null);

      final executor = wire();
      final result = await executor('missing', 'run-key', const {}, 'thread');

      expect(result, isNull);
      verifyNever(
        () => eventWorkflow.execute(
          agentIdentity: any(named: 'agentIdentity'),
          runKey: any(named: 'runKey'),
          triggerTokens: any(named: 'triggerTokens'),
          threadId: any(named: 'threadId'),
        ),
      );
    });

    test(
      'goal runner preserves whether the standing report was updated',
      () async {
        when(() => agentService.getAgent('goal-1')).thenAnswer(
          (_) async => makeTestIdentity(
            id: 'goal-1',
            agentId: 'goal-1',
            kind: AgentKinds.goalAgent,
          ),
        );
        contributedRunners[AgentKinds.goalAgent] =
            ({
              required agentIdentity,
              required runKey,
              required triggerTokens,
              required threadId,
            }) async => const WakeResult(
              success: true,
              mutatedEntries: {
                'progress-1': VectorClock({'host-a': 1}),
              },
            );

        final result = await wire()(
          'goal-1',
          'run-key',
          const {},
          'thread',
        );

        expect(result, {
          'progress-1': const VectorClock({'host-a': 1}),
        });
        expect(result, isA<WakeExecutorResult>());
        expect((result! as WakeExecutorResult).reportUpdated, isFalse);
      },
    );

    test(
      'relationship runner preserves whether the standing report was updated',
      () async {
        when(() => agentService.getAgent('rel-agent-1')).thenAnswer(
          (_) async => makeTestIdentity(
            id: 'rel-agent-1',
            agentId: 'rel-agent-1',
            kind: AgentKinds.relationshipAgent,
          ),
        );
        contributedRunners[AgentKinds.relationshipAgent] =
            ({
              required agentIdentity,
              required runKey,
              required triggerTokens,
              required threadId,
            }) async => const WakeResult(
              success: true,
              mutatedEntries: {
                'report-1': VectorClock({'host-a': 2}),
              },
              reportUpdated: true,
            );

        final result = await wire()(
          'rel-agent-1',
          'run-key',
          const {},
          'thread',
        );

        expect(result, {
          'report-1': const VectorClock({'host-a': 2}),
        });
        expect(result, isA<WakeExecutorResult>());
        expect((result! as WakeExecutorResult).reportUpdated, isTrue);
      },
    );
  });

  group('wireProjectSlotRefusals', () {
    late StreamController<WakeRunCompletion> completions;
    late MockWakeOrchestrator orchestrator;
    late MockProjectUpdateCadence cadence;
    late MockScheduledWakeManager manager;
    late MockUpdateNotifications notifications;
    late MockDomainLogger logger;
    late ProviderContainer container;

    final slot =
        AgentDomainEntity.scheduledWake(
              id: 'slot-next',
              agentId: 'project-agent',
              scheduledAt: DateTime.utc(2026, 10, 3),
              status: ScheduledWakeStatus.pending,
              reason: 'scheduled',
              updatedAt: DateTime(2026, 10, 2),
              vectorClock: null,
            )
            as ScheduledWakeEntity;

    WakeRunCompletion completion({
      Object? error,
      Set<String> tokens = const {ProjectUpdateSlots.triggerToken},
    }) => WakeRunCompletion(
      runKey: 'run-1',
      agentId: 'project-agent',
      status: error == null ? WakeRunStatus.completed : WakeRunStatus.aborted,
      triggerTokens: tokens,
      error: error,
    );

    setUp(() {
      completions = StreamController<WakeRunCompletion>.broadcast();
      addTearDown(completions.close);
      orchestrator = MockWakeOrchestrator();
      when(
        () => orchestrator.runCompletions,
      ).thenAnswer((_) => completions.stream);
      cadence = MockProjectUpdateCadence();
      manager = MockScheduledWakeManager();
      when(manager.requestCheck).thenReturn(null);
      notifications = MockUpdateNotifications();
      when(() => notifications.notifyUiOnly(any())).thenReturn(null);
      logger = MockDomainLogger();
      container = ProviderContainer(
        overrides: withServiceOverrides([
          domainLoggerProvider.overrideWithValue(logger),
          projectUpdateCadenceProvider.overrideWithValue(cadence),
          scheduledWakeManagerProvider.overrideWithValue(manager),
          updateNotificationsProvider.overrideWithValue(notifications),
        ]),
      );
      addTearDown(container.dispose);
      wireProjectSlotRefusals(
        container.read(Provider((ref) => ref)),
        orchestrator,
      );
    });

    test(
      'a refused slot wake re-arms with its cause and announces the slot',
      () async {
        when(
          () => cadence.rearmAfterRefusal(
            'project-agent',
            WakeDecisionCause.budgetExhausted,
          ),
        ).thenAnswer((_) async => slot);

        completions.add(
          completion(
            error: const WakeRefusedError(WakeDecisionCause.budgetExhausted),
          ),
        );
        await pumpEventQueue();

        verify(
          () => cadence.rearmAfterRefusal(
            'project-agent',
            WakeDecisionCause.budgetExhausted,
          ),
        ).called(1);
        verify(manager.requestCheck).called(1);
        verify(
          () =>
              notifications.notifyUiOnly({'project-agent', agentNotification}),
        ).called(1);
      },
    );

    test('a finished slot, or a refused wake that was not a slot, re-arms '
        'nothing', () async {
      completions
        ..add(completion())
        ..add(
          completion(
            error: const WakeRefusedError(WakeDecisionCause.notAnUpdateSlot),
            tokens: const {'PROJECT_ENTITY_UPDATE:p1'},
          ),
        )
        ..add(completion(error: StateError('model failed')));
      await pumpEventQueue();

      verifyNever(() => cadence.rearmAfterRefusal(any(), any()));
    });

    test('a re-arm that fails is contained, and nothing re-arms after '
        'dispose', () async {
      when(
        () => cadence.rearmAfterRefusal(any(), any()),
      ).thenAnswer((_) async => throw StateError('database locked'));

      completions.add(
        completion(
          error: const WakeRefusedError(WakeDecisionCause.budgetClaimFailed),
        ),
      );
      await pumpEventQueue();
      verifyNever(manager.requestCheck);
      verify(
        () => logger.error(
          LogDomain.agentRuntime,
          any<Object>(that: isA<StateError>()),
          stackTrace: any(named: 'stackTrace', that: isNotNull),
          subDomain: 'wireProjectSlotRefusals',
          message: 'failed to re-arm a refused project update slot',
        ),
      ).called(1);

      container.dispose();
      completions.add(
        completion(
          error: const WakeRefusedError(WakeDecisionCause.budgetClaimFailed),
        ),
      );
      await pumpEventQueue();
      verify(() => cadence.rearmAfterRefusal(any(), any())).called(1);
    });
  });
}
