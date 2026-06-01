import 'package:equatable/equatable.dart';

/// One entry in the uncovered verbatim tail, with its approximate token cost.
/// Entries are supplied in chronological (canonical assembly) order.
class TailEntry extends Equatable {
  /// Creates a tail entry. [tokens] is a non-negative size estimate.
  const TailEntry({required this.id, required this.tokens});

  /// The source/event id this entry represents.
  final String id;

  /// Approximate token cost of rendering this entry verbatim.
  final int tokens;

  @override
  List<Object?> get props => [id, tokens];
}

/// The decision of [planCompaction]: which oldest prefix of the tail to fold
/// into a summary checkpoint, and which (most-recent) suffix to keep verbatim.
class CompactionPlan extends Equatable {
  /// Wraps a plan. Callers obtain instances from [planCompaction].
  const CompactionPlan({required this.foldIds, required this.keepIds});

  /// Tail entry ids to fold into the summary — the **oldest** prefix, in order.
  /// Empty when no compaction is needed.
  final List<String> foldIds;

  /// Tail entry ids kept verbatim — the **most-recent** suffix, in order.
  final List<String> keepIds;

  /// True when there is anything to fold.
  bool get shouldCompact => foldIds.isNotEmpty;

  @override
  List<Object?> get props => [foldIds, keepIds];
}

/// Plans compaction over the uncovered verbatim [tail] (chronological order)
/// against a token [budget] (ADR 0017): if the tail fits, nothing is folded;
/// otherwise the **oldest** entries are folded into the summary until the
/// kept, most-recent suffix fits the budget.
///
/// Pure function of its inputs. Guarantees:
/// - `foldIds` ++ `keepIds` is exactly the tail ids, order preserved
///   (a clean prefix/suffix split);
/// - `keepIds` is the longest most-recent suffix whose token sum is `<=`
///   [budget] — **except** that the single most-recent entry is always kept
///   even if it alone exceeds the budget (an atomic entry can't be split; ADR
///   0017 folds bounded sub-frontiers, never truncates an entry);
/// - a larger budget never folds more (monotonic).
///
/// A non-positive [budget] folds everything but the last entry.
CompactionPlan planCompaction({
  required List<TailEntry> tail,
  required int budget,
}) {
  if (tail.isEmpty) {
    return const CompactionPlan(foldIds: [], keepIds: []);
  }

  // Walk from the most-recent end, keeping entries while they fit. Always keep
  // the last entry (index tail.length - 1) regardless of budget.
  var kept = 0;
  var keptTokens = 0;
  for (var i = tail.length - 1; i >= 0; i--) {
    final isMostRecent = i == tail.length - 1;
    final next = keptTokens + tail[i].tokens;
    if (isMostRecent || next <= budget) {
      keptTokens = next;
      kept = tail.length - i;
    } else {
      break;
    }
  }

  final splitAt = tail.length - kept;
  return CompactionPlan(
    foldIds: [for (var i = 0; i < splitAt; i++) tail[i].id],
    keepIds: [for (var i = splitAt; i < tail.length; i++) tail[i].id],
  );
}
