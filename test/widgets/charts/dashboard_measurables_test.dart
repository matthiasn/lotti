import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_measurables_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_bar_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_line_chart.dart';
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
    });
    tearDown(getIt.reset);

    for (final testCase in [
      (
        measurableChocolate,
        AggregationType.dailySum,
        '${measurableChocolate.displayName} [dailySum]',
      ),
      (
        measurableChocolate,
        AggregationType.hourlySum,
        '${measurableChocolate.displayName} [hourlySum]',
      ),
      (
        measurableCoverage,
        AggregationType.none,
        measurableCoverage.displayName,
      ),
      (
        measurablePullUps,
        AggregationType.dailyMax,
        '${measurablePullUps.displayName} [dailyMax]',
      ),
    ]) {
      final expectedChartType =
          testCase.$2 == AggregationType.none ? 'line' : 'bar';
      testWidgets(
          'renders chart with ${testCase.$2.name} aggregation and $expectedChartType chart',
          (tester) async {
        final measurable = testCase.$2 == AggregationType.none
            ? testCase.$1
            : testCase.$1.copyWith(aggregationType: testCase.$2);

        when(
          () => mockJournalDb.getMeasurementsByType(
            rangeStart: any(named: 'rangeStart'),
            rangeEnd: any(named: 'rangeEnd'),
            type: testCase.$1.id,
          ),
        ).thenAnswer((_) async => [testMeasurementChocolateEntry]);

        when(
          () => mockJournalDb.getMeasurableDataTypeById(testCase.$1.id),
        ).thenAnswer((_) async => measurable);

        final needsBeamer = testCase.$2 == AggregationType.dailyMax;

        Widget chart = MeasurablesBarChart(
          dashboardId: 'dashboardId',
          rangeStart: DateTime(2022),
          rangeEnd: DateTime(2023),
          measurableDataTypeId: testCase.$1.id,
          enableCreate: needsBeamer,
        );

        if (needsBeamer) {
          chart = BeamerProvider(
            routerDelegate: BeamerDelegate(
              locationBuilder: RoutesLocationBuilder(
                routes: {
                  '/': (context, state, data) => Container(),
                },
              ).call,
            ),
            child: chart,
          );
        }

        await tester.pumpWidget(makeTestableWidgetWithScaffold(chart));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump();

        expect(find.text(testCase.$3), findsOneWidget);
        // 'none' aggregation uses line chart, all others use bar chart
        if (testCase.$2 == AggregationType.none) {
          expect(find.byType(TimeSeriesLineChart), findsOneWidget);
        } else {
          expect(find.byType(TimeSeriesBarChart), findsOneWidget);
        }

        expect(
          find.byType(MeasurablesBarChart),
          findsOneWidget,
        );
      });
    }

    testWidgets('displays description stacked under title', (tester) async {
      when(
        () => mockJournalDb.getMeasurementsByType(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
          type: measurableWater.id,
        ),
      ).thenAnswer((_) async => []);

      when(() => mockJournalDb.getMeasurableDataTypeById(measurableWater.id))
          .thenAnswer((_) async => measurableWater);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          MeasurablesBarChart(
            dashboardId: 'dashboardId',
            rangeStart: DateTime(2022),
            rangeEnd: DateTime(2023),
            measurableDataTypeId: measurableWater.id,
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      expect(
        find.text('${measurableWater.displayName} [dailySum]'),
        findsOneWidget,
      );
      expect(find.text(measurableWater.description), findsOneWidget);
    });
  });
}
