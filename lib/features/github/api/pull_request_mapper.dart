import 'package:lotti/classes/pull_request_data.dart';

/// Builds a [PullRequestSnapshot] from the REST responses one refresh reads.
///
/// [pull] is `GET /repos/{o}/{r}/pulls/{n}`; [checkRuns] is
/// `GET /repos/{o}/{r}/commits/{sha}/check-runs`, or null when the token may
/// not read them; [combinedStatus] is
/// `GET /repos/{o}/{r}/commits/{sha}/status`; [reviews] is
/// `GET /repos/{o}/{r}/pulls/{n}/reviews`, oldest first as GitHub returns it.
/// [observedAt] is the server time of the pull response.
///
/// Throws [FormatException] when a required field is missing or mistyped:
/// a response that does not look like GitHub's is a failed refresh, never a
/// snapshot with made-up defaults.
PullRequestSnapshot pullRequestSnapshotFrom({
  required Map<String, dynamic> pull,
  required Map<String, dynamic>? checkRuns,
  required Map<String, dynamic> combinedStatus,
  required List<dynamic> reviews,
  required DateTime observedAt,
}) {
  final head = _map(pull, 'head');
  final base = _map(pull, 'base');
  final user = pull['user'];
  return PullRequestSnapshot(
    observedAt: observedAt.toUtc(),
    title: _string(pull, 'title'),
    body: pull['body'] as String?,
    status: _status(pull),
    draft: pull['draft'] == true,
    htmlUrl: _string(pull, 'html_url'),
    headSha: _string(head, 'sha'),
    headRef: _string(head, 'ref'),
    baseRef: _string(base, 'ref'),
    authorLogin: user is Map<String, dynamic> ? user['login'] as String? : null,
    mergedAt: _date(pull['merged_at']),
    closedAt: _date(pull['closed_at']),
    mergeability: _mergeability(pull),
    checks: _checks(checkRuns, combinedStatus),
    reviews: _reviews(reviews, pull),
    additions: pull['additions'] as int?,
    deletions: pull['deletions'] as int?,
    changedFiles: pull['changed_files'] as int?,
    commits: pull['commits'] as int?,
  );
}

PullRequestStatus _status(Map<String, dynamic> pull) {
  if (pull['merged'] == true || pull['merged_at'] != null) {
    return PullRequestStatus.merged;
  }
  return switch (pull['state']) {
    'open' => PullRequestStatus.open,
    'closed' => PullRequestStatus.closed,
    final other => throw FormatException('unknown pull request state $other'),
  };
}

/// `mergeable` is null while GitHub computes it; `mergeable_state` explains
/// a false one. `unstable` (non-required checks failing) and `has_hooks` are
/// still mergeable as they stand.
PullRequestMergeability _mergeability(Map<String, dynamic> pull) {
  final mergeable = pull['mergeable'] as bool?;
  final state = pull['mergeable_state'] as String?;
  if (mergeable == false || state == 'dirty') {
    return PullRequestMergeability.conflicting;
  }
  return switch (state) {
    'behind' => PullRequestMergeability.behind,
    'blocked' => PullRequestMergeability.blocked,
    'clean' ||
    'unstable' ||
    'has_hooks' when mergeable ?? false => PullRequestMergeability.clean,
    _ => PullRequestMergeability.unknown,
  };
}

enum _Outcome { passed, failed, pending }

const _passingConclusions = {'success', 'neutral', 'skipped'};

/// Every check run and commit status on the head commit, rolled up: any
/// failure fails, else anything still running is pending. Without the check
/// runs ([checkRuns] null) nothing passes: a hidden run may be failing.
PullRequestChecks _checks(
  Map<String, dynamic>? checkRuns,
  Map<String, dynamic> combinedStatus,
) {
  final outcomes = <(String, _Outcome)>[
    if (checkRuns != null)
      for (final run in _list(
        checkRuns,
        'check_runs',
      ).cast<Map<String, dynamic>>())
        (
          _string(run, 'name'),
          run['status'] != 'completed'
              ? _Outcome.pending
              : _passingConclusions.contains(run['conclusion'])
              ? _Outcome.passed
              : _Outcome.failed,
        ),
    for (final status in _list(
      combinedStatus,
      'statuses',
    ).cast<Map<String, dynamic>>())
      (
        _string(status, 'context'),
        switch (status['state']) {
          'success' => _Outcome.passed,
          'pending' => _Outcome.pending,
          _ => _Outcome.failed,
        },
      ),
  ];
  int count(_Outcome o) => outcomes.where((e) => e.$2 == o).length;
  final failed = count(_Outcome.failed);
  final pending = count(_Outcome.pending);
  final passed = count(_Outcome.passed);
  return PullRequestChecks(
    rollup: failed > 0
        ? PullRequestCheckRollup.failing
        : pending > 0
        ? PullRequestCheckRollup.pending
        : passed > 0 && checkRuns != null
        ? PullRequestCheckRollup.passing
        : PullRequestCheckRollup.none,
    total: outcomes.length,
    passed: passed,
    failed: failed,
    pending: pending,
    failingNames: outcomes
        .where((e) => e.$2 == _Outcome.failed)
        .map((e) => e.$1)
        .take(PullRequestChecks.maxFailingNames)
        .toList(),
    checkRunsHidden: checkRuns == null ? true : null,
  );
}

/// Each reviewer's latest decisive review counts once; a dismissal clears
/// it, and comments decide nothing. Requested reviewers or teams who have
/// not decided make the decision pending: in an organisation the request
/// often names only a team, and `requested_reviewers` is then empty.
PullRequestReviews _reviews(List<dynamic> reviews, Map<String, dynamic> pull) {
  final latest = <String, String>{};
  for (final review in reviews.cast<Map<String, dynamic>>()) {
    final user = review['user'];
    if (user is! Map<String, dynamic>) continue;
    final login = _string(user, 'login');
    switch (review['state']) {
      case 'APPROVED' || 'CHANGES_REQUESTED':
        latest[login] = review['state'] as String;
      case 'DISMISSED':
        latest.remove(login);
    }
  }
  final approvals = latest.values.where((s) => s == 'APPROVED').length;
  final changes = latest.values.where((s) => s == 'CHANGES_REQUESTED').length;
  bool any(String key) => (pull[key] as List<dynamic>? ?? const []).isNotEmpty;
  final requested = any('requested_reviewers') || any('requested_teams');
  return PullRequestReviews(
    decision: changes > 0
        ? PullRequestReviewDecision.changesRequested
        : approvals > 0
        ? PullRequestReviewDecision.approved
        : requested
        ? PullRequestReviewDecision.pending
        : PullRequestReviewDecision.none,
    approvals: approvals,
    changesRequested: changes,
  );
}

Map<String, dynamic> _map(Map<String, dynamic> json, String key) =>
    switch (json[key]) {
      final Map<String, dynamic> value => value,
      _ => throw FormatException('missing object $key'),
    };

List<dynamic> _list(Map<String, dynamic> json, String key) =>
    switch (json[key]) {
      final List<dynamic> value => value,
      _ => throw FormatException('missing list $key'),
    };

String _string(Map<String, dynamic> json, String key) => switch (json[key]) {
  final String value => value,
  _ => throw FormatException('missing string $key'),
};

DateTime? _date(Object? value) =>
    value is String ? DateTime.parse(value).toUtc() : null;
