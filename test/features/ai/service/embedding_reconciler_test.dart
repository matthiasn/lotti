import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/features/ai/database/embedding_register.dart';
import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/service/embedding_content_extractor.dart';
import 'package:lotti/features/ai/service/embedding_processor.dart';
import 'package:lotti/features/ai/service/embedding_reconciler.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../helpers/in_memory_embedding_store.dart';
import '../../../mocks/mocks.dart';

const _model = 'embeddinggemma-300m-q4';
final _date = DateTime.utc(2026, 11, 2);

String _hash(String text) => EmbeddingContentExtractor.contentHash(text);

Metadata _meta(String id, {List<String>? labelIds, bool deleted = false}) =>
    Metadata(
      id: id,
      createdAt: _date,
      updatedAt: _date,
      dateFrom: _date,
      dateTo: _date,
      labelIds: labelIds,
      deletedAt: deleted ? _date : null,
    );

JournalEntry _entry(String id, String text, {bool deleted = false}) =>
    JournalEntry(
      meta: _meta(id, deleted: deleted),
      entryText: EntryText(plainText: text),
    );

Task _task(
  String id,
  String title, {
  List<String> labelIds = const [],
  bool deleted = false,
}) => Task(
  meta: _meta(id, labelIds: labelIds, deleted: deleted),
  data: TaskData(
    status: TaskStatus.open(id: 's', createdAt: _date, utcOffset: 0),
    title: title,
    statusHistory: const [],
    dateFrom: _date,
    dateTo: _date,
  ),
);

LabelDefinition _label(String id, String name, {bool private = false}) =>
    LabelDefinition(
      id: id,
      createdAt: _date,
      updatedAt: _date,
      name: name,
      color: '#000000',
      vectorClock: null,
      private: private,
    );

void main() {
  late InMemoryEmbeddingStore store;
  late MockJournalDb journalDb;

  /// This device's journal, deleted rows included.
  late Map<String, JournalEntity> rows;
  late List<LabelDefinition> labels;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    store = InMemoryEmbeddingStore();
    rows = {};
    labels = [];
    journalDb = MockJournalDb();
    when(
      () => journalDb.getJournalEntitiesForIdsIncludingDeleted(any()),
    ).thenAnswer(
      (i) async => [
        for (final id in i.positionalArguments.first as Set<String>) ?rows[id],
      ],
    );
    when(
      journalDb.getAllLabelDefinitionsIncludingPrivate,
    ).thenAnswer((_) async => labels);
  });

  tearDown(() => EmbeddingProcessor.share = null);

  EmbeddingReconciler reconciler({int batchSize = 500}) => EmbeddingReconciler(
    store: store,
    journalDb: journalDb,
    modelId: _model,
    batchSize: batchSize,
  );

  /// Stores live vectors of [entityId] embedded from [text].
  void stored(
    String entityId,
    String text, {
    String entityType = kEntityTypeJournalText,
    String taskId = '',
    String model = _model,
  }) => store.replaceEntityEmbeddings(
    entityId: entityId,
    entityType: entityType,
    modelId: model,
    contentHash: _hash(text),
    embeddings: [Float32List(kEmbeddingDimensions)],
    taskId: taskId,
    register: EmbeddingRegister(
      entityId: entityId,
      modelId: model,
      entityType: entityType,
      contentHash: _hash(text),
      vectorClock: const VectorClock({'host-a': 1}),
      taskId: taskId,
      originatingHostId: 'host-a',
    ),
  );

  group('entriesToReprocess', () {
    test(
      'lists the entries whose stored vectors no longer match them, and '
      'nothing else',
      () async {
        const text = 'A journal entry long enough to embed';
        // Matches: left alone.
        rows['same'] = _entry('same', text);
        stored('same', text);
        // Deleted here.
        rows['deleted'] = _entry('deleted', text, deleted: true);
        stored('deleted', text);
        // No row at all — a journal restored from an older backup, say —
        // is never taken for deleted.
        stored('absent', text);
        // Now under the minimum length.
        rows['short'] = _entry('short', 'Too short');
        stored('short', text);
        // A live version without its chunks.
        rows['chunkless'] = _entry('chunkless', text);
        store.putRegister(
          EmbeddingRegister(
            entityId: 'chunkless',
            modelId: _model,
            entityType: kEntityTypeJournalText,
            contentHash: _hash(text),
            vectorClock: const VectorClock({'host-a': 1}),
          ),
        );
        // A label renamed since the task was embedded: same task clock,
        // different text.
        labels.add(_label('l1', 'renamed'));
        rows['relabelled'] = _task(
          'relabelled',
          'Plan the team offsite',
          labelIds: const ['l1'],
        );
        stored(
          'relabelled',
          'Plan the team offsite\nLabels: old name',
          entityType: kEntityTypeTask,
        );
        // A private label's name counts, whatever the privacy toggle says:
        // embedded with it, the task matches; embedded without it (as a
        // device hiding private items once did), it does not.
        labels.add(_label('lp', 'personal', private: true));
        rows['private'] = _task(
          'private',
          'Book the dentist appointment',
          labelIds: const ['lp'],
        );
        stored(
          'private',
          'Book the dentist appointment\nLabels: personal',
          entityType: kEntityTypeTask,
        );
        rows['hidden'] = _task(
          'hidden',
          'Call the insurance company back',
          labelIds: const ['lp'],
        );
        stored(
          'hidden',
          'Call the insurance company back',
          entityType: kEntityTypeTask,
        );
        // Not journal vectors of this model: a tombstone, a report, another
        // model's.
        rows['tombstoned'] = _entry('tombstoned', text, deleted: true);
        store.writeTombstone(
          const EmbeddingRegister(
            entityId: 'tombstoned',
            modelId: _model,
            entityType: kEntityTypeJournalText,
            contentHash: '',
            deleted: true,
          ),
        );
        stored('report', text, entityType: kEntityTypeAgentReport);
        stored('other-model', text, model: 'retired-model');

        expect(await reconciler().entriesToReprocess(), {
          'deleted',
          'short',
          'chunkless',
          'relabelled',
          'hidden',
        });
      },
    );

    test(
      'reads the journal in batches, and not at all without vectors',
      () async {
        expect(await reconciler(batchSize: 2).entriesToReprocess(), isEmpty);
        verifyNever(
          () => journalDb.getJournalEntitiesForIdsIncludingDeleted(any()),
        );
        verifyNever(journalDb.getAllLabelDefinitionsIncludingPrivate);

        const text = 'A journal entry long enough to embed';
        for (final id in ['a', 'b', 'c']) {
          rows[id] = _entry(id, text);
          stored(id, text);
        }

        expect(await reconciler(batchSize: 2).entriesToReprocess(), isEmpty);
        verify(
          () => journalDb.getJournalEntitiesForIdsIncludingDeleted(any()),
        ).called(2);
      },
    );
  });

  group('retireReportsOfDeletedTasks', () {
    test(
      'tombstones the report vectors whose task is deleted here, and keeps '
      'the rest',
      () async {
        final share = MockEmbeddingShare();
        final ticket = MockEmbeddingVersionTicket();
        when(
          () => ticket.vectorClock,
        ).thenReturn(const VectorClock({'host-b': 5}));
        when(() => ticket.hostId).thenReturn('host-b');
        when(() => ticket.send(any(), any())).thenAnswer((_) async {});
        when(
          () => share.reserve(
            registerId: any(named: 'registerId'),
            previous: any(named: 'previous'),
          ),
        ).thenAnswer((_) async => ticket);
        EmbeddingProcessor.share = share;

        const text = 'What the agent says about the task';
        rows['task-live'] = _task('task-live', 'A task that is still here');
        rows['task-deleted'] = _task(
          'task-deleted',
          'A task deleted on this device',
          deleted: true,
        );
        void report(String id, String taskId) => stored(
          id,
          text,
          entityType: kEntityTypeAgentReport,
          taskId: taskId,
        );
        report('r-kept', 'task-live');
        report('r-deleted', 'task-deleted');
        // A task with no row here is unknown, not deleted.
        report('r-absent', 'task-absent');
        // Journal vectors are not this pass's business.
        rows['entry'] = _entry('entry', text, deleted: true);
        stored('entry', text);

        expect(await reconciler().retireReportsOfDeletedTasks(), 1);

        expect(
          store.chunks.keys,
          unorderedEquals(['r-kept', 'r-absent', 'entry']),
        );
        final tombstone = store.registers['r-deleted']!;
        expect(tombstone.deleted, isTrue);
        expect(tombstone.taskId, 'task-deleted');
        expect(tombstone.vectorClock, const VectorClock({'host-b': 5}));
        verify(() => ticket.send(tombstone, const [])).called(1);
        verify(
          () => share.reserve(
            registerId: 'r-deleted|$_model',
            previous: const VectorClock({'host-a': 1}),
          ),
        ).called(1);
      },
    );

    test('reads nothing without report vectors', () async {
      expect(await reconciler().retireReportsOfDeletedTasks(), 0);
      verifyNever(
        () => journalDb.getJournalEntitiesForIdsIncludingDeleted(any()),
      );
    });
  });
}
