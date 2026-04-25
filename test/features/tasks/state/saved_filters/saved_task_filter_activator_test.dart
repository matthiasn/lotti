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

  group('liveTasksFilterProvider', () {
    test('builds a TasksFilter snapshot from the live page state', () async {
      final fake = FakeJournalPageController(
        const JournalPageState(
          selectedTaskStatuses: {'BLOCKED', 'ON_HOLD'},
          selectedPriorities: {'P0'},
          showCreationDate: true,
        ),
      );
      final container = _buildContainer(fakeController: fake);
      addTearDown(container.dispose);

      final live = container.read(liveTasksFilterProvider);

      expect(live.selectedTaskStatuses, {'BLOCKED', 'ON_HOLD'});
      expect(live.selectedPriorities, {'P0'});
      expect(live.showCreationDate, isTrue);
      expect(live.showDueDate, isTrue); // default
      expect(live.agentAssignmentFilter, AgentAssignmentFilter.all);
    });
  });
}
