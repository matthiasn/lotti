import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/query_chat_models.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/query/query_journal_crawler.dart';
import 'package:lotti/features/agents/query/query_task_facts.dart';

import '../../../test_data/test_data.dart';
import 'query_test_utils.dart';

void main() {
  final category = categoryMindfulness.id;
  late QueryTestBench bench;

  setUp(() {
    bench = QueryTestBench()
      ..add('note', category: category)
      ..link('hinge', 'note');
    bench.entries['hinge'] = testTask.copyWith(
      meta: testTask.meta.copyWith(
        id: 'hinge',
        categoryId: category,
        dateFrom: DateTime(2026, 9, 1, 8),
      ),
      data: testTask.data.copyWith(
        title: 'Fix the feeder hinge',
        due: DateTime(2026, 10, 3, 17),
        status: TaskStatus.blocked(
          id: 's2',
          createdAt: DateTime(2026, 10, 20, 9),
          utcOffset: 0,
          reason: 'waiting on parts',
        ),
        statusHistory: [
          TaskStatus.open(
            id: 's1',
            createdAt: DateTime(2026, 9),
            utcOffset: 0,
          ),
        ],
      ),
    );
  });

  Future<QueryCorpus> corpus() =>
      bench.crawler.discover(QueryScope.journal, const []);

  QuerySourceRef ref(QueryCorpus corpus, String id) =>
      corpus.access.reference(bench.entries[id]!);

  const facts = {
    'title': 'Fix the feeder hinge',
    'status': 'BLOCKED',
    'statusSince': '2026-10-20',
    'created': '2026-09-01',
    'due': '2026-10-03',
    'statusChanges': 1,
  };

  test('a task speaks for itself in days, not instants', () async {
    final read = await bench.crawler.withTaskDetails(await corpus(), [
      QuerySourceDocument.fromEntry(bench.entries['hinge']!)!,
    ]);

    expect(
      queryTaskFacts(
        read.corpus.access,
        read.corpus.affiliations,
        ref(read.corpus, 'hinge'),
      ),
      [facts],
    );
  });

  test('a note speaks for the task it is linked to', () async {
    final read = await bench.crawler.withTaskDetails(await corpus(), [
      QuerySourceDocument.fromEntry(bench.entries['hinge']!)!,
    ]);

    expect(
      queryTaskFacts(
        read.corpus.access,
        read.corpus.affiliations,
        ref(read.corpus, 'note'),
      ),
      [facts],
    );
  });

  test('a task with no due date says none, and a note with no task says '
      'nothing', () async {
    bench.entries['hinge'] = (bench.entries['hinge']! as Task).copyWith(
      data: (bench.entries['hinge']! as Task).data.copyWith(due: null),
    );
    bench.links.clear();
    final read = await corpus();

    expect(
      queryTaskFacts(
        read.access,
        read.affiliations,
        ref(read, 'hinge'),
      ).single.containsKey('due'),
      isFalse,
    );
    expect(
      queryTaskFacts(read.access, read.affiliations, ref(read, 'note')),
      isEmpty,
    );
  });

  test('facts come from the snapshot handed in: a task it holds speaks, '
      'one it does not or may no longer show is left out', () async {
    final read = await bench.crawler.withTaskDetails(await corpus(), [
      QuerySourceDocument.fromEntry(bench.entries['hinge']!)!,
    ]);
    final note = ref(read.corpus, 'note');
    final access = bench.crawler.access;

    // The task is not in the crawl's own snapshot, only in the one handed in.
    expect(
      queryTaskFacts(
        await access.load(['note', 'hinge']),
        read.corpus.affiliations,
        note,
      ),
      [facts],
    );
    expect(
      queryTaskFacts(
        await access.load(['note']),
        read.corpus.affiliations,
        note,
      ),
      isEmpty,
    );
    bench.entries['hinge'] = bench.entries['hinge']!.copyWith(
      meta: bench.entries['hinge']!.meta.copyWith(private: true),
    );
    expect(
      queryTaskFacts(
        await access.load(['note', 'hinge']),
        read.corpus.affiliations,
        note,
      ),
      isEmpty,
    );
  });

  test('a day is the local calendar day', () {
    expect(queryDay(DateTime(2026, 11, 14, 23, 59)), '2026-11-14');
  });
}
