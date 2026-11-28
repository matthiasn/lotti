import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/query_chat_models.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task_document_data.dart';
import 'package:lotti/classes/task_document_merge.dart';
import 'package:lotti/features/agents/query/query_chat_providers.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/documents/logic/markdown_block_diff.dart';
import 'package:lotti/features/documents/repository/task_document_repository.dart';
import 'package:lotti/features/documents/state/task_document_providers.dart';
import 'package:lotti/features/documents/ui/widgets/document_review_view.dart';
import 'package:lotti/features/documents/ui/widgets/review_block_row.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/domain/app_command_handler.dart';
import 'package:lotti/features/keyboard/ui/app_command_host.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../classes/task_document_fixtures.dart';
import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  const taskId = 'task-1';
  const documentId = 'doc-brief';
  const docKey = (taskId: taskId, documentId: documentId);
  const chatScope = QueryScope(kind: QueryScopeKind.task, id: taskId);

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
    changeSummary: 'Feeds later, reports to the council.',
    markdown:
        '# Brief\n\nFeed the penguins at one.\n\nCount them at '
        'dusk.\n\nReport to the council.',
  );
  final v3 = taskDocumentVersionEntry(
    number: 3,
    id: 'version-3',
    documentId: documentId,
    baseVersionId: 'version-2',
    changeSummary: 'Shortened by hand.',
    markdown: '# Brief\n\nFeed the penguins at one.',
  );

  TaskDocumentEntry documentShowing(TaskDocumentVersionEntry version) =>
      taskDocumentEntry(clock: {'a': 1}, id: documentId, current: version.ref);

  late MockTaskDocumentRepository repository;
  late TaskDocumentEntry? document;
  late bool chatEnabled;
  late int closed;
  late ProviderContainer container;

  setUp(() {
    repository = MockTaskDocumentRepository();
    when(() => repository.version(any())).thenAnswer((_) async => null);
    for (final version in [v1, v2, v3]) {
      when(
        () => repository.version(version.id),
      ).thenAnswer((_) async => version);
    }
    document = documentShowing(v2);
    chatEnabled = true;
    closed = 0;
  });

  /// Pumps the review of version [versionId] in a pane [width] wide, and
  /// waits for its rows.
  Future<void> pump(
    WidgetTester tester, {
    double width = 1100,
    String versionId = 'version-2',
  }) async {
    tester.view
      ..physicalSize = Size(width, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        // The document page's own Scaffold, which the toasts present on.
        Scaffold(
          body: AppCommandHost(
            handlers: const <AppCommandId, AppCommandHandler>{},
            platform: TargetPlatform.macOS,
            child: DocumentReviewView(
              reviewKey: (
                taskId: taskId,
                documentId: documentId,
                versionId: versionId,
              ),
              title: 'Brief',
              onClose: () => closed++,
            ),
          ),
        ),
        mediaQueryData: MediaQueryData(size: Size(width, 900)),
        overrides: [
          taskDocumentRepositoryProvider.overrideWithValue(repository),
          queryChatEnabledProvider.overrideWithValue(chatEnabled),
          taskDocumentProvider(docKey).overrideWith((ref) => document),
        ],
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    container = ProviderScope.containerOf(
      tester.element(find.byType(DocumentReviewView)),
    );
  }

  /// Makes the document show [version], as a write landing meanwhile would.
  Future<void> moveTo(
    WidgetTester tester,
    TaskDocumentVersionEntry version,
  ) async {
    document = documentShowing(version);
    container.invalidate(taskDocumentProvider(docKey));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
  }

  void stubRestore(TaskDocumentWriteStatus status) {
    when(
      () => repository.restore(
        versionId: any(named: 'versionId'),
        baseVersionId: any(named: 'baseVersionId'),
      ),
    ).thenAnswer((_) async => (status: status, version: null));
  }

  DesignSystemButton button(WidgetTester tester, Key key) =>
      tester.widget<DesignSystemButton>(find.byKey(key));

  group('the gate', () {
    testWidgets('a pane wide enough for two columns shows the versions side '
        'by side under their heads, each naming its version', (tester) async {
      await pump(tester);

      final heads = find.byKey(DocumentReviewViewKeys.columnHeads);
      expect(heads, findsOneWidget);
      expect(
        find.descendant(of: heads, matching: find.text('Before')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: heads, matching: find.text('After')),
        findsOneWidget,
      );
      expect(
        tester
            .widgetList<DsPill>(
              find.descendant(of: heads, matching: find.byType(DsPill)),
            )
            .map((pill) => pill.label),
        ['v1', 'v2'],
      );
      final rows = tester.widgetList<ReviewBlockRow>(
        find.byType(ReviewBlockRow),
      );
      // The leading "# Brief" only repeats the title the header shows.
      expect(rows, hasLength(3));
      expect(rows.first.pair.kind, MarkdownBlockChange.rewritten);
      expect(rows.every((row) => !row.stacked), isTrue);
      expect(
        rows.every((row) => row.baseVersion == 1 && row.version == 2),
        isTrue,
      );
    });

    testWidgets('flips to one column at the measured width, not a window '
        'breakpoint', (tester) async {
      await pump(tester);
      final tokens = tester
          .element(find.byType(DocumentReviewView))
          .designTokens;
      // The review's own gutters, then exactly the width two columns need.
      final fits =
          documentReviewSideBySideMinWidth(tokens) + 2 * tokens.spacing.step5;

      await pump(tester, width: fits);
      expect(find.byKey(DocumentReviewViewKeys.columnHeads), findsOneWidget);

      await pump(tester, width: fits - 1);
      expect(find.byKey(DocumentReviewViewKeys.columnHeads), findsNothing);
      expect(
        tester
            .widgetList<ReviewBlockRow>(find.byType(ReviewBlockRow))
            .every((row) => row.stacked),
        isTrue,
      );
    });
  });

  testWidgets('the header says which version this is and who wrote it, '
      "gives the agent's line on it under its spark, and counts the changes", (
    tester,
  ) async {
    await pump(tester);

    expect(
      tester.widget<Text>(find.byKey(DocumentReviewViewKeys.provenance)).data,
      startsWith('v2 · Written by the agent · '),
    );
    expect(find.text('Feeds later, reports to the council.'), findsOneWidget);
    // Tags for the kinds there are, each with the gutter's own mark.
    expect(
      tester
          .widgetList<DsPill>(
            find.descendant(
              of: find.byType(ExcludeSemantics),
              matching: find.byType(DsPill),
            ),
          )
          .map((pill) => ((pill.leading! as Icon).icon, pill.label)),
      [(LottiIcons.add, '1'), (LottiIcons.compare, '1')],
    );
    expect(
      find.bySemanticsLabel('1 added, 0 removed, 1 rewritten'),
      findsOneWidget,
    );
    // The agent's version wears its spark: on its summary and its head.
    expect(find.byIcon(LottiIcons.aiSpark), findsNWidgets(2));
  });

  testWidgets('a version the user wrote carries no spark: its line is plain '
      'and its head neutral', (tester) async {
    document = documentShowing(v3);
    await pump(tester, versionId: 'version-3');

    expect(
      tester.widget<Text>(find.byKey(DocumentReviewViewKeys.provenance)).data,
      startsWith('v3 · Written by you · '),
    );
    expect(find.text('Shortened by hand.'), findsOneWidget);
    expect(find.byIcon(LottiIcons.aiSpark), findsNothing);
    expect(
      tester
          .widgetList<ReviewBlockRow>(find.byType(ReviewBlockRow))
          .every((row) => !row.byAgent),
      isTrue,
    );
  });

  group('the bar', () {
    testWidgets('Go back names the version it lands on, restores it over '
        'the reviewed one, says so and closes', (tester) async {
      stubRestore(TaskDocumentWriteStatus.written);
      await pump(tester);

      final undo = button(tester, DocumentReviewViewKeys.undo);
      expect(undo.label, 'Go back to v1');
      // Beside Ask for changes it is the quiet one.
      expect(undo.variant, DesignSystemButtonVariant.quiet);

      await tester.tap(find.byKey(DocumentReviewViewKeys.undo));
      await tester.pump();
      await tester.pump();

      verify(
        () => repository.restore(
          versionId: 'version-1',
          baseVersionId: 'version-2',
        ),
      ).called(1);
      expect(find.text('Version restored'), findsOneWidget);
      expect(closed, 1);
    });

    for (final (status, message) in [
      (
        TaskDocumentWriteStatus.stale,
        'A newer version arrived meanwhile. Look at it, then restore again.',
      ),
      (TaskDocumentWriteStatus.failed, "That didn't save — please try again."),
      (TaskDocumentWriteStatus.missing, "That didn't save — please try again."),
    ]) {
      testWidgets('a restore that comes back ${status.name} says so and '
          'keeps the review open', (tester) async {
        stubRestore(status);
        await pump(tester);

        await tester.tap(find.byKey(DocumentReviewViewKeys.undo));
        await tester.pump();
        await tester.pump();

        expect(find.text(message), findsOneWidget);
        expect(closed, 0);
        // The button is live again for another try.
        expect(
          button(tester, DocumentReviewViewKeys.undo).onPressed,
          isNotNull,
        );
      });
    }

    testWidgets('once another version landed there is nothing to go back '
        'from: the rows stay and Go back leaves', (tester) async {
      await pump(tester);
      expect(find.byKey(DocumentReviewViewKeys.undo), findsOneWidget);

      await moveTo(tester, v3);

      expect(find.byKey(DocumentReviewViewKeys.undo), findsNothing);
      expect(find.byType(ReviewBlockRow), findsNWidgets(3));
      expect(find.byKey(DocumentReviewViewKeys.ask), findsOneWidget);
      expect(closed, 0);
    });

    testWidgets('a first version has no version to go back to', (
      tester,
    ) async {
      document = documentShowing(v1);
      await pump(tester, versionId: 'version-1');

      expect(find.byKey(DocumentReviewViewKeys.undo), findsNothing);
      // The left column has nothing: the document had no text.
      expect(find.text('No text yet'), findsWidgets);
    });

    testWidgets('Ask for changes is the filled button and opens the task '
        'chat', (tester) async {
      await pump(tester);

      expect(
        button(tester, DocumentReviewViewKeys.ask).variant,
        DesignSystemButtonVariant.primary,
      );
      await tester.tap(find.byKey(DocumentReviewViewKeys.ask));
      await tester.pump();

      expect(container.read(queryPaneOpenProvider(chatScope)), isTrue);
      expect(closed, 0);
    });

    testWidgets('without the task chat, Go back is the one action, filled; '
        'with neither there is no bar', (tester) async {
      chatEnabled = false;
      await pump(tester);

      expect(find.byKey(DocumentReviewViewKeys.ask), findsNothing);
      expect(
        button(tester, DocumentReviewViewKeys.undo).variant,
        DesignSystemButtonVariant.primary,
      );

      await moveTo(tester, v3);

      expect(find.byKey(DocumentReviewViewKeys.undo), findsNothing);
      expect(find.byType(DesignSystemButton), findsOneWidget); // Close review
    });
  });

  testWidgets('a key that names no version of the document closes the '
      'review, showing nothing', (tester) async {
    await pump(tester, versionId: 'version-missing');

    expect(find.byType(ReviewBlockRow), findsNothing);
    expect(closed, 1);
  });

  testWidgets('Close review and Escape both close', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(DocumentReviewViewKeys.close));
    expect(closed, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(closed, 2);
  });

  testWidgets('a version that rewrites the title keeps its title row', (
    tester,
  ) async {
    final retitled = taskDocumentVersionEntry(
      number: 2,
      id: 'version-retitled',
      documentId: documentId,
      baseVersionId: 'version-1',
      markdown:
          '# Penguin brief\n\nFeed the penguins at noon.\n\nCount them at '
          'dusk.',
    );
    when(
      () => repository.version('version-retitled'),
    ).thenAnswer((_) async => retitled);
    document = documentShowing(retitled);
    await pump(tester, versionId: 'version-retitled');

    expect(
      tester
          .widgetList<ReviewBlockRow>(find.byType(ReviewBlockRow))
          .first
          .pair
          .kind,
      MarkdownBlockChange.rewritten,
    );
    expect(find.textContaining('Penguin brief'), findsOneWidget);
  });

  testWidgets('the column heads are pinned over the rows', (tester) async {
    await pump(tester);

    expect(
      find.ancestor(
        of: find.byKey(DocumentReviewViewKeys.columnHeads),
        matching: find.byType(PinnedHeaderSliver),
      ),
      findsOneWidget,
    );
  });

  testWidgets('on a narrow pane Close review is an icon, its label the '
      'tooltip, and the bar keeps both actions', (tester) async {
    await pump(tester, width: 400);

    expect(
      find.descendant(
        of: find.byKey(DocumentReviewViewKeys.close),
        matching: find.byTooltip('Close review'),
      ),
      findsOneWidget,
    );
    for (final key in [
      DocumentReviewViewKeys.undo,
      DocumentReviewViewKeys.ask,
    ]) {
      expect(button(tester, key).size, DesignSystemButtonSize.medium);
    }
    await tester.tap(find.byKey(DocumentReviewViewKeys.close));
    expect(closed, 1);
  });

  testWidgets('the rows are found by their index key, which is their '
      'identity while the review is open', (tester) async {
    await pump(tester);

    final delegate =
        tester.widget<SliverList>(find.byType(SliverList)).delegate
            as SliverChildBuilderDelegate;
    expect(delegate.findChildIndexCallback!(const ValueKey<int>(2)), 2);
    expect(delegate.findChildIndexCallback!(const ValueKey('row')), isNull);
  });
}
