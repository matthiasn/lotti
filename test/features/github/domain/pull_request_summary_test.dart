import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/pull_request_data.dart';
import 'package:lotti/features/github/domain/pull_request_ref.dart';
import 'package:lotti/features/github/domain/pull_request_summary.dart';

import '../pull_request_fixtures.dart';

void main() {
  const ref = PullRequestRef(owner: 'penguin', repo: 'colony', number: 7);

  final merged = prSnapshot(status: PullRequestStatus.merged).copyWith(
    title: 'Waddle faster',
    body: 'Doubles the waddle speed.',
    additions: 10,
    deletions: 2,
    changedFiles: 3,
    commits: 4,
  );

  test('merged and closed pull requests are settled, open ones are not', () {
    expect(isSettledPullRequest(merged), isTrue);
    expect(
      isSettledPullRequest(merged.copyWith(status: PullRequestStatus.closed)),
      isTrue,
    );
    for (final draft in [false, true]) {
      expect(
        isSettledPullRequest(
          merged.copyWith(status: PullRequestStatus.open, draft: draft),
        ),
        isFalse,
      );
    }
  });

  group('pullRequestSummaryInput', () {
    test('is the content: title, state, size and description', () {
      expect(
        pullRequestSummaryInput(ref, merged),
        'Pull request: penguin/colony#7\n'
        'Title: Waddle faster\n'
        'State: merged\n'
        'Size: +10 −2, 3 files, 4 commits\n'
        'Description:\n'
        'Doubles the waddle speed.',
      );
      expect(
        pullRequestSummaryInput(
          ref,
          prSnapshot(status: PullRequestStatus.closed),
        ),
        'Pull request: penguin/colony#7\n'
        'Title: Track pull requests\n'
        'State: closed without merging\n'
        'Description:\n'
        '(none)',
      );
      expect(
        pullRequestSummaryInput(ref, prSnapshot()),
        contains('State: open\n'),
      );
      expect(
        pullRequestSummaryInput(ref, prSnapshot().copyWith(draft: true)),
        contains('State: open, draft\n'),
      );
    });

    test('names the review rounds and how much discussion there was', () {
      final discussed = merged.copyWith(
        reviews: const PullRequestReviews(
          decision: PullRequestReviewDecision.approved,
          approvals: 1,
          changesRequested: 2,
        ),
        comments: 12,
        reviewComments: 20,
      );
      expect(
        pullRequestSummaryInput(ref, discussed),
        contains(
          'Reviews: changes requested 2 times, approved once\n'
          'Discussion: a long discussion (21–50 comments)\n',
        ),
      );
    });

    test('puts the discussion in bands', () {
      String discussion(int comments) {
        final input = pullRequestSummaryInput(
          ref,
          merged.copyWith(comments: comments, reviewComments: 0),
        );
        return RegExp('Discussion: (.*)').firstMatch(input)!.group(1)!;
      }

      expect(discussion(0), 'no comments');
      expect(discussion(5), 'a few comments (1–5)');
      expect(discussion(6), 'some discussion (6–20 comments)');
      expect(discussion(50), 'a long discussion (21–50 comments)');
      expect(discussion(51), 'a very long discussion (over 50 comments)');
      expect(
        pullRequestSummaryInput(ref, merged),
        isNot(contains('Discussion:')),
        reason: 'counts not read yet say nothing',
      );
    });

    test(
      'a restamp, or a change of checks, mergeability or head, leaves the '
      'input as it is, and so does a comment within the same band — so no '
      'new summary is asked for',
      () {
        final counted = merged.copyWith(comments: 6, reviewComments: 0);
        final later = counted.copyWith(
          observedAt: merged.observedAt.add(const Duration(days: 2)),
          checks: const PullRequestChecks(
            rollup: PullRequestCheckRollup.failing,
            total: 2,
            failed: 2,
          ),
          mergeability: PullRequestMergeability.clean,
          headSha: 'bbbbbbb',
          comments: 7,
          reviewComments: 3,
        );
        expect(
          pullRequestSummaryInput(ref, later),
          pullRequestSummaryInput(ref, counted),
        );
      },
    );

    test(
      'a new title, description, state, review or discussion band is a new '
      'input',
      () {
        final input = pullRequestSummaryInput(ref, merged);
        for (final changed in [
          merged.copyWith(title: 'Waddle fastest'),
          merged.copyWith(body: 'Triples it.'),
          merged.copyWith(status: PullRequestStatus.closed),
          merged.copyWith(
            reviews: const PullRequestReviews(changesRequested: 1),
          ),
          merged.copyWith(comments: 30, reviewComments: 0),
        ]) {
          expect(pullRequestSummaryInput(ref, changed), isNot(input));
        }
      },
    );

    test('a very long description is cut, and says so', () {
      final input = pullRequestSummaryInput(
        ref,
        merged.copyWith(body: 'x' * (pullRequestSummaryDescriptionLimit + 5)),
      );
      expect(
        input,
        endsWith('${'x' * pullRequestSummaryDescriptionLimit} … (truncated)'),
      );
    });
  });

  test('a summary is put on one line, and cut at its limit', () {
    expect(
      briefPullRequestSummary('  One.\n\nTwo   three. '),
      'One. Two three.',
    );
    expect(
      briefPullRequestSummary('z' * (pullRequestTldrMaxChars + 3)),
      '${'z' * pullRequestTldrMaxChars} …',
    );
    expect(briefPullRequestSummary('abcdef', limit: 3), 'abc …');
  });

  test('two summaries with the same tiers are equal', () {
    const a = PullRequestSummary(oneLiner: 'One.', tldr: 'More.');
    expect(a, const PullRequestSummary(oneLiner: 'One.', tldr: 'More.'));
    expect(
      a.hashCode,
      const PullRequestSummary(oneLiner: 'One.', tldr: 'More.').hashCode,
    );
    expect(a, isNot(const PullRequestSummary(oneLiner: null, tldr: 'More.')));
    expect(a.toString(), 'PullRequestSummary(One., More.)');
  });
}
