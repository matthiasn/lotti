import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_journal_crawler.dart';
import 'package:lotti/features/agents/query/query_summary_reader.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../projects/test_utils.dart';
import '../test_data/entity_factories.dart';
import 'query_test_utils.dart';

void main() {
  final category = categoryMindfulness.id;
  const scope = QueryScope(kind: QueryScopeKind.task, id: 'home');
  late QueryTestBench bench;
  late MockAgentRepository repository;
  late Map<String, AgentReportEntity> reports;
  late QuerySummaryReader reader;
  void task(String id, {String? categoryId, bool private = false}) {
    bench.entries[id] = testTask.copyWith(
      meta: testTask.meta.copyWith(
        id: id,
        categoryId: categoryId ?? category,
        private: private,
        deletedAt: null,
      ),
      data: testTask.data.copyWith(title: 'Penguin task $id'),
    );
    reports[id] = makeTestReport(
      id: 'report-$id',
      tldr: 'Feeder calibration in $id found the lower-pressure setting.',
      content: 'Full report for $id: calibration results and meeting details.',
      oneLiner: 'No further action needed.',
    );
  }

  setUp(() {
    bench = QueryTestBench();
    repository = MockAgentRepository();
    reports = {};
    when(() => repository.getLatestTaskReportsForTaskIds(any())).thenAnswer(
      (call) async => {
        for (final id in call.positionalArguments.first as List<String>)
          id: ?reports[id],
      },
    );
    reader = QuerySummaryReader(
      journal: bench.db,
      access: bench.crawler.access,
      repository: repository,
    );
    task('home');
  });

  test('completed tasks contribute TLDRs in one batched report read', () async {
    task('completed');
    final completed = bench.entries['completed']! as Task;
    bench.entries['completed'] = completed.copyWith(
      data: completed.data.copyWith(
        status: TaskStatus.done(
          id: 'done',
          createdAt: DateTime(2026, 9),
          utcOffset: 0,
        ),
      ),
    );
    final catalog = await reader.discover(scope);
    final result = catalog.tasks
        .singleWhere((summary) => summary.owner.id == 'completed')
        .orientation;
    expect(result['taskId'], 'completed');
    expect(result['ownerId'], 'completed');
    expect(result['status'], 'DONE');
    expect(result['tldr'], contains('lower-pressure setting'));
    expect(result.values, isNot(contains('No further action needed.')));
    expect(result.containsKey('content'), isFalse);
    expect(catalog.incomplete, isFalse);
    verify(
      () => repository.getLatestTaskReportsForTaskIds(['home', 'completed']),
    ).called(1);
    expect(bench.searches, isEmpty);
  });

  test('hidden and cross-category task reports are not fetched', () async {
    task('private', private: true);
    task('foreign', categoryId: 'foreign-category');
    bench.link('home', 'foreign');
    final catalog = await reader.discover(scope);
    expect(catalog.tasks.map((s) => s.owner.id), ['home']);
    verify(() => repository.getLatestTaskReportsForTaskIds(['home'])).called(1);
  });

  test('full summaries require known IDs and do not crawl originals', () async {
    task('completed');
    final catalog = await reader.discover(scope);
    final full = await reader.fullSummaries(catalog, ['completed']);
    expect(full.single.fullSummary['content'], reports['completed']!.content);
    expect(full.single.owner.id, 'completed');
    await expectLater(
      reader.fullSummaries(catalog, ['invented']),
      throwsFormatException,
    );
    expect(bench.searches, isEmpty);
    expect(bench.categoryReads, 1);
    verify(() => repository.getLatestTaskReportsForTaskIds(any())).called(1);
  });

  test('privacy change during report lookup excludes the summary', () async {
    when(() => repository.getLatestTaskReportsForTaskIds(any())).thenAnswer(
      (_) async {
        task('home', private: true);
        return reports;
      },
    );
    await expectLater(
      reader.discover(scope),
      throwsA(isA<QueryScopeUnavailable>()),
    );
  });

  test('moving an owner blocks the later full-summary read', () async {
    task('completed');
    final catalog = await reader.discover(scope);
    task('completed', categoryId: 'foreign-category');
    await expectLater(
      reader.fullSummaries(catalog, ['completed']),
      throwsA(isA<QueryScopeUnavailable>()),
    );
  });

  test('fresh discovery picks up a maintained replacement report', () async {
    final before = await reader.discover(scope);
    reports['home'] = reports['home']!.copyWith(
      id: 'replacement',
      tldr: 'Updated task state after an entry was removed.',
    );
    final after = await reader.discover(scope);
    expect(before.tasks.single.report.id, 'report-home');
    expect(after.tasks.single.orientation['reportId'], 'replacement');
    expect(
      after.tasks.single.orientation['tldr'],
      contains('entry was removed'),
    );
  });

  test('missing reports and discovery caps mark incomplete coverage', () async {
    task('a');
    reports.remove('a');
    final missing = await reader.discover(scope);
    expect(missing.incomplete, isTrue);
    expect(missing.tasks.map((s) => s.owner.id), ['home']);
    task('b');
    final bounded = await QuerySummaryReader(
      journal: bench.db,
      access: bench.crawler.access,
      repository: repository,
      maxTasks: 1,
    ).discover(scope);
    expect(bounded.incomplete, isTrue);
    expect(bounded.tasks.single.owner.id, 'home');
    verify(() => repository.getLatestTaskReportsForTaskIds(['home'])).called(1);
  });

  test('home-only task discovery does not scan the category', () async {
    task('linked');
    task('unrelated');
    bench.link('home', 'linked');
    final catalog = await reader.discover(scope, homeOnly: true);
    expect(catalog.tasks.map((s) => s.owner.id), ['home', 'linked']);
    expect(bench.categoryReads, 0);
  });

  test('parent project contributes a TLDR without its full body', () async {
    bench.entries['project'] = makeTestProject(
      id: 'project',
      categoryId: category,
      title: 'Penguin logistics',
    );
    bench.taskProjects['home'] = 'project';
    when(
      () => repository.getLatestProjectReportForProjectId('project'),
    ).thenAnswer(
      (_) async => makeTestReport(
        id: 'project-report',
        tldr: 'Habitat calibration is complete.',
        content: 'Detailed project report.',
      ),
    );
    final catalog = await reader.discover(scope);
    expect(
      catalog.project!.orientation['tldr'],
      'Habitat calibration is complete.',
    );
    expect(catalog.project!.orientation.containsKey('content'), isFalse);
    expect(catalog.project!.orientation.containsKey('taskId'), isFalse);
    expect(catalog.project!.orientation['ownerId'], 'project');
  });
}
