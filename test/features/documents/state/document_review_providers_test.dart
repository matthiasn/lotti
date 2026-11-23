import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/change_set.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task_document_merge.dart';
import 'package:lotti/features/agents/state/unified_suggestion_providers.dart';
import 'package:lotti/features/documents/logic/markdown_block_diff.dart';
import 'package:lotti/features/documents/state/document_review_providers.dart';
import 'package:lotti/features/documents/state/task_document_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../classes/task_document_fixtures.dart';
import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../agents/test_data/change_set_factories.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  const taskId = 'task-1';
  const documentId = 'doc-brief';
  const docKey = (taskId: taskId, documentId: documentId);
  const reviewKey = (
    taskId: taskId,
    documentId: documentId,
    changeSetId: 'cs-draft',
    itemIndex: 0,
  );

  final v1 = taskDocumentVersionEntry(
    id: 'version-1',
    documentId: documentId,
    markdown: '# Brief\n\nFeed the penguins at noon.\n\nCount them at dusk.',
  );
  final v2 = taskDocumentVersionEntry(
    number: 2,
    id: 'version-2',
    documentId: documentId,
    markdown: 'Edited by hand.',
  );

  TaskDocumentEntry documentShowing(TaskDocumentVersionEntry version) =>
      taskDocumentEntry(clock: {'a': 1}, id: documentId, current: version.ref);

  PendingSuggestion draft({
    String setId = 'cs-draft',
    String document = documentId,
    String tool = 'propose_document_version',
    String? base = 'version-1',
    String markdown =
        '# Brief\n\nFeed the penguins at one.\n\nCount them at '
        'dusk.\n\nReport to the council.',
    DateTime? createdAt,
  }) {
    final set = makeTestChangeSet(
      id: setId,
      taskId: taskId,
      createdAt: createdAt,
      items: [
        ChangeItem(
          toolName: tool,
          args: {
            'documentId': document,
            'title': 'Brief',
            'baseVersionId': ?base,
            'markdown': markdown,
            'changeSummary': ' Feeds later, reports to the council. ',
          },
          humanSummary: 'New version of "Brief"',
        ),
      ],
    );
    return PendingSuggestion(
      changeSet: set,
      itemIndex: 0,
      item: set.items.single,
      fingerprint: 'fp-$setId',
    );
  }

  late MockTaskDocumentRepository repository;
  late List<PendingSuggestion> open;
  late TaskDocumentEntry? document;
  late ProviderContainer container;

  setUp(() {
    repository = MockTaskDocumentRepository();
    when(() => repository.version('version-1')).thenAnswer((_) async => v1);
    open = [draft()];
    document = documentShowing(v1);
    container = ProviderContainer(
      overrides: [
        taskDocumentRepositoryProvider.overrideWithValue(repository),
        unifiedSuggestionListProvider(taskId).overrideWith(
          (ref) async => UnifiedSuggestionList(open: open, activity: const []),
        ),
        taskDocumentProvider(docKey).overrideWith((ref) => document),
      ],
    );
    addTearDown(container.dispose);
  });

  /// Listens to [documentReviewProvider] and waits until it has a review.
  Future<DocumentReview> openReview() async {
    container.listen(documentReviewProvider(reviewKey), (_, _) {});
    for (var i = 0; i < 20; i++) {
      final review = container.read(documentReviewProvider(reviewKey));
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

  /// Reloads the task's proposals and lets the providers settle.
  Future<void> reloadProposals(List<PendingSuggestion> next) async {
    open = next;
    container.invalidate(unifiedSuggestionListProvider(taskId));
    await container.read(unifiedSuggestionListProvider(taskId).future);
    await settle();
  }

  group('pendingDocumentProposalsProvider', () {
    test('is null until the proposals load, then lists only this '
        "document's drafts", () async {
      open = [
        draft(),
        draft(setId: 'cs-other-doc', document: 'doc-other'),
        draft(setId: 'cs-title', tool: 'set_task_title'),
      ];
      container.listen(pendingDocumentProposalsProvider(docKey), (_, _) {});
      expect(container.read(pendingDocumentProposalsProvider(docKey)), isNull);

      await container.read(unifiedSuggestionListProvider(taskId).future);

      expect(
        container
            .read(pendingDocumentProposalsProvider(docKey))!
            .map((s) => s.changeSet.id),
        ['cs-draft'],
      );
    });
  });

  group('documentReviewProvider', () {
    test('aligns the draft against the version it was drafted over', () async {
      final review = await openReview();

      final snapshot = review.snapshot;
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
      expect(review.isStale, isFalse);
      expect(review.newerProposalAvailable, isFalse);
    });

    test('a draft over a document with no text is all additions', () async {
      open = [draft(base: null, markdown: 'One.\n\nTwo.')];
      document = taskDocumentEntry(clock: {'a': 1}, id: documentId);

      final review = await openReview();

      expect(review.snapshot.baseVersion, isNull);
      expect(review.snapshot.stats.added, 2);
      expect(review.isStale, isFalse);
      verifyNever(() => repository.version(any()));
    });

    test('a reload of the proposals keeps the pinned rows and reads '
        'nothing again', () async {
      final before = (await openReview()).snapshot;

      await reloadProposals([
        draft(),
        draft(setId: 'cs-title', tool: 'set_task_title'),
      ]);

      expect(
        identical(
          container.read(documentReviewProvider(reviewKey))!.snapshot,
          before,
        ),
        isTrue,
      );
      verify(() => repository.version('version-1')).called(1);
    });

    test('a version landing meanwhile marks the review stale and keeps its '
        'rows', () async {
      final before = (await openReview()).snapshot;

      document = documentShowing(v2);
      container.invalidate(taskDocumentProvider(docKey));
      await settle();

      final review = container.read(documentReviewProvider(reviewKey))!;
      expect(review.isStale, isTrue);
      expect(identical(review.snapshot, before), isTrue);
    });

    test('a newer draft of the same document is announced, not swapped '
        'in', () async {
      final before = (await openReview()).snapshot;

      await reloadProposals([
        draft(),
        draft(
          setId: 'cs-newer',
          markdown: 'Something else entirely.',
          createdAt: before.proposal.changeSet.createdAt.add(
            const Duration(minutes: 5),
          ),
        ),
      ]);

      final review = container.read(documentReviewProvider(reviewKey))!;
      expect(review.newerProposalAvailable, isTrue);
      expect(identical(review.snapshot, before), isTrue);
    });

    test('closes once the draft is no longer waiting — decided elsewhere or '
        'withdrawn', () async {
      await openReview();

      await reloadProposals(const []);

      expect(container.read(documentReviewProvider(reviewKey)), isNull);
    });
  });
}
