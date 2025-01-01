import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_measurables_chart.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';
import '../../test_data/test_data.dart';
import '../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var mockJournalDb = MockJournalDb();
  final mockSecureStorage = MockSecureStorage();
  final mockPersistenceLogic = MockPersistenceLogic();
  final mockEntitiesCacheService = MockEntitiesCacheService();

  group('DashboardMeasurablesChart Widget Tests - ', () {
    setUp(() {
      mockJournalDb = MockJournalDb();

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
        ..registerSingleton<NavService>(MockNavService())
        ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
        ..registerSingleton<SecureStorage>(mockSecureStorage);

      when(() => mockJournalDb.getConfigFlag(any()))
          .thenAnswer((_) async => false);

      when(mockJournalDb.watchMeasurableDataTypes).thenAnswer(
        (_) => Stream<List<MeasurableDataType>>.fromIterable([
          [measurableWater],
        ]),
      );
    });
    tearDown(getIt.reset);

    testWidgets(
        'chart is rendered with measurement entry, aggregation sum by day',
        (tester) async {
      when(
        () => mockJournalDb.watchMeasurementsByType(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
          type: measurableChocolate.id,
        ),
      ).thenAnswer(
        (_) => Stream<List<JournalEntity>>.fromIterable([
          [testMeasurementChocolateEntry],
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

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          MeasurablesBarChart(
            dashboardId: 'dashboardId',
            rangeStart: DateTime(2022),
            rangeEnd: DateTime(2023),
            measurableDataTypeId: measurableChocolate.id,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // measurement entry displays expected date
      expect(
        find.text('${measurableChocolate.displayName} [dailySum]'),
        findsOneWidget,
      );
    });

    testWidgets(
        'chart is rendered with measurement entry, aggregation sum by hour',
        (tester) async {
      when(
        () => mockJournalDb.watchMeasurementsByType(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
          type: measurableChocolate.id,
        ),
      ).thenAnswer(
        (_) => Stream<List<JournalEntity>>.fromIterable([
          [testMeasurementChocolateEntry],
        ]),
      );

      when(
        () => mockJournalDb.watchMeasurableDataTypeById(
          measurableChocolate.id,
        ),
      ).thenAnswer(
        (_) => Stream<MeasurableDataType>.fromIterable([
          measurableChocolate.copyWith(
            aggregationType: AggregationType.hourlySum,
          ),
        ]),
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          MeasurablesBarChart(
            dashboardId: 'dashboardId',
            rangeStart: DateTime(2022),
            rangeEnd: DateTime(2023),
            measurableDataTypeId: measurableChocolate.id,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // measurement entry displays expected date
      expect(
        find.text('${measurableChocolate.displayName} [hourlySum]'),
        findsOneWidget,
      );
    });

    testWidgets('chart is rendered with measurement entry, aggregation none',
        (tester) async {
      when(
        () => mockJournalDb.watchMeasurementsByType(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
          type: measurableCoverage.id,
        ),
      ).thenAnswer(
        (_) => Stream<List<JournalEntity>>.fromIterable([
          [testMeasuredCoverageEntry],
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
          MeasurablesBarChart(
            dashboardId: 'dashboardId',
            rangeStart: DateTime(2022),
            rangeEnd: DateTime(2023),
            measurableDataTypeId: measurableCoverage.id,
            enableCreate: true,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // measurement entry displays expected date
      expect(
        find.text(measurableCoverage.displayName),
        findsOneWidget,
      );
    });

    testWidgets(
        'chart is rendered with measurement entry, aggregation daily max',
        (tester) async {
      when(
        () => mockJournalDb.watchMeasurementsByType(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
          type: measurablePullUps.id,
        ),
      ).thenAnswer(
        (_) => Stream<List<JournalEntity>>.fromIterable([
          [testMeasuredPullUpsEntry],
        ]),
      );

      when(
        () => mockJournalDb.watchMeasurableDataTypeById(
          measurablePullUps.id,
        ),
      ).thenAnswer(
        (_) => Stream<MeasurableDataType>.fromIterable([
          measurablePullUps,
        ]),
      );

      final delegate = BeamerDelegate(
        locationBuilder: RoutesLocationBuilder(
          routes: {
            '/': (context, state, data) => Container(),
          },
        ).call,
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BeamerProvider(
            routerDelegate: delegate,
            child: MeasurablesBarChart(
              dashboardId: 'dashboardId',
              rangeStart: DateTime(2022),
              rangeEnd: DateTime(2023),
              measurableDataTypeId: measurablePullUps.id,
              enableCreate: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // measurement entry displays expected date
      expect(
        find.text('${measurablePullUps.displayName} [dailyMax]'),
        findsOneWidget,
      );

      final addIconFinder = find.byType(IconButton);
      await tester.tap(addIconFinder);
      await tester.pumpAndSettle();
    });
  });
}
