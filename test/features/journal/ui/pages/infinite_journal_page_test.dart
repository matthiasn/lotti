// ignore_for_file: avoid_redundant_argument_values

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/design_system/components/headers/tab_section_header.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/journal/ui/pages/infinite_journal_page.dart';
import 'package:lotti/features/journal/ui/widgets/create/create_entry_action_button.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/card_wrapper_widget.dart';
import 'package:lotti/features/journal/ui/widgets/logbook_filter_modal.dart';
import 'package:lotti/features/journal/ui/widgets/logbook_search_mode_row.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/features/journal/utils/entry_types.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/ui/app_command_controller.dart';
import 'package:lotti/features/keyboard/ui/app_command_host.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../helpers/path_provider.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../test_utils/fake_journal_page_controller.dart';
import '../../../../utils/utils.dart';
import '../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var mockJournalDb = MockJournalDb();
  final mockSettingsDb = MockSettingsDb();
  var mockPersistenceLogic = MockPersistenceLogic();
  final mockEntitiesCacheService = MockEntitiesCacheService();
  final mockUpdateNotifications = MockUpdateNotifications();

  final entryTypeStrings = entryTypes.toList();

  group('JournalPage Widget Tests - ', () {
    setUpAll(() async {
      setFakeDocumentsPath();
      ensureMpvInitialized();

      registerFallbackValue(FakeMeasurementData());
      // Avoid GoogleFonts attempting network fetches during tests
      GoogleFonts.config.allowRuntimeFetching = false;
    });

    setUp(() async {
      // Ensure a clean service locator before each test in this file
      await getIt.reset();
      mockJournalDb = mockJournalDbWithMeasurableTypes([
        measurableWater,
        measurableChocolate,
      ]);

      when(mockJournalDb.getJournalCount).thenAnswer((_) async => 1);

      mockPersistenceLogic = MockPersistenceLogic();

      final mockTimeService = MockTimeService();
      final mockNavService = MockNavService();
      // The journal page controller subscribes to the nav-index stream
      // to drain deferred refreshes when the tab becomes active. Stub
      // the stream to a no-op broadcast and pin the index getters so
      // build() resolves without throwing.
      when(() => mockNavService.tasksIndex).thenReturn(0);
      when(() => mockNavService.journalIndex).thenReturn(5);
      when(() => mockNavService.index).thenReturn(5);
      when(
        mockNavService.getIndexStream,
      ).thenAnswer((_) => const Stream<int>.empty());

      when(() => mockJournalDb.watchConfigFlag(privateFlag)).thenAnswer(
        (_) => Stream<bool>.fromIterable([true]),
      );
      when(mockJournalDb.watchActiveConfigFlagNames).thenAnswer(
        (_) => Stream<Set<String>>.fromIterable([<String>{}]),
      );

      when(
        () => mockSettingsDb.itemByKey(any()),
      ).thenAnswer((_) => Future(() => null));
      when(
        () => mockSettingsDb.saveSettingsItem(any(), any()),
      ).thenAnswer((_) async => 1);

      when(mockJournalDb.getTasksCount).thenAnswer((_) async => 42);

      // Add default implementations for pagination (subsequent pages should return empty lists)
      when(
        () => mockJournalDb.getJournalEntities(
          types: any(named: 'types'),
          starredStatuses: any(named: 'starredStatuses'),
          privateStatuses: any(named: 'privateStatuses'),
          flaggedStatuses: any(named: 'flaggedStatuses'),
          ids: any(named: 'ids'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          categoryIds: any(named: 'categoryIds'),
        ),
      ).thenAnswer((_) async => <JournalEntity>[]);

      when(
        () => mockJournalDb.getTasks(
          ids: any(named: 'ids'),
          starredStatuses: any(named: 'starredStatuses'),
          taskStatuses: any(named: 'taskStatuses'),
          categoryIds: any(named: 'categoryIds'),
          labelIds: any(named: 'labelIds'),
          priorities: any(named: 'priorities'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) async => <JournalEntity>[]);

      getIt
        ..registerSingleton<Directory>(await getApplicationDocumentsDirectory())
        ..registerSingleton<UserActivityService>(UserActivityService())
        ..registerSingleton<LoggingService>(LoggingService())
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<SettingsDb>(mockSettingsDb)
        ..registerSingleton<TimeService>(mockTimeService)
        ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<NavService>(mockNavService)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
        ..registerSingleton<Fts5Db>(MockFts5Db());

      when(
        () => mockJournalDb.getMeasurableDataTypeById(measurableWater.id),
      ).thenAnswer((_) async => measurableWater);

      when(() => mockUpdateNotifications.updateStream).thenAnswer(
        (_) => Stream<Set<String>>.fromIterable([]),
      );

      when(mockJournalDb.watchConfigFlags).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([
          <ConfigFlag>{
            const ConfigFlag(
              name: 'private',
              description: 'Show private entries?',
              status: true,
            ),
          },
        ]),
      );

      when(
        mockTimeService.getStream,
      ).thenAnswer((_) => Stream<JournalEntity>.fromIterable([]));
    });
    tearDown(getIt.reset);

    // Helper function to replace pumpAndSettle. All data comes from
    // synchronous mock stubs, so one event-loop pump plus a single 16 ms
    // frame is enough — no need to spin a dozen extra frames.
    Future<void> pumpWithDelay(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
    }

    // Stubs the page query for a single [entity] and pumps the page —
    // the shared scaffold of every per-entity render test below.
    Future<void> pumpPageWithEntity(
      WidgetTester tester,
      JournalEntity entity,
    ) async {
      when(
        () => mockJournalDb.getJournalEntities(
          types: any(named: 'types'),
          starredStatuses: [true, false],
          privateStatuses: [true, false],
          flaggedStatuses: [1, 0],
          ids: null,
          limit: 50,
          offset: any(named: 'offset'),
          categoryIds: any(named: 'categoryIds'),
        ),
      ).thenAnswer((_) async => [entity]);
      when(
        () => mockJournalDb.journalEntityById(entity.meta.id),
      ).thenAnswer((_) async => entity);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const InfiniteJournalPage()),
      );
      await pumpWithDelay(tester);
    }

    testWidgets('page is rendered with text entry', (tester) async {
      await pumpPageWithEntity(tester, testTextEntry);

      // test entry displays expected date
      expect(
        find.text(
          entryDateLabel(
            tester.element(find.byType(InfiniteJournalPage)),
            testTextEntry.meta.dateFrom,
          ),
        ),
        findsOneWidget,
      );

      // test text entry is starred
      expect(
        (tester.firstWidget(find.byIcon(MdiIcons.star)) as Icon).color,
        starredGold,
      );
    });

    testWidgets('page is rendered with task entry', (tester) async {
      await pumpPageWithEntity(tester, testTask);

      // test task title is displayed
      expect(
        find.text(testTask.data.title),
        findsOneWidget,
      );
    });

    testWidgets('page is rendered with weight entry', (tester) async {
      await pumpPageWithEntity(tester, testWeightEntry);

      // task entry displays expected date
      expect(
        find.text(
          entryDateLabel(
            tester.element(find.byType(InfiniteJournalPage)),
            testWeightEntry.meta.dateFrom,
          ),
        ),
        findsOneWidget,
      );

      // weight entry displays its humanised name (title) and value chip
      expect(find.text('Weight'), findsOneWidget);
      expect(find.text('94.49 kg'), findsOneWidget);

      // weight task is neither starred nor private (icons invisible)
      expect(find.byIcon(MdiIcons.star).hitTestable(), findsNothing);
      expect(find.byIcon(MdiIcons.security).hitTestable(), findsNothing);
    });

    testWidgets(
      'page is rendered with measurement entry, aggregation sum by day',
      (tester) async {
        Future<MeasurementEntry?> mockCreateMeasurementEntry() {
          return mockPersistenceLogic.createMeasurementEntry(
            data: any(named: 'data'),
            private: false,
          );
        }

        when(
          () => mockEntitiesCacheService.getDataTypeById(
            measurableChocolate.id,
          ),
        ).thenAnswer((_) => measurableChocolate);

        when(
          () => mockJournalDb.getMeasurementsByType(
            rangeStart: any(named: 'rangeStart'),
            rangeEnd: any(named: 'rangeEnd'),
            type: measurableChocolate.id,
          ),
        ).thenAnswer((_) async => []);

        when(
          () => mockJournalDb.getMeasurableDataTypeById(any()),
        ).thenAnswer((_) async => measurableChocolate);

        when(mockCreateMeasurementEntry).thenAnswer((_) async => null);

        await pumpPageWithEntity(tester, testMeasurementChocolateEntry);

        // measurement entry displays expected date
        expect(
          find.text(
            entryDateLabel(
              tester.element(find.byType(InfiniteJournalPage)),
              testMeasurementChocolateEntry.meta.dateFrom,
            ),
          ),
          findsOneWidget,
        );

        // measurement entry displays its name (title) and value chip
        expect(find.text(measurableChocolate.displayName), findsOneWidget);
        expect(
          find.text(
            '${nf.format(testMeasurementChocolateEntry.data.value)} '
            '${measurableChocolate.unitName}',
          ),
          findsOneWidget,
        );

        // test measurement is not starred (icon invisible)
        expect(find.byIcon(MdiIcons.star).hitTestable(), findsNothing);

        // test measurement is private (icon visible & red)
        expect(find.byIcon(MdiIcons.security).hitTestable(), findsOneWidget);
      },
    );

    testWidgets('page is rendered with measurement entry, aggregation none', (
      tester,
    ) async {
      when(
        () => mockEntitiesCacheService.getDataTypeById(
          measurableCoverage.id,
        ),
      ).thenAnswer((_) => measurableCoverage);

      when(
        () => mockJournalDb.getMeasurableDataTypeById(any()),
      ).thenAnswer((_) async => measurableCoverage);

      await pumpPageWithEntity(tester, testMeasuredCoverageEntry);

      // measurement entry displays expected date
      expect(
        find.text(
          entryDateLabel(
            tester.element(find.byType(InfiniteJournalPage)),
            testMeasuredCoverageEntry.meta.dateFrom,
          ),
        ),
        findsOneWidget,
      );

      // measurement entry displays its name (title) and value chip
      expect(find.text(measurableCoverage.displayName), findsOneWidget);
      expect(
        find.text(
          '${nf.format(testMeasuredCoverageEntry.data.value)} '
          '${measurableCoverage.unitName}',
        ),
        findsOneWidget,
      );

      // test measurement is neither starred nor private (icons invisible)
      expect(find.byIcon(MdiIcons.star).hitTestable(), findsNothing);
      expect(find.byIcon(MdiIcons.security).hitTestable(), findsNothing);
    });

    testWidgets('page shows empty state when no entries', (tester) async {
      when(
        () => mockJournalDb.getJournalEntities(
          types: entryTypeStrings,
          starredStatuses: [true, false],
          privateStatuses: [true, false],
          flaggedStatuses: [1, 0],
          ids: null,
          limit: 50,
          offset: any(named: 'offset'),
          categoryIds: any(named: 'categoryIds'),
        ),
      ).thenAnswer((_) async => []);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const InfiniteJournalPage(),
        ),
      );

      await pumpWithDelay(tester);

      // Verify no entries are displayed
      expect(find.byType(CardWrapperWidget), findsNothing);

      // A genuinely empty logbook (no search, no filters) shows the localized
      // first-run zero-state with an inline create action — never the
      // pagination package's stock "No items found".
      expect(find.text('Your logbook is empty'), findsOneWidget);
      expect(
        find.text('Create your first entry to start journaling.'),
        findsOneWidget,
      );
      expect(find.text('No items found'), findsNothing);

      // The inline CTA opens the same create modal as the FAB ("Add" sheet).
      await tester.tap(find.text('Create new entry'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Add'), findsOneWidget);
    });

    testWidgets('pull to refresh works correctly', (tester) async {
      when(
        () => mockJournalDb.getJournalEntities(
          types: any(named: 'types'),
          starredStatuses: [true, false],
          privateStatuses: [true, false],
          flaggedStatuses: [1, 0],
          ids: null,
          limit: 50,
          offset: any(named: 'offset'),
          categoryIds: any(named: 'categoryIds'),
        ),
      ).thenAnswer((_) async => [testTextEntry]);

      when(
        () => mockJournalDb.journalEntityById(testTextEntry.meta.id),
      ).thenAnswer((_) async => testTextEntry);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const InfiniteJournalPage(),
        ),
      );

      await pumpWithDelay(tester);

      // Find and pull down the refresh indicator
      await tester.drag(find.byType(RefreshIndicator), const Offset(0, 200));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Verify the journal was refreshed
      verify(
        () => mockJournalDb.getJournalEntities(
          types: any(named: 'types'),
          starredStatuses: any(named: 'starredStatuses'),
          privateStatuses: any(named: 'privateStatuses'),
          flaggedStatuses: any(named: 'flaggedStatuses'),
          ids: any(named: 'ids'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          categoryIds: any(named: 'categoryIds'),
        ),
      ).called(greaterThan(1));
    });

    testWidgets('multiple entries are rendered in correct order', (
      tester,
    ) async {
      final entries = [testTextEntry, testTask, testWeightEntry];

      when(
        () => mockJournalDb.getJournalEntities(
          types: any(named: 'types'),
          starredStatuses: [true, false],
          privateStatuses: [true, false],
          flaggedStatuses: [1, 0],
          ids: null,
          limit: 50,
          offset: any(named: 'offset'),
          categoryIds: any(named: 'categoryIds'),
        ),
      ).thenAnswer((_) async => entries);

      for (final entry in entries) {
        when(
          () => mockJournalDb.journalEntityById(entry.meta.id),
        ).thenAnswer((_) async => entry);
      }

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const InfiniteJournalPage(),
        ),
      );

      await pumpWithDelay(tester);

      // Verify all entries are displayed
      expect(find.byType(CardWrapperWidget), findsNWidgets(3));
    });

    testWidgets('private entry shows security icon', (tester) async {
      final privateEntry = testTextEntry.copyWith(
        meta: testTextEntry.meta.copyWith(private: true),
      );

      when(
        () => mockJournalDb.getJournalEntities(
          types: any(named: 'types'),
          starredStatuses: [true, false],
          privateStatuses: [true, false],
          flaggedStatuses: [1, 0],
          ids: null,
          limit: 50,
          offset: any(named: 'offset'),
          categoryIds: any(named: 'categoryIds'),
        ),
      ).thenAnswer((_) async => [privateEntry]);

      when(
        () => mockJournalDb.journalEntityById(privateEntry.meta.id),
      ).thenAnswer((_) async => privateEntry);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const InfiniteJournalPage(),
        ),
      );

      await pumpWithDelay(tester);

      // Verify security icon is visible
      expect(find.byIcon(MdiIcons.security), findsOneWidget);
    });
  });

  group('fake-controller branch coverage (merged from the former '
      'bottom-padding satellite file)', () {
    setUp(() async {
      await setUpTestGetIt(
        additionalSetup: () {
          final entitiesCacheService = MockEntitiesCacheService();
          when(
            () => entitiesCacheService.getCategoryById(any()),
          ).thenReturn(null);
          // The logbook filter modal's category section reads the sorted
          // categories from the cache service.
          when(
            () => entitiesCacheService.sortedCategories,
          ).thenReturn(const []);
          getIt
            ..registerSingleton<UserActivityService>(UserActivityService())
            ..registerSingleton<EntitiesCacheService>(entitiesCacheService);
        },
      );
    });

    tearDown(tearDownTestGetIt);

    /// Pumps [InfiniteJournalPage] with the page controller pinned to
    /// [state] and returns the fake controller for call-tracking assertions.
    Future<FakeJournalPageController> pumpPage(
      WidgetTester tester, {
      JournalPageState state = const JournalPageState(showTasks: false),
    }) async {
      final fakeController = FakeJournalPageController(state);
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const InfiniteJournalPage(),
          overrides: [
            journalPageScopeProvider.overrideWithValue(false),
            journalPageControllerProvider(
              false,
            ).overrideWith(() => fakeController),
          ],
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));
      return fakeController;
    }

    testWidgets(
      'a search/filter-narrowed empty feed shows the no-matches variant '
      'without a create CTA',
      (tester) async {
        final pagingController =
            PagingController<int, JournalEntity>(
                getNextPageKey: (_) => null,
                fetchPage: (_) async => const <JournalEntity>[],
              )
              ..value = PagingState(
                pages: const [<JournalEntity>[]],
                keys: const [0],
                hasNextPage: false,
              );
        addTearDown(pagingController.dispose);

        await pumpPage(
          tester,
          state: JournalPageState(
            showTasks: false,
            match: 'no such entry',
            pagingController: pagingController,
          ),
        );

        // Emptiness caused by the user's search reads as a query result with
        // a recovery hint — not as an empty logbook inviting a first entry.
        expect(find.text('No entries match'), findsOneWidget);
        expect(
          find.text('Adjust your search or filters to see more.'),
          findsOneWidget,
        );
        expect(find.text('Your logbook is empty'), findsNothing);
        expect(find.text('Create new entry'), findsNothing);
      },
    );

    testWidgets(
      'deselecting an allowed entry type narrows the feed (no first-run CTA)',
      (tester) async {
        final pagingController =
            PagingController<int, JournalEntity>(
                getNextPageKey: (_) => null,
                fetchPage: (_) async => const <JournalEntity>[],
              )
              ..value = PagingState(
                pages: const [<JournalEntity>[]],
                keys: const [0],
                hasNextPage: false,
              );
        addTearDown(pagingController.dispose);

        // Events are flag-enabled (in the allowed baseline) but the user
        // deselected them: the feed is user-narrowed even though every ungated
        // type is still selected, so the empty result is a query result — not a
        // first-run empty logbook.
        await pumpPage(
          tester,
          state: JournalPageState(
            showTasks: false,
            allowedEntryTypes: const ['JournalEntry', 'JournalEvent'],
            selectedEntryTypes: const ['JournalEntry'],
            pagingController: pagingController,
          ),
        );

        expect(find.text('No entries match'), findsOneWidget);
        expect(find.text('Your logbook is empty'), findsNothing);
        expect(find.text('Create new entry'), findsNothing);
      },
    );

    testWidgets('adds 104px bottom spacer sliver', (tester) async {
      const state = JournalPageState(
        match: '',
        filters: <DisplayFilter>{},
        showPrivateEntries: false,
        showTasks: false,
        selectedEntryTypes: <String>[],
        fullTextMatches: <String>{},
        pagingController: null,
        taskStatuses: <String>[],
        selectedTaskStatuses: <String>{},
        selectedCategoryIds: <String>{},
        selectedLabelIds: <String>{},
        selectedPriorities: <String>{},
      );

      final fakeController = FakeJournalPageController(state);

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const InfiniteJournalPage(),
          overrides: [
            journalPageScopeProvider.overrideWithValue(false),
            journalPageControllerProvider(
              false,
            ).overrideWith(() => fakeController),
          ],
        ),
      );

      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 600));

      // spacing.step11 + spacing.step6 = 80 + 24 keeps the last card above
      // the FAB / time indicator overlays.
      expect(
        find.byWidgetPredicate(
          (w) => w is SizedBox && w.height == 104,
        ),
        findsOneWidget,
      );
      // The null-pagingController branch shows the loading spinner instead
      // of the paged list.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(PagedSliverList<int, JournalEntity>), findsNothing);
    });

    testWidgets('renders the shared header with Logbook title and search', (
      tester,
    ) async {
      final fakeController = await pumpPage(tester);

      // The old SliverAppBar chrome is gone — the page now renders the same
      // TabSectionHeader Tasks and Projects use.
      expect(find.byType(SliverAppBar), findsNothing);
      expect(find.byType(TabSectionHeader), findsOneWidget);
      expect(find.text('Logbook'), findsOneWidget);

      // Typing into the header search field lands in the page controller.
      await tester.enterText(find.byType(TextField), 'penguins');
      await tester.pump();
      expect(fakeController.searchStringCalls, ['penguins']);

      // The search glyph re-submits the current text…
      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pump();
      expect(fakeController.searchStringCalls, ['penguins', 'penguins']);

      // …and the clear affordance resets the query to the empty string —
      // once via the clear callback and once via the field's change stream.
      await tester.tap(find.byIcon(Icons.cancel_rounded));
      await tester.pump();
      expect(fakeController.searchStringCalls, [
        'penguins',
        'penguins',
        '',
        '',
      ]);
    });

    testWidgets('header filter icon opens the logbook filter modal', (
      tester,
    ) async {
      await pumpPage(tester);

      await tester.tap(find.byIcon(Icons.filter_list_rounded));
      // Bounded pumps instead of pumpAndSettle: the page's loading spinner
      // (null pagingController branch) animates forever and would time out.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(LogbookFilterSheet), findsOneWidget);
      expect(find.text('Filter journal'), findsOneWidget);
    });

    // The vector-search row only renders when the config flag is on.
    for (final enabled in [true, false]) {
      testWidgets(
        'search-mode row is ${enabled ? 'shown' : 'hidden'} when vector '
        'search is ${enabled ? 'enabled' : 'disabled'}',
        (tester) async {
          await pumpPage(
            tester,
            state: JournalPageState(
              showTasks: false,
              enableVectorSearch: enabled,
            ),
          );
          expect(
            find.byType(LogbookSearchModeRow),
            enabled ? findsOneWidget : findsNothing,
          );
        },
      );
    }

    testWidgets('renders paged list branch when pagingController is present', (
      tester,
    ) async {
      final controller = PagingController<int, JournalEntity>(
        getNextPageKey: (PagingState<int, JournalEntity> state) => null,
        fetchPage: (int pageKey) async => <JournalEntity>[],
      );

      final state = JournalPageState(
        match: '',
        filters: <DisplayFilter>{},
        showPrivateEntries: false,
        showTasks: false,
        selectedEntryTypes: const <String>[],
        fullTextMatches: <String>{},
        pagingController: controller,
        taskStatuses: const <String>[],
        selectedTaskStatuses: <String>{},
        selectedCategoryIds: <String>{},
        selectedLabelIds: <String>{},
        selectedPriorities: <String>{},
      );

      final fakeController = FakeJournalPageController(state);

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const InfiniteJournalPage(),
          overrides: [
            journalPageScopeProvider.overrideWithValue(false),
            journalPageControllerProvider(
              false,
            ).overrideWith(() => fakeController),
          ],
        ),
      );

      // The paged branch mounts the PagedSliverList.
      expect(
        find.byType(PagedSliverList<int, JournalEntity>),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'passes the single selected category id to FloatingAddActionButton',
      (tester) async {
        // selectedCategoryIds.length == 1 takes the `selectedCategoryIds.first`
        // branch in InfiniteJournalPage.build.
        const state = JournalPageState(
          match: '',
          filters: <DisplayFilter>{},
          showPrivateEntries: false,
          showTasks: false,
          selectedEntryTypes: <String>[],
          fullTextMatches: <String>{},
          pagingController: null,
          taskStatuses: <String>[],
          selectedTaskStatuses: <String>{},
          selectedCategoryIds: {'cat-only-one'},
          selectedLabelIds: <String>{},
          selectedPriorities: <String>{},
        );

        final fakeController = FakeJournalPageController(state);

        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            const InfiniteJournalPage(),
            overrides: [
              journalPageScopeProvider.overrideWithValue(false),
              journalPageControllerProvider(
                false,
              ).overrideWith(() => fakeController),
            ],
          ),
        );

        await tester.pump(const Duration(milliseconds: 16));

        // The FAB is the only consumer of the resolved categoryId — finding
        // it confirms the single-id branch built without throwing.
        final fab = tester.widget<FloatingAddActionButton>(
          find.byType(FloatingAddActionButton),
        );
        expect(fab.categoryId, 'cat-only-one');
      },
    );

    testWidgets(
      'passes null categoryId to FloatingAddActionButton when multiple '
      'categories are selected',
      (tester) async {
        // selectedCategoryIds.length > 1 takes the `null` branch in
        // InfiniteJournalPage.build — no single category can be inferred for
        // the FAB target.
        const state = JournalPageState(
          match: '',
          filters: <DisplayFilter>{},
          showPrivateEntries: false,
          showTasks: false,
          selectedEntryTypes: <String>[],
          fullTextMatches: <String>{},
          pagingController: null,
          taskStatuses: <String>[],
          selectedTaskStatuses: <String>{},
          selectedCategoryIds: {'cat-one', 'cat-two'},
          selectedLabelIds: <String>{},
          selectedPriorities: <String>{},
        );

        final fakeController = FakeJournalPageController(state);

        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            const InfiniteJournalPage(),
            overrides: [
              journalPageScopeProvider.overrideWithValue(false),
              journalPageControllerProvider(
                false,
              ).overrideWith(() => fakeController),
            ],
          ),
        );

        await tester.pump(const Duration(milliseconds: 16));

        final fab = tester.widget<FloatingAddActionButton>(
          find.byType(FloatingAddActionButton),
        );
        expect(fab.categoryId, isNull);
      },
    );

    testWidgets('commands refresh, create, and focus journal search', (
      tester,
    ) async {
      const state = JournalPageState(
        showTasks: false,
        selectedCategoryIds: {'journal-category'},
      );
      final fakeController = FakeJournalPageController(state);
      String? createdCategoryId;

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          AppCommandHost(
            handlers: const {},
            platform: TargetPlatform.windows,
            child: InfiniteJournalPage(
              onCreateEntry: ({categoryId}) async {
                createdCategoryId = categoryId;
                return null;
              },
            ),
          ),
          overrides: [
            journalPageScopeProvider.overrideWithValue(false),
            journalPageControllerProvider(
              false,
            ).overrideWith(() => fakeController),
          ],
        ),
      );
      await tester.pump();
      fakeController.refreshQueryPreserveFlags.clear();

      final commandContext = tester.element(find.byType(TextField));
      final commandController = AppCommandControllerProvider.of(
        commandContext,
      );
      expect(
        await commandController.invoke(commandContext, AppCommandId.refresh),
        isTrue,
      );
      expect(fakeController.refreshQueryPreserveFlags, [true]);

      expect(
        await commandController.invoke(
          commandContext,
          AppCommandId.createInContext,
        ),
        isTrue,
      );
      expect(createdCategoryId, 'journal-category');

      expect(
        await commandController.invoke(
          commandContext,
          AppCommandId.focusSearch,
        ),
        isTrue,
      );
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
        isTrue,
      );
    });

    testWidgets('forwards vector-search distance to journal cards', (
      tester,
    ) async {
      final pagingController =
          PagingController<int, JournalEntity>(
              getNextPageKey: (_) => null,
              fetchPage: (_) async => const <JournalEntity>[],
            )
            ..value = PagingState<int, JournalEntity>(
              pages: [
                [testTextEntry],
              ],
              keys: const [0],
              hasNextPage: false,
            );
      addTearDown(pagingController.dispose);
      final fakeController = FakeJournalPageController(
        JournalPageState(
          showTasks: false,
          pagingController: pagingController,
          showDistances: true,
          vectorSearchDistances: {testTextEntry.meta.id: 0.125},
        ),
      );

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const InfiniteJournalPage(),
          overrides: [
            journalPageScopeProvider.overrideWithValue(false),
            journalPageControllerProvider(
              false,
            ).overrideWith(() => fakeController),
          ],
        ),
      );
      await tester.pump();

      expect(
        tester
            .widget<CardWrapperWidget>(find.byType(CardWrapperWidget))
            .vectorDistance,
        0.125,
      );
    });
  });
}
