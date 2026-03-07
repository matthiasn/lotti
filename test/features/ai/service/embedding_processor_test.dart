import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/ai/database/embeddings_db.dart';
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

void _stubNoExistingHash(MockEmbeddingsDb db) {
  when(() => db.getContentHash(any())).thenReturn(null);
}

void _stubDeleteEntityEmbeddings(MockEmbeddingsDb db) {
  when(() => db.deleteEntityEmbeddings(any())).thenReturn(null);
}

void _stubUpsertEmbedding(MockEmbeddingsDb db) {
  when(
    () => db.upsertEmbedding(
      entityId: any(named: 'entityId'),
      chunkIndex: any(named: 'chunkIndex'),
      entityType: any(named: 'entityType'),
      modelId: any(named: 'modelId'),
      embedding: any(named: 'embedding'),
      contentHash: any(named: 'contentHash'),
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
  late MockEmbeddingsDb mockEmbeddingsDb;
  late MockOllamaEmbeddingRepository mockEmbeddingRepo;

  setUpAll(() {
    registerFallbackValue(Float32List(0));
  });

  setUp(() {
    mockJournalDb = MockJournalDb();
    mockEmbeddingsDb = MockEmbeddingsDb();
    mockEmbeddingRepo = MockOllamaEmbeddingRepository();

    _stubNoExistingHash(mockEmbeddingsDb);
    _stubDeleteEntityEmbeddings(mockEmbeddingsDb);
    _stubUpsertEmbedding(mockEmbeddingsDb);
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
        embeddingsDb: mockEmbeddingsDb,
        embeddingRepository: mockEmbeddingRepo,
        baseUrl: _baseUrl,
      );

      expect(result, isTrue);
      verify(
        () => mockEmbeddingsDb.upsertEmbedding(
          entityId: entry.id,
          entityType: kEntityTypeJournalText,
          modelId: ollamaEmbedDefaultModel,
          embedding: any(named: 'embedding'),
          contentHash: _hashOf(_longText),
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
        embeddingsDb: mockEmbeddingsDb,
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
        embeddingsDb: mockEmbeddingsDb,
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
        embeddingsDb: mockEmbeddingsDb,
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
        () => mockEmbeddingsDb.getContentHash(entry.id),
      ).thenReturn(_hashOf(_longText));

      final result = await EmbeddingProcessor.processEntity(
        entityId: entry.id,
        journalDb: mockJournalDb,
        embeddingsDb: mockEmbeddingsDb,
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
          embeddingsDb: mockEmbeddingsDb,
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
          embeddingsDb: mockEmbeddingsDb,
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
        embeddingsDb: mockEmbeddingsDb,
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
        embeddingsDb: mockEmbeddingsDb,
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
          embeddingsDb: mockEmbeddingsDb,
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
        embeddingsDb: mockEmbeddingsDb,
        embeddingRepository: mockEmbeddingRepo,
        baseUrl: _baseUrl,
      );

      expect(result, isTrue);
      verify(
        () => mockEmbeddingsDb.upsertEmbedding(
          entityId: 'report-1',
          entityType: kEntityTypeAgentReport,
          modelId: ollamaEmbedDefaultModel,
          embedding: any(named: 'embedding'),
          contentHash: _hashOf(reportContent),
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
        embeddingsDb: mockEmbeddingsDb,
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
        embeddingsDb: mockEmbeddingsDb,
        embeddingRepository: mockEmbeddingRepo,
        baseUrl: _baseUrl,
      );

      expect(result, isFalse);
    });

    test('returns false when content hash unchanged', () async {
      const reportContent = 'This report content is long enough for embedding.';
      when(
        () => mockEmbeddingsDb.getContentHash('report-1'),
      ).thenReturn(_hashOf(reportContent));

      final result = await EmbeddingProcessor.processAgentReport(
        reportId: 'report-1',
        reportContent: reportContent,
        taskId: 'task-1',
        categoryId: 'cat-1',
        subtype: 'current',
        embeddingsDb: mockEmbeddingsDb,
        embeddingRepository: mockEmbeddingRepo,
        baseUrl: _baseUrl,
      );

      expect(result, isFalse);
    });

    test('embeds when content hash differs (content changed)', () async {
      const reportContent = 'Updated report content that is long enough.';
      when(
        () => mockEmbeddingsDb.getContentHash('report-1'),
      ).thenReturn('old-hash-that-no-longer-matches');

      final result = await EmbeddingProcessor.processAgentReport(
        reportId: 'report-1',
        reportContent: reportContent,
        taskId: 'task-1',
        categoryId: 'cat-1',
        subtype: 'current',
        embeddingsDb: mockEmbeddingsDb,
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
        embeddingsDb: mockEmbeddingsDb,
        embeddingRepository: mockEmbeddingRepo,
        baseUrl: _baseUrl,
      );

      verify(
        () => mockEmbeddingsDb.upsertEmbedding(
          entityId: any(named: 'entityId'),
          chunkIndex: any(named: 'chunkIndex'),
          entityType: kEntityTypeAgentReport,
          modelId: any(named: 'modelId'),
          embedding: any(named: 'embedding'),
          contentHash: any(named: 'contentHash'),
          categoryId: any(named: 'categoryId'),
          taskId: any(named: 'taskId'),
          subtype: any(named: 'subtype'),
        ),
      ).called(1);
    });
  });
}
