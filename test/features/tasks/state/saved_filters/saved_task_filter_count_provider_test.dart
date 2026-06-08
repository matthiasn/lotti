import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_count_provider.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_count_repository.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

class _FakeRepo implements SavedTaskFilterCountRepository {
  _FakeRepo(this.responses);

  /// Successive return values, consumed in order. Last value is reused if the
  /// queue is exhausted.
  final List<int> responses;
  int calls = 0;

  @override
  Future<int> count(TasksFilter filter) async {
    final i = calls < responses.length ? calls : responses.length - 1;
    calls++;
    return responses[i];
  }
}

class _StubController extends SavedTaskFiltersController {
  _StubController(this._seed);
  final List<SavedTaskFilter> _seed;

  @override
  Future<List<SavedTaskFilter>> build() async => _seed;
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
    overrides: [
      savedTaskFiltersControllerProvider.overrideWith(
        () => _StubController(seed),
      ),
      savedTaskFilterCountRepositoryProvider.overrideWithValue(repo),
    ],
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

        final container = ProviderContainer();
        addTearDown(container.dispose);

        final repo = container.read(savedTaskFilterCountRepositoryProvider);
        expect(repo, isA<SavedTaskFilterCountRepository>());
      },
    );
  });

  group('savedTaskFilterCountProvider (single id)', () {
    test('returns 0 when the saved id is unknown', () async {
      final container = _buildContainer(
        seed: const [],
        repo: _FakeRepo(const [99]),
      );
      addTearDown(container.dispose);
      final sub = container.listen(
        savedTaskFilterCountProvider('missing'),
        (_, _) {},
      );
      addTearDown(sub.close);

      expect(
        await container.read(savedTaskFilterCountProvider('missing').future),
        0,
      );
    });

    test('reads the per-id count from the aggregated map', () async {
      final repo = _FakeRepo(const [11]);
      final container = _buildContainer(
        seed: const [_filter],
        repo: repo,
      );
      addTearDown(container.dispose);
      final sub = container.listen(
        savedTaskFilterCountProvider('sv-1'),
        (_, _) {},
      );
      addTearDown(sub.close);

      expect(
        await container.read(savedTaskFilterCountProvider('sv-1').future),
        11,
      );
    });
  });
}
