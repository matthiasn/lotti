import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/empty_states/design_system_empty_state.dart';
import 'package:lotti/features/design_system/components/navigation/resizable_divider.dart';
import 'package:lotti/features/design_system/state/pane_width_controller.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/journal/ui/pages/entry_details_page.dart';
import 'package:lotti/features/journal/ui/pages/infinite_journal_page.dart';
import 'package:lotti/features/journal/ui/pages/journal_root_page.dart';
import 'package:lotti/features/keyboard/ui/list_detail_focus_traversal.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../test_utils/fake_journal_page_controller.dart';
import '../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeJournalPageController fakeController;
  late ValueNotifier<String?> selectedEntryId;

  setUp(() async {
    selectedEntryId = ValueNotifier<String?>(null);
    // Auto-select beams `/journal/<id>` rather than writing the notifier
    // directly (the URL is the single source of truth). In production
    // `JournalLocation.buildPages` then derives the selection from that route;
    // here there is no Beamer, so the override stands in for that round-trip so
    // the tests still assert auto-select lands on the right entry.
    beamToNamedOverride = (path) {
      selectedEntryId.value = path.split('/').last;
    };
    await setUpTestGetIt(
      additionalSetup: () {
        final mockUserActivityService = MockUserActivityService();
        when(mockUserActivityService.updateActivity).thenReturn(null);
        getIt.registerSingleton<UserActivityService>(mockUserActivityService);
        final mockNavService = MockNavService();
        when(() => mockNavService.isDesktopMode).thenReturn(false);
        // Auto-select reads currentPath to skip re-beaming an already-current
        // route; a non-entry path keeps the guard open so the beam proceeds.
        when(() => mockNavService.currentPath).thenReturn('/journal');
        when(
          () => mockNavService.desktopSelectedEntryId,
        ).thenReturn(selectedEntryId);
        // Feed rows render through ModernJournalCard, whose task variant
        // resolves the recording indicator through TimeService.
        final mockTimeService = MockTimeService();
        when(() => mockTimeService.linkedFrom).thenReturn(null);
        when(
          mockTimeService.getStream,
        ).thenAnswer((_) => Stream<JournalEntity?>.value(null));
        final mockEntitiesCacheService = MockEntitiesCacheService();
        when(
          () => mockEntitiesCacheService.getCategoryById(any()),
        ).thenReturn(null);
        getIt
          ..registerSingleton<NavService>(mockNavService)
          ..registerSingleton<TimeService>(mockTimeService)
          ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService);
      },
    );
  });

  tearDown(() async {
    beamToNamedOverride = null;
    await tearDownTestGetIt();
    selectedEntryId.dispose();
  });

  JournalPageState state() => const JournalPageState();

  Future<void> pumpRootPage(
    WidgetTester tester, {
    Size? size,
  }) async {
    fakeController = FakeJournalPageController(state());
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const JournalRootPage(),
        mediaQueryData: size != null ? MediaQueryData(size: size) : null,
        overrides: [
          journalPageScopeProvider.overrideWithValue(false),
          journalPageControllerProvider(
            false,
          ).overrideWith(() => fakeController),
        ],
      ),
    );
    await tester.pump();
  }

  const desktop = Size(1280, 800);

  testWidgets('below the breakpoint renders the list only', (tester) async {
    await pumpRootPage(tester);

    expect(find.byType(InfiniteJournalPage), findsOneWidget);
    // No desktop split chrome on mobile.
    expect(find.byType(ResizableDivider), findsNothing);
    expect(find.byType(ListDetailFocusTraversal), findsNothing);
    expect(find.byType(DesignSystemEmptyState), findsNothing);
  });

  testWidgets('desktop with no selection shows the split with an empty '
      'detail pane', (tester) async {
    await pumpRootPage(tester, size: desktop);

    expect(find.byType(InfiniteJournalPage), findsOneWidget);
    expect(find.byType(ListDetailFocusTraversal), findsOneWidget);
    expect(find.byType(ResizableDivider), findsOneWidget);
    final emptyState = tester.widget<DesignSystemEmptyState>(
      find.byType(DesignSystemEmptyState),
    );
    // Reachable only when the feed is empty (auto-select fills the pane
    // otherwise). The list pane owns the "logbook is empty" message + CTA, so
    // this pane defers with a quiet forward-pointing hint and the logbook's
    // own glyph — never a "select something" instruction.
    expect(emptyState.hint, 'New entries will open here.');
    expect(emptyState.title, isNull);
    expect(emptyState.icon, Icons.menu_book_outlined);
    expect(find.text('New entries will open here.'), findsOneWidget);
    // The list pane is sized by the journal-specific width, not the
    // tasks/projects one.
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SizedBox && widget.width == defaultJournalListPaneWidth,
      ),
      findsOneWidget,
    );
  });

  testWidgets('selecting an entry swaps the empty state for the details '
      'without a back button', (tester) async {
    selectedEntryId.value = 'entry-42';
    await pumpRootPage(tester, size: desktop);

    expect(find.byType(DesignSystemEmptyState), findsNothing);
    final detailsPage = tester.widget<EntryDetailsPage>(
      find.byType(EntryDetailsPage),
    );
    expect(detailsPage.itemId, 'entry-42');
    // The list stays on screen beside the details, so no back affordance,
    // and the list pane already owns the create FAB.
    expect(detailsPage.showBackButton, isFalse);
    expect(detailsPage.showFloatingActionButton, isFalse);

    // Dispose the tree and flush pending animation timers.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('changing the selection crossfades between detail pages', (
    tester,
  ) async {
    selectedEntryId.value = 'entry-a';
    await pumpRootPage(tester, size: desktop);

    expect(
      tester.widget<EntryDetailsPage>(find.byType(EntryDetailsPage)).itemId,
      'entry-a',
    );

    selectedEntryId.value = 'entry-b';
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Mid-fade both pages coexist; the outgoing one must not hold focus.
    expect(find.byType(EntryDetailsPage), findsNWidgets(2));
    final outgoing = find.ancestor(
      of: find.byWidgetPredicate(
        (widget) => widget is EntryDetailsPage && widget.itemId == 'entry-a',
      ),
      matching: find.byType(ExcludeFocus),
    );
    expect(
      tester
          .widgetList<ExcludeFocus>(outgoing)
          .where((guard) => guard.excluding),
      hasLength(1),
    );

    // After the fade completes only the new entry remains.
    await tester.pump(journalDetailSwitchDuration);
    expect(find.byType(EntryDetailsPage), findsOneWidget);
    expect(
      tester.widget<EntryDetailsPage>(find.byType(EntryDetailsPage)).itemId,
      'entry-b',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('clearing the selection returns to the empty state', (
    tester,
  ) async {
    selectedEntryId.value = 'entry-a';
    await pumpRootPage(tester, size: desktop);
    expect(find.byType(EntryDetailsPage), findsOneWidget);

    selectedEntryId.value = null;
    await tester.pump();
    await tester.pump(journalDetailSwitchDuration);
    // One more clock-advancing frame: the switcher reaps the faded-out child
    // on the frame after its animation completes.
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.byType(EntryDetailsPage), findsNothing);
    expect(find.byType(DesignSystemEmptyState), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  group('auto-select newest entry', () {
    PagingController<int, JournalEntity> pagingControllerWith(
      List<JournalEntity> items,
    ) {
      final controller =
          PagingController<int, JournalEntity>(
              getNextPageKey: (_) => null,
              fetchPage: (_) async => const <JournalEntity>[],
            )
            ..value = PagingState(
              pages: [items],
              keys: const [0],
              hasNextPage: false,
            );
      addTearDown(controller.dispose);
      return controller;
    }

    Future<void> pumpWithFeed(
      WidgetTester tester,
      List<JournalEntity> items,
    ) async {
      fakeController = FakeJournalPageController(
        JournalPageState(pagingController: pagingControllerWith(items)),
      );
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const JournalRootPage(),
          mediaQueryData: const MediaQueryData(size: desktop),
          overrides: [
            journalPageScopeProvider.overrideWithValue(false),
            journalPageControllerProvider(
              false,
            ).overrideWith(() => fakeController),
          ],
        ),
      );
      // First frame builds; the post-frame callback then writes the notifier;
      // one more pump renders the resulting selection.
      await tester.pump();
      await tester.pump();
    }

    testWidgets(
      'with no selection, the newest non-task entry fills the pane',
      (tester) async {
        await pumpWithFeed(tester, [testTask, testTextEntry]);

        // The task is skipped (it opens in the Tasks tab); the newest
        // selectable entry is auto-selected with zero taps.
        expect(selectedEntryId.value, testTextEntry.meta.id);
        // Let the empty state finish cross-fading out (plus the reap frame).
        await tester.pump(journalDetailSwitchDuration);
        await tester.pump(const Duration(milliseconds: 16));
        expect(find.byType(DesignSystemEmptyState), findsNothing);
        expect(
          tester.widget<EntryDetailsPage>(find.byType(EntryDetailsPage)).itemId,
          testTextEntry.meta.id,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );

    testWidgets('an existing selection is never overridden', (tester) async {
      selectedEntryId.value = 'chosen-entry';
      await pumpWithFeed(tester, [testTextEntry]);

      expect(selectedEntryId.value, 'chosen-entry');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });

    testWidgets(
      'a feed with only tasks/events keeps the empty state',
      (tester) async {
        await pumpWithFeed(tester, [testTask]);

        expect(selectedEntryId.value, isNull);
        expect(find.byType(DesignSystemEmptyState), findsOneWidget);
      },
    );

    testWidgets(
      'clearing the selection re-fills it with the newest entry',
      (tester) async {
        await pumpWithFeed(tester, [testTextEntry]);
        expect(selectedEntryId.value, testTextEntry.meta.id);

        // A bare /journal beam clears the notifier; the fallback restores it.
        selectedEntryId.value = null;
        await tester.pump();
        await tester.pump();
        expect(selectedEntryId.value, testTextEntry.meta.id);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('dragging the divider resizes the journal list pane through '
      'the controller', (tester) async {
    await pumpRootPage(tester, size: desktop);

    double listPaneWidth() => tester
        .widget<SizedBox>(
          find.ancestor(
            of: find.byType(InfiniteJournalPage),
            matching: find.byType(SizedBox),
          ),
        )
        .width!;

    final before = listPaneWidth();
    expect(before, defaultJournalListPaneWidth);

    await tester.drag(find.byType(ResizableDivider), const Offset(60, 0));
    await tester.pump();

    // The delta lands in paneWidthControllerProvider's journal width, not the
    // shared tasks/projects width — the pane resizes by exactly the drag.
    expect(listPaneWidth(), before + 60);
  });
}
