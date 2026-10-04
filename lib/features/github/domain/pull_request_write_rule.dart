import 'package:lotti/classes/github/pull_request_order.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/pull_request_data.dart';

/// How old a stored stamp may grow before an unchanged observation is
/// written anyway, so the entry's age stays honest on other devices.
const pullRequestRestampAfter = Duration(hours: 1);

/// Whether [observation] replaces what [stored] holds (`Persist` in
/// `specs/tla/PullRequestSnapshot.tla`).
///
/// Never over an unlinked entry, never an observation that is not newer, and
/// only a changed snapshot — or the same one once the stored stamp is
/// [restampAfter] old. Every write notifies the task, so writing on every
/// refresh would wake the task agent whose context asked for the refresh.
///
/// A snapshot stored before it carried `createdAt`, or the comment counts,
/// counts as changed once a read brings them: the digest leaves them out, so
/// without this the opening would stay unstored — the age and order shown
/// only on the screen that refreshed — and the counts unknown to a summary,
/// until the stamp grew an hour old.
bool shouldWritePullRequestObservation(
  PullRequestEntry stored,
  PullRequestSnapshot observation, {
  Duration restampAfter = pullRequestRestampAfter,
}) {
  if (stored.isDeleted) return false;
  final current = stored.data.snapshot;
  if (comparePullRequestObservations(observation, current) <= 0) return false;
  return current == null ||
      (current.createdAt == null && observation.createdAt != null) ||
      (current.comments == null && observation.comments != null) ||
      pullRequestSnapshotDigest(current) !=
          pullRequestSnapshotDigest(observation) ||
      observation.observedAt.difference(current.observedAt) >= restampAfter;
}
