// ignore_for_file: avoid_redundant_argument_values

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/history/domain/history_filter.dart';
import 'package:lotti/features/history/state/history_controller.dart';
import 'package:lotti/features/history/state/history_providers.dart';
import 'package:lotti/features/history/state/history_service.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/logging_domains.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../history_test_bench.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late HistoryTestBench bench;
  late MockDomainLogger logger;
  late ProviderContainer container;

  setUp(() {
    bench = HistoryTestBench();
    logger = MockDomainLogger();
    container = ProviderContainer.test(
      overrides: [
        historyDbProvider.overrideWithValue(bench.db),
        journalDbProvider.overrideWithValue(bench.journalDb),
        domainLoggerProvider.overrideWithValue(logger),
      ],
    );
  });

  tearDown(() => bench.close());

  /// Builds the controller, keeps it alive and lets its first read land.
  Future<HistoryController> open() async {
    container.listen(historyControllerProvider, (_, _) {});
    final controller = container.read(historyControllerProvider.notifier);
    await pumpEventQueue();
    return controller;
  }

  HistoryViewState read() => container.read(historyControllerProvider);

  List<String?> titles() => [for (final item in read().items) item.title];

  Future<void> seedTasks(int count, {String prefix = 'Task'}) async {
    for (var i = 0; i < count; i++) {
      bench.putTask('t$i', '$prefix $i');
      await bench.appendTaskVisit('t$i', DateTime(2026, 3, 1, 0, i));
    }
  }

  test('opens on the first page, newest first', () async {
    await seedTasks(HistoryService.pageSize + 5);
    await open();

    expect(read().isLoading, isFalse);
    expect(read().items, hasLength(HistoryService.pageSize));
    expect(read().items.first.title, 'Task 24');
    expect(read().hasMore, isTrue);
  });

  test('loadMore appends the next page, then stops', () async {
    await seedTasks(HistoryService.pageSize + 5);
    final controller = await open();

    await controller.loadMore();
    expect(read().items, hasLength(HistoryService.pageSize + 5));
    expect(read().items.last.title, 'Task 0');
    expect(read().hasMore, isFalse);

    // Nothing left: a further call reads nothing.
    clearInteractions(bench.journalDb);
    await controller.loadMore();
    verifyNever(() => bench.journalDb.getJournalEntitiesForIds(any()));
  });

  test('a query filters on current titles', () async {
    bench
      ..putTask('a', 'Bug fix for login')
      ..putTask('b', 'Write docs');
    await bench.appendTaskVisit('a', DateTime(2026, 3, 1));
    await bench.appendTaskVisit('b', DateTime(2026, 3, 2));
    final controller = await open();

    await controller.setQuery('bug');
    expect(titles(), ['Bug fix for login']);
    expect(read().filter.query, 'bug');

    await controller.setQuery('');
    expect(titles(), ['Write docs', 'Bug fix for login']);
  });

  test('the old list stays up while a new query loads', () async {
    await seedTasks(2);
    final controller = await open();
    final held = Completer<List<JournalEntity>>();
    when(
      () => bench.journalDb.getJournalEntitiesForIds(any()),
    ).thenAnswer((_) => held.future);

    final pending = controller.setQuery('task 1');
    await pumpEventQueue();
    expect(read().isLoading, isTrue);
    expect(titles(), ['Task 1', 'Task 0']);

    held.complete([bench.entities['t1']!, bench.entities['t0']!]);
    await pending;
    expect(read().isLoading, isFalse);
    expect(titles(), ['Task 1']);
  });

  test('an answer for a superseded query is dropped', () async {
    bench.putTask('t', 'Bug fix');
    await bench.appendTaskVisit('t', DateTime(2026, 3, 1));
    final controller = await open();
    final slow = Completer<List<JournalEntity>>();
    when(
      () => bench.journalDb.getJournalEntitiesForIds(any()),
    ).thenAnswer((_) => slow.future);

    final first = controller.setQuery('bu');
    await pumpEventQueue();
    when(
      () => bench.journalDb.getJournalEntitiesForIds(any()),
    ).thenAnswer((_) async => const []);
    await controller.setQuery('bugs');
    expect(titles(), isEmpty);

    // The slow read for "bu" lands last and must not win.
    slow.complete([bench.entities['t']!]);
    await first;
    expect(read().filter.query, 'bugs');
    expect(titles(), isEmpty);
  });

  test('setRange narrows to the window and keeps the query', () async {
    bench
      ..putTask('old', 'Old bug')
      ..putTask('new', 'New bug');
    await bench.appendTaskVisit('old', DateTime(2026, 1, 1));
    await bench.appendTaskVisit('new', DateTime(2026, 3, 14));

    await withClock(Clock.fixed(DateTime(2026, 3, 15)), () async {
      final controller = await open();
      await controller.setQuery('bug');
      await controller.setRange(HistoryTimeRange.last30Days);
    });

    expect(read().filter.range, HistoryTimeRange.last30Days);
    expect(read().filter.query, 'bug');
    expect(titles(), ['New bug']);
  });

  test('setCustomRange orders backwards dates', () async {
    bench
      ..putTask('in', 'Inside')
      ..putTask('out', 'Outside');
    await bench.appendTaskVisit('out', DateTime(2026, 2, 1));
    await bench.appendTaskVisit('in', DateTime(2026, 3, 2, 22));
    final controller = await open();

    await controller.setCustomRange(DateTime(2026, 3, 2), DateTime(2026, 3));

    expect(read().filter.customStart, DateTime(2026, 3));
    expect(read().filter.customEnd, DateTime(2026, 3, 2));
    expect(titles(), ['Inside']);
  });

  test('delete removes the row from the list and the log', () async {
    await seedTasks(2);
    final controller = await open();
    final doomed = read().items.first.entry;

    await controller.delete(doomed);

    expect(titles(), ['Task 0']);
    final rows = await bench.db.entriesPage(limit: 10);
    expect(rows.map((r) => r.id), isNot(contains(doomed.id)));
  });

  test('a failed read shows the error state and is logged', () async {
    when(
      () => bench.journalDb.getJournalEntitiesForIds(any()),
    ).thenThrow(StateError('broken'));
    await bench.appendTaskVisit('t', DateTime(2026, 3, 1));
    await open();

    expect(read().hasError, isTrue);
    expect(read().isLoading, isFalse);
    expect(read().items, isEmpty);
    verify(
      () => logger.error(
        LogDomain.navigation,
        any<Object>(that: isA<StateError>()),
        stackTrace: any(named: 'stackTrace'),
        subDomain: 'history.load',
      ),
    ).called(1);
  });

  test('a failed reload keeps the rows already shown', () async {
    await seedTasks(2);
    final controller = await open();
    when(
      () => bench.journalDb.getJournalEntitiesForIds(any()),
    ).thenThrow(StateError('broken'));

    await controller.setQuery('task');

    expect(titles(), ['Task 1', 'Task 0']);
    expect(read().hasError, isTrue);
    expect(read().isLoading, isFalse);
    expect(read().hasMore, isFalse);
  });

  test('a failed next page keeps what is listed', () async {
    await seedTasks(HistoryService.pageSize + 1);
    final controller = await open();
    when(
      () => bench.journalDb.getJournalEntitiesForIds(any()),
    ).thenThrow(StateError('broken'));

    await controller.loadMore();

    expect(read().items, hasLength(HistoryService.pageSize));
    expect(read().hasError, isTrue);
    expect(read().isLoadingMore, isFalse);
    // No next page stays on offer, so nothing asks for it again.
    expect(read().hasMore, isFalse);
    clearInteractions(bench.journalDb);
    await controller.loadMore();
    verifyNever(() => bench.journalDb.getJournalEntitiesForIds(any()));
  });
}
