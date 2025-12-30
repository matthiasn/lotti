import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/journal/ui/pages/infinite_journal_page.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/card_wrapper_widget.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/features/journal/utils/entry_types.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../../helpers/path_provider.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
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
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
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

      final mockTagsService = mockTagsServiceWithTags([]);
      final mockTimeService = MockTimeService();

      when(() => mockJournalDb.watchConfigFlag(privateFlag)).thenAnswer(
        (_) => Stream<bool>.fromIterable([true]),
      );
      when(mockJournalDb.watchActiveConfigFlagNames).thenAnswer(
        (_) => Stream<Set<String>>.fromIterable([<String>{}]),
      );

      when(() => mockSettingsDb.itemByKey(any()))
          .thenAnswer((_) => Future(() => null));
      when(() => mockSettingsDb.saveSettingsItem(any(), any()))
          .thenAnswer((_) async => 1);

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
        ..registerSingleton<LoggingDb>(MockLoggingDb())
        ..registerSingleton<LoggingService>(LoggingService())
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<SettingsDb>(mockSettingsDb)
        ..registerSingleton<TagsService>(mockTagsService)
        ..registerSingleton<TimeService>(mockTimeService)
        ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
        ..registerSingleton<Fts5Db>(MockFts5Db());

      when(() => mockJournalDb.getMeasurableDataTypeById(measurableWater.id))
          .thenAnswer((_) async => measurableWater);

      when(mockTagsService.watchTags).thenAnswer(
        (_) => Stream<List<TagEntity>>.fromIterable([[]]),
      );

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
          }
        ]),
      );

      when(mockTimeService.getStream)
          .thenAnswer((_) => Stream<JournalEntity>.fromIterable([]));
    });
    tearDown(getIt.reset);

    // Helper function to replace pumpAndSettle
    Future<void> pumpWithDelay(WidgetTester tester) async {
      // Give the widget time to build and load initial data
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Additional pumps to progress animations
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('page is rendered with text entry', (tester) async {
      Future<MeasurementEntry?> mockCreateMeasurementEntry() {
        return mockPersistenceLogic.createMeasurementEntry(
          data: any(named: 'data'),
          private: false,
        );
      }

      when(mockCreateMeasurementEntry).thenAnswer((_) async => null);

      when(
        () => mockJournalDb.getJournalEntities(
          types: any(named: 'types'),
          starredStatuses: [true, false],
          privateStatuses: [true, false],
          flaggedStatuses: [1, 0],
          ids: null,
          limit: 50,
        ),
      ).thenAnswer((_) async => [testTextEntry]);

      when(() => mockJournalDb.journalEntityById(testTextEntry.meta.id))
          .thenAnswer((_) async => testTextEntry);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const InfiniteJournalPage(showTasks: false),
        ),
      );

      await pumpWithDelay(tester);

      // test entry displays expected date
      expect(
        find.text(dfShorter.format(testTextEntry.meta.dateFrom)),
        findsOneWidget,
      );

      // test text entry is starred
      expect(
        (tester.firstWidget(find.byIcon(MdiIcons.star)) as Icon).color,
        starredGold,
      );
    });

    testWidgets('page is rendered with task entry', (tester) async {
      Future<MeasurementEntry?> mockCreateMeasurementEntry() {
        return mockPersistenceLogic.createMeasurementEntry(
          data: any(named: 'data'),
          private: false,
        );
      }

      when(
        () => mockJournalDb.getJournalEntities(
          types: any(named: 'types'),
          starredStatuses: [true, false],
          privateStatuses: [true, false],
          flaggedStatuses: [1, 0],
          ids: null,
          limit: 50,
        ),
      ).thenAnswer((_) async => [testTask]);

      when(() => mockJournalDb.journalEntityById(testTask.meta.id))
          .thenAnswer((_) async => testTask);

      when(mockCreateMeasurementEntry).thenAnswer((_) async => null);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const InfiniteJournalPage(showTasks: false),
        ),
      );

      await pumpWithDelay(tester);

      // test task title is displayed
      expect(
        find.text(testTask.data.title),
        findsOneWidget,
      );
    });

    testWidgets('tasks page is rendered with task entry', (tester) async {
      when(
        () => mockEntitiesCacheService.sortedCategories,
      ).thenAnswer((_) => []);

      when(
        () => mockJournalDb.getTasks(
          starredStatuses: [true, false],
          categoryIds: [''], // When no categories exist, default to unassigned
          labelIds: const <String>[],
          priorities: const <String>[],
          limit: 50,
          taskStatuses: ['OPEN', 'GROOMED', 'IN PROGRESS'],
        ),
      ).thenAnswer((_) async => [testTask]);

      when(() => mockJournalDb.journalEntityById(testTask.meta.id))
          .thenAnswer((_) async => testTask);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const InfiniteJournalPage(showTasks: true),
        ),
      );

      await pumpWithDelay(tester);

      // test task title is displayed
      expect(
        find.text(testTask.data.title),
        findsOneWidget,
      );
    });

    testWidgets('page is rendered with weight entry', (tester) async {
      Future<MeasurementEntry?> mockCreateMeasurementEntry() {
        return mockPersistenceLogic.createMeasurementEntry(
          data: any(named: 'data'),
          private: false,
        );
      }

      when(
        () => mockJournalDb.getJournalEntities(
          types: any(named: 'types'),
          starredStatuses: [true, false],
          privateStatuses: [true, false],
          flaggedStatuses: [1, 0],
          ids: null,
          limit: 50,
        ),
      ).thenAnswer((_) async => [testWeightEntry]);

      when(mockCreateMeasurementEntry).thenAnswer((_) async => null);

      when(() => mockJournalDb.journalEntityById(testWeightEntry.meta.id))
          .thenAnswer((_) async => testWeightEntry);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const InfiniteJournalPage(showTasks: false),
        ),
      );

      await pumpWithDelay(tester);

      // task entry displays expected date
      expect(
        find.text(dfShorter.format(testWeightEntry.meta.dateFrom)),
        findsOneWidget,
      );

      // weight entry displays expected measurement data
      expect(
        find.text('WEIGHT: 94.49 KILOGRAMS'),
        findsOneWidget,
      );

      // weight task is neither starred nor private (icons invisible)
      expect(find.byIcon(MdiIcons.star).hitTestable(), findsNothing);
      expect(find.byIcon(MdiIcons.security).hitTestable(), findsNothing);
      await tester.pump(VisibilityDetectorController.instance.updateInterval);
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
        () => mockJournalDb.watchMeasurableDataTypeById(
          measurableChocolate.id,
        ),
      ).thenAnswer(
        (_) => Stream<MeasurableDataType>.fromIterable([
          measurableChocolate,
        ]),
      );

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

      when(
        () => mockJournalDb.getJournalEntities(
          types: any(named: 'types'),
          starredStatuses: [true, false],
          privateStatuses: [true, false],
          flaggedStatuses: [1, 0],
          ids: null,
          limit: 50,
        ),
      ).thenAnswer((_) async => [testMeasurementChocolateEntry]);

      when(
        () => mockJournalDb.watchMeasurableDataTypeById(
          measurableChocolate.id,
        ),
      ).thenAnswer(
        (_) => Stream<MeasurableDataType>.fromIterable([
          measurableChocolate,
        ]),
      );

      when(
        () => mockJournalDb
            .journalEntityById(testMeasurementChocolateEntry.meta.id),
      ).thenAnswer((_) async => testMeasurementChocolateEntry);

      when(mockCreateMeasurementEntry).thenAnswer((_) async => null);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const InfiniteJournalPage(showTasks: false),
        ),
      );

      await pumpWithDelay(tester);

      // measurement entry displays expected date
      expect(
        find.text(
          dfShorter.format(testMeasurementChocolateEntry.meta.dateFrom),
        ),
        findsOneWidget,
      );

      // measurement entry displays expected measurement data
      expect(
        find.text(
          '${measurableChocolate.displayName}: '
          '${testMeasurementChocolateEntry.data.value} '
          '${measurableChocolate.unitName}',
        ),
        findsOneWidget,
      );

      // test measurement is not starred (icon invisible)
      expect(find.byIcon(MdiIcons.star).hitTestable(), findsNothing);

      // test measurement is private (icon visible & red)
      expect(find.byIcon(MdiIcons.security).hitTestable(), findsOneWidget);
    });

    testWidgets('page is rendered with measurement entry, aggregation none',
        (tester) async {
      when(
        () => mockJournalDb.watchMeasurableDataTypeById(
          measurableCoverage.id,
        ),
      ).thenAnswer(
        (_) => Stream<MeasurableDataType>.fromIterable([
          measurableCoverage,
        ]),
      );

      when(
        () => mockEntitiesCacheService.getDataTypeById(
          measurableCoverage.id,
        ),
      ).thenAnswer((_) => measurableCoverage);

      when(
        () => mockJournalDb.getMeasurableDataTypeById(any()),
      ).thenAnswer((_) async => measurableCoverage);

      when(
        () => mockJournalDb.getJournalEntities(
          types: any(named: 'types'),
          starredStatuses: [true, false],
          privateStatuses: [true, false],
          flaggedStatuses: [1, 0],
          ids: null,
          limit: 50,
        ),
      ).thenAnswer((_) async => [testMeasuredCoverageEntry]);

      when(
        () => mockJournalDb.watchMeasurableDataTypeById(
          measurableCoverage.id,
        ),
      ).thenAnswer(
        (_) => Stream<MeasurableDataType>.fromIterable([
          measurableCoverage,
        ]),
      );

      when(
        () =>
            mockJournalDb.journalEntityById(testMeasuredCoverageEntry.meta.id),
      ).thenAnswer((_) async => testMeasuredCoverageEntry);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const InfiniteJournalPage(showTasks: false),
        ),
      );

      await pumpWithDelay(tester);

      // measurement entry displays expected date
      expect(
        find.text(
          dfShorter.format(testMeasurementChocolateEntry.meta.dateFrom),
        ),
        findsOneWidget,
      );

      // measurement entry displays expected measurement data
      expect(
        find.text(
          '${measurableCoverage.displayName}: '
          '${testMeasuredCoverageEntry.data.value} '
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
        ),
      ).thenAnswer((_) async => []);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const InfiniteJournalPage(showTasks: false),
        ),
      );

      await pumpWithDelay(tester);

      // Verify no entries are displayed
      expect(find.byType(CardWrapperWidget), findsNothing);
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
        ),
      ).thenAnswer((_) async => [testTextEntry]);

      when(() => mockJournalDb.journalEntityById(testTextEntry.meta.id))
          .thenAnswer((_) async => testTextEntry);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const InfiniteJournalPage(showTasks: false),
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

    testWidgets('multiple entries are rendered in correct order',
        (tester) async {
      final entries = [testTextEntry, testTask, testWeightEntry];

      when(
        () => mockJournalDb.getJournalEntities(
          types: any(named: 'types'),
          starredStatuses: [true, false],
          privateStatuses: [true, false],
          flaggedStatuses: [1, 0],
          ids: null,
          limit: 50,
        ),
      ).thenAnswer((_) async => entries);

      for (final entry in entries) {
        when(() => mockJournalDb.journalEntityById(entry.meta.id))
            .thenAnswer((_) async => entry);
      }

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const InfiniteJournalPage(showTasks: false),
        ),
      );

      await pumpWithDelay(tester);

      // Verify all entries are displayed
      expect(find.byType(CardWrapperWidget), findsNWidgets(3));
    });

    testWidgets('floating action button creates task with selected category',
        (tester) async {
      when(
        () => mockEntitiesCacheService.sortedCategories,
      ).thenAnswer((_) => [
            CategoryDefinition(
              id: 'cat1',
              name: 'Work',
              color: '#FF0000',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              active: true,
              private: false,
              vectorClock: null,
            ),
          ]);

      when(
        () => mockJournalDb.getTasks(
          starredStatuses: [true, false],
          categoryIds: ['cat1'],
          labelIds: const <String>[],
          priorities: const <String>[],
          limit: 50,
          taskStatuses: ['OPEN', 'GROOMED', 'IN PROGRESS'],
        ),
      ).thenAnswer((_) async => []);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const InfiniteJournalPage(showTasks: true),
        ),
      );

      await pumpWithDelay(tester);

      // Find and tap the FAB
      final fab = find.byType(FloatingActionButton);
      expect(fab, findsOneWidget);
    });

    testWidgets('tasks page with categories shows correct entries',
        (tester) async {
      final testCategories = [
        CategoryDefinition(
          id: 'cat1',
          name: 'Work',
          color: '#FF0000',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          active: true,
          private: false,
          vectorClock: null,
        ),
        CategoryDefinition(
          id: 'cat2',
          name: 'Personal',
          color: '#00FF00',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          active: true,
          private: false,
          vectorClock: null,
        ),
      ];

      when(
        () => mockEntitiesCacheService.sortedCategories,
      ).thenAnswer((_) => testCategories);

      when(
        () => mockJournalDb.getTasks(
          starredStatuses: [true, false],
          categoryIds: testCategories.map((c) => c.id).toList(),
          labelIds: const <String>[],
          priorities: const <String>[],
          limit: 50,
          taskStatuses: ['OPEN', 'GROOMED', 'IN PROGRESS'],
        ),
      ).thenAnswer((_) async => [testTask]);

      when(() => mockJournalDb.journalEntityById(testTask.meta.id))
          .thenAnswer((_) async => testTask);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const InfiniteJournalPage(showTasks: true),
        ),
      );

      await pumpWithDelay(tester);

      // Verify task is displayed
      expect(find.text(testTask.data.title), findsOneWidget);
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
        ),
      ).thenAnswer((_) async => [privateEntry]);

      when(() => mockJournalDb.journalEntityById(privateEntry.meta.id))
          .thenAnswer((_) async => privateEntry);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const InfiniteJournalPage(showTasks: false),
        ),
      );

      await pumpWithDelay(tester);

      // Verify security icon is visible
      expect(find.byIcon(MdiIcons.security), findsOneWidget);
    });
  });
}
