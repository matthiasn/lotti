import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/routes/router.gr.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/sync/secure_storage.dart';
import 'package:lotti/themes/themes_service.dart';
import 'package:lotti/widgets/charts/dashboard_measurables_chart.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks.dart';
import '../../test_data.dart';
import '../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var mockJournalDb = MockJournalDb();
  final mockAppRouter = MockAppRouter();
  final mockSecureStorage = MockSecureStorage();

  group('DashboardMeasurablesChart Widget Tests - ', () {
    setUp(() {
      mockJournalDb = MockJournalDb();

      getIt
        ..registerSingleton<ThemesService>(ThemesService(watch: false))
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<NavService>(MockNavService())
        ..registerSingleton<SecureStorage>(mockSecureStorage)
        ..registerSingleton<AppRouter>(mockAppRouter);
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

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DashboardMeasurablesChart(
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
          DashboardMeasurablesChart(
            rangeStart: DateTime(2022),
            rangeEnd: DateTime(2023),
            measurableDataTypeId: measurableCoverage.id,
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
          [testMeasuredPullUpsEntry]
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

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DashboardMeasurablesChart(
            rangeStart: DateTime(2022),
            rangeEnd: DateTime(2023),
            measurableDataTypeId: measurablePullUps.id,
            enableCreate: true,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // measurement entry displays expected date
      expect(
        find.text('${measurablePullUps.displayName} [dailyMax]'),
        findsOneWidget,
      );

      // double tap on chart to trigger navigation to create measurement page
      const expectedRoute =
          '/dashboards/measure/22922182-15bf-4f2b-864f-1f546f95cac2';

      Future<void> mockWriteValue() =>
          mockSecureStorage.writeValue(any(), expectedRoute);
      when(mockWriteValue).thenAnswer((_) async {});

      Future<void> mockPushNamed() => mockAppRouter.pushNamed(expectedRoute);
      when(mockPushNamed).thenAnswer((_) async {});

      final chartTappableFinder = find.byType(GestureDetector).first;
      await tester.tap(chartTappableFinder);
      await tester.pump(kDoubleTapMinTime);
      await tester.tap(chartTappableFinder);

      await tester.pumpAndSettle();
      verify(mockWriteValue).called(1);
      verify(mockPushNamed).called(1);
    });
  });
}
