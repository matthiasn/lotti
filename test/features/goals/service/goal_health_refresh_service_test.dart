import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/goals/model/goal_health_data_types.dart';
import 'package:lotti/features/goals/service/goal_health_refresh_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

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

  setUp(() {
    healthImport = MockHealthImport();
    when(() => healthImport.fetchHealthDataDelta(any())).thenAnswer(
      (_) async {},
    );
    service = GoalHealthRefreshService(healthImport);
  });

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

    test('a failing import is contained, and the rest still run', () async {
      when(
        () => healthImport.fetchHealthDataDelta(GoalHealthDataTypes.steps),
      ).thenThrow(StateError('health store unavailable'));

      // Opening a goal page must not blow up because a sensor is unavailable.
      await service.refreshForCriteria([
        _metric(GoalHealthDataTypes.steps),
        _metric(GoalHealthDataTypes.weight),
      ]);

      verify(
        () => healthImport.fetchHealthDataDelta(GoalHealthDataTypes.weight),
      ).called(1);
    });
  });
}
