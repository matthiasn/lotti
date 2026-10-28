import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_page_state.dart';
import 'package:lotti/classes/saved_task_filter.dart';
import 'package:lotti/database/agents/agent_database.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_count_provider.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_count_repository.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_controller.dart';
import 'package:lotti/features/tasks/state/task_due_view_counts.dart';
import 'package:lotti/features/tasks/ui/utils.dart';
import 'package:lotti/features/tasks/util/due_date_utils.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/service_overrides.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_utils/fake_journal_page_controller.dart';
import '../../../../widget_test_utils.dart';

class _FakeRepo implements SavedTaskFilterCountRepository {
  _FakeRepo(this.responses);

  /// Successive return values, consumed in order. Last value is reused if the
  /// queue is exhausted.
  final List<int> responses;
  int calls = 0;

  @override
  Future<int> count(TasksFilter filter, {Set<String>? restrictToIds}) async {
    final i = calls < responses.length ? calls : responses.length - 1;
    calls++;
    return responses[i];
  }

  @override
  Future<List<DueDateUrgency>> dueUrgencies(List<TasksFilter> filters) async =>
      List.filled(filters.length, DueDateUrgency.normal);

  @override
  Future<TaskDueViewCounts> dueViewCounts(
    TasksFilter filter, {
    Set<String>? restrictToIds,
  }) async => TaskDueViewCounts.zero;
}

/// Answers [dueUrgencies] from [byStatus] (keyed by the filter's first status)
/// and counts each batch, so a test can see when the provider recomputed.
class _UrgencyRepo implements SavedTaskFilterCountRepository {
  _UrgencyRepo(this.byStatus);

  Map<String, DueDateUrgency> byStatus;
  int urgencyCalls = 0;

  @override
  Future<int> count(TasksFilter filter, {Set<String>? restrictToIds}) async =>
      0;

  @override
  Future<List<DueDateUrgency>> dueUrgencies(List<TasksFilter> filters) async {
    urgencyCalls++;
    return [
      for (final filter in filters)
        byStatus[filter.selectedTaskStatuses.first] ?? DueDateUrgency.normal,
    ];
  }

  @override
  Future<TaskDueViewCounts> dueViewCounts(
    TasksFilter filter, {
    Set<String>? restrictToIds,
  }) async => TaskDueViewCounts.zero;
}

class _StubController extends SavedTaskFiltersController {
  _StubController(this._seed);
  final List<SavedTaskFilter> _seed;

  @override
  Future<List<SavedTaskFilter>> build() async => _seed;
}

/// Records each [TasksFilter] passed to [count] so a test can assert exactly
/// what shape the provider asked the repository to count.
class _CapturingRepo implements SavedTaskFilterCountRepository {
  _CapturingRepo(this.result);
  final int result;
  final List<TasksFilter> captured = [];

  @override
  Future<int> count(TasksFilter filter, {Set<String>? restrictToIds}) async {
    captured.add(filter);
    return result;
  }

  @override
  Future<List<DueDateUrgency>> dueUrgencies(List<TasksFilter> filters) async =>
      List.filled(filters.length, DueDateUrgency.normal);

  @override
  Future<TaskDueViewCounts> dueViewCounts(
    TasksFilter filter, {
    Set<String>? restrictToIds,
  }) async => TaskDueViewCounts.zero;
}

const _filter = SavedTaskFilter(
  id: 'sv-1',
  name: 'A',
  filter: TasksFilter(selectedTaskStatuses: {'IN_PROGRESS'}),
);

const _filter2 = SavedTaskFilter(
  id: 'sv-2',
  name: 'B',
  filter: TasksFilter(selectedTaskStatuses: {'BLOCKED'}),
);

ProviderContainer _buildContainer({
  required List<SavedTaskFilter> seed,
  required _FakeRepo repo,
}) {
  return ProviderContainer(
    overrides: withServiceOverrides([
      savedTaskFiltersControllerProvider.overrideWith(
        () => _StubController(seed),
      ),
      savedTaskFilterCountRepositoryProvider.overrideWithValue(repo),
    ]),
  );
}

/// Builds a counts container, wires the notification stream, and drives the
/// async dependency chain under [fakeAsync] until the first real computation
/// has run. The stubbed saved-filters controller resolves a microtask after
/// the first build, so the counts provider only fans out `repo.count` once
/// that dependency has data — `elapse(Duration.zero)` settles both.
ProviderContainer _settledCountsContainer(
  FakeAsync async, {
  required TestGetItMocks mocks,
  required StreamController<Set<String>> controller,
  required _FakeRepo repo,
  List<SavedTaskFilter> seed = const [_filter, _filter2],
}) {
  when(
    () => mocks.updateNotifications.updateStream,
  ).thenAnswer((_) => controller.stream);
  final container = _buildContainer(seed: seed, repo: repo)
    ..listen(savedTaskFilterCountsProvider, (_, _) {})
    ..read(savedTaskFilterCountsProvider.future).ignore();
  async.elapse(Duration.zero);
  return container;
}

void main() {
  late TestGetItMocks mocks;

  setUp(() async {
    mocks = await setUpTestGetIt();
    when(
      () => mocks.updateNotifications.updateStream,
    ).thenAnswer((_) => const Stream.empty());
  });

  tearDown(tearDownTestGetIt);

  group('savedTaskFilterCountsProvider', () {
    test('returns an empty map when no saved filters exist', () async {
      final container = _buildContainer(
        seed: const [],
        repo: _FakeRepo(const [99]),
      );
      addTearDown(container.dispose);
      final sub = container.listen(
        savedTaskFilterCountsProvider,
        (_, _) {},
      );
      addTearDown(sub.close);

      expect(
        await container.read(savedTaskFilterCountsProvider.future),
        isEmpty,
      );
    });

    test('counts every saved filter in a single batched call', () async {
      final repo = _FakeRepo(const [3, 5]);
      final container = _buildContainer(
        seed: const [_filter, _filter2],
        repo: repo,
      );
      addTearDown(container.dispose);
      final sub = container.listen(
        savedTaskFilterCountsProvider,
        (_, _) {},
      );
      addTearDown(sub.close);

      final counts = await container.read(savedTaskFilterCountsProvider.future);
      expect(counts, {'sv-1': 3, 'sv-2': 5});
      expect(repo.calls, 2);
    });

    test(
      'debounces a burst of taskNotifications into a single recompute, '
      'then propagates the fresh counts',
      () {
        fakeAsync((async) {
          final controller = StreamController<Set<String>>.broadcast();
          final repo = _FakeRepo(const [3, 5, 7, 9]);
          final container = _settledCountsContainer(
            async,
            mocks: mocks,
            controller: controller,
            repo: repo,
          );

          // Initial computation runs immediately (never debounced).
          expect(repo.calls, 2);
          expect(
            container.read(savedTaskFilterCountsProvider).value,
            {'sv-1': 3, 'sv-2': 5},
          );

          // Three task notifications inside one debounce window.
          controller
            ..add({taskNotification, 'task-a'})
            ..add({taskNotification, 'task-b'})
            ..add({taskNotification, 'task-c'});
          async.elapse(Duration.zero);
          // Debounce still pending: no recompute yet.
          expect(repo.calls, 2);

          async.elapse(const Duration(milliseconds: 300));

          // Exactly one recompute (2 filters), not one per notification.
          expect(repo.calls, 4);
          expect(
            container.read(savedTaskFilterCountsProvider).value,
            {'sv-1': 7, 'sv-2': 9},
          );

          container.dispose();
          controller.close();
          async.elapse(Duration.zero);
        });
      },
    );

    test('a taskNotification after the window triggers a fresh recompute', () {
      fakeAsync((async) {
        final controller = StreamController<Set<String>>.broadcast();
        final repo = _FakeRepo(const [1, 1, 1, 1, 1, 1]);
        final container = _settledCountsContainer(
          async,
          mocks: mocks,
          controller: controller,
          repo: repo,
        );
        expect(repo.calls, 2);

        controller.add({taskNotification});
        async
          ..elapse(Duration.zero)
          ..elapse(const Duration(milliseconds: 300));
        expect(repo.calls, 4);

        // A second, separate notification past the window recomputes again.
        controller.add({taskNotification});
        async
          ..elapse(Duration.zero)
          ..elapse(const Duration(milliseconds: 300));
        expect(repo.calls, 6);

        container.dispose();
        controller.close();
        async.elapse(Duration.zero);
      });
    });

    test('disposing cancels a pending debounce (no late recompute)', () {
      fakeAsync((async) {
        final controller = StreamController<Set<String>>.broadcast();
        final repo = _FakeRepo(const [1]);
        final container = _settledCountsContainer(
          async,
          mocks: mocks,
          controller: controller,
          repo: repo,
        );
        expect(repo.calls, 2);

        controller.add({taskNotification});
        async.elapse(Duration.zero);
        expect(repo.calls, 2); // debounce armed but not fired

        container.dispose();
        // Elapsing past the window must not resurrect the cancelled timer.
        async.elapse(const Duration(milliseconds: 300));
        expect(repo.calls, 2);

        controller.close();
        async.elapse(Duration.zero);
      });
    });

    test('ignores non-task notifications', () async {
      final controller = StreamController<Set<String>>.broadcast();
      addTearDown(controller.close);
      when(
        () => mocks.updateNotifications.updateStream,
      ).thenAnswer((_) => controller.stream);

      final repo = _FakeRepo(const [2]);
      final container = _buildContainer(seed: const [_filter], repo: repo);
      addTearDown(container.dispose);
      final sub = container.listen(
        savedTaskFilterCountsProvider,
        (_, _) {},
      );
      addTearDown(sub.close);

      await container.read(savedTaskFilterCountsProvider.future);
      expect(repo.calls, 1);

      controller.add({'AUDIO', 'IMAGE'});
      await pumpEventQueue();

      // Re-read should not invalidate the cache → no additional repo calls.
      await container.read(savedTaskFilterCountsProvider.future);
      expect(repo.calls, 1);
    });
  });

  group('savedTaskFilterCountRepositoryProvider', () {
    test(
      'wires JournalDb / EntitiesCacheService / AgentDatabase from GetIt',
      () async {
        // The default factory pulls services from GetIt. setUpTestGetIt
        // already registers JournalDb and SettingsDb mocks; we add the
        // remaining two (EntitiesCacheService + AgentDatabase) so the
        // factory can construct a repository without going through the
        // override hook.
        final cache = MockEntitiesCacheService();
        when(() => cache.sortedCategories).thenReturn(const []);
        getIt
          ..registerSingleton<EntitiesCacheService>(cache)
          ..registerSingleton<AgentDatabase>(MockAgentDatabase());
        addTearDown(() {
          getIt
            ..unregister<EntitiesCacheService>()
            ..unregister<AgentDatabase>();
        });

        final container = ProviderContainer(overrides: getItServiceOverrides());
        addTearDown(container.dispose);

        final repo = container.read(savedTaskFilterCountRepositoryProvider);
        expect(repo, isA<SavedTaskFilterCountRepository>());
      },
    );
  });

  group('currentTasksFilterCountProvider', () {
    ProviderContainer build({
      required JournalPageState pageState,
      required SavedTaskFilterCountRepository repo,
    }) {
      return ProviderContainer(
        overrides: withServiceOverrides([
          journalPageControllerProvider(
            true,
          ).overrideWith(() => FakeJournalPageController(pageState)),
          savedTaskFilterCountRepositoryProvider.overrideWithValue(repo),
        ]),
      );
    }

    test('counts the live ad-hoc filter shape via the repository', () async {
      final repo = _CapturingRepo(7);
      final container = build(
        pageState: const JournalPageState(
          selectedTaskStatuses: {'IN PROGRESS'},
          selectedPriorities: {'P0'},
        ),
        repo: repo,
      );
      addTearDown(container.dispose);
      final sub = container.listen(
        currentTasksFilterCountProvider,
        (_, _) {},
      );
      addTearDown(sub.close);

      expect(
        await container.read(currentTasksFilterCountProvider.future),
        7,
      );
      // The live priorities + (already non-empty) statuses are forwarded as-is.
      expect(repo.captured.single.selectedPriorities, {'P0'});
      expect(repo.captured.single.selectedTaskStatuses, {'IN PROGRESS'});
    });

    test(
      'expands an empty status selection to all statuses so the Custom count '
      'matches the live list (the repo treats empty statuses as 0)',
      () async {
        final repo = _CapturingRepo(42);
        final container = build(
          // Ad-hoc filter with priorities but NO explicit statuses.
          pageState: const JournalPageState(selectedPriorities: {'P0'}),
          repo: repo,
        );
        addTearDown(container.dispose);
        final sub = container.listen(
          currentTasksFilterCountProvider,
          (_, _) {},
        );
        addTearDown(sub.close);

        expect(
          await container.read(currentTasksFilterCountProvider.future),
          42,
        );
        expect(
          repo.captured.single.selectedTaskStatuses,
          allTaskStatuses.toSet(),
        );
      },
    );

    test('recomputes (debounced) when a task notification arrives', () {
      fakeAsync((async) {
        final controller = StreamController<Set<String>>.broadcast();
        addTearDown(controller.close);
        when(
          () => mocks.updateNotifications.updateStream,
        ).thenAnswer((_) => controller.stream);

        final repo = _FakeRepo(const [10, 20]);
        final container = build(
          pageState: const JournalPageState(
            selectedTaskStatuses: {'IN PROGRESS'},
          ),
          repo: repo,
        )..listen(currentTasksFilterCountProvider, (_, _) {});
        addTearDown(container.dispose);

        container.read(currentTasksFilterCountProvider.future).ignore();
        async.elapse(Duration.zero);
        expect(container.read(currentTasksFilterCountProvider).value, 10);

        controller.add({taskNotification});
        async.elapse(const Duration(milliseconds: 300));
        container.read(currentTasksFilterCountProvider.future).ignore();
        async.elapse(Duration.zero);
        expect(container.read(currentTasksFilterCountProvider).value, 20);
      });
    });

    test('coalesces a burst of task notifications into a single recompute', () {
      fakeAsync((async) {
        final controller = StreamController<Set<String>>.broadcast();
        addTearDown(controller.close);
        when(
          () => mocks.updateNotifications.updateStream,
        ).thenAnswer((_) => controller.stream);

        final repo = _FakeRepo(const [10, 20]);
        final container = build(
          pageState: const JournalPageState(
            selectedTaskStatuses: {'IN PROGRESS'},
          ),
          repo: repo,
        )..listen(currentTasksFilterCountProvider, (_, _) {});
        addTearDown(container.dispose);

        container.read(currentTasksFilterCountProvider.future).ignore();
        async.elapse(Duration.zero);
        expect(repo.calls, 1);

        // Two notifications inside one debounce window: the second cancels the
        // timer the first armed, so exactly one recompute fires.
        controller
          ..add({taskNotification})
          ..add({taskNotification});
        async.elapse(const Duration(milliseconds: 300));
        container.read(currentTasksFilterCountProvider.future).ignore();
        async.elapse(Duration.zero);
        expect(repo.calls, 2);
      });
    });
  });

  group('allTasksTotalCountProvider', () {
    test('counts every task via the repository (all statuses)', () async {
      final repo = _FakeRepo(const [124]);
      final container = ProviderContainer(
        overrides: withServiceOverrides([
          savedTaskFilterCountRepositoryProvider.overrideWithValue(repo),
        ]),
      );
      addTearDown(container.dispose);
      final sub = container.listen(allTasksTotalCountProvider, (_, _) {});
      addTearDown(sub.close);

      expect(await container.read(allTasksTotalCountProvider.future), 124);
      // The repository was asked for the all-statuses total exactly once.
      expect(repo.calls, 1);
    });

    test('recomputes when a task notification arrives', () {
      fakeAsync((async) {
        final controller = StreamController<Set<String>>.broadcast();
        addTearDown(controller.close);
        when(
          () => mocks.updateNotifications.updateStream,
        ).thenAnswer((_) => controller.stream);

        final repo = _FakeRepo(const [10, 20]);
        final container = ProviderContainer(
          overrides: withServiceOverrides([
            savedTaskFilterCountRepositoryProvider.overrideWithValue(repo),
          ]),
        )..listen(allTasksTotalCountProvider, (_, _) {});
        addTearDown(container.dispose);

        container.read(allTasksTotalCountProvider.future).ignore();
        async.elapse(Duration.zero);
        expect(container.read(allTasksTotalCountProvider).value, 10);

        // A task-shaped notification triggers a debounced recompute.
        controller.add({taskNotification});
        async.elapse(const Duration(milliseconds: 300));
        container.read(allTasksTotalCountProvider.future).ignore();
        async.elapse(Duration.zero);
        expect(container.read(allTasksTotalCountProvider).value, 20);
      });
    });

    test('coalesces a burst of task notifications into a single recompute', () {
      fakeAsync((async) {
        final controller = StreamController<Set<String>>.broadcast();
        addTearDown(controller.close);
        when(
          () => mocks.updateNotifications.updateStream,
        ).thenAnswer((_) => controller.stream);

        final repo = _FakeRepo(const [10, 20]);
        final container = ProviderContainer(
          overrides: withServiceOverrides([
            savedTaskFilterCountRepositoryProvider.overrideWithValue(repo),
          ]),
        )..listen(allTasksTotalCountProvider, (_, _) {});
        addTearDown(container.dispose);

        container.read(allTasksTotalCountProvider.future).ignore();
        async.elapse(Duration.zero);
        expect(repo.calls, 1);

        // Two notifications inside one debounce window: the second cancels the
        // timer the first armed, so exactly one recompute fires.
        controller
          ..add({taskNotification})
          ..add({taskNotification});
        async.elapse(const Duration(milliseconds: 300));
        container.read(allTasksTotalCountProvider.future).ignore();
        async.elapse(Duration.zero);
        expect(repo.calls, 2);
      });
    });
  });

  group('savedTaskFilterDueUrgenciesProvider', () {
    ProviderContainer build(_UrgencyRepo repo, List<SavedTaskFilter> seed) =>
        ProviderContainer(
          overrides: withServiceOverrides([
            savedTaskFiltersControllerProvider.overrideWith(
              () => _StubController(seed),
            ),
            savedTaskFilterCountRepositoryProvider.overrideWithValue(repo),
          ]),
        );

    test('maps every saved filter to its own urgency', () async {
      final repo = _UrgencyRepo({
        'IN_PROGRESS': DueDateUrgency.overdue,
        'BLOCKED': DueDateUrgency.dueToday,
      });
      final container = build(repo, const [_filter, _filter2]);
      addTearDown(container.dispose);
      final sub = container.listen(
        savedTaskFilterDueUrgenciesProvider,
        (_, _) {},
      );
      addTearDown(sub.close);
      await container.read(savedTaskFiltersControllerProvider.future);

      expect(
        await container.read(savedTaskFilterDueUrgenciesProvider.future),
        {'sv-1': DueDateUrgency.overdue, 'sv-2': DueDateUrgency.dueToday},
      );
    });

    test('asks nothing when there are no saved filters', () async {
      final repo = _UrgencyRepo(const {});
      final container = build(repo, const []);
      addTearDown(container.dispose);
      final sub = container.listen(
        savedTaskFilterDueUrgenciesProvider,
        (_, _) {},
      );
      addTearDown(sub.close);

      expect(
        await container.read(savedTaskFilterDueUrgenciesProvider.future),
        isEmpty,
      );
      expect(repo.urgencyCalls, 0);
    });

    test('recomputes at local midnight, when due today turns overdue', () {
      // Two minutes before midnight: no task changes, only the date does.
      fakeAsync((async) {
        final repo = _UrgencyRepo({'IN_PROGRESS': DueDateUrgency.dueToday});
        final container = build(repo, const [_filter]);
        addTearDown(container.dispose);
        container
          ..listen(savedTaskFilterDueUrgenciesProvider, (_, _) {})
          ..read(savedTaskFilterDueUrgenciesProvider.future).ignore();
        async.elapse(Duration.zero);
        expect(
          container.read(savedTaskFilterDueUrgenciesProvider).value,
          {'sv-1': DueDateUrgency.dueToday},
        );

        repo.byStatus = {'IN_PROGRESS': DueDateUrgency.overdue};
        async.elapse(const Duration(minutes: 3));

        expect(
          container.read(savedTaskFilterDueUrgenciesProvider).value,
          {'sv-1': DueDateUrgency.overdue},
        );
      }, initialTime: DateTime(2024, 7, 3, 23, 58));
    });
  });

  group('savedTaskFilterCountsProvider and the date', () {
    for (final (label, dueFilter, recomputes) in [
      (
        'a saved due view recounts at local midnight',
        TaskDueFilter.dueToday,
        true,
      ),
      ('plain saved filters do not wake at midnight', TaskDueFilter.all, false),
    ]) {
      test(label, () {
        fakeAsync((async) {
          final repo = _FakeRepo(const [2, 0]);
          final container = _buildContainer(
            seed: [
              SavedTaskFilter(
                id: 'sv-due',
                name: 'Today',
                filter: TasksFilter(
                  selectedTaskStatuses: const {'OPEN'},
                  dueFilter: dueFilter,
                ),
              ),
            ],
            repo: repo,
          );
          addTearDown(container.dispose);
          container
            ..listen(savedTaskFilterCountsProvider, (_, _) {})
            ..read(savedTaskFilterCountsProvider.future).ignore();
          async.elapse(Duration.zero);
          final before = repo.calls;

          async.elapse(const Duration(minutes: 3));

          expect(repo.calls > before, recomputes);
        }, initialTime: DateTime(2024, 7, 3, 23, 58));
      });
    }
  });
}
