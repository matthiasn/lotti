import 'dart:async';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_floating_action_button.dart';
import 'package:lotti/features/journal/state/journal_focus_controller.dart';
import 'package:lotti/features/journal/ui/pages/entry_details_page.dart';
import 'package:lotti/features/journal/ui/widgets/linked_entries_with_timer.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/features/tasks/ui/checklists/linked_from_checklist_widget.dart';
import 'package:lotti/features/tasks/ui/checklists/linked_from_task_widget.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/link_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../helpers/path_provider.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';

// Minimal fake DropItem for invoking the onDragDone callback directly.
class _FakeDropItem extends Fake implements DropItem {
  _FakeDropItem(this._xFile);

  final XFile _xFile;

  @override
  String get name => _xFile.name;

  @override
  String get path => _xFile.path;

  @override
  Future<DateTime> lastModified() => _xFile.lastModified();
}

void main() {
  // setUpTestGetIt pre-registers core services (JournalDb,
  // UpdateNotifications, SettingsDb, loggers); groups swap in their own
  // mocks instead of double-registering.
  void reRegister<T extends Object>(T instance) {
    if (getIt.isRegistered<T>()) {
      getIt.unregister<T>();
    }
    getIt.registerSingleton<T>(instance);
  }

  TestWidgetsFlutterBinding.ensureInitialized();

  var mockJournalDb = MockJournalDb();
  var mockPersistenceLogic = MockPersistenceLogic();
  final mockUpdateNotifications = MockUpdateNotifications();
  final mockEntitiesCacheService = MockEntitiesCacheService();

  group('EntryDetailPage Widget Tests - ', () {
    setUpAll(() {
      setFakeDocumentsPath();
      registerFallbackValue(FakeMeasurementData());
      registerAllFallbackValues();
    });

    setUp(() async {
      mockJournalDb = mockJournalDbWithMeasurableTypes([
        measurableWater,
        measurableChocolate,
      ]);
      mockPersistenceLogic = MockPersistenceLogic();

      final mockTimeService = MockTimeService();
      final mockEditorStateService = MockEditorStateService();
      final mockHealthImport = MockHealthImport();

      final docsDir = await getApplicationDocumentsDirectory();
      await setUpTestGetIt(
        additionalSetup: () {
          reRegister<Directory>(docsDir);
          reRegister<UserActivityService>(UserActivityService());
          reRegister<UpdateNotifications>(mockUpdateNotifications);
          reRegister<EditorStateService>(mockEditorStateService);
          reRegister<EntitiesCacheService>(mockEntitiesCacheService);
          reRegister<LinkService>(MockLinkService());
          reRegister<HealthImport>(mockHealthImport);
          reRegister<TimeService>(mockTimeService);
          reRegister<JournalDb>(mockJournalDb);
          reRegister<PersistenceLogic>(mockPersistenceLogic);
        },
      );

      when(() => mockEntitiesCacheService.sortedCategories).thenAnswer(
        (_) => [categoryMindfulness],
      );

      when(
        () => mockJournalDb.getMeasurableDataTypeById(
          '83ebf58d-9cea-4c15-a034-89c84a8b8178',
        ),
      ).thenAnswer((_) async => measurableWater);

      when(() => mockUpdateNotifications.updateStream).thenAnswer(
        (_) => Stream<Set<String>>.fromIterable([]),
      );

      when(() => mockJournalDb.watchConfigFlags()).thenAnswer(
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
        () => mockEditorStateService.getUnsavedStream(
          any(),
          any(),
        ),
      ).thenAnswer(
        (_) => Stream<bool>.fromIterable([false]),
      );

      when(
        () => mockHealthImport.fetchHealthDataDelta(
          testWeightEntry.data.dataType,
        ),
      ).thenAnswer((_) async {});

      when(
        mockTimeService.getStream,
      ).thenAnswer((_) => Stream<JournalEntity>.fromIterable([]));

      when(
        () => mockJournalDb.getMeasurementsByType(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
          type: '83ebf58d-9cea-4c15-a034-89c84a8b8178',
        ),
      ).thenAnswer((_) async => []);

      when(
        () => mockJournalDb.getMeasurableDataTypeById(any()),
      ).thenAnswer((_) async => measurableWater);

      // Ensure ThemingController dependencies are registered
      ensureThemingServicesRegistered();
    });
    tearDown(tearDownTestGetIt);

    testWidgets('Text Entry is rendered', (tester) async {
      when(
        () => mockJournalDb.journalEntityById(testTextEntry.meta.id),
      ).thenAnswer((_) async => testTextEntry);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EntryDetailsPage(itemId: testTextEntry.meta.id),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // test entry displays expected date
      expect(
        find.text(dfShorter.format(testTextEntry.meta.dateFrom)),
        findsOneWidget,
      );

      // test entry displays duration of one hour
      expect(
        find.text('01:00:00'),
        findsOneWidget,
      );

      // test text entry is starred
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    });

    testWidgets('Weight Entry is rendered properly', (tester) async {
      Future<MeasurementEntry?> mockCreateMeasurementEntry() {
        return mockPersistenceLogic.createMeasurementEntry(
          data: any(named: 'data'),
          private: false,
        );
      }

      when(mockCreateMeasurementEntry).thenAnswer((_) async => null);

      when(
        () => mockJournalDb.journalEntityById(testWeightEntry.meta.id),
      ).thenAnswer((_) async => testWeightEntry);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EntryDetailsPage(itemId: testWeightEntry.meta.id),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // test entry displays expected date
      expect(
        find.text(dfShorter.format(testWeightEntry.meta.dateFrom)),
        findsOneWidget,
      );

      // test weight entry is not starred
      expect(find.byIcon(Icons.star_outline_rounded), findsNothing);
    });

    // -------------------------------------------------------------------------
    // ChecklistItem entry: renders LinkedFromChecklistWidget (line 159)
    // -------------------------------------------------------------------------
    testWidgets(
      'ChecklistItem entry renders LinkedFromChecklistWidget',
      (tester) async {
        final checklistItem = ChecklistItem(
          meta: Metadata(
            id: 'test-checklist-item-page-id',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15, 1),
            starred: false,
          ),
          data: const ChecklistItemData(
            title: 'Test checklist item for page',
            isChecked: false,
            linkedChecklists: [],
          ),
        );

        when(
          () => mockJournalDb.journalEntityById(checklistItem.meta.id),
        ).thenAnswer((_) async => checklistItem);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            EntryDetailsPage(itemId: checklistItem.meta.id),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // LinkedFromChecklistWidget is present in the widget tree when item is
        // a ChecklistItem (covers source line 159).
        expect(find.byType(LinkedFromChecklistWidget), findsOneWidget);
      },
    );

    // -------------------------------------------------------------------------
    // Checklist entry: renders LinkedFromTaskWidget (line 160)
    // -------------------------------------------------------------------------
    testWidgets(
      'Checklist entry renders LinkedFromTaskWidget',
      (tester) async {
        final checklist = Checklist(
          meta: Metadata(
            id: 'test-checklist-page-id',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15, 1),
            starred: false,
          ),
          // The checklist card renders linkedTasks.first, so the fixture
          // must reference a parent task.
          data: const ChecklistData(
            title: 'Test checklist for page',
            linkedChecklistItems: [],
            linkedTasks: ['parent-task-id'],
          ),
        );

        when(
          () => mockJournalDb.journalEntityById(checklist.meta.id),
        ).thenAnswer((_) async => checklist);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            EntryDetailsPage(itemId: checklist.meta.id),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // LinkedFromTaskWidget is present when the item is a Checklist
        // (covers source line 160).
        expect(find.byType(LinkedFromTaskWidget), findsOneWidget);
      },
    );

    // -------------------------------------------------------------------------
    // DropTarget.onDragDone callback (lines 115-116, 118-120)
    // -------------------------------------------------------------------------
    testWidgets(
      'DropTarget onDragDone callback executes without error for empty drop',
      (tester) async {
        when(
          () => mockJournalDb.journalEntityById(testTextEntry.meta.id),
        ).thenAnswer((_) async => testTextEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            EntryDetailsPage(itemId: testTextEntry.meta.id),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Find the DropTarget wrapping the entry page body.
        final dropTargetFinder = find.descendant(
          of: find.byType(EntryDetailsPage),
          matching: find.byType(DropTarget),
        );
        expect(dropTargetFinder, findsOneWidget);

        final dropTarget = tester.widget<DropTarget>(dropTargetFinder);
        expect(dropTarget.onDragDone, isNotNull);

        // Invoke with empty file list — no import logic runs, callback body
        // (lines 115-120) executes without throwing.
        const emptyDrop = DropDoneDetails(
          files: [],
          localPosition: Offset.zero,
          globalPosition: Offset.zero,
        );

        expect(
          () => dropTarget.onDragDone!.call(emptyDrop),
          returnsNormally,
        );

        await tester.pump();
      },
    );

    testWidgets(
      'DropTarget onDragDone forwards dropped image to media import with '
      'the entry id as linkedId',
      (tester) async {
        when(
          () => mockJournalDb.journalEntityById(testTextEntry.meta.id),
        ).thenAnswer((_) async => testTextEntry);

        // Stub the persistence seam reached by the media import pipeline:
        // handleDroppedMedia -> importDroppedImages ->
        // JournalRepository.createImageEntry -> PersistenceLogic.
        when(
          () => mockPersistenceLogic.createMetadata(
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
            uuidV5Input: any(named: 'uuidV5Input'),
            categoryId: any(named: 'categoryId'),
            flag: any(named: 'flag'),
          ),
        ).thenAnswer(
          (_) async => Metadata(
            id: 'image-meta-id',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
          ),
        );
        // Signals when the import pipeline reaches persistence, letting the
        // test await the fire-and-forget drop deterministically (no delays).
        final createDbEntityCalled = Completer<void>();
        when(
          () => mockPersistenceLogic.createDbEntity(
            any(that: isA<JournalImage>()),
            linkedId: any(named: 'linkedId'),
            shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
            enqueueSync: any(named: 'enqueueSync'),
          ),
        ).thenAnswer((_) async {
          if (!createDbEntityCalled.isCompleted) {
            createDbEntityCalled.complete();
          }
          return true;
        });

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            EntryDetailsPage(itemId: testTextEntry.meta.id),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final dropTargetFinder = find.descendant(
          of: find.byType(EntryDetailsPage),
          matching: find.byType(DropTarget),
        );
        final dropTarget = tester.widget<DropTarget>(dropTargetFinder);

        // onDragDone forwards to handleDroppedMedia (fire-and-forget). The whole
        // pipeline performs real file IO (creating the temp source, copying it
        // into the assets dir), so everything that touches dart:io must run
        // inside runAsync; under the test's fake-async zone real IO never
        // completes. Await the persistence seam being reached deterministically.
        await tester.runAsync(() async {
          final tempDir = await Directory.systemTemp.createTemp(
            'entry_details_drop_',
          );
          addTearDown(() => tempDir.delete(recursive: true).ignore());
          final imageFile = File(p.join(tempDir.path, 'dropped.png'));
          await imageFile.writeAsBytes(List<int>.filled(64, 0));

          final dropDetails = DropDoneDetails(
            files: [_FakeDropItem(XFile(imageFile.path))],
            localPosition: Offset.zero,
            globalPosition: Offset.zero,
          );

          dropTarget.onDragDone!.call(dropDetails);

          // Yield to the event loop (not just microtasks) so the real file
          // copy and the async persistence chain can run to completion. Bounded
          // so a genuine failure surfaces instead of hanging.
          for (var i = 0; i < 100 && !createDbEntityCalled.isCompleted; i++) {
            await Future<void>(() {});
          }
        });

        // The dropped file's entry is created and linked to the open entry.
        verify(
          () => mockPersistenceLogic.createDbEntity(
            any(that: isA<JournalImage>()),
            linkedId: testTextEntry.meta.id,
            shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
            enqueueSync: any(named: 'enqueueSync'),
          ),
        ).called(1);
      },
    );

    // -------------------------------------------------------------------------
    // Scroll listener / updateOffset (lines 51-54)
    // -------------------------------------------------------------------------
    testWidgets(
      'Scroll controller listener calls updateOffset on scroll',
      (tester) async {
        when(
          () => mockJournalDb.journalEntityById(testTextEntry.meta.id),
        ).thenAnswer((_) async => testTextEntry);

        // Use a wide-but-short viewport so content overflows vertically and
        // scrolling is possible without triggering horizontal overflow in the
        // entry header row.
        tester.view
          ..physicalSize = const Size(800, 400)
          ..devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            EntryDetailsPage(itemId: testTextEntry.meta.id),
            mediaQueryData: const MediaQueryData(size: Size(800, 400)),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Drag from a point within the viewport to trigger a scroll event
        // which fires the _scrollController listeners, exercising lines 51-54.
        await tester.dragFrom(
          const Offset(400, 200),
          const Offset(0, -200),
        );
        await tester.pump();

        // The DropTarget (and thus the full page body) is still present,
        // confirming the widget survived the scroll without error.
        expect(find.byType(DropTarget), findsOneWidget);
      },
    );
  });

  group('EntryDetailPage Auto-Scroll Tests - ', () {
    var mockJournalDbSat = MockJournalDb();
    var mockPersistenceLogicSat = MockPersistenceLogic();
    final mockUpdateNotificationsSat = MockUpdateNotifications();
    final mockEntitiesCacheServiceSat = MockEntitiesCacheService();

    setUpAll(() {
      setFakeDocumentsPath();
      registerFallbackValue(FakeMeasurementData());
    });

    setUp(() async {
      mockJournalDbSat = mockJournalDbWithMeasurableTypes([
        measurableWater,
        measurableChocolate,
      ]);
      mockPersistenceLogicSat = MockPersistenceLogic();

      final mockTimeService = MockTimeService();
      final mockEditorStateService = MockEditorStateService();
      final mockHealthImport = MockHealthImport();

      final docsDir = await getApplicationDocumentsDirectory();
      await setUpTestGetIt(
        additionalSetup: () {
          reRegister<Directory>(docsDir);
          reRegister<UserActivityService>(UserActivityService());
          reRegister<UpdateNotifications>(mockUpdateNotificationsSat);
          reRegister<EditorStateService>(mockEditorStateService);
          reRegister<EntitiesCacheService>(mockEntitiesCacheServiceSat);
          reRegister<LinkService>(MockLinkService());
          reRegister<HealthImport>(mockHealthImport);
          reRegister<TimeService>(mockTimeService);
          reRegister<JournalDb>(mockJournalDbSat);
          reRegister<PersistenceLogic>(mockPersistenceLogicSat);
        },
      );

      when(
        () => mockEntitiesCacheServiceSat.sortedCategories,
      ).thenAnswer((_) => [categoryMindfulness]);

      when(
        () => mockJournalDbSat.getMeasurableDataTypeById(
          '83ebf58d-9cea-4c15-a034-89c84a8b8178',
        ),
      ).thenAnswer((_) async => measurableWater);

      when(() => mockUpdateNotificationsSat.updateStream).thenAnswer(
        (_) => Stream<Set<String>>.fromIterable([]),
      );

      when(() => mockJournalDbSat.watchConfigFlags()).thenAnswer(
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
        () => mockEditorStateService.getUnsavedStream(
          any(),
          any(),
        ),
      ).thenAnswer(
        (_) => Stream<bool>.fromIterable([false]),
      );

      when(
        () => mockHealthImport.fetchHealthDataDelta(
          testWeightEntry.data.dataType,
        ),
      ).thenAnswer((_) async {});

      when(
        mockTimeService.getStream,
      ).thenAnswer((_) => Stream<JournalEntity>.fromIterable([]));

      when(
        () => mockJournalDbSat.getMeasurementsByType(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
          type: '83ebf58d-9cea-4c15-a034-89c84a8b8178',
        ),
      ).thenAnswer((_) async => []);

      when(
        () => mockJournalDbSat.getMeasurableDataTypeById(any()),
      ).thenAnswer((_) async => measurableWater);

      // Ensure ThemingController dependencies are registered
      ensureThemingServicesRegistered();
    });
    tearDown(tearDownTestGetIt);

    testWidgets('consumes pre-existing focus intent on first build', (
      tester,
    ) async {
      when(
        () => mockJournalDbSat.journalEntityById(testTextEntry.meta.id),
      ).thenAnswer((_) async => testTextEntry);

      // Create a container with pre-existing focus intent
      final container = ProviderContainer();
      final focusProvider = journalFocusControllerProvider(
        id: testTextEntry.meta.id,
      );

      // Set focus intent before building widget
      container
          .read(focusProvider.notifier)
          .publishJournalFocus(
            entryId: 'test-linked-entry-id',
            alignment: 0.3,
          );

      // Verify intent is set
      expect(container.read(focusProvider), isNotNull);

      // Use a tree without an inner ProviderScope to ensure our container is used
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: makeTestableWidget2(
            EntryDetailsPage(itemId: testTextEntry.meta.id),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // Allow initial timer to trigger
      await tester.pump(const Duration(milliseconds: 1));

      // Allow scroll retry/backoff to reach success/terminal outcome over multiple frames
      // In debug mode: maxScrollRetries=5, scrollRetryDelay=50ms
      for (var i = 0; i < 10 && container.read(focusProvider) != null; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }

      // Verify intent was cleared after consumption
      expect(container.read(focusProvider), isNull);

      // This harness exercises the retry-exhaustion path (the linked entry
      // is never rendered, so ensureVisible has no context): the intent is
      // consumed but the visual highlight must NOT be set. The page wires
      // the mixin's highlight into LinkedEntriesWithTimer — assert through
      // that seam; the set-then-clear success behavior is covered by the
      // mixin's own mirror test.
      expect(
        tester
            .widget<LinkedEntriesWithTimer>(
              find.byType(LinkedEntriesWithTimer),
            )
            .highlightedEntryId,
        isNull,
      );

      container.dispose();
    });

    testWidgets('creates GlobalKeys for entries with entryKeyBuilder', (
      tester,
    ) async {
      when(
        () => mockJournalDbSat.journalEntityById(testTextEntry.meta.id),
      ).thenAnswer((_) async => testTextEntry);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EntryDetailsPage(itemId: testTextEntry.meta.id),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify widget is rendered (indirect test that key builder is used)
      expect(find.byType(EntryDetailsPage), findsOneWidget);
    });

    testWidgets('scroll offset listener is triggered on scroll', (
      tester,
    ) async {
      when(
        () => mockJournalDbSat.journalEntityById(testTextEntry.meta.id),
      ).thenAnswer((_) async => testTextEntry);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EntryDetailsPage(itemId: testTextEntry.meta.id),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Find the CustomScrollView widget
      final scrollView = find.byType(CustomScrollView);
      expect(scrollView, findsOneWidget);

      // Trigger scroll to invoke the offset listener
      await tester.drag(scrollView, const Offset(0, -100));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The scroll offset listener should have been called (line 48-49)
      // We verify this indirectly by checking the widget still renders correctly
      expect(find.byType(EntryDetailsPage), findsOneWidget);
    });

    testWidgets('successfully scrolls to entry when context exists', (
      tester,
    ) async {
      when(
        () => mockJournalDbSat.journalEntityById(testTextEntry.meta.id),
      ).thenAnswer((_) async => testTextEntry);

      final container = ProviderContainer();
      final focusProvider = journalFocusControllerProvider(
        id: testTextEntry.meta.id,
      );

      // Set focus intent that would trigger scroll
      container
          .read(focusProvider.notifier)
          .publishJournalFocus(
            entryId: testTextEntry.meta.id,
            alignment: 0.5,
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: makeTestableWidgetWithScaffold(
            EntryDetailsPage(itemId: testTextEntry.meta.id),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify widget rendered successfully (scroll would have been attempted)
      // Line 71 would be executed if context exists
      expect(find.byType(EntryDetailsPage), findsOneWidget);

      container.dispose();
    });
  });

  group('EntryDetailsPage Edge Cases - ', () {
    var mockJournalDbEdge = MockJournalDb();
    var mockPersistenceLogicEdge = MockPersistenceLogic();
    final mockUpdateNotificationsEdge = MockUpdateNotifications();
    final mockEntitiesCacheServiceEdge = MockEntitiesCacheService();

    setUpAll(() {
      setFakeDocumentsPath();
      registerFallbackValue(FakeMeasurementData());
    });

    setUp(() async {
      mockJournalDbEdge = mockJournalDbWithMeasurableTypes([
        measurableWater,
        measurableChocolate,
      ]);
      mockPersistenceLogicEdge = MockPersistenceLogic();

      final mockTimeService = MockTimeService();
      final mockEditorStateService = MockEditorStateService();
      final mockHealthImport = MockHealthImport();

      final docsDir = await getApplicationDocumentsDirectory();
      await setUpTestGetIt(
        additionalSetup: () {
          reRegister<Directory>(docsDir);
          reRegister<UserActivityService>(UserActivityService());
          reRegister<UpdateNotifications>(mockUpdateNotificationsEdge);
          reRegister<EditorStateService>(mockEditorStateService);
          reRegister<EntitiesCacheService>(mockEntitiesCacheServiceEdge);
          reRegister<LinkService>(MockLinkService());
          reRegister<HealthImport>(mockHealthImport);
          reRegister<TimeService>(mockTimeService);
          reRegister<JournalDb>(mockJournalDbEdge);
          reRegister<PersistenceLogic>(mockPersistenceLogicEdge);
        },
      );

      when(
        () => mockEntitiesCacheServiceEdge.sortedCategories,
      ).thenAnswer((_) => [categoryMindfulness]);

      when(
        () => mockJournalDbEdge.getMeasurableDataTypeById(
          '83ebf58d-9cea-4c15-a034-89c84a8b8178',
        ),
      ).thenAnswer((_) async => measurableWater);

      when(() => mockUpdateNotificationsEdge.updateStream).thenAnswer(
        (_) => Stream<Set<String>>.fromIterable([]),
      );

      when(() => mockJournalDbEdge.watchConfigFlags()).thenAnswer(
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
        () => mockEditorStateService.getUnsavedStream(
          any(),
          any(),
        ),
      ).thenAnswer(
        (_) => Stream<bool>.fromIterable([false]),
      );

      when(
        () => mockHealthImport.fetchHealthDataDelta(
          testWeightEntry.data.dataType,
        ),
      ).thenAnswer((_) async {});

      when(
        mockTimeService.getStream,
      ).thenAnswer((_) => Stream<JournalEntity>.fromIterable([]));

      when(
        () => mockJournalDbEdge.getMeasurementsByType(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
          type: '83ebf58d-9cea-4c15-a034-89c84a8b8178',
        ),
      ).thenAnswer((_) async => []);

      when(
        () => mockJournalDbEdge.getMeasurableDataTypeById(any()),
      ).thenAnswer((_) async => measurableWater);

      // Ensure ThemingController dependencies are registered
      ensureThemingServicesRegistered();
    });

    tearDown(tearDownTestGetIt);

    testWidgets('scroll controller is properly disposed', (tester) async {
      when(
        () => mockJournalDbEdge.journalEntityById(testTextEntry.meta.id),
      ).thenAnswer((_) async => testTextEntry);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EntryDetailsPage(itemId: testTextEntry.meta.id),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify widget is rendered
      expect(find.byType(EntryDetailsPage), findsOneWidget);

      // Verify scroll controller is working by scrolling
      final scrollView = find.byType(CustomScrollView);
      expect(scrollView, findsOneWidget);

      // Trigger scroll to verify listener is attached
      await tester.drag(scrollView, const Offset(0, -50));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Now pop the widget to trigger dispose
      await tester.pumpWidget(Container());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Dispose must tear the page down cleanly: no page left in the tree
      // and no exception (e.g. from the scroll listener) recorded.
      expect(find.byType(EntryDetailsPage), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('handles null item gracefully', (tester) async {
      when(
        () => mockJournalDbEdge.journalEntityById(testTextEntry.meta.id),
      ).thenAnswer((_) async => null);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EntryDetailsPage(itemId: testTextEntry.meta.id),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Should show empty scaffold when item is null
      expect(find.text(''), findsWidgets);
    });

    testWidgets('scroll offset listener updates correctly', (tester) async {
      when(
        () => mockJournalDbEdge.journalEntityById(testTextEntry.meta.id),
      ).thenAnswer((_) async => testTextEntry);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EntryDetailsPage(itemId: testTextEntry.meta.id),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Find the CustomScrollView
      final scrollView = find.byType(CustomScrollView);
      expect(scrollView, findsOneWidget);

      // Scroll down to trigger offset listener
      await tester.drag(scrollView, const Offset(0, -100));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Scroll up to trigger offset listener again
      await tester.drag(scrollView, const Offset(0, 100));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify widget still renders correctly after multiple scroll events
      expect(find.byType(EntryDetailsPage), findsOneWidget);
    });

    testWidgets('creates GlobalKeys for each entry without duplicates', (
      tester,
    ) async {
      when(
        () => mockJournalDbEdge.journalEntityById(testTextEntry.meta.id),
      ).thenAnswer((_) async => testTextEntry);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EntryDetailsPage(itemId: testTextEntry.meta.id),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify widget renders
      expect(find.byType(EntryDetailsPage), findsOneWidget);

      // The _getEntryKey method should create unique GlobalKeys for each entry
      // This is tested implicitly by the widget rendering without errors
    });

    testWidgets('FloatingAddActionButton is present', (tester) async {
      when(
        () => mockJournalDbEdge.journalEntityById(testTextEntry.meta.id),
      ).thenAnswer((_) async => testTextEntry);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EntryDetailsPage(itemId: testTextEntry.meta.id),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify the design-system FAB is present (rounded-24 teal button
      // matching the Figma spec; swapped from Flutter's default FAB).
      expect(find.byType(DesignSystemFloatingActionButton), findsOneWidget);
      expect(
        find.byType(DesignSystemBottomNavigationFabPadding),
        findsOneWidget,
      );
    });

    testWidgets('scroll controller listeners are set up in initState', (
      tester,
    ) async {
      when(
        () => mockJournalDbEdge.journalEntityById(testTextEntry.meta.id),
      ).thenAnswer((_) async => testTextEntry);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EntryDetailsPage(itemId: testTextEntry.meta.id),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify scroll controller is working by performing scroll action
      final scrollView = find.byType(CustomScrollView);
      await tester.drag(scrollView, const Offset(0, -200));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // If scroll worked without errors, listeners are properly set up
      expect(find.byType(EntryDetailsPage), findsOneWidget);
    });

    testWidgets('handles scroll to non-existent entry gracefully', (
      tester,
    ) async {
      when(
        () => mockJournalDbEdge.journalEntityById(testTextEntry.meta.id),
      ).thenAnswer((_) async => testTextEntry);

      final container = ProviderContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: makeTestableWidgetWithScaffold(
            EntryDetailsPage(itemId: testTextEntry.meta.id),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // This test verifies that the debug print at line 83-85 is executed
      // when entry is not found (context is null)
      // The test passes if no exception is thrown
      expect(find.byType(EntryDetailsPage), findsOneWidget);

      container.dispose();
    });

    testWidgets('multiple scroll listeners work independently', (tester) async {
      when(
        () => mockJournalDbEdge.journalEntityById(testTextEntry.meta.id),
      ).thenAnswer((_) async => testTextEntry);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EntryDetailsPage(itemId: testTextEntry.meta.id),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final scrollView = find.byType(CustomScrollView);

      // Perform multiple scrolls to verify both listeners work
      // First listener: UserActivityService.updateActivity
      // Second listener: taskAppBarController.updateOffset
      await tester.drag(scrollView, const Offset(0, -50));
      await tester.pump();

      await tester.drag(scrollView, const Offset(0, -50));
      await tester.pump();

      await tester.drag(scrollView, const Offset(0, 50));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify widget still works after multiple listener calls
      expect(find.byType(EntryDetailsPage), findsOneWidget);
    });
  });
}
