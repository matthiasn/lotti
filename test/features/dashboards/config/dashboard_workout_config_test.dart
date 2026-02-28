import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/dashboards/config/dashboard_workout_config.dart';

void main() {
  group('workoutTypes', () {
    test('contains expected workout type keys', () {
      expect(workoutTypes, contains('running.energy'));
      expect(workoutTypes, contains('running.distance'));
      expect(workoutTypes, contains('running.duration'));
      expect(workoutTypes, contains('walking.energy'));
      expect(workoutTypes, contains('walking.distance'));
      expect(workoutTypes, contains('walking.duration'));
      expect(workoutTypes, contains('swimming.energy'));
      expect(workoutTypes, contains('swimming.distance'));
      expect(workoutTypes, contains('swimming.duration'));
      expect(
        workoutTypes,
        contains('functionalStrengthTraining.duration'),
      );
      expect(
        workoutTypes,
        contains('functionalStrengthTraining.energy'),
      );
    });

    test('running entries have correct workoutType', () {
      for (final key in workoutTypes.keys.where((k) => k.startsWith('run'))) {
        expect(workoutTypes[key]!.workoutType, 'running');
      }
    });

    test('each entry has correct valueType matching key suffix', () {
      for (final entry in workoutTypes.entries) {
        final suffix = entry.key.split('.').last;
        switch (suffix) {
          case 'energy':
            expect(
              entry.value.valueType,
              WorkoutValueType.energy,
              reason: '${entry.key} should be energy',
            );
          case 'distance':
            expect(
              entry.value.valueType,
              WorkoutValueType.distance,
              reason: '${entry.key} should be distance',
            );
          case 'duration':
            expect(
              entry.value.valueType,
              WorkoutValueType.duration,
              reason: '${entry.key} should be duration',
            );
        }
      }
    });

    test('all entries have non-empty displayName and color', () {
      for (final entry in workoutTypes.entries) {
        expect(
          entry.value.displayName,
          isNotEmpty,
          reason: '${entry.key} should have a displayName',
        );
        expect(
          entry.value.color,
          isNotEmpty,
          reason: '${entry.key} should have a color',
        );
      }
    });
  });
}
