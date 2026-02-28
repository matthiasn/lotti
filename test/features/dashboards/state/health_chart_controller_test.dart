import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/dashboards/state/health_chart_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../widget_test_utils.dart';
import '../test_utils.dart';

void main() {
  late TestGetItMocks mocks;

  setUpAll(registerAllFallbackValues);

  setUp(() async {
    mocks = await setUpTestGetIt();
  });

  tearDown(tearDownTestGetIt);

  group('HealthChartDataController', () {
    final rangeStart = DateTime(2024, 3, 10);
    final rangeEnd = DateTime(2024, 3, 15);
    const dataType = 'HealthDataType.WEIGHT';

    test('fetches quantitative data from JournalDb on build', () async {
      final entities = [
        makeQuantitativeEntry(
          dateFrom: DateTime(2024, 3, 12, 10),
          value: 72.5,
          dataType: dataType,
        ),
      ];

      when(
        () => mocks.journalDb.getQuantitativeByType(
          type: any(named: 'type'),
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => entities);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final future = container.read(
        healthChartDataControllerProvider(
          healthDataType: dataType,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        ).future,
      );

      final result = await future;

      expect(result, hasLength(1));
      verify(
        () => mocks.journalDb.getQuantitativeByType(
          type: dataType,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        ),
      ).called(1);
    });

    test('refreshes when update notification contains healthDataType',
        () async {
      final updateController = StreamController<Set<String>>.broadcast();
      when(() => mocks.updateNotifications.updateStream)
          .thenAnswer((_) => updateController.stream);

      final firstEntities = [
        makeQuantitativeEntry(
          dateFrom: DateTime(2024, 3, 12),
          value: 72.0,
          dataType: dataType,
        ),
      ];
      final secondEntities = [
        makeQuantitativeEntry(
          dateFrom: DateTime(2024, 3, 12),
          value: 73.0,
          dataType: dataType,
          id: 'updated',
        ),
      ];

      var callCount = 0;
      when(
        () => mocks.journalDb.getQuantitativeByType(
          type: any(named: 'type'),
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async {
        callCount++;
        return callCount == 1 ? firstEntities : secondEntities;
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final provider = healthChartDataControllerProvider(
        healthDataType: dataType,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      // Initial load
      await container.read(provider.future);

      // Listen for the refresh to complete
      final refreshed = Completer<List<JournalEntity>>();
      container.listen<AsyncValue<List<JournalEntity>>>(
        provider,
        (_, next) {
          if (next is AsyncData<List<JournalEntity>> &&
              !refreshed.isCompleted) {
            refreshed.complete(next.value);
          }
        },
      );

      // Trigger notification for this health type
      updateController.add({dataType});

      // Wait for the refresh to complete
      await refreshed.future;

      verify(
        () => mocks.journalDb.getQuantitativeByType(
          type: dataType,
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).called(2);

      await updateController.close();
    });
  });

  group('HealthObservationsController', () {
    final rangeStart = DateTime(2024, 3, 10);
    final rangeEnd = DateTime(2024, 3, 15);
    const dataType = 'HealthDataType.WEIGHT';

    test('aggregates data via aggregateByType', () async {
      final entities = [
        makeQuantitativeEntry(
          dateFrom: DateTime(2024, 3, 12, 10),
          value: 72.5,
          dataType: dataType,
        ),
        makeQuantitativeEntry(
          dateFrom: DateTime(2024, 3, 13, 11),
          value: 73.0,
          dataType: dataType,
          id: 'entry2',
        ),
      ];

      when(
        () => mocks.journalDb.getQuantitativeByType(
          type: any(named: 'type'),
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => entities);

      final container = ProviderContainer();

      // Ensure the data controller has loaded first
      await container.read(
        healthChartDataControllerProvider(
          healthDataType: dataType,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        ).future,
      );

      final result = await container.read(
        healthObservationsControllerProvider(
          healthDataType: dataType,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        ).future,
      );

      // WEIGHT uses 'none' aggregation, so one observation per entry
      expect(result, hasLength(2));
      expect(result[0].value, 72.5);
      expect(result[1].value, 73.0);

      container.dispose();
    });
  });
}
