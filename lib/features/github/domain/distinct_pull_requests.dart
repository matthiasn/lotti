import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/pull_request_data.dart';

/// The live pull requests among [entries], one per pull request, newest
/// first: by when each was opened on GitHub, the latest at the top, as GitHub
/// lists them. One whose opening is not known yet — never refreshed, or
/// stored before the snapshot carried it — comes after those, highest number
/// first, until a refresh tells.
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
    final aAt = a.data.snapshot?.createdAt;
    final bAt = b.data.snapshot?.createdAt;
    if (aAt != bAt) {
      if (aAt == null) return 1;
      if (bAt == null) return -1;
      return bAt.compareTo(aAt);
    }
    final byNumber = b.data.number.compareTo(a.data.number);
    return byNumber != 0 ? byNumber : a.data.key.compareTo(b.data.key);
  });
}
