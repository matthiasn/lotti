import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/features/history/domain/history_entry.dart';
import 'package:lotti/features/history/state/history_title_resolver.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../test_data/test_data.dart';
import '../history_test_bench.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late HistoryTestBench bench;

  setUp(() => bench = HistoryTestBench());
  tearDown(() => bench.close());

  HistoryTarget target(HistoryEntityKind kind, String id) =>
      HistoryTarget(kind: kind, entityId: id, route: '/$id');

  test('reads every journal kind in one batch', () async {
    bench
      ..putTask('t1', 'Task title')
      ..entities['e1'] = testTextEntry.copyWith(
        meta: testTextEntry.meta.copyWith(id: 'e1'),
      );

    final titles = await bench.titleResolver.currentTitles([
      target(HistoryEntityKind.task, 't1'),
      target(HistoryEntityKind.entry, 'e1'),
      target(HistoryEntityKind.project, 'missing'),
    ]);

    expect(titles, {
      (HistoryEntityKind.task, 't1'): 'Task title',
      (HistoryEntityKind.entry, 'e1'): 'test entry text',
    });
    verify(
      () => bench.journalDb.getJournalEntitiesForIds({'t1', 'e1', 'missing'}),
    ).called(1);
  });

  test('a soft-deleted journal entity reads as gone', () async {
    bench.entities['t1'] = testTask.copyWith(
      meta: testTask.meta.copyWith(id: 't1', deletedAt: DateTime(2026)),
    );
    final titles = await bench.titleResolver.currentTitles([
      target(HistoryEntityKind.task, 't1'),
    ]);
    expect(titles, isEmpty);
  });

  test('dashboards and habits are read by their names', () async {
    bench.dashboards['d1'] = testDashboardConfig;
    bench.habits['h1'] = habitFlossing;
    bench.habits['h2'] = habitFlossing.copyWith(deletedAt: DateTime(2026));

    final titles = await bench.titleResolver.currentTitles([
      target(HistoryEntityKind.dashboard, 'd1'),
      target(HistoryEntityKind.habit, 'h1'),
      target(HistoryEntityKind.habit, 'h2'),
      target(HistoryEntityKind.dashboard, 'missing'),
    ]);

    expect(titles, {
      (HistoryEntityKind.dashboard, 'd1'): testDashboardConfig.name,
      (HistoryEntityKind.habit, 'h1'): habitFlossing.name,
    });
  });

  group('historyTitleOf', () {
    test('uses the title field where the entity has one', () {
      expect(
        historyTitleOf(
          testTask.copyWith(data: testTask.data.copyWith(title: '  Ship  ')),
        ),
        'Ship',
      );
    });

    test('falls back to the first non-blank line of the text', () {
      final entry = testTextEntry.copyWith(
        entryText: const EntryText(plainText: '\n  \nFirst line\nSecond'),
      );
      expect(historyTitleOf(entry), 'First line');
    });

    test('is empty for an entity with neither', () {
      expect(historyTitleOf(testTextEntry.copyWith(entryText: null)), '');
    });
  });
}
