import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_chart.dart';
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

/// Wraps [widget] inside a bounded box so the header's Row has finite width.
Widget _wrapInStack(Widget widget) {
  return SizedBox(
    width: 1000,
    height: 600,
    child: widget,
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
  group('aggregationDisplayLabel', () {
    /// Pumps a [Builder] and returns the localized label for [type].
    Future<String> resolveLabel(
      WidgetTester tester,
      AggregationType type,
    ) async {
      late String label;
      await tester.pumpWidget(
        makeTestableWidget(
          Builder(
            builder: (context) {
              label = aggregationDisplayLabel(context, type);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return label;
    }

    testWidgets('returns empty string for AggregationType.none', (
      tester,
    ) async {
      expect(await resolveLabel(tester, AggregationType.none), '');
    });

    testWidgets('humanizes each aggregation type', (tester) async {
      const expected = {
        AggregationType.dailySum: 'Daily total',
        AggregationType.dailyMax: 'Daily max',
        AggregationType.dailyAvg: 'Daily average',
        AggregationType.hourlySum: 'Hourly total',
      };
      for (final entry in expected.entries) {
        expect(
          await resolveLabel(tester, entry.key),
          entry.value,
          reason: 'label for ${entry.key}',
        );
      }
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
      'title is just the displayName with no bracketed enum suffix',
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

        // The title is the plain display name — never "Heart Rate [none]".
        expect(find.text('Heart Rate'), findsOneWidget);
        expect(find.textContaining('['), findsNothing);
      },
    );

    testWidgets(
      'humanized aggregation appears in the subtitle, not the title',
      (tester) async {
        const expected = {
          AggregationType.dailySum: 'Daily total',
          AggregationType.dailyMax: 'Daily max',
          AggregationType.dailyAvg: 'Daily average',
          AggregationType.hourlySum: 'Hourly total',
        };
        for (final entry in expected.entries) {
          final dataType = _makeDataType(
            displayName: 'Steps',
            aggregationType: entry.key,
          );

          await _pumpWidget(
            tester,
            MeasurablesChartInfoWidget(
              dataType,
              aggregationType: entry.key,
              enableCreate: false,
            ),
          );

          // Title is the bare name; the humanized aggregation is the subtitle.
          expect(
            find.text('Steps'),
            findsOneWidget,
            reason: 'title for ${entry.key}',
          );
          expect(
            find.text(entry.value),
            findsOneWidget,
            reason: 'subtitle for ${entry.key}',
          );
          // No developer enum bracket leaks into the UI.
          expect(find.textContaining('['), findsNothing);
        }
      },
    );

    testWidgets(
      'subtitle joins aggregation and description with a middle dot',
      (tester) async {
        final dataType = _makeDataType(
          displayName: 'Water',
          description: 'Daily water intake',
          aggregationType: AggregationType.dailySum,
        );

        await _pumpWidget(
          tester,
          MeasurablesChartInfoWidget(
            dataType,
            aggregationType: AggregationType.dailySum,
            enableCreate: false,
          ),
        );

        expect(find.text('Water'), findsOneWidget);
        expect(find.text('Daily total · Daily water intake'), findsOneWidget);
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
      'subtitle is empty when both aggregation and description are empty',
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

        // Title shows; the header receives an empty subtitle so none renders.
        expect(find.text('Weight'), findsOneWidget);
        final header = tester.widget<DashboardChartHeader>(
          find.byType(DashboardChartHeader),
        );
        expect(header.subtitle, isEmpty);
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
        // _buildModalTitle renders the description as its own Text node, so the
        // modal title carries the raw description even though the card header
        // folds it into the " · "-joined subtitle.
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

        // The card header folds the description into the joined subtitle, so
        // the raw description is not yet a standalone Text node.
        expect(find.text('Daily energy level'), findsNothing);

        await tester.ensureVisible(find.byIcon(Icons.add_rounded));
        await tester.tap(find.byIcon(Icons.add_rounded));
        // Let the modal route's open animation run to completion.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // The modal title widget renders the description as its own Text.
        expect(find.text('Daily energy level'), findsOneWidget);
      },
    );
  });
}
