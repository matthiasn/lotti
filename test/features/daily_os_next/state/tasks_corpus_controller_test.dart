import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/logic/mock_day_agent.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/state/tasks_corpus_controller.dart';

void main() {
  group('TasksCorpusController', () {
    ProviderContainer makeContainer() {
      final container = ProviderContainer()
        ..listen(tasksCorpusControllerProvider, (_, _) {});
      addTearDown(container.dispose);
      return container;
    }

    test('default filter is `all` with no category and empty query', () {
      final container = makeContainer();
      final initial = container.read(tasksCorpusControllerProvider);
      expect(initial.stateFilter, TaskCorpusState.all);
      expect(initial.categoryId, isNull);
      expect(initial.query, isEmpty);
    });

    test(
      'setStateFilter / setCategory / setQuery mutate only the touched field',
      () {
        final container = makeContainer();
        final ctl = container.read(tasksCorpusControllerProvider.notifier);

        ctl.setStateFilter(TaskCorpusState.overdue);
        var s = container.read(tasksCorpusControllerProvider);
        expect(s.stateFilter, TaskCorpusState.overdue);
        expect(s.categoryId, isNull);
        expect(s.query, isEmpty);

        ctl.setCategory('cat_work');
        s = container.read(tasksCorpusControllerProvider);
        expect(s.stateFilter, TaskCorpusState.overdue);
        expect(s.categoryId, 'cat_work');
        expect(s.query, isEmpty);

        ctl.setQuery('  invoice  ');
        s = container.read(tasksCorpusControllerProvider);
        expect(s.stateFilter, TaskCorpusState.overdue);
        expect(s.categoryId, 'cat_work');
        // Controller stores the raw query — trimming is the consumer's job.
        expect(s.query, '  invoice  ');
      },
    );

    test(
      'setCategory(null) clears a previously-set category — not the same as '
      'leaving it unset',
      () {
        final container = makeContainer();
        final ctl = container.read(tasksCorpusControllerProvider.notifier)
          ..setCategory('cat_work');
        expect(
          container.read(tasksCorpusControllerProvider).categoryId,
          'cat_work',
        );

        ctl.setCategory(null);
        expect(
          container.read(tasksCorpusControllerProvider).categoryId,
          isNull,
        );
      },
    );
  });

  group('tasksCorpusItemsProvider', () {
    MockDayAgent freshAgent() => MockDayAgent(
      parseLatency: Duration.zero,
      pendingLatency: Duration.zero,
      triageLatency: Duration.zero,
      summarizeLatency: Duration.zero,
      clock: () => DateTime(2026, 5, 25, 9),
    );

    ProviderContainer makeContainer(MockDayAgent agent) {
      final container = ProviderContainer(
        overrides: [dayAgentProvider.overrideWithValue(agent)],
      )..listen(tasksCorpusItemsProvider, (_, _) {});
      addTearDown(container.dispose);
      return container;
    }

    test('returns the full corpus when the filter is at defaults', () async {
      final container = makeContainer(freshAgent());
      final items = await container.read(tasksCorpusItemsProvider.future);
      expect(items, isNotEmpty);
      expect(items.map((i) => i.id), contains('t_deck_review'));
      expect(items.map((i) => i.id), contains('t_morning_run_done'));
    });

    test(
      're-queries with the new filter when the state filter changes — '
      'overdue narrows to dentist',
      () async {
        final container = makeContainer(freshAgent());
        await container.read(tasksCorpusItemsProvider.future);

        container
            .read(tasksCorpusControllerProvider.notifier)
            .setStateFilter(TaskCorpusState.overdue);

        final filtered = await container.read(tasksCorpusItemsProvider.future);
        expect(filtered, hasLength(1));
        expect(filtered.single.id, 't_dentist');
        expect(filtered.single.state, TaskCorpusState.overdue);
      },
    );

    test('query is matched case-insensitively against task title', () async {
      final container = makeContainer(freshAgent());
      await container.read(tasksCorpusItemsProvider.future);

      container
          .read(tasksCorpusControllerProvider.notifier)
          .setQuery('DECK');

      final filtered = await container.read(tasksCorpusItemsProvider.future);
      expect(filtered, hasLength(1));
      expect(filtered.single.id, 't_deck_review');
    });

    test('category filter narrows the corpus to that category', () async {
      final container = makeContainer(freshAgent());
      await container.read(tasksCorpusItemsProvider.future);

      container
          .read(tasksCorpusControllerProvider.notifier)
          .setCategory('cat_health');

      final filtered = await container.read(tasksCorpusItemsProvider.future);
      expect(filtered.map((i) => i.category.id), everyElement('cat_health'));
      expect(filtered.map((i) => i.id), containsAll(<String>['t_dentist']));
    });
  });
}
