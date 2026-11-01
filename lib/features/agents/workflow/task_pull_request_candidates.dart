import 'dart:convert';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/model/pull_request_link_source.dart';

/// One unlinked pull request ranked against the task.
class TaskPullRequestCandidate {
  const TaskPullRequestCandidate({
    required this.pullRequest,
    required this.score,
    required this.sharedTerms,
  });

  final UnlinkedPullRequest pullRequest;

  /// How strongly its words match the task's: the summed rarity of the task
  /// terms it shares, a term in its title or branch counting more than one in
  /// its description. Zero when it shares none.
  final double score;

  /// The task terms it shares, strongest first.
  final List<String> sharedTerms;

  /// The entry `get_unlinked_pull_requests` reports for this pull request.
  Map<String, Object?> toToolJson(DateTime now) {
    final pr = pullRequest;
    final excerpt = descriptionExcerpt(pr.body);
    return {
      'number': pr.number,
      'title': pr.title,
      'branch': ?pr.headRef,
      if (pr.labels.isNotEmpty) 'labels': pr.labels,
      'author': ?pr.authorLogin,
      if (pr.draft) 'draft': true,
      'openedDaysAgo': math.max(0, now.difference(pr.createdAt).inDays),
      'sharedTaskTerms': sharedTerms,
      'matchScore': double.parse(score.toStringAsFixed(1)),
      if (excerpt.isNotEmpty) 'description': excerpt,
    };
  }
}

/// What `get_unlinked_pull_requests` read for one wake: the ranked
/// candidates of [repository], or why there are none to read.
class TaskPullRequestListing {
  const TaskPullRequestListing({
    required String this.repository,
    required this.candidates,
  }) : unavailableReason = null;

  const TaskPullRequestListing.unavailable(String this.unavailableReason)
    : repository = null,
      candidates = const [];

  /// `owner/repo`; null when nothing could be listed.
  final String? repository;

  /// Every unlinked open pull request, best match first.
  final List<TaskPullRequestCandidate> candidates;

  /// Why nothing could be listed, as an English sentence.
  final String? unavailableReason;

  /// The candidate numbered [number], or null when it is not one: linked by
  /// now, closed, or invented.
  TaskPullRequestCandidate? byNumber(int number) {
    for (final candidate in candidates) {
      if (candidate.pullRequest.number == number) return candidate;
    }
    return null;
  }
}

/// How many candidates the tool response shows, so a busy repository cannot
/// flood the wake. A proposal may still name any unlinked pull request.
const maxListedPullRequestCandidates = 10;

/// How much of a description the tool response shows.
const pullRequestExcerptLength = 300;

/// [taskId]'s unlinked pull requests from [source], ranked against the task's
/// title and description, which are read from [journalDb] and never leave
/// the device: GitHub is asked only for the repository's list.
Future<TaskPullRequestListing> loadTaskPullRequestListing({
  required String taskId,
  required JournalDb journalDb,
  required PullRequestLinkSource source,
}) async {
  switch (await source.unlinkedFor(taskId)) {
    case UnlinkedPullRequestsUnavailable(:final reason):
      return TaskPullRequestListing.unavailable(reason);
    case UnlinkedPullRequestsListed(:final repository, :final pullRequests):
      final task = await journalDb.journalEntityById(taskId);
      final taskText = task is Task
          ? '${task.data.title}\n${task.entryText?.plainText ?? ''}'
          : '';
      return TaskPullRequestListing(
        repository: repository,
        candidates: rankPullRequestsForTask(
          taskText: taskText,
          pullRequests: pullRequests,
        ),
      );
  }
}

/// [pullRequests] ranked by how well their words match [taskText], best
/// first; equal scores keep the newest first.
///
/// Keyword overlap weighted by rarity: a task term shared by one pull request
/// tells more than one shared by all of them. It only orders and annotates
/// the list — the agent judges the match from the titles and descriptions,
/// so a task written in another language than its pull request still finds
/// it, unannotated.
List<TaskPullRequestCandidate> rankPullRequestsForTask({
  required String taskText,
  required List<UnlinkedPullRequest> pullRequests,
}) {
  final taskTerms = matchTerms(taskText);
  final fieldTerms = [
    for (final pr in pullRequests)
      (
        title: matchTerms(pr.title),
        branch: matchTerms(pr.headRef ?? ''),
        labels: matchTerms(pr.labels.join(' ')),
        body: matchTerms(pr.body),
      ),
  ];
  final documentFrequency = <String, int>{};
  for (final fields in fieldTerms) {
    for (final term in {
      ...fields.title,
      ...fields.branch,
      ...fields.labels,
      ...fields.body,
    }) {
      if (taskTerms.contains(term)) {
        documentFrequency.update(term, (n) => n + 1, ifAbsent: () => 1);
      }
    }
  }

  final ranked = <TaskPullRequestCandidate>[];
  for (final (index, pr) in pullRequests.indexed) {
    final fields = fieldTerms[index];
    final weights = <String, double>{};
    for (final term in taskTerms) {
      final fieldWeight = fields.title.contains(term)
          ? 3
          : fields.branch.contains(term) || fields.labels.contains(term)
          ? 2
          : fields.body.contains(term)
          ? 1
          : 0;
      if (fieldWeight == 0) continue;
      final rarity = math.log(
        1 + pullRequests.length / documentFrequency[term]!,
      );
      weights[term] = fieldWeight * rarity;
    }
    final shared = weights.keys.toList()
      ..sort((a, b) {
        final byWeight = weights[b]!.compareTo(weights[a]!);
        return byWeight != 0 ? byWeight : a.compareTo(b);
      });
    ranked.add(
      TaskPullRequestCandidate(
        pullRequest: pr,
        score: weights.values.fold(0, (sum, w) => sum + w),
        sharedTerms: shared,
      ),
    );
  }
  return ranked..sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    final byCreated = b.pullRequest.createdAt.compareTo(
      a.pullRequest.createdAt,
    );
    return byCreated != 0
        ? byCreated
        : b.pullRequest.number.compareTo(a.pullRequest.number);
  });
}

/// The words of [text] that can tell one piece of work from another: lower
/// case, at least three letters or digits, without common function words and
/// pull request boilerplate, a plain plural folded into its singular.
Set<String> matchTerms(String text) => {
  for (final match in _word.allMatches(text.toLowerCase()))
    if (_term(match.group(0)!) case final String term) term,
};

final _word = RegExp(r'[\p{L}\p{N}]+', unicode: true);

String? _term(String word) {
  if (word.length < 3 || _stopWords.contains(word)) return null;
  final singular = word.length > 4 && word.endsWith('s') && !word.endsWith('ss')
      ? word.substring(0, word.length - 1)
      : word;
  return _stopWords.contains(singular) ? null : singular;
}

const _stopWords = <String>{
  // English function words.
  'the', 'and', 'for', 'with', 'that', 'this', 'from', 'into', 'are', 'was',
  'were', 'but', 'not', 'its', 'his', 'her', 'our', 'you', 'your', 'can',
  'will', 'has', 'have', 'had', 'what', 'when', 'where', 'which', 'who',
  'why', 'how', 'all', 'any', 'one', 'out', 'now', 'more', 'than', 'then',
  'them', 'they', 'there', 'their', 'each', 'only', 'also', 'onto', 'over',
  'via', 'per', 'own', 'too', 'very', 'just', 'like', 'make', 'new',
  // German function words.
  'der', 'die', 'das', 'und', 'mit', 'für', 'von', 'den', 'dem', 'des',
  'ein', 'eine', 'einen', 'ist', 'sind', 'auf', 'aus', 'bei', 'nicht',
  'auch', 'noch', 'wie', 'wenn', 'oder', 'aber', 'nach', 'zum', 'zur',
  // Pull request boilerplate.
  'feat', 'fix', 'chore', 'refactor', 'doc', 'docs', 'test', 'perf', 'pull',
  'request', 'summary', 'change', 'http', 'https', 'www', 'com', 'github',
};

/// [body] as a short plain excerpt: HTML comments, images and tags dropped,
/// whitespace collapsed, cut at [pullRequestExcerptLength] characters.
String descriptionExcerpt(String body) {
  final plain = body
      .replaceAll(_htmlComment, ' ')
      .replaceAll(_markdownImage, ' ')
      .replaceAll(_htmlTag, ' ')
      .replaceAll(_whitespace, ' ')
      .trim();
  if (plain.length <= pullRequestExcerptLength) return plain;
  return '${plain.substring(0, pullRequestExcerptLength).trimRight()}…';
}

final _htmlComment = RegExp('<!--.*?-->', dotAll: true);
final _markdownImage = RegExp(r'!\[[^\]]*\]\([^)]*\)');
final _htmlTag = RegExp('<[^>]+>');
final _whitespace = RegExp(r'\s+');

/// The `get_unlinked_pull_requests` response for [listing].
String renderTaskPullRequestListing(TaskPullRequestListing listing) {
  final repository = listing.repository;
  if (repository == null) {
    return 'The pull requests could not be listed: '
        '${listing.unavailableReason} Do not call link_pull_request.';
  }
  if (listing.candidates.isEmpty) {
    return 'Every open pull request of $repository is linked to a task '
        'already, or there is none. Do not call link_pull_request.';
  }
  final now = clock.now();
  final listed = listing.candidates
      .take(maxListedPullRequestCandidates)
      .toList();
  return const JsonEncoder.withIndent('  ').convert({
    'repository': repository,
    'unlinkedOpenPullRequests': listing.candidates.length,
    if (listed.length < listing.candidates.length)
      'shown': '${listed.length} best matches',
    'pullRequests': [for (final c in listed) c.toToolJson(now)],
  });
}
