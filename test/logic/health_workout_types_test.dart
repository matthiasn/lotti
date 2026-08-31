import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:health/health.dart';
import 'package:lotti/features/dashboards/config/dashboard_workout_config.dart'
    as catalogue;
import 'package:lotti/logic/health_workout_types.dart';

/// Spellings in the shapes the two import eras — and a few stray inputs —
/// produce: the fork's camelCase, the plugin's UPPER_SNAKE, and fragments
/// with no letters or a lone capital.
extension _AnyWorkoutSpelling on glados.Any {
  glados.Generator<String> get workoutSegment => choose(const [
    'walking',
    'RUNNING',
    'Strength',
    'training',
    'BIKING',
    'x',
    'A',
    '1',
    '',
  ]);

  glados.Generator<String> get workoutSpelling => combine2(
    list(workoutSegment),
    choose(const ['_', '']),
    (List<String> segments, String separator) => segments.join(separator),
  );

  glados.Generator<HealthWorkoutActivityType> get activity =>
      choose(HealthWorkoutActivityType.values);
}

void main() {
  group('canonicalWorkoutType', () {
    test('folds the plugin enum name into lowerCamelCase', () {
      expect(canonicalWorkoutType('WALKING'), 'walking');
      expect(
        canonicalWorkoutType('FUNCTIONAL_STRENGTH_TRAINING'),
        'functionalStrengthTraining',
      );
      expect(
        canonicalWorkoutType('HIGH_INTENSITY_INTERVAL_TRAINING'),
        'highIntensityIntervalTraining',
      );
    });

    test("maps the plugin's BIKING onto the cycling HealthKit records", () {
      expect(canonicalWorkoutType('BIKING'), 'cycling');
      expect(canonicalWorkoutType('biking'), 'cycling');
      // Only the bare activity is aliased; a stationary bike is its own type.
      expect(canonicalWorkoutType('BIKING_STATIONARY'), 'bikingStationary');
    });

    test('passes an already canonical value through unchanged', () {
      for (final canonical in const [
        'walking',
        'running',
        'cycling',
        'functionalStrengthTraining',
      ]) {
        expect(canonicalWorkoutType(canonical), canonical);
      }
    });

    test('folds a stray leading capital', () {
      expect(canonicalWorkoutType('Running'), 'running');
    });

    test('trims whitespace', () {
      expect(canonicalWorkoutType('  WALKING '), 'walking');
      expect(canonicalWorkoutType(' running'), 'running');
    });

    test('settles empty and underscore-only input on the empty string', () {
      expect(canonicalWorkoutType(''), '');
      expect(canonicalWorkoutType('   '), '');
      expect(canonicalWorkoutType('___'), '');
    });

    test('lower-cases a value without a single lower-case letter', () {
      expect(canonicalWorkoutType('A'), 'a');
      expect(canonicalWorkoutType('1_A'), '1a');
      expect(canonicalWorkoutType('123'), '123');
    });
  });

  group('workoutTypeForActivity', () {
    test('maps every plugin activity to a canonical, distinct name', () {
      final seen = <String>{};
      for (final activity in HealthWorkoutActivityType.values) {
        final type = workoutTypeForActivity(activity);
        expect(type, isNotEmpty, reason: activity.name);
        expect(type, isNot(contains('_')), reason: activity.name);
        expect(type[0], type[0].toLowerCase(), reason: activity.name);
        expect(canonicalWorkoutType(type), type, reason: activity.name);
        expect(seen.add(type), isTrue, reason: '$type is produced twice');
      }
    });

    test('names the four activities the dashboards chart', () {
      expect(
        workoutTypeForActivity(HealthWorkoutActivityType.WALKING),
        'walking',
      );
      expect(
        workoutTypeForActivity(HealthWorkoutActivityType.RUNNING),
        'running',
      );
      expect(
        workoutTypeForActivity(HealthWorkoutActivityType.SWIMMING),
        'swimming',
      );
      expect(
        workoutTypeForActivity(
          HealthWorkoutActivityType.FUNCTIONAL_STRENGTH_TRAINING,
        ),
        'functionalStrengthTraining',
      );
    });
  });

  group('the dashboard catalogue', () {
    test('is spelled canonically, so imported rows match it', () {
      for (final item in catalogue.workoutTypes.values) {
        expect(
          canonicalWorkoutType(item.workoutType),
          item.workoutType,
          reason: item.displayName,
        );
      }
    });

    test('charts only activities the plugin can deliver', () {
      final deliverable = HealthWorkoutActivityType.values
          .map(workoutTypeForActivity)
          .toSet();
      for (final item in catalogue.workoutTypes.values) {
        expect(
          deliverable,
          contains(item.workoutType),
          reason: item.displayName,
        );
      }
    });
  });

  group('isSameWorkoutType', () {
    test('matches an activity across both eras', () {
      expect(isSameWorkoutType('WALKING', 'walking'), isTrue);
      expect(isSameWorkoutType('walking', 'WALKING'), isTrue);
      expect(
        isSameWorkoutType(
          'FUNCTIONAL_STRENGTH_TRAINING',
          'functionalStrengthTraining',
        ),
        isTrue,
      );
      expect(isSameWorkoutType('BIKING', 'cycling'), isTrue);
    });

    test('keeps different activities apart, prefixes included', () {
      expect(isSameWorkoutType('walking', 'running'), isFalse);
      expect(isSameWorkoutType('walk', 'walking'), isFalse);
      expect(isSameWorkoutType('WALKING_TREADMILL', 'walking'), isFalse);
    });
  });

  group('properties', () {
    glados.Glados(
      glados.any.workoutSpelling,
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'canonicalWorkoutType is idempotent',
      (raw) {
        final once = canonicalWorkoutType(raw);
        expect(canonicalWorkoutType(once), once, reason: 'raw: "$raw"');
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.workoutSpelling,
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'the canonical form has no underscores and no leading capital',
      (raw) {
        final canonical = canonicalWorkoutType(raw);
        expect(canonical, isNot(contains('_')), reason: 'raw: "$raw"');
        if (canonical.isNotEmpty) {
          expect(
            canonical[0],
            canonical[0].toLowerCase(),
            reason: 'raw: "$raw"',
          );
        }
      },
      tags: 'glados',
    );

    glados.Glados2(
      glados.any.workoutSpelling,
      glados.any.workoutSpelling,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'isSameWorkoutType is reflexive and symmetric',
      (a, b) {
        expect(isSameWorkoutType(a, a), isTrue, reason: 'a: "$a"');
        expect(
          isSameWorkoutType(a, b),
          isSameWorkoutType(b, a),
          reason: 'a: "$a", b: "$b"',
        );
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.activity,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'every spelling of a plugin activity names the same canonical type',
      (activity) {
        final canonical = workoutTypeForActivity(activity);
        for (final spelling in [
          activity.name,
          activity.name.toLowerCase(),
          canonical,
        ]) {
          expect(
            isSameWorkoutType(spelling, canonical),
            isTrue,
            reason: '${activity.name} as "$spelling"',
          );
        }
      },
      tags: 'glados',
    );
  });
}
