import 'package:lotti/classes/pull_request_data.dart';
import 'package:lotti/features/github/domain/pull_request_ref.dart';

/// How much of a description a summary is asked to read.
const pullRequestSummaryDescriptionLimit = 12000;

/// How long a summary may be, stored or shown, should a model ignore the
/// length it was asked for.
const pullRequestSummaryLimit = 600;

/// [summary] on one line, cut at [pullRequestSummaryLimit].
String briefPullRequestSummary(String summary) {
  final line = summary.trim().replaceAll(RegExp(r'\s+'), ' ');
  return line.length > pullRequestSummaryLimit
      ? '${line.substring(0, pullRequestSummaryLimit)} …'
      : line;
}

/// Whether [snapshot]'s pull request is history — merged, or closed without
/// merging — so a task context shows it as a short summary rather than in
/// full. An open pull request, draft or not, is the work in progress.
bool isSettledPullRequest(PullRequestSnapshot snapshot) =>
    snapshot.status != PullRequestStatus.open;

/// What a summary of [ref] is written from: the pull request's content and
/// nothing about when it was read — its title, outcome, size and
/// description. Prompt text, so English.
///
/// The text doubles as the summary's key: a summary stores it as its
/// `prompt`, and matches the pull request while the same text comes out of
/// its current snapshot. A restamp or a change of checks, reviews or
/// mergeability leaves it as it is, so none of them asks for a new summary;
/// a retitled or re-described pull request does.
String pullRequestSummaryInput(
  PullRequestRef ref,
  PullRequestSnapshot snapshot,
) {
  final size = [
    if (snapshot.additions != null && snapshot.deletions != null)
      '+${snapshot.additions} −${snapshot.deletions}',
    if (snapshot.changedFiles != null) '${snapshot.changedFiles} files',
    if (snapshot.commits != null) '${snapshot.commits} commits',
  ];
  final body = snapshot.body?.trim() ?? '';
  final shown = body.length > pullRequestSummaryDescriptionLimit
      ? '${body.substring(0, pullRequestSummaryDescriptionLimit)} … (truncated)'
      : body;
  final out = StringBuffer()
    ..writeln('Pull request: $ref')
    ..writeln('Title: ${snapshot.title}')
    ..writeln('Outcome: ${_outcome(snapshot.status)}');
  if (size.isNotEmpty) out.writeln('Size: ${size.join(', ')}');
  out
    ..writeln('Description:')
    ..write(shown.isEmpty ? '(none)' : shown);
  return out.toString();
}

String _outcome(PullRequestStatus status) => switch (status) {
  PullRequestStatus.merged => 'merged',
  PullRequestStatus.closed => 'closed without merging',
  PullRequestStatus.open => 'open',
};
