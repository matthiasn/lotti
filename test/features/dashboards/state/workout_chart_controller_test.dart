import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/dashboards/state/workout_chart_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../test_utils.dart';

void main() {
  late TestGetItMocks mocks;
  late MockHealthImport mockHealthImport;

  setUpAll(registerAllFallbackValues);

  setUp(() async {
    mockHealthImport = MockHealthImport();
    when(() => mockHealthImport.getWorkoutsHealthDataDelta())
        .thenAnswer((_) async {});

    mocks = await setUpTestGetIt(
      additionalSetup: () {
        getIt.registerSingleton<HealthImport>(mockHealthImport);
      },
    );
  });

  tearDown(tearDownTestGetIt);

  group('WorkoutChartDataController', () {
    final rangeStart = DateTime(2024, 3, 10);
    final rangeEnd = DateTime(2024, 3, 15);

    test('fetches workouts from JournalDb on build', () async {
      final entities = [
        makeWorkoutEntry(
          dateFrom: DateTime(2024, 3, 12, 8),
          dateTo: DateTime(2024, 3, 12, 9),
          workoutType: 'running',
          energy: 500,
        ),
      ];

      when(
        () => mocks.journalDb.getWorkouts(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => entities);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final result = await container.read(
        workoutChartDataControllerProvider(
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        ).future,
      );

      expect(result, hasLength(1));
      verify(
        () => mocks.journalDb.getWorkouts(
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        ),
      ).called(1);
    });

    test('refreshes on workoutNotification', () async {
      final updateController = StreamController<Set<String>>.broadcast();
      when(() => mocks.updateNotifications.updateStream)
          .thenAnswer((_) => updateController.stream);

      when(
        () => mocks.journalDb.getWorkouts(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => []);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(
        workoutChartDataControllerProvider(
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        ).future,
      );

      updateController.add({workoutNotification});

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      verify(
        () => mocks.journalDb.getWorkouts(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).called(2);

      await updateController.close();
    });
  });

  group('WorkoutObservationsController', () {
    final rangeStart = DateTime(2024, 3, 10);
    final rangeEnd = DateTime(2024, 3, 15);

    const runningEnergyConfig = DashboardWorkoutItem(
      workoutType: 'running',
      displayName: 'Running (calories)',
      color: '#82E6CE',
      valueType: WorkoutValueType.energy,
    );

    test('aggregates workout data via aggregateWorkoutDailySum', () async {
      final entities = [
        makeWorkoutEntry(
          dateFrom: DateTime(2024, 3, 12, 8),
          dateTo: DateTime(2024, 3, 12, 9),
          workoutType: 'running',
          energy: 500,
        ),
      ];

      when(
        () => mocks.journalDb.getWorkouts(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => entities);

      final container = ProviderContainer();

      // First ensure the data controller has loaded
      await container.read(
        workoutChartDataControllerProvider(
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        ).future,
      );

      final result = await container.read(
        workoutObservationsControllerProvider(
          chartConfig: runningEnergyConfig,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        ).future,
      );

      // 5 days in range, each with aggregated value
      expect(result, hasLength(5));

      final march12 = result.firstWhere(
        (o) => o.dateTime == DateTime(2024, 3, 12),
      );
      expect(march12.value, 500);

      container.dispose();
    });
  });
}
