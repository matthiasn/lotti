import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_activator.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_controller.dart';

import '../../../../test_utils/fake_journal_page_controller.dart';
import '../../../../widget_test_utils.dart';

const _filterA = TasksFilter(
  selectedTaskStatuses: {'IN_PROGRESS'},
  selectedPriorities: {'P0', 'P1'},
);

const _filterB = TasksFilter(
  agentAssignmentFilter: AgentAssignmentFilter.noAgent,
);

ProviderContainer _buildContainer({
  required FakeJournalPageController fakeController,
  List<SavedTaskFilter> savedSeed = const <SavedTaskFilter>[],
}) {
  final container = ProviderContainer(
    overrides: [
      journalPageControllerProvider(true).overrideWith(() => fakeController),
      savedTaskFiltersControllerProvider.overrideWith(
        () => _StubSavedFiltersController(savedSeed),
      ),
    ],
  );
  return container;
}

class _StubSavedFiltersController extends SavedTaskFiltersController {
  _StubSavedFiltersController(this._seed);
  final List<SavedTaskFilter> _seed;

  @override
  Future<List<SavedTaskFilter>> build() async => _seed;
}

void main() {
  setUp(() async {
    await setUpTestGetIt();
  });

  tearDown(tearDownTestGetIt);

  group('SavedTaskFilterActivator.activate', () {
    test(
      'forwards every saved-filter field to applyBatchFilterUpdate',
      () async {
        final fake = FakeJournalPageController(const JournalPageState());
        final activator = SavedTaskFilterActivator(fake);

        await activator.activate(
          const SavedTaskFilter(
            id: 'sv-1',
            name: 'P0/P1 in progress',
            filter: _filterA,
          ),
        );

        expect(fake.applyBatchFilterUpdateCalled, 1);
        expect(fake.setSelectedTaskStatusesCalls.single, {'IN_PROGRESS'});
        expect(fake.setSelectedPrioritiesCalls.single, {'P0', 'P1'});
        // agent default is `all` — gets forwarded.
        expect(
          fake.agentAssignmentFilterCalls.single,
          AgentAssignmentFilter.all,
        );
        // Display flags are passed through with their saved values.
        expect(fake.showCreationDateCalls.single, false);
        expect(fake.showDueDateCalls.single, true);
      },
    );
  });

  group('SavedTaskFilterActivator.clearToDefault', () {
    test(
      'forwards an empty/default filter to applyBatchFilterUpdate',
      () async {
        final fake = FakeJournalPageController(
          const JournalPageState(
            selectedTaskStatuses: {'IN_PROGRESS'},
            selectedPriorities: {'P0'},
          ),
        );

        await SavedTaskFilterActivator(fake).clearToDefault();

        expect(fake.applyBatchFilterUpdateCalled, 1);
        expect(fake.setSelectedTaskStatusesCalls.single, <String>{});
        expect(fake.setSelectedPrioritiesCalls.single, <String>{});
        expect(fake.sortOptionCalls.single, TaskSortOption.byPriority);
        expect(
          fake.agentAssignmentFilterCalls.single,
          AgentAssignmentFilter.all,
        );
        expect(fake.showCreationDateCalls.single, false);
        expect(fake.showDueDateCalls.single, true);
      },
    );
  });

  group('currentSavedTaskFilterIdProvider', () {
    test('returns null when no saved filter matches the live state', () async {
      final fake = FakeJournalPageController(
        const JournalPageState(
          selectedTaskStatuses: {'OPEN'},
        ),
      );
      final container = _buildContainer(
        fakeController: fake,
        savedSeed: const [
          SavedTaskFilter(id: 'sv-1', name: 'A', filter: _filterA),
        ],
      );
      addTearDown(container.dispose);

      // Wait for the stub controller to load.
      await container.read(savedTaskFiltersControllerProvider.future);

      expect(
        container.read(currentSavedTaskFilterIdProvider),
        isNull,
      );
    });

    test(
      'returns the matching saved id when the live filter matches',
      () async {
        final fake = FakeJournalPageController(
          const JournalPageState(
            selectedTaskStatuses: {'IN_PROGRESS'},
            selectedPriorities: {'P0', 'P1'},
          ),
        );
        final container = _buildContainer(
          fakeController: fake,
          savedSeed: const [
            SavedTaskFilter(id: 'sv-1', name: 'In progress', filter: _filterA),
            SavedTaskFilter(id: 'sv-2', name: 'No agent', filter: _filterB),
          ],
        );
        addTearDown(container.dispose);

        await container.read(savedTaskFiltersControllerProvider.future);

        expect(
          container.read(currentSavedTaskFilterIdProvider),
          'sv-1',
        );
      },
    );
  });

  group('tasksFilterHasUnsavedClausesProvider', () {
    test('false when the live filter has no clauses', () async {
      final fake = FakeJournalPageController(const JournalPageState());
      final container = _buildContainer(fakeController: fake);
      addTearDown(container.dispose);

      await container.read(savedTaskFiltersControllerProvider.future);

      expect(
        container.read(tasksFilterHasUnsavedClausesProvider),
        isFalse,
      );
    });

    test(
      'false when the live filter matches an existing saved filter',
      () async {
        final fake = FakeJournalPageController(
          const JournalPageState(
            selectedTaskStatuses: {'IN_PROGRESS'},
            selectedPriorities: {'P0', 'P1'},
          ),
        );
        final container = _buildContainer(
          fakeController: fake,
          savedSeed: const [
            SavedTaskFilter(id: 'sv-1', name: 'A', filter: _filterA),
          ],
        );
        addTearDown(container.dispose);

        await container.read(savedTaskFiltersControllerProvider.future);

        expect(
          container.read(tasksFilterHasUnsavedClausesProvider),
          isFalse,
        );
      },
    );

    test(
      'true when the live filter has clauses and matches no saved filter',
      () async {
        final fake = FakeJournalPageController(
          const JournalPageState(
            selectedTaskStatuses: {'BLOCKED'},
          ),
        );
        final container = _buildContainer(
          fakeController: fake,
          savedSeed: const [
            SavedTaskFilter(id: 'sv-1', name: 'A', filter: _filterA),
          ],
        );
        addTearDown(container.dispose);

        await container.read(savedTaskFiltersControllerProvider.future);

        expect(
          container.read(tasksFilterHasUnsavedClausesProvider),
          isTrue,
        );
      },
    );
  });

  group('taskFilterNarrowingClauseCount', () {
    test('the resting open-work view narrows nothing', () {
      expect(
        taskFilterNarrowingClauseCount(
          const TasksFilter(selectedTaskStatuses: defaultSelectedTaskStatuses),
        ),
        0,
      );
      expect(
        taskFilterIsNarrowing(
          const TasksFilter(selectedTaskStatuses: defaultSelectedTaskStatuses),
        ),
        isFalse,
      );
    });

    test(
      'an empty status selection admits every status, so narrows nothing',
      () {
        expect(taskFilterNarrowingClauseCount(const TasksFilter()), 0);
      },
    );

    test('a deviating status selection counts one clause per status', () {
      expect(
        taskFilterNarrowingClauseCount(
          const TasksFilter(selectedTaskStatuses: {'BLOCKED', 'DONE'}),
        ),
        2,
      );
    });

    test(
      'the agent clause counts — the regression that let the header claim an '
      'agent-filtered list was unfiltered while the rail called it Custom',
      () {
        const agentOnly = TasksFilter(
          agentAssignmentFilter: AgentAssignmentFilter.hasAgent,
        );
        expect(taskFilterNarrowingClauseCount(agentOnly), 1);
        expect(taskFilterIsNarrowing(agentOnly), isTrue);
        // Both predicates now agree about the same filter.
        expect(tasksFilterHasActiveClauses(agentOnly), isTrue);
      },
    );

    test('every clause species sums into one count', () {
      expect(
        taskFilterNarrowingClauseCount(
          const TasksFilter(
            selectedTaskStatuses: {'BLOCKED'},
            selectedCategoryIds: {'c1', 'c2'},
            selectedProjectIds: {'p1'},
            selectedLabelIds: {'l1'},
            selectedPriorities: {'P0'},
            agentAssignmentFilter: AgentAssignmentFilter.noAgent,
          ),
        ),
        7,
      );
    });

    test(
      'sort is a reordering, not a narrowing: it moves only the saved-shape '
      'predicate',
      () {
        const sorted = TasksFilter(sortOption: TaskSortOption.byDueDate);
        expect(taskFilterIsNarrowing(sorted), isFalse);
        expect(tasksFilterHasActiveClauses(sorted), isTrue);
      },
    );
  });
}
