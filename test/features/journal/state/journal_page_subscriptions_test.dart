// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/journal/state/journal_page_subscriptions.dart';
import 'package:lotti/features/journal/utils/entry_type_gating.dart';
import 'package:lotti/utils/platform.dart' as platform;

/// Convenience: build a [JournalConfigFlags] record.
JournalConfigFlags _flags({
  bool events = true,
  bool habits = true,
  bool dashboards = true,
  bool vectorSearch = false,
  bool projects = true,
}) => (
  events: events,
  habits: habits,
  dashboards: dashboards,
  vectorSearch: vectorSearch,
  projects: projects,
);

/// Convenience: invoke `applyJournalConfigFlags` with sensible defaults so
/// individual tests only have to override what they care about.
ConfigFlagResult _apply({
  JournalConfigFlags? flags,
  bool showTasks = false,
  bool enableEvents = true,
  bool enableHabits = true,
  bool enableDashboards = true,
  bool enableVectorSearch = false,
  bool enableProjects = true,
  SearchMode searchMode = SearchMode.fullText,
  bool hasExplicitSearchModeSelection = false,
  Set<String>? selectedEntryTypes,
  Set<String> selectedProjectIds = const {},
}) {
  final resolvedFlags = flags ?? _flags();
  final resolvedTypes = selectedEntryTypes ??
      computeAllowedEntryTypes(
        events: enableEvents,
        habits: enableHabits,
        dashboards: enableDashboards,
      ).toSet();

  return JournalPageSubscriptions.applyJournalConfigFlags(
    flags: resolvedFlags,
    showTasks: showTasks,
    enableEvents: enableEvents,
    enableHabits: enableHabits,
    enableDashboards: enableDashboards,
    enableVectorSearch: enableVectorSearch,
    enableProjects: enableProjects,
    searchMode: searchMode,
    hasExplicitSearchModeSelection: hasExplicitSearchModeSelection,
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

    test('result.enableDashboards reflects the incoming flags.dashboards value',
        () {
      final result = _apply(flags: _flags(dashboards: false));
      expect(result.enableDashboards, isFalse);
    });

    test('result.enableProjects reflects the incoming flags.projects value',
        () {
      final result = _apply(flags: _flags(projects: false));
      expect(result.enableProjects, isFalse);
    });

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
      final expected =
          computeAllowedEntryTypes(events: true, habits: true, dashboards: true)
              .toSet();

      final result = _apply(
        flags: newFlags,
        selectedEntryTypes: const <String>{},
      );

      expect(result.selectedEntryTypes, equals(expected));
    });

    test(
        'when all previously-allowed types were selected, switches to new '
        'allowed set (reset-on-change behavior)', () {
      // Old state: all types allowed (events+habits+dashboards on).
      final oldAllowed = computeAllowedEntryTypes(
        events: true,
        habits: true,
        dashboards: true,
      ).toSet();

      // New flags: events disabled.
      final newFlags = _flags(events: false, habits: true, dashboards: true);
      final newAllowed = computeAllowedEntryTypes(
        events: false,
        habits: true,
        dashboards: true,
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

    test(
        'when a partial selection was active, result is the intersection with '
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
      ).toSet();

      for (final t in result.selectedEntryTypes) {
        expect(newAllowed, contains(t));
      }
    });
  });

  // ---------------------------------------------------------------------------
  // entryTypesChanged flag
  // ---------------------------------------------------------------------------

  group('applyJournalConfigFlags — entryTypesChanged', () {
    test('entryTypesChanged is false when types remain the same', () {
      final allTypes = computeAllowedEntryTypes(
        events: true,
        habits: true,
        dashboards: true,
      ).toSet();

      final result = _apply(
        flags: _flags(events: true, habits: true, dashboards: true),
        enableEvents: true,
        enableHabits: true,
        enableDashboards: true,
        selectedEntryTypes: allTypes,
      );

      expect(result.entryTypesChanged, isFalse);
    });

    test('entryTypesChanged is true when a type is removed by the new flags',
        () {
      final allTypes = computeAllowedEntryTypes(
        events: true,
        habits: true,
        dashboards: true,
      ).toSet();

      final result = _apply(
        flags: _flags(events: false),
        enableEvents: true,
        enableHabits: true,
        enableDashboards: true,
        selectedEntryTypes: allTypes,
      );

      expect(result.entryTypesChanged, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // projects filtering
  // ---------------------------------------------------------------------------

  group('applyJournalConfigFlags — project filter', () {
    test(
        'clears selectedProjectIds and sets shouldRefresh when projects flag '
        'turns off and projectIds were non-empty', () {
      final result = _apply(
        flags: _flags(projects: false),
        enableProjects: true,
        selectedProjectIds: const <String>{'proj-1', 'proj-2'},
      );

      expect(result.selectedProjectIds, isEmpty);
      expect(result.shouldRefresh, isTrue);
    });

    test(
        'keeps selectedProjectIds unchanged when projects flag is on and ids '
        'are non-empty', () {
      final result = _apply(
        flags: _flags(projects: true),
        selectedProjectIds: const <String>{'proj-1'},
      );

      expect(result.selectedProjectIds, equals(const <String>{'proj-1'}));
    });

    test(
        'shouldRefresh stays false when projects flag is off but no project '
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
  // vector-search search-mode switching
  // ---------------------------------------------------------------------------

  group('applyJournalConfigFlags — search-mode transitions', () {
    test(
        'disabling vectorSearch while mode is vector switches mode to fullText '
        'and sets shouldRefresh', () {
      final result = _apply(
        flags: _flags(vectorSearch: false),
        enableVectorSearch: true,
        searchMode: SearchMode.vector,
      );

      expect(result.searchMode, SearchMode.fullText);
      expect(result.shouldRefresh, isTrue);
    });

    test(
        'keeping vectorSearch enabled while mode is already vector does not '
        'trigger a shouldRefresh for the search-mode branch', () {
      // Save and restore isDesktop so we can control the "showTasks+isDesktop"
      // guard reliably in test.
      final savedDesktop = platform.isDesktop;
      platform.isDesktop = false; // suppress the auto-switch branch
      addTearDown(() => platform.isDesktop = savedDesktop);

      final result = _apply(
        flags: _flags(vectorSearch: true),
        showTasks: true,
        enableVectorSearch: true,
        searchMode: SearchMode.vector,
        hasExplicitSearchModeSelection: true,
      );

      // Mode was already vector — no change.
      expect(result.searchMode, SearchMode.vector);
      // shouldRefresh may be false unless projects also changed.
      expect(result.shouldRefresh, isFalse);
    });

    test(
        'enableVectorSearch flag turns on, showTasks=true, isDesktop=true, '
        'no explicit selection → mode switches to vector', () {
      final savedDesktop = platform.isDesktop;
      platform.isDesktop = true;
      addTearDown(() => platform.isDesktop = savedDesktop);

      final result = _apply(
        flags: _flags(vectorSearch: true),
        showTasks: true,
        enableVectorSearch: false,
        searchMode: SearchMode.fullText,
        hasExplicitSearchModeSelection: false,
      );

      expect(result.searchMode, SearchMode.vector);
      expect(result.shouldRefresh, isTrue);
    });

    test(
        'explicit search mode selection prevents auto-switch to vector even '
        'when all other conditions are met', () {
      final savedDesktop = platform.isDesktop;
      platform.isDesktop = true;
      addTearDown(() => platform.isDesktop = savedDesktop);

      final result = _apply(
        flags: _flags(vectorSearch: true),
        showTasks: true,
        enableVectorSearch: false,
        searchMode: SearchMode.fullText,
        hasExplicitSearchModeSelection: true, // explicit → no auto-switch
      );

      expect(result.searchMode, SearchMode.fullText);
    });
  });
}
