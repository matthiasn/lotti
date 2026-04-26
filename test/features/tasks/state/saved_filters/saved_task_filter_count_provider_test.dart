import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_count_provider.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_count_repository.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_controller.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

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

  @override
  int get maxFetch => 5000;
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

void main() {
  late TestGetItMocks mocks;

  setUp(() async {
    mocks = await setUpTestGetIt();
    when(
      () => mocks.updateNotifications.updateStream,
    ).thenAnswer((_) => const Stream.empty());
  });

  tearDown(tearDownTestGetIt);

  test('returns 0 when the saved id is unknown', () async {
    final container = ProviderContainer(
      overrides: [
        savedTaskFiltersControllerProvider.overrideWith(
          () => _StubController(const []),
        ),
        savedTaskFilterCountRepositoryProvider.overrideWithValue(
          _FakeRepo(const [99]),
        ),
      ],
    );
    addTearDown(container.dispose);

    // Keep the provider alive by holding a listen subscription.
    final sub = container.listen(
      savedTaskFilterCountProvider('missing'),
      (_, __) {},
    );
    addTearDown(sub.close);

    expect(
      await container.read(savedTaskFilterCountProvider('missing').future),
      0,
    );
  });

  test('delegates to the repository for a known saved filter', () async {
    final repo = _FakeRepo(const [7]);
    final container = ProviderContainer(
      overrides: [
        savedTaskFiltersControllerProvider.overrideWith(
          () => _StubController(const [_filter]),
        ),
        savedTaskFilterCountRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(
      savedTaskFilterCountProvider('sv-1'),
      (_, __) {},
    );
    addTearDown(sub.close);

    expect(
      await container.read(savedTaskFilterCountProvider('sv-1').future),
      7,
    );
    expect(repo.calls, 1);
  });

  test(
    're-runs the count when UpdateNotifications fires with taskNotification '
    '(covers both local writes AND sync-originated changes since '
    'updateStream multiplexes both)',
    () async {
      final controller = StreamController<Set<String>>.broadcast();
      addTearDown(controller.close);
      when(
        () => mocks.updateNotifications.updateStream,
      ).thenAnswer((_) => controller.stream);

      final repo = _FakeRepo(const [3, 5]);
      final container = ProviderContainer(
        overrides: [
          savedTaskFiltersControllerProvider.overrideWith(
            () => _StubController(const [_filter]),
          ),
          savedTaskFilterCountRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(
        savedTaskFilterCountProvider('sv-1'),
        (_, __) {},
      );
      addTearDown(sub.close);

      final initial =
          await container.read(savedTaskFilterCountProvider('sv-1').future);
      expect(initial, 3);

      // Sync-incoming task batch: UpdateNotifications.notify(..., fromSync:
      // true) is debounced and ultimately pushed onto the same updateStream,
      // which is what the provider listens to. Simulate by emitting on the
      // stream directly.
      controller.add({taskNotification, 'some-task-id'});
      // Allow the listener to dispatch invalidateSelf.
      await Future<void>.delayed(Duration.zero);

      final next =
          await container.read(savedTaskFilterCountProvider('sv-1').future);
      expect(next, 5);
      expect(repo.calls, 2);
    },
  );

  test('ignores non-task notifications', () async {
    final controller = StreamController<Set<String>>.broadcast();
    addTearDown(controller.close);
    when(
      () => mocks.updateNotifications.updateStream,
    ).thenAnswer((_) => controller.stream);

    final repo = _FakeRepo(const [2]);
    final container = ProviderContainer(
      overrides: [
        savedTaskFiltersControllerProvider.overrideWith(
          () => _StubController(const [_filter]),
        ),
        savedTaskFilterCountRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(
      savedTaskFilterCountProvider('sv-1'),
      (_, __) {},
    );
    addTearDown(sub.close);

    final initial =
        await container.read(savedTaskFilterCountProvider('sv-1').future);
    expect(initial, 2);

    controller.add({'AUDIO', 'IMAGE'});
    await Future<void>.delayed(Duration.zero);

    // Read again → cached value, no recount.
    final still =
        await container.read(savedTaskFilterCountProvider('sv-1').future);
    expect(still, 2);
    expect(repo.calls, 1);
  });
}
