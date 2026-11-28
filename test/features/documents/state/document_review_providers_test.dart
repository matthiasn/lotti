import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task_document_data.dart';
import 'package:lotti/classes/task_document_merge.dart';
import 'package:lotti/features/documents/logic/markdown_block_diff.dart';
import 'package:lotti/features/documents/state/document_review_providers.dart';
import 'package:lotti/features/documents/state/task_document_providers.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../classes/task_document_fixtures.dart';
import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  const taskId = 'task-1';
  const documentId = 'doc-brief';
  const docKey = (taskId: taskId, documentId: documentId);
  const reviewKey = (
    taskId: taskId,
    documentId: documentId,
    versionId: 'version-2',
  );

  final v1 = taskDocumentVersionEntry(
    id: 'version-1',
    documentId: documentId,
    markdown: '# Brief\n\nFeed the penguins at noon.\n\nCount them at dusk.',
  );
  // The agent's version, written over v1.
  final v2 = taskDocumentVersionEntry(
    number: 2,
    id: 'version-2',
    documentId: documentId,
    author: TaskDocumentAuthor.agent,
    baseVersionId: 'version-1',
    changeSummary: ' Feeds later, reports to the council. ',
    markdown:
        '# Brief\n\nFeed the penguins at one.\n\nCount them at '
        'dusk.\n\nReport to the council.',
  );
  final v3 = taskDocumentVersionEntry(
    number: 3,
    id: 'version-3',
    documentId: documentId,
    baseVersionId: 'version-2',
    markdown: 'Edited by hand.',
  );

  TaskDocumentEntry documentShowing(TaskDocumentVersionEntry version) =>
      taskDocumentEntry(clock: {'a': 1}, id: documentId, current: version.ref);

  late MockTaskDocumentRepository repository;
  late TaskDocumentEntry? document;
  late ProviderContainer container;

  setUp(() {
    repository = MockTaskDocumentRepository();
    when(() => repository.version(any())).thenAnswer((_) async => null);
    when(() => repository.version('version-1')).thenAnswer((_) async => v1);
    when(() => repository.version('version-2')).thenAnswer((_) async => v2);
    document = documentShowing(v2);
    container = ProviderContainer(
      overrides: [
        taskDocumentRepositoryProvider.overrideWithValue(repository),
        taskDocumentProvider(docKey).overrideWith((ref) => document),
      ],
    );
    addTearDown(container.dispose);
  });

  /// Listens to [documentReviewProvider] for [key] and waits until it has a
  /// review.
  Future<DocumentReview> openReview([DocumentReviewKey key = reviewKey]) async {
    container.listen(documentReviewProvider(key), (_, _) {});
    for (var i = 0; i < 20; i++) {
      final review = container.read(documentReviewProvider(key));
      if (review != null) return review;
      await Future<void>.value();
    }
    fail('the review never opened');
  }

  /// Lets Riverpod run the rebuilds it scheduled, and their futures finish.
  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await container.pump();
      await Future<void>.value();
    }
  }

  group('documentReviewProvider', () {
    test('aligns the version against the one it was written over', () async {
      final review = await openReview();

      final snapshot = review.snapshot;
      expect(snapshot.version, v2);
      expect(snapshot.baseVersion, v1);
      expect(snapshot.changeSummary, 'Feeds later, reports to the council.');
      expect(snapshot.pairs.map((pair) => pair.kind), [
        MarkdownBlockChange.same,
        MarkdownBlockChange.rewritten,
        MarkdownBlockChange.same,
        MarkdownBlockChange.added,
      ]);
      expect(
        snapshot.stats,
        const MarkdownBlockDiffStats(added: 1, removed: 0, rewritten: 1),
      );
      expect(review.isCurrent, isTrue);
    });

    test('a first version is all additions, with no line on what it changes '
        'when it carries none', () async {
      final first = taskDocumentVersionEntry(
        id: 'version-first',
        documentId: documentId,
        markdown: 'One.\n\nTwo.',
        changeSummary: '  ',
      );
      when(
        () => repository.version('version-first'),
      ).thenAnswer((_) async => first);

      final review = await openReview((
        taskId: taskId,
        documentId: documentId,
        versionId: 'version-first',
      ));

      expect(review.snapshot.baseVersion, isNull);
      expect(review.snapshot.stats.added, 2);
      expect(review.snapshot.changeSummary, isNull);
      // Only the version itself was read: it names no base.
      verify(() => repository.version('version-first')).called(1);
      verifyNever(() => repository.version('version-1'));
    });

    test('a version landing meanwhile takes "current" away and keeps the '
        'rows: neither version is read again', () async {
      final before = await openReview();
      clearInteractions(repository);

      document = documentShowing(v3);
      container.invalidate(taskDocumentProvider(docKey));
      await settle();

      final after = container.read(documentReviewProvider(reviewKey))!;
      expect(after.isCurrent, isFalse);
      expect(identical(after.snapshot, before.snapshot), isTrue);
      verifyNever(() => repository.version(any()));
    });

    test('is null for a version that does not exist, and for one of another '
        'document', () async {
      final other = taskDocumentVersionEntry(
        id: 'version-other',
        documentId: 'doc-other',
      );
      when(
        () => repository.version('version-other'),
      ).thenAnswer((_) async => other);

      for (final versionId in ['version-missing', 'version-other']) {
        final key = (
          taskId: taskId,
          documentId: documentId,
          versionId: versionId,
        );
        container.listen(documentReviewProvider(key), (_, _) {});
        final snapshot = await container.read(
          documentReviewSnapshotProvider(key).future,
        );
        expect(snapshot, isNull, reason: versionId);
        expect(container.read(documentReviewProvider(key)), isNull);
      }
    });
  });

  group('documentReviewShowingProvider', () {
    late ValueNotifier<({String taskId, String documentId})?> shown;
    late MockNavService nav;

    setUp(() {
      shown = ValueNotifier(null);
      addTearDown(shown.dispose);
      nav = MockNavService();
      when(() => nav.desktopTaskDocument).thenReturn(shown);
      container = ProviderContainer(
        overrides: [navServiceProvider.overrideWithValue(nav)],
      );
      addTearDown(container.dispose);
      container.listen(documentReviewShowingProvider(taskId), (_, _) {});
    });

    bool showing() => container.read(documentReviewShowingProvider(taskId));

    test('is true only while a review is open and its document is the one '
        'the pane shows', () async {
      final review = container.read(
        documentReviewOpenProvider(taskId).notifier,
      );
      expect(showing(), isFalse);
      // Nothing open: the pane is not even looked at.
      verifyNever(() => nav.desktopTaskDocument);

      review.open(reviewKey);
      expect(showing(), isFalse);

      shown.value = docKey;
      expect(showing(), isTrue);

      shown.value = (taskId: taskId, documentId: 'doc-other');
      expect(showing(), isFalse);

      shown.value = docKey;
      review.close();
      expect(showing(), isFalse);
    });

    test("another task's review does not count", () {
      container.read(documentReviewOpenProvider('task-other').notifier).open((
        taskId: 'task-other',
        documentId: documentId,
        versionId: 'version-2',
      ));
      shown.value = docKey;

      expect(showing(), isFalse);
    });
  });
}
