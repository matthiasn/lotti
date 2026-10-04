import 'dart:convert';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/pull_request_data.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/features/github/service/pull_request_summary_tool.dart';
import 'package:openai_dart/openai_dart.dart';

/// The instant every fixture observation is offset from.
final DateTime prFixtureEpoch = DateTime.utc(2026, 3, 15, 12);

/// A snapshot of pull request `matthiasn/lotti#42`, observed [second] seconds
/// after [prFixtureEpoch], opened at [createdAt] — the epoch itself unless
/// given. A snapshot stored before it carried the opening is
/// `prSnapshot().copyWith(createdAt: null)`.
PullRequestSnapshot prSnapshot({
  int second = 0,
  DateTime? createdAt,
  PullRequestStatus status = PullRequestStatus.open,
  String title = 'Track pull requests',
  String headSha = 'aaaaaaa',
  PullRequestCheckRollup checks = PullRequestCheckRollup.pending,
}) => PullRequestSnapshot(
  observedAt: prFixtureEpoch.add(Duration(seconds: second)),
  createdAt: createdAt ?? prFixtureEpoch,
  title: title,
  status: status,
  htmlUrl: 'https://github.com/matthiasn/lotti/pull/42',
  headSha: headSha,
  headRef: 'feat/pr-tracking',
  baseRef: 'main',
  checks: PullRequestChecks(rollup: checks),
);

/// Pull request entry [id] holding [snapshot] under [clock].
PullRequestEntry prEntry({
  required Map<String, int> clock,
  PullRequestSnapshot? snapshot,
  bool deleted = false,
  String id = 'pull-request-entry',
}) => PullRequestEntry(
  meta: Metadata(
    id: id,
    createdAt: prFixtureEpoch,
    updatedAt: prFixtureEpoch,
    dateFrom: prFixtureEpoch,
    dateTo: prFixtureEpoch,
    vectorClock: VectorClock(clock),
    deletedAt: deleted ? prFixtureEpoch : null,
  ),
  data: PullRequestData(
    owner: 'matthiasn',
    repo: 'lotti',
    number: 42,
    snapshot: snapshot,
  ),
);

/// The call a model makes to publish a pull request summary, with
/// [arguments] verbatim when given, else [oneLiner] and [tldr] as JSON.
ChatCompletionMessageToolCall summaryToolCall({
  String oneLiner = 'Tracks pull requests on tasks.',
  String tldr =
      'Links pull requests to tasks and refreshes them from GitHub. Merged '
      'after one round of requested changes.',
  String? arguments,
  String name = pullRequestSummaryToolName,
}) => ChatCompletionMessageToolCall(
  id: 'call-1',
  type: ChatCompletionMessageToolCallType.function,
  function: ChatCompletionMessageFunctionCall(
    name: name,
    arguments: arguments ?? jsonEncode({'oneLiner': oneLiner, 'tldr': tldr}),
  ),
);
