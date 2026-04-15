// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/ui/filtering/task_project_selection_modal.dart';
import 'package:lotti/features/tasks/ui/filtering/tasks_filter_sheet_state.dart';

import '../../../../helpers/entity_factories.dart';
import '../../../../widget_test_utils.dart';

void main() {
  group('TasksFilterSortIds', () {
    test('maps TaskSortOption to string IDs', () {
      expect(
        TasksFilterSortIds.fromSortOption(TaskSortOption.byDueDate),
        'byDueDate',
      );
      expect(
        TasksFilterSortIds.fromSortOption(TaskSortOption.byDate),
        'byDate',
      );
      expect(
        TasksFilterSortIds.fromSortOption(TaskSortOption.byPriority),
        'byPriority',
      );
    });

    test('maps string IDs back to TaskSortOption', () {
      expect(
        TasksFilterSortIds.toSortOption('byDueDate'),
        TaskSortOption.byDueDate,
      );
      expect(
        TasksFilterSortIds.toSortOption('byDate'),
        TaskSortOption.byDate,
      );
      expect(
        TasksFilterSortIds.toSortOption('byPriority'),
        TaskSortOption.byPriority,
      );
      expect(
        TasksFilterSortIds.toSortOption('unknown'),
        TaskSortOption.byPriority,
      );
    });
  });

  group('TasksFilterAgentIds', () {
    test('maps AgentAssignmentFilter to string IDs', () {
      expect(TasksFilterAgentIds.fromFilter(AgentAssignmentFilter.all), 'all');
      expect(
        TasksFilterAgentIds.fromFilter(AgentAssignmentFilter.hasAgent),
        'hasAgent',
      );
      expect(
        TasksFilterAgentIds.fromFilter(AgentAssignmentFilter.noAgent),
        'noAgent',
      );
    });

    test('maps string IDs back to AgentAssignmentFilter', () {
      expect(
        TasksFilterAgentIds.toFilter('all'),
        AgentAssignmentFilter.all,
      );
      expect(
        TasksFilterAgentIds.toFilter('hasAgent'),
        AgentAssignmentFilter.hasAgent,
      );
      expect(
        TasksFilterAgentIds.toFilter('noAgent'),
        AgentAssignmentFilter.noAgent,
      );
      expect(
        TasksFilterAgentIds.toFilter('unknown'),
        AgentAssignmentFilter.all,
      );
    });
  });

  group('TasksFilterSearchModeIds', () {
    test('maps SearchMode to string IDs', () {
      expect(
        TasksFilterSearchModeIds.fromMode(SearchMode.fullText),
        'fullText',
      );
      expect(
        TasksFilterSearchModeIds.fromMode(SearchMode.vector),
        'vector',
      );
    });

    test('maps string IDs back to SearchMode', () {
      expect(
        TasksFilterSearchModeIds.toMode('fullText'),
        SearchMode.fullText,
      );
      expect(
        TasksFilterSearchModeIds.toMode('vector'),
        SearchMode.vector,
      );
      expect(
        TasksFilterSearchModeIds.toMode('unknown'),
        SearchMode.fullText,
      );
    });
  });

  group('TasksFilterPriorityIds', () {
    test('maps internal priority to display ID', () {
      expect(TasksFilterPriorityIds.toDisplayId('CRITICAL'), 'p0');
      expect(TasksFilterPriorityIds.toDisplayId('HIGH'), 'p1');
      expect(TasksFilterPriorityIds.toDisplayId('MEDIUM'), 'p2');
      expect(TasksFilterPriorityIds.toDisplayId('LOW'), 'p3');
      expect(TasksFilterPriorityIds.toDisplayId('UNKNOWN'), isNull);
    });

    test('maps display ID back to internal priority', () {
      expect(TasksFilterPriorityIds.toInternalId('p0'), 'CRITICAL');
      expect(TasksFilterPriorityIds.toInternalId('p1'), 'HIGH');
      expect(TasksFilterPriorityIds.toInternalId('p2'), 'MEDIUM');
      expect(TasksFilterPriorityIds.toInternalId('p3'), 'LOW');
      expect(TasksFilterPriorityIds.toInternalId('unknown'), isNull);
    });
  });

  group('buildTasksFilterSheetState', () {
    final categories = [
      CategoryDefinition(
        id: 'cat-1',
        name: 'Work',
        color: '#FF0000',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        vectorClock: null,
        private: false,
        active: true,
      ),
      CategoryDefinition(
        id: 'cat-2',
        name: 'Personal',
        color: '#00FF00',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        vectorClock: null,
        private: false,
        active: true,
      ),
    ];

    final labels = [
      LabelDefinition(
        id: 'label-1',
        name: 'Focus',
        color: '#0000FF',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        vectorClock: null,
        private: false,
      ),
    ];

    const controllerState = JournalPageState(
      showTasks: true,
      selectedTaskStatuses: {'OPEN', 'IN PROGRESS'},
      selectedCategoryIds: {'cat-1'},
      selectedLabelIds: {'label-1'},
      selectedPriorities: {'HIGH'},
      sortOption: TaskSortOption.byDueDate,
      showCreationDate: true,
      showDueDate: false,
      agentAssignmentFilter: AgentAssignmentFilter.hasAgent,
      searchMode: SearchMode.fullText,
      enableVectorSearch: false,
    );

    testWidgets('builds state with all sections from controller state', (
      tester,
    ) async {
      late DesignSystemTaskFilterState result;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(
            builder: (context) {
              result = buildTasksFilterSheetState(
                context,
                controllerState: controllerState,
                categories: categories,
                labels: labels,
                projectsWithCategories: const [],
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(result.hasSortSection, isTrue);
      expect(result.selectedSortId, 'byDueDate');
      expect(result.hasStatusField, isTrue);
      expect(result.statusField!.selectedIds, {'OPEN', 'IN PROGRESS'});
      expect(result.statusField!.options, hasLength(7));
      expect(result.hasPrioritySection, isTrue);
      expect(result.selectedPriorityId, 'p1');
      expect(result.hasCategoryField, isTrue);
      expect(result.categoryField!.selectedIds, {'cat-1'});
      expect(result.categoryField!.options, hasLength(2));
      expect(result.hasLabelField, isTrue);
      expect(result.labelField!.selectedIds, {'label-1'});
      expect(result.hasAgentFilter, isTrue);
      expect(result.selectedAgentFilterId, 'hasAgent');
      expect(result.hasSearchMode, isFalse);
      expect(result.toggles, hasLength(2));
      expect(result.toggles[0].id, TasksFilterToggleIds.showCreationDate);
      expect(result.toggles[0].value, isTrue);
      expect(result.toggles[1].id, TasksFilterToggleIds.showDueDate);
      expect(result.toggles[1].value, isFalse);
    });

    testWidgets('hides search mode on mobile even when vector search enabled', (
      tester,
    ) async {
      late DesignSystemTaskFilterState result;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(
            builder: (context) {
              result = buildTasksFilterSheetState(
                context,
                controllerState: controllerState.copyWith(
                  enableVectorSearch: true,
                ),
                categories: categories,
                labels: labels,
                projectsWithCategories: const [],
              );
              return const SizedBox.shrink();
            },
          ),
          // Default phone media query (390px wide)
        ),
      );

      expect(result.hasSearchMode, isFalse);
    });

    testWidgets('shows search mode on desktop when vector search enabled', (
      tester,
    ) async {
      late DesignSystemTaskFilterState result;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(
            builder: (context) {
              result = buildTasksFilterSheetState(
                context,
                controllerState: controllerState.copyWith(
                  enableVectorSearch: true,
                ),
                categories: categories,
                labels: labels,
                projectsWithCategories: const [],
              );
              return const SizedBox.shrink();
            },
          ),
          mediaQueryData: const MediaQueryData(size: Size(1280, 800)),
        ),
      );

      expect(result.hasSearchMode, isTrue);
      expect(result.searchModeOptions, hasLength(2));
      expect(result.selectedSearchModeId, 'fullText');
    });

    testWidgets('maps empty priorities to allPriorityId', (tester) async {
      late DesignSystemTaskFilterState result;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(
            builder: (context) {
              result = buildTasksFilterSheetState(
                context,
                controllerState: controllerState.copyWith(
                  selectedPriorities: const {},
                ),
                categories: categories,
                labels: labels,
                projectsWithCategories: const [],
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(
        result.selectedPriorityId,
        DesignSystemTaskFilterState.allPriorityId,
      );
    });

    testWidgets('maps multi-priority set to allPriorityId', (tester) async {
      late DesignSystemTaskFilterState result;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(
            builder: (context) {
              result = buildTasksFilterSheetState(
                context,
                controllerState: controllerState.copyWith(
                  selectedPriorities: const {'CRITICAL', 'HIGH'},
                ),
                categories: categories,
                labels: labels,
                projectsWithCategories: const [],
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(
        result.selectedPriorityId,
        DesignSystemTaskFilterState.allPriorityId,
      );
    });

    testWidgets('builds project field with category prefix', (tester) async {
      late DesignSystemTaskFilterState result;

      final projectsWithCategories = [
        ProjectWithCategory(
          project: TestProjectFactory.create(
            id: 'proj-1',
            title: 'Alpha',
            categoryId: 'cat-1',
          ),
          categoryId: 'cat-1',
        ),
        ProjectWithCategory(
          project: TestProjectFactory.create(
            id: 'proj-2',
            title: 'Beta',
            categoryId: 'cat-2',
          ),
          categoryId: 'cat-2',
        ),
      ];

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(
            builder: (context) {
              result = buildTasksFilterSheetState(
                context,
                controllerState: controllerState.copyWith(
                  enableProjects: true,
                  selectedProjectIds: const {'proj-1'},
                ),
                categories: categories,
                labels: labels,
                projectsWithCategories: projectsWithCategories,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(result.hasProjectField, isTrue);
      expect(result.projectField!.options, hasLength(2));
      expect(result.projectField!.options[0].label, 'Work / Alpha');
      expect(result.projectField!.options[1].label, 'Personal / Beta');
      expect(result.projectField!.selectedIds, {'proj-1'});
    });

    testWidgets('returns null project field when no projects', (tester) async {
      late DesignSystemTaskFilterState result;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(
            builder: (context) {
              result = buildTasksFilterSheetState(
                context,
                controllerState: controllerState,
                categories: categories,
                labels: labels,
                projectsWithCategories: const [],
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(result.hasProjectField, isFalse);
    });

    testWidgets('returns null project field when enableProjects is false', (
      tester,
    ) async {
      late DesignSystemTaskFilterState result;

      final projectsWithCategories = [
        ProjectWithCategory(
          project: TestProjectFactory.create(id: 'proj-1', title: 'Alpha'),
          categoryId: 'cat-1',
        ),
      ];

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(
            builder: (context) {
              result = buildTasksFilterSheetState(
                context,
                controllerState: controllerState.copyWith(
                  enableProjects: false,
                ),
                categories: categories,
                labels: labels,
                projectsWithCategories: projectsWithCategories,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(result.hasProjectField, isFalse);
    });
  });

  group('DesignSystemTaskFilterState new fields', () {
    test('selectAgentFilter updates selectedAgentFilterId', () {
      final state = DesignSystemTaskFilterState(
        title: 'T',
        clearAllLabel: 'C',
        applyLabel: 'A',
        agentFilterOptions: const [
          DesignSystemTaskFilterOption(id: 'all', label: 'All'),
          DesignSystemTaskFilterOption(id: 'hasAgent', label: 'Has'),
        ],
        selectedAgentFilterId: 'all',
      );

      final updated = state.selectAgentFilter('hasAgent');
      expect(updated.selectedAgentFilterId, 'hasAgent');

      // No-op when same value
      expect(state.selectAgentFilter('all'), same(state));

      // No-op when no options
      final noOptions = state.copyWith(
        agentFilterOptions: const [],
      );
      expect(noOptions.selectAgentFilter('hasAgent'), same(noOptions));
    });

    test('selectSearchMode updates selectedSearchModeId', () {
      final state = DesignSystemTaskFilterState(
        title: 'T',
        clearAllLabel: 'C',
        applyLabel: 'A',
        searchModeOptions: const [
          DesignSystemTaskFilterOption(id: 'fullText', label: 'Full'),
          DesignSystemTaskFilterOption(id: 'vector', label: 'Vector'),
        ],
        selectedSearchModeId: 'fullText',
      );

      final updated = state.selectSearchMode('vector');
      expect(updated.selectedSearchModeId, 'vector');

      expect(state.selectSearchMode('fullText'), same(state));

      final noOptions = state.copyWith(searchModeOptions: const []);
      expect(noOptions.selectSearchMode('vector'), same(noOptions));
    });

    test('toggleValue flips toggle and ignores unknown IDs', () {
      final state = DesignSystemTaskFilterState(
        title: 'T',
        clearAllLabel: 'C',
        applyLabel: 'A',
        toggles: const [
          DesignSystemTaskFilterToggle(id: 'a', label: 'A', value: false),
          DesignSystemTaskFilterToggle(id: 'b', label: 'B', value: true),
        ],
      );

      final toggled = state.toggleValue('a');
      expect(toggled.toggles[0].value, isTrue);
      expect(toggled.toggles[1].value, isTrue);

      expect(state.toggleValue('unknown'), same(state));
    });

    test('removeSelection works for project section', () {
      final state = DesignSystemTaskFilterState(
        title: 'T',
        clearAllLabel: 'C',
        applyLabel: 'A',
        projectField: const DesignSystemTaskFilterFieldState(
          label: 'P',
          options: [
            DesignSystemTaskFilterOption(id: 'p1', label: 'P1'),
            DesignSystemTaskFilterOption(id: 'p2', label: 'P2'),
          ],
          selectedIds: {'p1', 'p2'},
        ),
      );

      final removed = state.removeSelection(
        DesignSystemTaskFilterSection.project,
        'p1',
      );
      expect(removed.projectField!.selectedIds, {'p2'});
    });

    test('clearAll also clears project field and agent filter', () {
      final state = DesignSystemTaskFilterState(
        title: 'T',
        clearAllLabel: 'C',
        applyLabel: 'A',
        projectField: const DesignSystemTaskFilterFieldState(
          label: 'P',
          options: [DesignSystemTaskFilterOption(id: 'p1', label: 'P1')],
          selectedIds: {'p1'},
        ),
        agentFilterOptions: const [
          DesignSystemTaskFilterOption(id: 'all', label: 'All'),
          DesignSystemTaskFilterOption(id: 'hasAgent', label: 'Has'),
        ],
        selectedAgentFilterId: 'hasAgent',
      );

      final cleared = state.clearAll();
      expect(cleared.projectField!.selectedIds, isEmpty);
      expect(cleared.selectedAgentFilterId, 'all');
    });

    test('appliedCount includes project selections and agent filter', () {
      final state = DesignSystemTaskFilterState(
        title: 'T',
        clearAllLabel: 'C',
        applyLabel: 'A',
        projectField: const DesignSystemTaskFilterFieldState(
          label: 'P',
          options: [
            DesignSystemTaskFilterOption(id: 'p1', label: 'P1'),
            DesignSystemTaskFilterOption(id: 'p2', label: 'P2'),
          ],
          selectedIds: {'p1', 'p2'},
        ),
        agentFilterOptions: const [
          DesignSystemTaskFilterOption(id: 'all', label: 'All'),
          DesignSystemTaskFilterOption(id: 'hasAgent', label: 'Has'),
        ],
        selectedAgentFilterId: 'hasAgent',
      );

      // 2 projects + 1 agent filter = 3
      expect(state.appliedCount, 3);
    });

    test('appliedCount excludes agent filter when at default', () {
      final state = DesignSystemTaskFilterState(
        title: 'T',
        clearAllLabel: 'C',
        applyLabel: 'A',
        agentFilterOptions: const [
          DesignSystemTaskFilterOption(id: 'all', label: 'All'),
          DesignSystemTaskFilterOption(id: 'hasAgent', label: 'Has'),
        ],
        selectedAgentFilterId: 'all',
      );

      expect(state.appliedCount, 0);
    });

    test('round-trips new fields through JSON', () {
      final state = DesignSystemTaskFilterState(
        title: 'T',
        clearAllLabel: 'C',
        applyLabel: 'A',
        projectField: const DesignSystemTaskFilterFieldState(
          label: 'Project',
          options: [DesignSystemTaskFilterOption(id: 'p1', label: 'P1')],
          selectedIds: {'p1'},
        ),
        agentFilterLabel: 'Agent',
        agentFilterOptions: const [
          DesignSystemTaskFilterOption(id: 'all', label: 'All'),
        ],
        selectedAgentFilterId: 'all',
        searchModeLabel: 'Search',
        searchModeOptions: const [
          DesignSystemTaskFilterOption(id: 'fullText', label: 'Full'),
        ],
        selectedSearchModeId: 'fullText',
        toggles: const [
          DesignSystemTaskFilterToggle(id: 'x', label: 'X', value: true),
        ],
      );

      final roundTrip = DesignSystemTaskFilterState.fromJson(state.toJson());

      expect(roundTrip.hasProjectField, isTrue);
      expect(roundTrip.projectField!.selectedIds, {'p1'});
      expect(roundTrip.agentFilterLabel, 'Agent');
      expect(roundTrip.selectedAgentFilterId, 'all');
      expect(roundTrip.searchModeLabel, 'Search');
      expect(roundTrip.selectedSearchModeId, 'fullText');
      expect(roundTrip.toggles, hasLength(1));
      expect(roundTrip.toggles[0].id, 'x');
      expect(roundTrip.toggles[0].value, isTrue);
    });
  });

  group('DesignSystemTaskFilterToggle', () {
    test('round-trips through JSON', () {
      const toggle = DesignSystemTaskFilterToggle(
        id: 'show',
        label: 'Show it',
        value: true,
      );

      final roundTrip = DesignSystemTaskFilterToggle.fromJson(toggle.toJson());
      expect(roundTrip.id, 'show');
      expect(roundTrip.label, 'Show it');
      expect(roundTrip.value, isTrue);
    });

    test('defaults value to false when missing from JSON', () {
      final toggle = DesignSystemTaskFilterToggle.fromJson(const {
        'id': 'x',
        'label': 'X',
      });
      expect(toggle.value, isFalse);
    });

    test('copyWith updates value', () {
      const toggle = DesignSystemTaskFilterToggle(
        id: 'a',
        label: 'A',
        value: false,
      );
      final updated = toggle.copyWith(value: true);
      expect(updated.value, isTrue);
      expect(updated.id, 'a');
    });
  });
}
