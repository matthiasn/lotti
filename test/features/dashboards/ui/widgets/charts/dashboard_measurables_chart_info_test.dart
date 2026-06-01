import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_measurables_chart_info.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../widget_test_utils.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

MeasurableDataType _makeDataType({
  String id = 'test-id',
  String displayName = 'Heart Rate',
  String description = '',
  String unitName = 'bpm',
  AggregationType aggregationType = AggregationType.none,
}) {
  return MeasurableDataType(
    id: id,
    displayName: displayName,
    description: description,
    unitName: unitName,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
    vectorClock: const VectorClock({}),
    version: 1,
    aggregationType: aggregationType,
  );
}

/// Wraps [widget] (a Positioned) inside a bounded Stack so layout works.
Widget _wrapInStack(Widget widget) {
  return SizedBox(
    width: 1000,
    height: 600,
    child: Stack(children: [widget]),
  );
}

Future<void> _pumpWidget(
  WidgetTester tester,
  Widget child, {
  MediaQueryData mediaQueryData = const MediaQueryData(size: Size(1400, 900)),
}) async {
  await tester.pumpWidget(
    makeTestableWidget(
      _wrapInStack(child),
      mediaQueryData: mediaQueryData,
    ),
  );
  await tester.pump();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('aggregationLabel', () {
    test('returns empty string for null', () {
      expect(aggregationLabel(null), '');
    });

    test('returns empty string for AggregationType.none', () {
      expect(aggregationLabel(AggregationType.none), '');
    });

    test('returns formatted label for dailySum', () {
      expect(
        aggregationLabel(AggregationType.dailySum),
        '[dailySum]',
      );
    });

    test('returns formatted label for dailyMax', () {
      expect(
        aggregationLabel(AggregationType.dailyMax),
        '[dailyMax]',
      );
    });
  });

  group('MeasurablesChartInfoWidget', () {
    setUp(() async {
      await setUpTestGetIt(
        additionalSetup: () {
          final mockPersistenceLogic = MockPersistenceLogic();
          final mockEntitiesCache = MockEntitiesCacheService();
          when(
            () => mockEntitiesCache.getDataTypeById(any()),
          ).thenReturn(null);
          getIt
            ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
            ..registerSingleton<EntitiesCacheService>(mockEntitiesCache);
        },
      );
    });

    tearDown(tearDownTestGetIt);

    testWidgets(
      'renders displayName without aggregation suffix when AggregationType.none',
      (tester) async {
        // ignore: avoid_redundant_argument_values
        final dataType = _makeDataType(displayName: 'Heart Rate');

        await _pumpWidget(
          tester,
          MeasurablesChartInfoWidget(
            dataType,
            aggregationType: AggregationType.none,
            enableCreate: false,
          ),
        );

        // Text should be just the name with no aggregation suffix
        expect(find.text('Heart Rate'), findsOneWidget);
        expect(find.text('Heart Rate '), findsNothing);
      },
    );

    testWidgets(
      'renders displayName with aggregation label when type is not none',
      (tester) async {
        for (final aggType in [
          AggregationType.dailySum,
          AggregationType.dailyMax,
          AggregationType.dailyAvg,
          AggregationType.hourlySum,
        ]) {
          final dataType = _makeDataType(
            displayName: 'Steps',
            aggregationType: aggType,
          );
          final label = aggregationLabel(aggType);

          await _pumpWidget(
            tester,
            MeasurablesChartInfoWidget(
              dataType,
              aggregationType: aggType,
              enableCreate: false,
            ),
          );

          expect(
            find.text('Steps $label'),
            findsOneWidget,
            reason: 'Expected "Steps $label" for $aggType',
          );
        }
      },
    );

    testWidgets(
      'shows description text when description is not empty',
      (tester) async {
        final dataType = _makeDataType(
          displayName: 'Weight',
          description: 'Body weight in kg',
        );

        await _pumpWidget(
          tester,
          MeasurablesChartInfoWidget(
            dataType,
            aggregationType: AggregationType.none,
            enableCreate: false,
          ),
        );

        expect(find.text('Body weight in kg'), findsOneWidget);
      },
    );

    testWidgets(
      'hides description text when description is empty',
      (tester) async {
        // ignore: avoid_redundant_argument_values
        final dataType = _makeDataType(displayName: 'Weight', description: '');

        await _pumpWidget(
          tester,
          MeasurablesChartInfoWidget(
            dataType,
            aggregationType: AggregationType.none,
            enableCreate: false,
          ),
        );

        // Only the title row — no description widget
        expect(find.text(''), findsNothing);
      },
    );

    testWidgets(
      'shows add icon button when enableCreate is true',
      (tester) async {
        final dataType = _makeDataType(displayName: 'Steps');

        await _pumpWidget(
          tester,
          MeasurablesChartInfoWidget(
            dataType,
            aggregationType: AggregationType.none,
            enableCreate: true,
          ),
        );

        expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      },
    );

    testWidgets(
      'hides add icon button when enableCreate is false',
      (tester) async {
        final dataType = _makeDataType(displayName: 'Steps');

        await _pumpWidget(
          tester,
          MeasurablesChartInfoWidget(
            dataType,
            aggregationType: AggregationType.none,
            enableCreate: false,
          ),
        );

        expect(find.byIcon(Icons.add_rounded), findsNothing);
      },
    );

    testWidgets(
      'tapping add button invokes captureData and builds modal title',
      (tester) async {
        // The modal title widget (_buildModalTitle) is constructed as part of
        // calling captureData. This test covers lines 23-25,27-31,33,50-51,53-56.
        // Use a narrow viewport so the trailing IconButton stays within bounds.
        tester.view
          ..physicalSize = const Size(800, 600)
          ..devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final dataType = _makeDataType(
          displayName: 'Mood',
          description: 'Daily mood score',
        );

        await _pumpWidget(
          tester,
          MeasurablesChartInfoWidget(
            dataType,
            aggregationType: AggregationType.none,
            enableCreate: true,
          ),
          mediaQueryData: const MediaQueryData(size: Size(800, 600)),
        );

        await tester.ensureVisible(find.byIcon(Icons.add_rounded));
        await tester.tap(find.byIcon(Icons.add_rounded));
        await tester.pump();

        // The modal title should display the displayName of the measurable.
        // ModalUtils shows a bottom sheet / dialog with the titleWidget.
        expect(find.text('Mood'), findsWidgets);
      },
    );

    testWidgets(
      'tapping add button with description shows description in modal title',
      (tester) async {
        // _buildModalTitle includes description when non-empty (lines 36-39,41).
        // Use a narrow viewport so the trailing IconButton stays within bounds.
        tester.view
          ..physicalSize = const Size(800, 600)
          ..devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final dataType = _makeDataType(
          displayName: 'Energy',
          description: 'Daily energy level',
        );

        await _pumpWidget(
          tester,
          MeasurablesChartInfoWidget(
            dataType,
            aggregationType: AggregationType.dailyAvg,
            enableCreate: true,
          ),
          mediaQueryData: const MediaQueryData(size: Size(800, 600)),
        );

        await tester.ensureVisible(find.byIcon(Icons.add_rounded));
        await tester.tap(find.byIcon(Icons.add_rounded));
        await tester.pump();

        // The modal title widget contains the description text.
        expect(find.text('Daily energy level'), findsWidgets);
      },
    );
  });
}
