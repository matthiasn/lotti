import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/agents/wake/wake_runner.dart';
import 'package:lotti/features/agents/workflow/task_agent_workflow.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../test_utils.dart';

void main() {
  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(const Stream<Set<String>>.empty());
  });

  late MockAgentService mockService;
  late MockAgentRepository mockRepository;

  setUp(() {
    mockService = MockAgentService();
    mockRepository = MockAgentRepository();
  });

  /// Helper to create a [ProviderContainer] with both mocks overridden.
  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        agentServiceProvider.overrideWithValue(mockService),
        agentRepositoryProvider.overrideWithValue(mockRepository),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('agentReportProvider', () {
    test('returns report entity when service finds one', () async {
      final report = makeTestReport();

      when(() => mockService.getAgentReport(kTestAgentId))
          .thenAnswer((_) async => report);

      final container = createContainer();
      final result =
          await container.read(agentReportProvider(kTestAgentId).future);

      expect(result, equals(report));
      verify(() => mockService.getAgentReport(kTestAgentId)).called(1);
    });

    test('returns null when service finds no report', () async {
      when(() => mockService.getAgentReport(kTestAgentId))
          .thenAnswer((_) async => null);

      final container = createContainer();
      final result =
          await container.read(agentReportProvider(kTestAgentId).future);

      expect(result, isNull);
      verify(() => mockService.getAgentReport(kTestAgentId)).called(1);
    });
  });

  group('agentStateProvider', () {
    test('returns state entity when repository finds one', () async {
      final state = makeTestState();

      when(() => mockRepository.getAgentState(kTestAgentId))
          .thenAnswer((_) async => state);

      final container = createContainer();
      final result =
          await container.read(agentStateProvider(kTestAgentId).future);

      expect(result, equals(state));
      verify(() => mockRepository.getAgentState(kTestAgentId)).called(1);
    });

    test('returns null when repository finds no state', () async {
      when(() => mockRepository.getAgentState(kTestAgentId))
          .thenAnswer((_) async => null);

      final container = createContainer();
      final result =
          await container.read(agentStateProvider(kTestAgentId).future);

      expect(result, isNull);
      verify(() => mockRepository.getAgentState(kTestAgentId)).called(1);
    });
  });

  group('agentIdentityProvider', () {
    test('returns identity entity when service finds one', () async {
      final identity = makeTestIdentity();

      when(() => mockService.getAgent(kTestAgentId))
          .thenAnswer((_) async => identity);

      final container = createContainer();
      final result =
          await container.read(agentIdentityProvider(kTestAgentId).future);

      expect(result, equals(identity));
      verify(() => mockService.getAgent(kTestAgentId)).called(1);
    });

    test('returns null when service finds no agent', () async {
      when(() => mockService.getAgent(kTestAgentId))
          .thenAnswer((_) async => null);

      final container = createContainer();
      final result =
          await container.read(agentIdentityProvider(kTestAgentId).future);

      expect(result, isNull);
      verify(() => mockService.getAgent(kTestAgentId)).called(1);
    });
  });

  group('agentRecentMessagesProvider', () {
    test('returns messages in DB order (newest-first)', () async {
      // The DB query sorts by created_at DESC, so the mock returns
      // them in that order already.
      final msg2 = makeTestMessage(
        id: 'msg-2',
        createdAt: DateTime(2024, 3, 15, 12),
      );
      final msg3 = makeTestMessage(
        id: 'msg-3',
        createdAt: DateTime(2024, 3, 15, 11),
      );
      final msg1 = makeTestMessage(
        id: 'msg-1',
        createdAt: DateTime(2024, 3, 15, 10),
      );

      when(
        () => mockRepository.getEntitiesByAgentId(
          kTestAgentId,
          type: 'agentMessage',
          limit: 50,
        ),
      ).thenAnswer((_) async => [msg2, msg3, msg1]);

      final container = createContainer();
      final result = await container
          .read(agentRecentMessagesProvider(kTestAgentId).future);

      expect(result, hasLength(3));
      expect((result[0] as AgentMessageEntity).id, 'msg-2');
      expect((result[1] as AgentMessageEntity).id, 'msg-3');
      expect((result[2] as AgentMessageEntity).id, 'msg-1');
    });

    test('passes limit=50 to repository', () async {
      when(
        () => mockRepository.getEntitiesByAgentId(
          kTestAgentId,
          type: 'agentMessage',
          limit: 50,
        ),
      ).thenAnswer((_) async => []);

      final container = createContainer();
      await container.read(agentRecentMessagesProvider(kTestAgentId).future);

      verify(
        () => mockRepository.getEntitiesByAgentId(
          kTestAgentId,
          type: 'agentMessage',
          limit: 50,
        ),
      ).called(1);
    });

    test('returns empty list when no messages exist', () async {
      when(
        () => mockRepository.getEntitiesByAgentId(
          kTestAgentId,
          type: 'agentMessage',
          limit: 50,
        ),
      ).thenAnswer((_) async => []);

      final container = createContainer();
      final result = await container
          .read(agentRecentMessagesProvider(kTestAgentId).future);

      expect(result, isEmpty);
    });

    test('filters out non-AgentMessageEntity types', () async {
      final msg = makeTestMessage(id: 'msg-1');
      final report = makeTestReport(id: 'report-1');
      final state = makeTestState(id: 'state-1');

      when(
        () => mockRepository.getEntitiesByAgentId(
          kTestAgentId,
          type: 'agentMessage',
          limit: 50,
        ),
      ).thenAnswer((_) async => [msg, report, state]);

      final container = createContainer();
      final result = await container
          .read(agentRecentMessagesProvider(kTestAgentId).future);

      expect(result, hasLength(1));
      expect((result[0] as AgentMessageEntity).id, 'msg-1');
    });
  });

  group('agentMessagePayloadTextProvider', () {
    test('returns text from payload content', () async {
      const payloadId = 'payload-1';
      final payloadEntity = AgentDomainEntity.agentMessagePayload(
        id: payloadId,
        agentId: kTestAgentId,
        createdAt: DateTime(2024, 3, 15),
        vectorClock: null,
        content: const {'text': 'hello world'},
      );

      when(() => mockRepository.getEntity(payloadId))
          .thenAnswer((_) async => payloadEntity);

      final container = createContainer();
      final result = await container
          .read(agentMessagePayloadTextProvider(payloadId).future);

      expect(result, 'hello world');
      verify(() => mockRepository.getEntity(payloadId)).called(1);
    });

    test('returns null when entity is not found', () async {
      const payloadId = 'nonexistent';

      when(() => mockRepository.getEntity(payloadId))
          .thenAnswer((_) async => null);

      final container = createContainer();
      final result = await container
          .read(agentMessagePayloadTextProvider(payloadId).future);

      expect(result, isNull);
    });

    test('returns null when entity is not a payload type', () async {
      const payloadId = 'not-a-payload';
      final identity = makeTestIdentity(id: payloadId);

      when(() => mockRepository.getEntity(payloadId))
          .thenAnswer((_) async => identity);

      final container = createContainer();
      final result = await container
          .read(agentMessagePayloadTextProvider(payloadId).future);

      expect(result, isNull);
    });

    test('returns null when payload text is empty', () async {
      const payloadId = 'payload-empty';
      final payloadEntity = AgentDomainEntity.agentMessagePayload(
        id: payloadId,
        agentId: kTestAgentId,
        createdAt: DateTime(2024, 3, 15),
        vectorClock: null,
        content: const {'text': ''},
      );

      when(() => mockRepository.getEntity(payloadId))
          .thenAnswer((_) async => payloadEntity);

      final container = createContainer();
      final result = await container
          .read(agentMessagePayloadTextProvider(payloadId).future);

      expect(result, isNull);
    });

    test('returns null when payload has no text key', () async {
      const payloadId = 'payload-no-text';
      final payloadEntity = AgentDomainEntity.agentMessagePayload(
        id: payloadId,
        agentId: kTestAgentId,
        createdAt: DateTime(2024, 3, 15),
        vectorClock: null,
        content: const {'other': 'data'},
      );

      when(() => mockRepository.getEntity(payloadId))
          .thenAnswer((_) async => payloadEntity);

      final container = createContainer();
      final result = await container
          .read(agentMessagePayloadTextProvider(payloadId).future);

      expect(result, isNull);
    });

    test('returns null when payload text is not a String', () async {
      const payloadId = 'payload-int-text';
      final payloadEntity = AgentDomainEntity.agentMessagePayload(
        id: payloadId,
        agentId: kTestAgentId,
        createdAt: DateTime(2024, 3, 15),
        vectorClock: null,
        content: const {'text': 42},
      );

      when(() => mockRepository.getEntity(payloadId))
          .thenAnswer((_) async => payloadEntity);

      final container = createContainer();
      final result = await container
          .read(agentMessagePayloadTextProvider(payloadId).future);

      expect(result, isNull);
    });
  });

  group('agentMessagesByThreadProvider', () {
    test('groups messages by threadId', () async {
      final msg1 = makeTestMessage(
        id: 'msg-1',
        threadId: 'thread-a',
        createdAt: DateTime(2024, 3, 15, 10),
      );
      final msg2 = makeTestMessage(
        id: 'msg-2',
        threadId: 'thread-b',
        createdAt: DateTime(2024, 3, 15, 11),
      );
      final msg3 = makeTestMessage(
        id: 'msg-3',
        threadId: 'thread-a',
        createdAt: DateTime(2024, 3, 15, 12),
      );

      when(
        () => mockRepository.getEntitiesByAgentId(
          kTestAgentId,
          type: 'agentMessage',
          limit: 200,
        ),
      ).thenAnswer((_) async => [msg1, msg2, msg3]);

      final container = createContainer();
      final result = await container
          .read(agentMessagesByThreadProvider(kTestAgentId).future);

      expect(result, hasLength(2));
      expect(result['thread-a'], hasLength(2));
      expect(result['thread-b'], hasLength(1));
    });

    test('sorts messages within each thread chronologically', () async {
      final msg1 = makeTestMessage(
        id: 'msg-1',
        threadId: 'thread-a',
        createdAt: DateTime(2024, 3, 15, 12),
      );
      final msg2 = makeTestMessage(
        id: 'msg-2',
        threadId: 'thread-a',
        createdAt: DateTime(2024, 3, 15, 10),
      );
      final msg3 = makeTestMessage(
        id: 'msg-3',
        threadId: 'thread-a',
        createdAt: DateTime(2024, 3, 15, 11),
      );

      when(
        () => mockRepository.getEntitiesByAgentId(
          kTestAgentId,
          type: 'agentMessage',
          limit: 200,
        ),
      ).thenAnswer((_) async => [msg1, msg2, msg3]);

      final container = createContainer();
      final result = await container
          .read(agentMessagesByThreadProvider(kTestAgentId).future);

      final thread = result['thread-a']!;
      expect((thread[0] as AgentMessageEntity).id, 'msg-2');
      expect((thread[1] as AgentMessageEntity).id, 'msg-3');
      expect((thread[2] as AgentMessageEntity).id, 'msg-1');
    });

    test('returns empty map when no messages exist', () async {
      when(
        () => mockRepository.getEntitiesByAgentId(
          kTestAgentId,
          type: 'agentMessage',
          limit: 200,
        ),
      ).thenAnswer((_) async => []);

      final container = createContainer();
      final result = await container
          .read(agentMessagesByThreadProvider(kTestAgentId).future);

      expect(result, isEmpty);
    });

    test('filters out non-AgentMessageEntity types', () async {
      final msg = makeTestMessage(id: 'msg-1', threadId: 'thread-a');
      final report = makeTestReport(id: 'report-1');

      when(
        () => mockRepository.getEntitiesByAgentId(
          kTestAgentId,
          type: 'agentMessage',
          limit: 200,
        ),
      ).thenAnswer((_) async => [msg, report]);

      final container = createContainer();
      final result = await container
          .read(agentMessagesByThreadProvider(kTestAgentId).future);

      expect(result, hasLength(1));
      expect(result['thread-a'], hasLength(1));
    });

    test('passes limit=200 to repository', () async {
      when(
        () => mockRepository.getEntitiesByAgentId(
          kTestAgentId,
          type: 'agentMessage',
          limit: 200,
        ),
      ).thenAnswer((_) async => []);

      final container = createContainer();
      await container.read(agentMessagesByThreadProvider(kTestAgentId).future);

      verify(
        () => mockRepository.getEntitiesByAgentId(
          kTestAgentId,
          type: 'agentMessage',
          limit: 200,
        ),
      ).called(1);
    });
  });

  group('agentObservationMessagesProvider', () {
    test('returns only observation messages', () async {
      final obs = makeTestMessage(
        id: 'obs-1',
        kind: AgentMessageKind.observation,
        createdAt: DateTime(2024, 3, 15, 10),
      );
      final thought = makeTestMessage(
        id: 'thought-1',
        createdAt: DateTime(2024, 3, 15, 11),
      );
      final action = makeTestMessage(
        id: 'action-1',
        kind: AgentMessageKind.action,
        createdAt: DateTime(2024, 3, 15, 12),
      );
      final obs2 = makeTestMessage(
        id: 'obs-2',
        kind: AgentMessageKind.observation,
        createdAt: DateTime(2024, 3, 15, 13),
      );

      when(
        () => mockRepository.getEntitiesByAgentId(
          kTestAgentId,
          type: 'agentMessage',
          limit: 200,
        ),
      ).thenAnswer((_) async => [obs, thought, action, obs2]);

      final container = createContainer();
      final result = await container
          .read(agentObservationMessagesProvider(kTestAgentId).future);

      expect(result, hasLength(2));
      expect((result[0] as AgentMessageEntity).id, 'obs-1');
      expect((result[1] as AgentMessageEntity).id, 'obs-2');
    });

    test('returns empty list when no observations exist', () async {
      final thought = makeTestMessage(
        id: 'thought-1',
        createdAt: DateTime(2024, 3, 15, 10),
      );

      when(
        () => mockRepository.getEntitiesByAgentId(
          kTestAgentId,
          type: 'agentMessage',
          limit: 200,
        ),
      ).thenAnswer((_) async => [thought]);

      final container = createContainer();
      final result = await container
          .read(agentObservationMessagesProvider(kTestAgentId).future);

      expect(result, isEmpty);
    });

    test('returns empty list when no messages exist at all', () async {
      when(
        () => mockRepository.getEntitiesByAgentId(
          kTestAgentId,
          type: 'agentMessage',
          limit: 200,
        ),
      ).thenAnswer((_) async => []);

      final container = createContainer();
      final result = await container
          .read(agentObservationMessagesProvider(kTestAgentId).future);

      expect(result, isEmpty);
    });

    test('filters out non-AgentMessageEntity types', () async {
      final obs = makeTestMessage(
        id: 'obs-1',
        kind: AgentMessageKind.observation,
      );
      final report = makeTestReport(id: 'report-1');

      when(
        () => mockRepository.getEntitiesByAgentId(
          kTestAgentId,
          type: 'agentMessage',
          limit: 200,
        ),
      ).thenAnswer((_) async => [obs, report]);

      final container = createContainer();
      final result = await container
          .read(agentObservationMessagesProvider(kTestAgentId).future);

      expect(result, hasLength(1));
      expect((result[0] as AgentMessageEntity).id, 'obs-1');
    });
  });

  group('agentIsRunningProvider', () {
    test('yields initial false when agent is not running', () async {
      final runner = WakeRunner();
      addTearDown(runner.dispose);

      final container = ProviderContainer(
        overrides: [
          wakeRunnerProvider.overrideWithValue(runner),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(
        agentIsRunningProvider(kTestAgentId),
        (_, __) {},
      );
      addTearDown(sub.close);

      // Let the stream provider initialize.
      await Future<void>.delayed(Duration.zero);

      final value = container.read(agentIsRunningProvider(kTestAgentId));
      expect(value.value, isFalse);
    });

    test('yields true after agent acquires lock', () async {
      final runner = WakeRunner();
      addTearDown(runner.dispose);

      final container = ProviderContainer(
        overrides: [
          wakeRunnerProvider.overrideWithValue(runner),
        ],
      );
      addTearDown(container.dispose);

      final values = <bool>[];
      final sub = container.listen(
        agentIsRunningProvider(kTestAgentId),
        (_, next) {
          if (next.hasValue) values.add(next.value!);
        },
      );
      addTearDown(sub.close);

      await Future<void>.delayed(Duration.zero);

      await runner.tryAcquire(kTestAgentId);
      await Future<void>.delayed(Duration.zero);

      final value = container.read(agentIsRunningProvider(kTestAgentId));
      expect(value.value, isTrue);
    });

    test('yields false again after agent is released', () async {
      final runner = WakeRunner();
      addTearDown(runner.dispose);

      final container = ProviderContainer(
        overrides: [
          wakeRunnerProvider.overrideWithValue(runner),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(
        agentIsRunningProvider(kTestAgentId),
        (_, __) {},
      );
      addTearDown(sub.close);

      await Future<void>.delayed(Duration.zero);

      await runner.tryAcquire(kTestAgentId);
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(agentIsRunningProvider(kTestAgentId)).value,
        isTrue,
      );

      runner.release(kTestAgentId);
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(agentIsRunningProvider(kTestAgentId)).value,
        isFalse,
      );
    });

    test('yields initial true when agent is already running', () async {
      final runner = WakeRunner();
      addTearDown(runner.dispose);

      // Acquire lock before creating the provider.
      await runner.tryAcquire(kTestAgentId);

      final container = ProviderContainer(
        overrides: [
          wakeRunnerProvider.overrideWithValue(runner),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(
        agentIsRunningProvider(kTestAgentId),
        (_, __) {},
      );
      addTearDown(sub.close);

      await Future<void>.delayed(Duration.zero);

      final value = container.read(agentIsRunningProvider(kTestAgentId));
      expect(value.value, isTrue);

      runner.release(kTestAgentId);
    });
  });

  group('agentInitializationProvider', () {
    late MockWakeOrchestrator mockOrchestrator;
    late MockTaskAgentWorkflow mockWorkflow;
    late MockTaskAgentService mockTaskAgentService;

    setUp(() async {
      await setUpTestGetIt();
      mockOrchestrator = MockWakeOrchestrator();
      mockWorkflow = MockTaskAgentWorkflow();
      mockTaskAgentService = MockTaskAgentService();

      when(() => mockOrchestrator.start(any())).thenAnswer((_) async {});
      when(() => mockOrchestrator.stop()).thenAnswer((_) async {});
      when(() => mockTaskAgentService.restoreSubscriptions())
          .thenAnswer((_) async {});
    });

    tearDown(tearDownTestGetIt);

    ProviderContainer createInitContainer({
      required bool enableAgents,
    }) {
      final container = ProviderContainer(
        overrides: [
          agentServiceProvider.overrideWithValue(mockService),
          agentRepositoryProvider.overrideWithValue(mockRepository),
          wakeOrchestratorProvider.overrideWithValue(mockOrchestrator),
          taskAgentWorkflowProvider.overrideWithValue(mockWorkflow),
          taskAgentServiceProvider.overrideWithValue(mockTaskAgentService),
          configFlagProvider.overrideWith(
            (ref, flagName) => Stream.value(
              flagName == enableAgentsFlag && enableAgents,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('does nothing when agents are disabled', () async {
      final container = createInitContainer(enableAgents: false);

      // Keep the subscription alive for keepAlive provider.
      final sub = container.listen(
        agentInitializationProvider,
        (_, __) {},
      );
      addTearDown(sub.close);

      await container.read(agentInitializationProvider.future);

      verifyNever(() => mockOrchestrator.start(any()));
      verifyNever(() => mockTaskAgentService.restoreSubscriptions());
    });

    test('starts orchestrator and restores subscriptions when enabled',
        () async {
      final container = createInitContainer(enableAgents: true);

      final sub = container.listen(
        agentInitializationProvider,
        (_, __) {},
      );
      addTearDown(sub.close);

      await container.read(agentInitializationProvider.future);

      verify(() => mockOrchestrator.start(any())).called(1);
      verify(() => mockTaskAgentService.restoreSubscriptions()).called(1);
    });

    test('sets wakeExecutor on orchestrator when enabled', () async {
      final container = createInitContainer(enableAgents: true);

      final sub = container.listen(
        agentInitializationProvider,
        (_, __) {},
      );
      addTearDown(sub.close);

      await container.read(agentInitializationProvider.future);

      // The orchestrator's wakeExecutor setter should have been called.
      verify(() => mockOrchestrator.wakeExecutor = any()).called(1);
    });

    test(
      'wakeExecutor returns null when agent identity not found',
      () async {
        when(() => mockService.getAgent(kTestAgentId))
            .thenAnswer((_) async => null);

        // Use a capturing orchestrator to grab the wakeExecutor callback.
        WakeExecutor? capturedExecutor;
        when(() => mockOrchestrator.wakeExecutor = any()).thenAnswer((inv) {
          capturedExecutor = inv.positionalArguments[0] as WakeExecutor?;
          return null;
        });

        final container = createInitContainer(enableAgents: true);
        final sub = container.listen(
          agentInitializationProvider,
          (_, __) {},
        );
        addTearDown(sub.close);
        await container.read(agentInitializationProvider.future);

        expect(capturedExecutor, isNotNull);
        final result = await capturedExecutor!(
          kTestAgentId,
          'run-key-1',
          {'tok-a'},
          'thread-1',
        );

        expect(result, isNull);
        verify(() => mockService.getAgent(kTestAgentId)).called(1);
      },
    );

    test(
      'wakeExecutor executes workflow and returns mutated entries',
      () async {
        final identity = makeTestIdentity();
        final mutated = <String, VectorClock>{
          'entry-1': const VectorClock({}),
        };

        when(() => mockService.getAgent(kTestAgentId))
            .thenAnswer((_) async => identity);
        when(
          () => mockWorkflow.execute(
            agentIdentity: any(named: 'agentIdentity'),
            runKey: any(named: 'runKey'),
            triggerTokens: any(named: 'triggerTokens'),
            threadId: any(named: 'threadId'),
          ),
        ).thenAnswer(
          (_) async => WakeResult(success: true, mutatedEntries: mutated),
        );

        WakeExecutor? capturedExecutor;
        when(() => mockOrchestrator.wakeExecutor = any()).thenAnswer((inv) {
          capturedExecutor = inv.positionalArguments[0] as WakeExecutor?;
          return null;
        });

        final container = createInitContainer(enableAgents: true);
        final sub = container.listen(
          agentInitializationProvider,
          (_, __) {},
        );
        addTearDown(sub.close);
        await container.read(agentInitializationProvider.future);

        expect(capturedExecutor, isNotNull);
        final result = await capturedExecutor!(
          kTestAgentId,
          'run-key-1',
          {'tok-a'},
          'thread-1',
        );

        expect(result, equals(mutated));
        verify(
          () => mockWorkflow.execute(
            agentIdentity: identity,
            runKey: 'run-key-1',
            triggerTokens: {'tok-a'},
            threadId: 'thread-1',
          ),
        ).called(1);
      },
    );

    test(
      'wakeExecutor invalidates UI providers after successful execution',
      () async {
        final identity = makeTestIdentity();
        final mutated = <String, VectorClock>{
          'entry-1': const VectorClock({}),
        };

        when(() => mockService.getAgent(kTestAgentId))
            .thenAnswer((_) async => identity);
        when(
          () => mockWorkflow.execute(
            agentIdentity: any(named: 'agentIdentity'),
            runKey: any(named: 'runKey'),
            triggerTokens: any(named: 'triggerTokens'),
            threadId: any(named: 'threadId'),
          ),
        ).thenAnswer(
          (_) async => WakeResult(success: true, mutatedEntries: mutated),
        );

        // Stub providers that will be read after invalidation.
        when(() => mockService.getAgentReport(kTestAgentId))
            .thenAnswer((_) async => null);
        when(() => mockRepository.getAgentState(kTestAgentId))
            .thenAnswer((_) async => null);
        when(
          () => mockRepository.getEntitiesByAgentId(
            kTestAgentId,
            type: 'agentMessage',
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => []);

        WakeExecutor? capturedExecutor;
        when(() => mockOrchestrator.wakeExecutor = any()).thenAnswer((inv) {
          capturedExecutor = inv.positionalArguments[0] as WakeExecutor?;
          return null;
        });

        final container = createInitContainer(enableAgents: true);
        final sub = container.listen(
          agentInitializationProvider,
          (_, __) {},
        );
        addTearDown(sub.close);
        await container.read(agentInitializationProvider.future);

        // Prime all providers so we can detect invalidation.
        container
          ..listen(agentReportProvider(kTestAgentId), (_, __) {})
          ..listen(agentStateProvider(kTestAgentId), (_, __) {})
          ..listen(
            agentRecentMessagesProvider(kTestAgentId),
            (_, __) {},
          )
          ..listen(
            agentObservationMessagesProvider(kTestAgentId),
            (_, __) {},
          )
          ..listen(
            agentMessagesByThreadProvider(kTestAgentId),
            (_, __) {},
          );
        await container.read(agentReportProvider(kTestAgentId).future);
        await container.read(agentStateProvider(kTestAgentId).future);
        await container.read(agentRecentMessagesProvider(kTestAgentId).future);
        await container
            .read(agentObservationMessagesProvider(kTestAgentId).future);
        await container
            .read(agentMessagesByThreadProvider(kTestAgentId).future);

        // Execute the wakeExecutor — this should invalidate all five
        // providers, causing them to re-fetch on next read.
        await capturedExecutor!(
          kTestAgentId,
          'run-key-2',
          {'tok-b'},
          'thread-2',
        );

        // Force the invalidated providers to re-execute.
        await container.read(agentReportProvider(kTestAgentId).future);
        await container.read(agentStateProvider(kTestAgentId).future);
        await container.read(agentRecentMessagesProvider(kTestAgentId).future);
        await container
            .read(agentObservationMessagesProvider(kTestAgentId).future);
        await container
            .read(agentMessagesByThreadProvider(kTestAgentId).future);

        // Each provider was read once to prime, then once after
        // invalidation — two calls total.
        verify(() => mockService.getAgentReport(kTestAgentId)).called(2);
        verify(() => mockRepository.getAgentState(kTestAgentId)).called(2);
        // agentRecentMessages (limit=50) + agentObservationMessages (limit=200)
        // + agentMessagesByThread (limit=200) = 3 reads per cycle, 2 cycles = 6.
        verify(
          () => mockRepository.getEntitiesByAgentId(
            kTestAgentId,
            type: 'agentMessage',
            limit: any(named: 'limit'),
          ),
        ).called(6);
      },
    );

    test('stops orchestrator on dispose', () async {
      final container = createInitContainer(enableAgents: true);

      final sub = container.listen(
        agentInitializationProvider,
        (_, __) {},
      );

      await container.read(agentInitializationProvider.future);

      sub.close();
      container.dispose();

      verify(() => mockOrchestrator.stop()).called(1);
    });
  });
}
