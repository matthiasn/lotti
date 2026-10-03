import 'package:lotti/classes/pull_request_data.dart';
import 'package:lotti/features/github/api/github_client.dart';
import 'package:lotti/features/github/context/pull_request_context_service.dart';

/// Who reads a rendered pull request section.
enum PullRequestContextAudience {
  /// The coding prompt: it may see a stale pull request's last known state,
  /// labelled as such, because nothing is proposed from it.
  codingPrompt,

  /// The task agent's wake: it sees a pull request's state only when it is
  /// current, because what it reads can become a checklist suggestion
  /// (`SuggestRequiresRefresh` in `specs/tla/PullRequestSnapshot.tla`).
  taskAgent,
}

/// How much of a pull request description a context carries.
const pullRequestDescriptionLimit = 4000;

/// The task's pull requests as Markdown for [audience], opening with how to
/// use them; empty when there are none. Prompt text, so English.
String renderPullRequestContext(
  List<PullRequestContextItem> items, {
  required PullRequestContextAudience audience,
}) {
  if (items.isEmpty) return '';
  final out = StringBuffer()
    ..writeln(switch (audience) {
      PullRequestContextAudience.taskAgent => _agentGuidance,
      PullRequestContextAudience.codingPrompt => _codingPromptGuidance,
    });
  for (final item in items) {
    out
      ..writeln()
      ..write(_renderItem(item, audience));
  }
  return out.toString().trimRight();
}

const _agentGuidance =
    'Pull requests linked to this task, refreshed from GitHub for this '
    'wake. A pull request marked current is evidence of work done: when it '
    'shows an open checklist item done — merged, or its description and '
    'changes complete what the item asks — propose checking that item with '
    'update_checklist_items and name the pull request (owner/repo#number) '
    'in the reason. A pull request marked not refreshed tells you nothing '
    'about its state: never propose a checklist change from it.';

const _codingPromptGuidance =
    'Pull requests linked to this task, refreshed from GitHub now. Treat '
    'what they contain as work already done and ask only for what remains. '
    'If they disagree with the task — a checklist item checked that no pull '
    'request covers, a pull request doing work no checklist item describes, '
    'or the entry notes asking for something a pull request already '
    'contains — list each mismatch at the top of the prompt, before the '
    'request. A pull request marked not refreshed shows its last known '
    'state, which may be out of date.';

String _renderItem(
  PullRequestContextItem item,
  PullRequestContextAudience audience,
) {
  final snapshot = item.snapshot;
  final out = StringBuffer()
    ..writeln(
      snapshot == null
          ? '### ${item.ref}'
          : '### ${item.ref} — ${snapshot.title}',
    );
  final failure = item.failure;

  if (!item.current) {
    final reason = failure == null ? 'not refreshed' : _failureReason(failure);
    if (audience == PullRequestContextAudience.taskAgent || snapshot == null) {
      out.writeln('- Not refreshed ($reason): its state is unknown.');
      return out.toString();
    }
    out.writeln(
      '- Not refreshed ($reason): last known state, observed '
      '${_iso(snapshot.observedAt)}, may be out of date.',
    );
  } else if (snapshot != null) {
    out.writeln('- Current: observed ${_iso(snapshot.observedAt)}.');
  }
  if (snapshot == null) return out.toString();

  out
    ..writeln('- State: ${_state(snapshot)}')
    ..writeln('- Branch: ${snapshot.headRef} → ${snapshot.baseRef}');
  if (snapshot.status == PullRequestStatus.open) {
    out
      ..writeln('- Checks: ${_checks(snapshot.checks)}')
      ..writeln('- Merge: ${_mergeability(snapshot.mergeability)}')
      ..writeln('- Reviews: ${_reviews(snapshot.reviews)}');
  }
  final size = _size(snapshot);
  if (size != null) out.writeln('- Size: $size');
  final body = snapshot.body?.trim();
  if (body != null && body.isNotEmpty) {
    final truncated = body.length > pullRequestDescriptionLimit;
    final shown = truncated
        ? '${body.substring(0, pullRequestDescriptionLimit)} … (truncated)'
        : body;
    out.writeln('- Description:');
    for (final line in shown.split('\n')) {
      out.writeln(line.isEmpty ? '  >' : '  > $line');
    }
  }
  return out.toString();
}

String _iso(DateTime t) => t.toUtc().toIso8601String();

String _state(PullRequestSnapshot s) => switch (s.status) {
  PullRequestStatus.open => s.draft ? 'open, draft' : 'open',
  PullRequestStatus.merged =>
    s.mergedAt == null ? 'merged' : 'merged at ${_iso(s.mergedAt!)}',
  PullRequestStatus.closed =>
    s.closedAt == null
        ? 'closed without merging'
        : 'closed without merging at ${_iso(s.closedAt!)}',
};

String _checks(PullRequestChecks c) =>
    c.checkRunsHidden ?? false ? '${_rollup(c)}; $_hidden' : _rollup(c);

const _hidden =
    'the token cannot read check runs, so only commit statuses are '
    'counted and CI may be failing unseen';

String _rollup(PullRequestChecks c) => switch (c.rollup) {
  PullRequestCheckRollup.none => 'none reported',
  PullRequestCheckRollup.passing => 'passing (${c.passed} of ${c.total})',
  PullRequestCheckRollup.pending =>
    'running (${c.pending} of ${c.total} not finished)',
  PullRequestCheckRollup.failing =>
    'failing (${c.failed} of ${c.total} failed'
        '${c.failingNames.isEmpty ? '' : ': ${c.failingNames.join(', ')}'})',
};

String _mergeability(PullRequestMergeability m) => switch (m) {
  PullRequestMergeability.clean => 'mergeable',
  PullRequestMergeability.conflicting => 'merge conflicts with the base',
  PullRequestMergeability.behind => 'behind the base branch',
  PullRequestMergeability.blocked => 'blocked by branch rules',
  PullRequestMergeability.unknown => 'not yet known',
};

String _reviews(PullRequestReviews r) => switch (r.decision) {
  PullRequestReviewDecision.approved => 'approved (${r.approvals})',
  PullRequestReviewDecision.changesRequested =>
    'changes requested (${r.changesRequested})',
  PullRequestReviewDecision.pending => 'review requested, none given yet',
  PullRequestReviewDecision.none => 'none',
};

String? _size(PullRequestSnapshot s) {
  final parts = [
    if (s.additions != null && s.deletions != null)
      '+${s.additions} −${s.deletions}',
    if (s.changedFiles != null) '${s.changedFiles} files',
    if (s.commits != null) '${s.commits} commits',
  ];
  return parts.isEmpty ? null : parts.join(', ');
}

String _failureReason(GitHubFailureKind kind) => switch (kind) {
  GitHubFailureKind.noToken => 'no GitHub token on this device',
  GitHubFailureKind.offline => 'GitHub could not be reached in time',
  GitHubFailureKind.unauthorized => 'the GitHub token was rejected',
  GitHubFailureKind.forbidden => 'the GitHub token lacks permission',
  GitHubFailureKind.rateLimited => 'GitHub rate limit reached',
  GitHubFailureKind.notFound => 'not found, or not visible to the token',
  GitHubFailureKind.server => 'GitHub reported an error',
  GitHubFailureKind.invalidResponse => 'GitHub sent an unreadable response',
};
