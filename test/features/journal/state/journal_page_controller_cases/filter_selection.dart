part of '../journal_page_controller_test.dart';

void _registerFilterSelection(JournalControllerTestSetup setup) {
  group('Filter Management - toggle membership contract', () {
    // Both remaining toggle methods share one contract: toggling a value
    // flips membership in its corresponding selection set. One spec per
    // method drives both directions.
    final toggleSpecs =
        <
          ({
            String method,
            bool tasksTab,
            void Function(JournalPageController controller, String value)
            toggle,
            void Function(JournalPageController controller)? prepareAdd,
            bool Function(JournalPageState state, String value) contains,
            String addValue,
            String removeValue,
            bool removeByDoubleToggle,
          })
        >[
          (
            method: 'toggleSelectedCategoryIds',
            tasksTab: true,
            toggle: (c, v) => c.toggleSelectedCategoryIds(v),
            prepareAdd: null,
            contains: (s, v) => s.selectedCategoryIds.contains(v),
            addValue: 'cat1',
            removeValue: 'cat1',
            removeByDoubleToggle: true,
          ),
          (
            method: 'toggleSelectedEntryTypes',
            tasksTab: false,
            toggle: (c, v) => c.toggleSelectedEntryTypes(v),
            // Task is in the default set; clear first so the add is observable.
            prepareAdd: (c) => c.clearSelectedEntryTypes(),
            contains: (s, v) => s.selectedEntryTypes.contains(v),
            addValue: 'Task',
            removeValue: 'Task',
            removeByDoubleToggle: false,
          ),
        ];

    for (final spec in toggleSpecs) {
      test('${spec.method} adds ${spec.addValue} when not present', () {
        fakeAsync((async) {
          final controller = setup.container.read(
            journalPageControllerProvider(spec.tasksTab).notifier,
          );

          settle(async);

          spec.prepareAdd?.call(controller);
          spec.toggle(controller, spec.addValue);

          settle(async);

          final state = setup.container.read(
            journalPageControllerProvider(spec.tasksTab),
          );
          expect(spec.contains(state, spec.addValue), isTrue);
        });
      });

      test('${spec.method} removes ${spec.removeValue} when present', () {
        fakeAsync((async) {
          final controller = setup.container.read(
            journalPageControllerProvider(spec.tasksTab).notifier,
          );

          settle(async);

          if (spec.removeByDoubleToggle) {
            spec.toggle(controller, spec.removeValue);
          }
          spec.toggle(controller, spec.removeValue);

          settle(async);

          final state = setup.container.read(
            journalPageControllerProvider(spec.tasksTab),
          );
          expect(spec.contains(state, spec.removeValue), isFalse);
        });
      });
    }
  });

  group('Batch Filter Updates - Task Status', () {
    test('sets only one task status', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(true).notifier,
        );

        settle(async);

        controller.applyBatchFilterUpdate(statuses: const {'DONE'});

        settle(async);

        final state = setup.container.read(journalPageControllerProvider(true));
        expect(state.selectedTaskStatuses, equals({'DONE'}));
      });
    });

    test('selects all task statuses', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(true).notifier,
        );

        settle(async);

        controller.applyBatchFilterUpdate(
          statuses: controller.state.taskStatuses.toSet(),
        );

        settle(async);

        final state = setup.container.read(journalPageControllerProvider(true));
        expect(
          state.selectedTaskStatuses,
          equals(state.taskStatuses.toSet()),
        );
      });
    });

    test('clears all task status selections', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(true).notifier,
        );

        settle(async);

        controller.applyBatchFilterUpdate(statuses: const {});

        settle(async);

        final state = setup.container.read(journalPageControllerProvider(true));
        expect(state.selectedTaskStatuses, isEmpty);
      });
    });
  });

  group('Filter Management - Category', () {
    test('selectedAllCategories clears all selected categories', () {
      fakeAsync((async) {
        when(() => setup.mockEntitiesCacheService.sortedCategories).thenReturn([
          CategoryDefinition(
            id: 'cat1',
            name: 'Work',
            color: '#FF0000',
            createdAt: DateTime(2024, 1, 1, 10),
            updatedAt: DateTime(2024, 1, 1, 10),
            active: true,
            private: false,
            vectorClock: null,
          ),
        ]);

        final controller = setup.container.read(
          journalPageControllerProvider(true).notifier,
        );

        settle(async);

        controller
          ..toggleSelectedCategoryIds('cat1')
          ..toggleSelectedCategoryIds('cat2');

        settle(async);

        controller.selectedAllCategories();

        settle(async);

        final state = setup.container.read(journalPageControllerProvider(true));
        expect(state.selectedCategoryIds, isEmpty);
      });
    });
  });

  group('Filter Management - Labels', () {
    test('an empty label batch clears all label filters', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(false).notifier,
        );

        settle(async);

        controller.applyBatchFilterUpdate(
          labelIds: const {'label-A', 'label-B'},
        );

        settle(async);

        controller.applyBatchFilterUpdate(labelIds: const {});

        settle(async);

        final state = setup.container.read(
          journalPageControllerProvider(false),
        );
        expect(state.selectedLabelIds, isEmpty);
      });
    });
  });

  group('Filter Management - Priority', () {
    test('an empty priority batch clears all priorities', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(true).notifier,
        );

        settle(async);

        controller
          ..applyBatchFilterUpdate(priorities: const {'P0', 'P1'})
          ..applyBatchFilterUpdate(priorities: const {});

        settle(async);

        final state = setup.container.read(journalPageControllerProvider(true));
        expect(state.selectedPriorities, isEmpty);
      });
    });
  });

  group('Filter Management - Entry Types', () {
    test('selectSingleEntryType sets only one type', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(false).notifier,
        );

        settle(async);

        controller.selectSingleEntryType('Task');

        settle(async);

        final state = setup.container.read(
          journalPageControllerProvider(false),
        );
        expect(state.selectedEntryTypes, equals(['Task']));
      });
    });

    test('selectAllEntryTypes selects all types', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(false).notifier,
        );

        settle(async);

        controller.selectAllEntryTypes();

        settle(async);

        final state = setup.container.read(
          journalPageControllerProvider(false),
        );
        expect(state.selectedEntryTypes.length, equals(entryTypes.length));
      });
    });

    test('clearSelectedEntryTypes clears all types', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(false).notifier,
        );

        settle(async);

        controller.clearSelectedEntryTypes();

        settle(async);

        final state = setup.container.read(
          journalPageControllerProvider(false),
        );
        expect(state.selectedEntryTypes, isEmpty);
      });
    });
  });

  group('Display Filter Management', () {
    test('setFilters updates starred filter', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(false).notifier,
        );

        settle(async);

        controller.setFilters({DisplayFilter.starredEntriesOnly});

        settle(async);

        final state = setup.container.read(
          journalPageControllerProvider(false),
        );
        expect(state.filters, equals({DisplayFilter.starredEntriesOnly}));
      });
    });

    test('setFilters updates flagged filter', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(false).notifier,
        );

        settle(async);

        controller.setFilters({DisplayFilter.flaggedEntriesOnly});

        settle(async);

        final state = setup.container.read(
          journalPageControllerProvider(false),
        );
        expect(state.filters, equals({DisplayFilter.flaggedEntriesOnly}));
      });
    });

    test('setFilters updates private filter', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(false).notifier,
        );

        settle(async);

        controller.setFilters({DisplayFilter.privateEntriesOnly});

        settle(async);

        final state = setup.container.read(
          journalPageControllerProvider(false),
        );
        expect(state.filters, equals({DisplayFilter.privateEntriesOnly}));
      });
    });

    test('setFilters can combine multiple filters', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(false).notifier,
        );

        settle(async);

        controller.setFilters({
          DisplayFilter.starredEntriesOnly,
          DisplayFilter.privateEntriesOnly,
        });

        settle(async);

        final state = setup.container.read(
          journalPageControllerProvider(false),
        );
        expect(
          state.filters,
          equals({
            DisplayFilter.starredEntriesOnly,
            DisplayFilter.privateEntriesOnly,
          }),
        );
      });
    });
  });

  group('Sort Option Management', () {
    test('batch update sets sort option to byDate', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(true).notifier,
        );

        settle(async);

        controller.applyBatchFilterUpdate(sortOption: TaskSortOption.byDate);

        settle(async);

        final state = setup.container.read(journalPageControllerProvider(true));
        expect(state.sortOption, equals(TaskSortOption.byDate));
      });
    });

    test('batch update can restore byPriority sorting', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(true).notifier,
        );

        settle(async);

        controller
          ..applyBatchFilterUpdate(sortOption: TaskSortOption.byDate)
          ..applyBatchFilterUpdate(sortOption: TaskSortOption.byPriority);

        settle(async);

        final state = setup.container.read(journalPageControllerProvider(true));
        expect(state.sortOption, equals(TaskSortOption.byPriority));
      });
    });

    test('batch update sets sort option to byDueDate', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(true).notifier,
        );

        settle(async);

        controller.applyBatchFilterUpdate(
          sortOption: TaskSortOption.byDueDate,
        );

        settle(async);

        final state = setup.container.read(journalPageControllerProvider(true));
        expect(state.sortOption, equals(TaskSortOption.byDueDate));
      });
    });

    test('batch updates cover all three sort options', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(true).notifier,
        );

        settle(async);

        // Start with byPriority (default)
        var state = setup.container.read(journalPageControllerProvider(true));
        expect(state.sortOption, equals(TaskSortOption.byPriority));

        // Switch to byDueDate
        controller.applyBatchFilterUpdate(
          sortOption: TaskSortOption.byDueDate,
        );
        settle(async);
        state = setup.container.read(journalPageControllerProvider(true));
        expect(state.sortOption, equals(TaskSortOption.byDueDate));

        // Switch to byDate
        controller.applyBatchFilterUpdate(sortOption: TaskSortOption.byDate);
        settle(async);
        state = setup.container.read(journalPageControllerProvider(true));
        expect(state.sortOption, equals(TaskSortOption.byDate));

        // Back to byPriority
        controller.applyBatchFilterUpdate(
          sortOption: TaskSortOption.byPriority,
        );
        settle(async);
        state = setup.container.read(journalPageControllerProvider(true));
        expect(state.sortOption, equals(TaskSortOption.byPriority));
      });
    });
  });

  group('Filter Management - Agent Assignment', () {
    late AgentDatabase agentDbForFilter;

    setUp(() {
      agentDbForFilter = AgentDatabase(
        inMemoryDatabase: true,
        background: false,
      );
      getIt.registerSingleton<AgentDatabase>(agentDbForFilter);
    });

    tearDown(() async {
      await agentDbForFilter.close();
      getIt.unregister<AgentDatabase>();
    });

    test('batch update sets agent filter to hasAgent', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(true).notifier,
        );

        settle(async);

        controller.applyBatchFilterUpdate(
          agentAssignmentFilter: AgentAssignmentFilter.hasAgent,
        );

        settle(async);

        final state = setup.container.read(journalPageControllerProvider(true));
        expect(
          state.agentAssignmentFilter,
          equals(AgentAssignmentFilter.hasAgent),
        );
      });
    });

    test('batch update sets agent filter to noAgent', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(true).notifier,
        );

        settle(async);

        controller.applyBatchFilterUpdate(
          agentAssignmentFilter: AgentAssignmentFilter.noAgent,
        );

        settle(async);

        final state = setup.container.read(journalPageControllerProvider(true));
        expect(
          state.agentAssignmentFilter,
          equals(AgentAssignmentFilter.noAgent),
        );
      });
    });

    test('batch update restores the all-agents filter', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(true).notifier,
        );

        settle(async);

        controller
          ..applyBatchFilterUpdate(
            agentAssignmentFilter: AgentAssignmentFilter.hasAgent,
          )
          ..applyBatchFilterUpdate(
            agentAssignmentFilter: AgentAssignmentFilter.all,
          );

        settle(async);

        final state = setup.container.read(journalPageControllerProvider(true));
        expect(
          state.agentAssignmentFilter,
          equals(AgentAssignmentFilter.all),
        );
      });
    });

    test('default agentAssignmentFilter is all', () {
      fakeAsync((async) {
        final state = setup.container.read(journalPageControllerProvider(true));
        expect(
          state.agentAssignmentFilter,
          equals(AgentAssignmentFilter.all),
        );

        settle(async);
      });
    });
  });

  group('Show Creation Date Toggle', () {
    test('batch update enables creation dates', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(true).notifier,
        );

        settle(async);

        controller.applyBatchFilterUpdate(showCreationDate: true);

        settle(async);

        final state = setup.container.read(journalPageControllerProvider(true));
        expect(state.showCreationDate, isTrue);
      });
    });

    test('batch update can disable creation dates again', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(true).notifier,
        );

        settle(async);

        controller
          ..applyBatchFilterUpdate(showCreationDate: true)
          ..applyBatchFilterUpdate(showCreationDate: false);

        settle(async);

        final state = setup.container.read(journalPageControllerProvider(true));
        expect(state.showCreationDate, isFalse);
      });
    });

    test(
      'sortOption and showCreationDate persist across other state changes',
      () {
        fakeAsync((async) {
          final controller = setup.container.read(
            journalPageControllerProvider(true).notifier,
          );

          settle(async);

          controller
            ..applyBatchFilterUpdate(
              sortOption: TaskSortOption.byDate,
              showCreationDate: true,
            )
            // Trigger unrelated state update
            ..setFilters({DisplayFilter.starredEntriesOnly});

          settle(async);

          final state = setup.container.read(
            journalPageControllerProvider(true),
          );
          expect(state.sortOption, equals(TaskSortOption.byDate));
          expect(state.showCreationDate, isTrue);
          expect(state.filters, contains(DisplayFilter.starredEntriesOnly));
        });
      },
    );
  });

  group('Show Due Date Toggle', () {
    test('batch update disables due dates', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(true).notifier,
        );

        settle(async);

        // Default is true, so toggle to false
        controller.applyBatchFilterUpdate(showDueDate: false);

        settle(async);

        final state = setup.container.read(journalPageControllerProvider(true));
        expect(state.showDueDate, isFalse);
      });
    });

    test('batch update can enable due dates again', () {
      fakeAsync((async) {
        final controller = setup.container.read(
          journalPageControllerProvider(true).notifier,
        );

        settle(async);

        controller
          ..applyBatchFilterUpdate(showDueDate: false)
          ..applyBatchFilterUpdate(showDueDate: true);

        settle(async);

        final state = setup.container.read(journalPageControllerProvider(true));
        expect(state.showDueDate, isTrue);
      });
    });

    test('showDueDate defaults to true', () {
      fakeAsync((async) {
        setup.container.read(journalPageControllerProvider(true));

        settle(async);

        final state = setup.container.read(journalPageControllerProvider(true));
        expect(state.showDueDate, isTrue);
      });
    });
  });
}
