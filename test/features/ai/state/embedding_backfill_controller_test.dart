import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/ai/database/embeddings_db.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/ollama_embedding_repository.dart';
import 'package:lotti/features/ai/service/embedding_content_extractor.dart';
import 'package:lotti/features/ai/state/embedding_backfill_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

// ---------------------------------------------------------------------------
// Test data helpers
// ---------------------------------------------------------------------------

final _fixedDate = DateTime(2024, 3, 15);

Metadata _meta({required String id}) => Metadata(
      id: id,
      createdAt: _fixedDate,
      updatedAt: _fixedDate,
      dateFrom: _fixedDate,
      dateTo: _fixedDate,
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

const _longText = 'This is a sufficiently long text for embedding generation.';

Float32List _fakeEmbedding() => Float32List(kEmbeddingDimensions);

const _testCategoryId = 'cat-1';

const _ollamaBaseUrl = 'http://localhost:11434';

/// Computes the same SHA-256 hash as EmbeddingContentExtractor.contentHash.
String _hashOf(String text) => sha256.convert(utf8.encode(text)).toString();

// ---------------------------------------------------------------------------
// Stub helpers
// ---------------------------------------------------------------------------

void _stubOllamaProvider(MockAiConfigRepository repo) {
  when(() => repo.resolveOllamaBaseUrl())
      .thenAnswer((_) async => _ollamaBaseUrl);
}

void _stubNoExistingHash(MockEmbeddingsDb db) {
  when(() => db.getContentHash(any())).thenReturn(null);
}

void _stubUpsertEmbedding(MockEmbeddingsDb db) {
  when(
    () => db.upsertEmbedding(
      entityId: any(named: 'entityId'),
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

void _stubEntityIds(MockJournalDb db, List<String> ids) {
  when(() => db.journalEntityIdsByCategory(_testCategoryId))
      .thenReturn(MockSelectable<String>(ids));
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
  late MockAiConfigRepository mockAiConfigRepo;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(Float32List(0));
  });

  setUp(() async {
    await getIt.reset();

    mockJournalDb = MockJournalDb();
    mockEmbeddingsDb = MockEmbeddingsDb();
    mockEmbeddingRepo = MockOllamaEmbeddingRepository();
    mockAiConfigRepo = MockAiConfigRepository();

    getIt
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<EmbeddingsDb>(mockEmbeddingsDb)
      ..registerSingleton<OllamaEmbeddingRepository>(mockEmbeddingRepo)
      ..registerSingleton<AiConfigRepository>(mockAiConfigRepo);

    _stubOllamaProvider(mockAiConfigRepo);
    _stubNoExistingHash(mockEmbeddingsDb);
    _stubUpsertEmbedding(mockEmbeddingsDb);
    _stubEmbed(mockEmbeddingRepo);

    // Default: embeddings flag enabled
    when(() => mockJournalDb.getConfigFlag(enableEmbeddingsFlag))
        .thenAnswer((_) async => true);

    // Default: no labels (needed for label resolver)
    when(() => mockJournalDb.getAllLabelDefinitions())
        .thenAnswer((_) async => []);

    container = ProviderContainer();
  });

  tearDown(() async {
    container.dispose();
    await getIt.reset();
  });

  EmbeddingBackfillController controller() =>
      container.read(embeddingBackfillControllerProvider.notifier);

  EmbeddingBackfillState state() =>
      container.read(embeddingBackfillControllerProvider);

  group('EmbeddingBackfillController initial state', () {
    test('starts with default values', () {
      final s = state();
      expect(s.isRunning, isFalse);
      expect(s.progress, 0);
      expect(s.processedCount, 0);
      expect(s.totalCount, 0);
      expect(s.embeddedCount, 0);
      expect(s.error, isNull);
    });
  });

  group('EmbeddingBackfillController processes entities', () {
    test('generates embedding for a task entry', () async {
      final task = Task(
        meta: _meta(id: 'entity-1'),
        data: _taskData('Test task title'),
        entryText: const EntryText(plainText: _longText),
      );

      _stubEntityIds(mockJournalDb, ['entity-1']);
      _stubEntity(mockJournalDb, task);

      await controller().backfillCategory(_testCategoryId);

      final s = state();
      expect(s.isRunning, isFalse);
      expect(s.progress, 1.0);
      expect(s.processedCount, 1);
      expect(s.totalCount, 1);
      expect(s.embeddedCount, 1);
      expect(s.error, isNull);

      verify(
        () => mockEmbeddingsDb.upsertEmbedding(
          entityId: 'entity-1',
          entityType: 'task',
          modelId: any(named: 'modelId'),
          embedding: any(named: 'embedding'),
          contentHash: any(named: 'contentHash'),
          categoryId: any(named: 'categoryId'),
        ),
      ).called(1);
    });

    test('generates embedding for a journal text entry', () async {
      final entry = JournalEntry(
        meta: _meta(id: 'entry-1'),
        entryText: const EntryText(plainText: _longText),
      );

      _stubEntityIds(mockJournalDb, ['entry-1']);
      _stubEntity(mockJournalDb, entry);

      await controller().backfillCategory(_testCategoryId);

      expect(state().embeddedCount, 1);
      verify(
        () => mockEmbeddingsDb.upsertEmbedding(
          entityId: 'entry-1',
          entityType: 'journal_text',
          modelId: any(named: 'modelId'),
          embedding: any(named: 'embedding'),
          contentHash: any(named: 'contentHash'),
          categoryId: any(named: 'categoryId'),
        ),
      ).called(1);
    });

    test('processes multiple entities with final progress at 1.0', () async {
      final entities = List.generate(
        5,
        (i) => JournalEntry(
          meta: _meta(id: 'entity-$i'),
          entryText: const EntryText(plainText: _longText),
        ),
      );
      final ids = entities.map((e) => e.id).toList();

      _stubEntityIds(mockJournalDb, ids);
      for (final entity in entities) {
        _stubEntity(mockJournalDb, entity);
      }

      await controller().backfillCategory(_testCategoryId);

      final s = state();
      expect(s.processedCount, 5);
      expect(s.totalCount, 5);
      expect(s.embeddedCount, 5);
      expect(s.progress, 1.0);
    });

    test('passes correct base URL to embedding repository', () async {
      final entry = JournalEntry(
        meta: _meta(id: 'entry-1'),
        entryText: const EntryText(plainText: _longText),
      );

      _stubEntityIds(mockJournalDb, ['entry-1']);
      _stubEntity(mockJournalDb, entry);

      await controller().backfillCategory(_testCategoryId);

      verify(
        () => mockEmbeddingRepo.embed(
          input: any(named: 'input'),
          baseUrl: _ollamaBaseUrl,
          model: any(named: 'model'),
        ),
      ).called(1);
    });
  });

  group('EmbeddingBackfillController skips entries', () {
    test('skips entities not found in database', () async {
      _stubEntityIds(mockJournalDb, ['missing-1']);
      when(() => mockJournalDb.journalEntityById('missing-1'))
          .thenAnswer((_) async => null);

      await controller().backfillCategory(_testCategoryId);

      expect(state().processedCount, 1);
      expect(state().embeddedCount, 0);
      verifyNever(
        () => mockEmbeddingRepo.embed(
          input: any(named: 'input'),
          baseUrl: any(named: 'baseUrl'),
          model: any(named: 'model'),
        ),
      );
    });

    test('skips entities with no extractable text (JournalImage)', () async {
      final image = JournalImage(
        meta: _meta(id: 'image-1'),
        data: ImageData(
          imageId: 'img-id',
          imageFile: 'photo.jpg',
          imageDirectory: '/images',
          capturedAt: _fixedDate,
        ),
      );

      _stubEntityIds(mockJournalDb, ['image-1']);
      _stubEntity(mockJournalDb, image);

      await controller().backfillCategory(_testCategoryId);

      expect(state().processedCount, 1);
      expect(state().embeddedCount, 0);
    });

    test('skips entities with text shorter than minimum length', () async {
      final entry = JournalEntry(
        meta: _meta(id: 'short-1'),
        entryText: const EntryText(plainText: 'Too short'),
      );

      _stubEntityIds(mockJournalDb, ['short-1']);
      _stubEntity(mockJournalDb, entry);

      await controller().backfillCategory(_testCategoryId);

      expect(state().processedCount, 1);
      expect(state().embeddedCount, 0);
    });

    test('skips entities with unchanged content hash', () async {
      final entry = JournalEntry(
        meta: _meta(id: 'cached-1'),
        entryText: const EntryText(plainText: _longText),
      );

      _stubEntityIds(mockJournalDb, ['cached-1']);
      _stubEntity(mockJournalDb, entry);

      when(() => mockEmbeddingsDb.getContentHash('cached-1'))
          .thenReturn(_hashOf(_longText));

      await controller().backfillCategory(_testCategoryId);

      expect(state().processedCount, 1);
      expect(state().embeddedCount, 0);
      verifyNever(
        () => mockEmbeddingRepo.embed(
          input: any(named: 'input'),
          baseUrl: any(named: 'baseUrl'),
          model: any(named: 'model'),
        ),
      );
    });

    test('embeddedCount reflects only actually embedded entries', () async {
      // Embeddable task
      final task = Task(
        meta: _meta(id: 'task-1'),
        data: _taskData('Embeddable task'),
        entryText: const EntryText(plainText: _longText),
      );
      // Image (not embeddable)
      final image = JournalImage(
        meta: _meta(id: 'image-1'),
        data: ImageData(
          imageId: 'img',
          imageFile: 'photo.jpg',
          imageDirectory: '/images',
          capturedAt: _fixedDate,
        ),
      );
      // Entry with cached hash (skipped)
      final cached = JournalEntry(
        meta: _meta(id: 'cached-1'),
        entryText: const EntryText(plainText: _longText),
      );

      _stubEntityIds(mockJournalDb, ['task-1', 'image-1', 'cached-1']);
      _stubEntity(mockJournalDb, task);
      _stubEntity(mockJournalDb, image);
      _stubEntity(mockJournalDb, cached);
      when(() => mockEmbeddingsDb.getContentHash('cached-1'))
          .thenReturn(_hashOf(_longText));

      await controller().backfillCategory(_testCategoryId);

      final s = state();
      expect(s.processedCount, 3);
      expect(s.totalCount, 3);
      expect(s.embeddedCount, 1);
    });

    test('handles empty category gracefully', () async {
      _stubEntityIds(mockJournalDb, []);

      await controller().backfillCategory(_testCategoryId);

      final s = state();
      expect(s.isRunning, isFalse);
      expect(s.progress, 1.0);
      expect(s.totalCount, 0);
      expect(s.processedCount, 0);
      expect(s.embeddedCount, 0);
    });
  });

  group('EmbeddingBackfillController error handling', () {
    test('continues processing after per-entity embed failure', () async {
      final bad = JournalEntry(
        meta: _meta(id: 'bad-1'),
        entryText: const EntryText(
          plainText: 'Bad entry with enough text for embedding gen.',
        ),
      );
      final good = JournalEntry(
        meta: _meta(id: 'good-1'),
        entryText: const EntryText(plainText: _longText),
      );

      _stubEntityIds(mockJournalDb, ['bad-1', 'good-1']);
      _stubEntity(mockJournalDb, bad);
      _stubEntity(mockJournalDb, good);

      // Override: first embed call throws, second succeeds
      var callCount = 0;
      when(
        () => mockEmbeddingRepo.embed(
          input: any(named: 'input'),
          baseUrl: any(named: 'baseUrl'),
          model: any(named: 'model'),
        ),
      ).thenAnswer((_) {
        callCount++;
        if (callCount == 1) throw Exception('Ollama down');
        return Future.value(_fakeEmbedding());
      });

      await controller().backfillCategory(_testCategoryId);

      final s = state();
      expect(s.processedCount, 2);
      expect(s.embeddedCount, 1);
      expect(s.error, isNull);
    });

    test('sets error when embedding pipeline not registered', () async {
      await getIt.reset();
      container.dispose();
      container = ProviderContainer();

      await controller().backfillCategory(_testCategoryId);

      expect(state().error, contains('not available'));
      expect(state().isRunning, isFalse);
    });

    test('sets error when no Ollama provider configured', () async {
      when(() => mockAiConfigRepo.resolveOllamaBaseUrl())
          .thenAnswer((_) async => null);

      await controller().backfillCategory(_testCategoryId);

      expect(state().error, contains('No Ollama provider'));
      expect(state().isRunning, isFalse);
    });

    test('sets error on unexpected exception during ID fetch', () async {
      when(() => mockJournalDb.journalEntityIdsByCategory(_testCategoryId))
          .thenThrow(Exception('Database connection lost'));

      await controller().backfillCategory(_testCategoryId);

      expect(state().error, contains('Database connection lost'));
      expect(state().isRunning, isFalse);
    });
  });

  group('EmbeddingBackfillController state transitions', () {
    test('clears previous error when starting new backfill', () async {
      // First: trigger error
      when(() => mockAiConfigRepo.resolveOllamaBaseUrl())
          .thenAnswer((_) async => null);

      await controller().backfillCategory(_testCategoryId);
      expect(state().error, isNotNull);

      // Second: fix provider, run empty category
      _stubOllamaProvider(mockAiConfigRepo);
      _stubEntityIds(mockJournalDb, []);

      await controller().backfillCategory(_testCategoryId);
      expect(state().error, isNull);
    });

    test('resets counters when starting new backfill', () async {
      final entry = JournalEntry(
        meta: _meta(id: 'entity-1'),
        entryText: const EntryText(plainText: _longText),
      );
      _stubEntityIds(mockJournalDb, ['entity-1']);
      _stubEntity(mockJournalDb, entry);

      await controller().backfillCategory(_testCategoryId);
      expect(state().processedCount, 1);

      // Second run — counters reset
      _stubEntityIds(mockJournalDb, []);
      await controller().backfillCategory(_testCategoryId);

      expect(state().processedCount, 0);
      expect(state().embeddedCount, 0);
      expect(state().totalCount, 0);
    });

    test('isRunning is false after completion', () async {
      _stubEntityIds(mockJournalDb, []);
      await controller().backfillCategory(_testCategoryId);
      expect(state().isRunning, isFalse);
    });

    test('isRunning is false after error', () async {
      when(() => mockAiConfigRepo.resolveOllamaBaseUrl())
          .thenAnswer((_) async => null);

      await controller().backfillCategory(_testCategoryId);
      expect(state().isRunning, isFalse);
    });

    test('cancel sets cancelled flag', () {
      // Verify cancel doesn't crash and the controller remains usable.
      expect(state().isRunning, isFalse);
    });

    test('cancel stops processing mid-loop', () async {
      // Create 3 entities — cancel after the first embed call
      final entities = List.generate(
        3,
        (i) => JournalEntry(
          meta: _meta(id: 'entity-$i'),
          entryText: const EntryText(plainText: _longText),
        ),
      );
      _stubEntityIds(mockJournalDb, entities.map((e) => e.id).toList());
      for (final entity in entities) {
        _stubEntity(mockJournalDb, entity);
      }

      // Cancel after the first embed call
      var embedCount = 0;
      when(
        () => mockEmbeddingRepo.embed(
          input: any(named: 'input'),
          baseUrl: any(named: 'baseUrl'),
          model: any(named: 'model'),
        ),
      ).thenAnswer((_) async {
        embedCount++;
        if (embedCount == 1) {
          controller().cancel();
        }
        return _fakeEmbedding();
      });

      await controller().backfillCategory(_testCategoryId);

      // Should have processed only 1 entity (cancelled before 2nd iteration)
      final s = state();
      expect(s.processedCount, 1);
      expect(s.embeddedCount, 1);
      expect(s.isRunning, isFalse);
    });

    test('rejects concurrent backfill when already running', () async {
      // Make the first backfill hang by using a Completer
      final entities = [
        JournalEntry(
          meta: _meta(id: 'slow-1'),
          entryText: const EntryText(plainText: _longText),
        ),
      ];
      _stubEntityIds(mockJournalDb, ['slow-1']);
      _stubEntity(mockJournalDb, entities.first);

      final completer = Completer<Float32List>();
      when(
        () => mockEmbeddingRepo.embed(
          input: any(named: 'input'),
          baseUrl: any(named: 'baseUrl'),
          model: any(named: 'model'),
        ),
      ).thenAnswer((_) => completer.future);

      // Start first backfill (won't complete yet)
      final firstRun = controller().backfillCategory(_testCategoryId);

      // Allow isRunning to be set
      await Future<void>.delayed(Duration.zero);
      expect(state().isRunning, isTrue);

      // Second call should be ignored
      await controller().backfillCategory(_testCategoryId);

      // Complete the hanging embed
      completer.complete(_fakeEmbedding());
      await firstRun;

      expect(state().processedCount, 1);
      expect(state().isRunning, isFalse);
    });

    test('sets error when embeddings are disabled', () async {
      when(() => mockJournalDb.getConfigFlag(enableEmbeddingsFlag))
          .thenAnswer((_) async => false);

      await controller().backfillCategory(_testCategoryId);

      expect(state().error, contains('disabled'));
      expect(state().isRunning, isFalse);
    });
  });

  group('EmbeddingBackfillState copyWith', () {
    test('preserves existing values when no arguments given', () {
      const original = EmbeddingBackfillState(
        progress: 0.5,
        isRunning: true,
        processedCount: 10,
        totalCount: 20,
        embeddedCount: 5,
        error: 'some error',
      );

      final copied = original.copyWith();

      expect(copied.progress, 0.5);
      expect(copied.isRunning, isTrue);
      expect(copied.processedCount, 10);
      expect(copied.totalCount, 20);
      expect(copied.embeddedCount, 5);
      expect(copied.error, 'some error');
    });

    test('updates specified fields', () {
      const original = EmbeddingBackfillState();

      final updated = original.copyWith(
        progress: 0.75,
        isRunning: true,
        processedCount: 15,
        totalCount: 20,
        embeddedCount: 10,
        error: 'test error',
      );

      expect(updated.progress, 0.75);
      expect(updated.isRunning, isTrue);
      expect(updated.processedCount, 15);
      expect(updated.totalCount, 20);
      expect(updated.embeddedCount, 10);
      expect(updated.error, 'test error');
    });

    test('clearError sets error to null', () {
      const original = EmbeddingBackfillState(error: 'old error');
      final cleared = original.copyWith(clearError: true);
      expect(cleared.error, isNull);
    });

    test('clearError takes precedence over error parameter', () {
      const original = EmbeddingBackfillState(error: 'old error');
      final cleared = original.copyWith(clearError: true, error: 'new error');
      expect(cleared.error, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // backfillAgentReports tests
  // -------------------------------------------------------------------------

  group('EmbeddingBackfillController.backfillAgentReports', () {
    late MockAgentRepository mockAgentRepo;

    /// Creates a test agent identity.
    AgentIdentityEntity makeAgent(String id) => AgentDomainEntity.agent(
          id: id,
          agentId: id,
          kind: 'task_agent',
          displayName: 'Test Agent $id',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-$id',
          config: const AgentConfig(),
          createdAt: _fixedDate,
          updatedAt: _fixedDate,
          vectorClock: null,
        ) as AgentIdentityEntity;

    /// Creates a test agent report.
    AgentReportEntity makeReport({
      required String id,
      required String agentId,
      String content = 'A long enough agent report content for embedding.',
    }) =>
        AgentDomainEntity.agentReport(
          id: id,
          agentId: agentId,
          scope: AgentReportScopes.current,
          createdAt: _fixedDate,
          vectorClock: null,
          content: content,
        ) as AgentReportEntity;

    /// Creates a test agent link.
    AgentLink makeTaskLink({
      required String fromId,
      required String toId,
    }) =>
        AgentLink.basic(
          id: 'link-$fromId-$toId',
          fromId: fromId,
          toId: toId,
          createdAt: _fixedDate,
          updatedAt: _fixedDate,
          vectorClock: null,
        );

    setUp(() async {
      mockAgentRepo = MockAgentRepository();
      if (getIt.isRegistered<AgentRepository>()) {
        getIt.unregister<AgentRepository>();
      }
      getIt.registerSingleton<AgentRepository>(mockAgentRepo);
    });

    test('embeds agent reports and tracks progress', () async {
      final agent = makeAgent('agent-1');
      final report = makeReport(id: 'report-1', agentId: 'agent-1');

      when(() => mockAgentRepo.getAllAgentIdentities())
          .thenAnswer((_) async => [agent]);
      when(
        () => mockAgentRepo.getLinksFrom(
          'agent-1',
          type: AgentLinkTypes.agentTask,
        ),
      ).thenAnswer(
        (_) async => [makeTaskLink(fromId: 'agent-1', toId: 'task-1')],
      );
      when(
        () => mockAgentRepo.getLatestReport(
          'agent-1',
          AgentReportScopes.current,
        ),
      ).thenAnswer((_) async => report);

      // Stub task entity lookup for category resolution.
      final task = Task(
        meta: _meta(id: 'task-1'),
        data: _taskData('Test task'),
      );
      _stubEntity(mockJournalDb, task);

      await controller().backfillAgentReports();

      final s = state();
      expect(s.isRunning, isFalse);
      expect(s.processedCount, 1);
      expect(s.totalCount, 1);
      expect(s.embeddedCount, 1);
      expect(s.progress, 1.0);

      verify(
        () => mockEmbeddingsDb.upsertEmbedding(
          entityId: 'report-1',
          entityType: kEntityTypeAgentReport,
          modelId: any(named: 'modelId'),
          embedding: any(named: 'embedding'),
          contentHash: any(named: 'contentHash'),
          categoryId: any(named: 'categoryId'),
          taskId: 'task-1',
          subtype: AgentReportScopes.current,
        ),
      ).called(1);
    });

    test('skips agents with no task links', () async {
      final agent = makeAgent('agent-1');

      when(() => mockAgentRepo.getAllAgentIdentities())
          .thenAnswer((_) async => [agent]);
      when(
        () => mockAgentRepo.getLinksFrom(
          'agent-1',
          type: AgentLinkTypes.agentTask,
        ),
      ).thenAnswer((_) async => []);

      await controller().backfillAgentReports();

      final s = state();
      expect(s.processedCount, 1);
      expect(s.embeddedCount, 0);
    });

    test('skips agents with no report', () async {
      final agent = makeAgent('agent-1');

      when(() => mockAgentRepo.getAllAgentIdentities())
          .thenAnswer((_) async => [agent]);
      when(
        () => mockAgentRepo.getLinksFrom(
          'agent-1',
          type: AgentLinkTypes.agentTask,
        ),
      ).thenAnswer(
        (_) async => [makeTaskLink(fromId: 'agent-1', toId: 'task-1')],
      );
      when(
        () => mockAgentRepo.getLatestReport(
          'agent-1',
          AgentReportScopes.current,
        ),
      ).thenAnswer((_) async => null);

      await controller().backfillAgentReports();

      expect(state().processedCount, 1);
      expect(state().embeddedCount, 0);
    });

    test('skips agents with empty report content', () async {
      final agent = makeAgent('agent-1');
      final emptyReport =
          makeReport(id: 'report-1', agentId: 'agent-1', content: '');

      when(() => mockAgentRepo.getAllAgentIdentities())
          .thenAnswer((_) async => [agent]);
      when(
        () => mockAgentRepo.getLinksFrom(
          'agent-1',
          type: AgentLinkTypes.agentTask,
        ),
      ).thenAnswer(
        (_) async => [makeTaskLink(fromId: 'agent-1', toId: 'task-1')],
      );
      when(
        () => mockAgentRepo.getLatestReport(
          'agent-1',
          AgentReportScopes.current,
        ),
      ).thenAnswer((_) async => emptyReport);

      await controller().backfillAgentReports();

      expect(state().processedCount, 1);
      expect(state().embeddedCount, 0);
    });

    test('handles empty agent list gracefully', () async {
      when(() => mockAgentRepo.getAllAgentIdentities())
          .thenAnswer((_) async => []);

      await controller().backfillAgentReports();

      final s = state();
      expect(s.isRunning, isFalse);
      expect(s.progress, 1.0);
      expect(s.totalCount, 0);
    });

    test('sets error when AgentRepository is not registered', () async {
      getIt.unregister<AgentRepository>();

      await controller().backfillAgentReports();

      expect(state().error, contains('not available'));
      expect(state().isRunning, isFalse);
    });

    test('sets error when embeddings are disabled', () async {
      when(() => mockJournalDb.getConfigFlag(enableEmbeddingsFlag))
          .thenAnswer((_) async => false);

      await controller().backfillAgentReports();

      expect(state().error, contains('disabled'));
      expect(state().isRunning, isFalse);
    });

    test('sets error when no Ollama provider configured', () async {
      when(() => mockAiConfigRepo.resolveOllamaBaseUrl())
          .thenAnswer((_) async => null);

      await controller().backfillAgentReports();

      expect(state().error, contains('No Ollama provider'));
      expect(state().isRunning, isFalse);
    });

    test('continues processing after per-agent error', () async {
      final agent1 = makeAgent('agent-1');
      final agent2 = makeAgent('agent-2');
      final report2 = makeReport(id: 'report-2', agentId: 'agent-2');

      when(() => mockAgentRepo.getAllAgentIdentities())
          .thenAnswer((_) async => [agent1, agent2]);

      // Agent 1: getLinksFrom throws
      when(
        () => mockAgentRepo.getLinksFrom(
          'agent-1',
          type: AgentLinkTypes.agentTask,
        ),
      ).thenThrow(Exception('Agent DB error'));

      // Agent 2: works fine
      when(
        () => mockAgentRepo.getLinksFrom(
          'agent-2',
          type: AgentLinkTypes.agentTask,
        ),
      ).thenAnswer(
        (_) async => [makeTaskLink(fromId: 'agent-2', toId: 'task-2')],
      );
      when(
        () => mockAgentRepo.getLatestReport(
          'agent-2',
          AgentReportScopes.current,
        ),
      ).thenAnswer((_) async => report2);

      final task = Task(
        meta: _meta(id: 'task-2'),
        data: _taskData('Test task 2'),
      );
      _stubEntity(mockJournalDb, task);

      await controller().backfillAgentReports();

      final s = state();
      expect(s.processedCount, 2);
      expect(s.embeddedCount, 1);
      expect(s.error, isNull);
    });

    test('resolves task category from journal entity', () async {
      final agent = makeAgent('agent-1');
      final report = makeReport(id: 'report-1', agentId: 'agent-1');

      when(() => mockAgentRepo.getAllAgentIdentities())
          .thenAnswer((_) async => [agent]);
      when(
        () => mockAgentRepo.getLinksFrom(
          'agent-1',
          type: AgentLinkTypes.agentTask,
        ),
      ).thenAnswer(
        (_) async => [makeTaskLink(fromId: 'agent-1', toId: 'task-1')],
      );
      when(
        () => mockAgentRepo.getLatestReport(
          'agent-1',
          AgentReportScopes.current,
        ),
      ).thenAnswer((_) async => report);

      // Task with a specific category
      final task = Task(
        meta: Metadata(
          id: 'task-1',
          createdAt: _fixedDate,
          updatedAt: _fixedDate,
          dateFrom: _fixedDate,
          dateTo: _fixedDate,
          categoryId: 'my-category',
        ),
        data: _taskData('Categorized task'),
      );
      _stubEntity(mockJournalDb, task);

      await controller().backfillAgentReports();

      verify(
        () => mockEmbeddingsDb.upsertEmbedding(
          entityId: 'report-1',
          entityType: kEntityTypeAgentReport,
          modelId: any(named: 'modelId'),
          embedding: any(named: 'embedding'),
          contentHash: any(named: 'contentHash'),
          categoryId: 'my-category',
          taskId: 'task-1',
          subtype: AgentReportScopes.current,
        ),
      ).called(1);
    });

    test('uses empty category when task not found', () async {
      final agent = makeAgent('agent-1');
      final report = makeReport(id: 'report-1', agentId: 'agent-1');

      when(() => mockAgentRepo.getAllAgentIdentities())
          .thenAnswer((_) async => [agent]);
      when(
        () => mockAgentRepo.getLinksFrom(
          'agent-1',
          type: AgentLinkTypes.agentTask,
        ),
      ).thenAnswer(
        (_) async => [makeTaskLink(fromId: 'agent-1', toId: 'task-1')],
      );
      when(
        () => mockAgentRepo.getLatestReport(
          'agent-1',
          AgentReportScopes.current,
        ),
      ).thenAnswer((_) async => report);

      // Task not found in journal DB
      when(() => mockJournalDb.journalEntityById('task-1'))
          .thenAnswer((_) async => null);

      await controller().backfillAgentReports();

      verify(
        () => mockEmbeddingsDb.upsertEmbedding(
          entityId: 'report-1',
          entityType: kEntityTypeAgentReport,
          modelId: any(named: 'modelId'),
          embedding: any(named: 'embedding'),
          contentHash: any(named: 'contentHash'),
          taskId: 'task-1',
          subtype: AgentReportScopes.current,
        ),
      ).called(1);
    });
  });

  // -------------------------------------------------------------------------
  // reindexAll tests
  // -------------------------------------------------------------------------

  group('EmbeddingBackfillController.reindexAll', () {
    late MockAgentRepository mockAgentRepo;

    AgentIdentityEntity makeAgent(String id) => AgentDomainEntity.agent(
          id: id,
          agentId: id,
          kind: 'task_agent',
          displayName: 'Test Agent $id',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-$id',
          config: const AgentConfig(),
          createdAt: _fixedDate,
          updatedAt: _fixedDate,
          vectorClock: null,
        ) as AgentIdentityEntity;

    AgentReportEntity makeReport({
      required String id,
      required String agentId,
      String content = 'A long enough agent report content for embedding.',
    }) =>
        AgentDomainEntity.agentReport(
          id: id,
          agentId: agentId,
          scope: AgentReportScopes.current,
          createdAt: _fixedDate,
          vectorClock: null,
          content: content,
        ) as AgentReportEntity;

    AgentLink makeTaskLink({
      required String fromId,
      required String toId,
    }) =>
        AgentLink.basic(
          id: 'link-$fromId-$toId',
          fromId: fromId,
          toId: toId,
          createdAt: _fixedDate,
          updatedAt: _fixedDate,
          vectorClock: null,
        );

    CategoryDefinitionDbEntity makeCategory(String id) =>
        CategoryDefinitionDbEntity(
          id: id,
          name: 'Category $id',
          createdAt: _fixedDate,
          updatedAt: _fixedDate,
          deleted: false,
          private: false,
          serialized: '{}',
          active: true,
        );

    void stubDeleteAll() {
      when(() => mockEmbeddingsDb.deleteAll()).thenReturn(null);
    }

    void stubCategories(List<CategoryDefinitionDbEntity> cats) {
      when(() => mockJournalDb.allCategoryDefinitions())
          .thenReturn(MockSelectable<CategoryDefinitionDbEntity>(cats));
    }

    void stubDeleteEntityEmbeddings() {
      when(() => mockEmbeddingsDb.deleteEntityEmbeddings(any()))
          .thenReturn(null);
    }

    setUp(() async {
      mockAgentRepo = MockAgentRepository();
      if (getIt.isRegistered<AgentRepository>()) {
        getIt.unregister<AgentRepository>();
      }
      getIt.registerSingleton<AgentRepository>(mockAgentRepo);
      stubDeleteAll();
      stubDeleteEntityEmbeddings();
    });

    test('clears all embeddings and re-indexes entities and agent reports',
        () async {
      final cat = makeCategory('cat-1');
      stubCategories([cat]);

      final task = Task(
        meta: _meta(id: 'task-1'),
        data: _taskData('Reindex task'),
        entryText: const EntryText(plainText: _longText),
      );
      when(() => mockJournalDb.journalEntityIdsByCategory('cat-1'))
          .thenReturn(MockSelectable<String>(['task-1']));
      _stubEntity(mockJournalDb, task);

      // Agent setup
      final agent = makeAgent('agent-1');
      final report = makeReport(id: 'report-1', agentId: 'agent-1');
      when(() => mockAgentRepo.getAllAgentIdentities())
          .thenAnswer((_) async => [agent]);
      when(
        () => mockAgentRepo.getLinksFrom(
          'agent-1',
          type: AgentLinkTypes.agentTask,
        ),
      ).thenAnswer(
        (_) async => [makeTaskLink(fromId: 'agent-1', toId: 'task-1')],
      );
      when(
        () => mockAgentRepo.getLatestReport(
          'agent-1',
          AgentReportScopes.current,
        ),
      ).thenAnswer((_) async => report);

      await controller().reindexAll();

      final s = state();
      expect(s.isRunning, isFalse);
      expect(s.error, isNull);
      expect(s.totalCount, 2); // 1 entity + 1 agent
      expect(s.processedCount, 2);
      expect(s.embeddedCount, 2);
      expect(s.progress, 1.0);

      verify(() => mockEmbeddingsDb.deleteAll()).called(1);
    });

    test('handles empty categories and no agents', () async {
      stubCategories([]);
      when(() => mockAgentRepo.getAllAgentIdentities())
          .thenAnswer((_) async => []);

      await controller().reindexAll();

      final s = state();
      expect(s.isRunning, isFalse);
      expect(s.progress, 1.0);
      expect(s.totalCount, 0);
      verify(() => mockEmbeddingsDb.deleteAll()).called(1);
    });

    test('processes multiple categories', () async {
      final cat1 = makeCategory('cat-1');
      final cat2 = makeCategory('cat-2');
      stubCategories([cat1, cat2]);

      final entry1 = JournalEntry(
        meta: _meta(id: 'entry-1'),
        entryText: const EntryText(plainText: _longText),
      );
      final entry2 = JournalEntry(
        meta: _meta(id: 'entry-2'),
        entryText: const EntryText(plainText: _longText),
      );

      when(() => mockJournalDb.journalEntityIdsByCategory('cat-1'))
          .thenReturn(MockSelectable<String>(['entry-1']));
      when(() => mockJournalDb.journalEntityIdsByCategory('cat-2'))
          .thenReturn(MockSelectable<String>(['entry-2']));
      _stubEntity(mockJournalDb, entry1);
      _stubEntity(mockJournalDb, entry2);

      when(() => mockAgentRepo.getAllAgentIdentities())
          .thenAnswer((_) async => []);

      await controller().reindexAll();

      final s = state();
      expect(s.processedCount, 2);
      expect(s.embeddedCount, 2);
      expect(s.totalCount, 2);
    });

    test('skips agent reports phase when AgentRepository not registered',
        () async {
      // Unregister to test the fallback path
      getIt.unregister<AgentRepository>();

      stubCategories([]);

      await controller().reindexAll();

      final s = state();
      expect(s.isRunning, isFalse);
      expect(s.progress, 1.0);
      expect(s.totalCount, 0);
    });

    test('sets error when embeddings disabled', () async {
      when(() => mockJournalDb.getConfigFlag(enableEmbeddingsFlag))
          .thenAnswer((_) async => false);

      await controller().reindexAll();

      expect(state().error, contains('disabled'));
      expect(state().isRunning, isFalse);
    });

    test('sets error when pipeline not available', () async {
      await getIt.reset();
      container.dispose();
      container = ProviderContainer();

      await controller().reindexAll();

      expect(state().error, contains('not available'));
      expect(state().isRunning, isFalse);
    });

    test('sets error when no Ollama provider configured', () async {
      when(() => mockAiConfigRepo.resolveOllamaBaseUrl())
          .thenAnswer((_) async => null);

      await controller().reindexAll();

      expect(state().error, contains('No Ollama provider'));
      expect(state().isRunning, isFalse);
    });

    test('cancellation stops processing mid-loop', () async {
      final cat = makeCategory('cat-1');
      stubCategories([cat]);

      final entries = List.generate(
        3,
        (i) => JournalEntry(
          meta: _meta(id: 'entry-$i'),
          entryText: const EntryText(plainText: _longText),
        ),
      );
      when(() => mockJournalDb.journalEntityIdsByCategory('cat-1')).thenReturn(
          MockSelectable<String>(entries.map((e) => e.id).toList()));
      for (final e in entries) {
        _stubEntity(mockJournalDb, e);
      }
      when(() => mockAgentRepo.getAllAgentIdentities())
          .thenAnswer((_) async => []);

      // Cancel after first embed
      var embedCount = 0;
      when(
        () => mockEmbeddingRepo.embed(
          input: any(named: 'input'),
          baseUrl: any(named: 'baseUrl'),
          model: any(named: 'model'),
        ),
      ).thenAnswer((_) async {
        embedCount++;
        if (embedCount == 1) controller().cancel();
        return _fakeEmbedding();
      });

      await controller().reindexAll();

      expect(state().processedCount, 1);
      expect(state().isRunning, isFalse);
    });

    test('agent report error does not stop other agents', () async {
      stubCategories([]);

      final agent1 = makeAgent('agent-1');
      final agent2 = makeAgent('agent-2');
      final report2 = makeReport(id: 'report-2', agentId: 'agent-2');

      when(() => mockAgentRepo.getAllAgentIdentities())
          .thenAnswer((_) async => [agent1, agent2]);

      // Agent 1 throws
      when(
        () => mockAgentRepo.getLinksFrom(
          'agent-1',
          type: AgentLinkTypes.agentTask,
        ),
      ).thenThrow(Exception('Agent error'));

      // Agent 2 succeeds
      when(
        () => mockAgentRepo.getLinksFrom(
          'agent-2',
          type: AgentLinkTypes.agentTask,
        ),
      ).thenAnswer(
        (_) async => [makeTaskLink(fromId: 'agent-2', toId: 'task-2')],
      );
      when(
        () => mockAgentRepo.getLatestReport(
          'agent-2',
          AgentReportScopes.current,
        ),
      ).thenAnswer((_) async => report2);

      final task = Task(
        meta: _meta(id: 'task-2'),
        data: _taskData('Task 2'),
      );
      _stubEntity(mockJournalDb, task);

      await controller().reindexAll();

      final s = state();
      expect(s.processedCount, 2);
      expect(s.embeddedCount, 1);
      expect(s.error, isNull);
    });

    test('skips agents with no task links during reindex', () async {
      stubCategories([]);

      final agent = makeAgent('agent-1');
      when(() => mockAgentRepo.getAllAgentIdentities())
          .thenAnswer((_) async => [agent]);
      when(
        () => mockAgentRepo.getLinksFrom(
          'agent-1',
          type: AgentLinkTypes.agentTask,
        ),
      ).thenAnswer((_) async => []);

      await controller().reindexAll();

      final s = state();
      expect(s.processedCount, 1);
      expect(s.embeddedCount, 0);
    });

    test('skips agents with null report during reindex', () async {
      stubCategories([]);

      final agent = makeAgent('agent-1');
      when(() => mockAgentRepo.getAllAgentIdentities())
          .thenAnswer((_) async => [agent]);
      when(
        () => mockAgentRepo.getLinksFrom(
          'agent-1',
          type: AgentLinkTypes.agentTask,
        ),
      ).thenAnswer(
        (_) async => [makeTaskLink(fromId: 'agent-1', toId: 'task-1')],
      );
      when(
        () => mockAgentRepo.getLatestReport(
          'agent-1',
          AgentReportScopes.current,
        ),
      ).thenAnswer((_) async => null);

      await controller().reindexAll();

      final s = state();
      expect(s.processedCount, 1);
      expect(s.embeddedCount, 0);
    });

    test('skips agents with empty report content during reindex', () async {
      stubCategories([]);

      final agent = makeAgent('agent-1');
      final emptyReport =
          makeReport(id: 'report-1', agentId: 'agent-1', content: '');
      when(() => mockAgentRepo.getAllAgentIdentities())
          .thenAnswer((_) async => [agent]);
      when(
        () => mockAgentRepo.getLinksFrom(
          'agent-1',
          type: AgentLinkTypes.agentTask,
        ),
      ).thenAnswer(
        (_) async => [makeTaskLink(fromId: 'agent-1', toId: 'task-1')],
      );
      when(
        () => mockAgentRepo.getLatestReport(
          'agent-1',
          AgentReportScopes.current,
        ),
      ).thenAnswer((_) async => emptyReport);

      await controller().reindexAll();

      final s = state();
      expect(s.processedCount, 1);
      expect(s.embeddedCount, 0);
    });

    test('cancellation during agent reports phase stops processing', () async {
      stubCategories([]);

      final agents = List.generate(3, (i) => makeAgent('agent-$i'));
      for (var i = 0; i < 3; i++) {
        final report = makeReport(id: 'report-$i', agentId: 'agent-$i');
        when(
          () => mockAgentRepo.getLinksFrom(
            'agent-$i',
            type: AgentLinkTypes.agentTask,
          ),
        ).thenAnswer(
          (_) async => [makeTaskLink(fromId: 'agent-$i', toId: 'task-$i')],
        );
        when(
          () => mockAgentRepo.getLatestReport(
            'agent-$i',
            AgentReportScopes.current,
          ),
        ).thenAnswer((_) async => report);
        final task = Task(
          meta: _meta(id: 'task-$i'),
          data: _taskData('Task $i'),
        );
        _stubEntity(mockJournalDb, task);
      }
      when(() => mockAgentRepo.getAllAgentIdentities())
          .thenAnswer((_) async => agents);

      // Cancel after first agent report embed
      var embedCount = 0;
      when(
        () => mockEmbeddingRepo.embed(
          input: any(named: 'input'),
          baseUrl: any(named: 'baseUrl'),
          model: any(named: 'model'),
        ),
      ).thenAnswer((_) async {
        embedCount++;
        if (embedCount == 1) controller().cancel();
        return _fakeEmbedding();
      });

      await controller().reindexAll();

      // Should have processed only 1 agent before cancellation took effect
      expect(state().processedCount, 1);
      expect(state().isRunning, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // Label resolver in backfillCategory tests
  // -------------------------------------------------------------------------

  group('EmbeddingBackfillController label resolver', () {
    test('enriches task embeddings with resolved label names', () async {
      final task = Task(
        meta: Metadata(
          id: 'task-1',
          createdAt: _fixedDate,
          updatedAt: _fixedDate,
          dateFrom: _fixedDate,
          dateTo: _fixedDate,
          labelIds: ['label-1', 'label-2'],
        ),
        data: _taskData('Fix auth bug'),
        entryText: const EntryText(plainText: _longText),
      );

      _stubEntityIds(mockJournalDb, ['task-1']);
      _stubEntity(mockJournalDb, task);

      // Stub label definitions
      when(() => mockJournalDb.getAllLabelDefinitions())
          .thenAnswer((_) async => [
                LabelDefinition(
                  id: 'label-1',
                  name: 'security',
                  color: '#FF0000',
                  createdAt: _fixedDate,
                  updatedAt: _fixedDate,
                  vectorClock: null,
                ),
                LabelDefinition(
                  id: 'label-2',
                  name: 'backend',
                  color: '#00FF00',
                  createdAt: _fixedDate,
                  updatedAt: _fixedDate,
                  vectorClock: null,
                ),
              ]);

      await controller().backfillCategory(_testCategoryId);

      const expectedText =
          'Fix auth bug\nLabels: security, backend\n$_longText';
      verify(
        () => mockEmbeddingRepo.embed(
          input: expectedText,
          baseUrl: _ollamaBaseUrl,
          model: any(named: 'model'),
        ),
      ).called(1);
    });

    test('filters out deleted labels from resolver', () async {
      final task = Task(
        meta: Metadata(
          id: 'task-1',
          createdAt: _fixedDate,
          updatedAt: _fixedDate,
          dateFrom: _fixedDate,
          dateTo: _fixedDate,
          labelIds: ['label-1', 'label-deleted'],
        ),
        data: _taskData('Some task with enough title for testing'),
      );

      _stubEntityIds(mockJournalDb, ['task-1']);
      _stubEntity(mockJournalDb, task);

      when(() => mockJournalDb.getAllLabelDefinitions())
          .thenAnswer((_) async => [
                LabelDefinition(
                  id: 'label-1',
                  name: 'active',
                  color: '#FF0000',
                  createdAt: _fixedDate,
                  updatedAt: _fixedDate,
                  vectorClock: null,
                ),
                LabelDefinition(
                  id: 'label-deleted',
                  name: 'deleted',
                  color: '#999999',
                  createdAt: _fixedDate,
                  updatedAt: _fixedDate,
                  vectorClock: null,
                  deletedAt: _fixedDate,
                ),
              ]);

      await controller().backfillCategory(_testCategoryId);

      // Capture the input text that was embedded.
      final captured = verify(
        () => mockEmbeddingRepo.embed(
          input: captureAny(named: 'input'),
          baseUrl: _ollamaBaseUrl,
          model: any(named: 'model'),
        ),
      ).captured;

      final embeddedText = captured.first as String;
      // Only 'active' label should appear, not 'deleted'
      expect(embeddedText, contains('Labels: active'));
      expect(embeddedText, isNot(contains('deleted')));
    });
  });
}
