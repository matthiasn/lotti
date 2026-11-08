import 'package:lotti/database/database.dart';
import 'package:lotti/features/front_agent/model/front_pull_requests.dart';
import 'package:lotti/features/insights/logic/time_bucketing.dart';
import 'package:lotti/utils/day_agent_capture_helpers.dart';

/// The pull requests [chart] counts — opened or merged in its days, newest
/// opened first — and how many in its scope are undated, read from what
/// the device stores: GitHub is never asked.
///
/// A pull request counts once, however many tasks hold it, when one of
/// them is inside the scope: not deleted, not private while private entries
/// are hidden, not in a private category while those are — a task need not
/// be private itself to sit in one — and in the scope's categories. When
/// the chart names the user's login, a pull request someone else opened
/// does not count; one not refreshed since it was linked has no author yet
/// and does. One whose opening is not stored counts when it was merged in
/// the days, and is otherwise `undated`.
Future<({List<FrontPullRequest> pullRequests, int undated})>
readFrontPullRequests(JournalDb journalDb, FrontPullRequestChart chart) async {
  final visible = {
    for (final category in await journalDb.getAllCategories()) category.id,
  };
  final hidden = {
    for (final category in await journalDb.getAllCategoriesIncludingPrivate())
      if (!visible.contains(category.id)) category.id,
  };
  final login = chart.authorLogin?.toLowerCase();
  final range = chart.range;
  bool inRange(DateTime? at) {
    if (at == null) return false;
    final day = epochDay(at.toLocal());
    return day >= range.startDay && day < range.endDayExclusive;
  }

  final seen = <String>{};
  final pullRequests = <FrontPullRequest>[];
  var undated = 0;
  // Ordered by entry id, so two devices' entries of one pull request
  // resolve to the one every device shows (`distinctPullRequests`).
  for (final row in await journalDb.pullRequestStatRows()) {
    if (seen.contains(row.key) ||
        hidden.contains(row.taskCategoryId) ||
        !categoryAllowed(row.taskCategoryId, chart.categoryIds)) {
      continue;
    }
    final author = row.authorLogin?.toLowerCase();
    if (login != null && author != null && author != login) continue;
    seen.add(row.key);
    final createdAt = row.createdAt;
    if (!inRange(createdAt) && !inRange(row.mergedAt)) {
      // Stored before the snapshot carried its opening: no day can count
      // it as opened. A merge inside the days still counts as shipped.
      if (createdAt == null) undated++;
      continue;
    }
    pullRequests.add(
      FrontPullRequest(
        key: row.key,
        title: row.title ?? '',
        createdAt: createdAt,
        mergedAt: row.mergedAt,
        additions: row.additions,
        deletions: row.deletions,
      ),
    );
  }
  // Newest opened first; one whose opening is not known last.
  pullRequests.sort((a, b) {
    final aAt = a.createdAt;
    final bAt = b.createdAt;
    if (aAt == null || bAt == null) {
      return (aAt == null ? 1 : 0) - (bAt == null ? 1 : 0);
    }
    return bAt.compareTo(aAt);
  });
  return (pullRequests: pullRequests, undated: undated);
}
