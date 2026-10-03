import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/pull_request_data.dart';
import 'package:lotti/features/provenance/crypto/canonical_json.dart';
import 'package:lotti/features/sync/vector_clock.dart';

/// SHA-256 over the canonical JSON of [snapshot] without its `observedAt`,
/// `createdAt` and comment counts: equal for two observations of the same
/// state, whenever they were made. `createdAt` never differs between two
/// observations of one pull request; the counts are what a summary reads,
/// not what a task acts on. Leaving the fields out keeps the digest a
/// version without them computes.
///
/// It carries no recency. It only makes the observation order total, so
/// every device picks the same winner between two same-second observations.
String pullRequestSnapshotDigest(PullRequestSnapshot snapshot) {
  final plain =
      jsonDecode(jsonEncode(snapshot.toJson())) as Map<String, dynamic>
        ..remove('observedAt')
        ..remove('createdAt')
        ..remove('comments')
        ..remove('reviewComments');
  return sha256.convert(canonicalJsonBytes(plain)).toString();
}

/// Orders two observations of one pull request; positive when [a] is newer.
///
/// The key is `Key` in `specs/tla/PullRequestSnapshot.tla`: the server time
/// of the observation, then merged before anything else — a merge is final,
/// so within one second of `Date` resolution a merged observation is the
/// later one — then the digest. No observation (`null`) is older than any.
int comparePullRequestObservations(
  PullRequestSnapshot? a,
  PullRequestSnapshot? b,
) {
  if (a == null || b == null) {
    return (a == null ? 0 : 1) - (b == null ? 0 : 1);
  }
  final byTime = a.observedAt.compareTo(b.observedAt);
  if (byTime != 0) return byTime;
  final byMerged = _mergedRank(a) - _mergedRank(b);
  if (byMerged != 0) return byMerged;
  return pullRequestSnapshotDigest(a).compareTo(pullRequestSnapshotDigest(b));
}

/// Whether [stored] was certainly read after [own] (`LaterThan` in
/// `specs/tla/PullRequestSnapshot.tla`).
///
/// A task context uses its own refresh's observation, unless what is stored
/// is provably later: a later second of the server's `Date`, or the same
/// second and merged where [own] is not — a merge is final, so the merged
/// read came second. Within one second the digest that breaks ties in
/// [comparePullRequestObservations] says nothing about time, so the newest
/// by that order can be a read made before the context asked.
bool isProvablyLaterObservation(
  PullRequestSnapshot stored,
  PullRequestSnapshot own,
) {
  final storedSecond = _second(stored.observedAt);
  final ownSecond = _second(own.observedAt);
  if (storedSecond != ownSecond) return storedSecond > ownSecond;
  return stored.status == PullRequestStatus.merged &&
      own.status != PullRequestStatus.merged;
}

int _second(DateTime t) => t.toUtc().millisecondsSinceEpoch ~/ 1000;

int _mergedRank(PullRequestSnapshot s) =>
    s.status == PullRequestStatus.merged ? 1 : 0;

/// The row every device writes for two concurrent versions of one pull
/// request entry, whichever it held first (`Merge` in the model).
///
/// The newer observation wins; an unlink on either side survives, because
/// the unlink is the user's and the refresh only the app's; the clock is the
/// join of both. Both orders of the arguments give the same row, so a merge
/// needs no message back. Two deletions are not handed here: the journal
/// merges those for every entry type.
PullRequestEntry mergeConcurrentPullRequestVersions(
  PullRequestEntry a,
  PullRequestEntry b,
) {
  final bySnapshot = comparePullRequestObservations(
    a.data.snapshot,
    b.data.snapshot,
  );
  final winner = switch (bySnapshot) {
    > 0 => a,
    < 0 => b,
    // The same observation on both sides: any fixed rule will do, as long
    // as it does not depend on which side is stored.
    _ => _clockKey(a).compareTo(_clockKey(b)) >= 0 ? a : b,
  };
  return winner.copyWith(
    meta: winner.meta.copyWith(
      deletedAt: winner.meta.deletedAt ?? a.meta.deletedAt ?? b.meta.deletedAt,
      vectorClock: VectorClock.merge(a.meta.vectorClock, b.meta.vectorClock),
    ),
  );
}

String _clockKey(PullRequestEntry e) => e.meta.vectorClock?.canonicalKey ?? '';
