import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/state/task_live_data_provider.dart';
import 'package:lotti/features/tasks/state/task_one_liner_provider.dart';
import 'package:lotti/features/tasks/ui/model/task_list_detail_models.dart';
import 'package:lotti/features/tasks/ui/model/task_list_detail_state.dart';
import 'package:lotti/features/tasks/ui/widgets/task_list_pane.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/entity_factories.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  setUp(() async {
    await setUpTestGetIt(
      additionalSetup: () {
        final mockTimeService = MockTimeService();
        when(mockTimeService.getStream).thenAnswer(
          (_) => const Stream.empty(),
        );
        when(() => mockTimeService.linkedFrom).thenReturn(null);
        getIt.registerSingleton<TimeService>(mockTimeService);
      },
    );
  });

  tearDown(tearDownTestGetIt);

  Widget wrap(Widget child) {
    return ProviderScope(
      overrides: [
        taskLiveDataProvider.overrideWith(
          // ignore: avoid_redundant_argument_values
          (ref, taskId) => Future.value(null),
        ),
        taskOneLinerProvider.overrideWith(
          // ignore: avoid_redundant_argument_values
          (ref, taskId) => Future.value(null),
        ),
        agentUpdateStreamProvider.overrideWith(
          (ref, agentId) => const Stream<Set<String>>.empty(),
        ),
      ],
      child: makeTestableWidget2(
        Theme(
          data: DesignSystemTheme.dark(),
          child: Scaffold(
            body: SizedBox(width: 402, height: 900, child: child),
          ),
        ),
        mediaQueryData: const MediaQueryData(size: Size(500, 1000)),
      ),
    );
  }

  TaskRecord makeTaskRecord({
    required String id,
    required String title,
    required CategoryDefinition category,
  }) {
    final task = TestTaskFactory.create(
      id: id,
      title: title,
      categoryId: category.id,
      dateFrom: DateTime(2026, 4, 8, 9),
      dateTo: DateTime(2026, 4, 8, 10),
    );

    return TaskRecord(
      task: task,
      category: category,
      sectionTitle: 'P1 High',
      sectionDate: DateTime(2026, 4, 8),
      projectTitle: 'Design system',
      timeRange: '09:00-10:00',
      labels: const <TaskShowcaseLabel>[],
      aiSummary: 'summary',
      description: 'description',
      trackedDurationLabel: '1h 30m',
      trackerEntries: const <TaskShowcaseTimeEntry>[],
      checklistItems: const <TaskShowcaseChecklistItem>[],
      audioEntries: const <TaskShowcaseAudioEntry>[],
    );
  }

  group('TaskListSectionsList', () {
    testWidgets(
      'hides the upper divider when hovering the next row in the same section',
      (tester) async {
        final category = CategoryDefinition(
          id: 'cat-1',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          name: 'Work',
          vectorClock: null,
          private: false,
          active: true,
          favorite: false,
          color: '#3355FF',
          icon: CategoryIcon.work,
        );
        final sections = [
          TaskListSection(
            title: 'P1 High',
            sectionDate: DateTime(2026, 4, 8),
            tasks: [
              makeTaskRecord(
                id: 'task-1',
                title: 'First task',
                category: category,
              ),
              makeTaskRecord(
                id: 'task-2',
                title: 'Second task',
                category: category,
              ),
            ],
          ),
        ];

        await tester.pumpWidget(
          wrap(
            TaskListSectionsList(
              sections: sections,
              sortOption: TaskSortOption.byPriority,
              selectedTaskId: null,
              bottomPadding: 0,
              onTaskSelected: (_) {},
            ),
          ),
        );
        await tester.pump();

        expect(
          find.byKey(const ValueKey('task-browse-divider-task-1')),
          findsOneWidget,
        );

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        addTearDown(gesture.removePointer);
        await gesture.addPointer();
        await gesture.moveTo(
          tester.getCenter(
            find.byKey(const ValueKey('task-browse-row-task-2')),
          ),
        );
        await tester.pump();

        expect(
          find.byKey(const ValueKey('task-browse-divider-task-1')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('task-browse-divider-slot-task-1')),
          findsOneWidget,
        );
      },
    );

    testWidgets('renders with byDueDate sort option', (tester) async {
      final category = CategoryDefinition(
        id: 'cat-1',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        name: 'Work',
        vectorClock: null,
        private: false,
        active: true,
        favorite: false,
        color: '#3355FF',
        icon: CategoryIcon.work,
      );
      final sections = [
        TaskListSection(
          title: 'Due Apr 10',
          sectionDate: DateTime(2026, 4, 10),
          tasks: [
            makeTaskRecord(
              id: 'task-due',
              title: 'Due task',
              category: category,
            ),
          ],
        ),
      ];

      await tester.pumpWidget(
        wrap(
          TaskListSectionsList(
            sections: sections,
            sortOption: TaskSortOption.byDueDate,
            selectedTaskId: null,
            bottomPadding: 0,
            onTaskSelected: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Due task'), findsOneWidget);
    });
  });

  group('TaskListActiveFilters', () {
    TaskListDetailState buildStateWithPriority(String priorityId) {
      final filterState = DesignSystemTaskFilterState(
        title: 'Filters',
        clearAllLabel: 'Clear',
        applyLabel: 'Apply',
        priorityOptions: const [
          DesignSystemTaskFilterOption(
            id: DesignSystemTaskFilterState.allPriorityId,
            label: 'All',
          ),
          DesignSystemTaskFilterOption(id: 'p0', label: 'P0'),
          DesignSystemTaskFilterOption(id: 'p1', label: 'P1'),
          DesignSystemTaskFilterOption(id: 'p2', label: 'P2'),
          DesignSystemTaskFilterOption(id: 'p3', label: 'P3'),
        ],
      ).selectPriority(priorityId);
      return TaskListDetailState(
        data: TaskListData(
          categories: const [],
          tasks: const [],
          currentTime: DateTime(2026, 4, 17),
        ),
        searchQuery: '',
        selectedTaskId: '',
        filterState: filterState,
      );
    }

    testWidgets(
      'renders a DesignSystemChip per applied filter with the priority glyph',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            TaskListActiveFilters(
              state: buildStateWithPriority(TaskPriorityFilterIds.p0),
              onFilterPressed: () {},
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(DesignSystemChip), findsOneWidget);
        // Material Chip must no longer be used.
        expect(find.byType(Chip), findsNothing);
        // Chip carries the priority id label.
        expect(find.text('P0'), findsOneWidget);
      },
    );

    testWidgets('tapping an active filter chip opens the filter sheet', (
      tester,
    ) async {
      var filterPressed = 0;

      await tester.pumpWidget(
        wrap(
          TaskListActiveFilters(
            state: buildStateWithPriority(TaskPriorityFilterIds.p2),
            onFilterPressed: () => filterPressed++,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(DesignSystemChip));
      await tester.pump();

      expect(filterPressed, 1);
    });

    TaskListDetailState buildStateWithFields({
      Set<String> statusIds = const {},
      Set<String> priorityIds = const {},
      Set<String> categoryIds = const {},
      Set<String> labelIds = const {},
    }) {
      final base = DesignSystemTaskFilterState(
        title: 'Filters',
        clearAllLabel: 'Clear',
        applyLabel: 'Apply',
        priorityOptions: const [
          DesignSystemTaskFilterOption(
            id: DesignSystemTaskFilterState.allPriorityId,
            label: 'All',
          ),
          DesignSystemTaskFilterOption(id: 'p0', label: 'P0'),
          DesignSystemTaskFilterOption(id: 'p1', label: 'P1'),
          DesignSystemTaskFilterOption(id: 'p2', label: 'P2'),
          DesignSystemTaskFilterOption(id: 'p3', label: 'P3'),
        ],
        selectedPriorityIds: priorityIds,
        statusField: DesignSystemTaskFilterFieldState(
          label: 'Status',
          options: const [
            DesignSystemTaskFilterOption(id: 'OPEN', label: 'Open'),
            DesignSystemTaskFilterOption(
              id: 'IN PROGRESS',
              label: 'In progress',
            ),
          ],
          selectedIds: statusIds,
        ),
        categoryField: DesignSystemTaskFilterFieldState(
          label: 'Category',
          options: const [
            DesignSystemTaskFilterOption(id: 'cat-1', label: 'Work'),
            DesignSystemTaskFilterOption(id: 'cat-2', label: 'Personal'),
          ],
          selectedIds: categoryIds,
        ),
        labelField: DesignSystemTaskFilterFieldState(
          label: 'Label',
          options: const [
            DesignSystemTaskFilterOption(id: 'label-1', label: 'Focus'),
            DesignSystemTaskFilterOption(id: 'label-2', label: 'Deep Work'),
          ],
          selectedIds: labelIds,
        ),
      );
      return TaskListDetailState(
        data: TaskListData(
          categories: const [],
          tasks: const [],
          currentTime: DateTime(2026, 4, 17),
        ),
        searchQuery: '',
        selectedTaskId: '',
        filterState: base,
      );
    }

    testWidgets(
      'returns SizedBox.shrink() when no filters are applied (no chip row)',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            TaskListActiveFilters(
              state: buildStateWithFields(),
              onFilterPressed: () {},
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(DesignSystemChip), findsNothing);
      },
    );

    testWidgets(
      'renders one chip per selected status / priority / category / label',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            TaskListActiveFilters(
              state: buildStateWithFields(
                statusIds: const {'OPEN', 'IN PROGRESS'},
                priorityIds: const {'p0', 'p2'},
                categoryIds: const {'cat-1'},
                labelIds: const {'label-1'},
              ),
              onFilterPressed: () {},
            ),
          ),
        );
        await tester.pump();

        // 2 statuses + 2 priorities + 1 category + 1 label = 6 chips.
        expect(find.byType(DesignSystemChip), findsNWidgets(6));
        expect(find.text('Open'), findsOneWidget);
        expect(find.text('In progress'), findsOneWidget);
        expect(find.text('P0'), findsOneWidget);
        expect(find.text('P2'), findsOneWidget);
        expect(find.text('Work'), findsOneWidget);
        expect(find.text('Focus'), findsOneWidget);
      },
    );

    testWidgets(
      'per-chip onRemove invokes onFilterChanged with the section removed '
      'from the draft state (status chip)',
      (tester) async {
        DesignSystemTaskFilterState? observed;
        await tester.pumpWidget(
          wrap(
            TaskListActiveFilters(
              state: buildStateWithFields(
                statusIds: const {'OPEN', 'IN PROGRESS'},
              ),
              onFilterPressed: () {},
              onFilterChanged: (state) => observed = state,
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.text('Open'));
        await tester.pump();

        expect(observed, isNotNull);
        expect(observed!.statusField!.selectedIds, equals({'IN PROGRESS'}));
      },
    );

    testWidgets(
      'priority chip remove toggles the priority off via togglePriority',
      (tester) async {
        DesignSystemTaskFilterState? observed;
        await tester.pumpWidget(
          wrap(
            TaskListActiveFilters(
              state: buildStateWithFields(priorityIds: const {'p0', 'p2'}),
              onFilterPressed: () {},
              onFilterChanged: (state) => observed = state,
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.text('P0'));
        await tester.pump();

        expect(observed, isNotNull);
        expect(observed!.selectedPriorityIds, equals({'p2'}));
      },
    );

    testWidgets(
      'category and label chip removes invoke onFilterChanged with the '
      'id stripped from the respective field',
      (tester) async {
        DesignSystemTaskFilterState? observed;
        await tester.pumpWidget(
          wrap(
            TaskListActiveFilters(
              state: buildStateWithFields(
                categoryIds: const {'cat-1', 'cat-2'},
                labelIds: const {'label-1', 'label-2'},
              ),
              onFilterPressed: () {},
              onFilterChanged: (state) => observed = state,
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.text('Work'));
        await tester.pump();
        expect(observed!.categoryField!.selectedIds, equals({'cat-2'}));

        observed = null;
        await tester.tap(find.text('Focus'));
        await tester.pump();
        expect(observed!.labelField!.selectedIds, equals({'label-2'}));
      },
    );

    testWidgets(
      'Clear-all chip is only rendered when onClearAll is supplied and '
      'fires the callback on tap',
      (tester) async {
        var cleared = 0;

        // Without onClearAll — no extra Clear-all chip rendered.
        await tester.pumpWidget(
          wrap(
            TaskListActiveFilters(
              state: buildStateWithFields(priorityIds: const {'p0'}),
              onFilterPressed: () {},
            ),
          ),
        );
        await tester.pump();
        expect(find.byIcon(Icons.close_rounded), findsNothing);

        // With onClearAll — chip appears and reports on tap.
        await tester.pumpWidget(
          wrap(
            TaskListActiveFilters(
              state: buildStateWithFields(priorityIds: const {'p0'}),
              onFilterPressed: () {},
              onClearAll: () => cleared++,
            ),
          ),
        );
        await tester.pump();

        expect(find.byIcon(Icons.close_rounded), findsOneWidget);
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pump();
        expect(cleared, 1);
      },
    );
  });

  group('TaskListPane chrome', () {
    testWidgets('list pane paints background.level01 to match sidebar', (
      tester,
    ) async {
      final state = TaskListDetailState(
        data: TaskListData(
          categories: const [],
          tasks: const [],
          currentTime: DateTime(2026, 4, 17),
        ),
        searchQuery: '',
        selectedTaskId: '',
        filterState: DesignSystemTaskFilterState(
          title: 'Filters',
          clearAllLabel: 'Clear',
          applyLabel: 'Apply',
        ),
      );

      await tester.pumpWidget(
        wrap(
          TaskListPane(
            state: state,
            onTaskSelected: (_) {},
            onSearchChanged: (_) {},
            onSearchCleared: () {},
            onFilterPressed: () {},
          ),
        ),
      );
      await tester.pump();

      final decoratedBox = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(TaskListPane),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final decoration = decoratedBox.decoration as BoxDecoration;
      expect(decoration.color, dsTokensDark.colors.background.level01);
    });

    testWidgets('filter icon is the Figma funnel glyph', (tester) async {
      final state = TaskListDetailState(
        data: TaskListData(
          categories: const [],
          tasks: const [],
          currentTime: DateTime(2026, 4, 17),
        ),
        searchQuery: '',
        selectedTaskId: '',
        filterState: DesignSystemTaskFilterState(
          title: 'Filters',
          clearAllLabel: 'Clear',
          applyLabel: 'Apply',
        ),
      );

      await tester.pumpWidget(
        wrap(
          TaskListPane(
            state: state,
            onTaskSelected: (_) {},
            onSearchChanged: (_) {},
            onSearchCleared: () {},
            onFilterPressed: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.filter_list_rounded), findsOneWidget);
      expect(find.byIcon(Icons.tune_rounded), findsNothing);
    });
  });
}
