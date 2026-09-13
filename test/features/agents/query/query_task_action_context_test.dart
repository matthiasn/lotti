import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/query/query_journal_crawler.dart';
import 'package:lotti/features/agents/query/query_task_action_context.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../test_data/test_data.dart';
import 'query_test_utils.dart';

void main() {
  late QueryTestBench bench;
  setUpAll(registerAllFallbackValues);
  setUp(() {
    bench = QueryTestBench();
    bench.entries['task'] = testTask.copyWith(
      meta: testTask.meta.copyWith(
        id: 'task',
        categoryId: null,
        private: false,
      ),
      data: testTask.data.copyWith(checklistIds: []),
    );
    when(bench.db.getAllLabelDefinitions).thenAnswer((_) async => []);
  });

  test(
    'offers only visible same-category neighbours and linked time entries',
    () async {
      for (final id in ['visible', 'private', 'foreign']) {
        bench.entries[id] = testTask.copyWith(
          meta: testTask.meta.copyWith(
            id: id,
            private: id == 'private',
            categoryId: id == 'foreign' ? categoryMindfulness.id : null,
          ),
        );
        bench.link('task', id);
      }
      bench
        ..add('time')
        ..link('task', 'time');
      final context = await QueryTaskActionContextLoader(
        access: bench.crawler.access,
      ).load('task');
      expect(context.taskIds, {'visible'});
      expect(context.dependencies.map((e) => e.id), isNot(contains('private')));
      expect(context.dependencies.map((e) => e.id), isNot(contains('foreign')));
      expect(context.input.containsKey('reports'), isFalse);
    },
  );

  for (final privateList in [false, true]) {
    test(
      'loads owned checklist/time/label targets with private parent=$privateList',
      () async {
        final task = bench.entries['task']! as Task;
        bench.entries['task'] = task.copyWith(
          data: task.data.copyWith(
            checklistIds: ['list'],
            aiSuppressedLabelIds: {'suppressed'},
          ),
        );
        bench.entries['list'] = Checklist(
          meta: task.meta.copyWith(id: 'list', private: privateList),
          data: const ChecklistData(
            title: 'Preflight',
            linkedChecklistItems: ['item'],
            linkedTasks: ['task'],
          ),
        );
        bench.entries['item'] = ChecklistItem(
          meta: task.meta.copyWith(id: 'item'),
          data: const ChecklistItemData(
            title: 'Inspect feeder',
            isChecked: false,
            linkedChecklists: ['list'],
          ),
        );
        for (final id in ['completed', 'running', 'unlinked']) {
          bench.entries[id] = testTextEntry.copyWith(
            meta: task.meta.copyWith(
              id: id,
              dateFrom: DateTime(2026, 9, 13, 10),
              dateTo: DateTime(2026, 9, 13, id == 'running' ? 10 : 11),
            ),
          );
          if (id != 'unlinked') bench.link('task', id);
        }
        when(bench.db.getAllLabelDefinitions).thenAnswer(
          (_) async => [
            testLabelDefinition1.copyWith(id: 'visible'),
            testLabelDefinition1.copyWith(id: 'private', private: true),
            testLabelDefinition1.copyWith(
              id: 'foreign',
              applicableCategoryIds: ['foreign'],
            ),
            testLabelDefinition1.copyWith(id: 'suppressed'),
            testLabelDefinition1.copyWith(
              id: 'deleted',
              deletedAt: DateTime(2026, 9, 13),
            ),
          ],
        );
        final context = await QueryTaskActionContextLoader(
          access: bench.crawler.access,
        ).load('task', runningTimerId: 'running');
        expect(context.checklistIds, privateList ? isEmpty : {'item'});
        expect(context.timeEntryIds, {'completed'});
        expect(context.runningTimerId, 'running');
        expect(context.labelIds, {'visible'});
        expect((context.input['timeEntries']! as List).length, 2);
        expect(
          context.dependencies.map((s) => s.id),
          isNot(contains('unlinked')),
        );
      },
    );
  }

  test(
    'action context keeps current fields and bounded time-text previews',
    () async {
      final text = List.filled(100, 'penguin maintenance ').join();
      bench.entries['completed'] = testTextEntry.copyWith(
        meta: testTextEntry.meta.copyWith(
          id: 'completed',
          private: false,
          categoryId: null,
          dateFrom: DateTime(2026, 9, 13, 10),
          dateTo: DateTime(2026, 9, 13, 11),
        ),
        entryText: testTextEntry.entryText!.copyWith(plainText: text),
      );
      bench.link('task', 'completed');
      final context = await QueryTaskActionContextLoader(
        access: bench.crawler.access,
      ).load('task');
      final preview =
          (context.input['timeEntries']! as List).single
              as Map<String, dynamic>;
      expect(preview['summaryPreview'], text.substring(0, 200));
      expect(preview['textTruncated'], isTrue);
      expect(
        (context.input['task']! as Map).containsKey('statusHistory'),
        isFalse,
      );
    },
  );

  test('refuses a missing or hidden home task', () async {
    final task = bench.entries['task']!;
    bench.entries['task'] = task.copyWith(
      meta: task.meta.copyWith(private: true),
    );
    await expectLater(
      QueryTaskActionContextLoader(access: bench.crawler.access).load('task'),
      throwsA(isA<QueryScopeUnavailable>()),
    );
  });

  test('does not expose a timer owned by another task', () async {
    bench.add('foreign-timer');
    final context = await QueryTaskActionContextLoader(
      access: bench.crawler.access,
    ).load('task', runningTimerId: 'foreign-timer');
    expect(context.runningTimerId, isNull);
    expect(context.timeEntryIds, isEmpty);
  });
}
