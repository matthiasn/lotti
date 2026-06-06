import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';

void main() {
  group('TasksFilter.fromJson', () {
    test('round-trips a fully populated filter', () {
      const filter = TasksFilter(
        selectedCategoryIds: {'cat-1', 'cat-2'},
        selectedProjectIds: {'proj-1'},
        selectedTaskStatuses: {'OPEN', 'DONE'},
        selectedLabelIds: {'label-1'},
        selectedPriorities: {'P0', 'P2'},
        sortOption: TaskSortOption.byDueDate,
        showCreationDate: true,
        showDueDate: false,
        showCoverArt: false,
        showProjectsHeader: false,
        showDistances: true,
        agentAssignmentFilter: AgentAssignmentFilter.hasAgent,
      );

      final restored = TasksFilter.fromJson(filter.toJson());

      expect(restored, filter);
    });

    test('empty JSON yields all defaults', () {
      final filter = TasksFilter.fromJson(const {});

      expect(filter, const TasksFilter());
      expect(filter.selectedCategoryIds, isEmpty);
      expect(filter.sortOption, TaskSortOption.byPriority);
      expect(filter.showDueDate, isTrue);
      expect(filter.showCoverArt, isTrue);
      expect(filter.showProjectsHeader, isTrue);
      expect(filter.agentAssignmentFilter, AgentAssignmentFilter.all);
    });

    test('missing optional fields fall back to defaults individually', () {
      final filter = TasksFilter.fromJson(const {
        'selectedCategoryIds': ['cat-1'],
        'sortOption': 'byDate',
      });

      expect(filter.selectedCategoryIds, {'cat-1'});
      expect(filter.sortOption, TaskSortOption.byDate);
      // Everything else keeps its default.
      expect(filter.selectedTaskStatuses, isEmpty);
      expect(filter.showCreationDate, isFalse);
      expect(filter.showDueDate, isTrue);
    });

    test('all enum values survive a serialization round-trip', () {
      for (final sort in TaskSortOption.values) {
        for (final agentFilter in AgentAssignmentFilter.values) {
          final filter = TasksFilter(
            sortOption: sort,
            agentAssignmentFilter: agentFilter,
          );
          expect(TasksFilter.fromJson(filter.toJson()), filter);
        }
      }
    });

    test('unknown enum string throws (malformed persisted state)', () {
      expect(
        () => TasksFilter.fromJson(const {'sortOption': 'byMagic'}),
        throwsArgumentError,
      );
      expect(
        () => TasksFilter.fromJson(const {'agentAssignmentFilter': 'maybe'}),
        throwsArgumentError,
      );
    });

    test('malformed collection type throws instead of silently coercing', () {
      expect(
        () => TasksFilter.fromJson(const {'selectedCategoryIds': 'not-a-list'}),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group('JournalPageState', () {
    test('defaults match the documented initial page state', () {
      const state = JournalPageState();

      expect(state.match, isEmpty);
      expect(state.filters, isEmpty);
      expect(state.showPrivateEntries, isFalse);
      expect(state.showTasks, isFalse);
      expect(state.pagingController, isNull);
      expect(state.sortOption, TaskSortOption.byPriority);
      expect(state.searchMode, SearchMode.fullText);
      expect(state.agentAssignmentFilter, AgentAssignmentFilter.all);
      expect(state.vectorSearchInFlight, isFalse);
      expect(state.vectorSearchResultCount, 0);
      expect(state.vectorSearchDistances, isEmpty);
    });

    test('copyWith replaces only the requested fields', () {
      const state = JournalPageState();

      final updated = state.copyWith(
        match: 'query',
        filters: {DisplayFilter.starredEntriesOnly},
        selectedTaskStatuses: {'OPEN'},
        searchMode: SearchMode.vector,
      );

      expect(updated.match, 'query');
      expect(updated.filters, {DisplayFilter.starredEntriesOnly});
      expect(updated.selectedTaskStatuses, {'OPEN'});
      expect(updated.searchMode, SearchMode.vector);
      // Untouched fields stay at their previous values.
      expect(updated.showTasks, state.showTasks);
      expect(updated.sortOption, state.sortOption);
      expect(updated.showDueDate, state.showDueDate);
    });
  });
}
