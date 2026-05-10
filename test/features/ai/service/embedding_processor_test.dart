import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/service/embedding_content_extractor.dart';
import 'package:lotti/features/ai/service/embedding_processor.dart';
import 'package:lotti/features/ai/service/text_chunker.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

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
const _baseUrl = 'http://localhost:11434';
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
    ),
  ).thenReturn(null);
}

void _stubEmbed(MockOllamaEmbeddingRepository repo) {
  when(
    () => repo.embed(
      input: any(named: 'input'),
      baseUrl: any(named: 'baseUrl'),
      model: any(named: 'model'),
    ),
  ).thenAnswer((_) async => _fakeEmbedding());
}

void _stubEntity(MockJournalDb db, JournalEntity entity) {
  when(() => db.journalEntityById(entity.id)).thenAnswer((_) async => entity);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockJournalDb mockJournalDb;
  late MockEmbeddingStore mockEmbeddingStore;
  late MockOllamaEmbeddingRepository mockEmbeddingRepo;

  setUpAll(() {
    registerFallbackValue(Float32List(0));
  });

  setUp(() {
    mockJournalDb = MockJournalDb();
    mockEmbeddingStore = MockEmbeddingStore();
    mockEmbeddingRepo = MockOllamaEmbeddingRepository();

    _stubNoExistingHash(mockEmbeddingStore);
    _stubNoCategoryId(mockEmbeddingStore);
    _stubReplaceEntityEmbeddings(mockEmbeddingStore);
    _stubEmbed(mockEmbeddingRepo);
  });

  group('EmbeddingProcessor.processEntity', () {
    test('embeds a journal entry and returns true', () async {
      final entry = JournalEntry(
        meta: _meta(categoryId: 'cat-1'),
        entryText: const EntryText(plainText: _longText),
      );
      _stubEntity(mockJournalDb, entry);

      final result = await EmbeddingProcessor.processEntity(
        entityId: entry.id,
        journalDb: mockJournalDb,
        embeddingStore: mockEmbeddingStore,
        embeddingRepository: mockEmbeddingRepo,
        baseUrl: _baseUrl,
      );

      expect(result, isTrue);
      verify(
        () => mockEmbeddingStore.replaceEntityEmbeddings(
          entityId: entry.id,
          entityType: kEntityTypeJournalText,
          modelId: ollamaEmbedDefaultModel,
          contentHash: _hashOf(_longText),
          embeddings: any(named: 'embeddings'),
          categoryId: 'cat-1',
          taskId: any(named: 'taskId'),
          subtype: any(named: 'subtype'),
        ),
      ).called(1);
    });

    test('returns false when entity not found', () async {
      when(
        () => mockJournalDb.journalEntityById('missing'),
      ).thenAnswer((_) async => null);

      final result = await EmbeddingProcessor.processEntity(
        entityId: 'missing',
        journalDb: mockJournalDb,
        embeddingStore: mockEmbeddingStore,
        embeddingRepository: mockEmbeddingRepo,
        baseUrl: _baseUrl,
      );

      expect(result, isFalse);
    });

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
      _stubEntity(mockJournalDb, image);

      final result = await EmbeddingProcessor.processEntity(
        entityId: image.id,
        journalDb: mockJournalDb,
        embeddingStore: mockEmbeddingStore,
        embeddingRepository: mockEmbeddingRepo,
        baseUrl: _baseUrl,
      );

      expect(result, isFalse);
    });

    test('returns false when text is too short', () async {
      final entry = JournalEntry(
        meta: _meta(),
        entryText: const EntryText(plainText: 'Too short'),
      );
      _stubEntity(mockJournalDb, entry);

      final result = await EmbeddingProcessor.processEntity(
        entityId: entry.id,
        journalDb: mockJournalDb,
        embeddingStore: mockEmbeddingStore,
        embeddingRepository: mockEmbeddingRepo,
        baseUrl: _baseUrl,
      );

      expect(result, isFalse);
    });

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

      final result = await EmbeddingProcessor.processEntity(
        entityId: entry.id,
        journalDb: mockJournalDb,
        embeddingStore: mockEmbeddingStore,
        embeddingRepository: mockEmbeddingRepo,
        baseUrl: _baseUrl,
      );

      expect(result, isFalse);
      verifyNever(
        () => mockEmbeddingRepo.embed(
          input: any(named: 'input'),
          baseUrl: any(named: 'baseUrl'),
          model: any(named: 'model'),
        ),
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
        _stubEntity(mockJournalDb, task);

        await EmbeddingProcessor.processEntity(
          entityId: task.id,
          journalDb: mockJournalDb,
          embeddingStore: mockEmbeddingStore,
          embeddingRepository: mockEmbeddingRepo,
          baseUrl: _baseUrl,
        );

        // Without label resolver, uses the default extractText format
        const expectedText = 'My task title that is long enough\n$_longText';
        verify(
          () => mockEmbeddingRepo.embed(
            input: expectedText,
            baseUrl: _baseUrl,
          ),
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
        _stubEntity(mockJournalDb, task);

        Future<List<String>> labelResolver(List<String> ids) async => [
          'security',
          'backend',
        ];

        await EmbeddingProcessor.processEntity(
          entityId: task.id,
          journalDb: mockJournalDb,
          embeddingStore: mockEmbeddingStore,
          embeddingRepository: mockEmbeddingRepo,
          baseUrl: _baseUrl,
          labelNameResolver: labelResolver,
        );

        const expectedText =
            'Fix auth bug\nLabels: security, backend\n$_longText';
        verify(
          () => mockEmbeddingRepo.embed(
            input: expectedText,
            baseUrl: _baseUrl,
          ),
        ).called(1);
      },
    );

    test('resolver with empty label IDs omits labels line', () async {
      final task = Task(
        meta: _meta(), // no labelIds
        data: _taskData('A task title that is long enough for embedding'),
      );
      _stubEntity(mockJournalDb, task);

      Future<List<String>> labelResolver(List<String> ids) async => [];

      await EmbeddingProcessor.processEntity(
        entityId: task.id,
        journalDb: mockJournalDb,
        embeddingStore: mockEmbeddingStore,
        embeddingRepository: mockEmbeddingRepo,
        baseUrl: _baseUrl,
        labelNameResolver: labelResolver,
      );

      verify(
        () => mockEmbeddingRepo.embed(
          input: 'A task title that is long enough for embedding',
          baseUrl: _baseUrl,
        ),
      ).called(1);
    });

    test('non-task entity ignores label resolver', () async {
      final entry = JournalEntry(
        meta: _meta(),
        entryText: const EntryText(plainText: _longText),
      );
      _stubEntity(mockJournalDb, entry);

      var resolverCalled = false;
      Future<List<String>> labelResolver(List<String> ids) async {
        resolverCalled = true;
        return [];
      }

      await EmbeddingProcessor.processEntity(
        entityId: entry.id,
        journalDb: mockJournalDb,
        embeddingStore: mockEmbeddingStore,
        embeddingRepository: mockEmbeddingRepo,
        baseUrl: _baseUrl,
        labelNameResolver: labelResolver,
      );

      expect(resolverCalled, isFalse);
      verify(
        () => mockEmbeddingRepo.embed(
          input: _longText,
          baseUrl: _baseUrl,
        ),
      ).called(1);
    });

    glados.Glados(
      glados.any.embeddingScenario,
      glados.ExploreConfig(numRuns: 140),
    ).test(
      'matches generated entity embedding pipeline semantics',
      (scenario) async {
        final localJournalDb = MockJournalDb();
        final localEmbeddingStore = MockEmbeddingStore();
        final localEmbeddingRepo = MockOllamaEmbeddingRepository();
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
          baseUrl: _baseUrl,
          labelNameResolver: scenario.useLabelResolver ? labelResolver : null,
        );

        if (!scenario.shouldEmbedEntity) {
          expect(result, isFalse, reason: '$scenario');
          verifyNever(
            () => localEmbeddingRepo.embed(
              input: any(named: 'input'),
              baseUrl: any(named: 'baseUrl'),
              model: any(named: 'model'),
            ),
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
            ),
          );
          return;
        }

        final expectedCategoryId = scenario.categoryId ?? '';
        if (scenario.hashMatches) {
          expect(result, scenario.categoryChanged, reason: '$scenario');
          verifyNever(
            () => localEmbeddingRepo.embed(
              input: any(named: 'input'),
              baseUrl: any(named: 'baseUrl'),
              model: any(named: 'model'),
            ),
          );
          if (scenario.categoryChanged) {
            verify(
              () => localEmbeddingStore.moveEntityToShard(
                scenario.entityId,
                expectedCategoryId,
              ),
            ).called(1);
            if (scenario.isTask) {
              verify(
                () => localEmbeddingStore.moveRelatedReportEmbeddings(
                  scenario.entityId,
                  expectedCategoryId,
                ),
              ).called(1);
            }
          } else {
            verifyNever(
              () => localEmbeddingStore.moveEntityToShard(any(), any()),
            );
          }
          return;
        }

        expect(result, isTrue, reason: '$scenario');
        verify(
          () => localEmbeddingRepo.embed(
            input: expectedText!,
            baseUrl: _baseUrl,
          ),
        ).called(1);
        verify(
          () => localEmbeddingStore.replaceEntityEmbeddings(
            entityId: scenario.entityId,
            entityType: scenario.isTask
                ? kEntityTypeTask
                : kEntityTypeJournalText,
            modelId: ollamaEmbedDefaultModel,
            contentHash: _hashOf(expectedText!),
            embeddings: any(named: 'embeddings'),
            categoryId: expectedCategoryId,
          ),
        ).called(1);
        if (scenario.categoryChanged && scenario.isTask) {
          verify(
            () => localEmbeddingStore.moveRelatedReportEmbeddings(
              scenario.entityId,
              expectedCategoryId,
            ),
          ).called(1);
        } else {
          verifyNever(
            () => localEmbeddingStore.moveRelatedReportEmbeddings(any(), any()),
          );
        }
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
        _stubEntity(mockJournalDb, entry);
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

        final result = await EmbeddingProcessor.processEntity(
          entityId: entry.id,
          journalDb: mockJournalDb,
          embeddingStore: mockEmbeddingStore,
          embeddingRepository: mockEmbeddingRepo,
          baseUrl: _baseUrl,
        );

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
        _stubEntity(mockJournalDb, task);
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

        final result = await EmbeddingProcessor.processEntity(
          entityId: task.id,
          journalDb: mockJournalDb,
          embeddingStore: mockEmbeddingStore,
          embeddingRepository: mockEmbeddingRepo,
          baseUrl: _baseUrl,
        );

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
          _stubEntity(mockJournalDb, task);
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

          final result = await EmbeddingProcessor.processEntity(
            entityId: task.id,
            journalDb: mockJournalDb,
            embeddingStore: mockEmbeddingStore,
            embeddingRepository: mockEmbeddingRepo,
            baseUrl: _baseUrl,
          );

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
        _stubEntity(mockJournalDb, entry);
        when(
          () => mockEmbeddingStore.getContentHash(entry.id),
        ).thenReturn(_hashOf(_longText));
        when(
          () => mockEmbeddingStore.getCategoryId(entry.id),
        ).thenReturn('cat-same');

        final result = await EmbeddingProcessor.processEntity(
          entityId: entry.id,
          journalDb: mockJournalDb,
          embeddingStore: mockEmbeddingStore,
          embeddingRepository: mockEmbeddingRepo,
          baseUrl: _baseUrl,
        );

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
          _stubEntity(mockJournalDb, entry);
          when(
            () => mockEmbeddingStore.getContentHash(entry.id),
          ).thenReturn(_hashOf(_longText));
          when(
            () => mockEmbeddingStore.getCategoryId(entry.id),
          ).thenReturn(null);

          final result = await EmbeddingProcessor.processEntity(
            entityId: entry.id,
            journalDb: mockJournalDb,
            embeddingStore: mockEmbeddingStore,
            embeddingRepository: mockEmbeddingRepo,
            baseUrl: _baseUrl,
          );

          expect(result, isFalse);
        },
      );

      test('moves from named category to default (empty) category', () async {
        // Entity has no categoryId (null → '') but stored as 'cat-old'.
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
        ).thenReturn('cat-old');
        when(
          () => mockEmbeddingStore.moveEntityToShard(any(), any()),
        ).thenReturn(null);

        final result = await EmbeddingProcessor.processEntity(
          entityId: entry.id,
          journalDb: mockJournalDb,
          embeddingStore: mockEmbeddingStore,
          embeddingRepository: mockEmbeddingRepo,
          baseUrl: _baseUrl,
        );

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
        _stubEntity(mockJournalDb, entry);
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

        final result = await EmbeddingProcessor.processEntity(
          entityId: entry.id,
          journalDb: mockJournalDb,
          embeddingStore: mockEmbeddingStore,
          embeddingRepository: mockEmbeddingRepo,
          baseUrl: _baseUrl,
        );

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
        () => mockEmbeddingRepo.embed(
          input: any(named: 'input'),
          baseUrl: any(named: 'baseUrl'),
          model: any(named: 'model'),
        ),
      ).thenThrow(Exception('Ollama down'));

      expect(
        () => EmbeddingProcessor.processEntity(
          entityId: entry.id,
          journalDb: mockJournalDb,
          embeddingStore: mockEmbeddingStore,
          embeddingRepository: mockEmbeddingRepo,
          baseUrl: _baseUrl,
        ),
        throwsException,
      );
    });
  });

  group('EmbeddingProcessor.processAgentReport', () {
    test('embeds report content and returns true', () async {
      const reportContent =
          'This agent report has enough content for embedding.';

      final result = await EmbeddingProcessor.processAgentReport(
        reportId: 'report-1',
        reportContent: reportContent,
        taskId: 'task-1',
        categoryId: 'cat-1',
        subtype: 'current',
        embeddingStore: mockEmbeddingStore,
        embeddingRepository: mockEmbeddingRepo,
        baseUrl: _baseUrl,
      );

      expect(result, isTrue);
      verify(
        () => mockEmbeddingStore.replaceEntityEmbeddings(
          entityId: 'report-1',
          entityType: kEntityTypeAgentReport,
          modelId: ollamaEmbedDefaultModel,
          contentHash: _hashOf(reportContent),
          embeddings: any(named: 'embeddings'),
          categoryId: 'cat-1',
          taskId: 'task-1',
          subtype: 'current',
        ),
      ).called(1);
    });

    test('returns false when content is too short', () async {
      final result = await EmbeddingProcessor.processAgentReport(
        reportId: 'report-1',
        reportContent: 'Too short',
        taskId: 'task-1',
        categoryId: 'cat-1',
        subtype: 'current',
        embeddingStore: mockEmbeddingStore,
        embeddingRepository: mockEmbeddingRepo,
        baseUrl: _baseUrl,
      );

      expect(result, isFalse);
      verifyNever(
        () => mockEmbeddingRepo.embed(
          input: any(named: 'input'),
          baseUrl: any(named: 'baseUrl'),
          model: any(named: 'model'),
        ),
      );
    });

    test('trims whitespace before checking length', () async {
      // Content is short when trimmed
      final result = await EmbeddingProcessor.processAgentReport(
        reportId: 'report-1',
        reportContent: '   short   ',
        taskId: 'task-1',
        categoryId: 'cat-1',
        subtype: 'current',
        embeddingStore: mockEmbeddingStore,
        embeddingRepository: mockEmbeddingRepo,
        baseUrl: _baseUrl,
      );

      expect(result, isFalse);
    });

    test('returns false when content hash unchanged', () async {
      const reportContent = 'This report content is long enough for embedding.';
      when(
        () => mockEmbeddingStore.getContentHash('report-1'),
      ).thenReturn(_hashOf(reportContent));

      final result = await EmbeddingProcessor.processAgentReport(
        reportId: 'report-1',
        reportContent: reportContent,
        taskId: 'task-1',
        categoryId: 'cat-1',
        subtype: 'current',
        embeddingStore: mockEmbeddingStore,
        embeddingRepository: mockEmbeddingRepo,
        baseUrl: _baseUrl,
      );

      expect(result, isFalse);
    });

    test('embeds when content hash differs (content changed)', () async {
      const reportContent = 'Updated report content that is long enough.';
      when(
        () => mockEmbeddingStore.getContentHash('report-1'),
      ).thenReturn('old-hash-that-no-longer-matches');

      final result = await EmbeddingProcessor.processAgentReport(
        reportId: 'report-1',
        reportContent: reportContent,
        taskId: 'task-1',
        categoryId: 'cat-1',
        subtype: 'current',
        embeddingStore: mockEmbeddingStore,
        embeddingRepository: mockEmbeddingRepo,
        baseUrl: _baseUrl,
      );

      expect(result, isTrue);
    });

    test('passes correct entity type for agent reports', () async {
      const reportContent =
          'A report with enough content for embedding generation.';

      await EmbeddingProcessor.processAgentReport(
        reportId: 'report-1',
        reportContent: reportContent,
        taskId: 'task-1',
        categoryId: 'cat-1',
        subtype: 'current',
        embeddingStore: mockEmbeddingStore,
        embeddingRepository: mockEmbeddingRepo,
        baseUrl: _baseUrl,
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
        final localEmbeddingRepo = MockOllamaEmbeddingRepository();
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
          () => localEmbeddingRepo.embed(
            input: any(named: 'input'),
            baseUrl: any(named: 'baseUrl'),
            model: any(named: 'model'),
          ),
        ).thenAnswer((invocation) async {
          final input = invocation.namedArguments[#input] as String;
          actualEmbedInputs.add(input);
          final currentIndex = embedCallIndex++;
          if (scenario.failureIndex == currentIndex) {
            throw StateError('generated report embedding failure');
          }
          return _fakeEmbedding();
        });

        final run = EmbeddingProcessor.processAgentReport(
          reportId: scenario.reportId,
          reportContent: scenario.reportContent,
          taskId: scenario.taskId,
          categoryId: scenario.categoryId,
          subtype: scenario.subtype,
          embeddingStore: localEmbeddingStore,
          embeddingRepository: localEmbeddingRepo,
          baseUrl: _baseUrl,
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
          expect(write.modelId, ollamaEmbedDefaultModel, reason: '$scenario');
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
}
