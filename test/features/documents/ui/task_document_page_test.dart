import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/query_chat_models.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task_document_data.dart';
import 'package:lotti/classes/task_document_merge.dart';
import 'package:lotti/features/agents/query/query_chat_providers.dart';
import 'package:lotti/features/agents/ui/query/query_companion.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/documents/state/document_review_providers.dart';
import 'package:lotti/features/documents/state/task_document_providers.dart';
import 'package:lotti/features/documents/ui/task_document_editor.dart';
import 'package:lotti/features/documents/ui/task_document_history.dart';
import 'package:lotti/features/documents/ui/task_document_page.dart';
import 'package:lotti/features/documents/ui/widgets/document_review_view.dart';
import 'package:lotti/features/journal/ui/pages/entry_details_page.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart' show BackWidget;
import 'package:lotti/widgets/modal/confirmation_modal.dart';
import 'package:mocktail/mocktail.dart';

import '../../../classes/task_document_fixtures.dart';
import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  const key = (taskId: 'task-1', documentId: 'doc-brief');
  late MockTaskDocumentRepository repository;

  final first = taskDocumentVersionEntry(
    id: 'version-1',
    documentId: 'doc-brief',
    markdown: '# Launch brief\n\nAll 36 penguins present.',
  );
  // The agent's version, written over the first.
  final version = taskDocumentVersionEntry(
    number: 2,
    id: 'version-2',
    documentId: 'doc-brief',
    markdown: '# Launch brief\n\nAll 37 penguins present.',
    author: TaskDocumentAuthor.agent,
    baseVersionId: 'version-1',
  );
  // The same text as the user's own, for a page with nothing to announce.
  final byHand = version.copyWith(
    data: version.data.copyWith(author: TaskDocumentAuthor.user),
  );
  final document = taskDocumentEntry(
    clock: {'a': 1},
    id: 'doc-brief',
    title: 'Launch brief for Mission Control',
    current: version.ref,
  );
  final empty = taskDocumentEntry(
    clock: {'a': 1},
    id: 'doc-brief',
    title: 'Roll-call summary',
  );

  setUp(() {
    repository = MockTaskDocumentRepository();
    when(() => repository.delete(any())).thenAnswer((_) async => true);
    when(() => repository.document(any())).thenAnswer((_) async => document);
    when(
      () => repository.currentVersion(document),
    ).thenAnswer((_) async => version);
    when(() => repository.version(any())).thenAnswer((_) async => null);
    when(
      () => repository.version('version-1'),
    ).thenAnswer((_) async => first);
    when(
      () => repository.version('version-2'),
    ).thenAnswer((_) async => version);
  });

  Future<void> pump(
    WidgetTester tester, {
    TaskDocumentEntry? shown,
    bool gone = false,
    bool loading = false,
    VoidCallback? onClose,
    bool chat = false,
    DocumentReviewKey? initialReview,
    VoidCallback? onInitialReviewOpened,
    TaskDocumentVersionEntry? current,
    bool pushed = false,
  }) async {
    final doc = gone || loading ? null : (shown ?? document);
    final page = TaskDocumentPage(
      taskId: key.taskId,
      documentId: key.documentId,
      onClose: onClose,
      initialReview: initialReview,
      onInitialReviewOpened: onInitialReviewOpened,
    );
    await withClock(
      Clock.fixed(taskDocFixtureEpoch.add(const Duration(hours: 2))),
      () async {
        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            // Pushed: a launcher under the page, which it was pushed from.
            pushed
                ? Builder(
                    builder: (context) => TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => page),
                      ),
                      child: const Text('Open the document'),
                    ),
                  )
                : page,
            overrides: [
              taskDocumentRepositoryProvider.overrideWithValue(repository),
              taskDocumentProvider(key).overrideWith((ref) => doc),
              taskDocumentGoneProvider(key).overrideWith((ref) => gone),
              taskDocumentCurrentVersionProvider(key).overrideWith(
                (ref) async =>
                    doc?.data.current == null ? null : (current ?? version),
              ),
              taskDocumentVersionsProvider(key).overrideWith(
                (ref) async => [version],
              ),
              queryChatEnabledProvider.overrideWithValue(chat),
            ],
          ),
        );
        await tester.pump();
      },
    );
  }

  bool enabled(WidgetTester tester, Key key) =>
      tester.widget<DesignSystemButton>(find.byKey(key)).onPressed != null;

  testWidgets(
    'shows the title, where the version came from and its rendered text',
    (tester) async {
      await pump(tester);

      expect(find.text('Launch brief for Mission Control'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(TaskDocumentPageKeys.provenance)).data,
        'v2 · Written by the agent · 2 h ago',
      );
      expect(find.text('All 37 penguins present.'), findsOneWidget);
      expect(enabled(tester, TaskDocumentPageKeys.copy), isTrue);
      expect(enabled(tester, TaskDocumentPageKeys.history), isTrue);
    },
  );

  testWidgets(
    'a document with no text yet says so, and has nothing to copy or look '
    'back on',
    (tester) async {
      await pump(tester, shown: empty);

      expect(find.text('No text yet'), findsOneWidget);
      expect(find.byKey(TaskDocumentPageKeys.provenance), findsNothing);
      expect(enabled(tester, TaskDocumentPageKeys.copy), isFalse);
      expect(enabled(tester, TaskDocumentPageKeys.history), isFalse);
      expect(enabled(tester, TaskDocumentPageKeys.edit), isTrue);
    },
  );

  testWidgets('a document deleted while open says so', (tester) async {
    await pump(tester, gone: true);

    expect(find.text('This document was deleted.'), findsOneWidget);
    expect(find.byKey(TaskDocumentPageKeys.edit), findsNothing);
  });

  testWidgets('a document not read yet is not called deleted: the page '
      'shows nothing of it until it is', (tester) async {
    await pump(tester, loading: true);

    expect(find.text('This document was deleted.'), findsNothing);
    expect(find.byKey(TaskDocumentPageKeys.edit), findsNothing);
    expect(find.byType(BackWidget), findsOneWidget);
  });

  testWidgets('Edit opens the editor on this document', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(TaskDocumentPageKeys.edit));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final editor = tester.widget<TaskDocumentEditor>(
      find.byType(TaskDocumentEditor),
    );
    expect(editor.document, document);
    expect(editor.taskId, key.taskId);
  });

  testWidgets('Copy puts the version on show on the clipboard', (
    tester,
  ) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pump(tester);

    await tester.tap(find.byKey(TaskDocumentPageKeys.copy));
    await tester.pump();

    expect(copied, ['# Launch brief\n\nAll 37 penguins present.']);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('History lists the versions', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(TaskDocumentPageKeys.history));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(TaskDocumentHistory), findsOneWidget);
    expect(find.byKey(TaskDocumentHistoryKeys.current), findsOneWidget);
  });

  testWidgets(
    'Delete asks first; confirmed, it deletes the document and leaves the '
    'page',
    (tester) async {
      var closed = 0;
      await pump(tester, onClose: () => closed++);

      await tester.tap(find.byKey(TaskDocumentPageKeys.delete));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(confirmationModalKey), findsOneWidget);
      expect(find.text('Delete this document?'), findsOneWidget);

      await tester.tap(find.text('Delete').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      verify(() => repository.delete('doc-brief')).called(1);
      expect(closed, 1);
    },
  );

  testWidgets('pushed without onClose, a confirmed delete pops back to '
      'where the page was opened from', (tester) async {
    await pump(tester, pushed: true);
    await tester.tap(find.text('Open the document'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(TaskDocumentPageKeys.delete));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    verify(() => repository.delete('doc-brief')).called(1);
    expect(find.byType(TaskDocumentPage), findsNothing);
    expect(find.text('Open the document'), findsOneWidget);
  });

  testWidgets('Delete cancelled deletes nothing and stays', (tester) async {
    var closed = 0;
    await pump(tester, onClose: () => closed++);

    await tester.tap(find.byKey(TaskDocumentPageKeys.delete));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    verifyNever(() => repository.delete(any()));
    expect(closed, 0);
  });

  testWidgets('the back arrow leaves through onClose when given', (
    tester,
  ) async {
    var closed = 0;
    await pump(tester, onClose: () => closed++);

    await tester.tap(find.byType(BackWidget));
    await tester.pump();

    expect(closed, 1);
  });

  testWidgets('pushed without onClose, the back arrow pops back to where it '
      'was opened from', (tester) async {
    await pump(tester, pushed: true);
    await tester.tap(find.text('Open the document'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskDocumentPage), findsOneWidget);

    await tester.tap(find.byType(BackWidget));
    await tester.pumpAndSettle();

    expect(find.byType(TaskDocumentPage), findsNothing);
    expect(find.text('Open the document'), findsOneWidget);
  });

  testWidgets("the task's chat opens an entry as its details page, without "
      'a back button of its own', (tester) async {
    await pump(tester, chat: true);

    final entry = tester
        .widget<QueryCompanion>(find.byType(QueryCompanion))
        .entryViewBuilder('entry-7');

    expect(entry, isA<EntryDetailsPage>());
    expect((entry as EntryDetailsPage).itemId, 'entry-7');
    expect(entry.showBackButton, isFalse);
  });

  testWidgets('without chat there is nothing to ask', (tester) async {
    await pump(tester);
    expect(find.text('Ask about this task'), findsNothing);
  });

  testWidgets("Ask opens the task's own chat beside the document", (
    tester,
  ) async {
    await pump(tester, chat: true);
    const scope = QueryScope(kind: QueryScopeKind.task, id: 'task-1');
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TaskDocumentPage)),
    );
    expect(container.read(queryPaneOpenProvider(scope)), isFalse);

    await tester.tap(find.text('Ask about this task'));
    // Only the open state is under test; the pane itself is QueryCompanion's.
    expect(container.read(queryPaneOpenProvider(scope)), isTrue);
    expect(
      tester.widget<QueryCompanion>(find.byType(QueryCompanion)).scope,
      scope,
    );
  });

  group("reviewing the agent's version", () {
    const reviewKey = (
      taskId: 'task-1',
      documentId: 'doc-brief',
      versionId: 'version-2',
    );

    testWidgets('a version the user wrote is not announced', (tester) async {
      await pump(tester, current: byHand);

      expect(find.byKey(TaskDocumentPageKeys.review), findsNothing);
      expect(find.text('The agent wrote this version'), findsNothing);
    });

    testWidgets('a document with no text has nothing to announce', (
      tester,
    ) async {
      await pump(tester, shown: empty);

      expect(find.byKey(TaskDocumentPageKeys.review), findsNothing);
    });

    testWidgets("the notice lays the agent's version beside the one before "
        'it, and closing the review returns to reading', (tester) async {
      await pump(tester);

      expect(find.text('The agent wrote this version'), findsOneWidget);
      await tester.tap(find.byKey(TaskDocumentPageKeys.review));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final review = tester.widget<DocumentReviewView>(
        find.byType(DocumentReviewView),
      );
      expect(review.reviewKey, reviewKey);
      expect(review.title, 'Launch brief for Mission Control');
      expect(find.byKey(TaskDocumentPageKeys.edit), findsNothing);

      await tester.tap(find.byKey(DocumentReviewViewKeys.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(DocumentReviewView), findsNothing);
      expect(find.byKey(TaskDocumentPageKeys.edit), findsOneWidget);
    });

    testWidgets('nothing waits for a decision: Edit stays the filled button '
        'and Review changes sits quiet beside it', (tester) async {
      await pump(tester);

      expect(
        tester
            .widget<DesignSystemButton>(find.byKey(TaskDocumentPageKeys.edit))
            .variant,
        DesignSystemButtonVariant.primary,
      );
      expect(
        tester
            .widget<DesignSystemButton>(find.byKey(TaskDocumentPageKeys.review))
            .variant,
        DesignSystemButtonVariant.secondary,
      );
    });

    testWidgets('a review left open on a document deleted meanwhile is '
        'over: the page says the document is gone, and the review is '
        'cleared', (tester) async {
      await pump(tester, gone: true);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TaskDocumentPage)),
      );
      container
          .read(documentReviewOpenProvider('task-1').notifier)
          .open(reviewKey);
      await tester.pump();
      await tester.pump();

      expect(find.byType(DocumentReviewView), findsNothing);
      expect(find.text('This document was deleted.'), findsOneWidget);
      expect(container.read(documentReviewOpenProvider('task-1')), isNull);
    });

    testWidgets('a version handed in by the review route stays asked for '
        'while its document is still being read', (tester) async {
      await pump(tester, loading: true, initialReview: reviewKey);
      await tester.pump();
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(TaskDocumentPage)),
      );
      expect(container.read(documentReviewOpenProvider('task-1')), reviewKey);
      expect(find.text('This document was deleted.'), findsNothing);
    });

    testWidgets('a version handed in by the review route opens as the page '
        'appears, and the route hears so', (tester) async {
      var heard = 0;
      await pump(
        tester,
        initialReview: reviewKey,
        onInitialReviewOpened: () => heard++,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(DocumentReviewView), findsOneWidget);
      expect(heard, 1);
    });

    testWidgets("a version of another document is not this page's to open", (
      tester,
    ) async {
      var heard = 0;
      await pump(
        tester,
        initialReview: (
          taskId: 'task-1',
          documentId: 'doc-other',
          versionId: 'version-2',
        ),
        onInitialReviewOpened: () => heard++,
      );
      await tester.pump();

      expect(find.byType(DocumentReviewView), findsNothing);
      expect(heard, 0);
    });

    testWidgets('while reviewing, back closes the review onto the text '
        'instead of leaving the page', (tester) async {
      var left = 0;
      await pump(
        tester,
        initialReview: reviewKey,
        onClose: () => left++,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(DocumentReviewView), findsOneWidget);
      expect(
        tester.widget<PopScope<void>>(find.byType(PopScope<void>)).canPop,
        isFalse,
      );

      await tester.tap(find.byType(BackWidget));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(DocumentReviewView), findsNothing);
      expect(left, 0);
      expect(
        tester.widget<PopScope<void>>(find.byType(PopScope<void>)).canPop,
        isTrue,
      );
    });

    testWidgets('while reviewing, the system back closes the review too, and '
        'the page stays', (tester) async {
      var left = 0;
      await pump(
        tester,
        initialReview: reviewKey,
        onClose: () => left++,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(DocumentReviewView), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(DocumentReviewView), findsNothing);
      expect(find.byType(TaskDocumentPage), findsOneWidget);
      expect(left, 0);
    });
  });
}
