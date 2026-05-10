import 'dart:async';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/service/embedding_content_extractor.dart';
import 'package:lotti/features/ai/service/embedding_service.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

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

    // Default: Ollama provider configured
    when(
      () => mockAiConfigRepo.resolveOllamaBaseUrl(),
    ).thenAnswer((_) async => 'http://localhost:11434');

    // Default: no existing content hash
    when(() => mockEmbeddingStore.getContentHash(any())).thenReturn(null);

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
