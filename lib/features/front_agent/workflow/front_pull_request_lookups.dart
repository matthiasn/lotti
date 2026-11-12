import 'package:lotti/features/front_agent/model/front_pull_requests.dart';
import 'package:lotti/features/front_agent/model/front_routing_index.dart';
import 'package:lotti/features/front_agent/service/front_pull_request_finder.dart';
import 'package:lotti/features/front_agent/workflow/front_agent_contract.dart';
import 'package:lotti/features/front_agent/workflow/front_pull_request_filter.dart';

/// Every pull request opened or merged in one window of days through the
/// tasks inside the turn's scope, each with its task and summary: what
/// `find_pull_requests` filters.
typedef FrontPullRequestFinder =
    Future<FrontPullRequestCandidates> Function(FrontPullRequestQuery query);

/// Pull requests as the device last stored them, in full, for
/// `read_pull_requests`.
typedef FrontPullRequestReader =
    Future<String> Function(List<FrontFoundPullRequest> pullRequests);

/// What one pull request tool call is answered: what she is told, whether
/// the call was taken — a refused one is logged as an error — and the task
/// rows it showed her, which her reply may then link and show.
typedef FrontPullRequestAnswer = ({
  String response,
  bool accepted,
  List<FrontIndexRow> rows,
});

/// The pull request tools of one turn, `find_pull_requests` and
/// `read_pull_requests`, and what they found: the strategy hands them their
/// calls and takes their answers.
class FrontPullRequestLookups {
  FrontPullRequestLookups({
    required this.now,
    this.finder,
    this.filter,
    this.reader,
    this.conversationPullRequests = const [],
    this.onFilterFailed,
  });

  /// The turn's clock, which a window of days counts back from.
  final DateTime now;

  /// Null when no pull requests are wired (tests, evals): searching is
  /// then unavailable.
  final FrontPullRequestFinder? finder;

  /// The isolated call that keeps, of the candidates, those about the
  /// topic; null when none is wired, which makes the search unavailable.
  final FrontPullRequestFilter? filter;

  /// Null when no pull requests are wired: reading is then unavailable.
  final FrontPullRequestReader? reader;

  /// The pull requests this conversation showed as cards, as
  /// `<conversation_pull_requests>` listed them.
  final List<FrontFoundPullRequest> conversationPullRequests;

  /// Told the filter call failed, with what failed: for the log, never the
  /// user's words.
  final void Function(Object error)? onFilterFailed;

  int _finds = 0;
  int _reads = 0;
  List<FrontFoundPullRequest> _found = const [];

  /// How many calls were taken this turn.
  int get calls => _finds + _reads;

  /// What `find_pull_requests` kept as about its topic this turn; empty
  /// when none ran or it kept none.
  List<FrontFoundPullRequest> get found => _found;

  /// What her reply may show and `read_pull_requests` may read, by key:
  /// what the conversation showed and what was found this turn.
  Map<String, FrontFoundPullRequest> get shown =>
      frontPullRequestsByKey([...conversationPullRequests, ..._found]);

  static FrontPullRequestAnswer _refused(String response) =>
      (response: response, accepted: false, rows: const []);

  /// Answers `find_pull_requests`: the candidates of its window go to the
  /// filter, a call apart from her conversation, and only those it keeps
  /// come back to her, with their tasks.
  Future<FrontPullRequestAnswer> find(Map<String, dynamic> args) async {
    if (_finds >= frontPullRequestFindsPerTurn) {
      return _refused(frontPullRequestFindExhaustedAnswer);
    }
    final topic = args['topic'] is String
        ? (args['topic'] as String).trim()
        : '';
    final query = frontPullRequestQuery(args, now);
    if (topic.isEmpty || query == null) {
      return _refused(
        'Error: find_pull_requests needs a topic and exactly one of: period '
        '(one of ${FrontTimePeriod.values.map((p) => p.wireName).join(', ')}'
        '), pastDays (1 to $frontPullRequestMaxDays), or from and through '
        '(YYYY-MM-DD, at most $frontPullRequestMaxDays days).',
      );
    }
    final finder = this.finder;
    final filter = this.filter;
    if (finder == null || filter == null) {
      return _refused(
        'Pull requests cannot be searched this turn; say so in your answer.',
      );
    }
    _finds++;
    final (:range, pullRequests: candidates) = await finder(query);
    final List<String> keys;
    try {
      keys = candidates.isEmpty ? const [] : await filter(topic, candidates);
    } catch (error) {
      onFilterFailed?.call(error);
      return _refused(
        'The pull request search failed this turn; say so in your answer.',
      );
    }
    final byKey = frontPullRequestsByKey(candidates);
    _found = [for (final key in keys) ?byKey[key]];
    return (
      response: renderFrontFoundPullRequests(
        topic: topic,
        range: range,
        searched: candidates.length,
        found: _found,
      ),
      accepted: true,
      rows: frontPullRequestTasks(_found),
    );
  }

  /// Answers `read_pull_requests`: each pull request it names, of those
  /// [shown], as last stored.
  Future<FrontPullRequestAnswer> read(Map<String, dynamic> args) async {
    if (_reads >= frontPullRequestReadsPerTurn) {
      return _refused(frontPullRequestReadExhaustedAnswer);
    }
    final ids = args['ids'];
    final shown = this.shown;
    final pullRequests = [
      if (ids is List)
        for (final id in ids)
          if (id is String) ?shown[id.trim()],
    ];
    if (ids is! List ||
        ids.isEmpty ||
        pullRequests.length != ids.length ||
        ids.length > frontPullRequestIdsPerRead) {
      return _refused(
        'Error: ids names 1 to $frontPullRequestIdsPerRead pull requests, '
        'each owner/repo#number as listed under <conversation_pull_requests> '
        'or found this turn.',
      );
    }
    final reader = this.reader;
    if (reader == null) {
      return _refused(
        'Pull requests are unavailable this turn; say so in your answer.',
      );
    }
    _reads++;
    final details = await reader(pullRequests);
    return (
      response: details.isEmpty
          ? 'Nothing is stored for them any more.'
          : details,
      accepted: true,
      rows: frontPullRequestTasks(pullRequests),
    );
  }
}
