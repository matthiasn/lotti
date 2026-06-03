import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/services/logging_domains.dart';

/// Structural contract tests for the [LogDomain] enum.
///
/// These tests assert the invariants documented in [LogDomain]'s comments
/// and serve as regression guards for future enum additions:
///
/// - `wireName` equals `name` (stable wire format, grep-friendly).
/// - `flagName` follows the `log_<snake>` convention.
/// - Only [LogDomain.sync] has `routesToSyncFile == true`.
/// - Only [LogDomain.sync] has `defaultEnabled == false`.
/// - All `flagName` values are unique across the enum (no duplicate flag keys).
/// - All `label` values are non-empty.
void main() {
  group('LogDomain — structural invariants', () {
    test('wireName equals name for every domain', () {
      for (final domain in LogDomain.values) {
        expect(
          domain.wireName,
          equals(domain.name),
          reason: '${domain.name}.wireName must equal .name for '
              'stable wire format',
        );
      }
    });

    test('every flagName starts with "log_"', () {
      for (final domain in LogDomain.values) {
        expect(
          domain.flagName.startsWith('log_'),
          isTrue,
          reason: '${domain.name}.flagName="${domain.flagName}" '
              'must start with "log_"',
        );
      }
    });

    test('every flagName contains only lowercase letters, digits, and underscores', () {
      final validChars = RegExp(r'^[a-z0-9_]+$');
      for (final domain in LogDomain.values) {
        expect(
          validChars.hasMatch(domain.flagName),
          isTrue,
          reason: '${domain.name}.flagName="${domain.flagName}" '
              'must contain only [a-z0-9_]',
        );
      }
    });

    test('all flagName values are unique across the enum', () {
      final flagNames = LogDomain.values.map((d) => d.flagName).toList();
      final uniqueCount = flagNames.toSet().length;
      expect(
        uniqueCount,
        equals(LogDomain.values.length),
        reason: 'Duplicate flagName detected: $flagNames',
      );
    });

    test('every label is non-empty', () {
      for (final domain in LogDomain.values) {
        expect(
          domain.label,
          isNotEmpty,
          reason: '${domain.name}.label must not be empty',
        );
      }
    });

    test('only LogDomain.sync routes to the sync file', () {
      for (final domain in LogDomain.values) {
        if (domain == LogDomain.sync) {
          expect(
            domain.routesToSyncFile,
            isTrue,
            reason: 'LogDomain.sync must route to the sync file',
          );
        } else {
          expect(
            domain.routesToSyncFile,
            isFalse,
            reason: '${domain.name}.routesToSyncFile must be false; '
                'only sync routes there',
          );
        }
      }
    });

    test('only LogDomain.sync is disabled by default', () {
      for (final domain in LogDomain.values) {
        if (domain == LogDomain.sync) {
          expect(
            domain.defaultEnabled,
            isFalse,
            reason: 'LogDomain.sync must be disabled by default',
          );
        } else {
          expect(
            domain.defaultEnabled,
            isTrue,
            reason: '${domain.name}.defaultEnabled must be true; '
                'only sync is off by default',
          );
        }
      }
    });

    test('LogDomain.sync has the canonical flag name "log_sync"', () {
      expect(LogDomain.sync.flagName, equals('log_sync'));
    });

    test('LogDomain.sync wireName is "sync"', () {
      expect(LogDomain.sync.wireName, equals('sync'));
    });

    test('all domain names are unique (no duplicate enum entries)', () {
      final names = LogDomain.values.map((d) => d.name).toList();
      expect(names.toSet().length, equals(names.length));
    });

    test('enum contains at least the core domains', () {
      // Regression guard: these names must not be removed or renamed without
      // a deliberate migration (callers depend on them at runtime).
      const requiredNames = <String>[
        'sync',
        'ai',
        'persistence',
        'database',
        'labels',
        'health',
        'habits',
        'navigation',
        'general',
      ];
      final domainNames = LogDomain.values.map((d) => d.name).toSet();
      for (final required in requiredNames) {
        expect(
          domainNames.contains(required),
          isTrue,
          reason: 'LogDomain.$required must exist',
        );
      }
    });
  });
}
