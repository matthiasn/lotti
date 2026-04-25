import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_controller.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_persistence.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../widget_test_utils.dart';

const _filterA = TasksFilter(
  selectedTaskStatuses: {'IN_PROGRESS'},
  selectedPriorities: {'P0', 'P1'},
);

const _filterB = TasksFilter(
  agentAssignmentFilter: AgentAssignmentFilter.noAgent,
);

const _filterC = TasksFilter(
  selectedTaskStatuses: {'BLOCKED', 'ON_HOLD'},
);

void main() {
  late TestGetItMocks mocks;

  setUp(() async {
    mocks = await setUpTestGetIt();
  });

  tearDown(tearDownTestGetIt);

  // Helper: stub the persisted list at the storage key.
  void stubPersisted(List<SavedTaskFilter> items) {
    when(
      () => mocks.settingsDb.itemByKey(
        SavedTaskFiltersPersistence.storageKey,
      ),
    ).thenAnswer(
      (_) async => jsonEncode(
        items.map((e) => e.toJson()).toList(growable: false),
      ),
    );
  }

  ProviderContainer makeContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  group('build', () {
    test('returns empty list when nothing is persisted', () async {
      final container = makeContainer();

      final list = await container.read(
        savedTaskFiltersControllerProvider.future,
      );

      expect(list, isEmpty);
    });

    test('loads persisted filters in stored order', () async {
      stubPersisted(const [
        SavedTaskFilter(id: 'sv-1', name: 'A', filter: _filterA),
        SavedTaskFilter(id: 'sv-2', name: 'B', filter: _filterB),
      ]);
      final container = makeContainer();

      final list = await container.read(
        savedTaskFiltersControllerProvider.future,
      );

      expect(list.map((e) => e.id), ['sv-1', 'sv-2']);
      expect(list[0].filter, _filterA);
    });
  });

  group('create', () {
    test('appends a new saved filter and persists', () async {
      final container = makeContainer();
      await container.read(savedTaskFiltersControllerProvider.future);

      final created = await container
          .read(savedTaskFiltersControllerProvider.notifier)
          .create(name: 'New view', filter: _filterA);

      expect(created.name, 'New view');
      expect(created.id, isNotEmpty);

      final list = container.read(savedTaskFiltersControllerProvider).value!;
      expect(list, hasLength(1));
      expect(list.first.id, created.id);
      expect(list.first.filter, _filterA);

      verify(
        () => mocks.settingsDb.saveSettingsItem(
          SavedTaskFiltersPersistence.storageKey,
          any(),
        ),
      ).called(1);
    });

    test('preserves existing entries when appending', () async {
      stubPersisted(const [
        SavedTaskFilter(id: 'sv-1', name: 'A', filter: _filterA),
      ]);
      final container = makeContainer();
      await container.read(savedTaskFiltersControllerProvider.future);

      await container
          .read(savedTaskFiltersControllerProvider.notifier)
          .create(name: 'B', filter: _filterB);

      final list = container.read(savedTaskFiltersControllerProvider).value!;
      expect(list.map((e) => e.name), ['A', 'B']);
    });

    test(
      'waits for initial load before mutating to avoid wiping data',
      () async {
        stubPersisted(const [
          SavedTaskFilter(id: 'sv-1', name: 'A', filter: _filterA),
        ]);
        final container = makeContainer();

        // Invoke create() without awaiting the build future first; the mutation
        // must internally await it so the persisted entry is preserved.
        final notifier = container.read(
          savedTaskFiltersControllerProvider.notifier,
        );
        await notifier.create(name: 'B', filter: _filterB);

        final list = container.read(savedTaskFiltersControllerProvider).value!;
        expect(list.map((e) => e.name), ['A', 'B']);
      },
    );
  });

  group('rename', () {
    test('renames an existing filter and persists', () async {
      stubPersisted(const [
        SavedTaskFilter(id: 'sv-1', name: 'Old', filter: _filterA),
      ]);
      final container = makeContainer();
      await container.read(savedTaskFiltersControllerProvider.future);

      await container
          .read(savedTaskFiltersControllerProvider.notifier)
          .rename('sv-1', 'New');

      expect(
        container.read(savedTaskFiltersControllerProvider).value!.single.name,
        'New',
      );
    });

    test('trims whitespace before applying', () async {
      stubPersisted(const [
        SavedTaskFilter(id: 'sv-1', name: 'Old', filter: _filterA),
      ]);
      final container = makeContainer();
      await container.read(savedTaskFiltersControllerProvider.future);

      await container
          .read(savedTaskFiltersControllerProvider.notifier)
          .rename('sv-1', '   Padded   ');

      expect(
        container.read(savedTaskFiltersControllerProvider).value!.single.name,
        'Padded',
      );
    });

    test('is a no-op for empty / whitespace name', () async {
      stubPersisted(const [
        SavedTaskFilter(id: 'sv-1', name: 'Keep', filter: _filterA),
      ]);
      final container = makeContainer();
      await container.read(savedTaskFiltersControllerProvider.future);
      // Reset mock invocation count after the load.
      clearInteractions(mocks.settingsDb);

      await container
          .read(savedTaskFiltersControllerProvider.notifier)
          .rename('sv-1', '   ');

      expect(
        container.read(savedTaskFiltersControllerProvider).value!.single.name,
        'Keep',
      );
      verifyNever(
        () => mocks.settingsDb.saveSettingsItem(any(), any()),
      );
    });

    test('is a no-op when id is unknown', () async {
      stubPersisted(const [
        SavedTaskFilter(id: 'sv-1', name: 'Keep', filter: _filterA),
      ]);
      final container = makeContainer();
      await container.read(savedTaskFiltersControllerProvider.future);
      clearInteractions(mocks.settingsDb);

      await container
          .read(savedTaskFiltersControllerProvider.notifier)
          .rename('missing', 'Whatever');

      verifyNever(
        () => mocks.settingsDb.saveSettingsItem(any(), any()),
      );
    });

    test('is a no-op when name is unchanged', () async {
      stubPersisted(const [
        SavedTaskFilter(id: 'sv-1', name: 'Same', filter: _filterA),
      ]);
      final container = makeContainer();
      await container.read(savedTaskFiltersControllerProvider.future);
      clearInteractions(mocks.settingsDb);

      await container
          .read(savedTaskFiltersControllerProvider.notifier)
          .rename('sv-1', 'Same');

      verifyNever(
        () => mocks.settingsDb.saveSettingsItem(any(), any()),
      );
    });
  });

  group('updateFilter', () {
    test('replaces the filter payload while preserving id and name', () async {
      stubPersisted(const [
        SavedTaskFilter(id: 'sv-1', name: 'View', filter: _filterA),
      ]);
      final container = makeContainer();
      await container.read(savedTaskFiltersControllerProvider.future);

      await container
          .read(savedTaskFiltersControllerProvider.notifier)
          .updateFilter('sv-1', _filterB);

      final updated = container
          .read(savedTaskFiltersControllerProvider)
          .value!
          .single;
      expect(updated.id, 'sv-1');
      expect(updated.name, 'View');
      expect(updated.filter, _filterB);
    });

    test('is a no-op when id is unknown', () async {
      stubPersisted(const [
        SavedTaskFilter(id: 'sv-1', name: 'View', filter: _filterA),
      ]);
      final container = makeContainer();
      await container.read(savedTaskFiltersControllerProvider.future);
      clearInteractions(mocks.settingsDb);

      await container
          .read(savedTaskFiltersControllerProvider.notifier)
          .updateFilter('missing', _filterB);

      expect(
        container.read(savedTaskFiltersControllerProvider).value!.single.filter,
        _filterA,
      );
      verifyNever(
        () => mocks.settingsDb.saveSettingsItem(any(), any()),
      );
    });
  });

  group('delete', () {
    test('removes the filter and persists', () async {
      stubPersisted(const [
        SavedTaskFilter(id: 'sv-1', name: 'A', filter: _filterA),
        SavedTaskFilter(id: 'sv-2', name: 'B', filter: _filterB),
      ]);
      final container = makeContainer();
      await container.read(savedTaskFiltersControllerProvider.future);

      await container
          .read(savedTaskFiltersControllerProvider.notifier)
          .delete('sv-1');

      final list = container.read(savedTaskFiltersControllerProvider).value!;
      expect(list.map((e) => e.id), ['sv-2']);
    });

    test('is a no-op when id is unknown', () async {
      stubPersisted(const [
        SavedTaskFilter(id: 'sv-1', name: 'A', filter: _filterA),
      ]);
      final container = makeContainer();
      await container.read(savedTaskFiltersControllerProvider.future);
      clearInteractions(mocks.settingsDb);

      await container
          .read(savedTaskFiltersControllerProvider.notifier)
          .delete('missing');

      expect(
        container.read(savedTaskFiltersControllerProvider).value,
        hasLength(1),
      );
      verifyNever(
        () => mocks.settingsDb.saveSettingsItem(any(), any()),
      );
    });
  });

  group('reorder', () {
    test('moves a filter to the target position', () async {
      stubPersisted(const [
        SavedTaskFilter(id: 'sv-1', name: 'A', filter: _filterA),
        SavedTaskFilter(id: 'sv-2', name: 'B', filter: _filterB),
        SavedTaskFilter(id: 'sv-3', name: 'C', filter: _filterC),
      ]);
      final container = makeContainer();
      await container.read(savedTaskFiltersControllerProvider.future);

      await container
          .read(savedTaskFiltersControllerProvider.notifier)
          .reorder('sv-3', 'sv-1');

      final list = container.read(savedTaskFiltersControllerProvider).value!;
      expect(list.map((e) => e.id), ['sv-3', 'sv-1', 'sv-2']);
    });

    test('handles dragging downward (reverse direction)', () async {
      stubPersisted(const [
        SavedTaskFilter(id: 'sv-1', name: 'A', filter: _filterA),
        SavedTaskFilter(id: 'sv-2', name: 'B', filter: _filterB),
        SavedTaskFilter(id: 'sv-3', name: 'C', filter: _filterC),
      ]);
      final container = makeContainer();
      await container.read(savedTaskFiltersControllerProvider.future);

      await container
          .read(savedTaskFiltersControllerProvider.notifier)
          .reorder('sv-1', 'sv-3');

      final list = container.read(savedTaskFiltersControllerProvider).value!;
      expect(list.map((e) => e.id), ['sv-2', 'sv-3', 'sv-1']);
    });

    test('is a no-op when dragId equals targetId', () async {
      stubPersisted(const [
        SavedTaskFilter(id: 'sv-1', name: 'A', filter: _filterA),
        SavedTaskFilter(id: 'sv-2', name: 'B', filter: _filterB),
      ]);
      final container = makeContainer();
      await container.read(savedTaskFiltersControllerProvider.future);
      clearInteractions(mocks.settingsDb);

      await container
          .read(savedTaskFiltersControllerProvider.notifier)
          .reorder('sv-1', 'sv-1');

      verifyNever(
        () => mocks.settingsDb.saveSettingsItem(any(), any()),
      );
    });

    test('is a no-op when either id is unknown', () async {
      stubPersisted(const [
        SavedTaskFilter(id: 'sv-1', name: 'A', filter: _filterA),
      ]);
      final container = makeContainer();
      await container.read(savedTaskFiltersControllerProvider.future);
      clearInteractions(mocks.settingsDb);

      await container
          .read(savedTaskFiltersControllerProvider.notifier)
          .reorder('sv-1', 'missing');

      verifyNever(
        () => mocks.settingsDb.saveSettingsItem(any(), any()),
      );
    });
  });
}
