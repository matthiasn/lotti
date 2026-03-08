import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/service/embedding_content_extractor.dart';
import 'package:lotti/features/ai/service/embedding_processor.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

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
  });
}
