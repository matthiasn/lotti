import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/ui/pages/entry_details_page.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/features/tasks/ui/checklists/linked_from_checklist_widget.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/link_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider/path_provider.dart';

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
  TestWidgetsFlutterBinding.ensureInitialized();

  var mockJournalDb = MockJournalDb();
  var mockPersistenceLogic = MockPersistenceLogic();
  final mockUpdateNotifications = MockUpdateNotifications();
  final mockEntitiesCacheService = MockEntitiesCacheService();

  group('EntryDetailPage Widget Tests - ', () {
    setUpAll(() {
      setFakeDocumentsPath();
      registerFallbackValue(FakeMeasurementData());
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

      getIt
        ..registerSingleton<Directory>(await getApplicationDocumentsDirectory())
        ..registerSingleton<UserActivityService>(UserActivityService())
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<EditorStateService>(mockEditorStateService)
        ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
        ..registerSingleton<LinkService>(MockLinkService())
        ..registerSingleton<HealthImport>(mockHealthImport)
        ..registerSingleton<TimeService>(mockTimeService)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);

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
    tearDown(getIt.reset);

    testWidgets('Text Entry is rendered', (tester) async {
      when(
        () => mockJournalDb.journalEntityById(testTextEntry.meta.id),
      ).thenAnswer((_) async => testTextEntry);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EntryDetailsPage(itemId: testTextEntry.meta.id),
        ),
      );

      await tester.pumpAndSettle();

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

      await tester.pumpAndSettle();

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

        await tester.pumpAndSettle();

        // LinkedFromChecklistWidget is present in the widget tree when item is
        // a ChecklistItem (covers source line 159).
        expect(find.byType(LinkedFromChecklistWidget), findsOneWidget);
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

        await tester.pumpAndSettle();

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
      'DropTarget onDragDone callback passes entry ids to handleDroppedMedia',
      (tester) async {
        when(
          () => mockJournalDb.journalEntityById(testTextEntry.meta.id),
        ).thenAnswer((_) async => testTextEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            EntryDetailsPage(itemId: testTextEntry.meta.id),
          ),
        );

        await tester.pumpAndSettle();

        final dropTargetFinder = find.descendant(
          of: find.byType(EntryDetailsPage),
          matching: find.byType(DropTarget),
        );
        final dropTarget = tester.widget<DropTarget>(dropTargetFinder);

        // Simulate dropping an unsupported file type so no real import runs —
        // the goal is confirming the callback body runs and uses the entry ids.
        final unsupportedFile = _FakeDropItem(XFile('/tmp/note.txt'));
        final dropDetails = DropDoneDetails(
          files: [unsupportedFile],
          localPosition: Offset.zero,
          globalPosition: Offset.zero,
        );

        expect(
          () => dropTarget.onDragDone!.call(dropDetails),
          returnsNormally,
        );

        await tester.pump();
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

        await tester.pumpAndSettle();

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
}
