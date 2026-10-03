import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/pull_request_data.dart';
import 'package:lotti/features/github/api/github_client.dart';
import 'package:lotti/features/github/context/pull_request_context_renderer.dart';
import 'package:lotti/features/github/context/pull_request_context_service.dart';
import 'package:lotti/features/github/domain/pull_request_ref.dart';

import '../pull_request_fixtures.dart';

void main() {
  const ref = PullRequestRef(owner: 'penguin', repo: 'colony', number: 12);

  final open = prSnapshot(second: 5).copyWith(
    title: 'Waddle faster',
    body: 'Implements the waddle.\n\nCloses the ice-shelf item.',
    checks: const PullRequestChecks(
      rollup: PullRequestCheckRollup.failing,
      total: 6,
      passed: 4,
      failed: 2,
      failingNames: ['lint', 'shard 3'],
    ),
    mergeability: PullRequestMergeability.conflicting,
    reviews: const PullRequestReviews(
      decision: PullRequestReviewDecision.approved,
      approvals: 2,
    ),
    additions: 10,
    deletions: 2,
    changedFiles: 3,
    commits: 4,
  );

  String render(
    PullRequestContextItem item, {
    PullRequestContextAudience audience = PullRequestContextAudience.taskAgent,
  }) => renderPullRequestContext([item], audience: audience);

  test(
    'check runs the token cannot read are named, so the agent does not take '
    'the commit statuses for all of CI',
    () {
      final text = render(
        PullRequestContextItem(
          ref: ref,
          snapshot: open.copyWith(
            checks: const PullRequestChecks(
              total: 1,
              passed: 1,
              checkRunsHidden: true,
            ),
          ),
          current: true,
        ),
      );

      expect(
        text,
        contains(
          '- Checks: none reported; the token cannot read check runs, so '
          'only commit statuses are counted and CI may be failing unseen',
        ),
      );
    },
  );

  test('nothing to render without pull requests', () {
    for (final audience in PullRequestContextAudience.values) {
      expect(renderPullRequestContext(const [], audience: audience), isEmpty);
    }
  });

  test('a current open pull request carries everything the task needs', () {
    final text = render(
      PullRequestContextItem(ref: ref, snapshot: open, current: true),
    );

    expect(text, contains('### penguin/colony#12 — Waddle faster'));
    expect(text, contains('- Current: observed 2026-03-15T12:00:05.000Z.'));
    expect(text, contains('- State: open'));
    expect(text, contains('- Branch: feat/pr-tracking → main'));
    expect(text, contains('- Checks: failing (2 of 6 failed: lint, shard 3)'));
    expect(text, contains('- Merge: merge conflicts with the base'));
    expect(text, contains('- Reviews: approved (2)'));
    expect(text, contains('- Size: +10 −2, 3 files, 4 commits'));
    expect(
      text,
      contains(
        '- Description:\n  > Implements the waddle.\n  >\n'
        '  > Closes the ice-shelf item.',
      ),
    );
  });

  test(
    'the agent is told to propose completions only from current pull '
    'requests, citing them',
    () {
      final text = render(
        PullRequestContextItem(ref: ref, snapshot: open, current: true),
      );
      expect(text, startsWith('Pull requests linked to this task'));
      expect(text, contains('update_checklist_items'));
      expect(text, contains('never propose a checklist change from it'));
    },
  );

  test(
    'the agent never sees the state of a pull request whose refresh failed '
    '(SuggestRequiresRefresh)',
    () {
      final text = render(
        PullRequestContextItem(
          ref: ref,
          snapshot: open,
          current: false,
          failure: GitHubFailureKind.rateLimited,
        ),
      );

      expect(
        text,
        contains(
          '- Not refreshed (GitHub rate limit reached): its state is unknown.',
        ),
      );
      for (final hidden in [
        '- State:',
        '- Checks:',
        '- Reviews:',
        'Description',
      ]) {
        expect(text, isNot(contains(hidden)), reason: hidden);
      }
    },
  );

  test(
    'the coding prompt sees the last known state of a stale pull request, '
    'labelled as possibly out of date',
    () {
      final text = render(
        PullRequestContextItem(
          ref: ref,
          snapshot: open,
          current: false,
          failure: GitHubFailureKind.offline,
        ),
        audience: PullRequestContextAudience.codingPrompt,
      );

      expect(
        text,
        contains(
          '- Not refreshed (GitHub could not be reached in time): last known '
          'state, observed 2026-03-15T12:00:05.000Z, may be out of date.',
        ),
      );
      expect(text, contains('- State: open'));
      expect(text, contains('ask only for what remains'));
      expect(text, contains('list each mismatch at the top of the prompt'));
    },
  );

  test('a merged pull request skips checks, merge and reviews', () {
    final merged = prSnapshot(status: PullRequestStatus.merged).copyWith(
      mergedAt: DateTime.utc(2026, 3, 15, 11),
    );
    final text = render(
      PullRequestContextItem(ref: ref, snapshot: merged, current: true),
    );

    expect(text, contains('- State: merged at 2026-03-15T11:00:00.000Z'));
    expect(text, isNot(contains('- Checks:')));
    expect(text, isNot(contains('- Reviews:')));
  });

  test('closed and draft pull requests say so', () {
    expect(
      render(
        PullRequestContextItem(
          ref: ref,
          snapshot: prSnapshot(status: PullRequestStatus.closed),
          current: true,
        ),
      ),
      contains('- State: closed without merging'),
    );
    expect(
      render(
        PullRequestContextItem(
          ref: ref,
          snapshot: prSnapshot().copyWith(draft: true),
          current: true,
        ),
      ),
      contains('- State: open, draft'),
    );
  });

  test('a long description is cut, and says so', () {
    final long = open.copyWith(body: 'x' * (pullRequestDescriptionLimit + 50));
    final text = render(
      PullRequestContextItem(ref: ref, snapshot: long, current: true),
    );
    expect(text, contains('… (truncated)'));
    expect(text, isNot(contains('x' * (pullRequestDescriptionLimit + 1))));
  });

  test('a pull request never observed is named, with nothing claimed', () {
    for (final audience in PullRequestContextAudience.values) {
      final text = render(
        const PullRequestContextItem(
          ref: ref,
          snapshot: null,
          current: false,
          failure: GitHubFailureKind.noToken,
        ),
        audience: audience,
      );
      expect(text, contains('### penguin/colony#12\n'));
      expect(
        text,
        contains(
          '- Not refreshed (no GitHub token on this device): its state is '
          'unknown.',
        ),
      );
    }
  });

  test('every failure has a reason the model can read', () {
    final reasons = {
      for (final kind in GitHubFailureKind.values)
        render(
          PullRequestContextItem(
            ref: ref,
            snapshot: null,
            current: false,
            failure: kind,
          ),
        ),
    };
    expect(reasons, hasLength(GitHubFailureKind.values.length));
  });
}
