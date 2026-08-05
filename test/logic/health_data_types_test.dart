import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:lotti/logic/health_data_types.dart';

void main() {
  group('permission families', () {
    test('every family is non-empty and shares no type with another', () {
      final seen = <HealthDataType>{};
      for (final family in healthPermissionFamilies) {
        expect(family, isNotEmpty);
        for (final type in family) {
          expect(
            seen.add(type),
            isTrue,
            reason:
                '$type is in two families — expandToPermissionFamilies would '
                'then authorize a different set depending on which type asked',
          );
        }
      }
    });

    test('blood pressure is one family, so it is one system sheet', () {
      expect(
        permissionFamilyFor(HealthDataType.BLOOD_PRESSURE_SYSTOLIC),
        bpTypes,
      );
      expect(
        permissionFamilyFor(HealthDataType.BLOOD_PRESSURE_DIASTOLIC),
        bpTypes,
      );
    });

    test('a type in no family is its own family, not dropped', () {
      // WATER belongs to no family Lotti imports. Returning an empty list here
      // would authorize nothing at all and make the read silently fail.
      expect(permissionFamilyFor(HealthDataType.WATER), [
        HealthDataType.WATER,
      ]);
    });

    test('every family member resolves back to the family', () {
      for (final family in healthPermissionFamilies) {
        for (final type in family) {
          expect(permissionFamilyFor(type), family, reason: '$type');
        }
      }
    });
  });

  group('expandToPermissionFamilies', () {
    test('one blood-pressure series expands to both', () {
      // The dashboard card mounts one controller per series, so this is the
      // exact call the systolic chart makes. Expanding it is what turns two
      // back-to-back authorization sheets into one.
      expect(
        expandToPermissionFamilies([HealthDataType.BLOOD_PRESSURE_SYSTOLIC]),
        bpTypes,
      );
    });

    test('de-duplicates when both members of a family are asked for', () {
      expect(expandToPermissionFamilies(bpTypes), bpTypes);
    });

    test('unions across families without repeating a type', () {
      final expanded = expandToPermissionFamilies([
        HealthDataType.STEPS,
        HealthDataType.WEIGHT,
        HealthDataType.STEPS,
      ]);

      expect(expanded.toSet(), {...activityTypes, ...bodyMeasurementTypes});
      expect(
        expanded,
        hasLength(activityTypes.length + bodyMeasurementTypes.length),
      );
    });

    test('an empty request expands to nothing', () {
      expect(expandToPermissionFamilies(const []), isEmpty);
    });

    test('families follow the input order, not the family-list order', () {
      // Workouts are declared last in healthPermissionFamilies and activity
      // first, so this is the case that distinguishes the two orderings.
      expect(
        expandToPermissionFamilies([
          HealthDataType.WORKOUT,
          HealthDataType.STEPS,
        ]),
        [...workoutTypes, ...activityTypes],
      );
      expect(
        expandToPermissionFamilies([
          HealthDataType.STEPS,
          HealthDataType.WORKOUT,
        ]),
        [...activityTypes, ...workoutTypes],
      );
    });

    test('order within a family is the family list order', () {
      // What the callers actually rely on: the gate hands this straight to
      // requestAuthorization, and the tests verify against `bpTypes` itself.
      expect(
        expandToPermissionFamilies([
          HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
        ]),
        bpTypes,
        reason: 'diastolic is declared second, yet the family order stands',
      );
    });

    test('is idempotent', () {
      final once = expandToPermissionFamilies([HealthDataType.SLEEP_REM]);
      expect(expandToPermissionFamilies(once), once);
    });
  });

  group('sleepStagesDuplicatedAsAsleep', () {
    // A membership test against a string is a test nothing type-checks: the set
    // previously named SLEEP_ASLEEP_CORE, which is not a value of the enum, and
    // the largest stage of every night was silently dropped.
    test('every member names a real HealthDataType', () {
      for (final name in sleepStagesDuplicatedAsAsleep) {
        expect(
          EnumToString.fromString(
            HealthDataType.values,
            name.replaceAll('HealthDataType.', ''),
          ),
          isNotNull,
          reason: '$name does not resolve to a HealthDataType',
        );
      }
    });

    test('holds exactly the staged types, and never the generic one', () {
      expect(sleepStagesDuplicatedAsAsleep, {
        'HealthDataType.SLEEP_LIGHT',
        'HealthDataType.SLEEP_DEEP',
        'HealthDataType.SLEEP_REM',
      });
      // Duplicating the generic type under itself would double every legacy
      // night's hours.
      expect(
        sleepStagesDuplicatedAsAsleep,
        isNot(contains('HealthDataType.SLEEP_ASLEEP')),
      );
    });

    test('every staged member is also a type sleep imports', () {
      for (final name in sleepStagesDuplicatedAsAsleep) {
        expect(
          sleepTypes.map((type) => type.toString()),
          contains(name),
          reason: '$name is duplicated but never read',
        );
      }
    });
  });
}
