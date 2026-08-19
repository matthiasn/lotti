import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/design_system/theme/design_tokens.dart';
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
        equals(LottiIcons.radioUnselected),
      );
    });

    test('GROOMED returns edit_outlined', () {
      expect(
        taskIconFromStatusString('GROOMED'),
        equals(LottiIcons.edit),
      );
    });

    test('IN PROGRESS returns play_arrow_rounded', () {
      expect(
        taskIconFromStatusString('IN PROGRESS'),
        equals(LottiIcons.play),
      );
    });

    test('BLOCKED returns warning_sharp', () {
      expect(
        taskIconFromStatusString('BLOCKED'),
        equals(LottiIcons.warning),
      );
    });

    test('ON HOLD returns pause', () {
      expect(taskIconFromStatusString('ON HOLD'), equals(LottiIcons.pause));
    });

    test('DONE returns check_circle_outline', () {
      expect(
        taskIconFromStatusString('DONE'),
        equals(LottiIcons.confirmCircled),
      );
    });

    test('REJECTED returns close_rounded', () {
      expect(
        taskIconFromStatusString('REJECTED'),
        equals(LottiIcons.close),
      );
    });

    test('unknown status returns help_outline', () {
      expect(
        taskIconFromStatusString('TOTALLY_UNKNOWN'),
        equals(LottiIcons.help),
      );
    });

    test('accepts alias OPENING (normalized to OPEN)', () {
      expect(
        taskIconFromStatusString('OPENING'),
        equals(LottiIcons.radioUnselected),
      );
    });

    test('accepts alias INPROGRESS (normalized to IN PROGRESS)', () {
      expect(
        taskIconFromStatusString('INPROGRESS'),
        equals(LottiIcons.play),
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
          isNot(equals(LottiIcons.help)),
        );
      });
    }

    // Exhaustiveness oracle: a string maps to the fallback icon if and only if
    // its normalized form is not one of the known statuses. This pins the
    // switch's default arm to exactly the unknown-input case.
    glados.Glados(
      glados.any.statusString,
      glados.ExploreConfig(numRuns: 150),
    ).test('fallback icon iff normalized status is unknown', (s) {
      final isKnown = _knownNormalized.contains(normalizeTaskStatusString(s));
      final usesFallback = taskIconFromStatusString(s) == LottiIcons.help;
      expect(usesFallback, equals(!isKnown));
    }, tags: 'glados');
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

    // Exhaustiveness oracle: any string whose normalized form is unknown falls
    // through to the default arm, which uses the same grey as OPEN. We assert
    // unknown inputs match the OPEN colour (the documented fallback) for both
    // brightnesses. (We cannot use a strict iff here because OPEN itself shares
    // the grey fallback colour.)
    glados.Glados(
      glados.any.statusString,
      glados.ExploreConfig(numRuns: 150),
    ).test('unknown status maps to the OPEN/grey fallback colour', (s) {
      if (_knownNormalized.contains(normalizeTaskStatusString(s))) {
        return; // only assert on genuinely unknown inputs
      }
      for (final brightness in [Brightness.light, Brightness.dark]) {
        expect(
          taskColorFromStatusString(s, brightness: brightness),
          equals(taskColorFromStatusString('OPEN', brightness: brightness)),
        );
      }
    }, tags: 'glados');
  });
}
