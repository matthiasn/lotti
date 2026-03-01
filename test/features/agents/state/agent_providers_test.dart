import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/service/agent_service.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/agents/wake/wake_queue.dart';
import 'package:lotti/features/agents/wake/wake_runner.dart';
import 'package:lotti/features/agents/workflow/task_agent_workflow.dart';
import 'package:lotti/features/agents/workflow/template_evolution_workflow.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart'
    show loggingServiceProvider, outboxServiceProvider;
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/logging_service.dart';
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

  group('dependency providers', () {
    setUp(() async {
      await getIt.reset();
    });

    tearDown(() async {
      await getIt.reset();
    });

    test('maybeUpdateNotificationsProvider returns null when unregistered', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(maybeUpdateNotificationsProvider), isNull);
    });

    test('updateNotificationsProvider throws when unregistered', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        () => container.read(updateNotificationsProvider),
        throwsA(
          predicate<Object>(
            (error) => error
                .toString()
                .contains('UpdateNotifications is not registered in GetIt'),
          ),
        ),
      );
    });

    test('updateNotificationsProvider returns registered instance', () {
      final mockNotifications = MockUpdateNotifications();
      getIt.registerSingleton<UpdateNotifications>(mockNotifications);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(updateNotificationsProvider),
        same(mockNotifications),
      );
    });

    test('maybeSyncEventProcessorProvider returns null when unregistered', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(maybeSyncEventProcessorProvider), isNull);
    });

    test('maybeSyncEventProcessorProvider returns registered instance', () {
      final mockProcessor = MockSyncEventProcessor();
      getIt.registerSingleton<SyncEventProcessor>(mockProcessor);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(maybeSyncEventProcessorProvider),
        same(mockProcessor),
      );
    });
  });

  group('domainLoggerProvider', () {
    test('creates DomainLogger and seeds initial flags', () async {
      final container = ProviderContainer(
        overrides: [
          loggingServiceProvider.overrideWithValue(LoggingService()),
          configFlagProvider(logAgentRuntimeFlag)
              .overrideWith((ref) => Stream.value(true)),
          configFlagProvider(logAgentWorkflowFlag)
              .overrideWith((ref) => Stream.value(false)),
          configFlagProvider(logSyncFlag)
              .overrideWith((ref) => Stream.value(true)),
        ],
      );
      addTearDown(container.dispose);

      // Read + listen to ensure the provider stays alive and processes
      // stream events from configFlagProvider.
      final sub = container.listen(domainLoggerProvider, (_, __) {});
      addTearDown(sub.close);
      final logger = container.read(domainLoggerProvider);
      expect(logger, isA<DomainLogger>());

      // Let the config flag streams emit so ref.listen fires.
      await Future<void>.delayed(Duration.zero);
      await container.pump();

      expect(logger.enabledDomains, contains(LogDomains.agentRuntime));
      expect(logger.enabledDomains, isNot(contains(LogDomains.agentWorkflow)));
      expect(logger.enabledDomains, contains(LogDomains.sync));
    });

    test('updates enabledDomains when config flags change', () async {
      final runtimeController = StreamController<bool>.broadcast();
      final workflowController = StreamController<bool>.broadcast();
      final syncController = StreamController<bool>.broadcast();
      addTearDown(runtimeController.close);
      addTearDown(workflowController.close);
      addTearDown(syncController.close);

      final container = ProviderContainer(
        overrides: [
          loggingServiceProvider.overrideWithValue(LoggingService()),
          configFlagProvider(logAgentRuntimeFlag)
              .overrideWith((ref) => runtimeController.stream),
          configFlagProvider(logAgentWorkflowFlag)
              .overrideWith((ref) => workflowController.stream),
          configFlagProvider(logSyncFlag)
              .overrideWith((ref) => syncController.stream),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(domainLoggerProvider, (_, __) {});
      addTearDown(sub.close);
      final logger = container.read(domainLoggerProvider);

      // Initially empty because streams haven't emitted yet.
      expect(logger.enabledDomains, isEmpty);

      // Emit: agent_runtime=true, agent_workflow=true, sync=false.
      runtimeController.add(true);
      workflowController.add(true);
      syncController.add(false);
      await Future<void>.delayed(Duration.zero);
      await container.pump();

      expect(logger.enabledDomains, contains(LogDomains.agentRuntime));
      expect(logger.enabledDomains, contains(LogDomains.agentWorkflow));
      expect(logger.enabledDomains, isNot(contains(LogDomains.sync)));

      // Toggle: agent_runtime off, sync on.
      runtimeController.add(false);
      syncController.add(true);
      await Future<void>.delayed(Duration.zero);
      await container.pump();

      expect(logger.enabledDomains, isNot(contains(LogDomains.agentRuntime)));
      expect(logger.enabledDomains, contains(LogDomains.agentWorkflow));
      expect(logger.enabledDomains, contains(LogDomains.sync));
    });
  });

  group('agentDatabaseProvider', () {
    test('creates database and closes on dispose', () async {
      final container = ProviderContainer();

      final db = container.read(agentDatabaseProvider);
      expect(db, isA<AgentDatabase>());

      // Dispose should close the database without error.
      container.dispose();
    });
  });

  group('agentRepositoryProvider', () {
    test('creates repository wrapping the database', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final repo = container.read(agentRepositoryProvider);
      expect(repo, isA<AgentRepository>());
    });
  });

  group('agentSyncServiceProvider', () {
    test('injects repository and outbox service', () async {
      final mockOutboxService = MockOutboxService();
      final container = ProviderContainer(
        overrides: [
          agentRepositoryProvider.overrideWithValue(mockRepository),
          outboxServiceProvider.overrideWithValue(mockOutboxService),
        ],
      );
      addTearDown(container.dispose);

      final syncService = container.read(agentSyncServiceProvider);

      // Verify the repository was injected.
      expect(syncService.repository, same(mockRepository));

      // Verify the outbox service was injected by exercising upsertEntity.
      final entity = makeTestIdentity();
      when(() => mockRepository.upsertEntity(any())).thenAnswer((_) async {});
      when(() => mockOutboxService.enqueueMessage(any()))
          .thenAnswer((_) async {});

      await syncService.upsertEntity(entity);

      verify(() => mockRepository.upsertEntity(entity)).called(1);
      verify(() => mockOutboxService.enqueueMessage(any())).called(1);
    });
  });

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

    test('sorts threads most-recent-first by latest message', () async {
      // thread-a: latest message at 10:00
      // thread-b: latest message at 14:00
      // thread-c: latest message at 12:00
      final messages = [
        makeTestMessage(
          id: 'a1',
          threadId: 'thread-a',
          createdAt: DateTime(2024, 3, 15, 10),
        ),
        makeTestMessage(
          id: 'b1',
          threadId: 'thread-b',
          createdAt: DateTime(2024, 3, 15, 14),
        ),
        makeTestMessage(
          id: 'c1',
          threadId: 'thread-c',
          createdAt: DateTime(2024, 3, 15, 12),
        ),
      ];

      when(
        () => mockRepository.getEntitiesByAgentId(
          kTestAgentId,
          type: 'agentMessage',
          limit: 200,
        ),
      ).thenAnswer((_) async => messages);

      final container = createContainer();
      final result = await container
          .read(agentMessagesByThreadProvider(kTestAgentId).future);

      final threadIds = result.keys.toList();
      expect(threadIds, ['thread-b', 'thread-c', 'thread-a']);
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

  group('agentReportHistoryProvider', () {
    test('returns report entities ordered most-recent-first', () async {
      final report1 = makeTestReport(
        id: 'report-1',
        content: 'First report',
      );
      final report2 = makeTestReport(
        id: 'report-2',
        content: 'Second report',
      );

      when(
        () => mockRepository.getEntitiesByAgentId(
          kTestAgentId,
          type: 'agentReport',
          limit: 50,
        ),
      ).thenAnswer((_) async => [report2, report1]);

      final container = createContainer();
      final result =
          await container.read(agentReportHistoryProvider(kTestAgentId).future);

      expect(result, hasLength(2));
      expect((result[0] as AgentReportEntity).id, 'report-2');
      expect((result[1] as AgentReportEntity).id, 'report-1');
    });

    test('returns empty list when no reports exist', () async {
      when(
        () => mockRepository.getEntitiesByAgentId(
          kTestAgentId,
          type: 'agentReport',
          limit: 50,
        ),
      ).thenAnswer((_) async => []);

      final container = createContainer();
      final result =
          await container.read(agentReportHistoryProvider(kTestAgentId).future);

      expect(result, isEmpty);
    });

    test('filters out non-AgentReportEntity types', () async {
      final report = makeTestReport(id: 'report-1');
      final msg = makeTestMessage(id: 'msg-1', threadId: 'thread-a');

      when(
        () => mockRepository.getEntitiesByAgentId(
          kTestAgentId,
          type: 'agentReport',
          limit: 50,
        ),
      ).thenAnswer((_) async => [report, msg]);

      final container = createContainer();
      final result =
          await container.read(agentReportHistoryProvider(kTestAgentId).future);

      expect(result, hasLength(1));
      expect((result[0] as AgentReportEntity).id, 'report-1');
    });

    test('passes limit=50 and type=agentReport to repository', () async {
      when(
        () => mockRepository.getEntitiesByAgentId(
          kTestAgentId,
          type: 'agentReport',
          limit: 50,
        ),
      ).thenAnswer((_) async => []);

      final container = createContainer();
      await container.read(agentReportHistoryProvider(kTestAgentId).future);

      verify(
        () => mockRepository.getEntitiesByAgentId(
          kTestAgentId,
          type: 'agentReport',
          limit: 50,
        ),
      ).called(1);
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
      await pumpEventQueue();

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

      await pumpEventQueue();

      await runner.tryAcquire(kTestAgentId);
      await pumpEventQueue();

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

      await pumpEventQueue();

      await runner.tryAcquire(kTestAgentId);
      await pumpEventQueue();
      expect(
        container.read(agentIsRunningProvider(kTestAgentId)).value,
        isTrue,
      );

      runner.release(kTestAgentId);
      await pumpEventQueue();
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

      await pumpEventQueue();

      final value = container.read(agentIsRunningProvider(kTestAgentId));
      expect(value.value, isTrue);

      runner.release(kTestAgentId);
    });
  });

  group('agentUpdateStreamProvider', () {
    Future<ProviderContainer> setUpStreamTest(
      StreamController<Set<String>> controller,
    ) async {
      final mockNotifications = MockUpdateNotifications();
      when(() => mockNotifications.updateStream)
          .thenAnswer((_) => controller.stream);
      when(() => mockNotifications.localUpdateStream)
          .thenAnswer((_) => const Stream.empty());

      await getIt.reset();
      getIt.registerSingleton<UpdateNotifications>(mockNotifications);
      addTearDown(getIt.reset);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      return container;
    }

    test('emits when UpdateNotifications fires with matching agent ID',
        () async {
      final controller = StreamController<Set<String>>.broadcast();
      addTearDown(controller.close);

      final container = await setUpStreamTest(controller);

      final values = <AsyncValue<Set<String>>>[];
      final sub = container.listen(
        agentUpdateStreamProvider(kTestAgentId),
        (_, next) => values.add(next),
      );
      addTearDown(sub.close);

      await pumpEventQueue();

      // Fire notification with matching agent ID.
      controller.add({kTestAgentId, 'other-id'});
      await pumpEventQueue();

      expect(values, isNotEmpty);
    });

    test('does NOT emit for unrelated agent IDs', () async {
      final controller = StreamController<Set<String>>.broadcast();
      addTearDown(controller.close);

      final container = await setUpStreamTest(controller);

      final values = <AsyncValue<Set<String>>>[];
      final sub = container.listen(
        agentUpdateStreamProvider(kTestAgentId),
        (_, next) => values.add(next),
      );
      addTearDown(sub.close);

      await pumpEventQueue();
      values.clear();

      // Fire notification with a DIFFERENT agent ID.
      controller.add({'different-agent-id'});
      await pumpEventQueue();

      expect(values, isEmpty);
    });

    test('multiple emissions each trigger a new notification', () async {
      final controller = StreamController<Set<String>>.broadcast();
      addTearDown(controller.close);

      final container = await setUpStreamTest(controller);

      final values = <AsyncValue<Set<String>>>[];
      final sub = container.listen(
        agentUpdateStreamProvider(kTestAgentId),
        (_, next) => values.add(next),
      );
      addTearDown(sub.close);

      await pumpEventQueue();
      values.clear();

      // Fire three successive notifications — each must produce a
      // distinct AsyncData because we pass through Set<String> (identity
      // distinct) rather than void (which Riverpod would deduplicate).
      controller.add({kTestAgentId});
      await pumpEventQueue();
      controller.add({kTestAgentId});
      await pumpEventQueue();
      controller.add({kTestAgentId});
      await pumpEventQueue();

      expect(values, hasLength(3));
    });
  });

  group('agentInitializationProvider', () {
    late MockWakeOrchestrator mockOrchestrator;
    late MockTaskAgentWorkflow mockWorkflow;
    late MockTaskAgentService mockTaskAgentService;
    late MockAgentTemplateService mockTemplateService;
    late MockAiConfigRepository mockAiConfigRepo;

    setUp(() async {
      await setUpTestGetIt();
      mockOrchestrator = MockWakeOrchestrator();
      mockWorkflow = MockTaskAgentWorkflow();
      mockTaskAgentService = MockTaskAgentService();
      mockTemplateService = MockAgentTemplateService();
      mockAiConfigRepo = MockAiConfigRepository();

      when(() => mockOrchestrator.start(any())).thenAnswer((_) async {});
      when(() => mockOrchestrator.stop()).thenAnswer((_) async {});
      when(() => mockTaskAgentService.restoreSubscriptions())
          .thenAnswer((_) async {});
      when(() => mockTemplateService.seedDefaults()).thenAnswer((_) async {});
      when(() => mockTemplateService.getTemplateForAgent(any()))
          .thenAnswer((_) async => null);
      when(() => mockRepository.abandonOrphanedWakeRuns())
          .thenAnswer((_) async => 0);
      // Profile seeding stubs.
      when(() => mockAiConfigRepo.getConfigById(any()))
          .thenAnswer((_) async => null);
      when(() => mockAiConfigRepo.saveConfig(any())).thenAnswer((_) async {});
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
          agentTemplateServiceProvider.overrideWithValue(mockTemplateService),
          aiConfigRepositoryProvider.overrideWithValue(mockAiConfigRepo),
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
      verify(() => mockTemplateService.seedDefaults()).called(1);
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
      'wakeExecutor throws when workflow returns unsuccessful result',
      () async {
        final identity = makeTestIdentity();

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
          (_) async => const WakeResult(
            success: false,
            error: 'workflow failed',
          ),
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
        await expectLater(
          capturedExecutor!(
            kTestAgentId,
            'run-key-fail',
            {'tok-fail'},
            'thread-fail',
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              'workflow failed',
            ),
          ),
        );

        final mockNotifications =
            getIt<UpdateNotifications>() as MockUpdateNotifications;
        verifyNever(
          () => mockNotifications.notify(
            {kTestAgentId, 'AGENT_CHANGED'},
          ),
        );
      },
    );

    test(
      'wakeExecutor fires update notification after successful execution',
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

        // Execute the wakeExecutor — this should fire a notification
        // with the agent ID so detail providers self-invalidate.
        await capturedExecutor!(
          kTestAgentId,
          'run-key-2',
          {'tok-b'},
          'thread-2',
        );

        final mockNotifications =
            getIt<UpdateNotifications>() as MockUpdateNotifications;
        verify(
          () => mockNotifications.notify(
            {kTestAgentId, 'AGENT_CHANGED'},
          ),
        ).called(1);
      },
    );

    test(
      'wakeExecutor includes templateId in notification when template exists',
      () async {
        final identity = makeTestIdentity();
        final mutated = <String, VectorClock>{
          'entry-1': const VectorClock({}),
        };
        final template = makeTestTemplate(
          id: 'tpl-1',
          agentId: 'tpl-1',
        );

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
        when(() => mockTemplateService.getTemplateForAgent(kTestAgentId))
            .thenAnswer((_) async => template);

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

        await capturedExecutor!(
          kTestAgentId,
          'run-key-tpl',
          {'tok-c'},
          'thread-tpl',
        );

        final mockNotifications =
            getIt<UpdateNotifications>() as MockUpdateNotifications;
        verify(
          () => mockNotifications.notify(
            {kTestAgentId, 'tpl-1', 'AGENT_CHANGED'},
          ),
        ).called(1);
      },
    );

    test(
      'wakeExecutor still notifies when getTemplateForAgent throws',
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
        when(() => mockTemplateService.getTemplateForAgent(kTestAgentId))
            .thenThrow(Exception('db connection lost'));

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
          'run-key-err',
          {'tok-d'},
          'thread-err',
        );

        // Wake still succeeds — returns mutated entries
        expect(result, mutated);

        // Notification is still sent with just agentId (no templateId)
        final mockNotifications =
            getIt<UpdateNotifications>() as MockUpdateNotifications;
        verify(
          () => mockNotifications.notify(
            {kTestAgentId, 'AGENT_CHANGED'},
          ),
        ).called(1);
      },
    );

    test('wires repository and orchestrator into SyncEventProcessor', () async {
      final mockProcessor = MockSyncEventProcessor();
      getIt.registerSingleton<SyncEventProcessor>(mockProcessor);

      final container = createInitContainer(enableAgents: true);

      final sub = container.listen(
        agentInitializationProvider,
        (_, __) {},
      );
      addTearDown(sub.close);

      await container.read(agentInitializationProvider.future);

      verify(() => mockProcessor.wakeOrchestrator = mockOrchestrator).called(1);
      verify(() => mockProcessor.agentRepository = any(that: isNotNull))
          .called(1);
    });

    test('clears SyncEventProcessor fields on dispose', () async {
      final mockProcessor = MockSyncEventProcessor();
      getIt.registerSingleton<SyncEventProcessor>(mockProcessor);

      final container = createInitContainer(enableAgents: true);

      final sub = container.listen(
        agentInitializationProvider,
        (_, __) {},
      );

      await container.read(agentInitializationProvider.future);

      sub.close();
      container.dispose();

      verify(() => mockProcessor.wakeOrchestrator = null).called(1);
      verify(() => mockProcessor.agentRepository = null).called(1);
    });

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

  group('template providers', () {
    late MockAgentTemplateService mockTemplateService;

    setUp(() {
      mockTemplateService = MockAgentTemplateService();
    });

    ProviderContainer createTemplateContainer() {
      final container = ProviderContainer(
        overrides: [
          agentTemplateServiceProvider.overrideWithValue(mockTemplateService),
          agentServiceProvider.overrideWithValue(mockService),
          agentRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('agentTemplatesProvider delegates to listTemplates', () async {
      final templates = [
        makeTestTemplate(id: 'tpl-a', agentId: 'tpl-a'),
      ];
      when(() => mockTemplateService.listTemplates())
          .thenAnswer((_) async => templates);

      final container = createTemplateContainer();
      final result = await container.read(agentTemplatesProvider.future);

      expect(result, hasLength(1));
      verify(() => mockTemplateService.listTemplates()).called(1);
    });

    test('agentTemplateProvider delegates to getTemplate', () async {
      final template = makeTestTemplate();
      when(() => mockTemplateService.getTemplate(kTestTemplateId))
          .thenAnswer((_) async => template);

      final container = createTemplateContainer();
      final result =
          await container.read(agentTemplateProvider(kTestTemplateId).future);

      expect(result, isNotNull);
      expect((result! as AgentTemplateEntity).id, kTestTemplateId);
    });

    test('agentTemplateProvider returns null when not found', () async {
      when(() => mockTemplateService.getTemplate('missing'))
          .thenAnswer((_) async => null);

      final container = createTemplateContainer();
      final result =
          await container.read(agentTemplateProvider('missing').future);

      expect(result, isNull);
    });

    test('activeTemplateVersionProvider delegates to getActiveVersion',
        () async {
      final version = makeTestTemplateVersion();
      when(() => mockTemplateService.getActiveVersion(kTestTemplateId))
          .thenAnswer((_) async => version);

      final container = createTemplateContainer();
      final result = await container
          .read(activeTemplateVersionProvider(kTestTemplateId).future);

      expect(result, isNotNull);
      expect((result! as AgentTemplateVersionEntity).version, 1);
    });

    test('templateVersionHistoryProvider delegates to getVersionHistory',
        () async {
      final versions = [
        makeTestTemplateVersion(id: 'v2', version: 2),
        makeTestTemplateVersion(id: 'v1'),
      ];
      when(() => mockTemplateService.getVersionHistory(kTestTemplateId))
          .thenAnswer((_) async => versions);

      final container = createTemplateContainer();
      final result = await container
          .read(templateVersionHistoryProvider(kTestTemplateId).future);

      expect(result, hasLength(2));
    });

    test('templateForAgentProvider delegates to getTemplateForAgent', () async {
      final template = makeTestTemplate();
      when(() => mockTemplateService.getTemplateForAgent(kTestAgentId))
          .thenAnswer((_) async => template);

      final container = createTemplateContainer();
      final result =
          await container.read(templateForAgentProvider(kTestAgentId).future);

      expect(result, isNotNull);
      expect((result! as AgentTemplateEntity).id, kTestTemplateId);
    });

    test('templatePerformanceMetricsProvider delegates to computeMetrics',
        () async {
      final metrics = makeTestMetrics();
      when(() => mockTemplateService.computeMetrics(kTestTemplateId))
          .thenAnswer((_) async => metrics);

      final container = createTemplateContainer();
      final result = await container
          .read(templatePerformanceMetricsProvider(kTestTemplateId).future);

      expect(result.totalWakes, 10);
      expect(result.successRate, 0.8);
    });

    test('activeTemplateVersionProvider returns null when not found', () async {
      when(() => mockTemplateService.getActiveVersion('missing'))
          .thenAnswer((_) async => null);

      final container = createTemplateContainer();
      final result =
          await container.read(activeTemplateVersionProvider('missing').future);

      expect(result, isNull);
    });

    test('templateForAgentProvider returns null when agent has no template',
        () async {
      when(() => mockTemplateService.getTemplateForAgent('no-template'))
          .thenAnswer((_) async => null);

      final container = createTemplateContainer();
      final result =
          await container.read(templateForAgentProvider('no-template').future);

      expect(result, isNull);
    });

    test('templateVersionHistoryProvider returns empty list', () async {
      when(() => mockTemplateService.getVersionHistory('empty'))
          .thenAnswer((_) async => []);

      final container = createTemplateContainer();
      final result =
          await container.read(templateVersionHistoryProvider('empty').future);

      expect(result, isEmpty);
    });

    test('agentTemplatesProvider returns empty list', () async {
      when(() => mockTemplateService.listTemplates())
          .thenAnswer((_) async => []);

      final container = createTemplateContainer();
      final result = await container.read(agentTemplatesProvider.future);

      expect(result, isEmpty);
    });
  });

  group('wakeQueueProvider', () {
    test('supports enqueue and dequeue', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final queue = container.read(wakeQueueProvider);

      // Queue starts empty.
      expect(queue.dequeue(), isNull);

      // Enqueue a job and dequeue it.
      final job = WakeJob(
        agentId: kTestAgentId,
        runKey: 'run-1',
        reason: 'subscription',
        triggerTokens: {'tok-a'},
        createdAt: DateTime(2024, 3, 15),
      );
      final added = queue.enqueue(job);
      expect(added, isTrue);

      final dequeued = queue.dequeue();
      expect(dequeued, isNotNull);
      expect(dequeued!.agentId, kTestAgentId);
      expect(dequeued.runKey, 'run-1');
    });

    test('deduplicates by run key', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final queue = container.read(wakeQueueProvider);

      final job = WakeJob(
        agentId: kTestAgentId,
        runKey: 'dup-key',
        reason: 'subscription',
        triggerTokens: {'tok'},
        createdAt: DateTime(2024, 3, 15),
      );
      expect(queue.enqueue(job), isTrue);
      expect(queue.enqueue(job), isFalse);
    });
  });

  group('wakeRunnerProvider', () {
    test('supports lock acquisition and release', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final runner = container.read(wakeRunnerProvider);

      // Acquire lock.
      final acquired = await runner.tryAcquire(kTestAgentId);
      expect(acquired, isTrue);
      expect(runner.isRunning(kTestAgentId), isTrue);

      // Release lock.
      runner.release(kTestAgentId);
      expect(runner.isRunning(kTestAgentId), isFalse);
    });

    test('disposes runner when container is disposed', () async {
      final container = ProviderContainer();

      final runner = container.read(wakeRunnerProvider);
      final acquired = await runner.tryAcquire(kTestAgentId);
      expect(acquired, isTrue);

      // Dispose should call runner.dispose() without error.
      container.dispose();
    });
  });

  group('wakeOrchestratorProvider', () {
    test('creates orchestrator with injected dependencies', () {
      final mockRepo = MockAgentRepository();
      final queue = WakeQueue();
      final runner = WakeRunner();
      addTearDown(runner.dispose);

      final container = ProviderContainer(
        overrides: [
          agentRepositoryProvider.overrideWithValue(mockRepo),
          wakeQueueProvider.overrideWithValue(queue),
          wakeRunnerProvider.overrideWithValue(runner),
          domainLoggerProvider.overrideWithValue(
            DomainLogger(loggingService: LoggingService()),
          ),
        ],
      );
      addTearDown(container.dispose);

      final orchestrator = container.read(wakeOrchestratorProvider);
      expect(orchestrator, isA<WakeOrchestrator>());
      expect(orchestrator.repository, same(mockRepo));
      expect(orchestrator.queue, same(queue));
      expect(orchestrator.runner, same(runner));
    });

    test(
        'wires persisted-state callback to UpdateNotifications when registered',
        () async {
      final mockRepo = MockAgentRepository();
      final queue = WakeQueue();
      final runner = WakeRunner();
      final mockNotifications = MockUpdateNotifications();
      addTearDown(runner.dispose);

      when(
        () => mockNotifications.notify(
          any(),
          fromSync: any(named: 'fromSync'),
        ),
      ).thenReturn(null);

      await getIt.reset();
      getIt.registerSingleton<UpdateNotifications>(mockNotifications);
      addTearDown(getIt.reset);

      final container = ProviderContainer(
        overrides: [
          agentRepositoryProvider.overrideWithValue(mockRepo),
          wakeQueueProvider.overrideWithValue(queue),
          wakeRunnerProvider.overrideWithValue(runner),
          domainLoggerProvider.overrideWithValue(
            DomainLogger(loggingService: LoggingService()),
          ),
        ],
      );
      addTearDown(container.dispose);

      final orchestrator = container.read(wakeOrchestratorProvider);
      orchestrator.onPersistedStateChanged?.call(kTestAgentId);

      verify(
        () => mockNotifications.notify(
          {kTestAgentId, agentNotification},
          fromSync: true,
        ),
      ).called(1);
    });
  });

  group('agentServiceProvider', () {
    test('creates service with injected dependencies', () {
      final mockRepo = MockAgentRepository();
      final mockOrchestrator = MockWakeOrchestrator();
      final mockSyncService = MockAgentSyncService();
      final mockOutbox = MockOutboxService();

      final container = ProviderContainer(
        overrides: [
          agentRepositoryProvider.overrideWithValue(mockRepo),
          wakeOrchestratorProvider.overrideWithValue(mockOrchestrator),
          agentSyncServiceProvider.overrideWithValue(mockSyncService),
          outboxServiceProvider.overrideWithValue(mockOutbox),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(agentServiceProvider);
      expect(service, isA<AgentService>());
      expect(service.repository, same(mockRepo));
      expect(service.orchestrator, same(mockOrchestrator));
    });
  });

  group('agentTemplateServiceProvider', () {
    test('creates service with injected dependencies', () {
      final mockRepo = MockAgentRepository();
      final mockSyncService = MockAgentSyncService();
      final mockOutbox = MockOutboxService();

      final container = ProviderContainer(
        overrides: [
          agentRepositoryProvider.overrideWithValue(mockRepo),
          agentSyncServiceProvider.overrideWithValue(mockSyncService),
          outboxServiceProvider.overrideWithValue(mockOutbox),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(agentTemplateServiceProvider);
      expect(service, isA<AgentTemplateService>());
      expect(service.repository, same(mockRepo));
    });
  });

  group('templateEvolutionWorkflowProvider', () {
    test('creates workflow instance', () {
      final mockTemplateWorkflow = MockTemplateEvolutionWorkflow();

      final container = ProviderContainer(
        overrides: [
          templateEvolutionWorkflowProvider
              .overrideWithValue(mockTemplateWorkflow),
        ],
      );
      addTearDown(container.dispose);

      final workflow = container.read(templateEvolutionWorkflowProvider);
      expect(workflow, isA<TemplateEvolutionWorkflow>());
      expect(workflow, same(mockTemplateWorkflow));
    });
  });

  group('evolutionSessionsProvider', () {
    late MockAgentTemplateService mockTemplateService;

    setUp(() {
      mockTemplateService = MockAgentTemplateService();
    });

    ProviderContainer createEvolutionContainer() {
      final container = ProviderContainer(
        overrides: [
          agentTemplateServiceProvider.overrideWithValue(mockTemplateService),
          agentServiceProvider.overrideWithValue(mockService),
          agentRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('delegates to getEvolutionSessions', () async {
      final sessions = [
        makeTestEvolutionSession(id: 's1'),
        makeTestEvolutionSession(
          id: 's2',
          status: EvolutionSessionStatus.completed,
        ),
      ];
      when(() => mockTemplateService.getEvolutionSessions(kTestTemplateId))
          .thenAnswer((_) async => sessions);

      final container = createEvolutionContainer();
      final result = await container
          .read(evolutionSessionsProvider(kTestTemplateId).future);

      expect(result, hasLength(2));
      final first = result[0] as EvolutionSessionEntity;
      expect(first.id, 's1');
      expect(first.status, EvolutionSessionStatus.active);
      final second = result[1] as EvolutionSessionEntity;
      expect(second.id, 's2');
      expect(second.status, EvolutionSessionStatus.completed);
    });

    test('returns empty list when no sessions exist', () async {
      when(() => mockTemplateService.getEvolutionSessions(kTestTemplateId))
          .thenAnswer((_) async => []);

      final container = createEvolutionContainer();
      final result = await container
          .read(evolutionSessionsProvider(kTestTemplateId).future);

      expect(result, isEmpty);
    });

    test('refetches when agentUpdateStream emits for template', () async {
      final controller = StreamController<Set<String>>.broadcast();
      addTearDown(controller.close);

      final mockNotifications = MockUpdateNotifications();
      when(() => mockNotifications.updateStream)
          .thenAnswer((_) => controller.stream);
      when(() => mockNotifications.localUpdateStream)
          .thenAnswer((_) => const Stream.empty());

      await getIt.reset();
      getIt.registerSingleton<UpdateNotifications>(mockNotifications);
      addTearDown(getIt.reset);

      var fetchCount = 0;
      when(() => mockTemplateService.getEvolutionSessions(kTestTemplateId))
          .thenAnswer((_) async {
        fetchCount++;
        return [];
      });

      final container = ProviderContainer(
        overrides: [
          agentTemplateServiceProvider.overrideWithValue(mockTemplateService),
          agentServiceProvider.overrideWithValue(mockService),
          agentRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
      addTearDown(container.dispose);

      // Initial fetch.
      final sub = container.listen(
        evolutionSessionsProvider(kTestTemplateId),
        (_, __) {},
      );
      addTearDown(sub.close);
      await container.read(evolutionSessionsProvider(kTestTemplateId).future);
      expect(fetchCount, 1);

      // Fire update notification for the template.
      controller.add({kTestTemplateId});
      await pumpEventQueue();

      // Provider should have refetched.
      await container.read(evolutionSessionsProvider(kTestTemplateId).future);
      expect(fetchCount, 2);
    });
  });

  group('allAgentInstancesProvider', () {
    test('delegates to listAgents and casts result', () async {
      final agents = [makeTestIdentity(id: 'a1', agentId: 'a1')];
      when(() => mockService.listAgents()).thenAnswer((_) async => agents);

      final container = createContainer();
      final result = await container.read(allAgentInstancesProvider.future);

      expect(result, hasLength(1));
      expect((result[0] as AgentIdentityEntity).id, 'a1');
      verify(() => mockService.listAgents()).called(1);
    });

    test('returns empty list when no agents exist', () async {
      when(() => mockService.listAgents()).thenAnswer((_) async => []);

      final container = createContainer();
      final result = await container.read(allAgentInstancesProvider.future);

      expect(result, isEmpty);
    });
  });

  group('allEvolutionSessionsProvider', () {
    test('aggregates sessions across templates sorted by updatedAt', () async {
      final session1 = makeTestEvolutionSession(
        id: 's1',
        agentId: 'tpl-1',
        updatedAt: DateTime(2024, 3, 15, 10),
      );
      final session2 = makeTestEvolutionSession(
        id: 's2',
        agentId: 'tpl-2',
        updatedAt: DateTime(2024, 3, 15, 12),
      );
      when(() => mockRepository.getAllEvolutionSessions())
          .thenAnswer((_) async => [session2, session1]);

      final container = ProviderContainer(
        overrides: [
          agentRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(allEvolutionSessionsProvider.future);

      expect(result, hasLength(2));
      // Most recent first (returned pre-sorted by the query)
      expect((result[0] as EvolutionSessionEntity).id, 's2');
      expect((result[1] as EvolutionSessionEntity).id, 's1');
    });

    test('returns empty when no sessions exist', () async {
      when(() => mockRepository.getAllEvolutionSessions())
          .thenAnswer((_) async => []);

      final container = ProviderContainer(
        overrides: [
          agentRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(allEvolutionSessionsProvider.future);

      expect(result, isEmpty);
    });
  });

  group('modelIdForThreadProvider', () {
    test('returns model ID from template version', () async {
      final wakeRun = makeTestWakeRun(
        runKey: 'thread-abc',
        templateVersionId: 'ver-1',
      );
      when(() => mockRepository.getWakeRun('thread-abc'))
          .thenAnswer((_) async => wakeRun);

      final version = makeTestTemplateVersion(
        id: 'ver-1',
        modelId: 'models/gemini-3-pro',
      );
      when(() => mockRepository.getEntity('ver-1'))
          .thenAnswer((_) async => version);

      final container = createContainer();
      final result = await container.read(
        modelIdForThreadProvider(kTestAgentId, 'thread-abc').future,
      );

      expect(result, 'models/gemini-3-pro');
    });

    test('returns null when wake run not found', () async {
      when(() => mockRepository.getWakeRun('missing'))
          .thenAnswer((_) async => null);

      final container = createContainer();
      final result = await container.read(
        modelIdForThreadProvider(kTestAgentId, 'missing').future,
      );

      expect(result, isNull);
    });

    test('returns null when template version has no modelId', () async {
      final wakeRun = makeTestWakeRun(
        runKey: 'thread-no-model',
        templateVersionId: 'ver-2',
      );
      when(() => mockRepository.getWakeRun('thread-no-model'))
          .thenAnswer((_) async => wakeRun);

      final version = makeTestTemplateVersion(id: 'ver-2');
      when(() => mockRepository.getEntity('ver-2'))
          .thenAnswer((_) async => version);

      final container = createContainer();
      final result = await container.read(
        modelIdForThreadProvider(kTestAgentId, 'thread-no-model').future,
      );

      expect(result, isNull);
    });

    test('returns null when wake run has no templateVersionId', () async {
      final wakeRun = makeTestWakeRun(runKey: 'thread-no-ver');
      when(() => mockRepository.getWakeRun('thread-no-ver'))
          .thenAnswer((_) async => wakeRun);

      final container = createContainer();
      final result = await container.read(
        modelIdForThreadProvider(kTestAgentId, 'thread-no-ver').future,
      );

      expect(result, isNull);
    });
  });

  group('agentInitializationProvider — orphan cleanup', () {
    late MockWakeOrchestrator mockOrchestrator;
    late MockTaskAgentWorkflow mockWorkflow;
    late MockTaskAgentService mockTaskAgentService;
    late MockAgentTemplateService mockTemplateService;
    late MockAiConfigRepository mockAiConfigRepo;

    setUp(() async {
      await setUpTestGetIt();
      mockOrchestrator = MockWakeOrchestrator();
      mockWorkflow = MockTaskAgentWorkflow();
      mockTaskAgentService = MockTaskAgentService();
      mockTemplateService = MockAgentTemplateService();
      mockAiConfigRepo = MockAiConfigRepository();

      when(() => mockOrchestrator.start(any())).thenAnswer((_) async {});
      when(() => mockOrchestrator.stop()).thenAnswer((_) async {});
      when(() => mockTaskAgentService.restoreSubscriptions())
          .thenAnswer((_) async {});
      when(() => mockTemplateService.seedDefaults()).thenAnswer((_) async {});
      // Profile seeding stubs.
      when(() => mockAiConfigRepo.getConfigById(any()))
          .thenAnswer((_) async => null);
      when(() => mockAiConfigRepo.saveConfig(any())).thenAnswer((_) async {});
    });

    tearDown(tearDownTestGetIt);

    ProviderContainer createInitContainer() {
      final container = ProviderContainer(
        overrides: [
          agentServiceProvider.overrideWithValue(mockService),
          agentRepositoryProvider.overrideWithValue(mockRepository),
          wakeOrchestratorProvider.overrideWithValue(mockOrchestrator),
          taskAgentWorkflowProvider.overrideWithValue(mockWorkflow),
          taskAgentServiceProvider.overrideWithValue(mockTaskAgentService),
          agentTemplateServiceProvider.overrideWithValue(mockTemplateService),
          aiConfigRepositoryProvider.overrideWithValue(mockAiConfigRepo),
          configFlagProvider.overrideWith(
            (ref, flagName) => Stream.value(
              flagName == enableAgentsFlag,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('calls abandonOrphanedWakeRuns on startup', () async {
      when(() => mockRepository.abandonOrphanedWakeRuns())
          .thenAnswer((_) async => 0);

      final container = createInitContainer();
      final sub = container.listen(
        agentInitializationProvider,
        (_, __) {},
      );
      addTearDown(sub.close);

      await container.read(agentInitializationProvider.future);

      verify(() => mockRepository.abandonOrphanedWakeRuns()).called(1);
    });

    test('logs when orphaned runs are found', () async {
      when(() => mockRepository.abandonOrphanedWakeRuns())
          .thenAnswer((_) async => 3);

      final container = createInitContainer();
      final sub = container.listen(
        agentInitializationProvider,
        (_, __) {},
      );
      addTearDown(sub.close);

      // Should complete without error even when orphans exist.
      await container.read(agentInitializationProvider.future);

      verify(() => mockRepository.abandonOrphanedWakeRuns()).called(1);
    });
  });

  group('evolutionNotesProvider', () {
    late MockAgentTemplateService mockTemplateService;

    setUp(() {
      mockTemplateService = MockAgentTemplateService();
    });

    ProviderContainer createEvolutionContainer() {
      final container = ProviderContainer(
        overrides: [
          agentTemplateServiceProvider.overrideWithValue(mockTemplateService),
          agentServiceProvider.overrideWithValue(mockService),
          agentRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('delegates to getRecentEvolutionNotes', () async {
      final notes = [
        makeTestEvolutionNote(id: 'n1'),
        makeTestEvolutionNote(
          id: 'n2',
          kind: EvolutionNoteKind.decision,
        ),
        makeTestEvolutionNote(
          id: 'n3',
          kind: EvolutionNoteKind.pattern,
        ),
      ];
      when(() => mockTemplateService.getRecentEvolutionNotes(kTestTemplateId))
          .thenAnswer((_) async => notes);

      final container = createEvolutionContainer();
      final result =
          await container.read(evolutionNotesProvider(kTestTemplateId).future);

      expect(result, hasLength(3));
      final first = result[0] as EvolutionNoteEntity;
      expect(first.id, 'n1');
      expect(first.kind, EvolutionNoteKind.reflection);
      final second = result[1] as EvolutionNoteEntity;
      expect(second.kind, EvolutionNoteKind.decision);
      final third = result[2] as EvolutionNoteEntity;
      expect(third.kind, EvolutionNoteKind.pattern);
    });

    test('returns empty list when no notes exist', () async {
      when(() => mockTemplateService.getRecentEvolutionNotes(kTestTemplateId))
          .thenAnswer((_) async => []);

      final container = createEvolutionContainer();
      final result =
          await container.read(evolutionNotesProvider(kTestTemplateId).future);

      expect(result, isEmpty);
    });

    test('refetches when agentUpdateStream emits for template', () async {
      final controller = StreamController<Set<String>>.broadcast();
      addTearDown(controller.close);

      final mockNotifications = MockUpdateNotifications();
      when(() => mockNotifications.updateStream)
          .thenAnswer((_) => controller.stream);
      when(() => mockNotifications.localUpdateStream)
          .thenAnswer((_) => const Stream.empty());

      await getIt.reset();
      getIt.registerSingleton<UpdateNotifications>(mockNotifications);
      addTearDown(getIt.reset);

      var fetchCount = 0;
      when(() => mockTemplateService.getRecentEvolutionNotes(kTestTemplateId))
          .thenAnswer((_) async {
        fetchCount++;
        return [];
      });

      final container = ProviderContainer(
        overrides: [
          agentTemplateServiceProvider.overrideWithValue(mockTemplateService),
          agentServiceProvider.overrideWithValue(mockService),
          agentRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
      addTearDown(container.dispose);

      // Initial fetch.
      final sub = container.listen(
        evolutionNotesProvider(kTestTemplateId),
        (_, __) {},
      );
      addTearDown(sub.close);
      await container.read(evolutionNotesProvider(kTestTemplateId).future);
      expect(fetchCount, 1);

      // Fire update notification for the template.
      controller.add({kTestTemplateId});
      await pumpEventQueue();

      // Provider should have refetched.
      await container.read(evolutionNotesProvider(kTestTemplateId).future);
      expect(fetchCount, 2);
    });
  });

  group('agentInitializationProvider - SyncEventProcessor not registered', () {
    late MockWakeOrchestrator mockOrchestrator;
    late MockTaskAgentWorkflow mockWorkflow;
    late MockTaskAgentService mockTaskAgentService;
    late MockAgentTemplateService mockTemplateService;
    late MockAiConfigRepository mockAiConfigRepo;

    setUp(() async {
      await setUpTestGetIt();
      mockOrchestrator = MockWakeOrchestrator();
      mockWorkflow = MockTaskAgentWorkflow();
      mockTaskAgentService = MockTaskAgentService();
      mockTemplateService = MockAgentTemplateService();
      mockAiConfigRepo = MockAiConfigRepository();

      when(() => mockOrchestrator.start(any())).thenAnswer((_) async {});
      when(() => mockOrchestrator.stop()).thenAnswer((_) async {});
      when(() => mockTaskAgentService.restoreSubscriptions())
          .thenAnswer((_) async {});
      when(() => mockTemplateService.seedDefaults()).thenAnswer((_) async {});
      when(() => mockRepository.abandonOrphanedWakeRuns())
          .thenAnswer((_) async => 0);
      // Profile seeding stubs.
      when(() => mockAiConfigRepo.getConfigById(any()))
          .thenAnswer((_) async => null);
      when(() => mockAiConfigRepo.saveConfig(any())).thenAnswer((_) async {});
    });

    tearDown(tearDownTestGetIt);

    test('skips SyncEventProcessor when not registered in GetIt', () async {
      // Ensure SyncEventProcessor is NOT registered.
      expect(getIt.isRegistered<SyncEventProcessor>(), isFalse);

      final container = ProviderContainer(
        overrides: [
          agentServiceProvider.overrideWithValue(mockService),
          agentRepositoryProvider.overrideWithValue(mockRepository),
          wakeOrchestratorProvider.overrideWithValue(mockOrchestrator),
          taskAgentWorkflowProvider.overrideWithValue(mockWorkflow),
          taskAgentServiceProvider.overrideWithValue(mockTaskAgentService),
          agentTemplateServiceProvider.overrideWithValue(mockTemplateService),
          aiConfigRepositoryProvider.overrideWithValue(mockAiConfigRepo),
          configFlagProvider.overrideWith(
            (ref, flagName) => Stream.value(flagName == enableAgentsFlag),
          ),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(
        agentInitializationProvider,
        (_, __) {},
      );
      addTearDown(sub.close);

      // Should complete without error even without SyncEventProcessor.
      await container.read(agentInitializationProvider.future);

      verify(() => mockOrchestrator.start(any())).called(1);
      verify(() => mockTemplateService.seedDefaults()).called(1);
      verify(() => mockTaskAgentService.restoreSubscriptions()).called(1);
    });
  });

  group('agentTokenUsageSummariesProvider', () {
    const agentId = kTestAgentId;

    ProviderContainer createTokenContainer({
      required List<WakeTokenUsageEntity> records,
    }) {
      final repo = MockAgentRepository();
      when(() =>
              repo.getTokenUsageForAgent(agentId, limit: any(named: 'limit')))
          .thenAnswer((_) async => records);

      final container = ProviderContainer(
        overrides: [
          agentRepositoryProvider.overrideWithValue(repo),
          agentUpdateStreamProvider
              .overrideWith((ref, agentId) => const Stream.empty()),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('returns empty list when no records', () async {
      final container = createTokenContainer(records: []);
      final result = await container.read(
        agentTokenUsageSummariesProvider(agentId).future,
      );
      expect(result, isEmpty);
    });

    test('aggregates records by model', () async {
      final now = DateTime(2025, 6, 15);
      final container = createTokenContainer(
        records: [
          WakeTokenUsageEntity(
            id: 'u1',
            agentId: agentId,
            runKey: 'run-1',
            threadId: 't1',
            modelId: 'gemini-2.5-pro',
            createdAt: now,
            vectorClock: null,
            inputTokens: 100,
            outputTokens: 50,
            thoughtsTokens: 20,
            cachedInputTokens: 10,
          ),
          WakeTokenUsageEntity(
            id: 'u2',
            agentId: agentId,
            runKey: 'run-2',
            threadId: 't1',
            modelId: 'gemini-2.5-pro',
            createdAt: now,
            vectorClock: null,
            inputTokens: 200,
            outputTokens: 80,
            thoughtsTokens: 30,
            cachedInputTokens: 5,
          ),
          WakeTokenUsageEntity(
            id: 'u3',
            agentId: agentId,
            runKey: 'run-3',
            threadId: 't2',
            modelId: 'claude-sonnet',
            createdAt: now,
            vectorClock: null,
            inputTokens: 500,
            outputTokens: 100,
          ),
        ],
      );

      final result = await container.read(
        agentTokenUsageSummariesProvider(agentId).future,
      );

      expect(result, hasLength(2));

      // Sorted by totalTokens descending: claude-sonnet (600) > gemini (480)
      expect(result[0].modelId, 'claude-sonnet');
      expect(result[0].inputTokens, 500);
      expect(result[0].outputTokens, 100);
      expect(result[0].wakeCount, 1);

      expect(result[1].modelId, 'gemini-2.5-pro');
      expect(result[1].inputTokens, 300);
      expect(result[1].outputTokens, 130);
      expect(result[1].thoughtsTokens, 50);
      expect(result[1].cachedInputTokens, 15);
      expect(result[1].wakeCount, 2);
    });

    test('handles null token fields gracefully', () async {
      final now = DateTime(2025, 6, 15);
      final container = createTokenContainer(
        records: [
          WakeTokenUsageEntity(
            id: 'u1',
            agentId: agentId,
            runKey: 'run-1',
            threadId: 't1',
            modelId: 'model-a',
            createdAt: now,
            vectorClock: null,
            // All token fields null
          ),
        ],
      );

      final result = await container.read(
        agentTokenUsageSummariesProvider(agentId).future,
      );

      expect(result, hasLength(1));
      expect(result[0].inputTokens, 0);
      expect(result[0].outputTokens, 0);
      expect(result[0].thoughtsTokens, 0);
      expect(result[0].cachedInputTokens, 0);
      expect(result[0].wakeCount, 1);
    });
  });

  group('tokenUsageForThreadProvider', () {
    const agentId = kTestAgentId;

    ProviderContainer createThreadTokenContainer({
      required List<WakeTokenUsageEntity> records,
    }) {
      final repo = MockAgentRepository();
      when(() =>
              repo.getTokenUsageForAgent(agentId, limit: any(named: 'limit')))
          .thenAnswer((_) async => records);

      final container = ProviderContainer(
        overrides: [
          agentRepositoryProvider.overrideWithValue(repo),
          agentUpdateStreamProvider
              .overrideWith((ref, agentId) => const Stream.empty()),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('returns null when no records match threadId', () async {
      final now = DateTime(2025, 6, 15);
      final container = createThreadTokenContainer(
        records: [
          WakeTokenUsageEntity(
            id: 'u1',
            agentId: agentId,
            runKey: 'run-1',
            threadId: 'other-thread',
            modelId: 'gemini-2.5-pro',
            createdAt: now,
            vectorClock: null,
            inputTokens: 100,
            outputTokens: 50,
          ),
        ],
      );
      final result = await container.read(
        tokenUsageForThreadProvider(agentId, 'my-thread').future,
      );
      expect(result, isNull);
    });

    test('returns null when no records at all', () async {
      final container = createThreadTokenContainer(records: []);
      final result = await container.read(
        tokenUsageForThreadProvider(agentId, 'my-thread').future,
      );
      expect(result, isNull);
    });

    test('aggregates records for matching threadId', () async {
      final now = DateTime(2025, 6, 15);
      final container = createThreadTokenContainer(
        records: [
          WakeTokenUsageEntity(
            id: 'u1',
            agentId: agentId,
            runKey: 'run-1',
            threadId: 'target-thread',
            modelId: 'gemini-2.5-pro',
            createdAt: now,
            vectorClock: null,
            inputTokens: 100,
            outputTokens: 50,
            thoughtsTokens: 20,
            cachedInputTokens: 10,
          ),
          WakeTokenUsageEntity(
            id: 'u2',
            agentId: agentId,
            runKey: 'run-2',
            threadId: 'target-thread',
            modelId: 'gemini-2.5-pro',
            createdAt: now,
            vectorClock: null,
            inputTokens: 200,
            outputTokens: 80,
            thoughtsTokens: 30,
            cachedInputTokens: 5,
          ),
          // Different thread — should be excluded
          WakeTokenUsageEntity(
            id: 'u3',
            agentId: agentId,
            runKey: 'run-3',
            threadId: 'other-thread',
            modelId: 'claude-sonnet',
            createdAt: now,
            vectorClock: null,
            inputTokens: 999,
            outputTokens: 999,
          ),
        ],
      );

      final result = await container.read(
        tokenUsageForThreadProvider(agentId, 'target-thread').future,
      );

      expect(result, isNotNull);
      expect(result!.modelId, 'gemini-2.5-pro');
      expect(result.inputTokens, 300);
      expect(result.outputTokens, 130);
      expect(result.thoughtsTokens, 50);
      expect(result.cachedInputTokens, 15);
      expect(result.wakeCount, 2);
      expect(result.totalTokens, 480);
    });

    test('handles null token fields gracefully', () async {
      final now = DateTime(2025, 6, 15);
      final container = createThreadTokenContainer(
        records: [
          WakeTokenUsageEntity(
            id: 'u1',
            agentId: agentId,
            runKey: 'run-1',
            threadId: 'null-thread',
            modelId: 'model-a',
            createdAt: now,
            vectorClock: null,
            // All token fields null
          ),
        ],
      );

      final result = await container.read(
        tokenUsageForThreadProvider(agentId, 'null-thread').future,
      );

      expect(result, isNotNull);
      expect(result!.inputTokens, 0);
      expect(result.outputTokens, 0);
      expect(result.thoughtsTokens, 0);
      expect(result.cachedInputTokens, 0);
      expect(result.wakeCount, 1);
    });
  });

  group('templateTokenUsageSummariesProvider', () {
    ProviderContainer createTemplateTokenContainer({
      required List<WakeTokenUsageEntity> records,
    }) {
      final repo = MockAgentRepository();
      when(
        () => repo.getTokenUsageForTemplate(
          kTestTemplateId,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => records);

      final container = ProviderContainer(
        overrides: [
          agentRepositoryProvider.overrideWithValue(repo),
          agentUpdateStreamProvider
              .overrideWith((ref, agentId) => const Stream.empty()),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('returns empty list when no records', () async {
      final container = createTemplateTokenContainer(records: []);
      final result = await container.read(
        templateTokenUsageSummariesProvider(kTestTemplateId).future,
      );
      expect(result, isEmpty);
    });

    test('aggregates records across multiple instances by model', () async {
      final now = DateTime(2025, 6, 15);
      final container = createTemplateTokenContainer(
        records: [
          WakeTokenUsageEntity(
            id: 'u1',
            agentId: 'agent-a',
            runKey: 'run-1',
            threadId: 't1',
            modelId: 'gemini-2.5-pro',
            createdAt: now,
            vectorClock: null,
            inputTokens: 100,
            outputTokens: 50,
            thoughtsTokens: 20,
            cachedInputTokens: 10,
          ),
          WakeTokenUsageEntity(
            id: 'u2',
            agentId: 'agent-b',
            runKey: 'run-2',
            threadId: 't2',
            modelId: 'gemini-2.5-pro',
            createdAt: now,
            vectorClock: null,
            inputTokens: 200,
            outputTokens: 80,
            thoughtsTokens: 30,
            cachedInputTokens: 5,
          ),
          WakeTokenUsageEntity(
            id: 'u3',
            agentId: 'agent-a',
            runKey: 'run-3',
            threadId: 't3',
            modelId: 'claude-sonnet',
            createdAt: now,
            vectorClock: null,
            inputTokens: 500,
            outputTokens: 100,
          ),
        ],
      );

      final result = await container.read(
        templateTokenUsageSummariesProvider(kTestTemplateId).future,
      );

      expect(result, hasLength(2));

      // Sorted by totalTokens descending: claude-sonnet (600) > gemini (480)
      expect(result[0].modelId, 'claude-sonnet');
      expect(result[0].inputTokens, 500);
      expect(result[0].outputTokens, 100);
      expect(result[0].wakeCount, 1);

      expect(result[1].modelId, 'gemini-2.5-pro');
      expect(result[1].inputTokens, 300);
      expect(result[1].outputTokens, 130);
      expect(result[1].thoughtsTokens, 50);
      expect(result[1].cachedInputTokens, 15);
      expect(result[1].wakeCount, 2);
    });

    test('sorts by totalTokens descending', () async {
      final now = DateTime(2025, 6, 15);
      final container = createTemplateTokenContainer(
        records: [
          WakeTokenUsageEntity(
            id: 'u1',
            agentId: 'agent-a',
            runKey: 'run-1',
            threadId: 't1',
            modelId: 'small-model',
            createdAt: now,
            vectorClock: null,
            inputTokens: 10,
            outputTokens: 5,
          ),
          WakeTokenUsageEntity(
            id: 'u2',
            agentId: 'agent-a',
            runKey: 'run-2',
            threadId: 't2',
            modelId: 'big-model',
            createdAt: now,
            vectorClock: null,
            inputTokens: 1000,
            outputTokens: 500,
          ),
          WakeTokenUsageEntity(
            id: 'u3',
            agentId: 'agent-a',
            runKey: 'run-3',
            threadId: 't3',
            modelId: 'medium-model',
            createdAt: now,
            vectorClock: null,
            inputTokens: 100,
            outputTokens: 50,
          ),
        ],
      );

      final result = await container.read(
        templateTokenUsageSummariesProvider(kTestTemplateId).future,
      );

      expect(result, hasLength(3));
      expect(result[0].modelId, 'big-model');
      expect(result[1].modelId, 'medium-model');
      expect(result[2].modelId, 'small-model');
    });

    test('handles null token fields', () async {
      final now = DateTime(2025, 6, 15);
      final container = createTemplateTokenContainer(
        records: [
          WakeTokenUsageEntity(
            id: 'u1',
            agentId: 'agent-a',
            runKey: 'run-1',
            threadId: 't1',
            modelId: 'model-a',
            createdAt: now,
            vectorClock: null,
            // All token fields null
          ),
        ],
      );

      final result = await container.read(
        templateTokenUsageSummariesProvider(kTestTemplateId).future,
      );

      expect(result, hasLength(1));
      expect(result[0].inputTokens, 0);
      expect(result[0].outputTokens, 0);
      expect(result[0].thoughtsTokens, 0);
      expect(result[0].cachedInputTokens, 0);
      expect(result[0].wakeCount, 1);
    });
  });

  group('templateInstanceTokenBreakdownProvider', () {
    ProviderContainer createBreakdownContainer({
      required List<WakeTokenUsageEntity> records,
      required List<AgentIdentityEntity> agents,
    }) {
      final repo = MockAgentRepository();
      when(
        () => repo.getTokenUsageForTemplate(
          kTestTemplateId,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => records);

      final templateService = MockAgentTemplateService();
      when(() => templateService.getAgentsForTemplate(kTestTemplateId))
          .thenAnswer((_) async => agents);

      final container = ProviderContainer(
        overrides: [
          agentRepositoryProvider.overrideWithValue(repo),
          agentTemplateServiceProvider.overrideWithValue(templateService),
          agentUpdateStreamProvider
              .overrideWith((ref, agentId) => const Stream.empty()),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('returns empty list for template with no instances', () async {
      final container = createBreakdownContainer(
        records: [],
        agents: [],
      );

      final result = await container.read(
        templateInstanceTokenBreakdownProvider(kTestTemplateId).future,
      );

      expect(result, isEmpty);
    });

    test('groups records by instance and by model within each instance',
        () async {
      final now = DateTime(2025, 6, 15);
      final agentA = makeTestIdentity(
        id: 'agent-a',
        agentId: 'agent-a',
        displayName: 'Agent A',
      );
      final agentB = makeTestIdentity(
        id: 'agent-b',
        agentId: 'agent-b',
        displayName: 'Agent B',
      );

      final container = createBreakdownContainer(
        records: [
          WakeTokenUsageEntity(
            id: 'u1',
            agentId: 'agent-a',
            runKey: 'run-1',
            threadId: 't1',
            modelId: 'gemini-2.5-pro',
            createdAt: now,
            vectorClock: null,
            inputTokens: 100,
            outputTokens: 50,
          ),
          WakeTokenUsageEntity(
            id: 'u2',
            agentId: 'agent-a',
            runKey: 'run-2',
            threadId: 't2',
            modelId: 'claude-sonnet',
            createdAt: now,
            vectorClock: null,
            inputTokens: 200,
            outputTokens: 100,
          ),
          WakeTokenUsageEntity(
            id: 'u3',
            agentId: 'agent-b',
            runKey: 'run-3',
            threadId: 't3',
            modelId: 'gemini-2.5-pro',
            createdAt: now,
            vectorClock: null,
            inputTokens: 50,
            outputTokens: 25,
          ),
        ],
        agents: [agentA, agentB],
      );

      final result = await container.read(
        templateInstanceTokenBreakdownProvider(kTestTemplateId).future,
      );

      expect(result, hasLength(2));

      // Agent A has more tokens (150+300=450) than Agent B (75)
      expect(result[0].agentId, 'agent-a');
      expect(result[0].displayName, 'Agent A');
      expect(result[0].summaries, hasLength(2));
      expect(result[0].totalTokens, 450);

      expect(result[1].agentId, 'agent-b');
      expect(result[1].displayName, 'Agent B');
      expect(result[1].summaries, hasLength(1));
      expect(result[1].totalTokens, 75);
    });

    test('sorts instances by totalTokens descending', () async {
      final now = DateTime(2025, 6, 15);
      final agentSmall = makeTestIdentity(
        id: 'agent-small',
        agentId: 'agent-small',
        displayName: 'Small Agent',
      );
      final agentBig = makeTestIdentity(
        id: 'agent-big',
        agentId: 'agent-big',
        displayName: 'Big Agent',
      );

      final container = createBreakdownContainer(
        records: [
          WakeTokenUsageEntity(
            id: 'u1',
            agentId: 'agent-small',
            runKey: 'run-1',
            threadId: 't1',
            modelId: 'model-a',
            createdAt: now,
            vectorClock: null,
            inputTokens: 10,
            outputTokens: 5,
          ),
          WakeTokenUsageEntity(
            id: 'u2',
            agentId: 'agent-big',
            runKey: 'run-2',
            threadId: 't2',
            modelId: 'model-a',
            createdAt: now,
            vectorClock: null,
            inputTokens: 1000,
            outputTokens: 500,
          ),
        ],
        agents: [agentSmall, agentBig],
      );

      final result = await container.read(
        templateInstanceTokenBreakdownProvider(kTestTemplateId).future,
      );

      expect(result, hasLength(2));
      expect(result[0].agentId, 'agent-big');
      expect(result[0].totalTokens, 1500);
      expect(result[1].agentId, 'agent-small');
      expect(result[1].totalTokens, 15);
    });

    test('includes instances with no token records (with empty summaries)',
        () async {
      final agentWithTokens = makeTestIdentity(
        id: 'agent-with',
        agentId: 'agent-with',
        displayName: 'With Tokens',
      );
      final agentWithout = makeTestIdentity(
        id: 'agent-without',
        agentId: 'agent-without',
        displayName: 'Without Tokens',
      );
      final now = DateTime(2025, 6, 15);

      final container = createBreakdownContainer(
        records: [
          WakeTokenUsageEntity(
            id: 'u1',
            agentId: 'agent-with',
            runKey: 'run-1',
            threadId: 't1',
            modelId: 'model-a',
            createdAt: now,
            vectorClock: null,
            inputTokens: 100,
            outputTokens: 50,
          ),
        ],
        agents: [agentWithTokens, agentWithout],
      );

      final result = await container.read(
        templateInstanceTokenBreakdownProvider(kTestTemplateId).future,
      );

      expect(result, hasLength(2));

      // Agent with tokens sorted first (150 > 0)
      expect(result[0].agentId, 'agent-with');
      expect(result[0].totalTokens, 150);
      expect(result[0].summaries, hasLength(1));

      expect(result[1].agentId, 'agent-without');
      expect(result[1].totalTokens, 0);
      expect(result[1].summaries, isEmpty);
    });

    test('returns all instances with empty summaries when no records exist',
        () async {
      final agentA = makeTestIdentity(
        id: 'agent-a',
        agentId: 'agent-a',
        displayName: 'Agent A',
      );
      final agentB = makeTestIdentity(
        id: 'agent-b',
        agentId: 'agent-b',
        displayName: 'Agent B',
      );

      final container = createBreakdownContainer(
        records: [],
        agents: [agentA, agentB],
      );

      final result = await container.read(
        templateInstanceTokenBreakdownProvider(kTestTemplateId).future,
      );

      expect(result, hasLength(2));
      expect(
        result.map((r) => r.agentId),
        containsAll(<String>['agent-a', 'agent-b']),
      );
      for (final breakdown in result) {
        expect(breakdown.totalTokens, 0);
        expect(breakdown.summaries, isEmpty);
      }
    });
  });

  group('templateRecentReportsProvider', () {
    test('returns reports from repository', () async {
      final report1 = makeTestReport(
        id: 'report-1',
        agentId: 'agent-a',
        content: 'First report',
      );
      final report2 = makeTestReport(
        id: 'report-2',
        agentId: 'agent-b',
        content: 'Second report',
      );

      final repo = MockAgentRepository();
      when(
        () => repo.getRecentReportsByTemplate(
          kTestTemplateId,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [report1, report2]);

      final container = ProviderContainer(
        overrides: [
          agentRepositoryProvider.overrideWithValue(repo),
          agentUpdateStreamProvider
              .overrideWith((ref, agentId) => const Stream.empty()),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        templateRecentReportsProvider(kTestTemplateId).future,
      );

      expect(result, hasLength(2));
      expect((result[0] as AgentReportEntity).id, 'report-1');
      expect((result[1] as AgentReportEntity).id, 'report-2');
    });

    test('returns empty list when no reports', () async {
      final repo = MockAgentRepository();
      when(
        () => repo.getRecentReportsByTemplate(
          kTestTemplateId,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => []);

      final container = ProviderContainer(
        overrides: [
          agentRepositoryProvider.overrideWithValue(repo),
          agentUpdateStreamProvider
              .overrideWith((ref, agentId) => const Stream.empty()),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        templateRecentReportsProvider(kTestTemplateId).future,
      );

      expect(result, isEmpty);
    });
  });
}
