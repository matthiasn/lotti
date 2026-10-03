import 'package:lotti/classes/pull_request_data.dart';
import 'package:lotti/features/github/domain/pull_request_ref.dart';
import 'package:meta/meta.dart';

/// How much of a description a summary is asked to read.
const pullRequestSummaryDescriptionLimit = 12000;

/// Upper bound on a summary's one-liner, in characters: the subtitle of the
/// pull request's row shows one line.
const pullRequestOneLinerMaxChars = 140;

/// Upper bound on a summary's TL;DR, in characters: a short paragraph.
const pullRequestTldrMaxChars = 1200;

/// The two tiers of a pull request summary.
@immutable
class PullRequestSummary {
  const PullRequestSummary({required this.oneLiner, required this.tldr});

  /// One sentence, the subtitle of the pull request in the task; null for a
  /// summary that has only a TL;DR.
  final String? oneLiner;

  /// A short paragraph: what the task's contexts and the details show.
  final String tldr;

  @override
  bool operator ==(Object other) =>
      other is PullRequestSummary &&
      other.oneLiner == oneLiner &&
      other.tldr == tldr;

  @override
  int get hashCode => Object.hash(oneLiner, tldr);

  @override
  String toString() => 'PullRequestSummary($oneLiner, $tldr)';
}

/// Whether [snapshot]'s pull request is history — merged, or closed without
/// merging — so a task context shows it in brief rather than in full. An
/// open pull request, draft or not, is the work in progress.
bool isSettledPullRequest(PullRequestSnapshot snapshot) =>
    snapshot.status != PullRequestStatus.open;

/// [text] on one line, cut at [limit] characters — for a summary from a
/// model that ignored its length, or that synced in from elsewhere.
String briefPullRequestSummary(
  String text, {
  int limit = pullRequestTldrMaxChars,
}) {
  final line = text.trim().replaceAll(RegExp(r'\s+'), ' ');
  return line.length > limit ? '${line.substring(0, limit)} …' : line;
}

/// What a summary of [ref] is written from: the pull request's content and
/// nothing about when it was read — its title, state, size, reviews, how
/// much discussion it saw, and its description. Prompt text, so English.
///
/// The text doubles as the summary's key: a summary stores it as its
/// `prompt`, and matches the pull request while the same text comes out of
/// its current snapshot. A restamp, or a change of checks or mergeability,
/// leaves it as it is, so none of them asks for a new summary; a new title,
/// description, state or review does. The discussion is given as a band
/// (`_discussion`), so one more comment does not ask either — only reaching
/// the next band does.
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
  final reviews = snapshot.reviews;
  final reviewed = [
    if (reviews.changesRequested > 0)
      'changes requested ${_times(reviews.changesRequested)}',
    if (reviews.approvals > 0) 'approved ${_times(reviews.approvals)}',
  ];
  final comments = snapshot.comments;
  final body = snapshot.body?.trim() ?? '';
  final shown = body.length > pullRequestSummaryDescriptionLimit
      ? '${body.substring(0, pullRequestSummaryDescriptionLimit)} … (truncated)'
      : body;
  final out = StringBuffer()
    ..writeln('Pull request: $ref')
    ..writeln('Title: ${snapshot.title}')
    ..writeln('State: ${_state(snapshot)}');
  if (size.isNotEmpty) out.writeln('Size: ${size.join(', ')}');
  if (reviewed.isNotEmpty) out.writeln('Reviews: ${reviewed.join(', ')}');
  if (comments != null) {
    out.writeln(
      'Discussion: ${_discussion(comments + (snapshot.reviewComments ?? 0))}',
    );
  }
  out
    ..writeln('Description:')
    ..write(shown.isEmpty ? '(none)' : shown);
  return out.toString();
}

String _state(PullRequestSnapshot s) => switch (s.status) {
  PullRequestStatus.merged => 'merged',
  PullRequestStatus.closed => 'closed without merging',
  PullRequestStatus.open => s.draft ? 'open, draft' : 'open',
};

String _times(int n) => n == 1 ? 'once' : '$n times';

/// How much was said, as a band: a summary says "a long discussion", not
/// "47 comments", and is not asked for again on every new comment.
String _discussion(int comments) => switch (comments) {
  0 => 'no comments',
  <= 5 => 'a few comments (1–5)',
  <= 20 => 'some discussion (6–20 comments)',
  <= 50 => 'a long discussion (21–50 comments)',
  _ => 'a very long discussion (over 50 comments)',
};
