import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/pull_request_data.dart';
import 'package:lotti/features/github/api/pull_request_mapper.dart';

import '../github_fixtures.dart';

void main() {
  final observedAt = DateTime.utc(2024, 3, 15, 12);

  PullRequestSnapshot map({
    Map<String, dynamic>? pull,
    List<Map<String, dynamic>> runs = const [],
    List<Map<String, dynamic>> statuses = const [],
    List<Map<String, dynamic>> reviews = const [],
  }) => pullRequestSnapshotFrom(
    pull: pull ?? githubPullJson(),
    checkRuns: githubCheckRunsJson(runs),
    combinedStatus: githubCombinedStatusJson(statuses),
    reviews: reviews,
    observedAt: observedAt,
  );

  test('copies identity, description and diff stats', () {
    final snapshot = map();
    expect(snapshot.observedAt, observedAt);
    expect(snapshot.title, 'Waddle faster');
    expect(snapshot.body, 'Implements the waddle.');
    expect(snapshot.htmlUrl, 'https://github.com/penguin/colony/pull/12');
    expect(snapshot.headSha, 'abc1234');
    expect(snapshot.headRef, 'feat/waddle');
    expect(snapshot.baseRef, 'main');
    expect(snapshot.authorLogin, 'pingu');
    expect(snapshot.draft, isFalse);
    expect(
      (snapshot.additions, snapshot.deletions, snapshot.changedFiles),
      (10, 2, 3),
    );
    expect(snapshot.commits, 4);
  });

  group('status', () {
    test('open, closed, and merged even though GitHub says closed', () {
      expect(map().status, PullRequestStatus.open);
      expect(
        map(pull: githubPullJson(state: 'closed')).status,
        PullRequestStatus.closed,
      );
      final merged = map(
        pull: githubPullJson(
          state: 'closed',
          merged: true,
          mergedAt: '2024-03-15T11:00:00Z',
        ),
      );
      expect(merged.status, PullRequestStatus.merged);
      expect(merged.mergedAt, DateTime.utc(2024, 3, 15, 11));
    });

    test('an unknown state is a format error, not a guess', () {
      expect(
        () => map(pull: githubPullJson(state: 'locked')),
        throwsFormatException,
      );
    });
  });

  group('mergeability', () {
    PullRequestMergeability of({bool? mergeable, String? state}) => map(
      pull: githubPullJson(mergeable: mergeable, mergeableState: state),
    ).mergeability;

    test('conflicts, whichever field reports them', () {
      expect(
        of(mergeable: false, state: 'dirty'),
        PullRequestMergeability.conflicting,
      );
      expect(
        of(mergeable: false, state: 'unknown'),
        PullRequestMergeability.conflicting,
      );
      expect(
        of(state: 'dirty'),
        PullRequestMergeability.conflicting,
      );
    });

    test('behind and blocked', () {
      expect(
        of(mergeable: true, state: 'behind'),
        PullRequestMergeability.behind,
      );
      expect(
        of(mergeable: true, state: 'blocked'),
        PullRequestMergeability.blocked,
      );
    });

    test('clean, unstable and hooked branches merge as they stand', () {
      for (final state in ['clean', 'unstable', 'has_hooks']) {
        expect(
          of(mergeable: true, state: state),
          PullRequestMergeability.clean,
          reason: state,
        );
      }
    });

    test('still computing, or a state this version does not know', () {
      expect(of(), PullRequestMergeability.unknown);
      expect(
        of(state: 'clean'),
        PullRequestMergeability.unknown,
      );
      expect(
        of(mergeable: true, state: 'draft'),
        PullRequestMergeability.unknown,
      );
    });
  });

  group('checks', () {
    test('none at all', () {
      final checks = map().checks;
      expect(checks.rollup, PullRequestCheckRollup.none);
      expect(checks.total, 0);
    });

    test('check runs and commit statuses count together', () {
      final checks = map(
        runs: [
          githubCheckRunJson('build', conclusion: 'success'),
          githubCheckRunJson('lint', conclusion: 'skipped'),
        ],
        statuses: [githubStatusJson('ci/legacy', 'success')],
      ).checks;
      expect(checks.rollup, PullRequestCheckRollup.passing);
      expect((checks.total, checks.passed), (3, 3));
    });

    test('anything running makes it pending', () {
      final checks = map(
        runs: [
          githubCheckRunJson('build', conclusion: 'success'),
          githubCheckRunJson('test', status: 'in_progress'),
        ],
      ).checks;
      expect(checks.rollup, PullRequestCheckRollup.pending);
      expect(checks.pending, 1);
    });

    test('any failure fails, and names the failing checks, capped', () {
      final checks = map(
        runs: [
          githubCheckRunJson('test', status: 'queued'),
          for (var i = 0; i < 12; i++)
            githubCheckRunJson('shard $i', conclusion: 'failure'),
          githubCheckRunJson('timeout', conclusion: 'timed_out'),
        ],
        statuses: [githubStatusJson('ci/legacy', 'error')],
      ).checks;
      expect(checks.rollup, PullRequestCheckRollup.failing);
      expect((checks.failed, checks.pending, checks.total), (14, 1, 15));
      expect(checks.failingNames, hasLength(PullRequestChecks.maxFailingNames));
      expect(checks.failingNames.first, 'shard 0');
    });
  });

  group('reviews', () {
    test('the latest decisive review of each reviewer counts', () {
      final reviews = map(
        reviews: [
          githubReviewJson('emperor', 'CHANGES_REQUESTED'),
          githubReviewJson('emperor', 'COMMENTED'),
          githubReviewJson('emperor', 'APPROVED'),
          githubReviewJson('king', 'APPROVED'),
        ],
      ).reviews;
      expect(reviews.decision, PullRequestReviewDecision.approved);
      expect((reviews.approvals, reviews.changesRequested), (2, 0));
    });

    test('one outstanding change request outweighs approvals', () {
      final reviews = map(
        reviews: [
          githubReviewJson('emperor', 'APPROVED'),
          githubReviewJson('king', 'CHANGES_REQUESTED'),
        ],
      ).reviews;
      expect(reviews.decision, PullRequestReviewDecision.changesRequested);
      expect(reviews.changesRequested, 1);
    });

    test('a dismissal clears that reviewer', () {
      final reviews = map(
        reviews: [
          githubReviewJson('king', 'CHANGES_REQUESTED'),
          githubReviewJson('king', 'DISMISSED'),
        ],
      ).reviews;
      expect(reviews.decision, PullRequestReviewDecision.none);
    });

    test('requested reviewers who have not decided make it pending', () {
      final reviews = map(
        pull: githubPullJson(requestedReviewers: ['emperor']),
        reviews: [githubReviewJson('king', 'COMMENTED')],
      ).reviews;
      expect(reviews.decision, PullRequestReviewDecision.pending);
    });
  });

  test(
    'a review requested only from a team is pending too: in an '
    'organisation that is often the only request there is',
    () {
      final reviews = map(
        pull: githubPullJson(requestedTeams: ['colony-elders']),
      ).reviews;
      expect(reviews.decision, PullRequestReviewDecision.pending);
    },
  );

  test('a response missing a required field is a format error', () {
    final pull = githubPullJson()..remove('head');
    expect(() => map(pull: pull), throwsFormatException);
  });
}
