import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/features/agents/model/pull_request_link_source.dart';
import 'package:lotti/features/agents/workflow/task_pull_request_candidates.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';

UnlinkedPullRequest pr(
  int number,
  String title, {
  String body = '',
  List<String> labels = const [],
  String? branch,
  DateTime? createdAt,
  bool draft = false,
}) => UnlinkedPullRequest(
  owner: 'penguin',
  repo: 'colony',
  number: number,
  title: title,
  createdAt: createdAt ?? DateTime.utc(2026, 10, 30),
  body: body,
  labels: labels,
  headRef: branch,
  authorLogin: 'pingu',
  draft: draft,
);

class _Source implements PullRequestLinkSource {
  _Source(this.result);

  final UnlinkedPullRequestsResult result;

  @override
  Future<bool> canListFor(String taskId) async => true;

  @override
  Future<UnlinkedPullRequestsResult> unlinkedFor(String taskId) async => result;

  @override
  Future<PullRequestLinkConfirmation> link({
    required String taskId,
    required String owner,
    required String repo,
    required int number,
  }) => throw UnimplementedError();
}

void main() {
  group('matchTerms', () {
    test('keeps distinguishing words, folds plurals, drops the rest', () {
      expect(
        matchTerms('feat(Igloos): the Penguins build igloos, ok? #4935 é'),
        {'igloo', 'penguin', 'build', '4935'},
      );
    });

    test('splits branch names and reads letters beyond ASCII', () {
      expect(matchTerms('feat/eis-schollen-zählen'), {
        'eis',
        'schollen',
        'zählen',
      });
    });

    test('keeps a double s and short plurals as written', () {
      expect(matchTerms('glass bus'), {'glass', 'bus'});
    });
  });

  group('rankPullRequestsForTask', () {
    test("ranks the pull request sharing the task's words first, naming "
        'them strongest first', () {
      final ranked = rankPullRequestsForTask(
        taskText: 'Count the igloos on the ice floe\nBefore winter',
        pullRequests: [
          pr(1, 'Waddle faster'),
          pr(2, 'Count igloos', body: 'Walks the floe before winter.'),
        ],
      );

      expect(ranked.map((c) => c.pullRequest.number), [2, 1]);
      expect(ranked.first.sharedTerms.take(2), ['count', 'igloo']);
      expect(ranked.first.sharedTerms, containsAll(['floe', 'winter']));
      expect(ranked.last.score, 0);
      expect(ranked.last.sharedTerms, isEmpty);
    });

    test('a word in the title outweighs one in the branch or labels, which '
        'outweigh one in the description', () {
      final ranked = rankPullRequestsForTask(
        taskText: 'igloo',
        pullRequests: [
          pr(1, 'One', body: 'igloo'),
          pr(2, 'Two', branch: 'feat/igloo'),
          pr(3, 'Three', labels: ['igloo']),
          pr(4, 'Igloo'),
        ],
      );

      final scores = {
        for (final c in ranked) c.pullRequest.number: c.score,
      };
      expect(scores[4], greaterThan(scores[2]!));
      expect(scores[2], scores[3]);
      expect(scores[2], greaterThan(scores[1]!));
      expect(scores[4], closeTo(3 * scores[1]!, 1e-9));
    });

    test('a word every pull request shares counts less than a rare one', () {
      final ranked = rankPullRequestsForTask(
        taskText: 'colony igloo',
        pullRequests: [
          pr(1, 'colony igloo'),
          pr(2, 'colony'),
          pr(3, 'colony'),
        ],
      );

      final first = ranked.first;
      expect(first.pullRequest.number, 1);
      expect(first.sharedTerms, ['igloo', 'colony']);
    });

    test('equal scores keep the newest first, then the higher number', () {
      final ranked = rankPullRequestsForTask(
        taskText: 'nothing shared',
        pullRequests: [
          pr(1, 'a', createdAt: DateTime.utc(2026, 9, 30)),
          pr(3, 'b', createdAt: DateTime.utc(2026, 10, 2)),
          pr(2, 'c', createdAt: DateTime.utc(2026, 10, 2)),
        ],
      );

      expect(ranked.map((c) => c.pullRequest.number), [3, 2, 1]);
    });
  });

  group('descriptionExcerpt', () {
    test('drops comments, images and tags, and collapses whitespace', () {
      expect(
        descriptionExcerpt(
          '<!-- template -->\n## What\n\n![shot](https://x/y.png) '
          '<img src="a"> Counts   the\nigloos.',
        ),
        '## What Counts the igloos.',
      );
    });

    test('cuts a long description with an ellipsis', () {
      final excerpt = descriptionExcerpt('igloo' * 100);
      expect(excerpt, '${'igloo' * 60}…');
      expect(excerpt.length, pullRequestExcerptLength + 1);
      // A cut that lands on a space does not end the excerpt in one.
      expect(descriptionExcerpt('word ' * 100), endsWith('word…'));
    });
  });

  group('renderTaskPullRequestListing', () {
    test('says why nothing could be listed, and to propose nothing', () {
      expect(
        renderTaskPullRequestListing(
          const TaskPullRequestListing.unavailable('GitHub is down.'),
        ),
        'The pull requests could not be listed: GitHub is down. '
        'Do not call link_pull_request.',
      );
    });

    test('says when every open pull request is linked already', () {
      expect(
        renderTaskPullRequestListing(
          const TaskPullRequestListing(
            repository: 'penguin/colony',
            candidates: [],
          ),
        ),
        contains('Do not call link_pull_request'),
      );
    });

    test('lists at most ten, each with what the agent judges by', () {
      final listing = TaskPullRequestListing(
        repository: 'penguin/colony',
        candidates: rankPullRequestsForTask(
          taskText: 'igloo',
          pullRequests: [
            pr(
              100,
              'Count igloos',
              body: '<!-- x -->Walks the floe.',
              labels: ['ice'],
              branch: 'feat/igloo',
              draft: true,
              createdAt: DateTime.utc(2026, 10, 28, 12),
            ),
            for (var n = 1; n <= 11; n++) pr(n, 'Other $n'),
          ],
        ),
      );

      final json =
          jsonDecode(
                withClock(
                  Clock.fixed(DateTime.utc(2026, 11)),
                  () => renderTaskPullRequestListing(listing),
                ),
              )
              as Map<String, dynamic>;

      expect(json['repository'], 'penguin/colony');
      expect(json['unlinkedOpenPullRequests'], 12);
      expect(json['shown'], '10 best matches');
      final listed = json['pullRequests'] as List<dynamic>;
      expect(listed, hasLength(maxListedPullRequestCandidates));
      expect(listed.first, {
        'number': 100,
        'title': 'Count igloos',
        'branch': 'feat/igloo',
        'labels': ['ice'],
        'author': 'pingu',
        'draft': true,
        'openedDaysAgo': 3,
        'sharedTaskTerms': ['igloo'],
        // Title weight 3 × ln(1 + 12 pull requests / 1 sharing the term).
        'matchScore': 7.7,
        'description': 'Walks the floe.',
      });
      expect((listed[1] as Map)['sharedTaskTerms'], isEmpty);
      expect((listed[1] as Map).containsKey('description'), isFalse);
      expect((listed[1] as Map).containsKey('draft'), isFalse);
    });
  });

  test('byNumber finds a listed pull request, and only one', () {
    final listing = TaskPullRequestListing(
      repository: 'penguin/colony',
      candidates: rankPullRequestsForTask(
        taskText: '',
        pullRequests: [pr(7, 'Waddle')],
      ),
    );

    expect(listing.byNumber(7)?.pullRequest.title, 'Waddle');
    expect(listing.byNumber(8), isNull);
  });

  group('loadTaskPullRequestListing', () {
    test('ranks the listing against the task title and description', () async {
      final db = MockJournalDb();
      when(() => db.journalEntityById('task')).thenAnswer(
        (_) async => testTask.copyWith(
          data: testTask.data.copyWith(title: 'Waddle'),
          entryText: const EntryText(plainText: 'across the floe'),
        ),
      );

      final listing = await loadTaskPullRequestListing(
        taskId: 'task',
        journalDb: db,
        source: _Source(
          UnlinkedPullRequestsListed('penguin/colony', [
            pr(1, 'Paint the igloo'),
            pr(2, 'Map the floe'),
            pr(3, 'Waddle faster'),
          ]),
        ),
      );

      expect(listing.repository, 'penguin/colony');
      expect(listing.candidates.map((c) => c.pullRequest.number), [3, 2, 1]);
    });

    test('passes on why nothing could be listed, reading no task', () async {
      final db = MockJournalDb();

      final listing = await loadTaskPullRequestListing(
        taskId: 'task',
        journalDb: db,
        source: _Source(const UnlinkedPullRequestsUnavailable('No token.')),
      );

      expect(listing.repository, isNull);
      expect(listing.unavailableReason, 'No token.');
      expect(listing.candidates, isEmpty);
      verifyNever(() => db.journalEntityById(any()));
    });

    test('ranks against nothing when the entry is not a task', () async {
      final db = MockJournalDb();
      when(() => db.journalEntityById('task')).thenAnswer((_) async => null);

      final listing = await loadTaskPullRequestListing(
        taskId: 'task',
        journalDb: db,
        source: _Source(
          UnlinkedPullRequestsListed('penguin/colony', [pr(1, 'Waddle')]),
        ),
      );

      expect(listing.candidates.single.score, 0);
    });
  });
}
