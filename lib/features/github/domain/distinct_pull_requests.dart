import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/pull_request_data.dart';

/// The live pull requests among [entries], one per pull request, by number.
///
/// Two devices that link the same pull request to a task before they sync
/// each create an entry, and sync keeps both. Every device keeps the one
/// with the lowest id, so they all show the same entry and refresh it; the
/// other stays stored, unseen, until the pull request is unlinked, which
/// removes both.
List<PullRequestEntry> distinctPullRequests(
  Iterable<PullRequestEntry> entries,
) {
  final byKey = <String, PullRequestEntry>{};
  for (final entry in entries) {
    if (entry.isDeleted) continue;
    final kept = byKey[entry.data.key];
    if (kept == null || entry.id.compareTo(kept.id) < 0) {
      byKey[entry.data.key] = entry;
    }
  }
  return byKey.values.toList()..sort((a, b) {
    final byNumber = a.data.number.compareTo(b.data.number);
    return byNumber != 0 ? byNumber : a.data.key.compareTo(b.data.key);
  });
}
