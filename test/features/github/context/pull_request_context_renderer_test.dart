import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/github/pull_request_ref.dart';
import 'package:lotti/classes/pull_request_data.dart';
import 'package:lotti/features/github/api/github_client.dart';
import 'package:lotti/features/github/context/pull_request_context_renderer.dart';
import 'package:lotti/features/github/context/pull_request_context_service.dart';
import 'package:lotti/features/github/domain/pull_request_summary.dart';

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

  group('a merged or closed pull request is shown in brief', () {
    final merged = open.copyWith(
      status: PullRequestStatus.merged,
      mergedAt: DateTime.utc(2026, 3, 15, 11),
    );
    const tldr = 'Makes penguins waddle twice as fast on the ice shelf.';
    const summary = PullRequestSummary(
      oneLiner: 'Penguins waddle faster.',
      tldr: tldr,
    );

    test(
      'with its summary: outcome, size and TL;DR, no branch, checks or '
      'description',
      () {
        for (final audience in PullRequestContextAudience.values) {
          final text = render(
            PullRequestContextItem(
              ref: ref,
              snapshot: merged,
              current: true,
              summary: summary,
            ),
            audience: audience,
          );

          expect(
            text.substring(text.indexOf('### ')),
            '### penguin/colony#12 — Waddle faster\n'
            '- Current: observed 2026-03-15T12:00:05.000Z.\n'
            '- State: merged at 2026-03-15T11:00:00.000Z '
            '(+10 −2, 3 files, 4 commits)\n'
            '- TL;DR: $tldr',
            reason: audience.name,
          );
        }
      },
    );

    test(
      'without one yet: the same brief block minus the TL;DR, never the full '
      'description',
      () {
        final text = render(
          PullRequestContextItem(ref: ref, snapshot: merged, current: true),
        );

        expect(
          text.substring(text.indexOf('### ')),
          '### penguin/colony#12 — Waddle faster\n'
          '- Current: observed 2026-03-15T12:00:05.000Z.\n'
          '- State: merged at 2026-03-15T11:00:00.000Z '
          '(+10 −2, 3 files, 4 commits)',
        );
      },
    );

    test('one closed without merging says so, in brief', () {
      final text = render(
        PullRequestContextItem(
          ref: ref,
          snapshot: open.copyWith(status: PullRequestStatus.closed),
          current: true,
          summary: const PullRequestSummary(
            oneLiner: null,
            tldr: 'Abandoned for a sled.',
          ),
        ),
        audience: PullRequestContextAudience.codingPrompt,
      );

      expect(
        text,
        contains(
          '- State: closed without merging (+10 −2, 3 files, 4 commits)\n'
          '- TL;DR: Abandoned for a sled.',
        ),
      );
      expect(text, isNot(contains('- Description:')));
    });

    test(
      'an open or draft pull request keeps its full detail, with its TL;DR '
      'under its state',
      () {
        for (final snapshot in [open, open.copyWith(draft: true)]) {
          final text = render(
            PullRequestContextItem(
              ref: ref,
              snapshot: snapshot,
              current: true,
              summary: summary,
            ),
          );

          expect(
            text,
            contains(
              '- State: ${snapshot.draft ? 'open, draft' : 'open'}\n'
              '- TL;DR: $tldr\n'
              '- Branch:',
            ),
          );
          expect(text, contains('- Checks: failing'));
          expect(text, contains('- Description:'));
        }
      },
    );

    test(
      'the agent still sees only the name of one that was not refreshed '
      '(SuggestRequiresRefresh)',
      () {
        final text = render(
          PullRequestContextItem(
            ref: ref,
            snapshot: merged,
            current: false,
            failure: GitHubFailureKind.offline,
            summary: summary,
          ),
        );

        expect(
          text.substring(text.indexOf('### ')),
          '### penguin/colony#12 — Waddle faster\n'
          '- Not refreshed (GitHub could not be reached in time): its state '
          'is unknown.',
        );
      },
    );

    test('the coding prompt shows one not refreshed as last known', () {
      final text = render(
        PullRequestContextItem(
          ref: ref,
          snapshot: merged,
          current: false,
          failure: GitHubFailureKind.offline,
          summary: summary,
        ),
        audience: PullRequestContextAudience.codingPrompt,
      );

      expect(text, contains('last known state, observed'));
      expect(text, contains('- TL;DR: $tldr'));
    });

    test('a summary is one line, cut when a model ran long', () {
      final text = render(
        PullRequestContextItem(
          ref: ref,
          snapshot: merged,
          current: true,
          summary: const PullRequestSummary(
            oneLiner: null,
            tldr: '  First line.\n\nSecond   line.  ',
          ),
        ),
      );
      expect(text, endsWith('- TL;DR: First line. Second line.'));

      final long = render(
        PullRequestContextItem(
          ref: ref,
          snapshot: merged,
          current: true,
          summary: PullRequestSummary(
            oneLiner: null,
            tldr: 'y' * (pullRequestTldrMaxChars + 10),
          ),
        ),
      );
      expect(long, endsWith('- TL;DR: ${'y' * pullRequestTldrMaxChars} …'));
    });

    test('both audiences are told what the brief form means', () {
      for (final audience in PullRequestContextAudience.values) {
        expect(
          render(
            PullRequestContextItem(ref: ref, snapshot: merged, current: true),
            audience: audience,
          ),
          contains(
            'A merged or closed pull request is shown in brief — its outcome, '
            'size and, once one is written, a TL;DR of what it did: a merged '
            'one is work done, one closed without merging is not.',
          ),
          reason: audience.name,
        );
      }
    });

    test(
      'nine pull requests, eight of them merged, render a fraction of the '
      'full detail',
      () {
        final body = 'Changes the colony. ' * 200;
        final items = [
          for (var n = 1; n <= 9; n++)
            PullRequestContextItem(
              ref: PullRequestRef(owner: 'penguin', repo: 'colony', number: n),
              snapshot: (n == 9 ? open : merged).copyWith(body: body),
              current: true,
              summary: n == 9 ? null : summary,
            ),
        ];
        final full = [
          for (final item in items)
            PullRequestContextItem(
              ref: item.ref,
              snapshot: item.snapshot!.copyWith(
                status: PullRequestStatus.open,
              ),
              current: true,
            ),
        ];

        final brief = renderPullRequestContext(
          items,
          audience: PullRequestContextAudience.taskAgent,
        ).length;
        final detailed = renderPullRequestContext(
          full,
          audience: PullRequestContextAudience.taskAgent,
        ).length;

        expect(brief, lessThan(detailed ~/ 5));
      },
    );
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
