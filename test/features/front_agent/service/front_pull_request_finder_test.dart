import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/pull_request_data.dart';
import 'package:lotti/features/front_agent/model/front_pull_requests.dart';
import 'package:lotti/features/front_agent/service/front_pull_request_finder.dart';
import 'package:lotti/features/front_agent/service/front_routing_index_builder.dart';
import 'package:lotti/features/github/domain/pull_request_summary.dart';
import 'package:lotti/features/insights/logic/time_bucketing.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../categories/test_utils.dart';
import '../../github/pull_request_fixtures.dart';
import '../front_pull_request_test_data.dart';

void main() {
  late MockJournalDb journalDb;
  late MockAgentRepository agentRepository;
  late MockPullRequestRepository repository;

  Task task(String id, {String categoryId = 'colony'}) => testTask.copyWith(
    meta: testTask.meta.copyWith(id: id, categoryId: categoryId),
    data: testTask.data.copyWith(title: 'Task $id'),
  );

  /// Entry [id] of pull request `matthiasn/lotti#<number>`.
  PullRequestEntry entry(String id, int number, {PullRequestSnapshot? snap}) {
    final base = prEntry(clock: const {'a': 1}, id: id, snapshot: snap);
    return base.copyWith(data: base.data.copyWith(number: number));
  }

  FrontRoutingIndexBuilder builder({bool wired = true}) =>
      FrontRoutingIndexBuilder(
        journalDb: journalDb,
        agentRepository: agentRepository,
        githubLogin: () async => 'pingu',
        pullRequestRepository: wired ? repository : null,
      );

  setUp(() {
    journalDb = MockJournalDb();
    agentRepository = MockAgentRepository();
    repository = MockPullRequestRepository();
    final categories = [
      CategoryTestUtils.createTestCategory(id: 'colony'),
      CategoryTestUtils.createTestCategory(id: 'secret'),
    ];
    when(
      () => journalDb.getAllCategories(),
    ).thenAnswer((_) async => [categories.first]);
    when(
      () => journalDb.getAllCategoriesIncludingPrivate(),
    ).thenAnswer((_) async => categories);
    when(
      () => journalDb.getJournalEntitiesForIds(any()),
    ).thenAnswer(
      (_) async => [task('ledger'), task('vault', categoryId: 'secret')],
    );
    when(
      () => agentRepository.getLatestTaskReportsForTaskIds(any()),
    ).thenAnswer((_) async => {});
    when(() => repository.forTask('ledger')).thenAnswer(
      (_) async => [
        entry('e-7', 7, snap: prSnapshot(title: 'Fish ledger')),
        entry('e-8', 8),
      ],
    );
    when(() => repository.summaryOf(any(), any())).thenAnswer(
      (_) async => const PullRequestSummary(
        oneLiner: 'Adds the fish ledger.',
        tldr: 'Adds the ledger the colony counts fish in.',
      ),
    );
  });

  group('pullRequestsOf', () {
    test('each card as the turn may see it: its title, summary and task; '
        'one whose task is hidden or that the task no longer holds is left '
        'out', () async {
      final found = await builder().pullRequestsOf(const [
        (key: 'matthiasn/lotti#9', taskId: 'ledger'),
        (key: 'matthiasn/lotti#7', taskId: 'ledger'),
        (key: 'matthiasn/lotti#1', taskId: 'vault'),
        (key: 'matthiasn/lotti#8', taskId: 'ledger'),
      ], const FrontRoutingScope());

      expect(found.map((pr) => pr.key), [
        'matthiasn/lotti#7',
        'matthiasn/lotti#8',
      ]);
      final ledger = found.first;
      expect(ledger.title, 'Fish ledger');
      expect(ledger.oneLiner, 'Adds the fish ledger.');
      expect(ledger.task.title, 'Task ledger');
      expect(ledger.createdAt, prFixtureEpoch);
      // Never read from GitHub: named by its key, with no summary.
      expect(found.last.title, 'matthiasn/lotti#8');
      expect(found.last.oneLiner, isNull);
      verifyNever(() => repository.forTask('vault'));
    });

    test('reads nothing without cards or without a repository', () async {
      expect(
        await builder().pullRequestsOf(const [], const FrontRoutingScope()),
        isEmpty,
      );
      expect(
        await builder(wired: false).pullRequestsOf(const [
          (key: 'matthiasn/lotti#7', taskId: 'ledger'),
        ], const FrontRoutingScope()),
        isEmpty,
      );
      verifyZeroInteractions(journalDb);
    });
  });

  group('pullRequestFinder', () {
    test('the window counted as the statistics count it, the user own, each '
        'with its task', () async {
      final now = DateTime(2026, 3, 20, 12);
      when(() => journalDb.pullRequestStatRows()).thenAnswer(
        (_) async => [
          (
            entryId: 'e-7',
            key: 'matthiasn/lotti#7',
            taskId: 'ledger',
            taskCategoryId: 'colony',
            title: 'Fish ledger',
            authorLogin: 'pingu',
            createdAt: DateTime.utc(2026, 3, 18, 10),
            mergedAt: null,
            additions: 10,
            deletions: 2,
          ),
          (
            entryId: 'e-5',
            key: 'matthiasn/lotti#5',
            taskId: 'ledger',
            taskCategoryId: 'colony',
            title: 'Someone else',
            authorLogin: 'skipper',
            createdAt: DateTime.utc(2026, 3, 18, 10),
            mergedAt: null,
            additions: 1,
            deletions: 1,
          ),
        ],
      );

      final candidates = await builder().pullRequestFinder(
        const FrontRoutingScope(),
        now: now,
      )!((period: null, range: _week(now)));

      expect(candidates.range, _week(now));
      expect(candidates.pullRequests.map((pr) => pr.key), [
        'matthiasn/lotti#7',
      ]);
      expect(candidates.pullRequests.single.task.id, 'ledger');
    });

    test('is unavailable without a repository', () {
      expect(
        builder(wired: false).pullRequestFinder(
          const FrontRoutingScope(),
          now: DateTime(2026),
        ),
        isNull,
      );
    });
  });

  test('pullRequestDetails renders each as last stored, in full, for the '
      'companion', () async {
    final details = await builder().pullRequestDetails([
      // Not one the task holds any more: left out.
      foundPullRequest(1),
      FrontFoundPullRequest(
        key: 'matthiasn/lotti#7',
        title: 'Fish ledger',
        task: pullRequestTask('ledger'),
      ),
    ]);

    expect(details, contains('Pull requests as the app last stored them'));
    expect(details, contains('### matthiasn/lotti#7 — Fish ledger'));
    expect(details, contains('- Last stored: observed'));
    expect(details, contains('- TL;DR: Adds the ledger'));
    expect(details, isNot(contains('penguin/colony#1')));
  });

  test('frontPullRequestTasks lists each holding task once', () {
    expect(
      frontPullRequestTasks([
        foundPullRequest(1),
        foundPullRequest(2, taskId: 'igloo'),
        foundPullRequest(3),
      ]).map((row) => row.id),
      ['ledger', 'igloo'],
    );
  });
}

InsightsRange _week(DateTime now) => InsightsRange(
  startDay: epochDay(now) - 6,
  endDayExclusive: epochDay(now) + 1,
);
