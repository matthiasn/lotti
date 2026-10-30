// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/journal/state/journal_page_subscriptions.dart';
import 'package:lotti/features/journal/utils/entry_type_gating.dart';

/// Convenience: build a [JournalConfigFlags] record.
JournalConfigFlags _flags({
  bool events = true,
  bool habits = true,
  bool dashboards = true,
  bool vectorSearch = false,
  bool projects = true,
  bool relationships = true,
}) => (
  events: events,
  habits: habits,
  dashboards: dashboards,
  vectorSearch: vectorSearch,
  projects: projects,
  relationships: relationships,
);

/// Convenience: invoke `applyJournalConfigFlags` with sensible defaults so
/// individual tests only have to override what they care about.
ConfigFlagResult _apply({
  JournalConfigFlags? flags,
  bool enableEvents = true,
  bool enableHabits = true,
  bool enableDashboards = true,
  bool enableRelationships = true,
  bool enableVectorSearch = false,
  bool enableProjects = true,
  Set<String>? selectedEntryTypes,
  Set<String> selectedProjectIds = const {},
}) {
  final resolvedFlags = flags ?? _flags();
  final resolvedTypes =
      selectedEntryTypes ??
      computeAllowedEntryTypes(
        events: enableEvents,
        habits: enableHabits,
        dashboards: enableDashboards,
        relationships: enableRelationships,
      ).toSet();

  return JournalPageSubscriptions.applyJournalConfigFlags(
    flags: resolvedFlags,
    enableEvents: enableEvents,
    enableHabits: enableHabits,
    enableDashboards: enableDashboards,
    enableRelationships: enableRelationships,
    enableVectorSearch: enableVectorSearch,
    enableProjects: enableProjects,
    selectedEntryTypes: resolvedTypes,
    selectedProjectIds: selectedProjectIds,
  );
}

void main() {
  group('applyJournalConfigFlags — flag propagation', () {
    test('result.enableEvents reflects the incoming flags.events value', () {
      final result = _apply(flags: _flags(events: false));
      expect(result.enableEvents, isFalse);
    });

    test('result.enableHabits reflects the incoming flags.habits value', () {
      final result = _apply(flags: _flags(habits: false));
      expect(result.enableHabits, isFalse);
    });

    test(
      'result.enableDashboards reflects the incoming flags.dashboards value',
      () {
        final result = _apply(flags: _flags(dashboards: false));
        expect(result.enableDashboards, isFalse);
      },
    );

    test(
      'result.enableProjects reflects the incoming flags.projects value',
      () {
        final result = _apply(flags: _flags(projects: false));
        expect(result.enableProjects, isFalse);
      },
    );

    test('result.enableVectorSearch reflects flags.vectorSearch', () {
      final result = _apply(flags: _flags(vectorSearch: true));
      expect(result.enableVectorSearch, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // selectedEntryTypes logic
  // ---------------------------------------------------------------------------

  group('applyJournalConfigFlags — selectedEntryTypes', () {
    test(
      'when selectedEntryTypes is empty, result is the full new allowed set',
      () {
        final newFlags = _flags(events: true, habits: true, dashboards: true);
        final expected = computeAllowedEntryTypes(
          events: true,
          habits: true,
          dashboards: true,
          relationships: true,
        ).toSet();

        final result = _apply(
          flags: newFlags,
          selectedEntryTypes: const <String>{},
        );

        expect(result.selectedEntryTypes, equals(expected));
      },
    );

    test('when all previously-allowed types were selected, switches to new '
        'allowed set (reset-on-change behavior)', () {
      // Old state: all types allowed (events+habits+dashboards on).
      final oldAllowed = computeAllowedEntryTypes(
        events: true,
        habits: true,
        dashboards: true,
        relationships: true,
      ).toSet();

      // New flags: events disabled.
      final newFlags = _flags(events: false, habits: true, dashboards: true);
      final newAllowed = computeAllowedEntryTypes(
        events: false,
        habits: true,
        dashboards: true,
        relationships: true,
      ).toSet();

      final result = _apply(
        flags: newFlags,
        enableEvents: true,
        enableHabits: true,
        enableDashboards: true,
        selectedEntryTypes: oldAllowed,
      );

      expect(result.selectedEntryTypes, equals(newAllowed));
    });

    test('when a partial selection was active, result is the intersection with '
        'the new allowed set', () {
      // Old partial selection: Task + JournalEvent only.
      const partial = <String>{'Task', 'JournalEvent'};

      // New flags: events disabled → JournalEvent becomes disallowed.
      final newFlags = _flags(events: false, habits: true, dashboards: true);

      final result = _apply(
        flags: newFlags,
        enableEvents: true,
        enableHabits: true,
        enableDashboards: true,
        selectedEntryTypes: partial,
      );

      // JournalEvent must be removed; Task remains.
      expect(result.selectedEntryTypes, equals(const <String>{'Task'}));
    });

    test('selectedEntryTypes is always a subset of the new allowed set', () {
      const partial = <String>{'Task', 'JournalEntry', 'JournalEvent'};
      final newFlags = _flags(events: false);

      final result = _apply(
        flags: newFlags,
        enableEvents: true,
        enableHabits: true,
        enableDashboards: true,
        selectedEntryTypes: partial,
      );

      final newAllowed = computeAllowedEntryTypes(
        events: false,
        habits: true,
        dashboards: true,
        relationships: true,
      ).toSet();

      for (final t in result.selectedEntryTypes) {
        expect(newAllowed, contains(t));
      }
    });
  });

  // ---------------------------------------------------------------------------
  // projects filtering
  // ---------------------------------------------------------------------------

  group('applyJournalConfigFlags — project filter', () {
    test('clears selectedProjectIds and sets shouldRefresh when projects flag '
        'turns off and projectIds were non-empty', () {
      final result = _apply(
        flags: _flags(projects: false),
        enableProjects: true,
        selectedProjectIds: const <String>{'proj-1', 'proj-2'},
      );

      expect(result.selectedProjectIds, isEmpty);
      expect(result.shouldRefresh, isTrue);
    });

    test('keeps selectedProjectIds unchanged when projects flag is on and ids '
        'are non-empty', () {
      final result = _apply(
        flags: _flags(projects: true),
        selectedProjectIds: const <String>{'proj-1'},
      );

      expect(result.selectedProjectIds, equals(const <String>{'proj-1'}));
    });

    test('shouldRefresh stays false when projects flag is off but no project '
        'ids were selected', () {
      final result = _apply(
        flags: _flags(projects: false),
        selectedProjectIds: const <String>{},
      );

      // No project IDs to clear → should NOT cause a refresh for this reason.
      expect(result.selectedProjectIds, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // search by meaning turning on or off
  // ---------------------------------------------------------------------------

  group('applyJournalConfigFlags — search by meaning', () {
    for (final (was, now) in [(false, true), (true, false)]) {
      test('turning it ${now ? 'on' : 'off'} refreshes: it changes what a '
          'search lists', () {
        final result = _apply(
          flags: _flags(vectorSearch: now),
          enableVectorSearch: was,
        );

        expect(result.enableVectorSearch, now);
        expect(result.shouldRefresh, isTrue);
      });
    }

    for (final on in [false, true]) {
      test('staying ${on ? 'on' : 'off'} refreshes nothing', () {
        final result = _apply(
          flags: _flags(vectorSearch: on),
          enableVectorSearch: on,
        );

        expect(result.shouldRefresh, isFalse);
      });
    }
  });

  group('applyJournalConfigFlags — generated invariants', () {
    glados.Glados2(
      glados.IntAnys(glados.any).intInRange(0, 16384),
      glados.IntAnys(glados.any).intInRange(0, 3),
      glados.ExploreConfig(numRuns: 160),
    ).test('structural invariants hold across the input cross-product', (
      bits,
      entrySelKind,
    ) {
      bool bit(int n) => (bits >> n) & 1 == 1;

      final flags = _flags(
        events: bit(0),
        habits: bit(1),
        dashboards: bit(2),
        vectorSearch: bit(3),
        projects: bit(4),
        relationships: bit(12),
      );
      final enableEvents = bit(5);
      final enableRelationships = bit(13);
      final enableHabits = bit(6);
      final enableDashboards = bit(7);
      final enableVectorSearch = bit(10);
      final selectedProjectIds = bit(11) ? {'project-1'} : <String>{};

      final oldAllowed = computeAllowedEntryTypes(
        events: enableEvents,
        habits: enableHabits,
        dashboards: enableDashboards,
        relationships: enableRelationships,
      ).toSet();
      final selectedEntryTypes = switch (entrySelKind) {
        0 => <String>{},
        1 => oldAllowed,
        _ => oldAllowed.take(oldAllowed.length ~/ 2).toSet(),
      };

      {
        final result = JournalPageSubscriptions.applyJournalConfigFlags(
          flags: flags,
          enableEvents: enableEvents,
          enableHabits: enableHabits,
          enableDashboards: enableDashboards,
          enableRelationships: enableRelationships,
          enableVectorSearch: enableVectorSearch,
          enableProjects: bit(4),
          selectedEntryTypes: selectedEntryTypes,
          selectedProjectIds: selectedProjectIds,
        );

        final newAllowed = computeAllowedEntryTypes(
          events: flags.events,
          habits: flags.habits,
          dashboards: flags.dashboards,
          relationships: flags.relationships,
        ).toSet();
        final reason = 'bits=$bits entrySelKind=$entrySelKind';

        // Flags propagate verbatim.
        expect(result.enableEvents, flags.events, reason: reason);
        expect(result.enableHabits, flags.habits, reason: reason);
        expect(result.enableDashboards, flags.dashboards, reason: reason);
        expect(
          result.enableRelationships,
          flags.relationships,
          reason: reason,
        );
        expect(result.enableVectorSearch, flags.vectorSearch, reason: reason);
        expect(result.enableProjects, flags.projects, reason: reason);

        // The new selection is always a subset of the new allowed set.
        expect(
          result.selectedEntryTypes.difference(newAllowed),
          isEmpty,
          reason: reason,
        );

        // Empty or fully-selected previous selection snaps to the new
        // allowed set (no partial carry-over).
        if (selectedEntryTypes.isEmpty ||
            (oldAllowed.isNotEmpty &&
                selectedEntryTypes.containsAll(oldAllowed) &&
                oldAllowed.containsAll(selectedEntryTypes))) {
          expect(result.selectedEntryTypes, newAllowed, reason: reason);
        }

        // Project selection never survives a disabled projects flag.
        if (!flags.projects) {
          expect(result.selectedProjectIds, isEmpty, reason: reason);
        }

        // shouldRefresh fires exactly when search by meaning turns on or
        // off, or a project selection is cleared.
        final projectsCleared =
            !flags.projects && selectedProjectIds.isNotEmpty;
        expect(
          result.shouldRefresh,
          flags.vectorSearch != enableVectorSearch || projectsCleared,
          reason: reason,
        );
      }
    }, tags: 'glados');
  });
}
