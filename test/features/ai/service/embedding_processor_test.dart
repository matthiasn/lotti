import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/ai_attribution.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/features/ai/database/embedding_register.dart';
import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/on_device_embedding/on_device_embedding_repository.dart';
import 'package:lotti/features/ai/service/embedding_content_extractor.dart';
import 'package:lotti/features/ai/service/embedding_processor.dart';
import 'package:lotti/features/ai/service/text_chunker.dart';
import 'package:lotti/features/ai_consumption/service/ai_attribution_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../helpers/in_memory_embedding_store.dart';
import '../../../mocks/mocks.dart';
import '../../ai_consumption/test_utils.dart';

enum _GeneratedEmbeddingEntityShape {
  missing,
  unsupported,
  tooShort,
  journalEntry,
  task,
}

enum _GeneratedStoredCategoryShape { none, same, different }

class _GeneratedEmbeddingScenario {
  const _GeneratedEmbeddingScenario({
    required this.entityShape,
    required this.storedCategoryShape,
    required this.hashMatches,
    required this.useLabelResolver,
    required this.seed,
  });

  final _GeneratedEmbeddingEntityShape entityShape;
  final _GeneratedStoredCategoryShape storedCategoryShape;
  final bool hashMatches;
  final bool useLabelResolver;
  final int seed;

  String get entityId => 'generated-entity-$seed';

  String? get categoryId => seed.isEven ? 'cat-generated' : null;

  String get storedCategoryId => switch (storedCategoryShape) {
    _GeneratedStoredCategoryShape.same => categoryId ?? '',
    _GeneratedStoredCategoryShape.different =>
      categoryId == null ? 'cat-previous' : 'cat-other',
    _GeneratedStoredCategoryShape.none => '',
  };

  bool get hasStoredCategory =>
      storedCategoryShape != _GeneratedStoredCategoryShape.none;

  bool get categoryChanged =>
      hasStoredCategory && storedCategoryId != (categoryId ?? '');

  bool get isTask => entityShape == _GeneratedEmbeddingEntityShape.task;

  bool get shouldEmbedEntity =>
      entityShape == _GeneratedEmbeddingEntityShape.journalEntry ||
      entityShape == _GeneratedEmbeddingEntityShape.task;

  String get journalText =>
      'Generated journal text $seed with enough detail for embedding.';

  String get taskTitle =>
      'Generated task title $seed with enough semantic detail';

  String get taskBody =>
      'Generated task body $seed with implementation context.';

  String? get expectedText => switch (entityShape) {
    _GeneratedEmbeddingEntityShape.journalEntry => journalText,
    _GeneratedEmbeddingEntityShape.task =>
      useLabelResolver
          ? '$taskTitle\nLabels: backend, security\n$taskBody'
          : '$taskTitle\n$taskBody',
    _ => null,
  };

  JournalEntity? entity() {
    return switch (entityShape) {
      _GeneratedEmbeddingEntityShape.missing => null,
      _GeneratedEmbeddingEntityShape.unsupported => JournalImage(
        meta: _meta(id: entityId, categoryId: categoryId),
        data: ImageData(
          imageId: 'image-$seed',
          imageFile: 'image-$seed.jpg',
          imageDirectory: '/images',
          capturedAt: _fixedDate,
        ),
      ),
      _GeneratedEmbeddingEntityShape.tooShort => JournalEntry(
        meta: _meta(id: entityId, categoryId: categoryId),
        entryText: const EntryText(plainText: 'short'),
      ),
      _GeneratedEmbeddingEntityShape.journalEntry => JournalEntry(
        meta: _meta(id: entityId, categoryId: categoryId),
        entryText: EntryText(plainText: '  $journalText  '),
      ),
      _GeneratedEmbeddingEntityShape.task => Task(
        meta: _meta(
          id: entityId,
          categoryId: categoryId,
          labelIds: const ['label-1', 'label-2'],
        ),
        data: _taskData(taskTitle),
        entryText: EntryText(plainText: taskBody),
      ),
    };
  }

  @override
  String toString() {
    return '_GeneratedEmbeddingScenario('
        'entityShape: $entityShape, '
        'storedCategoryShape: $storedCategoryShape, '
        'hashMatches: $hashMatches, '
        'useLabelResolver: $useLabelResolver, '
        'seed: $seed)';
  }
}

extension _AnyGeneratedEmbeddingScenario on glados.Any {
  glados.Generator<_GeneratedEmbeddingEntityShape> get embeddingEntityShape =>
      glados.AnyUtils(this).choose(_GeneratedEmbeddingEntityShape.values);

  glados.Generator<_GeneratedStoredCategoryShape> get storedCategoryShape =>
      glados.AnyUtils(this).choose(_GeneratedStoredCategoryShape.values);

  glados.Generator<_GeneratedEmbeddingScenario> get embeddingScenario =>
      glados.CombinableAny(this).combine5(
        embeddingEntityShape,
        storedCategoryShape,
        glados.AnyUtils(this).choose([false, true]),
        glados.AnyUtils(this).choose([false, true]),
        glados.IntAnys(this).intInRange(0, 10000),
        (
          _GeneratedEmbeddingEntityShape entityShape,
          _GeneratedStoredCategoryShape storedCategoryShape,
          bool hashMatches,
          bool useLabelResolver,
          int seed,
        ) => _GeneratedEmbeddingScenario(
          entityShape: entityShape,
          storedCategoryShape: storedCategoryShape,
          hashMatches: hashMatches,
          useLabelResolver: useLabelResolver,
          seed: seed,
        ),
      );
}

enum _GeneratedAgentReportContentShape {
  whitespaceOnly,
  tooShort,
  singleChunk,
  multiChunk,
}

enum _GeneratedAgentReportFailureShape {
  none,
  firstChunk,
  secondChunk,
}

enum _GeneratedAgentReportMetadataSlot {
  current,
  previous,
  defaultCategory,
}

class _GeneratedAgentReportScenario {
  const _GeneratedAgentReportScenario({
    required this.contentShape,
    required this.failureShape,
    required this.metadataSlot,
    required this.hashMatches,
    required this.seed,
  });

  final _GeneratedAgentReportContentShape contentShape;
  final _GeneratedAgentReportFailureShape failureShape;
  final _GeneratedAgentReportMetadataSlot metadataSlot;
  final bool hashMatches;
  final int seed;

  String get reportId => 'generated-report-$seed';

  String get taskId => switch (metadataSlot) {
    _GeneratedAgentReportMetadataSlot.current => 'task-current-$seed',
    _GeneratedAgentReportMetadataSlot.previous => 'task-previous-$seed',
    _GeneratedAgentReportMetadataSlot.defaultCategory => 'task-default-$seed',
  };

  String get categoryId => switch (metadataSlot) {
    _GeneratedAgentReportMetadataSlot.current => 'cat-current',
    _GeneratedAgentReportMetadataSlot.previous => 'cat-previous',
    _GeneratedAgentReportMetadataSlot.defaultCategory => '',
  };

  String get subtype => switch (metadataSlot) {
    _GeneratedAgentReportMetadataSlot.current => 'current',
    _GeneratedAgentReportMetadataSlot.previous => 'previous',
    _GeneratedAgentReportMetadataSlot.defaultCategory => 'default',
  };

  String get reportContent => switch (contentShape) {
    _GeneratedAgentReportContentShape.whitespaceOnly => '   \n\t   ',
    _GeneratedAgentReportContentShape.tooShort => '  short $seed  ',
    _GeneratedAgentReportContentShape.singleChunk =>
      '  Generated report $seed has enough content for embedding.  ',
    _GeneratedAgentReportContentShape.multiChunk => _longReport(seed),
  };

  String get trimmedContent => reportContent.trim();

  bool get hasEnoughContent => trimmedContent.length >= kMinEmbeddingTextLength;

  List<String> get chunks {
    if (!hasEnoughContent || hashMatches) return const [];
    return TextChunker.chunk(trimmedContent);
  }

  int? get failureIndex {
    if (chunks.isEmpty) return null;
    return switch (failureShape) {
      _GeneratedAgentReportFailureShape.none => null,
      _GeneratedAgentReportFailureShape.firstChunk => 0,
      _GeneratedAgentReportFailureShape.secondChunk =>
        chunks.length > 1 ? 1 : null,
    };
  }

  bool get shouldThrow => failureIndex != null;

  bool get shouldStore =>
      hasEnoughContent && !hashMatches && failureIndex == null;

  static String _longReport(int seed) {
    final words = List.generate(
      260,
      (index) => 'report_${seed}_word_$index',
    ).join(' ');
    return '\n  $words  \n';
  }

  @override
  String toString() {
    return '_GeneratedAgentReportScenario('
        'contentShape: $contentShape, '
        'failureShape: $failureShape, '
        'metadataSlot: $metadataSlot, '
        'hashMatches: $hashMatches, '
        'seed: $seed)';
  }
}

class _CapturedAgentReportWrite {
  const _CapturedAgentReportWrite({
    required this.entityId,
    required this.entityType,
    required this.modelId,
    required this.contentHash,
    required this.embeddingCount,
    required this.categoryId,
    required this.taskId,
    required this.subtype,
  });

  final String entityId;
  final String entityType;
  final String modelId;
  final String contentHash;
  final int embeddingCount;
  final String categoryId;
  final String taskId;
  final String subtype;
}

extension _AnyGeneratedAgentReportScenario on glados.Any {
  glados.Generator<_GeneratedAgentReportContentShape>
  get agentReportContentShape =>
      glados.AnyUtils(this).choose(_GeneratedAgentReportContentShape.values);

  glados.Generator<_GeneratedAgentReportFailureShape>
  get agentReportFailureShape =>
      glados.AnyUtils(this).choose(_GeneratedAgentReportFailureShape.values);

  glados.Generator<_GeneratedAgentReportMetadataSlot>
  get agentReportMetadataSlot =>
      glados.AnyUtils(this).choose(_GeneratedAgentReportMetadataSlot.values);

  glados.Generator<_GeneratedAgentReportScenario> get agentReportScenario =>
      glados.CombinableAny(this).combine5(
        agentReportContentShape,
        agentReportFailureShape,
        agentReportMetadataSlot,
        glados.AnyUtils(this).choose([false, true]),
        glados.IntAnys(this).intInRange(0, 10000),
        (
          _GeneratedAgentReportContentShape contentShape,
          _GeneratedAgentReportFailureShape failureShape,
          _GeneratedAgentReportMetadataSlot metadataSlot,
          bool hashMatches,
          int seed,
        ) => _GeneratedAgentReportScenario(
          contentShape: contentShape,
          failureShape: failureShape,
          metadataSlot: metadataSlot,
          hashMatches: hashMatches,
          seed: seed,
        ),
      );
}

// ---------------------------------------------------------------------------
// Test data helpers
// ---------------------------------------------------------------------------

final _fixedDate = DateTime(2024, 3, 15);
const _modelId = 'test-embedding-model';
const _longText = 'This is a sufficiently long text for embedding generation.';

Metadata _meta({
  String id = 'entity-1',
  List<String>? labelIds,
  String? categoryId,
}) => Metadata(
  id: id,
  createdAt: _fixedDate,
  updatedAt: _fixedDate,
  dateFrom: _fixedDate,
  dateTo: _fixedDate,
  labelIds: labelIds,
  categoryId: categoryId,
);

TaskData _taskData(String title) => TaskData(
  status: TaskStatus.open(
    id: 'status-id',
    createdAt: _fixedDate,
    utcOffset: 0,
  ),
  title: title,
  statusHistory: [],
  dateFrom: _fixedDate,
  dateTo: _fixedDate,
);

Float32List _fakeEmbedding() => Float32List(kEmbeddingDimensions);

String _hashOf(String text) => sha256.convert(utf8.encode(text)).toString();

// ---------------------------------------------------------------------------
// Stub helpers
// ---------------------------------------------------------------------------

void _stubNoExistingHash(MockEmbeddingStore db) {
  when(() => db.getContentHash(any())).thenReturn(null);
}

void _stubNoCategoryId(MockEmbeddingStore db) {
  when(() => db.getCategoryId(any())).thenReturn(null);
}

void _stubNoTaskReports(MockEmbeddingStore db) {
  when(() => db.agentReportIdsForTask(any())).thenAnswer((_) async => {});
}

void _stubReplaceEntityEmbeddings(MockEmbeddingStore db) {
  when(
    () => db.replaceEntityEmbeddings(
      entityId: any(named: 'entityId'),
      entityType: any(named: 'entityType'),
      modelId: any(named: 'modelId'),
      contentHash: any(named: 'contentHash'),
      embeddings: any(named: 'embeddings'),
      categoryId: any(named: 'categoryId'),
      taskId: any(named: 'taskId'),
      subtype: any(named: 'subtype'),
      register: any(named: 'register'),
    ),
  ).thenReturn(null);
}

void _stubEmbed(MockOnDeviceEmbeddingRepository repo) {
  when(() => repo.modelId).thenReturn(_modelId);
  when(
    () => repo.embedDocument(any()),
  ).thenAnswer((_) async => _fakeEmbedding());
}

void _stubEntity(MockJournalDb db, JournalEntity entity) {
  when(() => db.journalEntityById(entity.id)).thenAnswer((_) async => entity);
}

/// What the store holds for one id.
class _StoredRow {
  _StoredRow({
    required this.hash,
    required this.categoryId,
    required this.taskId,
  });

  final String hash;
  String categoryId;
  final String taskId;
}

/// Backs [store] with [rows], for tests about what the store ends up holding:
/// writes land in the map, reads come from it, and a task's reports move with
/// it as they do in `ShardedEmbeddingStore`.
void _backWithRows(MockEmbeddingStore store, Map<String, _StoredRow> rows) {
  String idOf(Invocation i) => i.positionalArguments.first as String;
  when(
    () => store.getContentHash(any()),
  ).thenAnswer((i) => rows[idOf(i)]?.hash);
  when(
    () => store.hasEmbedding(any()),
  ).thenAnswer((i) => rows.containsKey(idOf(i)));
  when(
    () => store.getCategoryId(any()),
  ).thenAnswer((i) => rows[idOf(i)]?.categoryId);
  when(() => store.deleteEntityEmbeddings(any())).thenAnswer((i) {
    rows.remove(idOf(i));
  });
  when(() => store.agentReportIdsForTask(any())).thenAnswer(
    (i) async => {
      for (final MapEntry(:key, :value) in rows.entries)
        if (value.taskId == idOf(i)) key,
    },
  );
  when(() => store.moveEntityToShard(any(), any())).thenAnswer((i) {
    rows[idOf(i)]?.categoryId = i.positionalArguments[1] as String;
  });
  when(() => store.moveRelatedReportEmbeddings(any(), any())).thenAnswer((i) {
    for (final row in rows.values.where((r) => r.taskId == idOf(i))) {
      row.categoryId = i.positionalArguments[1] as String;
    }
  });
  when(
    () => store.replaceEntityEmbeddings(
      entityId: any(named: 'entityId'),
      entityType: any(named: 'entityType'),
      modelId: any(named: 'modelId'),
      contentHash: any(named: 'contentHash'),
      embeddings: any(named: 'embeddings'),
      categoryId: any(named: 'categoryId'),
      taskId: any(named: 'taskId'),
      subtype: any(named: 'subtype'),
      register: any(named: 'register'),
    ),
  ).thenAnswer((i) {
    rows[i.namedArguments[#entityId] as String] = _StoredRow(
      hash: i.namedArguments[#contentHash] as String,
      categoryId: i.namedArguments[#categoryId] as String,
      taskId: i.namedArguments[#taskId] as String,
    );
  });
}

/// Holds the first `embed` call open on the returned completer; every later
/// call answers at once.
Completer<Float32List> _pauseFirstEmbed(MockOnDeviceEmbeddingRepository repo) {
  final first = Completer<Float32List>();
  var calls = 0;
  when(
    () => repo.embedDocument(any()),
  ).thenAnswer(
    (_) => calls++ == 0 ? first.future : Future.value(_fakeEmbedding()),
  );
  return first;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockJournalDb mockJournalDb;
  late MockEmbeddingStore mockEmbeddingStore;
  late MockOnDeviceEmbeddingRepository mockEmbeddingRepo;

  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(Float32List(0));
  });

  setUp(() {
    mockJournalDb = MockJournalDb();
    stubNoDeletedEntries(mockJournalDb);
    mockEmbeddingStore = MockEmbeddingStore();
    stubEmbeddingRegisters(mockEmbeddingStore);
    mockEmbeddingRepo = MockOnDeviceEmbeddingRepository();

    _stubNoExistingHash(mockEmbeddingStore);
    _stubNoCategoryId(mockEmbeddingStore);
    _stubNoTaskReports(mockEmbeddingStore);
    _stubReplaceEntityEmbeddings(mockEmbeddingStore);
    _stubEmbed(mockEmbeddingRepo);
  });

  /// Runs [EmbeddingProcessor.processEntity] against the shared mocks,
  /// removing the repeated `journalDb:/embeddingStore:/embeddingRepository:`
  /// boilerplate from every test. When [entity] is supplied it is
  /// also stubbed on [mockJournalDb] and used as the entity ID, so most tests
  /// collapse to a single call.
  Future<bool> processEntity({
    JournalEntity? entity,
    String? entityId,
    LabelNameResolver? labelNameResolver,
  }) {
    if (entity != null) {
      _stubEntity(mockJournalDb, entity);
    }
    return EmbeddingProcessor.processEntity(
      entityId: entityId ?? entity!.id,
      journalDb: mockJournalDb,
      embeddingStore: mockEmbeddingStore,
      embeddingRepository: mockEmbeddingRepo,
      labelNameResolver: labelNameResolver,
    );
  }

  /// Runs [EmbeddingProcessor.processAgentReport] with the report's task
  /// stored in [categoryId] on the shared journal mock.
  Future<bool> processAgentReport({
    required String reportId,
    required String reportContent,
    required String taskId,
    required String categoryId,
    required String subtype,
    required EmbeddingStore embeddingStore,
    required OnDeviceEmbeddingRepository embeddingRepository,
  }) {
    _stubEntity(
      mockJournalDb,
      Task(
        meta: _meta(id: taskId, categoryId: categoryId),
        data: _taskData('Task $taskId'),
      ),
    );
    return EmbeddingProcessor.processAgentReport(
      reportId: reportId,
      reportContent: reportContent,
      taskId: taskId,
      subtype: subtype,
      journalDb: mockJournalDb,
      embeddingStore: embeddingStore,
      embeddingRepository: embeddingRepository,
    );
  }

  group('EmbeddingProcessor.processEntity', () {
    test('embeds a journal entry and returns true', () async {
      final entry = JournalEntry(
        meta: _meta(categoryId: 'cat-1'),
        entryText: const EntryText(plainText: _longText),
      );

      final result = await processEntity(entity: entry);

      expect(result, isTrue);
      verify(
        () => mockEmbeddingStore.replaceEntityEmbeddings(
          entityId: entry.id,
          entityType: kEntityTypeJournalText,
          modelId: _modelId,
          contentHash: _hashOf(_longText),
          embeddings: any(named: 'embeddings'),
          categoryId: 'cat-1',
          taskId: any(named: 'taskId'),
          subtype: any(named: 'subtype'),
          register: any(named: 'register'),
        ),
      ).called(1);
    });

    test(
      'deletes the vectors of an entry that is gone and returns false',
      () async {
        // The read hides soft-deleted rows: a deleted entry reads as null.
        final rows = {
          'deleted': _StoredRow(hash: 'old', categoryId: 'cat-1', taskId: ''),
        };
        _backWithRows(mockEmbeddingStore, rows);
        when(
          () => mockJournalDb.journalEntityById('deleted'),
        ).thenAnswer((_) async => null);

        final result = await processEntity(entityId: 'deleted');

        expect(result, isFalse);
        expect(rows, isEmpty);
      },
    );

    test('returns false for unsupported entity type (JournalImage)', () async {
      final image = JournalImage(
        meta: _meta(id: 'image-1'),
        data: ImageData(
          imageId: 'img',
          imageFile: 'photo.jpg',
          imageDirectory: '/images',
          capturedAt: _fixedDate,
        ),
      );

      final result = await processEntity(entity: image);

      expect(result, isFalse);
    });

    test(
      'deletes the vectors of an entry shortened below the minimum',
      () async {
        final rows = {
          'entity-1': _StoredRow(
            hash: _hashOf(_longText),
            categoryId: '',
            taskId: '',
          ),
        };
        _backWithRows(mockEmbeddingStore, rows);
        final entry = JournalEntry(
          meta: _meta(),
          entryText: const EntryText(plainText: 'Too short'),
        );

        final result = await processEntity(entity: entry);

        expect(result, isFalse);
        expect(rows, isEmpty);
      },
    );

    test('returns false when content hash unchanged', () async {
      final entry = JournalEntry(
        meta: _meta(),
        entryText: const EntryText(plainText: _longText),
      );
      _stubEntity(mockJournalDb, entry);
      when(
        () => mockEmbeddingStore.getContentHash(entry.id),
      ).thenReturn(_hashOf(_longText));
      when(
        () => mockEmbeddingStore.getCategoryId(entry.id),
      ).thenReturn('');

      final result = await processEntity(entityId: entry.id);

      expect(result, isFalse);
      verifyNever(
        () => mockEmbeddingRepo.embedDocument(any()),
      );
    });

    test(
      'uses extractText (not enriched template) when no label resolver',
      () async {
        final task = Task(
          meta: _meta(),
          data: _taskData('My task title that is long enough'),
          entryText: const EntryText(plainText: _longText),
        );

        await processEntity(entity: task);

        // Without label resolver, uses the default extractText format
        const expectedText = 'My task title that is long enough\n$_longText';
        verify(
          () => mockEmbeddingRepo.embedDocument(expectedText),
        ).called(1);
      },
    );

    test(
      'uses enriched template with labels when resolver is provided',
      () async {
        final task = Task(
          meta: _meta(labelIds: ['label-1', 'label-2']),
          data: _taskData('Fix auth bug'),
          entryText: const EntryText(plainText: _longText),
        );

        Future<List<String>> labelResolver(List<String> ids) async => [
          'security',
          'backend',
        ];

        await processEntity(entity: task, labelNameResolver: labelResolver);

        const expectedText =
            'Fix auth bug\nLabels: security, backend\n$_longText';
        verify(
          () => mockEmbeddingRepo.embedDocument(expectedText),
        ).called(1);
      },
    );

    test('resolver with empty label IDs omits labels line', () async {
      final task = Task(
        meta: _meta(), // no labelIds
        data: _taskData('A task title that is long enough for embedding'),
      );

      Future<List<String>> labelResolver(List<String> ids) async => [];

      await processEntity(entity: task, labelNameResolver: labelResolver);

      verify(
        () => mockEmbeddingRepo.embedDocument(
          'A task title that is long enough for embedding',
        ),
      ).called(1);
    });

    test('non-task entity ignores label resolver', () async {
      final entry = JournalEntry(
        meta: _meta(),
        entryText: const EntryText(plainText: _longText),
      );

      var resolverCalled = false;
      Future<List<String>> labelResolver(List<String> ids) async {
        resolverCalled = true;
        return [];
      }

      await processEntity(entity: entry, labelNameResolver: labelResolver);

      expect(resolverCalled, isFalse);
      verify(
        () => mockEmbeddingRepo.embedDocument(_longText),
      ).called(1);
    });

    glados.Glados(
      glados.any.embeddingScenario,
      glados.ExploreConfig(numRuns: 140),
    ).test(
      'matches generated entity embedding pipeline semantics',
      (scenario) async {
        final localJournalDb = MockJournalDb();
        stubNoDeletedEntries(localJournalDb);
        final localEmbeddingStore = MockEmbeddingStore();
        stubEmbeddingRegisters(localEmbeddingStore);
        final localEmbeddingRepo = MockOnDeviceEmbeddingRepository();
        when(() => localEmbeddingRepo.modelId).thenReturn(_modelId);
        final entity = scenario.entity();
        final expectedText = scenario.expectedText;

        when(
          () => localJournalDb.journalEntityById(scenario.entityId),
        ).thenAnswer((_) async => entity);
        when(
          () => localEmbeddingStore.getContentHash(scenario.entityId),
        ).thenReturn(
          expectedText != null && scenario.hashMatches
              ? _hashOf(expectedText)
              : 'old-hash',
        );
        when(
          () => localEmbeddingStore.getCategoryId(scenario.entityId),
        ).thenReturn(
          scenario.hasStoredCategory ? scenario.storedCategoryId : null,
        );
        when(
          () => localEmbeddingStore.moveEntityToShard(any(), any()),
        ).thenReturn(null);
        when(
          () => localEmbeddingStore.moveRelatedReportEmbeddings(any(), any()),
        ).thenReturn(null);
        when(
          () => localEmbeddingStore.deleteEntityEmbeddings(any()),
        ).thenReturn(null);
        _stubReplaceEntityEmbeddings(localEmbeddingStore);
        _stubEmbed(localEmbeddingRepo);

        Future<List<String>> labelResolver(List<String> ids) async => [
          'backend',
          'security',
        ];

        final result = await EmbeddingProcessor.processEntity(
          entityId: scenario.entityId,
          journalDb: localJournalDb,
          embeddingStore: localEmbeddingStore,
          embeddingRepository: localEmbeddingRepo,
          labelNameResolver: scenario.useLabelResolver ? labelResolver : null,
        );

        if (!scenario.shouldEmbedEntity) {
          expect(result, isFalse, reason: '$scenario');
          verifyNever(
            () => localEmbeddingRepo.embedDocument(any()),
          );
          verifyNever(
            () => localEmbeddingStore.replaceEntityEmbeddings(
              entityId: any(named: 'entityId'),
              entityType: any(named: 'entityType'),
              modelId: any(named: 'modelId'),
              contentHash: any(named: 'contentHash'),
              embeddings: any(named: 'embeddings'),
              categoryId: any(named: 'categoryId'),
              taskId: any(named: 'taskId'),
              subtype: any(named: 'subtype'),
              register: any(named: 'register'),
            ),
          );
          // A deleted or too-short entry loses its vectors; an entity type
          // that is never embedded has none to lose.
          final gone =
              scenario.entityShape == _GeneratedEmbeddingEntityShape.missing ||
              scenario.entityShape == _GeneratedEmbeddingEntityShape.tooShort;
          if (gone) {
            verify(
              () =>
                  localEmbeddingStore.deleteEntityEmbeddings(scenario.entityId),
            ).called(1);
          } else {
            verifyNever(
              () => localEmbeddingStore.deleteEntityEmbeddings(any()),
            );
          }
          return;
        }

        final expectedCategoryId = scenario.categoryId ?? '';
        // A task's reports follow it into its category on every run.
        void verifyReportsFollow() {
          if (scenario.isTask) {
            verify(
              () => localEmbeddingStore.moveRelatedReportEmbeddings(
                scenario.entityId,
                expectedCategoryId,
              ),
            ).called(1);
          } else {
            verifyNever(
              () =>
                  localEmbeddingStore.moveRelatedReportEmbeddings(any(), any()),
            );
          }
        }

        verifyNever(() => localEmbeddingStore.deleteEntityEmbeddings(any()));
        if (scenario.hashMatches) {
          expect(result, scenario.categoryChanged, reason: '$scenario');
          verifyNever(
            () => localEmbeddingRepo.embedDocument(any()),
          );
          if (scenario.categoryChanged) {
            verify(
              () => localEmbeddingStore.moveEntityToShard(
                scenario.entityId,
                expectedCategoryId,
              ),
            ).called(1);
          } else {
            verifyNever(
              () => localEmbeddingStore.moveEntityToShard(any(), any()),
            );
          }
          verifyReportsFollow();
          return;
        }

        expect(result, isTrue, reason: '$scenario');
        verify(
          () => localEmbeddingRepo.embedDocument(expectedText!),
        ).called(1);
        verify(
          () => localEmbeddingStore.replaceEntityEmbeddings(
            entityId: scenario.entityId,
            entityType: scenario.isTask
                ? kEntityTypeTask
                : kEntityTypeJournalText,
            modelId: _modelId,
            contentHash: _hashOf(expectedText!),
            embeddings: any(named: 'embeddings'),
            categoryId: expectedCategoryId,
            register: any(named: 'register'),
          ),
        ).called(1);
        verifyReportsFollow();
        verifyNever(
          () => localEmbeddingStore.moveEntityToShard(any(), any()),
        );
      },
      tags: 'glados',
    );

    group('category-change detection', () {
      test('moves entity to new shard when category changed', () async {
        final entry = JournalEntry(
          meta: _meta(categoryId: 'cat-new'),
          entryText: const EntryText(plainText: _longText),
        );
        // Content hash matches — no re-embedding needed.
        when(
          () => mockEmbeddingStore.getContentHash(entry.id),
        ).thenReturn(_hashOf(_longText));
        // But stored category differs.
        when(
          () => mockEmbeddingStore.getCategoryId(entry.id),
        ).thenReturn('cat-old');
        when(
          () => mockEmbeddingStore.moveEntityToShard(any(), any()),
        ).thenReturn(null);

        final result = await processEntity(entity: entry);

        expect(result, isTrue);
        verify(
          () => mockEmbeddingStore.moveEntityToShard(entry.id, 'cat-new'),
        ).called(1);
        // Not a task, so no report cascade.
        verifyNever(
          () => mockEmbeddingStore.moveRelatedReportEmbeddings(
            any(),
            any(),
          ),
        );
      });

      test('cascades to reports when task category changes', () async {
        final task = Task(
          meta: _meta(categoryId: 'cat-new'),
          data: _taskData('A task title that is long enough for embedding'),
          entryText: const EntryText(plainText: _longText),
        );
        const taskText =
            'A task title that is long enough for embedding'
            '\n$_longText';
        when(
          () => mockEmbeddingStore.getContentHash(task.id),
        ).thenReturn(_hashOf(taskText));
        when(
          () => mockEmbeddingStore.getCategoryId(task.id),
        ).thenReturn('cat-old');
        when(
          () => mockEmbeddingStore.moveEntityToShard(any(), any()),
        ).thenReturn(null);
        when(
          () => mockEmbeddingStore.moveRelatedReportEmbeddings(any(), any()),
        ).thenReturn(null);

        final result = await processEntity(entity: task);

        expect(result, isTrue);
        verify(
          () => mockEmbeddingStore.moveEntityToShard(task.id, 'cat-new'),
        ).called(1);
        verify(
          () => mockEmbeddingStore.moveRelatedReportEmbeddings(
            task.id,
            'cat-new',
          ),
        ).called(1);
      });

      test(
        'cascades report moves when task content AND category both change',
        () async {
          final task = Task(
            meta: _meta(categoryId: 'cat-new'),
            data: _taskData('Updated task title that is long enough'),
            entryText: const EntryText(plainText: _longText),
          );
          // Content hash differs — task will be re-embedded.
          when(
            () => mockEmbeddingStore.getContentHash(task.id),
          ).thenReturn('old-hash-that-no-longer-matches');
          // Category also changed.
          when(
            () => mockEmbeddingStore.getCategoryId(task.id),
          ).thenReturn('cat-old');
          when(
            () => mockEmbeddingStore.moveRelatedReportEmbeddings(any(), any()),
          ).thenReturn(null);

          final result = await processEntity(entity: task);

          expect(result, isTrue);
          // Task itself is re-embedded to the correct shard via _embedChunks.
          verify(
            () => mockEmbeddingStore.replaceEntityEmbeddings(
              entityId: task.id,
              entityType: any(named: 'entityType'),
              modelId: any(named: 'modelId'),
              contentHash: any(named: 'contentHash'),
              embeddings: any(named: 'embeddings'),
              categoryId: 'cat-new',
              taskId: any(named: 'taskId'),
              subtype: any(named: 'subtype'),
              register: any(named: 'register'),
            ),
          ).called(1);
          // Reports must also be moved to the new category.
          verify(
            () => mockEmbeddingStore.moveRelatedReportEmbeddings(
              task.id,
              'cat-new',
            ),
          ).called(1);
        },
      );

      test('returns false when hash and category both unchanged', () async {
        final entry = JournalEntry(
          meta: _meta(categoryId: 'cat-same'),
          entryText: const EntryText(plainText: _longText),
        );
        when(
          () => mockEmbeddingStore.getContentHash(entry.id),
        ).thenReturn(_hashOf(_longText));
        when(
          () => mockEmbeddingStore.getCategoryId(entry.id),
        ).thenReturn('cat-same');

        final result = await processEntity(entity: entry);

        expect(result, isFalse);
        verifyNever(
          () => mockEmbeddingStore.moveEntityToShard(any(), any()),
        );
      });

      test(
        'returns false when stored categoryId is null (not yet stored)',
        () async {
          final entry = JournalEntry(
            meta: _meta(categoryId: 'cat-1'),
            entryText: const EntryText(plainText: _longText),
          );
          when(
            () => mockEmbeddingStore.getContentHash(entry.id),
          ).thenReturn(_hashOf(_longText));
          when(
            () => mockEmbeddingStore.getCategoryId(entry.id),
          ).thenReturn(null);

          final result = await processEntity(entity: entry);

          expect(result, isFalse);
        },
      );

      test('moves from named category to default (empty) category', () async {
        // Entity has no categoryId (null → '') but stored as 'cat-old'.
        final entry = JournalEntry(
          meta: _meta(),
          entryText: const EntryText(plainText: _longText),
        );
        when(
          () => mockEmbeddingStore.getContentHash(entry.id),
        ).thenReturn(_hashOf(_longText));
        when(
          () => mockEmbeddingStore.getCategoryId(entry.id),
        ).thenReturn('cat-old');
        when(
          () => mockEmbeddingStore.moveEntityToShard(any(), any()),
        ).thenReturn(null);

        final result = await processEntity(entity: entry);

        expect(result, isTrue);
        // Should move to empty string categoryId (default).
        verify(
          () => mockEmbeddingStore.moveEntityToShard(entry.id, ''),
        ).called(1);
      });

      test('moves from default (empty) category to named category', () async {
        final entry = JournalEntry(
          meta: _meta(categoryId: 'cat-new'),
          entryText: const EntryText(plainText: _longText),
        );
        when(
          () => mockEmbeddingStore.getContentHash(entry.id),
        ).thenReturn(_hashOf(_longText));
        // Stored as empty string (default category).
        when(
          () => mockEmbeddingStore.getCategoryId(entry.id),
        ).thenReturn('');
        when(
          () => mockEmbeddingStore.moveEntityToShard(any(), any()),
        ).thenReturn(null);

        final result = await processEntity(entity: entry);

        expect(result, isTrue);
        verify(
          () => mockEmbeddingStore.moveEntityToShard(entry.id, 'cat-new'),
        ).called(1);
      });
    });

    test('propagates embedding repository exceptions to caller', () async {
      final entry = JournalEntry(
        meta: _meta(),
        entryText: const EntryText(plainText: _longText),
      );
      _stubEntity(mockJournalDb, entry);
      when(
        () => mockEmbeddingRepo.embedDocument(any()),
      ).thenThrow(Exception('model failed'));

      expect(
        () => processEntity(entityId: entry.id),
        throwsException,
      );
    });
  });

  group('EmbeddingProcessor.processAgentReport', () {
    test(
      'attributes the work and its vector, with no interaction per chunk',
      () async {
        final bench = AiInteractionCaptureTestBench.create()..register();
        addTearDown(bench.unregister);
        const reportContent =
            'This attributed report has enough content for embedding.';

        final result = await processAgentReport(
          reportId: 'report-attributed',
          reportContent: reportContent,
          taskId: 'task-attributed',
          categoryId: 'cat-attributed',
          subtype: 'current',
          embeddingStore: mockEmbeddingStore,
          embeddingRepository: mockEmbeddingRepo,
        );

        expect(result, isTrue);
        final start =
            verify(() => bench.service.begin(captureAny())).captured.single
                as AiAttributionStart;
        expect(start.workType, AiWorkType.embeddingIndexing);
        expect(start.taskId, 'task-attributed');
        expect(start.categoryId, 'cat-attributed');
        expect(start.intendedOutputs.single.id, 'report-attributed');
        // On-device: no provider is called, so nothing is recorded as used.
        verifyNever(
          () => bench.service.recordInteraction(
            attributionId: any(named: 'attributionId'),
            event: any(named: 'event'),
          ),
        );
        verify(() => bench.service.finalize(any())).called(1);
      },
    );

    test('terminalizes attribution when embedding generation fails', () async {
      final bench = AiInteractionCaptureTestBench.create()..register();
      addTearDown(bench.unregister);
      when(
        () => mockEmbeddingRepo.embedDocument(any()),
      ).thenThrow(StateError('offline'));

      await expectLater(
        processAgentReport(
          reportId: 'report-failed',
          reportContent:
              'This attributed report is long enough but embedding fails.',
          taskId: 'task-failed',
          categoryId: 'cat-failed',
          subtype: 'current',
          embeddingStore: mockEmbeddingStore,
          embeddingRepository: mockEmbeddingRepo,
        ),
        throwsStateError,
      );

      verify(
        () => bench.service.prepareCompletion(
          attributionId: any(named: 'attributionId'),
          outputs: const [],
          status: AiWorkStatus.failed,
          errorCode: 'StateError',
        ),
      ).called(1);
      verify(() => bench.service.finalize(any())).called(1);
    });

    test('embeds report content and returns true', () async {
      const reportContent =
          'This agent report has enough content for embedding.';

      final result = await processAgentReport(
        reportId: 'report-1',
        reportContent: reportContent,
        taskId: 'task-1',
        categoryId: 'cat-1',
        subtype: 'current',
        embeddingStore: mockEmbeddingStore,
        embeddingRepository: mockEmbeddingRepo,
      );

      expect(result, isTrue);
      verify(
        () => mockEmbeddingStore.replaceEntityEmbeddings(
          entityId: 'report-1',
          entityType: kEntityTypeAgentReport,
          modelId: _modelId,
          contentHash: _hashOf(reportContent),
          embeddings: any(named: 'embeddings'),
          categoryId: 'cat-1',
          taskId: 'task-1',
          subtype: 'current',
          register: any(named: 'register'),
        ),
      ).called(1);
    });

    test('returns false when content is too short', () async {
      final result = await processAgentReport(
        reportId: 'report-1',
        reportContent: 'Too short',
        taskId: 'task-1',
        categoryId: 'cat-1',
        subtype: 'current',
        embeddingStore: mockEmbeddingStore,
        embeddingRepository: mockEmbeddingRepo,
      );

      expect(result, isFalse);
      verifyNever(
        () => mockEmbeddingRepo.embedDocument(any()),
      );
    });

    test('trims whitespace before checking length', () async {
      // Content is short when trimmed
      final result = await processAgentReport(
        reportId: 'report-1',
        reportContent: '   short   ',
        taskId: 'task-1',
        categoryId: 'cat-1',
        subtype: 'current',
        embeddingStore: mockEmbeddingStore,
        embeddingRepository: mockEmbeddingRepo,
      );

      expect(result, isFalse);
    });

    test('returns false when content hash unchanged', () async {
      const reportContent = 'This report content is long enough for embedding.';
      when(
        () => mockEmbeddingStore.getContentHash('report-1'),
      ).thenReturn(_hashOf(reportContent));

      final result = await processAgentReport(
        reportId: 'report-1',
        reportContent: reportContent,
        taskId: 'task-1',
        categoryId: 'cat-1',
        subtype: 'current',
        embeddingStore: mockEmbeddingStore,
        embeddingRepository: mockEmbeddingRepo,
      );

      expect(result, isFalse);
    });

    test('embeds when content hash differs (content changed)', () async {
      const reportContent = 'Updated report content that is long enough.';
      when(
        () => mockEmbeddingStore.getContentHash('report-1'),
      ).thenReturn('old-hash-that-no-longer-matches');

      final result = await processAgentReport(
        reportId: 'report-1',
        reportContent: reportContent,
        taskId: 'task-1',
        categoryId: 'cat-1',
        subtype: 'current',
        embeddingStore: mockEmbeddingStore,
        embeddingRepository: mockEmbeddingRepo,
      );

      expect(result, isTrue);
    });

    test('passes correct entity type for agent reports', () async {
      const reportContent =
          'A report with enough content for embedding generation.';

      await processAgentReport(
        reportId: 'report-1',
        reportContent: reportContent,
        taskId: 'task-1',
        categoryId: 'cat-1',
        subtype: 'current',
        embeddingStore: mockEmbeddingStore,
        embeddingRepository: mockEmbeddingRepo,
      );

      verify(
        () => mockEmbeddingStore.replaceEntityEmbeddings(
          entityId: any(named: 'entityId'),
          entityType: kEntityTypeAgentReport,
          modelId: any(named: 'modelId'),
          contentHash: any(named: 'contentHash'),
          embeddings: any(named: 'embeddings'),
          categoryId: any(named: 'categoryId'),
          taskId: any(named: 'taskId'),
          subtype: any(named: 'subtype'),
          register: any(named: 'register'),
        ),
      ).called(1);
    });

    glados.Glados(
      glados.any.agentReportScenario,
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'matches generated agent report embedding semantics',
      (scenario) async {
        final localEmbeddingStore = MockEmbeddingStore();
        stubEmbeddingRegisters(localEmbeddingStore);
        final localEmbeddingRepo = MockOnDeviceEmbeddingRepository();
        when(() => localEmbeddingRepo.modelId).thenReturn(_modelId);
        _stubNoTaskReports(localEmbeddingStore);
        final actualEmbedInputs = <String>[];
        final writes = <_CapturedAgentReportWrite>[];
        var embedCallIndex = 0;

        when(
          () => localEmbeddingStore.getContentHash(scenario.reportId),
        ).thenReturn(
          scenario.hashMatches
              ? _hashOf(scenario.trimmedContent)
              : 'old-generated-hash',
        );
        when(
          () => localEmbeddingStore.replaceEntityEmbeddings(
            entityId: any(named: 'entityId'),
            entityType: any(named: 'entityType'),
            modelId: any(named: 'modelId'),
            contentHash: any(named: 'contentHash'),
            embeddings: any(named: 'embeddings'),
            categoryId: any(named: 'categoryId'),
            taskId: any(named: 'taskId'),
            subtype: any(named: 'subtype'),
            register: any(named: 'register'),
          ),
        ).thenAnswer((invocation) {
          writes.add(
            _CapturedAgentReportWrite(
              entityId: invocation.namedArguments[#entityId] as String,
              entityType: invocation.namedArguments[#entityType] as String,
              modelId: invocation.namedArguments[#modelId] as String,
              contentHash: invocation.namedArguments[#contentHash] as String,
              embeddingCount:
                  (invocation.namedArguments[#embeddings] as List<Float32List>)
                      .length,
              categoryId: invocation.namedArguments[#categoryId] as String,
              taskId: invocation.namedArguments[#taskId] as String,
              subtype: invocation.namedArguments[#subtype] as String,
            ),
          );
        });
        when(
          () => localEmbeddingRepo.embedDocument(any()),
        ).thenAnswer((invocation) async {
          final input = invocation.positionalArguments.first as String;
          actualEmbedInputs.add(input);
          final currentIndex = embedCallIndex++;
          if (scenario.failureIndex == currentIndex) {
            throw StateError('generated report embedding failure');
          }
          return _fakeEmbedding();
        });

        final run = processAgentReport(
          reportId: scenario.reportId,
          reportContent: scenario.reportContent,
          taskId: scenario.taskId,
          categoryId: scenario.categoryId,
          subtype: scenario.subtype,
          embeddingStore: localEmbeddingStore,
          embeddingRepository: localEmbeddingRepo,
        );

        if (scenario.shouldThrow) {
          await expectLater(
            run,
            throwsA(isA<StateError>()),
            reason: '$scenario',
          );
        } else {
          expect(await run, scenario.shouldStore, reason: '$scenario');
        }

        final expectedInputs = scenario.shouldThrow
            ? scenario.chunks.take(scenario.failureIndex! + 1).toList()
            : scenario.chunks;
        expect(actualEmbedInputs, expectedInputs, reason: '$scenario');

        if (scenario.shouldStore) {
          expect(writes, hasLength(1), reason: '$scenario');
          final write = writes.single;
          expect(write.entityId, scenario.reportId, reason: '$scenario');
          expect(write.entityType, kEntityTypeAgentReport, reason: '$scenario');
          expect(write.modelId, _modelId, reason: '$scenario');
          expect(
            write.contentHash,
            _hashOf(scenario.trimmedContent),
            reason: '$scenario',
          );
          expect(
            write.embeddingCount,
            scenario.chunks.length,
            reason: '$scenario',
          );
          expect(write.categoryId, scenario.categoryId, reason: '$scenario');
          expect(write.taskId, scenario.taskId, reason: '$scenario');
          expect(write.subtype, scenario.subtype, reason: '$scenario');
        } else {
          expect(writes, isEmpty, reason: '$scenario');
        }
      },
      tags: 'glados',
    );
  });

  // The traces of specs/tla/EmbeddingFreshness.tla: runs of the service, the
  // backfill and the report writer interleaved around a slow network call.
  group('concurrent runs stay in step with the journal', () {
    const firstText = 'The first version of this entry, long enough.';
    const secondText = 'The second version of this entry, long enough.';

    JournalEntry entryWith(String text) => JournalEntry(
      meta: _meta(),
      entryText: EntryText(plainText: text),
    );

    test(
      'a run that read an older version cannot land after a newer run',
      () async {
        final rows = <String, _StoredRow>{};
        _backWithRows(mockEmbeddingStore, rows);
        var current = entryWith(firstText);
        when(
          () => mockJournalDb.journalEntityById('entity-1'),
        ).thenAnswer((_) async => current);
        final firstEmbed = _pauseFirstEmbed(mockEmbeddingRepo);

        // The backfill reads the first version and waits on the network…
        final backfill = processEntity(entityId: 'entity-1');
        await pumpEventQueue();
        // …the user edits, and the service processes the edit.
        current = entryWith(secondText);
        final service = processEntity(entityId: 'entity-1');
        await pumpEventQueue();
        firstEmbed.complete(_fakeEmbedding());
        await Future.wait([backfill, service]);

        // Nothing else will process the entry: what is stored now stays.
        expect(rows['entity-1']!.hash, _hashOf(secondText));
      },
    );

    test('an undone edit is not skipped behind a run that saw it', () async {
      final rows = {
        'entity-1': _StoredRow(
          hash: _hashOf(firstText),
          categoryId: '',
          taskId: '',
        ),
      };
      _backWithRows(mockEmbeddingStore, rows);
      var current = entryWith(secondText);
      when(
        () => mockJournalDb.journalEntityById('entity-1'),
      ).thenAnswer((_) async => current);
      final firstEmbed = _pauseFirstEmbed(mockEmbeddingRepo);

      // The backfill reads the edit; the user undoes it, and the service
      // finds the undone text equal to what is stored.
      final backfill = processEntity(entityId: 'entity-1');
      await pumpEventQueue();
      current = entryWith(firstText);
      final service = processEntity(entityId: 'entity-1');
      await pumpEventQueue();
      firstEmbed.complete(_fakeEmbedding());
      await Future.wait([backfill, service]);

      expect(rows['entity-1']!.hash, _hashOf(firstText));
    });

    test('a short task still takes its reports to its new category', () async {
      final rows = {
        'report-1': _StoredRow(
          hash: 'report-hash',
          categoryId: 'cat-old',
          taskId: 'task-1',
        ),
      };
      _backWithRows(mockEmbeddingStore, rows);
      // Too short to embed, so the task has no vector of its own.
      final task = Task(
        meta: _meta(id: 'task-1', categoryId: 'cat-new'),
        data: _taskData('Fix login'),
      );

      final result = await processEntity(entity: task);

      expect(result, isFalse);
      expect(rows['report-1']!.categoryId, 'cat-new');
    });

    _StoredRow reportOf(String taskId) =>
        _StoredRow(hash: 'report-hash', categoryId: 'cat-1', taskId: taskId);

    test('a stored report is the only one its task keeps', () async {
      final rows = {
        'report-old': reportOf('task-1'),
        // Its own embed was skipped, so nothing ever replaced it.
        'report-orphan': reportOf('task-1'),
        'report-other-task': reportOf('task-2'),
      };
      _backWithRows(mockEmbeddingStore, rows);

      final result = await processAgentReport(
        reportId: 'report-new',
        reportContent: 'The latest agent report, with plenty of content.',
        taskId: 'task-1',
        categoryId: 'cat-1',
        subtype: 'current',
        embeddingStore: mockEmbeddingStore,
        embeddingRepository: mockEmbeddingRepo,
      );

      expect(result, isTrue);
      expect(rows.keys, unorderedEquals(['report-new', 'report-other-task']));
    });

    test('a skipped or failed report deletes nothing', () async {
      final rows = {'report-old': reportOf('task-1')};
      _backWithRows(mockEmbeddingStore, rows);

      final skipped = await processAgentReport(
        reportId: 'report-short',
        reportContent: 'Too short.',
        taskId: 'task-1',
        categoryId: 'cat-1',
        subtype: 'current',
        embeddingStore: mockEmbeddingStore,
        embeddingRepository: mockEmbeddingRepo,
      );
      when(
        () => mockEmbeddingRepo.embedDocument(any()),
      ).thenThrow(StateError('offline'));
      final failed = processAgentReport(
        reportId: 'report-failed',
        reportContent: 'A long enough report whose embedding call fails.',
        taskId: 'task-1',
        categoryId: 'cat-1',
        subtype: 'current',
        embeddingStore: mockEmbeddingStore,
        embeddingRepository: mockEmbeddingRepo,
      );

      expect(skipped, isFalse);
      await expectLater(failed, throwsStateError);
      expect(rows.keys, ['report-old']);
    });

    test(
      "an earlier report's cleanup never deletes a newer report",
      () async {
        final rows = <String, _StoredRow>{};
        _backWithRows(mockEmbeddingStore, rows);
        // The first run's cleanup is held between storing its report and
        // listing the task's reports, the window a later run must not use.
        final firstListing = Completer<void>();
        var listings = 0;
        when(
          () => mockEmbeddingStore.agentReportIdsForTask('task-1'),
        ).thenAnswer((_) async {
          if (listings++ == 0) await firstListing.future;
          return {
            for (final MapEntry(:key, :value) in rows.entries)
              if (value.taskId == 'task-1') key,
          };
        });

        // Two wakes write reports one after the other; both embeds are
        // fire-and-forget.
        final first = processAgentReport(
          reportId: 'report-1',
          reportContent: 'The first wake report, with plenty of content.',
          taskId: 'task-1',
          categoryId: 'cat-1',
          subtype: 'current',
          embeddingStore: mockEmbeddingStore,
          embeddingRepository: mockEmbeddingRepo,
        );
        await pumpEventQueue();
        final second = processAgentReport(
          reportId: 'report-2',
          reportContent: 'The second wake report, with plenty of content.',
          taskId: 'task-1',
          categoryId: 'cat-1',
          subtype: 'current',
          embeddingStore: mockEmbeddingStore,
          embeddingRepository: mockEmbeddingRepo,
        );
        await pumpEventQueue();
        firstListing.complete();
        await Future.wait([first, second]);

        expect(rows.keys, ['report-2']);
      },
    );

    test(
      'a report embedded while its task moves category follows the task',
      () async {
        final rows = {
          'task-1': _StoredRow(
            hash: _hashOf('Task title\n$_longText'),
            categoryId: 'cat-old',
            taskId: '',
          ),
        };
        _backWithRows(mockEmbeddingStore, rows);
        var task = Task(
          meta: _meta(id: 'task-1', categoryId: 'cat-old'),
          data: _taskData('Task title'),
          entryText: const EntryText(plainText: _longText),
        );
        when(
          () => mockJournalDb.journalEntityById('task-1'),
        ).thenAnswer((_) async => task);
        final reportEmbed = _pauseFirstEmbed(mockEmbeddingRepo);

        // The agent's report reads the task's category and embeds…
        final report = EmbeddingProcessor.processAgentReport(
          reportId: 'report-1',
          reportContent: 'An agent report with plenty of content to embed.',
          taskId: 'task-1',
          subtype: 'current',
          journalDb: mockJournalDb,
          embeddingStore: mockEmbeddingStore,
          embeddingRepository: mockEmbeddingRepo,
        );
        await pumpEventQueue();
        // …while the user moves the task, and the service processes it.
        task = task.copyWith(
          meta: task.meta.copyWith(categoryId: 'cat-new'),
        );
        final service = processEntity(entityId: 'task-1');
        await pumpEventQueue();
        reportEmbed.complete(_fakeEmbedding());
        await Future.wait([report, service]);

        expect(rows['task-1']!.categoryId, 'cat-new');
        expect(rows['report-1']!.categoryId, 'cat-new');
      },
    );
  });

  group('register versions', () {
    late InMemoryEmbeddingStore store;
    late MockEmbeddingShare share;
    late MockEmbeddingVersionTicket ticket;

    const sharedClock = VectorClock({'host-a': 7});

    setUp(() {
      store = InMemoryEmbeddingStore();
      share = MockEmbeddingShare();
      ticket = MockEmbeddingVersionTicket();
      when(() => ticket.vectorClock).thenReturn(sharedClock);
      when(() => ticket.hostId).thenReturn('host-a');
      when(() => ticket.send(any(), any())).thenAnswer((_) async {});
      when(ticket.release).thenAnswer((_) async {});
      when(
        () => share.reserve(
          registerId: any(named: 'registerId'),
          previous: any(named: 'previous'),
        ),
      ).thenAnswer((_) async => ticket);
    });

    tearDown(() => EmbeddingProcessor.share = null);

    Future<bool> process(JournalEntity entity) {
      _stubEntity(mockJournalDb, entity);
      return EmbeddingProcessor.processEntity(
        entityId: entity.id,
        journalDb: mockJournalDb,
        embeddingStore: store,
        embeddingRepository: mockEmbeddingRepo,
      );
    }

    final entry = JournalEntry(
      meta: _meta(id: 'entry-1').copyWith(
        vectorClock: const VectorClock({'host-b': 3}),
      ),
      entryText: const EntryText(plainText: _longText),
    );

    test('without a share a version is stored with no clock', () async {
      await process(entry);

      final register = store.registers['entry-1']!;
      expect(register.isShared, isFalse);
      expect(register.contentHash, _hashOf(_longText));
      expect(register.sourceVectorClock, const VectorClock({'host-b': 3}));
      expect(register.modelId, _modelId);
    });

    test(
      'a shared version extends the stored clock, is stored with the '
      "ticket's clock and sent with its chunks",
      () async {
        store.registers['entry-1'] = const EmbeddingRegister(
          entityId: 'entry-1',
          modelId: _modelId,
          entityType: kEntityTypeJournalText,
          contentHash: 'old',
          vectorClock: VectorClock({'host-a': 2}),
        );
        EmbeddingProcessor.share = share;

        await process(entry);

        verify(
          () => share.reserve(
            registerId: 'entry-1|$_modelId',
            previous: const VectorClock({'host-a': 2}),
          ),
        ).called(1);
        final register = store.registers['entry-1']!;
        expect(register.vectorClock, sharedClock);
        expect(register.originatingHostId, 'host-a');
        final sent = verify(() => ticket.send(captureAny(), captureAny()))
          ..called(1);
        expect(sent.captured[0], register);
        expect(
          sent.captured[1] as List<Float32List>,
          store.chunkVectors('entry-1'),
        );
        verifyNever(ticket.release);
      },
    );

    test(
      'a store that fails releases the reservation and sends nothing',
      () async {
        final failing = MockEmbeddingStore();
        stubEmbeddingRegisters(failing);
        when(() => failing.getContentHash(any())).thenReturn(null);
        when(() => failing.getCategoryId(any())).thenReturn(null);
        when(
          () => failing.replaceEntityEmbeddings(
            entityId: any(named: 'entityId'),
            entityType: any(named: 'entityType'),
            modelId: any(named: 'modelId'),
            contentHash: any(named: 'contentHash'),
            embeddings: any(named: 'embeddings'),
            categoryId: any(named: 'categoryId'),
            taskId: any(named: 'taskId'),
            subtype: any(named: 'subtype'),
            register: any(named: 'register'),
          ),
        ).thenThrow(StateError('disk full'));
        EmbeddingProcessor.share = share;
        _stubEntity(mockJournalDb, entry);

        await expectLater(
          EmbeddingProcessor.processEntity(
            entityId: entry.id,
            journalDb: mockJournalDb,
            embeddingStore: failing,
            embeddingRepository: mockEmbeddingRepo,
          ),
          throwsStateError,
        );

        verify(ticket.release).called(1);
        verifyNever(() => ticket.send(any(), any()));
      },
    );

    test(
      'a deleted entry leaves a sent tombstone in place of its vectors',
      () async {
        await process(entry);
        EmbeddingProcessor.share = share;
        when(
          () => mockJournalDb.journalEntityById('entry-1'),
        ).thenAnswer((_) async => null);

        await EmbeddingProcessor.processEntity(
          entityId: 'entry-1',
          journalDb: mockJournalDb,
          embeddingStore: store,
          embeddingRepository: mockEmbeddingRepo,
        );

        final tombstone = store.registers['entry-1']!;
        expect(tombstone.deleted, isTrue);
        expect(tombstone.vectorClock, sharedClock);
        expect(tombstone.entityType, kEntityTypeJournalText);
        expect(store.chunks, isEmpty);
        verify(() => ticket.send(tombstone, const [])).called(1);
      },
    );

    test(
      'a deleted entry this device never embedded still announces its '
      'removal, made from the deleted version',
      () async {
        EmbeddingProcessor.share = share;
        when(
          () => mockJournalDb.journalEntityById('entry-1'),
        ).thenAnswer((_) async => null);
        when(
          () => mockJournalDb.journalEntityByIdIncludingDeleted('entry-1'),
        ).thenAnswer(
          (_) async => entry.copyWith(
            meta: entry.meta.copyWith(
              vectorClock: const VectorClock({'host-b': 4}),
              deletedAt: _fixedDate,
            ),
          ),
        );

        await EmbeddingProcessor.processEntity(
          entityId: 'entry-1',
          journalDb: mockJournalDb,
          embeddingStore: store,
          embeddingRepository: mockEmbeddingRepo,
        );

        final tombstone = store.registers['entry-1']!;
        expect(tombstone.deleted, isTrue);
        expect(tombstone.entityType, kEntityTypeJournalText);
        expect(tombstone.sourceVectorClock, const VectorClock({'host-b': 4}));
        verify(() => ticket.send(tombstone, const [])).called(1);

        // A second pass finds the tombstone and sends nothing more.
        await EmbeddingProcessor.processEntity(
          entityId: 'entry-1',
          journalDb: mockJournalDb,
          embeddingStore: store,
          embeddingRepository: mockEmbeddingRepo,
        );
        verifyNever(() => ticket.send(any(), any()));
      },
    );

    test(
      'an id that was never an embeddable entry announces nothing',
      () async {
        EmbeddingProcessor.share = share;
        when(
          () => mockJournalDb.journalEntityById('gone'),
        ).thenAnswer((_) async => null);

        await EmbeddingProcessor.processEntity(
          entityId: 'gone',
          journalDb: mockJournalDb,
          embeddingStore: store,
          embeddingRepository: mockEmbeddingRepo,
        );

        expect(store.registers, isEmpty);
        verifyNever(
          () => share.reserve(
            registerId: any(named: 'registerId'),
            previous: any(named: 'previous'),
          ),
        );
      },
    );

    test(
      'a tombstone made from this version or a later one is not embedded '
      'over; one made from an older version is',
      () async {
        Future<void> tombstoneFrom(Map<String, int> source) async =>
            store.registers['entry-1'] = EmbeddingRegister(
              entityId: 'entry-1',
              modelId: _modelId,
              entityType: kEntityTypeJournalText,
              contentHash: '',
              vectorClock: const VectorClock({'host-c': 1}),
              sourceVectorClock: VectorClock(source),
              deleted: true,
            );

        await tombstoneFrom({'host-b': 3});
        expect(await process(entry), isFalse);
        await tombstoneFrom({'host-b': 5});
        expect(await process(entry), isFalse);
        expect(store.chunks, isEmpty);

        await tombstoneFrom({'host-b': 2});
        expect(await process(entry), isTrue);
        expect(store.chunks.keys, ['entry-1']);
      },
    );

    test(
      "a shortened entry's tombstone is made from the short version",
      () async {
        await process(entry);
        EmbeddingProcessor.share = share;

        await process(
          JournalEntry(
            meta: _meta(id: 'entry-1').copyWith(
              vectorClock: const VectorClock({'host-b': 9}),
            ),
            entryText: const EntryText(plainText: 'short'),
          ),
        );

        final tombstone = store.registers['entry-1']!;
        expect(tombstone.deleted, isTrue);
        expect(tombstone.sourceVectorClock, const VectorClock({'host-b': 9}));
      },
    );

    test('a removal with no share deletes the register along', () async {
      await process(entry);
      when(
        () => mockJournalDb.journalEntityById('entry-1'),
      ).thenAnswer((_) async => null);

      await EmbeddingProcessor.processEntity(
        entityId: 'entry-1',
        journalDb: mockJournalDb,
        embeddingStore: store,
        embeddingRepository: mockEmbeddingRepo,
      );

      expect(store.registers, isEmpty);
      expect(store.chunks, isEmpty);
    });

    test(
      'an entry that never had vectors, or has a tombstone already, sends '
      'nothing however often it is processed',
      () async {
        EmbeddingProcessor.share = share;
        final short = JournalEntry(
          meta: _meta(id: 'entry-2'),
          entryText: const EntryText(plainText: 'short'),
        );
        await process(short);
        store.registers['entry-2'] = const EmbeddingRegister(
          entityId: 'entry-2',
          modelId: _modelId,
          entityType: kEntityTypeJournalText,
          contentHash: '',
          vectorClock: VectorClock({'host-a': 1}),
          deleted: true,
        );
        await process(short);

        verifyNever(
          () => share.reserve(
            registerId: any(named: 'registerId'),
            previous: any(named: 'previous'),
          ),
        );
      },
    );

    test(
      "a report's cleanup sends a tombstone for each report it removes",
      () async {
        when(
          () => mockJournalDb.journalEntityById('task-1'),
        ).thenAnswer((_) async => null);
        Future<void> report(String id) => EmbeddingProcessor.processAgentReport(
          reportId: id,
          reportContent: 'An agent report with plenty of content: $id',
          taskId: 'task-1',
          subtype: 'current',
          journalDb: mockJournalDb,
          embeddingStore: store,
          embeddingRepository: mockEmbeddingRepo,
        );
        await report('report-1');
        EmbeddingProcessor.share = share;

        await report('report-2');

        expect(store.chunks.keys, ['report-2']);
        final tombstone = store.registers['report-1']!;
        expect(tombstone.deleted, isTrue);
        expect(tombstone.taskId, 'task-1');
        verify(() => ticket.send(tombstone, const [])).called(1);
      },
    );
  });
}
