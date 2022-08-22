import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/audio/player_cubit.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/journal/journal_page.dart';
import 'package:lotti/routes/router.gr.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/themes/themes.dart';
import 'package:lotti/themes/themes_service.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:mocktail/mocktail.dart';

import '../../journal_test_data/test_data.dart';
import '../../mocks/mocks.dart';
import '../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var mockJournalDb = MockJournalDb();
  var mockPersistenceLogic = MockPersistenceLogic();
  var mockAppRouter = MockAppRouter();

  group('JournalPage Widget Tests - ', () {
    setUpAll(() {
      registerFallbackValue(FakeMeasurementData());
    });

    setUp(() {
      mockJournalDb = mockJournalDbWithMeasurableTypes([
        measurableWater,
        measurableChocolate,
      ]);
      mockPersistenceLogic = MockPersistenceLogic();

      mockAppRouter = MockAppRouter();
      when(mockAppRouter.pop).thenAnswer((invocation) async => true);

      final mockTagsService = mockTagsServiceWithTags([]);
      final mockTimeService = MockTimeService();

      getIt
        ..registerSingleton<ThemesService>(ThemesService(watch: false))
        ..registerSingleton<LoggingDb>(MockLoggingDb())
        ..registerSingleton<TagsService>(mockTagsService)
        ..registerSingleton<TimeService>(mockTimeService)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
        ..registerSingleton<AppRouter>(mockAppRouter);

      when(() => mockJournalDb.getMeasurableDataTypeById(measurableWater.id))
          .thenAnswer((_) async => measurableWater);

      when(mockTagsService.watchTags).thenAnswer(
        (_) => Stream<List<TagEntity>>.fromIterable([[]]),
      );

      when(
        () => mockJournalDb.watchConfigFlags(),
      ).thenAnswer(
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

      when(
        () => mockJournalDb.watchEntityById(testTask.meta.id),
      ).thenAnswer(
        (_) => Stream<JournalEntity>.fromIterable([testTask]),
      );

      when(
        () => mockJournalDb.watchLinkedTotalDuration(
          linkedFrom: testTask.meta.id,
        ),
      ).thenAnswer(
        (_) => Stream<Map<String, Duration>>.fromIterable([
          {testTask.meta.id: const Duration(hours: 1)}
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
        );
      }

      when(mockCreateMeasurementEntry).thenAnswer((_) async => null);

      when(
        () => mockJournalDb.watchJournalEntities(
          types: defaultTypes.toList(),
          starredStatuses: [true, false],
          privateStatuses: [true, false],
          flaggedStatuses: [1, 0],
          ids: null,
        ),
      ).thenAnswer(
        (_) => Stream<List<JournalEntity>>.fromIterable([
          [testTextEntry]
        ]),
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<AudioPlayerCubit>(
            create: (BuildContext context) => AudioPlayerCubit(),
            lazy: false,
            child: const JournalPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // TODO: test that entry text is rendered

      // test entry displays expected date
      expect(
        find.text(df.format(testTextEntry.meta.dateFrom)),
        findsOneWidget,
      );

      // test entry displays duration of one hour
      expect(
        find.text('1:00:00'),
        findsOneWidget,
      );

      // test text entry is starred
      expect(
        (tester.firstWidget(find.byIcon(MdiIcons.star)) as Icon).color,
        darkTheme.starredGold,
      );
    });

    testWidgets('page is rendered with task entry', (tester) async {
      Future<MeasurementEntry?> mockCreateMeasurementEntry() {
        return mockPersistenceLogic.createMeasurementEntry(
          data: any(named: 'data'),
        );
      }

      when(
        () => mockJournalDb.watchJournalEntities(
          types: defaultTypes.toList(),
          starredStatuses: [true, false],
          privateStatuses: [true, false],
          flaggedStatuses: [1, 0],
          ids: null,
        ),
      ).thenAnswer(
        (_) => Stream<List<JournalEntity>>.fromIterable([
          [testTask]
        ]),
      );

      when(mockCreateMeasurementEntry).thenAnswer((_) async => null);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<AudioPlayerCubit>(
            create: (BuildContext context) => AudioPlayerCubit(),
            lazy: false,
            child: const JournalPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // task entry displays expected date
      expect(
        find.text(df.format(testTask.meta.dateFrom)),
        findsOneWidget,
      );

      // test task displays progress bar with 2 hours progress and 3 hours total
      final progressBar =
          tester.firstWidget(find.byType(ProgressBar)) as ProgressBar;
      expect(progressBar, isNotNull);
      expect(progressBar.progress, const Duration(hours: 2));
      expect(progressBar.total, const Duration(hours: 3));

      // test task title is displayed
      expect(
        find.text(testTask.data.title),
        findsOneWidget,
      );

      // test task is starred
      expect(
        (tester.firstWidget(find.byIcon(MdiIcons.star)) as Icon).color,
        darkTheme.starredGold,
      );
    });

    testWidgets('page is rendered with weight entry', (tester) async {
      Future<MeasurementEntry?> mockCreateMeasurementEntry() {
        return mockPersistenceLogic.createMeasurementEntry(
          data: any(named: 'data'),
        );
      }

      when(
        () => mockJournalDb.watchJournalEntities(
          types: defaultTypes.toList(),
          starredStatuses: [true, false],
          privateStatuses: [true, false],
          flaggedStatuses: [1, 0],
          ids: null,
        ),
      ).thenAnswer(
        (_) => Stream<List<JournalEntity>>.fromIterable([
          [testWeightEntry]
        ]),
      );

      when(mockCreateMeasurementEntry).thenAnswer((_) async => null);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<AudioPlayerCubit>(
            create: (BuildContext context) => AudioPlayerCubit(),
            lazy: false,
            child: const JournalPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // task entry displays expected date
      expect(
        find.text(df.format(testWeightEntry.meta.dateFrom)),
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
    });

    testWidgets(
        'page is rendered with measurement entry, aggregation sum by day',
        (tester) async {
      Future<MeasurementEntry?> mockCreateMeasurementEntry() {
        return mockPersistenceLogic.createMeasurementEntry(
          data: any(named: 'data'),
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
        () => mockJournalDb.watchMeasurementsByType(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
          type: measurableChocolate.id,
        ),
      ).thenAnswer(
        (_) => Stream<List<JournalEntity>>.fromIterable([[]]),
      );

      when(
        () => mockJournalDb.getMeasurableDataTypeById(any()),
      ).thenAnswer((_) async => measurableChocolate);

      when(
        () => mockJournalDb.watchJournalEntities(
          types: defaultTypes.toList(),
          starredStatuses: [true, false],
          privateStatuses: [true, false],
          flaggedStatuses: [1, 0],
          ids: null,
        ),
      ).thenAnswer(
        (_) => Stream<List<JournalEntity>>.fromIterable([
          [testMeasurementChocolateEntry]
        ]),
      );

      when(
        () => mockJournalDb.watchMeasurableDataTypeById(
          measurableChocolate.id,
        ),
      ).thenAnswer(
        (_) => Stream<MeasurableDataType>.fromIterable([
          measurableChocolate,
        ]),
      );

      when(mockCreateMeasurementEntry).thenAnswer((_) async => null);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<AudioPlayerCubit>(
            create: (BuildContext context) => AudioPlayerCubit(),
            lazy: false,
            child: const JournalPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // measurement entry displays expected date
      expect(
        find.text(df.format(testMeasurementChocolateEntry.meta.dateFrom)),
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
      expect(
        (tester.firstWidget(find.byIcon(MdiIcons.security)) as Icon).color,
        darkTheme.error,
      );
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
        () => mockJournalDb.watchMeasurementsByType(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
          type: measurableCoverage.id,
        ),
      ).thenAnswer(
        (_) => Stream<List<JournalEntity>>.fromIterable([[]]),
      );

      when(
        () => mockJournalDb.getMeasurableDataTypeById(any()),
      ).thenAnswer((_) async => measurableCoverage);

      when(
        () => mockJournalDb.watchJournalEntities(
          types: defaultTypes.toList(),
          starredStatuses: [true, false],
          privateStatuses: [true, false],
          flaggedStatuses: [1, 0],
          ids: null,
        ),
      ).thenAnswer(
        (_) => Stream<List<JournalEntity>>.fromIterable([
          [testMeasuredCoverageEntry]
        ]),
      );

      when(
        () => mockJournalDb.watchMeasurableDataTypeById(
          measurableCoverage.id,
        ),
      ).thenAnswer(
        (_) => Stream<MeasurableDataType>.fromIterable([
          measurableCoverage,
        ]),
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<AudioPlayerCubit>(
            create: (BuildContext context) => AudioPlayerCubit(),
            lazy: false,
            child: const JournalPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // measurement entry displays expected date
      expect(
        find.text(df.format(testMeasurementChocolateEntry.meta.dateFrom)),
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
