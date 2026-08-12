import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/goals/model/goal_health_data_types.dart';

void main() {
  test('supported goal health types use journal storage identifiers', () {
    expect(GoalHealthDataTypes.supported, {
      'HealthDataType.WEIGHT',
      'HealthDataType.BLOOD_PRESSURE_SYSTOLIC',
      'HealthDataType.BLOOD_PRESSURE_DIASTOLIC',
    });
  });

  test('criterion ids are stable and reject unsupported data types', () {
    expect(
      {
        for (final dataType in GoalHealthDataTypes.supported)
          dataType: GoalHealthDataTypes.criterionId(dataType),
      },
      {
        GoalHealthDataTypes.weight: 'health-weight',
        GoalHealthDataTypes.bloodPressureSystolic:
            'health-blood-pressure-systolic',
        GoalHealthDataTypes.bloodPressureDiastolic:
            'health-blood-pressure-diastolic',
      },
    );
    expect(
      () => GoalHealthDataTypes.criterionId('HealthDataType.UNKNOWN'),
      throwsArgumentError,
    );
  });
}
