import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/journal/ui/pages/infinite_journal_page.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/features/speech/state/asr_service.dart';
import 'package:lotti/features/speech/state/player_cubit.dart';
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

import '../../helpers/path_provider.dart';
import '../../mocks/mocks.dart';
import '../../test_data/test_data.dart';
import '../../utils/utils.dart';
import '../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var mockJournalDb = MockJournalDb();
  final mockSettingsDb = MockSettingsDb();
  var mockPersistenceLogic = MockPersistenceLogic();
  final mockEntitiesCacheService = MockEntitiesCacheService();
  final mockUpdateNotifications = MockUpdateNotifications();

  final entryTypeStrings = entryTypes.toList();

  group('JournalPage Widget Tests - ', () {
    setUpAll(() {
      setFakeDocumentsPath();
      ensureMpvInitialized();

      registerFallbackValue(FakeMeasurementData());
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
    });

    setUp(() async {
      mockJournalDb = mockJournalDbWithMeasurableTypes([
        measurableWater,
        measurableChocolate,
      ]);

      when(mockJournalDb.watchJournalCount)
          .thenAnswer((_) => Stream<int>.fromIterable([1]));

      mockPersistenceLogic = MockPersistenceLogic();

      final mockTagsService = mockTagsServiceWithTags([]);
      final mockTimeService = MockTimeService();

      when(() => mockJournalDb.watchConfigFlag(privateFlag)).thenAnswer(
        (_) => Stream<bool>.fromIterable([true]),
      );

      when(mockJournalDb.watchCountImportFlagEntries)
          .thenAnswer((_) => Stream<int>.fromIterable([42]));

      when(() => mockSettingsDb.itemByKey(any()))
          .thenAnswer((_) => Future(() => null));

      when(mockJournalDb.getInProgressTasksCount).thenAnswer((_) async => 42);

      getIt
        ..registerSingleton<Directory>(await getApplicationDocumentsDirectory())
        ..registerSingleton<UserActivityService>(UserActivityService())
        ..registerSingleton<LoggingDb>(MockLoggingDb())
        ..registerSingleton<LoggingService>(LoggingService())
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<SettingsDb>(mockSettingsDb)
        ..registerSingleton<AsrService>(MockAsrService())
        ..registerSingleton<TagsService>(mockTagsService)
        ..registerSingleton<TimeService>(mockTimeService)
        ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);

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
          types: entryTypeStrings,
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
          BlocProvider<AudioPlayerCubit>(
            create: (BuildContext context) => AudioPlayerCubit(),
            lazy: false,
            child: const InfiniteJournalPage(showTasks: false),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

      // TODO: test that entry text is rendered

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
          types: entryTypeStrings,
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
          BlocProvider<AudioPlayerCubit>(
            create: (BuildContext context) => AudioPlayerCubit(),
            lazy: false,
            child: const InfiniteJournalPage(showTasks: false),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

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
          categoryIds: [],
          limit: 50,
          taskStatuses: ['OPEN', 'GROOMED', 'IN PROGRESS'],
        ),
      ).thenAnswer((_) async => [testTask]);

      when(() => mockJournalDb.journalEntityById(testTask.meta.id))
          .thenAnswer((_) async => testTask);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<AudioPlayerCubit>(
            create: (BuildContext context) => AudioPlayerCubit(),
            lazy: false,
            child: const InfiniteJournalPage(showTasks: true),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

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
          types: entryTypeStrings,
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
          BlocProvider<AudioPlayerCubit>(
            create: (BuildContext context) => AudioPlayerCubit(),
            lazy: false,
            child: const InfiniteJournalPage(showTasks: false),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

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
          types: entryTypeStrings,
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
          BlocProvider<AudioPlayerCubit>(
            create: (BuildContext context) => AudioPlayerCubit(),
            lazy: false,
            child: const InfiniteJournalPage(showTasks: false),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

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
          types: entryTypeStrings,
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
          BlocProvider<AudioPlayerCubit>(
            create: (BuildContext context) => AudioPlayerCubit(),
            lazy: false,
            child: const InfiniteJournalPage(showTasks: false),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

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
  });
}
