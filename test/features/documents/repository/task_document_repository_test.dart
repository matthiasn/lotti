import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task_document_data.dart';
import 'package:lotti/features/documents/repository/task_document_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../helpers/real_journal_persistence.dart';
import '../../../test_data/test_data.dart';

/// A [PersistenceLogic] that runs [afterVersionCreated] once, right after a
/// version row is stored — the window between storing a version and
/// pointing its document at it, where another write can land.
class _RacingPersistenceLogic extends PersistenceLogic {
  _RacingPersistenceLogic() : super(services: buildPersistenceServices());

  Future<void> Function()? afterVersionCreated;

  @override
  Future<bool?> createDbEntity(
    JournalEntity journalEntity, {
    bool shouldAddGeolocation = true,
    bool enqueueSync = true,
    String? linkedId,
    bool linkCollapsed = false,
  }) async {
    final created = await super.createDbEntity(
      journalEntity,
      shouldAddGeolocation: shouldAddGeolocation,
      enqueueSync: enqueueSync,
      linkedId: linkedId,
      linkCollapsed: linkCollapsed,
    );
    final hook = afterVersionCreated;
    if (journalEntity is TaskDocumentVersionEntry && hook != null) {
      afterVersionCreated = null;
      await hook();
    }
    return created;
  }
}

void main() {
  setUpAll(registerAllFallbackValues);

  final harness = RealJournalPersistence();
  late _RacingPersistenceLogic persistence;
  late TaskDocumentRepository repository;
  final taskId = testTask.meta.id;

  setUp(() async {
    await harness.setUp(
      persistenceLogic: () => persistence = _RacingPersistenceLogic(),
    );
    repository = TaskDocumentRepository(
      journalDb: harness.journalDb,
      persistenceLogic: persistence,
      journalRepository: harness.journalRepository(),
    );
    await persistence.createDbEntity(
      testTask.copyWith(
        meta: testTask.meta.copyWith(categoryId: 'colony', private: true),
      ),
    );
  });

  tearDown(harness.tearDown);

  Future<TaskDocumentEntry> created({
    String title = 'Client one-pager',
  }) async => (await repository.create(taskId: taskId, title: title))!;

  Future<TaskDocumentVersionEntry> written(
    TaskDocumentEntry document,
    String markdown, {
    String? base,
  }) async {
    final result = await repository.writeVersion(
      documentId: document.id,
      markdown: markdown,
      author: TaskDocumentAuthor.user,
      baseVersionId: base,
    );
    expect(result.status, TaskDocumentWriteStatus.written);
    return result.version!;
  }

  group('create', () {
    test(
      'links the document from its task, in the task category and with its '
      'private flag, with no version yet',
      () async {
        final document = await created();

        final linked = await harness.journalDb.getLinkedEntities(taskId);
        expect(linked.map((e) => e.id), contains(document.id));
        final stored = await repository.document(document.id);
        expect(stored?.data.title, 'Client one-pager');
        expect(stored?.data.current, isNull);
        expect(stored?.meta.categoryId, 'colony');
        expect(stored?.meta.private, isTrue);
        expect(await repository.currentVersion(stored!), isNull);
      },
    );

    test('creates nothing for a task that does not exist', () async {
      expect(
        await repository.create(taskId: 'no-such-task', title: 'Notes'),
        isNull,
      );
    });
  });

  group('derived ids', () {
    test(
      'a creation with a derived id happens once, and a document deleted '
      'since is not brought back',
      () async {
        final first = await repository.create(
          taskId: taskId,
          title: 'Brief',
          uuidV5Input: 'change-effect:set:0:task-document',
        );
        final second = await repository.create(
          taskId: taskId,
          title: 'Brief',
          uuidV5Input: 'change-effect:set:0:task-document',
        );
        expect(second?.id, first!.id);
        expect(await repository.forTask(taskId), hasLength(1));

        await repository.delete(first.id);
        expect(
          await repository.create(
            taskId: taskId,
            title: 'Brief',
            uuidV5Input: 'change-effect:set:0:task-document',
          ),
          isNull,
        );
        expect(await repository.forTask(taskId), isEmpty);
      },
    );

    test(
      'a version with a derived id is written once: applied again, even '
      'after it moved the document on, it is found and nothing is written',
      () async {
        final document = await created();
        Future<TaskDocumentWriteResult> write() => repository.writeVersion(
          documentId: document.id,
          markdown: 'one',
          author: TaskDocumentAuthor.agent,
          baseVersionId: null,
          uuidV5Input: 'change-effect:set:0:task-document-version',
        );

        final first = await write();
        clearInteractions(harness.outboxService);
        final second = await write();

        expect(second.status, TaskDocumentWriteStatus.written);
        expect(second.version?.id, first.version!.id);
        expect(await repository.versions(document.id), hasLength(1));
        verifyNever(() => harness.outboxService.enqueueMessage(any()));
      },
    );
  });

  group('forTask', () {
    test(
      "lists the task's live documents oldest first, and nothing else it "
      'links',
      () async {
        final first = await created(title: 'One-pager');
        final second = await created(title: 'Meeting summary');
        final third = await created(title: 'Follow-up email');
        await repository.delete(second.id);
        await persistence.createDbEntity(testTextEntry, linkedId: taskId);

        final documents = await repository.forTask(taskId);

        expect(documents.map((d) => d.id), [first.id, third.id]);
      },
    );
  });

  group('version', () {
    test('reads any version by id, not only the one on show', () async {
      final document = await created();
      final first = await written(document, 'The first draft.');
      await written(document, 'The second draft.', base: first.id);

      expect(
        (await repository.version(first.id))?.data.markdown,
        'The first draft.',
      );
    });

    test('is null for an id that names no version', () async {
      final document = await created();
      expect(await repository.version('no-such-version'), isNull);
      // A document is not a version.
      expect(await repository.version(document.id), isNull);
    });
  });

  group('writeVersion', () {
    test(
      'writes a first version and points the document at it, with its '
      'author and provenance',
      () async {
        final document = await created();

        final result = await repository.writeVersion(
          documentId: document.id,
          markdown: '# Next steps',
          author: TaskDocumentAuthor.agent,
          baseVersionId: null,
          changeSummary: 'First draft from the voice note.',
          changeEffectKey: 'change-set-1:0',
        );

        expect(result.status, TaskDocumentWriteStatus.written);
        final version = result.version!;
        expect(version.data.number, 1);
        expect(version.data.author, TaskDocumentAuthor.agent);
        expect(version.data.changeEffectKey, 'change-set-1:0');
        expect(version.meta.categoryId, 'colony');
        final stored = await repository.document(document.id);
        expect(stored?.data.current?.id, version.id);
        expect(
          (await repository.currentVersion(stored!))?.data.markdown,
          '# Next steps',
        );
      },
    );

    test(
      'numbers each version one past the one it was written over, and lists '
      'them newest first',
      () async {
        final document = await created();
        final v1 = await written(document, 'one');
        final v2 = await written(document, 'two', base: v1.id);

        expect(v2.data.number, 2);
        expect(v2.data.baseVersionId, v1.id);
        expect(
          (await repository.versions(document.id)).map((v) => v.id),
          [v2.id, v1.id],
        );
      },
    );

    test(
      'refuses a text written over a version the document no longer shows, '
      'and stores and syncs nothing',
      () async {
        final document = await created();
        final v1 = await written(document, 'one');
        final v2 = await written(document, 'two', base: v1.id);
        clearInteractions(harness.outboxService);

        final stale = await repository.writeVersion(
          documentId: document.id,
          markdown: 'edited from v1',
          author: TaskDocumentAuthor.user,
          baseVersionId: v1.id,
        );

        expect(stale.status, TaskDocumentWriteStatus.stale);
        expect(stale.version, isNull);
        // Refused before anything is written: no version row is created and
        // deleted again, which would send both to every other device.
        verifyNever(() => harness.outboxService.enqueueMessage(any()));
        expect((await repository.versions(document.id)).length, 2);
        expect(
          (await repository.document(document.id))?.data.current?.id,
          v2.id,
        );
      },
    );

    test(
      'when the document moves on while the version is being stored, the '
      'write comes back stale and its row is deleted, so history holds only '
      'versions the document showed',
      () async {
        final document = await created();
        final v1 = await written(document, 'one');
        late TaskDocumentVersionEntry landedMeanwhile;
        persistence.afterVersionCreated = () async {
          landedMeanwhile = await written(document, 'theirs', base: v1.id);
        };

        final mine = await repository.writeVersion(
          documentId: document.id,
          markdown: 'mine',
          author: TaskDocumentAuthor.user,
          baseVersionId: v1.id,
        );

        expect(mine.status, TaskDocumentWriteStatus.stale);
        expect(
          (await repository.document(document.id))?.data.current?.id,
          landedMeanwhile.id,
        );
        expect(
          (await repository.versions(document.id)).map((v) => v.data.markdown),
          ['theirs', 'one'],
        );
      },
    );

    test('reports a document that does not exist as missing', () async {
      final result = await repository.writeVersion(
        documentId: 'no-such-document',
        markdown: 'text',
        author: TaskDocumentAuthor.user,
        baseVersionId: null,
      );

      expect(result.status, TaskDocumentWriteStatus.missing);
    });

    test(
      'reports a document deleted while the version was being stored as '
      'missing, and deletes the version row',
      () async {
        final document = await created();
        persistence.afterVersionCreated = () async {
          await harness.journalRepository().deleteJournalEntity(document.id);
        };

        final result = await repository.writeVersion(
          documentId: document.id,
          markdown: 'text',
          author: TaskDocumentAuthor.user,
          baseVersionId: null,
        );

        expect(result.status, TaskDocumentWriteStatus.missing);
        expect(await repository.versions(document.id), isEmpty);
      },
    );
  });

  group('restore', () {
    test(
      'writes the older text as a new version by the user, so history stays '
      'whole',
      () async {
        final document = await created();
        final v1 = await written(document, 'one');
        final v2 = await written(document, 'two', base: v1.id);

        final restored = await repository.restore(
          versionId: v1.id,
          baseVersionId: v2.id,
        );

        expect(restored.status, TaskDocumentWriteStatus.written);
        expect(restored.version?.data.number, 3);
        expect(restored.version?.data.markdown, 'one');
        expect(restored.version?.data.author, TaskDocumentAuthor.user);
        expect(restored.version?.data.restoredFromVersionId, v1.id);
        expect((await repository.versions(document.id)).length, 3);
      },
    );

    test('reports a version that does not exist as missing', () async {
      final result = await repository.restore(
        versionId: 'no-such-version',
        baseVersionId: null,
      );

      expect(result.status, TaskDocumentWriteStatus.missing);
    });
  });

  group('rename', () {
    test('renames the document and keeps the version it shows', () async {
      final document = await created();
      final v1 = await written(document, 'one');

      expect(await repository.rename(document.id, 'Meeting summary'), isTrue);

      final stored = await repository.document(document.id);
      expect(stored?.data.title, 'Meeting summary');
      expect(stored?.data.current?.id, v1.id);
    });

    test('renames nothing that does not exist', () async {
      expect(await repository.rename('no-such-document', 'Notes'), isFalse);
    });
  });

  group('delete', () {
    test('deletes the document and every version of it', () async {
      final document = await created();
      final v1 = await written(document, 'one');
      await written(document, 'two', base: v1.id);

      expect(await repository.delete(document.id), isTrue);

      expect(await repository.document(document.id), isNull);
      expect(await repository.versions(document.id), isEmpty);
      expect(await repository.forTask(taskId), isEmpty);
    });
  });
}
