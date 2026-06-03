import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/utils/entry_type_gating.dart';
import 'package:lotti/features/journal/utils/entry_types.dart';

/// All entry types that are gated behind the "dashboards" flag.
const _dashboardGatedTypes = <String>{
  'MeasurementEntry',
  'QuantitativeEntry',
  'SurveyEntry',
  'WorkoutEntry',
};

void main() {
  // ---------------------------------------------------------------------------
  // computeAllowedEntryTypes — exhaustive flag combinations
  // ---------------------------------------------------------------------------

  group('computeAllowedEntryTypes', () {
    test('all flags true returns the full entryTypes list', () {
      final result = computeAllowedEntryTypes(
        events: true,
        habits: true,
        dashboards: true,
      );
      expect(result, equals(entryTypes));
    });

    test('events=false excludes JournalEvent', () {
      final result = computeAllowedEntryTypes(
        events: false,
        habits: true,
        dashboards: true,
      );
      expect(result, isNot(contains('JournalEvent')));
      // All other types are present.
      for (final t in entryTypes) {
        if (t != 'JournalEvent') {
          expect(result, contains(t), reason: 'Missing type: $t');
        }
      }
    });

    test('habits=false excludes HabitCompletionEntry', () {
      final result = computeAllowedEntryTypes(
        events: true,
        habits: false,
        dashboards: true,
      );
      expect(result, isNot(contains('HabitCompletionEntry')));
      for (final t in entryTypes) {
        if (t != 'HabitCompletionEntry') {
          expect(result, contains(t), reason: 'Missing type: $t');
        }
      }
    });

    test('dashboards=false excludes MeasurementEntry, QuantitativeEntry, '
        'SurveyEntry, WorkoutEntry', () {
      final result = computeAllowedEntryTypes(
        events: true,
        habits: true,
        dashboards: false,
      );
      for (final t in _dashboardGatedTypes) {
        expect(result, isNot(contains(t)), reason: 'Should be excluded: $t');
      }
      for (final t in entryTypes) {
        if (!_dashboardGatedTypes.contains(t)) {
          expect(result, contains(t), reason: 'Should be included: $t');
        }
      }
    });

    test('all flags false excludes JournalEvent, HabitCompletionEntry and all '
        'dashboard types', () {
      final result = computeAllowedEntryTypes(
        events: false,
        habits: false,
        dashboards: false,
      );
      expect(result, isNot(contains('JournalEvent')));
      expect(result, isNot(contains('HabitCompletionEntry')));
      for (final t in _dashboardGatedTypes) {
        expect(result, isNot(contains(t)));
      }
    });

    test('result is always a subset of entryTypes', () {
      for (final events in <bool>[true, false]) {
        for (final habits in <bool>[true, false]) {
          for (final dashboards in <bool>[true, false]) {
            final result = computeAllowedEntryTypes(
              events: events,
              habits: habits,
              dashboards: dashboards,
            );
            for (final t in result) {
              expect(
                entryTypes,
                contains(t),
                reason: 'Unexpected type $t in result for '
                    'events=$events habits=$habits dashboards=$dashboards',
              );
            }
          }
        }
      }
    });

    test('result contains no duplicates for any flag combination', () {
      for (final events in <bool>[true, false]) {
        for (final habits in <bool>[true, false]) {
          for (final dashboards in <bool>[true, false]) {
            final result = computeAllowedEntryTypes(
              events: events,
              habits: habits,
              dashboards: dashboards,
            );
            expect(
              result.length,
              equals(result.toSet().length),
              reason: 'Duplicates for '
                  'events=$events habits=$habits dashboards=$dashboards',
            );
          }
        }
      }
    });

    test('result preserves the ordering of entryTypes', () {
      // The returned list is filtered from entryTypes in order; verify order.
      final result = computeAllowedEntryTypes(
        events: true,
        habits: true,
        dashboards: true,
      );
      final indices = result.map(entryTypes.indexOf).toList();
      for (var i = 1; i < indices.length; i++) {
        expect(
          indices[i],
          greaterThan(indices[i - 1]),
          reason: 'Order not preserved at position $i',
        );
      }
    });
  });
}
