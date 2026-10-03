import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/pull_request_data.dart';
import 'package:lotti/features/github/domain/pull_request_ref.dart';
import 'package:lotti/features/github/domain/pull_request_summary_input.dart';

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
    expect(
      isSettledPullRequest(merged.copyWith(status: PullRequestStatus.open)),
      isFalse,
    );
    expect(
      isSettledPullRequest(
        merged.copyWith(status: PullRequestStatus.open, draft: true),
      ),
      isFalse,
    );
  });

  test('the input is the content: title, outcome, size and description', () {
    expect(
      pullRequestSummaryInput(ref, merged),
      'Pull request: penguin/colony#7\n'
      'Title: Waddle faster\n'
      'Outcome: merged\n'
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
      'Outcome: closed without merging\n'
      'Description:\n'
      '(none)',
    );
    expect(
      pullRequestSummaryInput(ref, prSnapshot()),
      contains('Outcome: open\n'),
    );
  });

  test(
    'a restamp or a change of checks, reviews or mergeability leaves the '
    'input as it is, so no new summary is asked for',
    () {
      final later = merged.copyWith(
        observedAt: merged.observedAt.add(const Duration(days: 2)),
        checks: const PullRequestChecks(
          rollup: PullRequestCheckRollup.failing,
          total: 2,
          failed: 2,
        ),
        reviews: const PullRequestReviews(
          decision: PullRequestReviewDecision.approved,
          approvals: 1,
        ),
        mergeability: PullRequestMergeability.clean,
        headSha: 'bbbbbbb',
      );
      expect(
        pullRequestSummaryInput(ref, later),
        pullRequestSummaryInput(ref, merged),
      );
    },
  );

  test('a new title, description or outcome is a new input', () {
    final input = pullRequestSummaryInput(ref, merged);
    for (final changed in [
      merged.copyWith(title: 'Waddle fastest'),
      merged.copyWith(body: 'Triples it.'),
      merged.copyWith(status: PullRequestStatus.closed),
    ]) {
      expect(pullRequestSummaryInput(ref, changed), isNot(input));
    }
  });

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
}
