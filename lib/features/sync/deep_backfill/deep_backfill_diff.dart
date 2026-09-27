import 'package:lotti/features/sync/vector_clock.dart';

/// What one inventory batch asks of the device that diffs it.
///
/// This is `Diff` of `specs/tla/DeepBackfill.tla`, computed in memory from a
/// single range read of the local rows: the model's `Wanted` decides
/// [requests], its `Owes` and `OwedConflicts` decide [pushes].
class DeepBackfillDiff {
  const DeepBackfillDiff({
    required this.requests,
    required this.absentLocally,
    required this.pushes,
    required this.advertiserLacks,
    required this.incomparable,
  });

  /// Records to request from the advertiser, each with the advertised
  /// versions the request asks for: the advertiser's row, and any of its open
  /// conflict versions this device does not keep. The request is settled
  /// once every one of them is covered here.
  final Map<String, List<VectorClock>> requests;

  /// The requested records this device holds no row for at all: their
  /// answers carry media, since nothing of the entry is here yet.
  final Set<String> absentLocally;

  /// Records whose row, or an open conflict version, the advertiser does not
  /// keep: they are sent back to it.
  final Set<String> pushes;

  /// The pushed records the advertiser holds no row for: their pushes carry
  /// media.
  final Set<String> advertiserLacks;

  /// Records whose clocks could not be compared (a malformed counter). They
  /// are neither requested nor pushed, and are reported instead.
  final Set<String> incomparable;
}

/// `b` is `a` or a newer version of it.
bool vectorClockCovers(VectorClock a, VectorClock b) {
  final status = VectorClock.compare(a, b);
  return status == VclockStatus.equal || status == VclockStatus.b_gt_a;
}

/// Whether a request that asked for [asked] is settled by what this device
/// now holds: for every version asked for, the row or one of the record's
/// open conflicts is that version or a newer one. Coverage, not the sender,
/// settles a request: nothing on the wire ties an answer to the request it
/// answers (the model's `ClearOnlyCovered`). An empty clock asks for a row
/// the advertiser holds without one, and any row settles it.
bool deepBackfillRequestSettled({
  required Iterable<VectorClock> asked,
  required bool holdsRow,
  required VectorClock? local,
  required Iterable<VectorClock> openConflicts,
}) => asked.every(
  (version) =>
      version.vclock.isEmpty ? holdsRow : _keeps(local, openConflicts, version),
);

/// What a request for a row the advertiser holds without a clock asks for.
const VectorClock unclockedVersion = VectorClock(<String, int>{});

/// Diffs one inventory batch against this device's rows in the batch's
/// range.
///
/// - [advertised]: the advertiser's rows in the range, id to clock.
/// - [advertisedConflicts]: the advertiser's open conflict versions there.
/// - [advertisedUnclocked]: ids the advertiser holds without a clock. They
///   are never pushed back as if the advertiser lacked them, and are asked
///   for only where this device holds no row at all: a clockless copy cannot
///   be ordered against another one.
/// - [local]: this device's rows in the same range; a null clock is a row
///   written before clocks existed.
/// - [localConflicts]: this device's open conflict versions there.
/// - [outstanding]: records already requested from this advertiser and not
///   yet settled — they are not requested again.
DeepBackfillDiff diffDeepBackfillBatch({
  required Map<String, VectorClock> advertised,
  required Map<String, List<VectorClock>> advertisedConflicts,
  required Map<String, VectorClock?> local,
  required Map<String, List<VectorClock>> localConflicts,
  required Set<String> outstanding,
  Set<String> advertisedUnclocked = const {},
}) {
  final requests = <String, List<VectorClock>>{};
  final absentLocally = <String>{};
  final pushes = <String>{};
  final advertiserLacks = <String>{};
  final incomparable = <String>{};

  final ids = {
    ...advertised.keys,
    ...advertisedConflicts.keys,
    ...local.keys,
    ...localConflicts.keys,
  };
  for (final id in advertisedUnclocked) {
    if (advertised.containsKey(id) || local.containsKey(id)) continue;
    if (!outstanding.contains(id)) {
      requests[id] = const [unclockedVersion];
      absentLocally.add(id);
    }
  }
  for (final id in ids) {
    // Held by the advertiser without a clock: nothing orders the two copies,
    // so nothing is sent either way (absence was handled above).
    if (advertisedUnclocked.contains(id) && !advertised.containsKey(id)) {
      continue;
    }
    final theirs = advertised[id];
    final theirConflicts = advertisedConflicts[id] ?? const <VectorClock>[];
    final holdsRow = local.containsKey(id);
    final mine = local[id];
    final myConflicts = localConflicts[id] ?? const <VectorClock>[];
    final asked = <VectorClock>[];
    var push = false;

    try {
      if (theirs != null) {
        if (!holdsRow || mine == null) {
          // No row, or one written before clocks: a clocked version replaces
          // it, and the reverse is refused, so it is never pushed.
          asked.add(theirs);
        } else {
          switch (VectorClock.compare(mine, theirs)) {
            case VclockStatus.equal:
              break;
            case VclockStatus.b_gt_a:
              asked.add(theirs);
            case VclockStatus.a_gt_b:
              push = true;
            case VclockStatus.concurrent:
              // Skip what this device already holds as an open conflict, and
              // what the advertiser does: otherwise the pair travels every
              // round.
              if (!myConflicts.any((c) => vectorClockCovers(theirs, c))) {
                asked.add(theirs);
              }
              if (!theirConflicts.any((h) => vectorClockCovers(mine, h))) {
                push = true;
              }
          }
        }
      } else if (holdsRow) {
        // The range says the advertiser would have listed it.
        push = true;
        advertiserLacks.add(id);
      }

      // Conflict versions travel like rows: one held on a single device
      // would otherwise never reach a third, whose row equals the others'.
      for (final conflict in theirConflicts) {
        if (!_keeps(mine, myConflicts, conflict)) asked.add(conflict);
      }
      for (final conflict in myConflicts) {
        if (!_keeps(theirs, theirConflicts, conflict)) push = true;
      }
    } on VclockException {
      incomparable.add(id);
      continue;
    }

    if (push) pushes.add(id);
    if (asked.isNotEmpty && !outstanding.contains(id)) {
      requests[id] = asked;
      if (!holdsRow) absentLocally.add(id);
    }
  }

  return DeepBackfillDiff(
    requests: requests,
    absentLocally: absentLocally,
    pushes: pushes,
    advertiserLacks: advertiserLacks,
    incomparable: incomparable,
  );
}

/// [row] or one of [conflicts] is [version] or newer. A malformed clock
/// keeps nothing.
bool _keeps(
  VectorClock? row,
  Iterable<VectorClock> conflicts,
  VectorClock version,
) {
  try {
    if (row != null && vectorClockCovers(version, row)) return true;
    return conflicts.any((c) => vectorClockCovers(version, c));
  } on VclockException {
    return false;
  }
}
