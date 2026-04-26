import 'dart:async';

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
      're-runs every count when UpdateNotifications fires with '
      'taskNotification (covers both local writes AND sync-originated '
      'changes since updateStream multiplexes both)',
      () async {
        final controller = StreamController<Set<String>>.broadcast();
        addTearDown(controller.close);
        when(
          () => mocks.updateNotifications.updateStream,
        ).thenAnswer((_) => controller.stream);

        final repo = _FakeRepo(const [3, 5, 7, 9]);
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

        final initial = await container.read(
          savedTaskFilterCountsProvider.future,
        );
        expect(initial, {'sv-1': 3, 'sv-2': 5});

        controller.add({taskNotification, 'some-task-id'});
        await Future<void>.delayed(Duration.zero);

        final next = await container.read(savedTaskFilterCountsProvider.future);
        expect(next, {'sv-1': 7, 'sv-2': 9});
      },
    );

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
      await Future<void>.delayed(Duration.zero);

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
