import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/tasks/ui/utils.dart';

/// Glados generator for task-status-like strings.
extension _AnyStatus on glados.Any {
  glados.Generator<String> get statusString => glados.any.stringOf(
    'abcdefghijklmnopqrstuvwxyz_ABCDEFGHIJKLMNOPQRSTUVWXYZ 0123456789',
  );
}

/// The canonical set of known normalized statuses that the switch covers.
const _knownNormalized = <String>{
  'OPEN',
  'GROOMED',
  'IN PROGRESS',
  'BLOCKED',
  'ON HOLD',
  'DONE',
  'REJECTED',
};

void main() {
  // ---------------------------------------------------------------------------
  // normalizeTaskStatusString — worked examples
  // ---------------------------------------------------------------------------

  group('normalizeTaskStatusString', () {
    test('OPEN passes through', () {
      expect(normalizeTaskStatusString('OPEN'), 'OPEN');
    });

    test('lowercase open becomes OPEN', () {
      expect(normalizeTaskStatusString('open'), 'OPEN');
    });

    test('OPENING normalizes to OPEN', () {
      expect(normalizeTaskStatusString('OPENING'), 'OPEN');
    });

    test('OPENED normalizes to OPEN', () {
      expect(normalizeTaskStatusString('OPENED'), 'OPEN');
    });

    test('Opening (mixed case) normalizes to OPEN', () {
      expect(normalizeTaskStatusString('Opening'), 'OPEN');
    });

    test('INPROGRESS normalizes to IN PROGRESS', () {
      expect(normalizeTaskStatusString('INPROGRESS'), 'IN PROGRESS');
    });

    test('inProgress (camelCase) normalizes to IN PROGRESS', () {
      expect(normalizeTaskStatusString('inProgress'), 'IN PROGRESS');
    });

    test('IN_PROGRESS normalizes to IN PROGRESS', () {
      expect(normalizeTaskStatusString('IN_PROGRESS'), 'IN PROGRESS');
    });

    test('underscore replacement: ON_HOLD becomes ON HOLD', () {
      expect(normalizeTaskStatusString('ON_HOLD'), 'ON HOLD');
    });

    test('leading/trailing whitespace is stripped', () {
      expect(normalizeTaskStatusString('  DONE  '), 'DONE');
    });

    test('unknown status returns its uppercased/underscore-replaced form', () {
      expect(normalizeTaskStatusString('unknown_thing'), 'UNKNOWN THING');
    });
  });

  // ---------------------------------------------------------------------------
  // normalizeTaskStatusString — Glados properties
  // ---------------------------------------------------------------------------

  group('normalizeTaskStatusString — properties', () {
    glados.Glados(
      glados.any.statusString,
      glados.ExploreConfig(numRuns: 120),
    ).test('result is fully uppercase', (s) {
      final result = normalizeTaskStatusString(s);
      expect(result, equals(result.toUpperCase()));
    }, tags: 'glados');

    glados.Glados(
      glados.any.statusString,
      glados.ExploreConfig(numRuns: 120),
    ).test('result contains no underscores', (s) {
      expect(normalizeTaskStatusString(s).contains('_'), isFalse);
    }, tags: 'glados');

    // Note: the function trims BEFORE replacing '_' with ' ', so an input like
    // '_OPEN_' yields ' OPEN ' (edge underscores become edge spaces). The
    // output is therefore neither always-trimmed nor idempotent — only the
    // canonical values below are fixed points.
    test('each canonical status is a fixed point', () {
      for (final status in _knownNormalized) {
        expect(normalizeTaskStatusString(status), equals(status));
      }
    });
  });

  // ---------------------------------------------------------------------------
  // taskIconFromStatusString — worked examples
  // ---------------------------------------------------------------------------

  group('taskIconFromStatusString', () {
    test('OPEN returns radio_button_unchecked', () {
      expect(
        taskIconFromStatusString('OPEN'),
        equals(Icons.radio_button_unchecked),
      );
    });

    test('GROOMED returns edit_outlined', () {
      expect(
        taskIconFromStatusString('GROOMED'),
        equals(Icons.edit_outlined),
      );
    });

    test('IN PROGRESS returns play_arrow_rounded', () {
      expect(
        taskIconFromStatusString('IN PROGRESS'),
        equals(Icons.play_arrow_rounded),
      );
    });

    test('BLOCKED returns warning_sharp', () {
      expect(
        taskIconFromStatusString('BLOCKED'),
        equals(Icons.warning_sharp),
      );
    });

    test('ON HOLD returns pause', () {
      expect(taskIconFromStatusString('ON HOLD'), equals(Icons.pause));
    });

    test('DONE returns check_circle_outline', () {
      expect(
        taskIconFromStatusString('DONE'),
        equals(Icons.check_circle_outline),
      );
    });

    test('REJECTED returns close_rounded', () {
      expect(
        taskIconFromStatusString('REJECTED'),
        equals(Icons.close_rounded),
      );
    });

    test('unknown status returns help_outline', () {
      expect(
        taskIconFromStatusString('TOTALLY_UNKNOWN'),
        equals(Icons.help_outline),
      );
    });

    test('accepts alias OPENING (normalized to OPEN)', () {
      expect(
        taskIconFromStatusString('OPENING'),
        equals(Icons.radio_button_unchecked),
      );
    });

    test('accepts alias INPROGRESS (normalized to IN PROGRESS)', () {
      expect(
        taskIconFromStatusString('INPROGRESS'),
        equals(Icons.play_arrow_rounded),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // taskIconFromStatusString — Glados properties
  // ---------------------------------------------------------------------------

  group('taskIconFromStatusString — properties', () {
    glados.Glados(
      glados.any.statusString,
      glados.ExploreConfig(numRuns: 120),
    ).test('always returns a non-null IconData for any string', (s) {
      // The switch has a default arm, so this should never throw.
      final icon = taskIconFromStatusString(s);
      expect(icon, isNotNull);
    }, tags: 'glados');

    // Every known normalized status should return an icon from the explicit arm
    // (i.e., NOT the fallback help_outline).
    for (final status in _knownNormalized) {
      test('known status "$status" does not return the fallback icon', () {
        expect(
          taskIconFromStatusString(status),
          isNot(equals(Icons.help_outline)),
        );
      });
    }
  });

  // ---------------------------------------------------------------------------
  // taskColorFromStatusString — worked examples
  // ---------------------------------------------------------------------------

  group('taskColorFromStatusString', () {
    test('OPEN returns different colors for light vs dark', () {
      final darkColor = taskColorFromStatusString('OPEN');
      final lightColor = taskColorFromStatusString(
        'OPEN',
        brightness: Brightness.light,
      );
      expect(darkColor, isNot(equals(lightColor)));
    });

    test('DONE light mode returns a Color value', () {
      final c = taskColorFromStatusString('DONE', brightness: Brightness.light);
      expect(c, isNotNull);
    });

    test('BLOCKED dark mode returns a Color value', () {
      final c = taskColorFromStatusString(
        'BLOCKED',
        brightness: Brightness.dark,
      );
      expect(c, isNotNull);
    });

    test('unknown status returns fallback grey-ish color (not null)', () {
      final c = taskColorFromStatusString('DOES_NOT_EXIST');
      expect(c, isNotNull);
    });
  });

  // ---------------------------------------------------------------------------
  // taskColorFromStatusString — Glados properties
  // ---------------------------------------------------------------------------

  group('taskColorFromStatusString — properties', () {
    glados.Glados(
      glados.any.statusString,
      glados.ExploreConfig(numRuns: 120),
    ).test('always returns a Color for dark brightness (no throw)', (s) {
      expect(
        () => taskColorFromStatusString(s, brightness: Brightness.dark),
        returnsNormally,
      );
    }, tags: 'glados');

    glados.Glados(
      glados.any.statusString,
      glados.ExploreConfig(numRuns: 120),
    ).test('always returns a Color for light brightness (no throw)', (s) {
      expect(
        () => taskColorFromStatusString(s, brightness: Brightness.light),
        returnsNormally,
      );
    }, tags: 'glados');
  });
}
