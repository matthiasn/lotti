import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/query_chat_models.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task_document_merge.dart';
import 'package:lotti/features/agents/query/query_chat_providers.dart';
import 'package:lotti/features/agents/state/change_set_providers.dart';
import 'package:lotti/features/agents/state/unified_suggestion_providers.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/documents/state/document_review_providers.dart';
import 'package:lotti/features/documents/state/task_document_providers.dart';
import 'package:lotti/features/documents/ui/widgets/document_review_view.dart';
import 'package:lotti/features/documents/ui/widgets/review_block_row.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/domain/app_command_handler.dart';
import 'package:lotti/features/keyboard/ui/app_command_host.dart';
import 'package:lotti/providers/update_notifications_providers.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../classes/task_document_fixtures.dart';
import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../document_draft_fixtures.dart';

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
  const chatScope = QueryScope(kind: QueryScopeKind.task, id: taskId);

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

  late MockTaskDocumentRepository repository;
  late MockChangeSetConfirmationService service;
  late MockUpdateNotifications notifications;
  late List<PendingSuggestion> open;
  late TaskDocumentEntry? document;
  late int closed;
  late List<DocumentReviewKey> opened;
  late ProviderContainer container;

  setUp(() {
    repository = MockTaskDocumentRepository();
    service = MockChangeSetConfirmationService();
    notifications = MockUpdateNotifications();
    when(() => repository.version('version-1')).thenAnswer((_) async => v1);
    when(() => notifications.notify(any())).thenReturn(null);
    open = [documentDraft()];
    document = documentShowing(v1);
    closed = 0;
    opened = [];
  });

  /// Pumps the review of [reviewKey] in a pane [width] wide, and waits for
  /// its rows.
  Future<void> pump(WidgetTester tester, {double width = 1100}) async {
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
              reviewKey: reviewKey,
              title: 'Brief',
              onClose: () => closed++,
              onOpenDraft: opened.add,
            ),
          ),
        ),
        mediaQueryData: MediaQueryData(size: Size(width, 900)),
        overrides: [
          taskDocumentRepositoryProvider.overrideWithValue(repository),
          changeSetConfirmationServiceProvider.overrideWithValue(service),
          updateNotificationsProvider.overrideWithValue(notifications),
          queryChatEnabledProvider.overrideWithValue(true),
          unifiedSuggestionListProvider(taskId).overrideWith(
            (ref) async =>
                UnifiedSuggestionList(open: open, activity: const []),
          ),
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

  Future<void> reloadProposals(
    WidgetTester tester,
    List<PendingSuggestion> next,
  ) async {
    open = next;
    container.invalidate(unifiedSuggestionListProvider(taskId));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
  }

  String label(WidgetTester tester, Key key) =>
      tester.widget<DesignSystemButton>(find.byKey(key)).label;

  group('the gate', () {
    testWidgets('a pane wide enough for two columns shows the versions side '
        'by side under their heads', (tester) async {
      await pump(tester);

      expect(find.byKey(DocumentReviewViewKeys.columnHeads), findsOneWidget);
      expect(find.text('Current'), findsOneWidget);
      expect(find.text('Proposed'), findsOneWidget);
      final rows = tester.widgetList<ReviewBlockRow>(
        find.byType(ReviewBlockRow),
      );
      expect(rows, hasLength(4));
      expect(rows.every((row) => !row.stacked), isTrue);
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

  testWidgets("the header counts the changes and gives the agent's line on "
      'them', (tester) async {
    await pump(tester);

    expect(find.text('+1'), findsOneWidget);
    expect(find.text('~1'), findsOneWidget);
    expect(find.text('−0'), findsNothing);
    expect(
      find.bySemanticsLabel('1 added, 0 removed, 1 rewritten'),
      findsOneWidget,
    );
    expect(find.text('Feeds later, reports to the council.'), findsOneWidget);
  });

  group('the bar', () {
    testWidgets('Confirm names the version it makes, confirms the item '
        'through the shared service, and closes', (tester) async {
      when(() => service.confirmItem(any(), any())).thenAnswer(
        (_) async => const ToolExecutionResult(success: true, output: 'ok'),
      );
      await pump(tester);

      expect(label(tester, DocumentReviewViewKeys.confirm), 'Confirm v2');
      await tester.tap(find.byKey(DocumentReviewViewKeys.confirm));
      await tester.pump();

      final captured = verify(
        () => service.confirmItem(captureAny(), captureAny()),
      ).captured;
      expect((captured[0] as dynamic).id, 'cs-draft');
      expect(captured[1], 0);
      verify(() => notifications.notify(any())).called(1);
      expect(closed, 1);
    });

    testWidgets('a confirm that fails says so and keeps the review open', (
      tester,
    ) async {
      when(() => service.confirmItem(any(), any())).thenAnswer(
        (_) async => const ToolExecutionResult(success: false, output: 'no'),
      );
      await pump(tester);

      await tester.tap(find.byKey(DocumentReviewViewKeys.confirm));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Failed to apply change'), findsWidgets);
      expect(closed, 0);
      expect(
        tester
            .widget<DesignSystemButton>(
              find.byKey(DocumentReviewViewKeys.confirm),
            )
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('Discard draft rejects the item and closes', (tester) async {
      when(
        () => service.rejectItem(any(), any()),
      ).thenAnswer((_) async => true);
      await pump(tester);

      await tester.tap(find.byKey(DocumentReviewViewKeys.discard));
      await tester.pump();

      verify(() => service.rejectItem(any(), 0)).called(1);
      verifyNever(() => service.confirmItem(any(), any()));
      expect(closed, 1);
    });

    testWidgets('Ask for changes opens the task chat', (tester) async {
      await pump(tester);

      await tester.tap(find.byKey(DocumentReviewViewKeys.ask));
      await tester.pump();

      expect(container.read(queryPaneOpenProvider(chatScope)), isTrue);
      expect(closed, 0);
    });
  });

  testWidgets('a draft written over an older version cannot be confirmed; '
      'it offers asking the agent to redo it', (tester) async {
    document = documentShowing(v2);
    await pump(tester);

    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(DocumentReviewViewKeys.stale),
              matching: find.byType(Text),
            ),
          )
          .data,
      'Written against v1, current is v2',
    );
    expect(find.byKey(DocumentReviewViewKeys.confirm), findsNothing);
    expect(find.byKey(DocumentReviewViewKeys.ask), findsNothing);
    // Not "v2": that number is already the hand edit the draft is stale
    // against.
    expect(
      tester
          .widgetList<ReviewBlockRow>(find.byType(ReviewBlockRow))
          .map((row) => row.proposedVersion)
          .toSet(),
      {null},
    );
    expect(label(tester, DocumentReviewViewKeys.redo), 'Ask the agent to redo');

    await tester.tap(find.byKey(DocumentReviewViewKeys.redo));
    await tester.pump();

    expect(container.read(queryPaneOpenProvider(chatScope)), isTrue);
  });

  testWidgets('a newer draft is offered, and opening it reviews that one', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byKey(DocumentReviewViewKeys.newer), findsNothing);
    final createdAt = open.single.changeSet.createdAt;

    await reloadProposals(tester, [
      documentDraft(),
      documentDraft(
        setId: 'cs-newer',
        markdown: 'Something else entirely.',
        createdAt: createdAt.add(const Duration(minutes: 5)),
      ),
    ]);
    await tester.tap(find.text('Open the newer draft'));

    expect(opened, [
      (
        taskId: taskId,
        documentId: documentId,
        changeSetId: 'cs-newer',
        itemIndex: 0,
      ),
    ]);
    // The rows stay the ones the review opened with.
    expect(find.text('Feed the penguins at one.'), findsOneWidget);
  });

  testWidgets('closes once the draft is decided elsewhere', (tester) async {
    await pump(tester);

    await reloadProposals(tester, const []);

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
}
