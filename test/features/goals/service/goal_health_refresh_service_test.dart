import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/goals/model/goal_health_data_types.dart';
import 'package:lotti/features/goals/service/goal_health_refresh_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

GoalCriterion _metric(String dataType) => GoalCriterion.metric(
  criterionId: 'c-$dataType',
  dataType: dataType,
  window: const GoalWindow.rollingDays(count: 7),
  aggregation: GoalAggregation.dailySumThenAverage,
  target: 10000,
);

void main() {
  late MockHealthImport healthImport;
  late GoalHealthRefreshService service;
  late MockLoggingService loggingService;

  setUp(() async {
    // The shared harness: the provider case below resolves the importer out of
    // GetIt, so the whole file runs against one registered world.
    await setUpTestGetIt();
    loggingService = MockLoggingService();
    stubLoggingService(loggingService);
    healthImport = MockHealthImport();
    when(() => healthImport.fetchHealthDataDelta(any())).thenAnswer(
      (_) async {},
    );
    service = GoalHealthRefreshService(healthImport);
  });

  tearDown(tearDownTestGetIt);

  group('importRequestsFor', () {
    test('asks only for what the platform health store owns', () {
      final requests = GoalHealthRefreshService.importRequestsFor([
        _metric(GoalHealthDataTypes.steps),
        // A user-authored measurable is written in Lotti and is current by
        // construction — importing it would be meaningless.
        const GoalCriterion.measurable(
          criterionId: 'words',
          dataTypeId: 'words-written',
          window: GoalWindow.rollingDays(count: 7),
          aggregation: GoalAggregation.sum,
          target: 1000,
        ),
        const GoalCriterion.habit(
          criterionId: 'gym',
          habitId: 'gym',
          window: GoalWindow.rollingDays(count: 7),
          targetCount: 3,
        ),
      ]);

      expect(requests, {GoalHealthDataTypes.steps});
    });

    test('collapses the blood-pressure pair onto one composite request', () {
      final requests = GoalHealthRefreshService.importRequestsFor([
        GoalCriterion.allOf(
          criterionId: 'root',
          criteria: [
            _metric(GoalHealthDataTypes.bloodPressureSystolic),
            _metric(GoalHealthDataTypes.bloodPressureDiastolic),
          ],
        ),
      ]);

      // One reading is two samples; asking for the halves separately queues
      // two imports for what the user authorized once.
      expect(requests, {'BLOOD_PRESSURE'});
    });

    test('reaches criteria nested inside composites', () {
      final requests = GoalHealthRefreshService.importRequestsFor([
        GoalCriterion.atLeastCount(
          criterionId: 'root',
          successes: 1,
          criteria: [
            GoalCriterion.anyOf(
              criterionId: 'inner',
              criteria: [_metric(GoalHealthDataTypes.weight)],
            ),
          ],
        ),
      ]);

      expect(requests, {GoalHealthDataTypes.weight});
    });
  });

  group('refreshForCriteria', () {
    test('queues one delta import per distinct health signal', () async {
      await service.refreshForCriteria([
        _metric(GoalHealthDataTypes.steps),
        _metric(GoalHealthDataTypes.weight),
        // The same signal twice must not queue twice.
        _metric(GoalHealthDataTypes.steps),
      ]);

      verify(
        () => healthImport.fetchHealthDataDelta(GoalHealthDataTypes.steps),
      ).called(1);
      verify(
        () => healthImport.fetchHealthDataDelta(GoalHealthDataTypes.weight),
      ).called(1);
      verifyNoMoreInteractions(healthImport);
    });

    test('a goal with no health signal asks for nothing', () async {
      await service.refreshForCriteria([
        const GoalCriterion.habit(
          criterionId: 'gym',
          habitId: 'gym',
          window: GoalWindow.rollingDays(count: 7),
          targetCount: 3,
        ),
      ]);

      verifyNever(() => healthImport.fetchHealthDataDelta(any()));
    });

    test(
      'a failing import is contained, reported, and the rest still run',
      () async {
        final logging = GoalHealthRefreshService(
          healthImport,
          DomainLogger(loggingService: loggingService),
        );
        when(
          () => healthImport.fetchHealthDataDelta(GoalHealthDataTypes.steps),
        ).thenThrow(StateError('health store unavailable'));

        // Opening a goal page must not blow up because a sensor is unavailable.
        await logging.refreshForCriteria([
          _metric(GoalHealthDataTypes.steps),
          _metric(GoalHealthDataTypes.weight),
        ]);

        verify(
          () => healthImport.fetchHealthDataDelta(GoalHealthDataTypes.weight),
        ).called(1);
        // Contained is not the same as silent: a sensor that keeps failing has
        // to be findable in the logs.
        verify(
          () => loggingService.captureException(
            any<dynamic>(),
            domain: any(named: 'domain'),
            subDomain: 'goalHealthRefresh',
            stackTrace: any<dynamic>(named: 'stackTrace'),
            level: any(named: 'level'),
            type: any(named: 'type'),
          ),
        ).called(1);
      },
    );
  });

  group('goalHealthRefreshServiceProvider', () {
    test('resolves the registered importer', () {
      getIt.registerSingleton<HealthImport>(healthImport);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(goalHealthRefreshServiceProvider), isNotNull);
    });

    test('is null where no importer is registered', () {
      // Desktop, and every widget test that never registers one: a goal page
      // must open rather than throw out of its first frame.
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(goalHealthRefreshServiceProvider), isNull);
    });
  });
}
