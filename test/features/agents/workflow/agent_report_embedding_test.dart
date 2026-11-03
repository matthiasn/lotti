import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/workflow/agent_report_embedding.dart';
import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/service/embedding_content_extractor.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  late MockJournalDb journalDb;
  late MockEmbeddingStore store;
  late MockOnDeviceEmbeddingRepository repository;
  late List<String> errors;

  const eventId = 'event-1';
  final at = DateTime(2026, 7, 16, 18, 30);

  setUpAll(registerAllFallbackValues);

  setUp(() {
    journalDb = MockJournalDb();
    store = MockEmbeddingStore();
    repository = MockOnDeviceEmbeddingRepository();
    errors = [];
    stubEmbeddingRegisters(store);
    when(
      () => journalDb.getConfigFlag(enableEmbeddingsFlag),
    ).thenAnswer((_) async => true);
    when(repository.isInstalled).thenAnswer((_) async => true);
    when(() => repository.modelId).thenReturn('test-embedding-model');
    when(() => store.getContentHash(any())).thenReturn(null);
    when(() => repository.embedDocument(any())).thenAnswer(
      (_) async =>
          Float32List.fromList(List<double>.filled(kEmbeddingDimensions, 0.25)),
    );
    when(() => journalDb.journalEntityById(eventId)).thenAnswer(
      (_) async => JournalEntity.event(
        meta: Metadata(
          id: eventId,
          createdAt: at,
          updatedAt: at,
          dateFrom: at,
          dateTo: at,
          categoryId: 'category-outings',
        ),
        data: const EventData(
          title: 'Ice garden picnic',
          stars: 0,
          status: EventStatus.completed,
        ),
      ),
    );
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
    ).thenAnswer((_) async {});
    when(
      () => store.agentReportIdsForTask(eventId),
    ).thenAnswer((_) async => {'report-1'});
  });

  Future<void> embed({bool withPipeline = true}) => embedAgentReport(
    embeddingStore: withPipeline ? store : null,
    embeddingRepository: withPipeline ? repository : null,
    journalDb: journalDb,
    reportId: 'report-1',
    reportContent: 'Pip and Skua skated across the frozen lake until dusk.',
    reportOneLiner: 'A picnic on the ice with Pip.',
    subjectId: eventId,
    logError: (message, {error, stackTrace}) => errors.add(message),
  );

  test('indexes the report under its subject, in its category', () async {
    await embed();

    final stored = verify(
      () => store.replaceEntityEmbeddings(
        entityId: 'report-1',
        entityType: kEntityTypeAgentReport,
        modelId: 'test-embedding-model',
        contentHash: any(named: 'contentHash'),
        embeddings: any(named: 'embeddings'),
        categoryId: captureAny(named: 'categoryId'),
        taskId: captureAny(named: 'taskId'),
        subtype: any(named: 'subtype'),
        register: any(named: 'register'),
      ),
    ).captured;
    // A hit on the recap resolves to the event it is about.
    expect(stored, ['category-outings', eventId]);
    final text =
        verify(
              () => repository.embedDocument(captureAny()),
            ).captured.single
            as String;
    expect(text, contains('A picnic on the ice with Pip.'));
    expect(text, contains('frozen lake'));
    expect(errors, isEmpty);
  });

  test('does nothing without the embedding pipeline', () async {
    await embed(withPipeline: false);

    verifyNever(() => journalDb.getConfigFlag(any()));
  });

  for (final (embeddingsOn, installed) in [(false, true), (true, false)]) {
    test(
      'embeds nothing while embeddings are ${embeddingsOn ? 'on' : 'off'} '
      'and the model is ${installed ? '' : 'not '}installed',
      () async {
        when(
          () => journalDb.getConfigFlag(enableEmbeddingsFlag),
        ).thenAnswer((_) async => embeddingsOn);
        when(repository.isInstalled).thenAnswer((_) async => installed);

        await embed();

        verifyNever(() => repository.embedDocument(any()));
      },
    );
  }

  test('a failure is logged, never thrown', () async {
    when(
      () => repository.embedDocument(any()),
    ).thenAnswer((_) async => throw StateError('runtime gone'));

    await embed();

    expect(errors, ['failed to embed agent report']);
  });
}
