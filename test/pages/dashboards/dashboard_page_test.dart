import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/audio/player_cubit.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/dashboards/dashboard_page.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/themes/themes_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';
import '../../test_data/test_data.dart';
import '../../utils/utils.dart';
import '../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var mockJournalDb = MockJournalDb();
  var mockPersistenceLogic = MockPersistenceLogic();

  group('DashboardPage Widget Tests - ', () {
    setUpAll(() {
      registerFallbackValue(FakeMeasurementData());
      ensureMpvInitialized();
    });

    setUp(() {
      mockJournalDb = mockJournalDbWithMeasurableTypes([
        measurableWater,
        measurableChocolate,
      ]);
      mockPersistenceLogic = MockPersistenceLogic();

      when(
        () => mockJournalDb.watchMeasurableDataTypeById(any()),
      ).thenAnswer(
        (_) => Stream<MeasurableDataType>.fromIterable([]),
      );

      final mockTagsService = mockTagsServiceWithTags([]);
      final mockTimeService = MockTimeService();
      final mockHealthImport = MockHealthImport();

      getIt
        ..registerSingleton<ThemesService>(ThemesService(watch: false))
        ..registerSingleton<LoggingDb>(MockLoggingDb())
        ..registerSingleton<TagsService>(mockTagsService)
        ..registerSingleton<TimeService>(mockTimeService)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<HealthImport>(mockHealthImport)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);

      when(
        () => mockJournalDb.watchDashboardById(testDashboardConfig.id),
      ).thenAnswer(
        (_) => Stream<List<DashboardDefinition>>.fromIterable([
          <DashboardDefinition>[testDashboardConfig]
        ]),
      );

      when(
        () => mockJournalDb.watchEntityById(testTask.meta.id),
      ).thenAnswer(
        (_) => Stream<JournalEntity>.fromIterable([testTask]),
      );

      when(
        () => mockJournalDb.watchJournalEntitiesByTag(
          tagId: any(named: 'tagId'),
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer(
        (_) => Stream<List<JournalEntity>>.fromIterable([]),
      );

      when(
        () => mockJournalDb.watchSurveysByType(
          type: any(named: 'type'),
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer(
        (_) => Stream<List<JournalEntity>>.fromIterable([]),
      );

      when(
        () => mockJournalDb.watchWorkouts(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer(
        (_) => Stream<List<JournalEntity>>.fromIterable([]),
      );

      when(
        () => mockJournalDb.watchQuantitativeByType(
          type: any(named: 'type'),
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer(
        (_) => Stream<List<JournalEntity>>.fromIterable([]),
      );

      when(
        () => mockHealthImport.fetchHealthDataDelta(any()),
      ).thenAnswer((_) async {});

      when(mockHealthImport.getWorkoutsHealthDataDelta)
          .thenAnswer((_) async {});

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
          private: false,
        );
      }

      when(mockCreateMeasurementEntry).thenAnswer((_) async => null);

      when(
        () => mockJournalDb.watchJournalEntities(
          types: entryTypes.toList(),
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
            child: DashboardPage(dashboardId: testDashboardConfig.id),
          ),
        ),
      );

      await tester.pumpAndSettle();
    });
  });
}
