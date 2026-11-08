import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/front_agent/model/front_pull_requests.dart';
import 'package:lotti/features/front_agent/service/front_pull_request_reader.dart';
import 'package:lotti/features/insights/logic/time_bucketing.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../categories/test_utils.dart';

void main() {
  late MockJournalDb journalDb;

  // 2026-11-02 through 2026-11-08.
  final range = InsightsRange(
    startDay: epochDay(DateTime(2026, 11, 2)),
    endDayExclusive: epochDay(DateTime(2026, 11, 9)),
  );

  PullRequestStatRowRecord row(
    String key, {
    String entryId = 'entry',
    String? category,
    String? author = 'Pingu',
    DateTime? createdAt,
    DateTime? mergedAt,
    int additions = 10,
    int deletions = 1,
  }) => (
    entryId: '$entryId-$key',
    key: key,
    taskCategoryId: category,
    title: 'Title $key',
    authorLogin: author,
    createdAt: createdAt,
    mergedAt: mergedAt,
    additions: additions,
    deletions: deletions,
  );

  setUp(() {
    journalDb = MockJournalDb();
    when(() => journalDb.getAllCategories()).thenAnswer(
      (_) async => [
        CategoryTestUtils.createTestCategory(id: 'colony', name: 'Colony'),
        CategoryTestUtils.createTestCategory(id: 'ice', name: 'Ice'),
      ],
    );
    when(() => journalDb.getAllCategoriesIncludingPrivate()).thenAnswer(
      (_) async => [
        CategoryTestUtils.createTestCategory(id: 'colony', name: 'Colony'),
        CategoryTestUtils.createTestCategory(id: 'ice', name: 'Ice'),
        CategoryTestUtils.createTestCategory(
          id: 'secret',
          name: 'Secret',
          private: true,
        ),
      ],
    );
  });

  Future<({List<FrontPullRequest> pullRequests, int undated})> read(
    List<PullRequestStatRowRecord> rows, {
    Set<String> categoryIds = const {},
    String? login,
  }) {
    when(() => journalDb.pullRequestStatRows()).thenAnswer((_) async => rows);
    return readFrontPullRequests(
      journalDb,
      FrontPullRequestChart(
        range: range,
        categoryIds: categoryIds,
        authorLogin: login,
      ),
    );
  }

  test('counts a pull request once however many tasks hold it, and only '
      'those opened or merged in the days, newest opened first', () async {
    final result = await read([
      row('p/c#1', category: 'colony', createdAt: DateTime(2026, 11, 3)),
      // Its second holder, and a second device's entry of it.
      row('p/c#1', category: 'ice', createdAt: DateTime(2026, 11, 3)),
      row(
        'p/c#1',
        entryId: 'zz',
        category: 'colony',
        createdAt: DateTime(2026, 11, 3),
        additions: 999,
      ),
      row('p/c#2', createdAt: DateTime(2026, 11, 7), additions: 50),
      // Opened before the days, merged in them.
      row(
        'p/c#3',
        createdAt: DateTime(2026, 10, 20),
        mergedAt: DateTime(2026, 11, 4),
      ),
      // Opened and merged before the days.
      row(
        'p/c#4',
        createdAt: DateTime(2026, 10, 20),
        mergedAt: DateTime(2026, 10, 21),
      ),
      // Opened after the days.
      row('p/c#5', createdAt: DateTime(2026, 11, 9, 8)),
    ]);

    expect(result.pullRequests.map((pr) => pr.key), [
      'p/c#2',
      'p/c#1',
      'p/c#3',
    ]);
    expect(result.pullRequests.map((pr) => pr.additions), [50, 10, 10]);
    expect(result.undated, 0);
  });

  test('reads through the tasks the scope lets her see: a holder outside '
      'it does not count, another inside it does', () async {
    final result = await read(
      [
        row('p/c#1', category: 'ice', createdAt: DateTime(2026, 11, 3)),
        row('p/c#1', category: 'colony', createdAt: DateTime(2026, 11, 3)),
        row('p/c#2', category: 'ice', createdAt: DateTime(2026, 11, 3)),
        // No category: outside a narrowed scope.
        row('p/c#3', createdAt: DateTime(2026, 11, 3)),
      ],
      categoryIds: {'colony'},
    );
    expect(result.pullRequests.map((pr) => pr.key), ['p/c#1']);
  });

  test('a task in a private category holds its pull requests out while '
      'private entries are hidden', () async {
    final result = await read([
      row('p/c#1', category: 'secret', createdAt: DateTime(2026, 11, 3)),
      row('p/c#2', category: 'colony', createdAt: DateTime(2026, 11, 3)),
    ]);
    expect(result.pullRequests.map((pr) => pr.key), ['p/c#2']);
  });

  test("with the user's login only theirs count, whatever its case; one "
      'with no author yet counts, and an undated one is counted '
      'apart', () async {
    final rows = [
      row('p/c#1', author: 'pingu', createdAt: DateTime(2026, 11, 3)),
      row('p/c#2', author: 'robby', createdAt: DateTime(2026, 11, 3)),
      row('p/c#3', author: null, createdAt: DateTime(2026, 11, 4)),
      row('p/c#4', author: null),
      row('p/c#4', author: null, category: 'colony'),
    ];

    final mine = await read(rows, login: 'PINGU');
    expect(mine.pullRequests.map((pr) => pr.key), ['p/c#3', 'p/c#1']);
    expect(mine.undated, 1);

    final everyone = await read(rows);
    expect(everyone.pullRequests.map((pr) => pr.key), [
      'p/c#3',
      'p/c#1',
      'p/c#2',
    ]);
  });
}
