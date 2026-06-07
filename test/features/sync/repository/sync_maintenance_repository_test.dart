import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/models/sync_models.dart';
import 'package:lotti/features/sync/repository/sync_maintenance_repository.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  late MockJournalDb mockJournalDb;
  late MockOutboxService mockOutboxService;
  late MockDomainLogger mockLoggingService;
  late MockAiConfigRepository mockAiConfigRepository;
  late MockAgentRepository mockAgentRepository;
  late MockVectorClockService mockVectorClockService;
  late SyncMaintenanceRepository syncMaintenanceRepository;

  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
    registerFallbackValue(fallbackSyncMessage);
    registerFallbackValue(Exception('fallback'));
    registerFallbackValue(const VectorClock({}));
    registerFallbackValue(
      AgentDomainEntity.agent(
        id: 'fallback',
        agentId: 'fallback',
        kind: 'task_agent',
        displayName: 'fallback',
        lifecycle: AgentLifecycle.active,
        mode: AgentInteractionMode.autonomous,
        allowedCategoryIds: const {},
        currentStateId: '',
        config: const AgentConfig(),
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        vectorClock: null,
      ),
    );
    registerFallbackValue(
      AgentLink.agentTask(
        id: 'fallback',
        fromId: 'fallback',
        toId: 'fallback',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        vectorClock: null,
      ),
    );
  });

  setUp(() {
    mockJournalDb = MockJournalDb();
    mockOutboxService = MockOutboxService();
    mockLoggingService = MockDomainLogger();
    mockAiConfigRepository = MockAiConfigRepository();
    mockAgentRepository = MockAgentRepository();
    mockVectorClockService = MockVectorClockService();

    when(
      () => mockLoggingService.error(
        any<LogDomain>(),
        any<Object>(),
        stackTrace: any<StackTrace>(named: 'stackTrace'),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenAnswer((_) async {});

    syncMaintenanceRepository = SyncMaintenanceRepository(
      journalDb: mockJournalDb,
      outboxService: mockOutboxService,
      loggingService: mockLoggingService,
      aiConfigRepository: mockAiConfigRepository,
      agentRepository: mockAgentRepository,
      vectorClockService: mockVectorClockService,
    );
  });

  group('SyncMaintenanceRepository - Original Tests', () {
    // The four entity-definition sync methods share one shape: read all
    // rows, skip deleted ones, enqueue an update SyncMessage per active
    // row. One spec per method drives both tests below.
    final entitySyncSpecs =
        <
          ({
            String name,
            void Function(List<EntityDefinition> rows) stubRows,
            Future<void> Function() callSync,
            EntityDefinition Function(String id, {DateTime? deletedAt}) make,
          })
        >[
          (
            name: 'measurables',
            stubRows: (rows) => when(
              () => mockJournalDb.getAllMeasurableDataTypes(),
            ).thenAnswer((_) async => rows.cast<MeasurableDataType>()),
            callSync: () => syncMaintenanceRepository.syncMeasurables(),
            make: (id, {deletedAt}) =>
                FakeMeasurableDataType(id: id, deletedAt: deletedAt),
          ),
          (
            name: 'categories',
            stubRows: (rows) => when(
              () => mockJournalDb.getAllCategories(),
            ).thenAnswer((_) async => rows.cast<CategoryDefinition>()),
            callSync: () => syncMaintenanceRepository.syncCategories(),
            make: (id, {deletedAt}) =>
                FakeCategoryDefinition(id: id, deletedAt: deletedAt),
          ),
          (
            name: 'dashboards',
            stubRows: (rows) => when(
              () => mockJournalDb.getAllDashboards(),
            ).thenAnswer((_) async => rows.cast<DashboardDefinition>()),
            callSync: () => syncMaintenanceRepository.syncDashboards(),
            make: (id, {deletedAt}) =>
                FakeDashboardDefinition(id: id, deletedAt: deletedAt),
          ),
          (
            name: 'habits',
            stubRows: (rows) => when(
              () => mockJournalDb.getAllHabitDefinitions(),
            ).thenAnswer((_) async => rows.cast<HabitDefinition>()),
            callSync: () => syncMaintenanceRepository.syncHabits(),
            make: (id, {deletedAt}) =>
                FakeHabitDefinition(id: id, deletedAt: deletedAt),
          ),
        ];

    String? capturedEntityId(SyncMessage message) =>
        message.mapOrNull(entityDefinition: (s) => s.entityDefinition.id);

    for (final spec in entitySyncSpecs) {
      test('sync ${spec.name}: enqueues active rows as updates', () async {
        final active = spec.make('1');
        spec.stubRows([active]);
        when(
          () => mockOutboxService.enqueueMessage(any()),
        ).thenAnswer((_) async {});

        await spec.callSync();

        final captured = verify(
          () => mockOutboxService.enqueueMessage(captureAny()),
        ).captured;
        expect(captured.length, 1);
        final capturedMessage = captured.first as SyncMessage;
        expect(capturedEntityId(capturedMessage), active.id);
        expect(
          capturedMessage.mapOrNull(entityDefinition: (s) => s.status),
          SyncEntryStatus.update,
        );
      });

      test('sync ${spec.name}: skips deleted rows', () async {
        final deleted = spec.make(
          '2',
          deletedAt: DateTime(2024, 3, 15, 10, 30),
        );
        final active = spec.make('3');
        spec.stubRows([deleted, active]);
        when(
          () => mockOutboxService.enqueueMessage(any()),
        ).thenAnswer((_) async {});

        await spec.callSync();

        final captured = verify(
          () => mockOutboxService.enqueueMessage(captureAny()),
        ).captured;
        expect(captured.length, 1);
        expect(capturedEntityId(captured.first as SyncMessage), active.id);
        for (final msg in captured) {
          expect(capturedEntityId(msg as SyncMessage), isNot(deleted.id));
        }
      });
    }

    test('syncAiSettings enqueues active AI configs for sync', () async {
      final createdAt = DateTime(2024, 3, 15, 10, 30);
      final provider = AiConfig.inferenceProvider(
        id: 'provider-1',
        baseUrl: 'https://example.com',
        apiKey: 'secret',
        name: 'Provider',
        createdAt: createdAt,
        inferenceProviderType: InferenceProviderType.openAi,
      );
      final model = AiConfig.model(
        id: 'model-1',
        name: 'Model',
        providerModelId: 'gpt',
        inferenceProviderId: provider.id,
        createdAt: createdAt,
        inputModalities: const [Modality.text],
        outputModalities: const [Modality.text],
        isReasoningModel: false,
      );
      final prompt = AiConfig.prompt(
        id: 'prompt-1',
        name: 'Prompt',
        systemMessage: 'system',
        userMessage: 'user',
        defaultModelId: model.id,
        modelIds: const ['model-1'],
        createdAt: createdAt,
        useReasoning: false,
        requiredInputData: const <InputDataType>[],
        // ignore: deprecated_member_use_from_same_package
        aiResponseType: AiResponseType.taskSummary,
      );

      when(
        () => mockAiConfigRepository.getConfigsByType(
          AiConfigType.inferenceProvider,
        ),
      ).thenAnswer((_) async => [provider]);
      when(
        () => mockAiConfigRepository.getConfigsByType(AiConfigType.model),
      ).thenAnswer((_) async => [model]);
      when(
        () => mockAiConfigRepository.getConfigsByType(AiConfigType.prompt),
      ).thenAnswer((_) async => [prompt]);
      when(
        () => mockOutboxService.enqueueMessage(any()),
      ).thenAnswer((_) async {});

      await syncMaintenanceRepository.syncAiSettings();

      final captured = verify(
        () => mockOutboxService.enqueueMessage(captureAny()),
      ).captured;
      expect(captured.length, 3);

      expect(
        captured
            .whereType<SyncMessage>()
            .where(
              (message) => message.maybeMap(
                aiConfig: (config) => config.aiConfig == provider,
                orElse: () => false,
              ),
            )
            .length,
        1,
      );
      expect(
        captured
            .whereType<SyncMessage>()
            .where(
              (message) => message.maybeMap(
                aiConfig: (config) => config.aiConfig == model,
                orElse: () => false,
              ),
            )
            .length,
        1,
      );
      expect(
        captured
            .whereType<SyncMessage>()
            .where(
              (message) => message.maybeMap(
                aiConfig: (config) => config.aiConfig == prompt,
                orElse: () => false,
              ),
            )
            .length,
        1,
      );
    });

    test('syncAiSettings logs and skips when fetching configs fails', () async {
      final exception = Exception('db failure');

      // The provider fetch throws synchronously while the Future.wait list
      // literal is still being built, so the model/prompt fetches are never
      // reached — no stubs for them.
      when(
        () => mockAiConfigRepository.getConfigsByType(
          AiConfigType.inferenceProvider,
        ),
      ).thenThrow(exception);

      await expectLater(
        syncMaintenanceRepository.syncAiSettings(),
        throwsA(exception),
      );

      verify(
        () => mockLoggingService.error(
          LogDomain.sync,
          exception,
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: 'syncAiSettings_fetch',
        ),
      ).called(1);
      verifyNever(() => mockOutboxService.enqueueMessage(any()));
    });
  });

  group('SyncMaintenanceRepository - Labels', () {
    test('syncLabels enqueues label definitions for sync', () async {
      final label = LabelDefinition(
        id: 'lab-1',
        name: 'Label1',
        color: '#ffffff',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        vectorClock: null,
        private: false,
      );
      when(
        () => mockJournalDb.getAllLabelDefinitions(),
      ).thenAnswer((_) async => [label]);
      when(
        () => mockOutboxService.enqueueMessage(any()),
      ).thenAnswer((_) async {});

      await syncMaintenanceRepository.syncLabels();

      final captured = verify(
        () => mockOutboxService.enqueueMessage(captureAny()),
      ).captured;
      expect(captured.length, 1);
      final capturedMessage = captured.first as SyncMessage;
      expect(
        capturedMessage.mapOrNull(
          entityDefinition: (s) => (s.entityDefinition as LabelDefinition).id,
        ),
        label.id,
      );
      expect(
        capturedMessage.mapOrNull(entityDefinition: (s) => s.status),
        SyncEntryStatus.update,
      );
    });

    test('syncLabels filters deleted labels (deletedAt != null)', () async {
      final deleted = LabelDefinition(
        id: 'lab-del',
        name: 'X',
        color: '#ffffff',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        vectorClock: null,
        private: false,
        deletedAt: DateTime(2024),
      );
      final active = LabelDefinition(
        id: 'lab-ok',
        name: 'Y',
        color: '#000000',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        vectorClock: null,
        private: false,
      );

      when(
        () => mockJournalDb.getAllLabelDefinitions(),
      ).thenAnswer((_) async => [deleted, active]);
      when(
        () => mockOutboxService.enqueueMessage(any()),
      ).thenAnswer((_) async {});

      await syncMaintenanceRepository.syncLabels();

      final messages = verify(
        () => mockOutboxService.enqueueMessage(captureAny()),
      ).captured;
      expect(messages.length, 1);
      final first = messages.first as SyncMessage;
      final id = first.mapOrNull(
        entityDefinition: (s) => (s.entityDefinition as LabelDefinition).id,
      );
      expect(id, 'lab-ok');
    });
  });

  group('SyncMaintenanceRepository - Logging Tests', () {
    final testException = Exception('Test DB Error');

    group('syncMeasurables', () {
      test('should log and rethrow exception when db fails', () async {
        when(
          () => mockJournalDb.getAllMeasurableDataTypes(),
        ).thenThrow(testException);

        await expectLater(
          () => syncMaintenanceRepository.syncMeasurables(),
          throwsA(testException),
        );

        verify(
          () => mockLoggingService.error(
            LogDomain.sync,
            testException,
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'syncMeasurables',
          ),
        ).called(1);
      });
    });

    group('syncLabels', () {
      test('should log and rethrow exception when db fails', () async {
        when(
          () => mockJournalDb.getAllLabelDefinitions(),
        ).thenThrow(testException);

        await expectLater(
          () => syncMaintenanceRepository.syncLabels(),
          throwsA(testException),
        );

        verify(
          () => mockLoggingService.error(
            LogDomain.sync,
            testException,
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'syncLabels',
          ),
        ).called(1);
      });
    });

    group('syncCategories', () {
      test('should log and rethrow exception when db fails', () async {
        when(() => mockJournalDb.getAllCategories()).thenThrow(testException);

        await expectLater(
          () => syncMaintenanceRepository.syncCategories(),
          throwsA(testException),
        );

        verify(
          () => mockLoggingService.error(
            LogDomain.sync,
            testException,
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'syncCategories',
          ),
        ).called(1);
      });
    });

    group('syncDashboards', () {
      test('should log and rethrow exception when db fails', () async {
        when(() => mockJournalDb.getAllDashboards()).thenThrow(testException);

        await expectLater(
          () => syncMaintenanceRepository.syncDashboards(),
          throwsA(testException),
        );

        verify(
          () => mockLoggingService.error(
            LogDomain.sync,
            testException,
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'syncDashboards',
          ),
        ).called(1);
      });
    });

    group('syncHabits', () {
      test('should log and rethrow exception when db fails', () async {
        when(
          () => mockJournalDb.getAllHabitDefinitions(),
        ).thenThrow(testException);

        await expectLater(
          () => syncMaintenanceRepository.syncHabits(),
          throwsA(testException),
        );

        verify(
          () => mockLoggingService.error(
            LogDomain.sync,
            testException,
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'syncHabits',
          ),
        ).called(1);
      });
    });

    // The four agent-related methods route through the same
    // _runWithLogging / _runOperation error funnel — one spec each.
    final agentErrorSpecs =
        <
          ({
            String subDomain,
            void Function() stubThrow,
            Future<void> Function() call,
          })
        >[
          (
            subDomain: 'syncAgentEntities',
            stubThrow: () => when(
              () => mockAgentRepository.getAllEntities(),
            ).thenThrow(testException),
            call: () => syncMaintenanceRepository.syncAgentEntities(),
          ),
          (
            subDomain: 'syncAgentLinks',
            stubThrow: () => when(
              () => mockAgentRepository.getAllLinks(),
            ).thenThrow(testException),
            call: () => syncMaintenanceRepository.syncAgentLinks(),
          ),
          (
            subDomain: 'backfillAgentEntityClocks',
            stubThrow: () => when(
              () => mockAgentRepository.getEntitiesWithNullVectorClock(),
            ).thenThrow(testException),
            call: () => syncMaintenanceRepository.backfillAgentEntityClocks(),
          ),
          (
            subDomain: 'backfillAgentLinkClocks',
            stubThrow: () => when(
              () => mockAgentRepository.getLinksWithNullVectorClock(),
            ).thenThrow(testException),
            call: () => syncMaintenanceRepository.backfillAgentLinkClocks(),
          ),
        ];

    for (final spec in agentErrorSpecs) {
      group(spec.subDomain, () {
        test(
          'should log and rethrow exception when repository fails',
          () async {
            spec.stubThrow();

            await expectLater(spec.call, throwsA(testException));

            verify(
              () => mockLoggingService.error(
                LogDomain.sync,
                testException,
                stackTrace: any<StackTrace>(named: 'stackTrace'),
                subDomain: spec.subDomain,
              ),
            ).called(1);
          },
        );
      });
    }
  });

  group('fetchTotalsForSteps', () {
    test('returns empty map when no steps provided', () async {
      final totals = await syncMaintenanceRepository.fetchTotalsForSteps({});

      expect(totals, isEmpty);
      verifyZeroInteractions(mockAiConfigRepository);
    });

    test(
      'SyncStep.complete contributes a 0 total without touching any '
      'repository',
      () async {
        final totals = await syncMaintenanceRepository.fetchTotalsForSteps({
          SyncStep.complete,
        });

        expect(totals, {SyncStep.complete: 0});
        verifyNever(() => mockJournalDb.getAllMeasurableDataTypes());
        verifyNever(() => mockJournalDb.getAllLabelDefinitions());
        verifyNever(() => mockJournalDb.getAllCategories());
        verifyNever(() => mockJournalDb.getAllDashboards());
        verifyNever(() => mockJournalDb.getAllHabitDefinitions());
        verifyNever(
          () => mockAiConfigRepository.getConfigsByType(
            AiConfigType.inferenceProvider,
          ),
        );
      },
    );

    test('returns totals for each requested step', () async {
      when(
        () => mockJournalDb.getAllMeasurableDataTypes(),
      ).thenAnswer((_) async => [FakeMeasurableDataType(id: 'm-1')]);
      when(
        () => mockJournalDb.getAllCategories(),
      ).thenAnswer((_) async => [FakeCategoryDefinition(id: 'c-1')]);
      when(
        () => mockJournalDb.getAllDashboards(),
      ).thenAnswer((_) async => [FakeDashboardDefinition(id: 'd-1')]);
      when(() => mockJournalDb.getAllHabitDefinitions()).thenAnswer(
        (_) async => [
          FakeHabitDefinition(id: 'h-1'),
          FakeHabitDefinition(id: 'h-2'),
        ],
      );

      final providerConfig = AiConfig.inferenceProvider(
        id: 'provider',
        baseUrl: 'https://example.com',
        apiKey: 'key',
        name: 'Provider',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.openAi,
      );
      final modelConfig = AiConfig.model(
        id: 'model',
        name: 'Model',
        providerModelId: 'provider-model',
        inferenceProviderId: providerConfig.id,
        createdAt: DateTime(2024),
        inputModalities: const [Modality.text],
        outputModalities: const [Modality.text],
        isReasoningModel: false,
      );
      final promptConfig = AiConfig.prompt(
        id: 'prompt',
        name: 'Prompt',
        systemMessage: 'system',
        userMessage: 'user',
        defaultModelId: modelConfig.id,
        modelIds: const ['model'],
        createdAt: DateTime(2024),
        useReasoning: false,
        requiredInputData: const [],
        // ignore: deprecated_member_use_from_same_package
        aiResponseType: AiResponseType.taskSummary,
      );

      when(
        () => mockAiConfigRepository.getConfigsByType(
          AiConfigType.inferenceProvider,
        ),
      ).thenAnswer((_) async => [providerConfig]);
      when(
        () => mockAiConfigRepository.getConfigsByType(AiConfigType.model),
      ).thenAnswer((_) async => [modelConfig]);
      when(
        () => mockAiConfigRepository.getConfigsByType(AiConfigType.prompt),
      ).thenAnswer((_) async => [promptConfig]);

      final totals = await syncMaintenanceRepository.fetchTotalsForSteps({
        SyncStep.measurables,
        SyncStep.categories,
        SyncStep.dashboards,
        SyncStep.habits,
        SyncStep.aiSettings,
      });

      expect(totals, {
        SyncStep.measurables: 1,
        SyncStep.categories: 1,
        SyncStep.dashboards: 1,
        SyncStep.habits: 2,
        SyncStep.aiSettings: 3,
      });

      verify(() => mockJournalDb.getAllMeasurableDataTypes()).called(1);
      verify(() => mockJournalDb.getAllCategories()).called(1);
      verify(() => mockJournalDb.getAllDashboards()).called(1);
      verify(() => mockJournalDb.getAllHabitDefinitions()).called(1);
      verify(
        () => mockAiConfigRepository.getConfigsByType(
          AiConfigType.inferenceProvider,
        ),
      ).called(1);
      verify(
        () => mockAiConfigRepository.getConfigsByType(AiConfigType.model),
      ).called(1);
      verify(
        () => mockAiConfigRepository.getConfigsByType(AiConfigType.prompt),
      ).called(1);
    });
  });

  group('syncAgentEntities', () {
    test('enqueues all agent entities for sync', () async {
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
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
      );

      when(
        () => mockAgentRepository.getAllEntities(),
      ).thenAnswer((_) async => [entity]);
      when(
        () => mockOutboxService.enqueueMessage(any()),
      ).thenAnswer((_) async {});

      await syncMaintenanceRepository.syncAgentEntities();

      final captured = verify(
        () => mockOutboxService.enqueueMessage(captureAny()),
      ).captured;
      expect(captured.length, 1);
      final msg = captured.first as SyncMessage;
      expect(
        msg.mapOrNull(agentEntity: (m) => m.agentEntity!.id),
        'agent-1',
      );
    });

    test('enqueues nothing when no agent entities exist', () async {
      when(
        () => mockAgentRepository.getAllEntities(),
      ).thenAnswer((_) async => []);
      when(
        () => mockOutboxService.enqueueMessage(any()),
      ).thenAnswer((_) async {});

      await syncMaintenanceRepository.syncAgentEntities();

      verifyNever(() => mockOutboxService.enqueueMessage(any()));
    });
  });

  group('_runOperation progress callbacks', () {
    AgentDomainEntity makeEntity(String id) => AgentDomainEntity.agent(
      id: id,
      agentId: id,
      kind: 'task_agent',
      displayName: 'Agent $id',
      lifecycle: AgentLifecycle.active,
      mode: AgentInteractionMode.autonomous,
      allowedCategoryIds: const {},
      currentStateId: 'state-$id',
      config: const AgentConfig(),
      createdAt: DateTime(2024, 3, 15),
      updatedAt: DateTime(2024, 3, 15),
      vectorClock: null,
    );

    test(
      'reports per-entity progress for non-empty operation (lines 449, '
      '458-459)',
      () async {
        when(
          () => mockAgentRepository.getAllEntities(),
        ).thenAnswer((_) async => [makeEntity('a'), makeEntity('b')]);
        when(
          () => mockOutboxService.enqueueMessage(any()),
        ).thenAnswer((_) async {});

        final progressUpdates = <double>[];
        final detailedProgress = <List<int>>[];

        await syncMaintenanceRepository.syncAgentEntities(
          onProgress: progressUpdates.add,
          onDetailedProgress: (p, t) => detailedProgress.add([p, t]),
        );

        // Initial 0/total emission (line 449) followed by per-entity
        // emissions (lines 458-459) with normalized fraction.
        expect(detailedProgress, [
          [0, 2],
          [1, 2],
          [2, 2],
        ]);
        expect(progressUpdates, [0.5, 1.0]);
      },
    );

    test(
      'reports immediate completion for empty operation (lines 444-445)',
      () async {
        when(
          () => mockAgentRepository.getAllEntities(),
        ).thenAnswer((_) async => []);

        final progressUpdates = <double>[];
        final detailedProgress = <List<int>>[];

        await syncMaintenanceRepository.syncAgentEntities(
          onProgress: progressUpdates.add,
          onDetailedProgress: (p, t) => detailedProgress.add([p, t]),
        );

        // Empty path: a single 0/0 detailed emission and a 1.0 progress
        // emission, with no enqueue calls.
        expect(detailedProgress, [
          [0, 0],
        ]);
        expect(progressUpdates, [1.0]);
        verifyNever(() => mockOutboxService.enqueueMessage(any()));
      },
    );
  });

  group('syncAgentLinks', () {
    test('enqueues all agent links for sync', () async {
      final link = AgentLink.agentTask(
        id: 'link-1',
        fromId: 'agent-1',
        toId: 'task-1',
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
      );

      when(
        () => mockAgentRepository.getAllLinks(),
      ).thenAnswer((_) async => [link]);
      when(
        () => mockOutboxService.enqueueMessage(any()),
      ).thenAnswer((_) async {});

      await syncMaintenanceRepository.syncAgentLinks();

      final captured = verify(
        () => mockOutboxService.enqueueMessage(captureAny()),
      ).captured;
      expect(captured.length, 1);
      final msg = captured.first as SyncMessage;
      expect(
        msg.mapOrNull(agentLink: (m) => m.agentLink!.id),
        'link-1',
      );
    });

    test('enqueues nothing when no agent links exist', () async {
      when(() => mockAgentRepository.getAllLinks()).thenAnswer((_) async => []);
      when(
        () => mockOutboxService.enqueueMessage(any()),
      ).thenAnswer((_) async {});

      await syncMaintenanceRepository.syncAgentLinks();

      verifyNever(() => mockOutboxService.enqueueMessage(any()));
    });
  });

  group('syncMaintenanceRepositoryProvider', () {
    test('constructs repository from shared service providers', () async {
      await getIt.reset();
      getIt
        ..registerSingleton<VectorClockService>(mockVectorClockService)
        ..registerSingleton<DomainLogger>(mockLoggingService);
      addTearDown(getIt.reset);

      final container = ProviderContainer(
        overrides: [
          journalDbProvider.overrideWithValue(mockJournalDb),
          outboxServiceProvider.overrideWithValue(mockOutboxService),
          aiConfigRepositoryProvider.overrideWithValue(
            mockAiConfigRepository,
          ),
          agentRepositoryProvider.overrideWithValue(mockAgentRepository),
        ],
      );
      addTearDown(container.dispose);

      final repository = container.read(syncMaintenanceRepositoryProvider);

      expect(repository, isA<SyncMaintenanceRepository>());
    });
  });

  group('backfillAgentEntityClocks', () {
    void stubVectorClock(int counter) {
      when(
        () => mockVectorClockService.getNextVectorClock(
          previous: any(named: 'previous'),
        ),
      ).thenAnswer(
        (_) async => VectorClock({'host-1': counter}),
      );
    }

    test('stamps and enqueues entities with null vector clocks', () async {
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
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
      );

      when(
        () => mockAgentRepository.getEntitiesWithNullVectorClock(),
      ).thenAnswer((_) async => [entity]);
      when(
        () => mockAgentRepository.upsertEntity(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockOutboxService.enqueueMessage(any()),
      ).thenAnswer((_) async {});
      stubVectorClock(0);

      final progressUpdates = <double>[];
      final detailedProgress = <List<int>>[];

      await syncMaintenanceRepository.backfillAgentEntityClocks(
        onProgress: progressUpdates.add,
        onDetailedProgress: (p, t) => detailedProgress.add([p, t]),
      );

      // Verify entity was stamped with vector clock and persisted
      final captured = verify(
        () => mockAgentRepository.upsertEntity(captureAny()),
      ).captured;
      expect(captured.length, 1);
      final stamped = captured.first as AgentDomainEntity;
      expect(stamped.vectorClock, isNotNull);
      expect(stamped.vectorClock!.vclock, {'host-1': 0});

      // Verify entity was enqueued for sync
      final messages = verify(
        () => mockOutboxService.enqueueMessage(captureAny()),
      ).captured;
      expect(messages.length, 1);
      final msg = messages.first as SyncMessage;
      expect(
        msg.mapOrNull(agentEntity: (m) => m.agentEntity!.vectorClock),
        isNotNull,
      );

      // Verify progress reporting
      expect(progressUpdates, [1.0]);
      expect(detailedProgress, [
        [0, 1],
        [1, 1],
      ]);
    });

    test(
      'reports completion immediately when no entities need backfill',
      () async {
        when(
          () => mockAgentRepository.getEntitiesWithNullVectorClock(),
        ).thenAnswer((_) async => []);

        final progressUpdates = <double>[];
        final detailedProgress = <List<int>>[];

        await syncMaintenanceRepository.backfillAgentEntityClocks(
          onProgress: progressUpdates.add,
          onDetailedProgress: (p, t) => detailedProgress.add([p, t]),
        );

        expect(progressUpdates, [1.0]);
        expect(detailedProgress, [
          [0, 0],
        ]);
        verifyNever(() => mockAgentRepository.upsertEntity(any()));
        verifyNever(() => mockOutboxService.enqueueMessage(any()));
      },
    );

    test('stamps multiple entities with incrementing clocks', () async {
      final entities = List.generate(
        3,
        (i) => AgentDomainEntity.agent(
          id: 'agent-$i',
          agentId: 'agent-$i',
          kind: 'task_agent',
          displayName: 'Agent $i',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-$i',
          config: const AgentConfig(),
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
        ),
      );

      var counter = 0;
      when(
        () => mockVectorClockService.getNextVectorClock(
          previous: any(named: 'previous'),
        ),
      ).thenAnswer((_) async => VectorClock({'host-1': counter++}));
      when(
        () => mockAgentRepository.getEntitiesWithNullVectorClock(),
      ).thenAnswer((_) async => entities);
      when(
        () => mockAgentRepository.upsertEntity(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockOutboxService.enqueueMessage(any()),
      ).thenAnswer((_) async {});

      final progressUpdates = <double>[];

      await syncMaintenanceRepository.backfillAgentEntityClocks(
        onProgress: progressUpdates.add,
      );

      verify(() => mockAgentRepository.upsertEntity(any())).called(3);
      verify(() => mockOutboxService.enqueueMessage(any())).called(3);
      expect(progressUpdates.length, 3);
      expect(progressUpdates.last, 1.0);
    });
  });

  group('backfillAgentLinkClocks', () {
    void stubVectorClock(int counter) {
      when(
        () => mockVectorClockService.getNextVectorClock(
          previous: any(named: 'previous'),
        ),
      ).thenAnswer(
        (_) async => VectorClock({'host-1': counter}),
      );
    }

    test('stamps and enqueues links with null vector clocks', () async {
      final link = AgentLink.agentTask(
        id: 'link-1',
        fromId: 'agent-1',
        toId: 'task-1',
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
      );

      when(
        () => mockAgentRepository.getLinksWithNullVectorClock(),
      ).thenAnswer((_) async => [link]);
      when(
        () => mockAgentRepository.upsertLink(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockOutboxService.enqueueMessage(any()),
      ).thenAnswer((_) async {});
      stubVectorClock(0);

      final progressUpdates = <double>[];
      final detailedProgress = <List<int>>[];

      await syncMaintenanceRepository.backfillAgentLinkClocks(
        onProgress: progressUpdates.add,
        onDetailedProgress: (p, t) => detailedProgress.add([p, t]),
      );

      // Verify link was stamped with vector clock and persisted
      final captured = verify(
        () => mockAgentRepository.upsertLink(captureAny()),
      ).captured;
      expect(captured.length, 1);
      final stamped = captured.first as AgentLink;
      expect(stamped.vectorClock, isNotNull);
      expect(stamped.vectorClock!.vclock, {'host-1': 0});

      // Verify link was enqueued for sync
      final messages = verify(
        () => mockOutboxService.enqueueMessage(captureAny()),
      ).captured;
      expect(messages.length, 1);
      final msg = messages.first as SyncMessage;
      expect(
        msg.mapOrNull(agentLink: (m) => m.agentLink!.vectorClock),
        isNotNull,
      );

      // Verify progress reporting
      expect(progressUpdates, [1.0]);
      expect(detailedProgress, [
        [0, 1],
        [1, 1],
      ]);
    });

    test(
      'reports completion immediately when no links need backfill',
      () async {
        when(
          () => mockAgentRepository.getLinksWithNullVectorClock(),
        ).thenAnswer((_) async => []);

        final progressUpdates = <double>[];
        final detailedProgress = <List<int>>[];

        await syncMaintenanceRepository.backfillAgentLinkClocks(
          onProgress: progressUpdates.add,
          onDetailedProgress: (p, t) => detailedProgress.add([p, t]),
        );

        expect(progressUpdates, [1.0]);
        expect(detailedProgress, [
          [0, 0],
        ]);
        verifyNever(() => mockAgentRepository.upsertLink(any()));
        verifyNever(() => mockOutboxService.enqueueMessage(any()));
      },
    );
  });

  group('fetchTotalsForSteps - backfill steps', () {
    test(
      'returns count from dedicated query for backfill entity step',
      () async {
        when(
          () => mockAgentRepository.countEntitiesWithNullVectorClock(),
        ).thenAnswer((_) async => 42);

        final totals = await syncMaintenanceRepository.fetchTotalsForSteps(
          {SyncStep.backfillAgentEntityClocks},
        );

        expect(totals[SyncStep.backfillAgentEntityClocks], 42);
        verify(
          () => mockAgentRepository.countEntitiesWithNullVectorClock(),
        ).called(1);
      },
    );

    test('returns count from dedicated query for backfill link step', () async {
      when(
        () => mockAgentRepository.countLinksWithNullVectorClock(),
      ).thenAnswer((_) async => 7);

      final totals = await syncMaintenanceRepository.fetchTotalsForSteps(
        {SyncStep.backfillAgentLinkClocks},
      );

      expect(totals[SyncStep.backfillAgentLinkClocks], 7);
      verify(
        () => mockAgentRepository.countLinksWithNullVectorClock(),
      ).called(1);
    });
  });
  group('progress callback properties', () {
    glados.Glados2(
      glados.IntAnys(glados.any).intInRange(0, 32),
      glados.IntAnys(glados.any).intInRange(0, 1 << 16),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      '_runOperation progress is monotonic in [0,1], ends at 1.0, and '
      'detailed counts satisfy 0 <= processed <= total',
      (count, deletedMask) async {
        // Generated row set: bit i of deletedMask decides whether row i is
        // soft-deleted (shouldSync false) — exercising every mix of synced
        // and skipped entities, including the all-skipped and empty cases.
        final rows = [
          for (var i = 0; i < count; i++)
            FakeMeasurableDataType(
              id: 'm-$i',
              deletedAt: (deletedMask >> (i % 16)).isOdd && i.isEven
                  ? DateTime(2024, 3, 15)
                  : null,
            ),
        ];
        when(
          () => mockJournalDb.getAllMeasurableDataTypes(),
        ).thenAnswer((_) async => rows);
        when(
          () => mockOutboxService.enqueueMessage(any()),
        ).thenAnswer((_) async {});

        final progress = <double>[];
        final detailed = <({int processed, int total})>[];
        await syncMaintenanceRepository.syncMeasurables(
          onProgress: progress.add,
          onDetailedProgress: (processed, total) =>
              detailed.add((processed: processed, total: total)),
        );

        final reason = 'count=$count mask=$deletedMask';

        // Progress: every value in [0,1], non-decreasing, final value 1.0.
        expect(progress, isNotEmpty, reason: reason);
        for (final value in progress) {
          expect(value, inInclusiveRange(0.0, 1.0), reason: reason);
        }
        for (var i = 1; i < progress.length; i++) {
          expect(
            progress[i],
            greaterThanOrEqualTo(progress[i - 1]),
            reason: reason,
          );
        }
        expect(progress.last, 1.0, reason: reason);

        // Detailed: totals constant, processed within [0, total] and
        // non-decreasing, ending fully processed.
        expect(detailed, isNotEmpty, reason: reason);
        for (final entry in detailed) {
          expect(entry.total, count, reason: reason);
          expect(
            entry.processed,
            inInclusiveRange(0, entry.total),
            reason: reason,
          );
        }
        for (var i = 1; i < detailed.length; i++) {
          expect(
            detailed[i].processed,
            greaterThanOrEqualTo(detailed[i - 1].processed),
            reason: reason,
          );
        }
        expect(detailed.last.processed, count, reason: reason);
      },
      tags: 'glados',
    );
  });

  group('domain helpers', () {
    // Hard-coded expectations (not derived from the impl) so a typo or
    // convention drift in the production mapping is caught, and the exact
    // logging subDomain strings other tooling greps for stay pinned.
    const expectedSyncDomains = <SyncStep, String>{
      SyncStep.measurables: 'syncMeasurables',
      SyncStep.labels: 'syncLabels',
      SyncStep.categories: 'syncCategories',
      SyncStep.dashboards: 'syncDashboards',
      SyncStep.habits: 'syncHabits',
      SyncStep.aiSettings: 'syncAiSettings',
      SyncStep.backfillAgentEntityClocks: 'backfillAgentEntityClocks',
      SyncStep.backfillAgentLinkClocks: 'backfillAgentLinkClocks',
      SyncStep.agentEntities: 'syncAgentEntities',
      SyncStep.agentLinks: 'syncAgentLinks',
    };
    const expectedTotalsDomains = <SyncStep, String>{
      SyncStep.measurables: 'fetchTotals_measurables',
      SyncStep.labels: 'fetchTotals_labels',
      SyncStep.categories: 'fetchTotals_categories',
      SyncStep.dashboards: 'fetchTotals_dashboards',
      SyncStep.habits: 'fetchTotals_habits',
      SyncStep.aiSettings: 'fetchTotals_aiSettings',
      SyncStep.backfillAgentEntityClocks: 'fetchTotals_backfillAgentEntityClocks',
      SyncStep.backfillAgentLinkClocks: 'fetchTotals_backfillAgentLinkClocks',
      SyncStep.agentEntities: 'fetchTotals_agentEntities',
      SyncStep.agentLinks: 'fetchTotals_agentLinks',
    };

    test('maps every non-complete step to its sync and totals subDomain', () {
      for (final step
          in SyncStep.values.where((step) => step != SyncStep.complete)) {
        expect(
          syncMaintenanceRepository.debugSyncDomainFor(step),
          expectedSyncDomains[step],
          reason: 'sync domain for $step',
        );
        expect(
          syncMaintenanceRepository.debugTotalsDomainFor(step),
          expectedTotalsDomains[step],
          reason: 'totals domain for $step',
        );
      }
    });

    test('SyncStep.complete has neither a sync nor a totals domain', () {
      expect(
        () => syncMaintenanceRepository.debugSyncDomainFor(SyncStep.complete),
        throwsUnsupportedError,
      );
      expect(
        () => syncMaintenanceRepository.debugTotalsDomainFor(SyncStep.complete),
        throwsUnsupportedError,
      );
    });
  });
}
