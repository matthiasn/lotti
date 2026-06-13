// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' show AnyUtils, Glados, ListAnys, any;
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/ui/filtering/task_project_selection_modal.dart';
import 'package:lotti/features/tasks/ui/filtering/tasks_filter_sheet_state.dart';

import '../../../../helpers/entity_factories.dart';
import '../../../../widget_test_utils.dart';

void main() {
  group('TasksFilterSortIds', () {
    Glados(any.choose(TaskSortOption.values)).test(
      'round-trips every TaskSortOption',
      (option) {
        expect(
          TasksFilterSortIds.toSortOption(
            TasksFilterSortIds.fromSortOption(option),
          ),
          option,
        );
      },
      tags: 'glados',
    );

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
    Glados(any.choose(AgentAssignmentFilter.values)).test(
      'round-trips every AgentAssignmentFilter',
      (filter) {
        expect(
          TasksFilterAgentIds.toFilter(TasksFilterAgentIds.fromFilter(filter)),
          filter,
        );
      },
      tags: 'glados',
    );

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
    Glados(any.choose(SearchMode.values)).test(
      'round-trips every SearchMode',
      (mode) {
        expect(
          TasksFilterSearchModeIds.toMode(
            TasksFilterSearchModeIds.fromMode(mode),
          ),
          mode,
        );
      },
      tags: 'glados',
    );

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
    Glados(any.choose(['P0', 'P1', 'P2', 'P3'])).test(
      'round-trips every valid priority ID',
      (internalId) {
        expect(
          TasksFilterPriorityIds.toInternalId(
            TasksFilterPriorityIds.toDisplayId(internalId)!,
          ),
          internalId,
        );
      },
      tags: 'glados',
    );

    // Property test for the set transformation that backs
    // `_prioritySetToDisplayIds` in `tasks_filter_sheet_state.dart`: the
    // production code maps each internal priority via `toDisplayId` and drops
    // null results. Whatever arbitrary subset of internal IDs (including the
    // unrecognised `UNKNOWN` sentinel) is fed in, the resulting display ID set
    // must always be a subset of the four valid display IDs.
    Glados(
      any.list(any.choose(const ['P0', 'P1', 'P2', 'P3', 'UNKNOWN'])),
    ).test(
      'display-id mapping yields only valid display IDs for any input subset',
      (internalList) {
        final internals = internalList.toSet();
        final displayIds = <String>{
          for (final internal in internals)
            ?TasksFilterPriorityIds.toDisplayId(internal),
        };

        const validDisplayIds = {'p0', 'p1', 'p2', 'p3'};
        expect(displayIds.difference(validDisplayIds), isEmpty);

        // Independent oracle: every recognised internal ID survives as its
        // lower-cased display ID, and the only entry ever dropped is the
        // unrecognised sentinel.
        final expected = {
          for (final i in internals.difference({'UNKNOWN'})) i.toLowerCase(),
        };
        expect(displayIds, expected);
      },
      tags: 'glados',
    );

    test('maps internal priority to display ID', () {
      // Internal ids are the short codes stored in the `task_priority`
      // column (`P0`..`P3`), not the legacy `CRITICAL`/`HIGH`/`MEDIUM`/`LOW`
      // labels.
      expect(TasksFilterPriorityIds.toDisplayId('P0'), 'p0');
      expect(TasksFilterPriorityIds.toDisplayId('P1'), 'p1');
      expect(TasksFilterPriorityIds.toDisplayId('P2'), 'p2');
      expect(TasksFilterPriorityIds.toDisplayId('P3'), 'p3');
      expect(TasksFilterPriorityIds.toDisplayId('UNKNOWN'), isNull);
    });

    test('maps display ID back to internal priority', () {
      expect(TasksFilterPriorityIds.toInternalId('p0'), 'P0');
      expect(TasksFilterPriorityIds.toInternalId('p1'), 'P1');
      expect(TasksFilterPriorityIds.toInternalId('p2'), 'P2');
      expect(TasksFilterPriorityIds.toInternalId('p3'), 'P3');
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
      selectedPriorities: {'P1'},
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
      // Controller holds `{'P1'}`, so the sheet exposes `{'p1'}` as its
      // multi-select set. The legacy single getter picks that same value.
      expect(result.selectedPriorityIds, {'p1'});
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

    testWidgets('maps empty priorities to an empty selection set', (
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

      expect(result.selectedPriorityIds, isEmpty);
      // Empty set is equivalent to the legacy `allPriorityId` sentinel.
      expect(
        result.selectedPriorityId,
        DesignSystemTaskFilterState.allPriorityId,
      );
    });

    testWidgets('maps multi-priority set through to the sheet selection', (
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
                  selectedPriorities: const {'P0', 'P1'},
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

      expect(result.selectedPriorityIds, {'p0', 'p1'});
      // Legacy single getter falls back to `allPriorityId` for multi-select.
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
}
