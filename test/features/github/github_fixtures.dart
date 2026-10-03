/// GitHub REST response bodies, trimmed to the fields the app reads.
library;

Map<String, dynamic> githubPullJson({
  String state = 'open',
  bool merged = false,
  String? mergedAt,
  bool? mergeable = true,
  String? mergeableState = 'clean',
  List<String> requestedReviewers = const [],
  List<String> requestedTeams = const [],
  String headSha = 'abc1234',
}) => {
  'number': 12,
  'title': 'Waddle faster',
  'body': 'Implements the waddle.',
  'state': state,
  'draft': false,
  'merged': merged,
  'merged_at': mergedAt,
  'closed_at': state == 'closed' ? '2024-03-15T11:00:00Z' : null,
  'html_url': 'https://github.com/penguin/colony/pull/12',
  'user': {'login': 'pingu'},
  'head': {'sha': headSha, 'ref': 'feat/waddle'},
  'base': {'ref': 'main'},
  'mergeable': mergeable,
  'mergeable_state': mergeableState,
  'requested_reviewers': [
    for (final login in requestedReviewers) {'login': login},
  ],
  'requested_teams': [
    for (final slug in requestedTeams) {'slug': slug},
  ],
  'additions': 10,
  'deletions': 2,
  'changed_files': 3,
  'commits': 4,
};

Map<String, dynamic> githubCheckRunsJson(List<Map<String, dynamic>> runs) => {
  'total_count': runs.length,
  'check_runs': runs,
};

Map<String, dynamic> githubCheckRunJson(
  String name, {
  String status = 'completed',
  String? conclusion,
}) => {'name': name, 'status': status, 'conclusion': conclusion};

Map<String, dynamic> githubCombinedStatusJson(
  List<Map<String, dynamic>> statuses,
) => {'state': 'pending', 'statuses': statuses};

Map<String, dynamic> githubStatusJson(String context, String state) => {
  'context': context,
  'state': state,
};

Map<String, dynamic> githubReviewJson(String login, String state) => {
  'user': {'login': login},
  'state': state,
};
