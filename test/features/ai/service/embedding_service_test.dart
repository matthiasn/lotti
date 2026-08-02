import 'dart:async';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/database/agent_database.dart'
    hide AgentLink;
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ollama_embedding_repository.dart';
import 'package:lotti/features/ai/service/embedding_content_extractor.dart';
import 'package:lotti/features/ai/service/embedding_service.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/entity_factories.dart';
import '../../../mocks/mocks.dart';

/// A minimal [Metadata] for test entities.
Metadata _meta({String id = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'}) =>
    Metadata(
      id: id,
      createdAt: DateTime(2024, 3, 15),
      updatedAt: DateTime(2024, 3, 15),
      dateFrom: DateTime(2024, 3, 15),
      dateTo: DateTime(2024, 3, 15),
    );

const _entityId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
const _longText = 'This is a sufficiently long text for embedding generation.';
final _agentTestDate = DateTime.utc(2026, 8, 2);

AgentIdentityEntity _agentIdentity(String id) =>
    AgentDomainEntity.agent(
          id: id,
          agentId: id,
          kind: 'task_agent',
          displayName: 'Test Agent $id',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-$id',
          config: const AgentConfig(),
          createdAt: _agentTestDate,
          updatedAt: _agentTestDate,
          vectorClock: null,
        )
        as AgentIdentityEntity;

AgentReportEntity _agentReport({
  required String id,
  required String agentId,
  String content = 'A current report with enough content for embedding.',
  DateTime? createdAt,
}) =>
    AgentDomainEntity.agentReport(
          id: id,
          agentId: agentId,
          scope: AgentReportScopes.current,
          createdAt: createdAt ?? _agentTestDate,
          vectorClock: null,
          content: content,
        )
        as AgentReportEntity;

AgentLink _agentTaskLink({required String agentId, required String taskId}) =>
    AgentLink.agentTask(
      id: 'link-$agentId-$taskId',
      fromId: agentId,
      toId: taskId,
      createdAt: _agentTestDate,
      updatedAt: _agentTestDate,
      vectorClock: null,
    );

/// Creates a fake Float32List matching the expected dimensions.
Float32List _fakeEmbedding() => Float32List(kEmbeddingDimensions);

enum _GeneratedEmbeddingPreflightShape {
  enabled,
  disabled,
  missingBaseUrl,
  flagThrows,
  baseUrlThrows,
  labelResolverThrows,
}

enum _GeneratedEmbeddingEntitySlot { first, second, third, fourth }

enum _GeneratedEmbeddingEntityShape {
  embeddable,
  missing,
  tooShort,
  hashMatches,
  embedThrows,
}

enum _GeneratedEmbeddingOperationKind {
  start,
  stop,
  notifyRelevantSingle,
  notifyRelevantPair,
  notifyDuplicateEntity,
  notifyTypeOnly,
  notifyIrrelevantType,
  notifyInvalidUuid,
  notifyMixedRelevantInvalid,
}

enum _GeneratedEmbeddingRelevantTypeSlot {
  textEntry,
  task,
  audio,
  aiResponse,
}

const Map<_GeneratedEmbeddingEntitySlot, String>
_generatedEmbeddingEntityIds = {
  _GeneratedEmbeddingEntitySlot.first: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeee0001',
  _GeneratedEmbeddingEntitySlot.second: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeee0002',
  _GeneratedEmbeddingEntitySlot.third: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeee0003',
  _GeneratedEmbeddingEntitySlot.fourth: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeee0004',
};

const _generatedInvalidEntityId = 'generated-not-a-uuid';

String _generatedEmbeddingEntityId(_GeneratedEmbeddingEntitySlot slot) =>
    _generatedEmbeddingEntityIds[slot]!;

String _generatedEmbeddingText(_GeneratedEmbeddingEntitySlot slot) {
  return 'Generated embedding text for ${slot.name} with enough content.';
}

String _generatedEmbeddingRelevantType(
  _GeneratedEmbeddingRelevantTypeSlot slot,
) {
  return switch (slot) {
    _GeneratedEmbeddingRelevantTypeSlot.textEntry => textEntryNotification,
    _GeneratedEmbeddingRelevantTypeSlot.task => taskNotification,
    _GeneratedEmbeddingRelevantTypeSlot.audio => audioNotification,
    _GeneratedEmbeddingRelevantTypeSlot.aiResponse => aiResponseNotification,
  };
}

class _GeneratedEmbeddingEntityPlan {
  const _GeneratedEmbeddingEntityPlan({
    required this.first,
    required this.second,
    required this.third,
    required this.fourth,
  });

  final _GeneratedEmbeddingEntityShape first;
  final _GeneratedEmbeddingEntityShape second;
  final _GeneratedEmbeddingEntityShape third;
  final _GeneratedEmbeddingEntityShape fourth;

  _GeneratedEmbeddingEntityShape shape(_GeneratedEmbeddingEntitySlot slot) {
    return switch (slot) {
      _GeneratedEmbeddingEntitySlot.first => first,
      _GeneratedEmbeddingEntitySlot.second => second,
      _GeneratedEmbeddingEntitySlot.third => third,
      _GeneratedEmbeddingEntitySlot.fourth => fourth,
    };
  }

  _GeneratedEmbeddingEntityShape shapeForId(String entityId) {
    final slot = _generatedEmbeddingEntityIds.entries
        .singleWhere((entry) => entry.value == entityId)
        .key;
    return shape(slot);
  }

  _GeneratedEmbeddingEntitySlot slotForText(String input) {
    return _GeneratedEmbeddingEntitySlot.values.singleWhere(
      (slot) => _generatedEmbeddingText(slot) == input,
    );
  }

  JournalEntity? entity(_GeneratedEmbeddingEntitySlot slot) {
    final id = _generatedEmbeddingEntityId(slot);
    return switch (shape(slot)) {
      _GeneratedEmbeddingEntityShape.missing => null,
      _GeneratedEmbeddingEntityShape.tooShort => JournalEntry(
        meta: _meta(id: id),
        entryText: const EntryText(plainText: 'short'),
      ),
      _GeneratedEmbeddingEntityShape.embeddable ||
      _GeneratedEmbeddingEntityShape.hashMatches ||
      _GeneratedEmbeddingEntityShape.embedThrows => JournalEntry(
        meta: _meta(id: id),
        entryText: EntryText(plainText: _generatedEmbeddingText(slot)),
      ),
    };
  }

  @override
  String toString() {
    return '_GeneratedEmbeddingEntityPlan('
        'first: $first, second: $second, third: $third, fourth: $fourth)';
  }
}

class _GeneratedEmbeddingOperation {
  const _GeneratedEmbeddingOperation({
    required this.kind,
    required this.entitySlot,
    required this.otherEntitySlot,
    required this.relevantTypeSlot,
  });

  final _GeneratedEmbeddingOperationKind kind;
  final _GeneratedEmbeddingEntitySlot entitySlot;
  final _GeneratedEmbeddingEntitySlot otherEntitySlot;
  final _GeneratedEmbeddingRelevantTypeSlot relevantTypeSlot;

  Set<String> notificationTokens() {
    final entityId = _generatedEmbeddingEntityId(entitySlot);
    final otherEntityId = _generatedEmbeddingEntityId(otherEntitySlot);
    final relevantType = _generatedEmbeddingRelevantType(relevantTypeSlot);

    return switch (kind) {
      _GeneratedEmbeddingOperationKind.start ||
      _GeneratedEmbeddingOperationKind.stop => const <String>{},
      _GeneratedEmbeddingOperationKind.notifyRelevantSingle => {
        relevantType,
        entityId,
      },
      _GeneratedEmbeddingOperationKind.notifyRelevantPair => {
        relevantType,
        entityId,
        otherEntityId,
      },
      _GeneratedEmbeddingOperationKind.notifyDuplicateEntity => {
        relevantType,
        entityId,
        entityId,
      },
      _GeneratedEmbeddingOperationKind.notifyTypeOnly => {relevantType},
      _GeneratedEmbeddingOperationKind.notifyIrrelevantType => {
        imageNotification,
        entityId,
      },
      _GeneratedEmbeddingOperationKind.notifyInvalidUuid => {
        relevantType,
        _generatedInvalidEntityId,
      },
      _GeneratedEmbeddingOperationKind.notifyMixedRelevantInvalid => {
        relevantType,
        entityId,
        _generatedInvalidEntityId,
      },
    };
  }

  List<String> validEntityIds() {
    return notificationTokens()
        .where(_generatedEmbeddingEntityIds.values.contains)
        .toSet()
        .toList();
  }

  bool get startsService => kind == _GeneratedEmbeddingOperationKind.start;

  bool get stopsService => kind == _GeneratedEmbeddingOperationKind.stop;

  bool get hasRelevantType {
    final tokens = notificationTokens();
    return tokens.contains(textEntryNotification) ||
        tokens.contains(taskNotification) ||
        tokens.contains(audioNotification) ||
        tokens.contains(aiResponseNotification);
  }

  @override
  String toString() {
    return '_GeneratedEmbeddingOperation('
        'kind: $kind, entitySlot: $entitySlot, '
        'otherEntitySlot: $otherEntitySlot, '
        'relevantTypeSlot: $relevantTypeSlot)';
  }
}

class _GeneratedEmbeddingServiceScenario {
  const _GeneratedEmbeddingServiceScenario({
    required this.preflightShape,
    required this.entityPlan,
    required this.operations,
  });

  final _GeneratedEmbeddingPreflightShape preflightShape;
  final _GeneratedEmbeddingEntityPlan entityPlan;
  final List<_GeneratedEmbeddingOperation> operations;

  bool get flagThrows =>
      preflightShape == _GeneratedEmbeddingPreflightShape.flagThrows;

  bool get embeddingsEnabled =>
      preflightShape != _GeneratedEmbeddingPreflightShape.disabled;

  bool get baseUrlThrows =>
      preflightShape == _GeneratedEmbeddingPreflightShape.baseUrlThrows;

  bool get hasBaseUrl =>
      preflightShape != _GeneratedEmbeddingPreflightShape.missingBaseUrl;

  bool get labelResolverThrows =>
      preflightShape == _GeneratedEmbeddingPreflightShape.labelResolverThrows;

  bool get canProcessEntities =>
      !flagThrows && embeddingsEnabled && !baseUrlThrows && hasBaseUrl;

  @override
  String toString() {
    return '_GeneratedEmbeddingServiceScenario('
        'preflightShape: $preflightShape, entityPlan: $entityPlan, '
        'operations: $operations)';
  }
}

class _GeneratedEmbeddingExpected {
  int flagChecks = 0;
  int baseUrlResolutions = 0;
  int labelLookups = 0;
  final entityLookups = <String>[];
  final embedInputs = <String>[];
  final storedEntityIds = <String>[];
}

extension _AnyGeneratedEmbeddingServiceScenario on glados.Any {
  glados.Generator<_GeneratedEmbeddingPreflightShape>
  get embeddingPreflightShape =>
      glados.AnyUtils(this).choose(_GeneratedEmbeddingPreflightShape.values);

  glados.Generator<_GeneratedEmbeddingEntityShape> get embeddingEntityShape =>
      glados.AnyUtils(this).choose(_GeneratedEmbeddingEntityShape.values);

  glados.Generator<_GeneratedEmbeddingEntitySlot> get embeddingEntitySlot =>
      glados.AnyUtils(this).choose(_GeneratedEmbeddingEntitySlot.values);

  glados.Generator<_GeneratedEmbeddingRelevantTypeSlot>
  get embeddingRelevantTypeSlot =>
      glados.AnyUtils(this).choose(_GeneratedEmbeddingRelevantTypeSlot.values);

  glados.Generator<_GeneratedEmbeddingOperationKind>
  get embeddingOperationKind =>
      glados.AnyUtils(this).choose(_GeneratedEmbeddingOperationKind.values);

  glados.Generator<_GeneratedEmbeddingEntityPlan> get embeddingEntityPlan =>
      glados.CombinableAny(this).combine4(
        embeddingEntityShape,
        embeddingEntityShape,
        embeddingEntityShape,
        embeddingEntityShape,
        (
          _GeneratedEmbeddingEntityShape first,
          _GeneratedEmbeddingEntityShape second,
          _GeneratedEmbeddingEntityShape third,
          _GeneratedEmbeddingEntityShape fourth,
        ) => _GeneratedEmbeddingEntityPlan(
          first: first,
          second: second,
          third: third,
          fourth: fourth,
        ),
      );

  glados.Generator<_GeneratedEmbeddingOperation> get embeddingOperation =>
      glados.CombinableAny(this).combine4(
        embeddingOperationKind,
        embeddingEntitySlot,
        embeddingEntitySlot,
        embeddingRelevantTypeSlot,
        (
          _GeneratedEmbeddingOperationKind kind,
          _GeneratedEmbeddingEntitySlot entitySlot,
          _GeneratedEmbeddingEntitySlot otherEntitySlot,
          _GeneratedEmbeddingRelevantTypeSlot relevantTypeSlot,
        ) => _GeneratedEmbeddingOperation(
          kind: kind,
          entitySlot: entitySlot,
          otherEntitySlot: otherEntitySlot,
          relevantTypeSlot: relevantTypeSlot,
        ),
      );

  glados.Generator<_GeneratedEmbeddingServiceScenario>
  get embeddingServiceScenario => glados.CombinableAny(this).combine3(
    embeddingPreflightShape,
    embeddingEntityPlan,
    glados.ListAnys(this).listWithLengthInRange(1, 18, embeddingOperation),
    (
      _GeneratedEmbeddingPreflightShape preflightShape,
      _GeneratedEmbeddingEntityPlan entityPlan,
      List<_GeneratedEmbeddingOperation> operations,
    ) => _GeneratedEmbeddingServiceScenario(
      preflightShape: preflightShape,
      entityPlan: entityPlan,
      operations: operations,
    ),
  );
}

void main() {
  late MockEmbeddingStore mockEmbeddingStore;
  late MockOllamaEmbeddingRepository mockEmbeddingRepo;
  late MockJournalDb mockJournalDb;
  late MockAiConfigRepository mockAiConfigRepo;
  late UpdateNotifications updateNotifications;
  late EmbeddingService service;

  setUpAll(() {
    registerFallbackValue(Float32List(0));
  });

  setUp(() {
    mockEmbeddingStore = MockEmbeddingStore();
    mockEmbeddingRepo = MockOllamaEmbeddingRepository();
    mockJournalDb = MockJournalDb();
    mockAiConfigRepo = MockAiConfigRepository();
    updateNotifications = UpdateNotifications();

    service = EmbeddingService(
      embeddingStore: mockEmbeddingStore,
      embeddingRepository: mockEmbeddingRepo,
      journalDb: mockJournalDb,
      updateNotifications: updateNotifications,
      aiConfigRepository: mockAiConfigRepo,
    );

    // Default: flag enabled
    when(
      () => mockJournalDb.getConfigFlag(enableEmbeddingsFlag),
    ).thenAnswer((_) async => true);
    when(
      () => mockJournalDb.watchConfigFlag(enableEmbeddingsFlag),
    ).thenAnswer((_) => const Stream.empty());

    // Default: Ollama provider configured
    when(
      () => mockAiConfigRepo.resolveOllamaBaseUrl(),
    ).thenAnswer((_) async => 'http://localhost:11434');
    when(
      () => mockAiConfigRepo.watchConfigsByType(
        AiConfigType.inferenceProvider,
      ),
    ).thenAnswer((_) => const Stream.empty());

    // Default: no existing content hash
    when(() => mockEmbeddingStore.getContentHash(any())).thenReturn(null);
    when(
      () => mockEmbeddingStore.getEntityIdsForTask(any()),
    ).thenReturn(<String>{});

    // Default: store swap succeeds
    when(
      () => mockEmbeddingStore.replaceEntityEmbeddings(
        entityId: any(named: 'entityId'),
        entityType: any(named: 'entityType'),
        modelId: any(named: 'modelId'),
        contentHash: any(named: 'contentHash'),
        embeddings: any(named: 'embeddings'),
        categoryId: any(named: 'categoryId'),
        taskId: any(named: 'taskId'),
        subtype: any(named: 'subtype'),
      ),
    ).thenReturn(null);

    // Default: no labels (needed for label resolver)
    when(
      () => mockJournalDb.getAllLabelDefinitions(),
    ).thenAnswer((_) async => []);
  });

  tearDown(() async {
    await service.stop();
    await updateNotifications.dispose();
  });

  /// Helper: stubs journalEntityById to return [entity].
  void stubEntity(JournalEntity entity) {
    when(
      () => mockJournalDb.journalEntityById(entity.id),
    ).thenAnswer((_) async => entity);
  }

  /// Helper: stubs the embedding repo to return a fake vector.
  void stubEmbedding() {
    when(
      () => mockEmbeddingRepo.embed(
        input: any(named: 'input'),
        baseUrl: any(named: 'baseUrl'),
        model: any(named: 'model'),
      ),
    ).thenAnswer((_) async => _fakeEmbedding());
  }

  void stubPrimaryTaskAgent(
    MockAgentRepository repository, {
    required String agentId,
    required String taskId,
  }) {
    when(
      () => repository.getLinksTo(
        taskId,
        type: AgentLinkTypes.agentTask,
      ),
    ).thenAnswer(
      (_) async => [_agentTaskLink(agentId: agentId, taskId: taskId)],
    );
  }

  /// Sends a notification batch and advances fake time past the debounce
  /// timer (100ms), then flushes microtasks so async processing completes.
  void sendAndProcess(FakeAsync async, Set<String> tokens) {
    updateNotifications.notify(tokens);
    async
      ..elapse(const Duration(milliseconds: 150))
      ..flushMicrotasks();
  }

  /// Stops the service inside the fake-async zone so in-flight futures
  /// created within that zone can complete before tearDown runs.
  void stopInZone(FakeAsync async) {
    unawaited(service.stop());
    async.flushMicrotasks();
  }

  group('EmbeddingService', () {
    test('generates embedding for a journal entry on notification', () {
      fakeAsync((async) {
        final entry = JournalEntry(
          meta: _meta(),
          entryText: const EntryText(plainText: _longText),
        );
        stubEntity(entry);
        stubEmbedding();
        service.start();

        sendAndProcess(async, {_entityId, textEntryNotification});

        verify(
          () => mockEmbeddingRepo.embed(
            input: _longText,
            baseUrl: 'http://localhost:11434',
          ),
        ).called(1);

        verify(
          () => mockEmbeddingStore.replaceEntityEmbeddings(
            entityId: _entityId,
            entityType: kEntityTypeJournalText,
            modelId: ollamaEmbedDefaultModel,
            contentHash: EmbeddingContentExtractor.contentHash(_longText),
            embeddings: any(named: 'embeddings'),
            categoryId: any(named: 'categoryId'),
          ),
        ).called(1);

        stopInZone(async);
      });
    });

    test('start is idempotent: a second start adds no extra subscription', () {
      fakeAsync((async) {
        final entry = JournalEntry(
          meta: _meta(),
          entryText: const EntryText(plainText: _longText),
        );
        stubEntity(entry);
        stubEmbedding();

        // Double start: if a second listener were registered, the batch
        // below would be delivered twice and produce two embeddings.
        service
          ..start()
          ..start();

        sendAndProcess(async, {_entityId, textEntryNotification});

        verify(
          () => mockEmbeddingRepo.embed(
            input: any(named: 'input'),
            baseUrl: any(named: 'baseUrl'),
          ),
        ).called(1);

        stopInZone(async);
      });
    });

    test(
      'startup recovers the latest report and removes stale report embeddings',
      () async {
        const agentId = 'agent-1';
        const taskId = 'task-1';
        const currentReportId = 'report-current';
        const staleReportId = 'report-stale';
        final agentRepository = MockAgentRepository();
        final currentReportStored = Completer<void>();
        final agent = _agentIdentity(agentId);
        final currentReport = _agentReport(
          id: currentReportId,
          agentId: agentId,
          content:
              'The current report has enough content for startup recovery.',
        );
        final staleReport = _agentReport(
          id: staleReportId,
          agentId: agentId,
          createdAt: _agentTestDate.subtract(const Duration(minutes: 1)),
          content:
              'The stale report was embedded before the interrupted retry.',
        );
        final taskLink = _agentTaskLink(agentId: agentId, taskId: taskId);

        when(
          agentRepository.getAllAgentIdentities,
        ).thenAnswer((_) async => [agent]);
        when(
          () => agentRepository.getLinksFrom(
            agentId,
            type: AgentLinkTypes.agentTask,
          ),
        ).thenAnswer((_) async => [taskLink]);
        stubPrimaryTaskAgent(
          agentRepository,
          agentId: agentId,
          taskId: taskId,
        );
        when(
          () => agentRepository.getLatestReport(
            agentId,
            AgentReportScopes.current,
          ),
        ).thenAnswer((_) async => currentReport);
        when(
          () => agentRepository.getEntitiesByAgentIdAndSubtype(
            agentId,
            type: AgentEntityTypes.agentReport,
            subtype: AgentReportScopes.current,
          ),
        ).thenAnswer((_) async => [currentReport, staleReport]);
        when(
          () => mockEmbeddingStore.getEntityIdsForTask(taskId),
        ).thenReturn({currentReportId, staleReportId});
        when(
          () => mockJournalDb.journalEntityById(taskId),
        ).thenAnswer(
          (_) async => TestTaskFactory.create(
            id: taskId,
            title: 'Recover report embeddings',
            categoryId: 'cat-1',
          ),
        );
        stubEmbedding();
        when(
          () => mockEmbeddingStore.replaceEntityEmbeddings(
            entityId: currentReportId,
            entityType: kEntityTypeAgentReport,
            modelId: any(named: 'modelId'),
            contentHash: any(named: 'contentHash'),
            embeddings: any(named: 'embeddings'),
            categoryId: 'cat-1',
            taskId: taskId,
            subtype: AgentReportScopes.current,
          ),
        ).thenAnswer((_) {
          currentReportStored.complete();
        });

        service = EmbeddingService(
          embeddingStore: mockEmbeddingStore,
          embeddingRepository: mockEmbeddingRepo,
          journalDb: mockJournalDb,
          updateNotifications: updateNotifications,
          aiConfigRepository: mockAiConfigRepo,
          agentRepository: agentRepository,
        )..start();

        await currentReportStored.future;
        await pumpEventQueue();

        verify(
          () => mockEmbeddingStore.replaceEntityEmbeddings(
            entityId: currentReportId,
            entityType: kEntityTypeAgentReport,
            modelId: ollamaEmbedDefaultModel,
            contentHash: any(named: 'contentHash'),
            embeddings: any(named: 'embeddings'),
            categoryId: 'cat-1',
            taskId: taskId,
            subtype: AgentReportScopes.current,
          ),
        ).called(1);
        verify(
          () => mockEmbeddingStore.deleteEntityEmbeddings(staleReportId),
        ).called(1);
        verifyNever(
          () => mockEmbeddingStore.deleteEntityEmbeddings(currentReportId),
        );
        verifyNever(
          () => agentRepository.getEntitiesByAgentIdAndSubtype(
            agentId,
            type: AgentEntityTypes.agentReport,
            subtype: AgentReportScopes.current,
          ),
        );
      },
    );

    test(
      'startup reconciles only the primary agent for a shared task',
      () async {
        const olderAgentId = 'agent-shared-task-older';
        const primaryAgentId = 'agent-shared-task-primary';
        const taskId = 'task-shared-by-agents';
        final agentRepository = MockAgentRepository();
        final olderAgent = _agentIdentity(olderAgentId);
        final primaryAgent = _agentIdentity(primaryAgentId);
        final olderReport = _agentReport(
          id: 'report-shared-task-older',
          agentId: olderAgentId,
        );
        final primaryReport = _agentReport(
          id: 'report-shared-task-primary',
          agentId: primaryAgentId,
        );
        final olderLink = AgentLink.basic(
          id: 'link-shared-task-older',
          fromId: olderAgentId,
          toId: taskId,
          createdAt: _agentTestDate.subtract(const Duration(minutes: 1)),
          updatedAt: _agentTestDate.subtract(const Duration(minutes: 1)),
          vectorClock: null,
        );
        final primaryLink = AgentLink.basic(
          id: 'link-shared-task-primary',
          fromId: primaryAgentId,
          toId: taskId,
          createdAt: _agentTestDate,
          updatedAt: _agentTestDate,
          vectorClock: null,
        );
        final primaryStored = Completer<void>();

        when(
          agentRepository.getAllAgentIdentities,
        ).thenAnswer((_) async => [olderAgent, primaryAgent]);
        when(
          () => agentRepository.getLinksFrom(
            olderAgentId,
            type: AgentLinkTypes.agentTask,
          ),
        ).thenAnswer((_) async => [olderLink]);
        when(
          () => agentRepository.getLinksFrom(
            primaryAgentId,
            type: AgentLinkTypes.agentTask,
          ),
        ).thenAnswer((_) async => [primaryLink]);
        when(
          () => agentRepository.getLinksTo(
            taskId,
            type: AgentLinkTypes.agentTask,
          ),
        ).thenAnswer((_) async => [olderLink, primaryLink]);
        when(
          () => agentRepository.getLatestReport(
            olderAgentId,
            AgentReportScopes.current,
          ),
        ).thenAnswer((_) async => olderReport);
        when(
          () => agentRepository.getLatestReport(
            primaryAgentId,
            AgentReportScopes.current,
          ),
        ).thenAnswer((_) async => primaryReport);
        when(
          () => mockJournalDb.journalEntityById(taskId),
        ).thenAnswer((_) async => null);
        stubEmbedding();
        when(
          () => mockEmbeddingStore.replaceEntityEmbeddings(
            entityId: primaryReport.id,
            entityType: kEntityTypeAgentReport,
            modelId: any(named: 'modelId'),
            contentHash: any(named: 'contentHash'),
            embeddings: any(named: 'embeddings'),
            categoryId: any(named: 'categoryId'),
            taskId: taskId,
            subtype: AgentReportScopes.current,
          ),
        ).thenAnswer((_) {
          primaryStored.complete();
        });

        service = EmbeddingService(
          embeddingStore: mockEmbeddingStore,
          embeddingRepository: mockEmbeddingRepo,
          journalDb: mockJournalDb,
          updateNotifications: updateNotifications,
          aiConfigRepository: mockAiConfigRepo,
          agentRepository: agentRepository,
        )..start();

        await primaryStored.future;
        await pumpEventQueue();

        verifyNever(
          () => mockEmbeddingStore.replaceEntityEmbeddings(
            entityId: olderReport.id,
            entityType: any(named: 'entityType'),
            modelId: any(named: 'modelId'),
            contentHash: any(named: 'contentHash'),
            embeddings: any(named: 'embeddings'),
            categoryId: any(named: 'categoryId'),
            taskId: taskId,
            subtype: AgentReportScopes.current,
          ),
        );
        verify(
          () => mockEmbeddingStore.replaceEntityEmbeddings(
            entityId: primaryReport.id,
            entityType: kEntityTypeAgentReport,
            modelId: any(named: 'modelId'),
            contentHash: any(named: 'contentHash'),
            embeddings: any(named: 'embeddings'),
            categoryId: any(named: 'categoryId'),
            taskId: taskId,
            subtype: AgentReportScopes.current,
          ),
        ).called(1);
      },
    );

    test(
      'recovery abandons a report when the primary agent changes mid-pass',
      () async {
        const originalAgentId = 'agent-primary-original';
        const successorAgentId = 'agent-primary-successor';
        const taskId = 'task-primary-changed';
        final agentRepository = MockAgentRepository();
        final originalAgent = _agentIdentity(originalAgentId);
        final successorAgent = _agentIdentity(successorAgentId);
        final originalReport = _agentReport(
          id: 'report-primary-original',
          agentId: originalAgentId,
        );
        final successorReport = _agentReport(
          id: 'report-primary-successor',
          agentId: successorAgentId,
        );
        final originalLink = AgentLink.agentTask(
          id: 'link-primary-original',
          fromId: originalAgentId,
          toId: taskId,
          createdAt: _agentTestDate,
          updatedAt: _agentTestDate,
          vectorClock: null,
        );
        final initialSuccessorLink = AgentLink.agentTask(
          id: 'link-primary-successor-old',
          fromId: successorAgentId,
          toId: taskId,
          createdAt: _agentTestDate.subtract(const Duration(minutes: 1)),
          updatedAt: _agentTestDate.subtract(const Duration(minutes: 1)),
          vectorClock: null,
        );
        final promotedSuccessorLink = AgentLink.agentTask(
          id: 'link-primary-successor-new',
          fromId: successorAgentId,
          toId: taskId,
          createdAt: _agentTestDate.add(const Duration(minutes: 1)),
          updatedAt: _agentTestDate.add(const Duration(minutes: 1)),
          vectorClock: null,
        );
        final embedStarted = Completer<void>();
        final releaseEmbedding = Completer<Float32List>();
        var primaryChanged = false;
        var embedCallCount = 0;

        when(
          agentRepository.getAllAgentIdentities,
        ).thenAnswer((_) async => [originalAgent, successorAgent]);
        when(
          () => agentRepository.getLinksFrom(
            originalAgentId,
            type: AgentLinkTypes.agentTask,
          ),
        ).thenAnswer((_) async => [originalLink]);
        when(
          () => agentRepository.getLinksFrom(
            successorAgentId,
            type: AgentLinkTypes.agentTask,
          ),
        ).thenAnswer(
          (_) async {
            final successorLink = primaryChanged
                ? promotedSuccessorLink
                : initialSuccessorLink;
            return [successorLink];
          },
        );
        when(
          () => agentRepository.getLinksTo(
            taskId,
            type: AgentLinkTypes.agentTask,
          ),
        ).thenAnswer(
          (_) async {
            final successorLink = primaryChanged
                ? promotedSuccessorLink
                : initialSuccessorLink;
            return [originalLink, successorLink];
          },
        );
        when(
          () => agentRepository.getLatestReport(
            originalAgentId,
            AgentReportScopes.current,
          ),
        ).thenAnswer((_) async => originalReport);
        when(
          () => agentRepository.getLatestReport(
            successorAgentId,
            AgentReportScopes.current,
          ),
        ).thenAnswer((_) async => successorReport);
        when(
          () => mockJournalDb.journalEntityById(taskId),
        ).thenAnswer((_) async => null);
        when(
          () => mockEmbeddingStore.getEntityIdsForTask(taskId),
        ).thenReturn({successorReport.id});
        when(
          () => mockEmbeddingRepo.embed(
            input: any(named: 'input'),
            baseUrl: any(named: 'baseUrl'),
            model: any(named: 'model'),
          ),
        ).thenAnswer((_) {
          embedCallCount++;
          if (embedCallCount == 1) {
            embedStarted.complete();
            return releaseEmbedding.future;
          }
          return Future.value(_fakeEmbedding());
        });

        service = EmbeddingService(
          embeddingStore: mockEmbeddingStore,
          embeddingRepository: mockEmbeddingRepo,
          journalDb: mockJournalDb,
          updateNotifications: updateNotifications,
          aiConfigRepository: mockAiConfigRepo,
          agentRepository: agentRepository,
        )..start();

        await embedStarted.future;
        primaryChanged = true;
        releaseEmbedding.complete(_fakeEmbedding());
        await pumpEventQueue();

        verifyNever(
          () => mockEmbeddingStore.replaceEntityEmbeddings(
            entityId: originalReport.id,
            entityType: any(named: 'entityType'),
            modelId: any(named: 'modelId'),
            contentHash: any(named: 'contentHash'),
            embeddings: any(named: 'embeddings'),
            categoryId: any(named: 'categoryId'),
            taskId: taskId,
            subtype: AgentReportScopes.current,
          ),
        );
        verify(
          () => mockEmbeddingStore.replaceEntityEmbeddings(
            entityId: successorReport.id,
            entityType: any(named: 'entityType'),
            modelId: any(named: 'modelId'),
            contentHash: any(named: 'contentHash'),
            embeddings: any(named: 'embeddings'),
            categoryId: any(named: 'categoryId'),
            taskId: taskId,
            subtype: AgentReportScopes.current,
          ),
        ).called(1);
        verifyNever(
          () => mockEmbeddingStore.deleteEntityEmbeddings(successorReport.id),
        );
      },
    );

    test(
      'recovery stores a report in the task category current at write time',
      () async {
        const agentId = 'agent-task-category-changed';
        const taskId = 'task-category-changed';
        const oldCategoryId = 'category-before-recovery';
        const newCategoryId = 'category-after-recovery';
        final agentRepository = MockAgentRepository();
        final agent = _agentIdentity(agentId);
        final report = _agentReport(
          id: 'report-task-category-changed',
          agentId: agentId,
        );
        final taskLink = AgentLink.agentTask(
          id: 'link-task-category-changed',
          fromId: agentId,
          toId: taskId,
          createdAt: _agentTestDate,
          updatedAt: _agentTestDate,
          vectorClock: null,
        );
        final embedStarted = Completer<void>();
        final releaseEmbedding = Completer<Float32List>();
        var categoryChanged = false;
        var embedCallCount = 0;

        when(
          agentRepository.getAllAgentIdentities,
        ).thenAnswer((_) async => [agent]);
        when(
          () => agentRepository.getLinksFrom(
            agentId,
            type: AgentLinkTypes.agentTask,
          ),
        ).thenAnswer((_) async => [taskLink]);
        when(
          () => agentRepository.getLinksTo(
            taskId,
            type: AgentLinkTypes.agentTask,
          ),
        ).thenAnswer((_) async => [taskLink]);
        when(
          () => agentRepository.getLatestReport(
            agentId,
            AgentReportScopes.current,
          ),
        ).thenAnswer((_) async => report);
        when(
          () => mockJournalDb.journalEntityById(taskId),
        ).thenAnswer(
          (_) async => TestTaskFactory.create(
            id: taskId,
            title: 'Task whose category changes during recovery',
            categoryId: categoryChanged ? newCategoryId : oldCategoryId,
          ),
        );
        when(
          () => mockEmbeddingStore.getEntityIdsForTask(taskId),
        ).thenReturn({report.id});
        when(
          () => mockEmbeddingRepo.embed(
            input: any(named: 'input'),
            baseUrl: any(named: 'baseUrl'),
            model: any(named: 'model'),
          ),
        ).thenAnswer((_) {
          embedCallCount++;
          if (embedCallCount == 1) {
            embedStarted.complete();
            return releaseEmbedding.future;
          }
          return Future.value(_fakeEmbedding());
        });

        service = EmbeddingService(
          embeddingStore: mockEmbeddingStore,
          embeddingRepository: mockEmbeddingRepo,
          journalDb: mockJournalDb,
          updateNotifications: updateNotifications,
          aiConfigRepository: mockAiConfigRepo,
          agentRepository: agentRepository,
        )..start();

        await embedStarted.future;
        categoryChanged = true;
        releaseEmbedding.complete(_fakeEmbedding());
        await pumpEventQueue();

        verifyNever(
          () => mockEmbeddingStore.replaceEntityEmbeddings(
            entityId: report.id,
            entityType: any(named: 'entityType'),
            modelId: any(named: 'modelId'),
            contentHash: any(named: 'contentHash'),
            embeddings: any(named: 'embeddings'),
            categoryId: oldCategoryId,
            taskId: taskId,
            subtype: AgentReportScopes.current,
          ),
        );
        verify(
          () => mockEmbeddingStore.replaceEntityEmbeddings(
            entityId: report.id,
            entityType: any(named: 'entityType'),
            modelId: any(named: 'modelId'),
            contentHash: any(named: 'contentHash'),
            embeddings: any(named: 'embeddings'),
            categoryId: newCategoryId,
            taskId: taskId,
            subtype: AgentReportScopes.current,
          ),
        ).called(1);
      },
    );

    test(
      'startup bypasses a stale identity cache owned by its repository',
      () async {
        const agentId = 'agent-after-identity-cache';
        const taskId = 'task-after-identity-cache';
        final db = AgentDatabase(inMemoryDatabase: true, background: false);
        final recoveryRepository = AgentRepository(db);
        final writerRepository = AgentRepository(db);
        final report = _agentReport(
          id: 'report-after-identity-cache',
          agentId: agentId,
        );

        try {
          expect(await recoveryRepository.getAllAgentIdentities(), isEmpty);
          await writerRepository.upsertEntity(_agentIdentity(agentId));
          await writerRepository.upsertLink(
            AgentLink.agentTask(
              id: 'link-after-identity-cache',
              fromId: agentId,
              toId: taskId,
              createdAt: _agentTestDate,
              updatedAt: _agentTestDate,
              vectorClock: null,
            ),
          );
          await writerRepository.upsertEntity(report);
          await writerRepository.upsertEntity(
            AgentDomainEntity.agentReportHead(
              id: 'head-after-identity-cache',
              agentId: agentId,
              scope: AgentReportScopes.current,
              reportId: report.id,
              updatedAt: _agentTestDate,
              vectorClock: null,
            ),
          );
          when(
            () => mockJournalDb.journalEntityById(taskId),
          ).thenAnswer((_) async => null);
          when(
            () => mockEmbeddingStore.getEntityIdsForTask(taskId),
          ).thenReturn({report.id});
          stubEmbedding();

          service = EmbeddingService(
            embeddingStore: mockEmbeddingStore,
            embeddingRepository: mockEmbeddingRepo,
            journalDb: mockJournalDb,
            updateNotifications: updateNotifications,
            aiConfigRepository: mockAiConfigRepo,
            agentRepository: recoveryRepository,
          )..start();

          await pumpEventQueue();

          verify(
            () => mockEmbeddingStore.replaceEntityEmbeddings(
              entityId: report.id,
              entityType: kEntityTypeAgentReport,
              modelId: any(named: 'modelId'),
              contentHash: any(named: 'contentHash'),
              embeddings: any(named: 'embeddings'),
              categoryId: any(named: 'categoryId'),
              taskId: taskId,
              subtype: AgentReportScopes.current,
            ),
          ).called(1);
        } finally {
          await service.stop();
          await db.close();
        }
      },
    );

    test(
      'startup skips a report superseded before its store write',
      () async {
        const agentId = 'agent-superseded-before-store';
        const taskId = 'task-superseded-before-store';
        final agentRepository = MockAgentRepository();
        final reportA = _agentReport(
          id: 'report-a',
          agentId: agentId,
          createdAt: _agentTestDate.subtract(const Duration(minutes: 1)),
        );
        final reportB = _agentReport(id: 'report-b', agentId: agentId);
        final embedStarted = Completer<void>();
        final releaseEmbedding = Completer<Float32List>();
        final recoverySettled = Completer<void>();
        var currentHead = reportA;
        var latestReportReadCount = 0;

        when(
          agentRepository.getAllAgentIdentities,
        ).thenAnswer((_) async => [_agentIdentity(agentId)]);
        when(
          () => agentRepository.getLinksFrom(
            agentId,
            type: AgentLinkTypes.agentTask,
          ),
        ).thenAnswer(
          (_) async => [_agentTaskLink(agentId: agentId, taskId: taskId)],
        );
        stubPrimaryTaskAgent(
          agentRepository,
          agentId: agentId,
          taskId: taskId,
        );
        when(
          () => agentRepository.getLatestReport(
            agentId,
            AgentReportScopes.current,
          ),
        ).thenAnswer((_) async {
          latestReportReadCount++;
          if (latestReportReadCount > 1 && !recoverySettled.isCompleted) {
            recoverySettled.complete();
          }
          return currentHead;
        });
        when(
          () => agentRepository.getEntitiesByAgentIdAndSubtype(
            agentId,
            type: AgentEntityTypes.agentReport,
            subtype: AgentReportScopes.current,
          ),
        ).thenAnswer((_) async {
          if (!recoverySettled.isCompleted) recoverySettled.complete();
          return [reportA, reportB];
        });
        when(
          () => mockJournalDb.journalEntityById(taskId),
        ).thenAnswer((_) async => null);
        when(
          () => mockEmbeddingRepo.embed(
            input: any(named: 'input'),
            baseUrl: any(named: 'baseUrl'),
            model: any(named: 'model'),
          ),
        ).thenAnswer((_) {
          if (!embedStarted.isCompleted) embedStarted.complete();
          return releaseEmbedding.future;
        });

        service = EmbeddingService(
          embeddingStore: mockEmbeddingStore,
          embeddingRepository: mockEmbeddingRepo,
          journalDb: mockJournalDb,
          updateNotifications: updateNotifications,
          aiConfigRepository: mockAiConfigRepo,
          agentRepository: agentRepository,
        )..start();

        await embedStarted.future;
        currentHead = reportB;
        releaseEmbedding.complete(_fakeEmbedding());
        await recoverySettled.future;
        await pumpEventQueue();

        verifyNever(
          () => mockEmbeddingStore.replaceEntityEmbeddings(
            entityId: reportA.id,
            entityType: any(named: 'entityType'),
            modelId: any(named: 'modelId'),
            contentHash: any(named: 'contentHash'),
            embeddings: any(named: 'embeddings'),
            categoryId: any(named: 'categoryId'),
            taskId: any(named: 'taskId'),
            subtype: any(named: 'subtype'),
          ),
        );
        verifyNever(
          () => mockEmbeddingStore.deleteEntityEmbeddings(reportB.id),
        );
        verify(
          () => mockEmbeddingStore.replaceEntityEmbeddings(
            entityId: reportB.id,
            entityType: kEntityTypeAgentReport,
            modelId: any(named: 'modelId'),
            contentHash: any(named: 'contentHash'),
            embeddings: any(named: 'embeddings'),
            categoryId: any(named: 'categoryId'),
            taskId: taskId,
            subtype: AgentReportScopes.current,
          ),
        ).called(1);
      },
    );

    test(
      'startup reconciles the successor after a store-time supersession',
      () async {
        const agentId = 'agent-superseded-during-store';
        const taskId = 'task-superseded-during-store';
        final agentRepository = MockAgentRepository();
        final reportA = _agentReport(
          id: 'report-a',
          agentId: agentId,
          createdAt: _agentTestDate.subtract(const Duration(minutes: 1)),
        );
        final reportB = _agentReport(id: 'report-b', agentId: agentId);
        final reportP = _agentReport(
          id: 'report-p',
          agentId: agentId,
          createdAt: _agentTestDate.subtract(const Duration(minutes: 2)),
        );
        final storeStarted = Completer<void>();
        final releaseStore = Completer<void>();
        final deletionObserved = Completer<void>();
        final deletedReportIds = <String>[];
        var currentHead = reportA;

        when(
          agentRepository.getAllAgentIdentities,
        ).thenAnswer((_) async => [_agentIdentity(agentId)]);
        when(
          () => agentRepository.getLinksFrom(
            agentId,
            type: AgentLinkTypes.agentTask,
          ),
        ).thenAnswer(
          (_) async => [_agentTaskLink(agentId: agentId, taskId: taskId)],
        );
        stubPrimaryTaskAgent(
          agentRepository,
          agentId: agentId,
          taskId: taskId,
        );
        when(
          () => agentRepository.getLatestReport(
            agentId,
            AgentReportScopes.current,
          ),
        ).thenAnswer((_) async => currentHead);
        when(
          () => agentRepository.getEntitiesByAgentIdAndSubtype(
            agentId,
            type: AgentEntityTypes.agentReport,
            subtype: AgentReportScopes.current,
          ),
        ).thenAnswer((_) async => [reportP, reportA, reportB]);
        when(
          () => mockEmbeddingStore.getEntityIdsForTask(taskId),
        ).thenReturn({reportP.id, reportA.id, reportB.id});
        when(
          () => mockJournalDb.journalEntityById(taskId),
        ).thenAnswer((_) async => null);
        stubEmbedding();
        when(
          () => mockEmbeddingStore.getContentHash(reportB.id),
        ).thenReturn(EmbeddingContentExtractor.contentHash(reportB.content));
        when(
          () => mockEmbeddingStore.hasEmbedding(reportB.id),
        ).thenReturn(true);
        when(
          () => mockEmbeddingStore.replaceEntityEmbeddings(
            entityId: reportA.id,
            entityType: any(named: 'entityType'),
            modelId: any(named: 'modelId'),
            contentHash: any(named: 'contentHash'),
            embeddings: any(named: 'embeddings'),
            categoryId: any(named: 'categoryId'),
            taskId: taskId,
            subtype: AgentReportScopes.current,
          ),
        ).thenAnswer((_) {
          storeStarted.complete();
          return releaseStore.future;
        });
        when(
          () => mockEmbeddingStore.deleteEntityEmbeddings(any()),
        ).thenAnswer((invocation) {
          deletedReportIds.add(
            invocation.positionalArguments.first as String,
          );
          if (!deletionObserved.isCompleted) deletionObserved.complete();
        });

        service = EmbeddingService(
          embeddingStore: mockEmbeddingStore,
          embeddingRepository: mockEmbeddingRepo,
          journalDb: mockJournalDb,
          updateNotifications: updateNotifications,
          aiConfigRepository: mockAiConfigRepo,
          agentRepository: agentRepository,
        )..start();

        await storeStarted.future;
        currentHead = reportB;
        releaseStore.complete();
        await deletionObserved.future;
        await pumpEventQueue();

        expect(deletedReportIds, [reportA.id, reportP.id]);
        verify(
          () => mockEmbeddingStore.deleteEntityEmbeddings(reportA.id),
        ).called(1);
        verify(
          () => mockEmbeddingStore.deleteEntityEmbeddings(reportP.id),
        ).called(1);
        verifyNever(
          () => mockEmbeddingStore.deleteEntityEmbeddings(reportB.id),
        );
      },
    );

    test(
      'startup revalidates the head after reading cleanup candidates',
      () async {
        const agentId = 'agent-head-changes-during-cleanup';
        const taskId = 'task-head-changes-during-cleanup';
        final agentRepository = MockAgentRepository();
        final reportA = _agentReport(
          id: 'report-a',
          agentId: agentId,
          createdAt: _agentTestDate.subtract(const Duration(minutes: 2)),
        );
        final reportB = _agentReport(id: 'report-b', agentId: agentId);
        final reportC = _agentReport(
          id: 'report-c',
          agentId: agentId,
          createdAt: _agentTestDate.subtract(const Duration(minutes: 3)),
        );
        final twoDeletionsObserved = Completer<void>();
        final deletedReportIds = <String>[];
        var currentHead = reportB;
        var cleanupReadCount = 0;

        when(
          agentRepository.getAllAgentIdentities,
        ).thenAnswer((_) async => [_agentIdentity(agentId)]);
        when(
          () => agentRepository.getLinksFrom(
            agentId,
            type: AgentLinkTypes.agentTask,
          ),
        ).thenAnswer(
          (_) async => [_agentTaskLink(agentId: agentId, taskId: taskId)],
        );
        stubPrimaryTaskAgent(
          agentRepository,
          agentId: agentId,
          taskId: taskId,
        );
        when(
          () => agentRepository.getLatestReport(
            agentId,
            AgentReportScopes.current,
          ),
        ).thenAnswer((_) async => currentHead);
        when(
          () => mockEmbeddingStore.getEntityIdsForTask(taskId),
        ).thenAnswer((_) {
          cleanupReadCount++;
          if (cleanupReadCount == 1) currentHead = reportC;
          return {reportA.id, reportB.id, reportC.id};
        });
        when(
          () => mockJournalDb.journalEntityById(taskId),
        ).thenAnswer((_) async => null);
        stubEmbedding();
        when(
          () => mockEmbeddingStore.getContentHash(reportC.id),
        ).thenReturn(EmbeddingContentExtractor.contentHash(reportC.content));
        when(
          () => mockEmbeddingStore.hasEmbedding(reportC.id),
        ).thenReturn(true);
        when(
          () => mockEmbeddingStore.deleteEntityEmbeddings(any()),
        ).thenAnswer((invocation) {
          deletedReportIds.add(
            invocation.positionalArguments.first as String,
          );
          if (deletedReportIds.length == 2 &&
              !twoDeletionsObserved.isCompleted) {
            twoDeletionsObserved.complete();
          }
        });

        service = EmbeddingService(
          embeddingStore: mockEmbeddingStore,
          embeddingRepository: mockEmbeddingRepo,
          journalDb: mockJournalDb,
          updateNotifications: updateNotifications,
          aiConfigRepository: mockAiConfigRepo,
          agentRepository: agentRepository,
        )..start();

        await twoDeletionsObserved.future;
        await pumpEventQueue();

        expect(deletedReportIds, [reportB.id, reportA.id]);
        verifyNever(
          () => mockEmbeddingStore.deleteEntityEmbeddings(reportC.id),
        );
      },
    );

    test(
      'startup rebuilds the category after reading cleanup candidates',
      () async {
        const agentId = 'agent-category-changes-during-cleanup';
        const taskId = 'task-category-changes-during-cleanup';
        const oldCategoryId = 'category-before-candidate-read';
        const newCategoryId = 'category-after-candidate-read';
        const staleReportId = 'report-from-stale-candidate-snapshot';
        final agentRepository = MockAgentRepository();
        final report = _agentReport(
          id: 'report-category-changes-during-cleanup',
          agentId: agentId,
        );
        final secondStore = Completer<void>();
        final storedCategoryIds = <String>[];
        var categoryChanged = false;
        var cleanupReadCount = 0;

        when(
          agentRepository.getAllAgentIdentities,
        ).thenAnswer((_) async => [_agentIdentity(agentId)]);
        when(
          () => agentRepository.getLinksFrom(
            agentId,
            type: AgentLinkTypes.agentTask,
          ),
        ).thenAnswer(
          (_) async => [_agentTaskLink(agentId: agentId, taskId: taskId)],
        );
        stubPrimaryTaskAgent(
          agentRepository,
          agentId: agentId,
          taskId: taskId,
        );
        when(
          () => agentRepository.getLatestReport(
            agentId,
            AgentReportScopes.current,
          ),
        ).thenAnswer((_) async => report);
        when(
          () => mockJournalDb.journalEntityById(taskId),
        ).thenAnswer(
          (_) async => TestTaskFactory.create(
            id: taskId,
            title: 'Task whose category changes after candidate read',
            categoryId: categoryChanged ? newCategoryId : oldCategoryId,
          ),
        );
        when(
          () => mockEmbeddingStore.getEntityIdsForTask(taskId),
        ).thenAnswer((_) {
          cleanupReadCount++;
          if (cleanupReadCount == 1) {
            categoryChanged = true;
            return {report.id, staleReportId};
          }
          return {report.id};
        });
        stubEmbedding();
        when(
          () => mockEmbeddingStore.replaceEntityEmbeddings(
            entityId: report.id,
            entityType: kEntityTypeAgentReport,
            modelId: any(named: 'modelId'),
            contentHash: any(named: 'contentHash'),
            embeddings: any(named: 'embeddings'),
            categoryId: any(named: 'categoryId'),
            taskId: taskId,
            subtype: AgentReportScopes.current,
          ),
        ).thenAnswer((invocation) {
          storedCategoryIds.add(
            invocation.namedArguments[#categoryId]! as String,
          );
          if (storedCategoryIds.length == 2) secondStore.complete();
        });
        when(
          () => mockEmbeddingStore.deleteEntityEmbeddings(any()),
        ).thenReturn(null);

        service = EmbeddingService(
          embeddingStore: mockEmbeddingStore,
          embeddingRepository: mockEmbeddingRepo,
          journalDb: mockJournalDb,
          updateNotifications: updateNotifications,
          aiConfigRepository: mockAiConfigRepo,
          agentRepository: agentRepository,
        )..start();

        await secondStore.future;
        await pumpEventQueue();

        expect(storedCategoryIds, [oldCategoryId, newCategoryId]);
        verify(
          () => mockEmbeddingStore.deleteEntityEmbeddings(report.id),
        ).called(1);
        verifyNever(
          () => mockEmbeddingStore.deleteEntityEmbeddings(staleReportId),
        );
      },
    );

    test(
      'recovery aborts when its task topology snapshot is partial',
      () async {
        const primaryAgentId = 'agent-topology-primary';
        const secondaryAgentId = 'agent-topology-secondary';
        const taskId = 'task-partial-topology';
        final agentRepository = MockAgentRepository();
        final primaryLink = AgentLink.agentTask(
          id: 'link-topology-primary',
          fromId: primaryAgentId,
          toId: taskId,
          createdAt: _agentTestDate,
          updatedAt: _agentTestDate,
          vectorClock: null,
        );
        final secondaryLink = AgentLink.agentTask(
          id: 'link-topology-secondary',
          fromId: secondaryAgentId,
          toId: taskId,
          createdAt: _agentTestDate.subtract(const Duration(minutes: 1)),
          updatedAt: _agentTestDate.subtract(const Duration(minutes: 1)),
          vectorClock: null,
        );
        when(agentRepository.getAllAgentIdentities).thenAnswer(
          (_) async => [
            _agentIdentity(primaryAgentId),
            _agentIdentity(secondaryAgentId),
          ],
        );
        when(
          () => agentRepository.getLinksFrom(
            primaryAgentId,
            type: AgentLinkTypes.agentTask,
          ),
        ).thenThrow(StateError('primary topology read failed'));
        when(
          () => agentRepository.getLinksFrom(
            secondaryAgentId,
            type: AgentLinkTypes.agentTask,
          ),
        ).thenAnswer((_) async => [secondaryLink]);
        when(
          () => agentRepository.getLinksTo(
            taskId,
            type: AgentLinkTypes.agentTask,
          ),
        ).thenAnswer((_) async => [secondaryLink, primaryLink]);
        when(
          () => agentRepository.getLatestReport(
            secondaryAgentId,
            AgentReportScopes.current,
          ),
        ).thenAnswer(
          (_) async => _agentReport(
            id: 'report-partial-topology',
            agentId: secondaryAgentId,
          ),
        );
        when(
          () => mockJournalDb.journalEntityById(taskId),
        ).thenAnswer((_) async => null);
        stubEmbedding();

        service = EmbeddingService(
          embeddingStore: mockEmbeddingStore,
          embeddingRepository: mockEmbeddingRepo,
          journalDb: mockJournalDb,
          updateNotifications: updateNotifications,
          aiConfigRepository: mockAiConfigRepo,
          agentRepository: agentRepository,
        )..start();

        await pumpEventQueue(times: 5);

        verifyNever(
          () => mockEmbeddingRepo.embed(
            input: any(named: 'input'),
            baseUrl: any(named: 'baseUrl'),
            model: any(named: 'model'),
          ),
        );
        verify(
          () => agentRepository.getLinksFrom(
            primaryAgentId,
            type: AgentLinkTypes.agentTask,
          ),
        ).called(1);
      },
    );

    test('startup report recovery respects the disabled flag', () async {
      final agentRepository = MockAgentRepository();
      final flagChecked = Completer<void>();
      when(
        () => mockJournalDb.getConfigFlag(enableEmbeddingsFlag),
      ).thenAnswer((_) async {
        flagChecked.complete();
        return false;
      });

      service = EmbeddingService(
        embeddingStore: mockEmbeddingStore,
        embeddingRepository: mockEmbeddingRepo,
        journalDb: mockJournalDb,
        updateNotifications: updateNotifications,
        aiConfigRepository: mockAiConfigRepo,
        agentRepository: agentRepository,
      )..start();

      await flagChecked.future;
      await pumpEventQueue();

      verifyNever(agentRepository.getAllAgentIdentities);
    });

    test('startup report recovery requires a configured provider', () async {
      final agentRepository = MockAgentRepository();
      final baseUrlChecked = Completer<void>();
      when(mockAiConfigRepo.resolveOllamaBaseUrl).thenAnswer((_) async {
        baseUrlChecked.complete();
        return null;
      });

      service = EmbeddingService(
        embeddingStore: mockEmbeddingStore,
        embeddingRepository: mockEmbeddingRepo,
        journalDb: mockJournalDb,
        updateNotifications: updateNotifications,
        aiConfigRepository: mockAiConfigRepo,
        agentRepository: agentRepository,
      )..start();

      await baseUrlChecked.future;
      await pumpEventQueue();

      verifyNever(agentRepository.getAllAgentIdentities);
    });

    test('provider setup restarts pending report recovery', () async {
      const agentId = 'agent-configured-after-startup';
      const taskId = 'task-configured-after-startup';
      final agentRepository = MockAgentRepository();
      final providerConfigs = StreamController<List<AiConfig>>.broadcast(
        sync: true,
      );
      addTearDown(providerConfigs.close);
      final report = _agentReport(
        id: 'report-configured-after-startup',
        agentId: agentId,
      );
      final initialBaseUrlChecked = Completer<void>();
      var configured = false;

      when(
        () => mockAiConfigRepo.watchConfigsByType(
          AiConfigType.inferenceProvider,
        ),
      ).thenAnswer((_) => providerConfigs.stream);
      when(mockAiConfigRepo.resolveOllamaBaseUrl).thenAnswer((_) async {
        if (!initialBaseUrlChecked.isCompleted) {
          initialBaseUrlChecked.complete();
        }
        return configured ? 'http://localhost:11434' : null;
      });
      when(
        agentRepository.getAllAgentIdentities,
      ).thenAnswer((_) async => [_agentIdentity(agentId)]);
      when(
        () => agentRepository.getLinksFrom(
          agentId,
          type: AgentLinkTypes.agentTask,
        ),
      ).thenAnswer(
        (_) async => [_agentTaskLink(agentId: agentId, taskId: taskId)],
      );
      stubPrimaryTaskAgent(
        agentRepository,
        agentId: agentId,
        taskId: taskId,
      );
      when(
        () => agentRepository.getLatestReport(
          agentId,
          AgentReportScopes.current,
        ),
      ).thenAnswer((_) async => report);
      when(
        () => mockJournalDb.journalEntityById(taskId),
      ).thenAnswer((_) async => null);
      stubEmbedding();

      service = EmbeddingService(
        embeddingStore: mockEmbeddingStore,
        embeddingRepository: mockEmbeddingRepo,
        journalDb: mockJournalDb,
        updateNotifications: updateNotifications,
        aiConfigRepository: mockAiConfigRepo,
        agentRepository: agentRepository,
      )..start();

      await initialBaseUrlChecked.future;
      providerConfigs.add(const []);
      configured = true;
      providerConfigs.add(const []);
      await pumpEventQueue();

      verify(
        () => mockEmbeddingStore.replaceEntityEmbeddings(
          entityId: report.id,
          entityType: kEntityTypeAgentReport,
          modelId: any(named: 'modelId'),
          contentHash: any(named: 'contentHash'),
          embeddings: any(named: 'embeddings'),
          categoryId: any(named: 'categoryId'),
          taskId: taskId,
          subtype: AgentReportScopes.current,
        ),
      ).called(1);
    });

    test(
      'provider initial snapshot does not duplicate startup recovery',
      () async {
        final agentRepository = MockAgentRepository();
        when(
          () => mockAiConfigRepo.watchConfigsByType(
            AiConfigType.inferenceProvider,
          ),
        ).thenAnswer((_) => Stream.value(const <AiConfig>[]));
        when(
          agentRepository.getAllAgentIdentities,
        ).thenAnswer((_) async => []);

        service = EmbeddingService(
          embeddingStore: mockEmbeddingStore,
          embeddingRepository: mockEmbeddingRepo,
          journalDb: mockJournalDb,
          updateNotifications: updateNotifications,
          aiConfigRepository: mockAiConfigRepo,
          agentRepository: agentRepository,
        )..start();

        await pumpEventQueue();

        verify(agentRepository.getAllAgentIdentities).called(1);
      },
    );

    test('enabling embeddings restarts pending report recovery', () async {
      final agentRepository = MockAgentRepository();
      final flagChanges = StreamController<bool>.broadcast(sync: true);
      addTearDown(flagChanges.close);
      final initialFlagChecked = Completer<void>();
      var enabled = false;
      when(
        () => mockJournalDb.watchConfigFlag(enableEmbeddingsFlag),
      ).thenAnswer((_) => flagChanges.stream);
      when(
        () => mockJournalDb.getConfigFlag(enableEmbeddingsFlag),
      ).thenAnswer((_) async {
        if (!initialFlagChecked.isCompleted) initialFlagChecked.complete();
        return enabled;
      });
      when(
        agentRepository.getAllAgentIdentities,
      ).thenAnswer((_) async => []);

      service = EmbeddingService(
        embeddingStore: mockEmbeddingStore,
        embeddingRepository: mockEmbeddingRepo,
        journalDb: mockJournalDb,
        updateNotifications: updateNotifications,
        aiConfigRepository: mockAiConfigRepo,
        agentRepository: agentRepository,
      )..start();

      await initialFlagChecked.future;
      flagChanges.add(false);
      enabled = true;
      flagChanges.add(true);
      await pumpEventQueue();

      verify(agentRepository.getAllAgentIdentities).called(1);
    });

    test('provider change resumes an availability-paused entity batch', () {
      final providerConfigs = StreamController<List<AiConfig>>.broadcast(
        sync: true,
      );
      addTearDown(providerConfigs.close);
      when(
        () => mockAiConfigRepo.watchConfigsByType(
          AiConfigType.inferenceProvider,
        ),
      ).thenAnswer((_) => providerConfigs.stream);
      stubEntity(
        JournalEntry(
          meta: _meta(),
          entryText: const EntryText(plainText: _longText),
        ),
      );
      var embeddingCalls = 0;
      when(
        () => mockEmbeddingRepo.embed(
          input: any(named: 'input'),
          baseUrl: any(named: 'baseUrl'),
          model: any(named: 'model'),
        ),
      ).thenAnswer((_) async {
        embeddingCalls++;
        if (embeddingCalls == 1) {
          throw OllamaEmbeddingCooldownException(
            retryAt: clock.now().add(const Duration(hours: 1)),
            suppressedRequestCount: 1,
          );
        }
        return _fakeEmbedding();
      });

      fakeAsync((async) {
        service.start();
        providerConfigs.add(const []);
        sendAndProcess(async, {_entityId, textEntryNotification});
        expect(embeddingCalls, 1);

        providerConfigs.add(const []);
        async.flushMicrotasks();

        expect(embeddingCalls, 2);
        stopInZone(async);
      });
    });

    test('provider change during a failed request reruns on the new URL', () {
      final providerConfigs = StreamController<List<AiConfig>>.broadcast(
        sync: true,
      );
      addTearDown(providerConfigs.close);
      late Completer<Float32List> firstRequest;
      var currentBaseUrl = 'http://old-ollama:11434';
      final attemptedBaseUrls = <String>[];
      when(
        () => mockAiConfigRepo.watchConfigsByType(
          AiConfigType.inferenceProvider,
        ),
      ).thenAnswer((_) => providerConfigs.stream);
      when(
        mockAiConfigRepo.resolveOllamaBaseUrl,
      ).thenAnswer((_) async => currentBaseUrl);
      stubEntity(
        JournalEntry(
          meta: _meta(),
          entryText: const EntryText(plainText: _longText),
        ),
      );
      when(
        () => mockEmbeddingRepo.embed(
          input: any(named: 'input'),
          baseUrl: any(named: 'baseUrl'),
          model: any(named: 'model'),
        ),
      ).thenAnswer((invocation) {
        final baseUrl = invocation.namedArguments[#baseUrl]! as String;
        attemptedBaseUrls.add(baseUrl);
        if (attemptedBaseUrls.length == 1) return firstRequest.future;
        return Future.value(_fakeEmbedding());
      });

      fakeAsync((async) {
        firstRequest = Completer<Float32List>();
        service.start();
        providerConfigs.add(const []);
        sendAndProcess(async, {_entityId, textEntryNotification});
        expect(attemptedBaseUrls, ['http://old-ollama:11434']);

        currentBaseUrl = 'http://new-ollama:11434';
        providerConfigs.add(const []);
        firstRequest.completeError(
          OllamaEmbeddingCooldownException(
            retryAt: clock.now().add(const Duration(hours: 1)),
            suppressedRequestCount: 1,
          ),
        );
        async.flushMicrotasks();
        stopInZone(async);

        expect(attemptedBaseUrls, [
          'http://old-ollama:11434',
          'http://new-ollama:11434',
        ]);
      });
    });

    test('a journal notification rechecks recovery after enabling it', () {
      fakeAsync((async) {
        final agentRepository = MockAgentRepository();
        var enabled = false;
        when(
          () => mockJournalDb.getConfigFlag(enableEmbeddingsFlag),
        ).thenAnswer((_) async => enabled);
        when(
          agentRepository.getAllAgentIdentities,
        ).thenAnswer((_) async => []);
        when(
          () => mockJournalDb.journalEntityById(_entityId),
        ).thenAnswer((_) async => null);

        service = EmbeddingService(
          embeddingStore: mockEmbeddingStore,
          embeddingRepository: mockEmbeddingRepo,
          journalDb: mockJournalDb,
          updateNotifications: updateNotifications,
          aiConfigRepository: mockAiConfigRepo,
          agentRepository: agentRepository,
        )..start();
        async.flushMicrotasks();
        verifyNever(agentRepository.getAllAgentIdentities);

        enabled = true;
        sendAndProcess(async, {_entityId, textEntryNotification});

        verify(agentRepository.getAllAgentIdentities).called(1);
        stopInZone(async);
      });
    });

    test('a journal notification rechecks recovery after provider setup', () {
      fakeAsync((async) {
        final agentRepository = MockAgentRepository();
        String? baseUrl;
        when(
          mockAiConfigRepo.resolveOllamaBaseUrl,
        ).thenAnswer((_) async => baseUrl);
        when(
          agentRepository.getAllAgentIdentities,
        ).thenAnswer((_) async => []);
        when(
          () => mockJournalDb.journalEntityById(_entityId),
        ).thenAnswer((_) async => null);

        service = EmbeddingService(
          embeddingStore: mockEmbeddingStore,
          embeddingRepository: mockEmbeddingRepo,
          journalDb: mockJournalDb,
          updateNotifications: updateNotifications,
          aiConfigRepository: mockAiConfigRepo,
          agentRepository: agentRepository,
        )..start();
        async.flushMicrotasks();
        verifyNever(agentRepository.getAllAgentIdentities);

        baseUrl = 'http://localhost:11434';
        sendAndProcess(async, {_entityId, textEntryNotification});

        verify(agentRepository.getAllAgentIdentities).called(1);
        stopInZone(async);
      });
    });

    test('synced deletion of the last task link removes report vectors', () {
      fakeAsync((async) {
        const taskId = 'task-whose-last-agent-link-was-deleted';
        const reportId = 'report-left-by-deleted-agent-link';
        final agentRepository = MockAgentRepository();
        when(
          agentRepository.getAllAgentIdentities,
        ).thenAnswer((_) async => []);
        when(
          () => agentRepository.getLinksTo(
            taskId,
            type: AgentLinkTypes.agentTask,
          ),
        ).thenAnswer((_) async => []);
        when(
          () => mockEmbeddingStore.getEntityIdsForTask(taskId),
        ).thenReturn({reportId});
        when(
          () => mockEmbeddingStore.deleteEntityEmbeddings(reportId),
        ).thenReturn(null);

        service = EmbeddingService(
          embeddingStore: mockEmbeddingStore,
          embeddingRepository: mockEmbeddingRepo,
          journalDb: mockJournalDb,
          updateNotifications: updateNotifications,
          aiConfigRepository: mockAiConfigRepo,
          agentRepository: agentRepository,
        )..start();
        async.flushMicrotasks();

        updateNotifications.notify(
          {
            agentTaskLinkNotification,
            '$agentTaskLinkNotificationPrefix$taskId',
          },
          fromSync: true,
        );
        async
          ..elapse(const Duration(seconds: 1))
          ..flushMicrotasks();

        verify(
          () => mockEmbeddingStore.deleteEntityEmbeddings(reportId),
        ).called(1);
        stopInZone(async);
      });
    });

    test('local hard-delete signal removes report vectors', () {
      fakeAsync((async) {
        const taskId = 'task-whose-agent-was-hard-deleted-locally';
        const reportId = 'report-left-by-local-hard-delete';
        final agentRepository = MockAgentRepository();
        var scanCount = 0;
        when(agentRepository.getAllAgentIdentities).thenAnswer((_) async {
          scanCount++;
          return [];
        });
        when(
          () => agentRepository.getLinksTo(
            taskId,
            type: AgentLinkTypes.agentTask,
          ),
        ).thenAnswer((_) async => []);
        when(
          () => mockEmbeddingStore.getEntityIdsForTask(taskId),
        ).thenReturn({reportId});
        when(
          () => mockEmbeddingStore.deleteEntityEmbeddings(reportId),
        ).thenReturn(null);

        service = EmbeddingService(
          embeddingStore: mockEmbeddingStore,
          embeddingRepository: mockEmbeddingRepo,
          journalDb: mockJournalDb,
          updateNotifications: updateNotifications,
          aiConfigRepository: mockAiConfigRepo,
          agentRepository: agentRepository,
        )..start();
        async.flushMicrotasks();
        expect(scanCount, 1);

        updateNotifications.notify({
          '$agentTaskLinkNotificationPrefix$taskId',
        });
        async
          ..elapse(const Duration(seconds: 1))
          ..flushMicrotasks();
        stopInZone(async);

        verify(
          () => mockEmbeddingStore.deleteEntityEmbeddings(reportId),
        ).called(1);
        expect(scanCount, 1);
      });
    });

    test('synced task link update retains report vectors', () {
      fakeAsync((async) {
        const taskId = 'task-with-an-active-agent-link';
        final agentRepository = MockAgentRepository();
        when(
          agentRepository.getAllAgentIdentities,
        ).thenAnswer((_) async => []);
        when(
          () => agentRepository.getLinksTo(
            taskId,
            type: AgentLinkTypes.agentTask,
          ),
        ).thenAnswer(
          (_) async => [
            _agentTaskLink(agentId: 'active-agent', taskId: taskId),
          ],
        );

        service = EmbeddingService(
          embeddingStore: mockEmbeddingStore,
          embeddingRepository: mockEmbeddingRepo,
          journalDb: mockJournalDb,
          updateNotifications: updateNotifications,
          aiConfigRepository: mockAiConfigRepo,
          agentRepository: agentRepository,
        )..start();
        async.flushMicrotasks();

        updateNotifications.notify(
          {
            agentTaskLinkNotification,
            '$agentTaskLinkNotificationPrefix$taskId',
          },
          fromSync: true,
        );
        async
          ..elapse(const Duration(seconds: 1))
          ..flushMicrotasks();

        verifyNever(() => mockEmbeddingStore.getEntityIdsForTask(taskId));
        stopInZone(async);
      });
    });

    test('failed synced unlink cleanup retries on the next signal', () {
      fakeAsync((async) {
        const taskId = 'task-whose-unlink-cleanup-retries';
        const reportId = 'report-removed-by-retried-unlink-cleanup';
        final agentRepository = MockAgentRepository();
        var linkReadCount = 0;
        when(
          agentRepository.getAllAgentIdentities,
        ).thenAnswer((_) async => []);
        when(
          () => agentRepository.getLinksTo(
            taskId,
            type: AgentLinkTypes.agentTask,
          ),
        ).thenAnswer((_) async {
          linkReadCount++;
          if (linkReadCount == 1) {
            throw StateError('temporary link read failure');
          }
          return [];
        });
        when(
          () => mockEmbeddingStore.getEntityIdsForTask(taskId),
        ).thenReturn({reportId});
        when(
          () => mockEmbeddingStore.deleteEntityEmbeddings(reportId),
        ).thenReturn(null);

        service = EmbeddingService(
          embeddingStore: mockEmbeddingStore,
          embeddingRepository: mockEmbeddingRepo,
          journalDb: mockJournalDb,
          updateNotifications: updateNotifications,
          aiConfigRepository: mockAiConfigRepo,
          agentRepository: agentRepository,
        )..start();
        async.flushMicrotasks();

        updateNotifications.notify(
          {
            agentTaskLinkNotification,
            '$agentTaskLinkNotificationPrefix$taskId',
          },
          fromSync: true,
        );
        async
          ..elapse(const Duration(seconds: 1))
          ..flushMicrotasks();
        verifyNever(
          () => mockEmbeddingStore.deleteEntityEmbeddings(reportId),
        );

        updateNotifications.notify(
          {agentTaskLinkNotification},
          fromSync: true,
        );
        async
          ..elapse(const Duration(seconds: 1))
          ..flushMicrotasks();

        expect(linkReadCount, 2);
        verify(
          () => mockEmbeddingStore.deleteEntityEmbeddings(reportId),
        ).called(1);
        stopInZone(async);
      });
    });

    test('synced agent notifications request report reconciliation', () {
      fakeAsync((async) {
        const agentId = 'agent-notification-recovery';
        const taskId = 'task-notification-recovery';
        final agentRepository = MockAgentRepository();
        final report = _agentReport(
          id: 'report-notification-recovery',
          agentId: agentId,
        );
        var scanCount = 0;

        when(agentRepository.getAllAgentIdentities).thenAnswer((_) async {
          scanCount++;
          return scanCount == 1 ? [] : [_agentIdentity(agentId)];
        });
        when(
          () => agentRepository.getLinksFrom(
            agentId,
            type: AgentLinkTypes.agentTask,
          ),
        ).thenAnswer(
          (_) async => [_agentTaskLink(agentId: agentId, taskId: taskId)],
        );
        stubPrimaryTaskAgent(
          agentRepository,
          agentId: agentId,
          taskId: taskId,
        );
        when(
          () => agentRepository.getLatestReport(
            agentId,
            AgentReportScopes.current,
          ),
        ).thenAnswer((_) async => report);
        when(
          () => mockJournalDb.journalEntityById(taskId),
        ).thenAnswer((_) async => null);
        stubEmbedding();

        service = EmbeddingService(
          embeddingStore: mockEmbeddingStore,
          embeddingRepository: mockEmbeddingRepo,
          journalDb: mockJournalDb,
          updateNotifications: updateNotifications,
          aiConfigRepository: mockAiConfigRepo,
          agentRepository: agentRepository,
        )..start();
        async.flushMicrotasks();
        expect(scanCount, 1);

        updateNotifications.notify(
          {agentId, agentReportHeadNotification},
          fromSync: true,
        );
        async
          ..elapse(const Duration(seconds: 1))
          ..flushMicrotasks();

        expect(scanCount, 2);
        verify(
          () => mockEmbeddingStore.replaceEntityEmbeddings(
            entityId: report.id,
            entityType: kEntityTypeAgentReport,
            modelId: any(named: 'modelId'),
            contentHash: any(named: 'contentHash'),
            embeddings: any(named: 'embeddings'),
            categoryId: any(named: 'categoryId'),
            taskId: taskId,
            subtype: AgentReportScopes.current,
          ),
        ).called(1);
        stopInZone(async);
      });
    });

    test('synced report arrival retries a previously missing current body', () {
      fakeAsync((async) {
        const agentId = 'agent-report-arrival';
        const taskId = 'task-report-arrival';
        final agentRepository = MockAgentRepository();
        AgentReportEntity? currentReport;
        when(
          agentRepository.getAllAgentIdentities,
        ).thenAnswer((_) async => [_agentIdentity(agentId)]);
        when(
          () => agentRepository.getLinksFrom(
            agentId,
            type: AgentLinkTypes.agentTask,
          ),
        ).thenAnswer(
          (_) async => [_agentTaskLink(agentId: agentId, taskId: taskId)],
        );
        stubPrimaryTaskAgent(
          agentRepository,
          agentId: agentId,
          taskId: taskId,
        );
        when(
          () => agentRepository.getLatestReport(
            agentId,
            AgentReportScopes.current,
          ),
        ).thenAnswer((_) async => currentReport);
        when(
          () => mockJournalDb.journalEntityById(taskId),
        ).thenAnswer((_) async => null);
        stubEmbedding();

        service = EmbeddingService(
          embeddingStore: mockEmbeddingStore,
          embeddingRepository: mockEmbeddingRepo,
          journalDb: mockJournalDb,
          updateNotifications: updateNotifications,
          aiConfigRepository: mockAiConfigRepo,
          agentRepository: agentRepository,
        )..start();
        async.flushMicrotasks();
        verifyNever(
          () => mockEmbeddingStore.replaceEntityEmbeddings(
            entityId: any(named: 'entityId'),
            entityType: any(named: 'entityType'),
            modelId: any(named: 'modelId'),
            contentHash: any(named: 'contentHash'),
            embeddings: any(named: 'embeddings'),
            categoryId: any(named: 'categoryId'),
            taskId: any(named: 'taskId'),
            subtype: any(named: 'subtype'),
          ),
        );

        currentReport = _agentReport(
          id: 'report-arrived-after-head',
          agentId: agentId,
        );
        updateNotifications.notify(
          {agentId, agentReportNotification},
          fromSync: true,
        );
        async
          ..elapse(const Duration(seconds: 1))
          ..flushMicrotasks();

        verify(
          () => mockEmbeddingStore.replaceEntityEmbeddings(
            entityId: currentReport!.id,
            entityType: kEntityTypeAgentReport,
            modelId: any(named: 'modelId'),
            contentHash: any(named: 'contentHash'),
            embeddings: any(named: 'embeddings'),
            categoryId: any(named: 'categoryId'),
            taskId: taskId,
            subtype: AgentReportScopes.current,
          ),
        ).called(1);
        stopInZone(async);
      });
    });

    test('synced task change retries report relocation after an outage', () {
      fakeAsync((async) {
        const agentId = 'agent-synced-task-category';
        const taskId = 'task-synced-task-category';
        const oldCategoryId = 'category-before-task-sync';
        const newCategoryId = 'category-after-task-sync';
        final agentRepository = MockAgentRepository();
        final report = _agentReport(
          id: 'report-synced-task-category',
          agentId: agentId,
        );
        final storedCategories = <String>[];
        var embedCallCount = 0;
        var categoryChanged = false;
        var scanCount = 0;
        when(agentRepository.getAllAgentIdentities).thenAnswer((_) async {
          scanCount++;
          return [_agentIdentity(agentId)];
        });
        when(
          () => agentRepository.getEntity(agentId),
        ).thenAnswer((_) async => _agentIdentity(agentId));
        when(
          () => agentRepository.getLinksFrom(
            agentId,
            type: AgentLinkTypes.agentTask,
          ),
        ).thenAnswer(
          (_) async => [_agentTaskLink(agentId: agentId, taskId: taskId)],
        );
        stubPrimaryTaskAgent(
          agentRepository,
          agentId: agentId,
          taskId: taskId,
        );
        when(
          () => agentRepository.getLatestReport(
            agentId,
            AgentReportScopes.current,
          ),
        ).thenAnswer((_) async => report);
        when(
          () => mockJournalDb.journalEntityById(taskId),
        ).thenAnswer(
          (_) async => TestTaskFactory.create(
            id: taskId,
            title: 'Task category changed through sync',
            categoryId: categoryChanged ? newCategoryId : oldCategoryId,
          ),
        );
        when(
          () => mockEmbeddingRepo.embed(
            input: any(named: 'input'),
            baseUrl: any(named: 'baseUrl'),
            model: any(named: 'model'),
          ),
        ).thenAnswer((_) async {
          embedCallCount++;
          if (embedCallCount == 2) {
            throw OllamaEmbeddingCooldownException(
              retryAt: clock.now().add(
                OllamaEmbeddingRepository.availabilityCooldown,
              ),
              suppressedRequestCount: 1,
            );
          }
          return _fakeEmbedding();
        });
        when(
          () => mockEmbeddingStore.replaceEntityEmbeddings(
            entityId: report.id,
            entityType: kEntityTypeAgentReport,
            modelId: any(named: 'modelId'),
            contentHash: any(named: 'contentHash'),
            embeddings: any(named: 'embeddings'),
            categoryId: any(named: 'categoryId'),
            taskId: taskId,
            subtype: AgentReportScopes.current,
          ),
        ).thenAnswer((invocation) {
          storedCategories.add(
            invocation.namedArguments[#categoryId]! as String,
          );
        });

        service = EmbeddingService(
          embeddingStore: mockEmbeddingStore,
          embeddingRepository: mockEmbeddingRepo,
          journalDb: mockJournalDb,
          updateNotifications: updateNotifications,
          aiConfigRepository: mockAiConfigRepo,
          agentRepository: agentRepository,
        )..start();
        async.flushMicrotasks();
        expect(storedCategories, [oldCategoryId]);
        expect(scanCount, 1);

        categoryChanged = true;
        updateNotifications.notify(
          {
            taskId,
            taskNotification,
            '$taskNotificationPrefix$taskId',
          },
          fromSync: true,
        );
        async
          ..elapse(const Duration(seconds: 1))
          ..flushMicrotasks();

        expect(embedCallCount, 2);
        expect(storedCategories, [oldCategoryId]);
        expect(scanCount, 1);

        async
          ..elapse(OllamaEmbeddingRepository.availabilityCooldown)
          ..flushMicrotasks();

        expect(embedCallCount, 3);
        expect(storedCategories, [oldCategoryId, newCategoryId]);
        expect(scanCount, 1);
        stopInZone(async);
      });
    });

    test('failed synced task recovery retries only that task', () {
      fakeAsync((async) {
        const agentId = 'agent-targeted-task-retry';
        const taskId = 'task-targeted-retry';
        final agentRepository = MockAgentRepository();
        final report = _agentReport(
          id: 'report-targeted-task-retry',
          agentId: agentId,
        );
        var agentReadCount = 0;
        var scanCount = 0;

        when(agentRepository.getAllAgentIdentities).thenAnswer((_) async {
          scanCount++;
          return [];
        });
        stubPrimaryTaskAgent(
          agentRepository,
          agentId: agentId,
          taskId: taskId,
        );
        when(() => agentRepository.getEntity(agentId)).thenAnswer((_) async {
          agentReadCount++;
          if (agentReadCount == 1) {
            throw StateError('temporary targeted agent read failure');
          }
          return _agentIdentity(agentId);
        });
        when(
          () => agentRepository.getLatestReport(
            agentId,
            AgentReportScopes.current,
          ),
        ).thenAnswer((_) async => report);
        when(
          () => mockJournalDb.journalEntityById(taskId),
        ).thenAnswer((_) async => null);
        stubEmbedding();

        service = EmbeddingService(
          embeddingStore: mockEmbeddingStore,
          embeddingRepository: mockEmbeddingRepo,
          journalDb: mockJournalDb,
          updateNotifications: updateNotifications,
          aiConfigRepository: mockAiConfigRepo,
          agentRepository: agentRepository,
        )..start();
        async.flushMicrotasks();

        void notifyTaskChanged() {
          updateNotifications.notify(
            {taskNotification, '$taskNotificationPrefix$taskId'},
            fromSync: true,
          );
          async
            ..elapse(const Duration(seconds: 1))
            ..flushMicrotasks();
        }

        notifyTaskChanged();

        expect(agentReadCount, 1);
        verifyNever(
          () => mockEmbeddingStore.replaceEntityEmbeddings(
            entityId: report.id,
            entityType: any(named: 'entityType'),
            modelId: any(named: 'modelId'),
            contentHash: any(named: 'contentHash'),
            embeddings: any(named: 'embeddings'),
            categoryId: any(named: 'categoryId'),
            taskId: taskId,
            subtype: any(named: 'subtype'),
          ),
        );

        notifyTaskChanged();

        expect(agentReadCount, 2);
        expect(scanCount, 1);
        verify(
          () => mockEmbeddingStore.replaceEntityEmbeddings(
            entityId: report.id,
            entityType: kEntityTypeAgentReport,
            modelId: any(named: 'modelId'),
            contentHash: any(named: 'contentHash'),
            embeddings: any(named: 'embeddings'),
            categoryId: any(named: 'categoryId'),
            taskId: taskId,
            subtype: AgentReportScopes.current,
          ),
        ).called(1);
        stopInZone(async);
      });
    });

    test('generic synced agent notifications do not scan report heads', () {
      fakeAsync((async) {
        final agentRepository = MockAgentRepository();
        var scanCount = 0;
        when(agentRepository.getAllAgentIdentities).thenAnswer((_) async {
          scanCount++;
          return [];
        });

        service = EmbeddingService(
          embeddingStore: mockEmbeddingStore,
          embeddingRepository: mockEmbeddingRepo,
          journalDb: mockJournalDb,
          updateNotifications: updateNotifications,
          aiConfigRepository: mockAiConfigRepo,
          agentRepository: agentRepository,
        )..start();
        async.flushMicrotasks();
        expect(scanCount, 1);

        updateNotifications.notify(
          {agentNotification},
          fromSync: true,
        );
        async
          ..elapse(const Duration(seconds: 1))
          ..flushMicrotasks();

        expect(scanCount, 1);
        stopInZone(async);
      });
    });

    test('coalesces a local agent notification received during recovery', () {
      fakeAsync((async) {
        final agentRepository = MockAgentRepository();
        final firstScan = Completer<List<AgentIdentityEntity>>();
        var scanCount = 0;

        when(agentRepository.getAllAgentIdentities).thenAnswer((_) {
          scanCount++;
          return scanCount == 1 ? firstScan.future : Future.value([]);
        });

        service = EmbeddingService(
          embeddingStore: mockEmbeddingStore,
          embeddingRepository: mockEmbeddingRepo,
          journalDb: mockJournalDb,
          updateNotifications: updateNotifications,
          aiConfigRepository: mockAiConfigRepo,
          agentRepository: agentRepository,
        )..start();
        async.flushMicrotasks();
        expect(scanCount, 1);

        updateNotifications.notify({agentNotification});
        async
          ..elapse(const Duration(milliseconds: 150))
          ..flushMicrotasks();
        expect(scanCount, 1);

        firstScan.complete([]);
        async.flushMicrotasks();

        expect(scanCount, 2);
        stopInZone(async);
      });
    });

    test('a synced agent notification retries recovery before cooldown', () {
      fakeAsync((async) {
        const agentId = 'agent-sync-retry';
        const taskId = 'task-sync-retry';
        final agentRepository = MockAgentRepository();
        final report = _agentReport(id: 'report-sync-retry', agentId: agentId);
        var embedCallCount = 0;

        when(
          agentRepository.getAllAgentIdentities,
        ).thenAnswer((_) async => [_agentIdentity(agentId)]);
        when(
          () => agentRepository.getLinksFrom(
            agentId,
            type: AgentLinkTypes.agentTask,
          ),
        ).thenAnswer(
          (_) async => [_agentTaskLink(agentId: agentId, taskId: taskId)],
        );
        stubPrimaryTaskAgent(
          agentRepository,
          agentId: agentId,
          taskId: taskId,
        );
        when(
          () => agentRepository.getLatestReport(
            agentId,
            AgentReportScopes.current,
          ),
        ).thenAnswer((_) async => report);
        when(
          () => mockJournalDb.journalEntityById(taskId),
        ).thenAnswer((_) async => null);
        when(
          () => mockEmbeddingRepo.embed(
            input: any(named: 'input'),
            baseUrl: any(named: 'baseUrl'),
            model: any(named: 'model'),
          ),
        ).thenAnswer((_) async {
          embedCallCount++;
          if (embedCallCount == 1) {
            throw OllamaEmbeddingCooldownException(
              retryAt: clock.now().add(
                OllamaEmbeddingRepository.availabilityCooldown,
              ),
              suppressedRequestCount: 1,
            );
          }
          return _fakeEmbedding();
        });

        service = EmbeddingService(
          embeddingStore: mockEmbeddingStore,
          embeddingRepository: mockEmbeddingRepo,
          journalDb: mockJournalDb,
          updateNotifications: updateNotifications,
          aiConfigRepository: mockAiConfigRepo,
          agentRepository: agentRepository,
        )..start();
        async.flushMicrotasks();
        expect(embedCallCount, 1);

        updateNotifications.notify(
          {agentReportHeadNotification},
          fromSync: true,
        );
        async
          ..elapse(const Duration(seconds: 1))
          ..flushMicrotasks();

        expect(embedCallCount, 2);
        verify(
          () => mockEmbeddingStore.replaceEntityEmbeddings(
            entityId: report.id,
            entityType: kEntityTypeAgentReport,
            modelId: any(named: 'modelId'),
            contentHash: any(named: 'contentHash'),
            embeddings: any(named: 'embeddings'),
            categoryId: any(named: 'categoryId'),
            taskId: taskId,
            subtype: AgentReportScopes.current,
          ),
        ).called(1);
        stopInZone(async);
      });
    });

    test(
      'startup keeps historical coverage when the current report is not '
      'searchable',
      () async {
        const agentId = 'agent-unsearchable';
        const taskId = 'task-unsearchable';
        final agentRepository = MockAgentRepository();
        final report = _agentReport(
          id: 'report-unsearchable',
          agentId: agentId,
        );
        final hash = EmbeddingContentExtractor.contentHash(report.content);
        final searchableChecked = Completer<void>();

        when(
          agentRepository.getAllAgentIdentities,
        ).thenAnswer((_) async => [_agentIdentity(agentId)]);
        when(
          () => agentRepository.getLinksFrom(
            agentId,
            type: AgentLinkTypes.agentTask,
          ),
        ).thenAnswer(
          (_) async => [_agentTaskLink(agentId: agentId, taskId: taskId)],
        );
        stubPrimaryTaskAgent(
          agentRepository,
          agentId: agentId,
          taskId: taskId,
        );
        when(
          () => agentRepository.getLatestReport(
            agentId,
            AgentReportScopes.current,
          ),
        ).thenAnswer((_) async => report);
        when(
          () => mockJournalDb.journalEntityById(taskId),
        ).thenAnswer((_) async => null);
        when(
          () => mockEmbeddingStore.getContentHash(report.id),
        ).thenReturn(hash);
        when(
          () => mockEmbeddingStore.hasEmbedding(report.id),
        ).thenAnswer((_) {
          searchableChecked.complete();
          return false;
        });

        service = EmbeddingService(
          embeddingStore: mockEmbeddingStore,
          embeddingRepository: mockEmbeddingRepo,
          journalDb: mockJournalDb,
          updateNotifications: updateNotifications,
          aiConfigRepository: mockAiConfigRepo,
          agentRepository: agentRepository,
        )..start();

        await searchableChecked.future;
        await pumpEventQueue();

        verifyNever(() => mockEmbeddingStore.getEntityIdsForTask(taskId));
        verifyNever(
          () => mockEmbeddingStore.deleteEntityEmbeddings(any()),
        );
      },
    );

    test('startup report recovery retries after an Ollama outage', () {
      fakeAsync((async) {
        const agentId = 'agent-retry';
        const taskId = 'task-retry';
        final agentRepository = MockAgentRepository();
        final report = _agentReport(id: 'report-retry', agentId: agentId);
        var embedCallCount = 0;

        when(
          agentRepository.getAllAgentIdentities,
        ).thenAnswer((_) async => [_agentIdentity(agentId)]);
        when(
          () => agentRepository.getLinksFrom(
            agentId,
            type: AgentLinkTypes.agentTask,
          ),
        ).thenAnswer(
          (_) async => [_agentTaskLink(agentId: agentId, taskId: taskId)],
        );
        stubPrimaryTaskAgent(
          agentRepository,
          agentId: agentId,
          taskId: taskId,
        );
        when(
          () => agentRepository.getLatestReport(
            agentId,
            AgentReportScopes.current,
          ),
        ).thenAnswer((_) async => report);
        when(
          () => agentRepository.getEntitiesByAgentIdAndSubtype(
            agentId,
            type: AgentEntityTypes.agentReport,
            subtype: AgentReportScopes.current,
          ),
        ).thenAnswer((_) async => [report]);
        when(
          () => mockJournalDb.journalEntityById(taskId),
        ).thenAnswer((_) async => null);
        when(
          () => mockEmbeddingRepo.embed(
            input: any(named: 'input'),
            baseUrl: any(named: 'baseUrl'),
            model: any(named: 'model'),
          ),
        ).thenAnswer((_) async {
          embedCallCount++;
          if (embedCallCount == 1) {
            throw OllamaEmbeddingCooldownException(
              retryAt: clock.now().add(
                OllamaEmbeddingRepository.availabilityCooldown,
              ),
              suppressedRequestCount: 1,
            );
          }
          return _fakeEmbedding();
        });

        service = EmbeddingService(
          embeddingStore: mockEmbeddingStore,
          embeddingRepository: mockEmbeddingRepo,
          journalDb: mockJournalDb,
          updateNotifications: updateNotifications,
          aiConfigRepository: mockAiConfigRepo,
          agentRepository: agentRepository,
        )..start();
        async.flushMicrotasks();

        expect(embedCallCount, 1);

        async
          ..elapse(OllamaEmbeddingRepository.availabilityCooldown)
          ..flushMicrotasks();

        expect(embedCallCount, 2);
        verify(
          () => mockEmbeddingStore.replaceEntityEmbeddings(
            entityId: report.id,
            entityType: kEntityTypeAgentReport,
            modelId: any(named: 'modelId'),
            contentHash: any(named: 'contentHash'),
            embeddings: any(named: 'embeddings'),
            categoryId: any(named: 'categoryId'),
            taskId: taskId,
            subtype: AgentReportScopes.current,
          ),
        ).called(1);

        stopInZone(async);
      });
    });

    test(
      'partial topology recovery retries on the next provider signal',
      () async {
        const failedAgentId = 'agent-failed';
        const recoveredAgentId = 'agent-recovered';
        const taskId = 'task-recovered';
        final agentRepository = MockAgentRepository();
        final providerConfigs = StreamController<List<AiConfig>>.broadcast(
          sync: true,
        );
        addTearDown(providerConfigs.close);
        final report = _agentReport(
          id: 'report-recovered',
          agentId: recoveredAgentId,
        );
        final failedTopologyRead = Completer<void>();
        final reportStored = Completer<void>();
        var failedAgentReadCount = 0;

        when(
          () => mockAiConfigRepo.watchConfigsByType(
            AiConfigType.inferenceProvider,
          ),
        ).thenAnswer((_) => providerConfigs.stream);

        when(agentRepository.getAllAgentIdentities).thenAnswer(
          (_) async => [
            _agentIdentity(failedAgentId),
            _agentIdentity(recoveredAgentId),
          ],
        );
        when(
          () => agentRepository.getLinksFrom(
            failedAgentId,
            type: AgentLinkTypes.agentTask,
          ),
        ).thenAnswer((_) async {
          failedAgentReadCount++;
          if (failedAgentReadCount == 1) {
            failedTopologyRead.complete();
            throw StateError('agent DB read failed');
          }
          return [];
        });
        when(
          () => agentRepository.getLinksFrom(
            recoveredAgentId,
            type: AgentLinkTypes.agentTask,
          ),
        ).thenAnswer(
          (_) async => [
            _agentTaskLink(agentId: recoveredAgentId, taskId: taskId),
          ],
        );
        stubPrimaryTaskAgent(
          agentRepository,
          agentId: recoveredAgentId,
          taskId: taskId,
        );
        when(
          () => agentRepository.getLatestReport(
            recoveredAgentId,
            AgentReportScopes.current,
          ),
        ).thenAnswer((_) async => report);
        when(
          () => agentRepository.getEntitiesByAgentIdAndSubtype(
            recoveredAgentId,
            type: AgentEntityTypes.agentReport,
            subtype: AgentReportScopes.current,
          ),
        ).thenAnswer((_) async => [report]);
        when(
          () => mockJournalDb.journalEntityById(taskId),
        ).thenAnswer((_) async => null);
        stubEmbedding();
        when(
          () => mockEmbeddingStore.replaceEntityEmbeddings(
            entityId: report.id,
            entityType: any(named: 'entityType'),
            modelId: any(named: 'modelId'),
            contentHash: any(named: 'contentHash'),
            embeddings: any(named: 'embeddings'),
            categoryId: any(named: 'categoryId'),
            taskId: taskId,
            subtype: AgentReportScopes.current,
          ),
        ).thenAnswer((_) {
          reportStored.complete();
        });

        service = EmbeddingService(
          embeddingStore: mockEmbeddingStore,
          embeddingRepository: mockEmbeddingRepo,
          journalDb: mockJournalDb,
          updateNotifications: updateNotifications,
          aiConfigRepository: mockAiConfigRepo,
          agentRepository: agentRepository,
        )..start();

        providerConfigs.add(const []);
        await failedTopologyRead.future;
        await pumpEventQueue();
        verifyNever(
          () => mockEmbeddingStore.replaceEntityEmbeddings(
            entityId: report.id,
            entityType: any(named: 'entityType'),
            modelId: any(named: 'modelId'),
            contentHash: any(named: 'contentHash'),
            embeddings: any(named: 'embeddings'),
            categoryId: any(named: 'categoryId'),
            taskId: taskId,
            subtype: AgentReportScopes.current,
          ),
        );

        providerConfigs.add(const []);
        await reportStored.future;
        await pumpEventQueue();

        expect(failedAgentReadCount, 2);
        verify(
          () => agentRepository.getLinksFrom(
            recoveredAgentId,
            type: AgentLinkTypes.agentTask,
          ),
        ).called(2);
      },
    );

    test('startup report recovery continues after one task fails', () async {
      const failedAgentId = 'agent-report-failed';
      const failedTaskId = 'task-report-failed';
      const recoveredAgentId = 'agent-report-recovered';
      const recoveredTaskId = 'task-report-recovered';
      final agentRepository = MockAgentRepository();
      final report = _agentReport(
        id: 'report-after-task-failure',
        agentId: recoveredAgentId,
      );
      final reportStored = Completer<void>();

      when(agentRepository.getAllAgentIdentities).thenAnswer(
        (_) async => [
          _agentIdentity(failedAgentId),
          _agentIdentity(recoveredAgentId),
        ],
      );
      when(
        () => agentRepository.getLinksFrom(
          failedAgentId,
          type: AgentLinkTypes.agentTask,
        ),
      ).thenAnswer(
        (_) async => [
          _agentTaskLink(agentId: failedAgentId, taskId: failedTaskId),
        ],
      );
      when(
        () => agentRepository.getLinksFrom(
          recoveredAgentId,
          type: AgentLinkTypes.agentTask,
        ),
      ).thenAnswer(
        (_) async => [
          _agentTaskLink(
            agentId: recoveredAgentId,
            taskId: recoveredTaskId,
          ),
        ],
      );
      stubPrimaryTaskAgent(
        agentRepository,
        agentId: recoveredAgentId,
        taskId: recoveredTaskId,
      );
      when(
        () => agentRepository.getLatestReport(
          failedAgentId,
          AgentReportScopes.current,
        ),
      ).thenThrow(StateError('report head read failed'));
      when(
        () => agentRepository.getLatestReport(
          recoveredAgentId,
          AgentReportScopes.current,
        ),
      ).thenAnswer((_) async => report);
      when(
        () => agentRepository.getEntitiesByAgentIdAndSubtype(
          recoveredAgentId,
          type: AgentEntityTypes.agentReport,
          subtype: AgentReportScopes.current,
        ),
      ).thenAnswer((_) async => [report]);
      when(
        () => mockJournalDb.journalEntityById(failedTaskId),
      ).thenAnswer((_) async => null);
      when(
        () => mockJournalDb.journalEntityById(recoveredTaskId),
      ).thenAnswer((_) async => null);
      stubEmbedding();
      when(
        () => mockEmbeddingStore.replaceEntityEmbeddings(
          entityId: report.id,
          entityType: any(named: 'entityType'),
          modelId: any(named: 'modelId'),
          contentHash: any(named: 'contentHash'),
          embeddings: any(named: 'embeddings'),
          categoryId: any(named: 'categoryId'),
          taskId: recoveredTaskId,
          subtype: AgentReportScopes.current,
        ),
      ).thenAnswer((_) {
        reportStored.complete();
      });

      service = EmbeddingService(
        embeddingStore: mockEmbeddingStore,
        embeddingRepository: mockEmbeddingRepo,
        journalDb: mockJournalDb,
        updateNotifications: updateNotifications,
        aiConfigRepository: mockAiConfigRepo,
        agentRepository: agentRepository,
      )..start();

      await reportStored.future;
      await pumpEventQueue();

      verify(
        () => agentRepository.getLatestReport(
          failedAgentId,
          AgentReportScopes.current,
        ),
      ).called(1);
    });

    test('startup report recovery contains repository failures', () async {
      final agentRepository = MockAgentRepository();
      final readAttempted = Completer<void>();
      when(agentRepository.getAllAgentIdentities).thenAnswer((_) {
        readAttempted.complete();
        throw StateError('agent database unavailable');
      });

      service = EmbeddingService(
        embeddingStore: mockEmbeddingStore,
        embeddingRepository: mockEmbeddingRepo,
        journalDb: mockJournalDb,
        updateNotifications: updateNotifications,
        aiConfigRepository: mockAiConfigRepo,
        agentRepository: agentRepository,
      )..start();

      await readAttempted.future;
      await pumpEventQueue();

      verify(agentRepository.getAllAgentIdentities).called(1);
      verifyNever(
        () => mockEmbeddingRepo.embed(
          input: any(named: 'input'),
          baseUrl: any(named: 'baseUrl'),
          model: any(named: 'model'),
        ),
      );
    });

    test('stop waits for the in-flight embedding before returning', () async {
      // Real-async on purpose: fakeAsync cannot resolve the broadcast
      // cancel future stop() awaits (see the Glados driver note below), so
      // this is the one place the in-flight handshake runs on real time.
      final entry = JournalEntry(
        meta: _meta(),
        entryText: const EntryText(plainText: _longText),
      );
      stubEntity(entry);

      final embedStarted = Completer<void>();
      final embedGate = Completer<Float32List>();
      when(
        () => mockEmbeddingRepo.embed(
          input: any(named: 'input'),
          baseUrl: any(named: 'baseUrl'),
          model: any(named: 'model'),
        ),
      ).thenAnswer((_) {
        if (!embedStarted.isCompleted) embedStarted.complete();
        return embedGate.future;
      });

      service.start();
      updateNotifications.notify({_entityId, textEntryNotification});

      // The embedding request is now in flight (_isProcessing = true).
      await embedStarted.future;

      var stopReturned = false;
      final stopFuture = service.stop().then((_) => stopReturned = true);
      await pumpEventQueue();
      expect(
        stopReturned,
        isFalse,
        reason: 'stop() must wait for the in-flight embedding',
      );

      // Release the gated embedding: stop() may now complete.
      embedGate.complete(_fakeEmbedding());
      await stopFuture;
      expect(stopReturned, isTrue);
    });

    test('skips when content hash matches (unchanged content)', () {
      fakeAsync((async) {
        final entry = JournalEntry(
          meta: _meta(),
          entryText: const EntryText(plainText: _longText),
        );
        stubEntity(entry);

        // Simulate existing hash that matches current content.
        when(
          () => mockEmbeddingStore.getContentHash(_entityId),
        ).thenReturn(EmbeddingContentExtractor.contentHash(_longText));

        service.start();
        sendAndProcess(async, {_entityId, textEntryNotification});

        verifyNever(
          () => mockEmbeddingRepo.embed(
            input: any(named: 'input'),
            baseUrl: any(named: 'baseUrl'),
            model: any(named: 'model'),
          ),
        );

        stopInZone(async);
      });
    });

    test('skips when entity not found in DB', () {
      fakeAsync((async) {
        when(
          () => mockJournalDb.journalEntityById(_entityId),
        ).thenAnswer((_) async => null);

        service.start();
        sendAndProcess(async, {_entityId, textEntryNotification});

        verifyNever(
          () => mockEmbeddingRepo.embed(
            input: any(named: 'input'),
            baseUrl: any(named: 'baseUrl'),
            model: any(named: 'model'),
          ),
        );

        stopInZone(async);
      });
    });

    test('skips when entity has no embeddable text', () {
      fakeAsync((async) {
        // JournalEntry with short text below threshold
        final entry = JournalEntry(
          meta: _meta(),
          entryText: const EntryText(plainText: 'short'),
        );
        stubEntity(entry);

        service.start();
        sendAndProcess(async, {_entityId, textEntryNotification});

        verifyNever(
          () => mockEmbeddingRepo.embed(
            input: any(named: 'input'),
            baseUrl: any(named: 'baseUrl'),
            model: any(named: 'model'),
          ),
        );

        stopInZone(async);
      });
    });

    test('skips when config flag is disabled', () {
      fakeAsync((async) {
        when(
          () => mockJournalDb.getConfigFlag(enableEmbeddingsFlag),
        ).thenAnswer((_) async => false);

        final entry = JournalEntry(
          meta: _meta(),
          entryText: const EntryText(plainText: _longText),
        );
        stubEntity(entry);
        stubEmbedding();

        service.start();
        sendAndProcess(async, {_entityId, textEntryNotification});

        verifyNever(
          () => mockEmbeddingRepo.embed(
            input: any(named: 'input'),
            baseUrl: any(named: 'baseUrl'),
            model: any(named: 'model'),
          ),
        );

        stopInZone(async);
      });
    });

    test('skips when no Ollama provider is configured', () {
      fakeAsync((async) {
        when(
          () => mockAiConfigRepo.resolveOllamaBaseUrl(),
        ).thenAnswer((_) async => null);

        final entry = JournalEntry(
          meta: _meta(),
          entryText: const EntryText(plainText: _longText),
        );
        stubEntity(entry);

        service.start();
        sendAndProcess(async, {_entityId, textEntryNotification});

        verifyNever(
          () => mockEmbeddingRepo.embed(
            input: any(named: 'input'),
            baseUrl: any(named: 'baseUrl'),
            model: any(named: 'model'),
          ),
        );

        stopInZone(async);
      });
    });

    test('ignores notification batches without relevant type tokens', () {
      fakeAsync((async) {
        final entry = JournalEntry(
          meta: _meta(),
          entryText: const EntryText(plainText: _longText),
        );
        stubEntity(entry);
        stubEmbedding();

        service.start();
        // Send only entity ID with an irrelevant type token
        sendAndProcess(async, {_entityId, imageNotification});

        verifyNever(
          () => mockEmbeddingRepo.embed(
            input: any(named: 'input'),
            baseUrl: any(named: 'baseUrl'),
            model: any(named: 'model'),
          ),
        );

        stopInZone(async);
      });
    });

    test(
      'mixed batch: processes the valid entity ID and skips the invalid '
      'UUID token',
      () {
        fakeAsync((async) {
          final entry = JournalEntry(
            meta: _meta(),
            entryText: const EntryText(plainText: _longText),
          );
          stubEntity(entry);
          stubEmbedding();

          service.start();
          // Relevant type token + one garbage token + one valid entity id.
          sendAndProcess(async, {
            textEntryNotification,
            'NOT-A-UUID',
            _entityId,
          });

          // The valid entity was looked up and embedded…
          verify(() => mockJournalDb.journalEntityById(_entityId)).called(1);
          verify(
            () => mockEmbeddingRepo.embed(
              input: any(named: 'input'),
              baseUrl: any(named: 'baseUrl'),
              model: any(named: 'model'),
            ),
          ).called(greaterThanOrEqualTo(1));
          // …while the non-UUID token never reached the database.
          verifyNever(() => mockJournalDb.journalEntityById('NOT-A-UUID'));

          stopInZone(async);
        });
      },
    );

    test('continues processing after Ollama error', () {
      fakeAsync((async) {
        const entityId2 = 'ffffffff-bbbb-cccc-dddd-eeeeeeeeeeee';

        final entry1 = JournalEntry(
          meta: _meta(),
          entryText: const EntryText(plainText: _longText),
        );
        final entry2 = JournalEntry(
          meta: _meta(id: entityId2),
          entryText: const EntryText(
            plainText: 'Another long enough text for embedding generation.',
          ),
        );

        stubEntity(entry1);
        when(
          () => mockJournalDb.journalEntityById(entityId2),
        ).thenAnswer((_) async => entry2);

        // First call throws, second succeeds
        var callCount = 0;
        when(
          () => mockEmbeddingRepo.embed(
            input: any(named: 'input'),
            baseUrl: any(named: 'baseUrl'),
            model: any(named: 'model'),
          ),
        ).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) throw Exception('Ollama is down');
          return _fakeEmbedding();
        });

        service.start();
        sendAndProcess(
          async,
          {_entityId, entityId2, textEntryNotification},
        );

        // Both entities were attempted despite first failing
        verify(
          () => mockEmbeddingRepo.embed(
            input: any(named: 'input'),
            baseUrl: any(named: 'baseUrl'),
            model: any(named: 'model'),
          ),
        ).called(2);

        // Only second entity was stored (first failed)
        verify(
          () => mockEmbeddingStore.replaceEntityEmbeddings(
            entityId: entityId2,
            entityType: any(named: 'entityType'),
            modelId: any(named: 'modelId'),
            contentHash: any(named: 'contentHash'),
            embeddings: any(named: 'embeddings'),
            categoryId: any(named: 'categoryId'),
          ),
        ).called(1);

        stopInZone(async);
      });
    });

    test('stops the current batch when Ollama is cooling down', () {
      fakeAsync((async) {
        const entityId2 = 'ffffffff-bbbb-cccc-dddd-eeeeeeeeeeee';
        final entry1 = JournalEntry(
          meta: _meta(),
          entryText: const EntryText(plainText: _longText),
        );
        final entry2 = JournalEntry(
          meta: _meta(id: entityId2),
          entryText: const EntryText(
            plainText: 'Another long enough text for embedding generation.',
          ),
        );
        stubEntity(entry1);
        when(
          () => mockJournalDb.journalEntityById(entityId2),
        ).thenAnswer((_) async => entry2);
        when(
          () => mockEmbeddingRepo.embed(
            input: any(named: 'input'),
            baseUrl: any(named: 'baseUrl'),
            model: any(named: 'model'),
          ),
        ).thenThrow(
          OllamaEmbeddingCooldownException(
            retryAt: clock.now().add(
              OllamaEmbeddingRepository.availabilityCooldown,
            ),
            suppressedRequestCount: 1,
          ),
        );

        service.start();
        sendAndProcess(
          async,
          {_entityId, entityId2, textEntryNotification},
        );

        verify(
          () => mockEmbeddingRepo.embed(
            input: any(named: 'input'),
            baseUrl: any(named: 'baseUrl'),
            model: any(named: 'model'),
          ),
        ).called(1);
        verifyNever(() => mockJournalDb.journalEntityById(entityId2));

        stopInZone(async);
      });
    });

    test('preserves and retries the current batch after an Ollama outage', () {
      fakeAsync((async) {
        const entityId2 = 'ffffffff-bbbb-cccc-dddd-eeeeeeeeeeee';
        final entry1 = JournalEntry(
          meta: _meta(),
          entryText: const EntryText(plainText: _longText),
        );
        final entry2 = JournalEntry(
          meta: _meta(id: entityId2),
          entryText: const EntryText(
            plainText: 'Another long enough text for embedding generation.',
          ),
        );
        stubEntity(entry1);
        when(
          () => mockJournalDb.journalEntityById(entityId2),
        ).thenAnswer((_) async => entry2);
        var embedCallCount = 0;
        when(
          () => mockEmbeddingRepo.embed(
            input: any(named: 'input'),
            baseUrl: any(named: 'baseUrl'),
            model: any(named: 'model'),
          ),
        ).thenAnswer((_) async {
          embedCallCount++;
          if (embedCallCount == 1) {
            throw OllamaEmbeddingUnavailableException(
              'Ollama transport retries exhausted',
              retryAt: clock.now().add(
                OllamaEmbeddingRepository.availabilityCooldown,
              ),
            );
          }
          return _fakeEmbedding();
        });

        service.start();
        sendAndProcess(
          async,
          {_entityId, entityId2, textEntryNotification},
        );

        expect(embedCallCount, 1);
        verifyNever(() => mockJournalDb.journalEntityById(entityId2));

        async
          ..elapse(OllamaEmbeddingRepository.availabilityCooldown)
          ..flushMicrotasks();

        expect(embedCallCount, 3);
        verify(() => mockJournalDb.journalEntityById(entityId2)).called(1);
        verify(
          () => mockEmbeddingStore.replaceEntityEmbeddings(
            entityId: any(named: 'entityId'),
            entityType: any(named: 'entityType'),
            modelId: any(named: 'modelId'),
            contentHash: any(named: 'contentHash'),
            embeddings: any(named: 'embeddings'),
            categoryId: any(named: 'categoryId'),
            taskId: any(named: 'taskId'),
            subtype: any(named: 'subtype'),
          ),
        ).called(2);
        verify(
          () => mockEmbeddingRepo.embed(
            input: any(named: 'input'),
            baseUrl: any(named: 'baseUrl'),
            model: any(named: 'model'),
          ),
        ).called(3);

        stopInZone(async);
      });
    });

    test('a new notification retries a deferred batch before cooldown', () {
      fakeAsync((async) {
        const entityId2 = 'ffffffff-bbbb-cccc-dddd-eeeeeeeeeeee';
        final entry1 = JournalEntry(
          meta: _meta(),
          entryText: const EntryText(plainText: _longText),
        );
        final entry2 = JournalEntry(
          meta: _meta(id: entityId2),
          entryText: const EntryText(
            plainText: 'Another long enough text for embedding generation.',
          ),
        );
        stubEntity(entry1);
        when(
          () => mockJournalDb.journalEntityById(entityId2),
        ).thenAnswer((_) async => entry2);
        var embedCallCount = 0;
        when(
          () => mockEmbeddingRepo.embed(
            input: any(named: 'input'),
            baseUrl: any(named: 'baseUrl'),
            model: any(named: 'model'),
          ),
        ).thenAnswer((_) async {
          embedCallCount++;
          if (embedCallCount == 1) {
            throw OllamaEmbeddingUnavailableException(
              'Ollama transport retries exhausted',
              retryAt: clock.now().add(
                OllamaEmbeddingRepository.availabilityCooldown,
              ),
            );
          }
          return _fakeEmbedding();
        });

        service.start();
        sendAndProcess(
          async,
          {_entityId, entityId2, textEntryNotification},
        );
        expect(embedCallCount, 1);

        sendAndProcess(async, {entityId2, textEntryNotification});

        expect(embedCallCount, 3);
        verify(
          () => mockEmbeddingStore.replaceEntityEmbeddings(
            entityId: _entityId,
            entityType: any(named: 'entityType'),
            modelId: any(named: 'modelId'),
            contentHash: any(named: 'contentHash'),
            embeddings: any(named: 'embeddings'),
            categoryId: any(named: 'categoryId'),
            taskId: any(named: 'taskId'),
            subtype: any(named: 'subtype'),
          ),
        ).called(1);
        verify(
          () => mockEmbeddingStore.replaceEntityEmbeddings(
            entityId: entityId2,
            entityType: any(named: 'entityType'),
            modelId: any(named: 'modelId'),
            contentHash: any(named: 'contentHash'),
            embeddings: any(named: 'embeddings'),
            categoryId: any(named: 'categoryId'),
            taskId: any(named: 'taskId'),
            subtype: any(named: 'subtype'),
          ),
        ).called(1);

        stopInZone(async);
      });
    });

    test('generates embedding for a task', () {
      fakeAsync((async) {
        final task = Task(
          meta: _meta(),
          data: TaskData(
            status: TaskStatus.open(
              id: 'status-id',
              createdAt: DateTime(2024, 3, 15),
              utcOffset: 0,
            ),
            title: 'Implement the embedding pipeline feature',
            statusHistory: [],
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
          ),
          entryText: const EntryText(plainText: _longText),
        );
        stubEntity(task);
        stubEmbedding();

        service.start();
        sendAndProcess(async, {_entityId, taskNotification});

        verify(
          () => mockEmbeddingStore.replaceEntityEmbeddings(
            entityId: _entityId,
            entityType: kEntityTypeTask,
            modelId: any(named: 'modelId'),
            contentHash: any(named: 'contentHash'),
            embeddings: any(named: 'embeddings'),
            categoryId: any(named: 'categoryId'),
          ),
        ).called(1);

        stopInZone(async);
      });
    });

    test(
      'start is idempotent — second call does not create duplicate listener',
      () {
        fakeAsync((async) {
          final entry = JournalEntry(
            meta: _meta(),
            entryText: const EntryText(plainText: _longText),
          );
          stubEntity(entry);
          stubEmbedding();

          // Call start twice
          service
            ..start()
            ..start();

          sendAndProcess(async, {_entityId, textEntryNotification});

          // Should be called exactly once, not twice (no duplicate listener).
          verify(
            () => mockEmbeddingRepo.embed(
              input: _longText,
              baseUrl: 'http://localhost:11434',
            ),
          ).called(1);

          stopInZone(async);
        });
      },
    );

    test('stop cancels subscription and clears pending', () {
      fakeAsync((async) {
        final entry = JournalEntry(
          meta: _meta(),
          entryText: const EntryText(plainText: _longText),
        );
        stubEntity(entry);
        stubEmbedding();

        service.start();
        stopInZone(async);

        // Notification after stop should not trigger processing
        updateNotifications.notify({_entityId, textEntryNotification});
        async
          ..elapse(const Duration(milliseconds: 150))
          ..flushMicrotasks();

        verifyNever(
          () => mockEmbeddingRepo.embed(
            input: any(named: 'input'),
            baseUrl: any(named: 'baseUrl'),
            model: any(named: 'model'),
          ),
        );
      });
    });

    glados.Glados(
      glados.any.embeddingServiceScenario,
      glados.ExploreConfig(numRuns: 180),
    ).test(
      'matches generated notification lifecycle and processing semantics',
      (scenario) {
        fakeAsync((async) {
          final generatedEmbeddingStore = MockEmbeddingStore();
          final generatedEmbeddingRepo = MockOllamaEmbeddingRepository();
          final generatedJournalDb = MockJournalDb();
          final generatedAiConfigRepo = MockAiConfigRepository();
          final generatedNotifications = UpdateNotifications();
          final generatedService = EmbeddingService(
            embeddingStore: generatedEmbeddingStore,
            embeddingRepository: generatedEmbeddingRepo,
            journalDb: generatedJournalDb,
            updateNotifications: generatedNotifications,
            aiConfigRepository: generatedAiConfigRepo,
          );
          final actual = _GeneratedEmbeddingExpected();
          final expected = _GeneratedEmbeddingExpected();

          when(
            () => generatedJournalDb.getConfigFlag(enableEmbeddingsFlag),
          ).thenAnswer((_) async {
            actual.flagChecks += 1;
            if (scenario.flagThrows) {
              throw StateError('generated config flag failure');
            }
            return scenario.embeddingsEnabled;
          });
          when(
            generatedAiConfigRepo.resolveOllamaBaseUrl,
          ).thenAnswer((_) async {
            actual.baseUrlResolutions += 1;
            if (scenario.baseUrlThrows) {
              throw StateError('generated base URL failure');
            }
            return scenario.hasBaseUrl ? 'http://localhost:11434' : null;
          });
          when(
            () => generatedAiConfigRepo.watchConfigsByType(
              AiConfigType.inferenceProvider,
            ),
          ).thenAnswer((_) => const Stream.empty());
          when(
            generatedJournalDb.getAllLabelDefinitions,
          ).thenAnswer((_) async {
            actual.labelLookups += 1;
            if (scenario.labelResolverThrows) {
              throw StateError('generated label resolver failure');
            }
            return [];
          });
          when(
            () => generatedJournalDb.journalEntityById(any()),
          ).thenAnswer((invocation) async {
            final entityId = invocation.positionalArguments.single as String;
            actual.entityLookups.add(entityId);
            final slot = _generatedEmbeddingEntityIds.entries
                .singleWhere((entry) => entry.value == entityId)
                .key;
            return scenario.entityPlan.entity(slot);
          });
          when(
            () => generatedEmbeddingStore.getContentHash(any()),
          ).thenAnswer((invocation) {
            final entityId = invocation.positionalArguments.single as String;
            final shape = scenario.entityPlan.shapeForId(entityId);
            if (shape != _GeneratedEmbeddingEntityShape.hashMatches) {
              return null;
            }
            final slot = _generatedEmbeddingEntityIds.entries
                .singleWhere((entry) => entry.value == entityId)
                .key;
            return EmbeddingContentExtractor.contentHash(
              _generatedEmbeddingText(slot),
            );
          });
          when(
            () => generatedEmbeddingStore.getCategoryId(any()),
          ).thenReturn(null);
          when(
            () => generatedEmbeddingStore.replaceEntityEmbeddings(
              entityId: any(named: 'entityId'),
              entityType: any(named: 'entityType'),
              modelId: any(named: 'modelId'),
              contentHash: any(named: 'contentHash'),
              embeddings: any(named: 'embeddings'),
              categoryId: any(named: 'categoryId'),
              taskId: any(named: 'taskId'),
              subtype: any(named: 'subtype'),
            ),
          ).thenAnswer((invocation) {
            actual.storedEntityIds.add(
              invocation.namedArguments[#entityId] as String,
            );
          });
          when(
            () => generatedEmbeddingRepo.embed(
              input: any(named: 'input'),
              baseUrl: any(named: 'baseUrl'),
              model: any(named: 'model'),
            ),
          ).thenAnswer((invocation) async {
            final input = invocation.namedArguments[#input] as String;
            actual.embedInputs.add(input);
            final slot = scenario.entityPlan.slotForText(input);
            if (scenario.entityPlan.shape(slot) ==
                _GeneratedEmbeddingEntityShape.embedThrows) {
              throw StateError('generated embed failure for ${slot.name}');
            }
            return _fakeEmbedding();
          });

          void stopGeneratedService() {
            unawaited(generatedService.stop());
            async.flushMicrotasks();
          }

          void expectProcessedBatch(List<String> entityIds) {
            if (entityIds.isEmpty) return;

            expected.flagChecks += 1;
            if (scenario.flagThrows || !scenario.embeddingsEnabled) {
              return;
            }

            expected.baseUrlResolutions += 1;
            if (scenario.baseUrlThrows || !scenario.hasBaseUrl) {
              return;
            }

            expected.labelLookups += 1;

            for (final entityId in entityIds) {
              expected.entityLookups.add(entityId);
              final shape = scenario.entityPlan.shapeForId(entityId);
              if (shape == _GeneratedEmbeddingEntityShape.missing ||
                  shape == _GeneratedEmbeddingEntityShape.tooShort ||
                  shape == _GeneratedEmbeddingEntityShape.hashMatches) {
                continue;
              }

              final slot = _generatedEmbeddingEntityIds.entries
                  .singleWhere((entry) => entry.value == entityId)
                  .key;
              expected.embedInputs.add(_generatedEmbeddingText(slot));
              if (shape == _GeneratedEmbeddingEntityShape.embeddable) {
                expected.storedEntityIds.add(entityId);
              }
            }
          }

          // Treat the first stop as terminal: any later start in the
          // generated sequence is dropped instead of restarting the service.
          // This is a deliberate choice for the test driver, not a model of
          // the production contract — `EmbeddingService.start()` itself is
          // restart-safe. The constraint exists because `service.stop()`
          // awaits the broadcast subscription's cancel future, and in
          // `fakeAsync` that future does not resolve via `flushMicrotasks`
          // (broadcast cancel only completes once the controller is closed).
          // Without this gate, `unawaited(stop()) + flushMicrotasks` would
          // leave `_subscription` non-null, the next `start()` would early
          // return, and any post-restart notifications would be silently
          // dropped — producing false negatives unrelated to service logic.
          var started = false;
          var stoppedOnce = false;
          try {
            for (final operation in scenario.operations) {
              if (operation.startsService) {
                if (!stoppedOnce) {
                  generatedService.start();
                  started = true;
                }
                continue;
              }
              if (operation.stopsService) {
                stopGeneratedService();
                started = false;
                stoppedOnce = true;
                continue;
              }

              generatedNotifications.notify(operation.notificationTokens());
              if (started && operation.hasRelevantType) {
                expectProcessedBatch(operation.validEntityIds());
              }
              async
                ..elapse(const Duration(milliseconds: 150))
                ..flushMicrotasks();
            }

            expect(actual.flagChecks, expected.flagChecks, reason: '$scenario');
            expect(
              actual.baseUrlResolutions,
              expected.baseUrlResolutions,
              reason: '$scenario',
            );
            expect(
              actual.labelLookups,
              expected.labelLookups,
              reason: '$scenario',
            );
            expect(
              actual.entityLookups,
              expected.entityLookups,
              reason: '$scenario',
            );
            expect(
              actual.embedInputs,
              expected.embedInputs,
              reason: '$scenario',
            );
            expect(
              actual.storedEntityIds,
              expected.storedEntityIds,
              reason: '$scenario',
            );
          } finally {
            stopGeneratedService();
            unawaited(generatedNotifications.dispose());
            async.flushMicrotasks();
          }
        });
      },
      tags: 'glados',
    );
  });

  group('EmbeddingService._isEntityId', () {
    // Testing the static method indirectly via notification handling

    test('filters out UPPER_SNAKE_CASE notification tokens', () {
      fakeAsync((async) {
        // Only type tokens, no entity IDs → nothing to process
        service.start();
        sendAndProcess(
          async,
          {textEntryNotification, taskNotification},
        );

        verifyNever(
          () => mockJournalDb.journalEntityById(any()),
        );

        stopInZone(async);
      });
    });
  });

  group('EmbeddingService label resolver', () {
    final fixedDate = DateTime(2024, 3, 15);

    test('builds label resolver from getAllLabelDefinitions', () {
      fakeAsync((async) {
        // Stub labels
        when(() => mockJournalDb.getAllLabelDefinitions()).thenAnswer(
          (_) async => [
            LabelDefinition(
              id: 'label-1',
              name: 'security',
              color: '#FF0000',
              createdAt: fixedDate,
              updatedAt: fixedDate,
              vectorClock: null,
            ),
            LabelDefinition(
              id: 'label-2',
              name: 'backend',
              color: '#00FF00',
              createdAt: fixedDate,
              updatedAt: fixedDate,
              vectorClock: null,
            ),
          ],
        );

        final task = Task(
          meta: Metadata(
            id: _entityId,
            createdAt: fixedDate,
            updatedAt: fixedDate,
            dateFrom: fixedDate,
            dateTo: fixedDate,
            labelIds: ['label-1', 'label-2'],
          ),
          data: TaskData(
            status: TaskStatus.open(
              id: 'status-id',
              createdAt: fixedDate,
              utcOffset: 0,
            ),
            title: 'Fix auth bug',
            statusHistory: [],
            dateFrom: fixedDate,
            dateTo: fixedDate,
          ),
          entryText: const EntryText(plainText: _longText),
        );
        stubEntity(task);
        stubEmbedding();

        service.start();
        sendAndProcess(async, {_entityId, taskNotification});

        // Verify that the enriched template (with labels) was used
        final captured = verify(
          () => mockEmbeddingRepo.embed(
            input: captureAny(named: 'input'),
            baseUrl: any(named: 'baseUrl'),
          ),
        ).captured;

        final embeddedText = captured.first as String;
        expect(embeddedText, contains('Labels: security, backend'));
        expect(embeddedText, startsWith('Fix auth bug'));

        stopInZone(async);
      });
    });

    test('excludes deleted labels from resolver', () {
      fakeAsync((async) {
        when(() => mockJournalDb.getAllLabelDefinitions()).thenAnswer(
          (_) async => [
            LabelDefinition(
              id: 'label-1',
              name: 'active-label',
              color: '#FF0000',
              createdAt: fixedDate,
              updatedAt: fixedDate,
              vectorClock: null,
            ),
            LabelDefinition(
              id: 'label-deleted',
              name: 'deleted-label',
              color: '#999999',
              createdAt: fixedDate,
              updatedAt: fixedDate,
              vectorClock: null,
              deletedAt: fixedDate,
            ),
          ],
        );

        final task = Task(
          meta: Metadata(
            id: _entityId,
            createdAt: fixedDate,
            updatedAt: fixedDate,
            dateFrom: fixedDate,
            dateTo: fixedDate,
            labelIds: ['label-1', 'label-deleted'],
          ),
          data: TaskData(
            status: TaskStatus.open(
              id: 'status-id',
              createdAt: fixedDate,
              utcOffset: 0,
            ),
            title: 'A task with labels that is long enough',
            statusHistory: [],
            dateFrom: fixedDate,
            dateTo: fixedDate,
          ),
        );
        stubEntity(task);
        stubEmbedding();

        service.start();
        sendAndProcess(async, {_entityId, taskNotification});

        final captured = verify(
          () => mockEmbeddingRepo.embed(
            input: captureAny(named: 'input'),
            baseUrl: any(named: 'baseUrl'),
          ),
        ).captured;

        final embeddedText = captured.first as String;
        expect(embeddedText, contains('Labels: active-label'));
        expect(embeddedText, isNot(contains('deleted-label')));

        stopInZone(async);
      });
    });

    test('non-task entities skip label resolver entirely', () {
      fakeAsync((async) {
        final entry = JournalEntry(
          meta: _meta(),
          entryText: const EntryText(plainText: _longText),
        );
        stubEntity(entry);
        stubEmbedding();

        service.start();
        sendAndProcess(async, {_entityId, textEntryNotification});

        // For non-task entities, the plain text should be used directly
        verify(
          () => mockEmbeddingRepo.embed(
            input: _longText,
            baseUrl: 'http://localhost:11434',
          ),
        ).called(1);

        stopInZone(async);
      });
    });
  });
}
