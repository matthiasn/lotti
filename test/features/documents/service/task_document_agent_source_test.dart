import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task_document_data.dart';
import 'package:lotti/features/agents/model/task_document_source.dart';
import 'package:lotti/features/documents/repository/task_document_repository.dart';
import 'package:lotti/features/documents/service/task_document_agent_source.dart';

import '../../../helpers/fallbacks.dart';
import '../../../helpers/real_journal_persistence.dart';
import '../../../test_data/test_data.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  final harness = RealJournalPersistence();
  late TaskDocumentRepository repository;
  late TaskDocumentAgentSource source;
  final taskId = testTask.meta.id;

  setUp(() async {
    await harness.setUp();
    repository = TaskDocumentRepository(
      journalDb: harness.journalDb,
      persistenceLogic: harness.persistenceLogic,
      journalRepository: harness.journalRepository(),
    );
    source = TaskDocumentAgentSource(repository);
    await harness.persistenceLogic.createDbEntity(testTask);
  });

  tearDown(harness.tearDown);

  /// A document on the task with [text] as its first version, by the user.
  Future<({String documentId, String versionId})> documentWith(
    String text,
  ) async {
    final document = (await repository.create(
      taskId: taskId,
      title: 'Launch brief',
    ))!;
    final written = await repository.writeVersion(
      documentId: document.id,
      markdown: text,
      author: TaskDocumentAuthor.user,
      baseVersionId: null,
    );
    return (documentId: document.id, versionId: written.version!.id);
  }

  Future<TaskDocumentApplyOutcome> apply({
    String markdown = '# Brief, revised',
    String? documentId,
    String? newTitle,
    String? baseVersionId,
    String effectKey = 'change-set-1:0',
  }) => source.apply(
    taskId: taskId,
    markdown: markdown,
    documentId: documentId,
    newTitle: newTitle,
    baseVersionId: baseVersionId,
    changeSummary: 'Tightens the tone.',
    changeEffectKey: effectKey,
    documentUuidV5Input: 'change-effect:$effectKey:task-document',
    versionUuidV5Input: 'change-effect:$effectKey:task-document-version',
  );

  test(
    "lists the task's documents with the version each shows, and reads one "
    'only of this task',
    () async {
      final doc = await documentWith('# Brief');

      final summary = (await source.documentsOf(taskId)).single;
      expect(summary.id, doc.documentId);
      expect(summary.title, 'Launch brief');
      expect(summary.versionId, doc.versionId);
      expect(summary.versionNumber, 1);

      final text = await source.read(
        taskId: taskId,
        documentId: doc.documentId,
      );
      expect(text?.markdown, '# Brief');
      expect(
        await source.read(taskId: 'another-task', documentId: doc.documentId),
        isNull,
      );
    },
  );

  test(
    "writes the confirmed text as the agent's next version over its base, "
    'with its summary and provenance',
    () async {
      final doc = await documentWith('# Brief');

      final outcome = await apply(
        documentId: doc.documentId,
        baseVersionId: doc.versionId,
      );

      expect(outcome, isA<TaskDocumentApplied>());
      final current = (await repository.versions(doc.documentId)).first;
      expect((outcome as TaskDocumentApplied).versionId, current.id);
      expect(current.data.number, 2);
      expect(current.data.markdown, '# Brief, revised');
      expect(current.data.author, TaskDocumentAuthor.agent);
      expect(current.data.changeSummary, 'Tightens the tone.');
      expect(current.data.changeEffectKey, 'change-set-1:0');
    },
  );

  test(
    'applying the same confirmation twice writes one version, even after '
    'the first moved the document on',
    () async {
      final doc = await documentWith('# Brief');

      final first = await apply(
        documentId: doc.documentId,
        baseVersionId: doc.versionId,
      );
      final second = await apply(
        documentId: doc.documentId,
        baseVersionId: doc.versionId,
      );

      expect(
        (second as TaskDocumentApplied).versionId,
        (first as TaskDocumentApplied).versionId,
      );
      expect(await repository.versions(doc.documentId), hasLength(2));
    },
  );

  test(
    'a version drafted against an older version is refused for good, and '
    'nothing is written',
    () async {
      final doc = await documentWith('# Brief');
      await repository.writeVersion(
        documentId: doc.documentId,
        markdown: '# Brief, edited by hand',
        author: TaskDocumentAuthor.user,
        baseVersionId: doc.versionId,
      );

      final outcome = await apply(
        documentId: doc.documentId,
        baseVersionId: doc.versionId,
      );

      expect(outcome, isA<TaskDocumentApplyRefused>());
      expect((outcome as TaskDocumentApplyRefused).permanent, isTrue);
      expect(await repository.versions(doc.documentId), hasLength(2));
    },
  );

  test(
    'a new document is created with the text as its first version, once '
    'however often the confirmation applies',
    () async {
      final first = await apply(newTitle: '  Meeting summary  ');
      final second = await apply(newTitle: 'Meeting summary');

      final documents = await repository.forTask(taskId);
      expect(documents.single.data.title, 'Meeting summary');
      final versions = await repository.versions(documents.single.id);
      expect(versions.single.data.author, TaskDocumentAuthor.agent);
      expect(
        (second as TaskDocumentApplied).versionId,
        (first as TaskDocumentApplied).versionId,
      );
    },
  );

  test(
    'a document that is not on the task, or no document and no title, is '
    'refused for good',
    () async {
      final elsewhere = await apply(documentId: 'not-on-this-task');
      final neither = await apply();

      for (final outcome in [elsewhere, neither]) {
        expect(outcome, isA<TaskDocumentApplyRefused>());
        expect((outcome as TaskDocumentApplyRefused).permanent, isTrue);
      }
    },
  );
}
