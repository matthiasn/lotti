import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/agent_wiring.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/agents/workflow/wake_result.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
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

    setUp(() {
      agentService = MockAgentService();
      eventWorkflow = MockEventAgentWorkflow();
      taskWorkflow = MockTaskAgentWorkflow();
      templateService = MockAgentTemplateService();
      orchestrator = MockWakeOrchestrator();
      notifications = MockUpdateNotifications();

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
        overrides: [
          agentServiceProvider.overrideWithValue(agentService),
          eventAgentWorkflowProvider.overrideWithValue(eventWorkflow),
          agentTemplateServiceProvider.overrideWithValue(templateService),
        ],
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
      'throws a StateError carrying the workflow error when the event wake '
      'fails',
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
            isA<StateError>().having(
              (e) => e.message,
              'message',
              'No active event ID',
            ),
          ),
        );

        // A failed wake must not emit a completion notification.
        verifyNever(() => notifications.notifyUiOnly(any()));
      },
    );

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
  });
}
