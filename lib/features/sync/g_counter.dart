import 'package:equatable/equatable.dart';
import 'package:lotti/features/sync/vector_clock.dart';

/// A grow-only counter (G-counter CRDT): a per-host map of monotonic counts
/// whose observable [value] is their **sum**. Merge is element-wise max, so an
/// increment made on any device is never lost regardless of sync order or
/// partitions — the convergence the whole-row LWW resolver (PR 2) cannot give a
/// *cumulative* field, which it resolves by picking one side and dropping the
/// other's increments.
///
/// Each device increments **its own host's** entry, so per-host entries are
/// disjoint and the max-merge across hosts equals the sum of all increments.
///
/// Structurally identical to a [VectorClock] — a `Map<String,int>` with
/// element-wise-max merge — so [merge] reuses [VectorClock.merge] rather than
/// re-implementing it. The difference is purely semantic: a G-counter's
/// observable quantity is the *sum* of entries, not a per-node causal offset.
class GCounter extends Equatable {
  const GCounter(this.byHost);

  /// The zero counter — usable as a `const` default (e.g. freezed `@Default`).
  const GCounter.empty() : byHost = const {};

  factory GCounter.fromJson(Map<String, dynamic> json) =>
      GCounter(Map<String, int>.from(json));

  /// Per-host counts. Each entry is grow-only; the total is [value].
  final Map<String, int> byHost;

  /// The counter's observable value: the sum of all per-host counts.
  int get value => byHost.values.fold(0, (sum, count) => sum + count);

  /// A new counter with [host]'s entry increased by [by] (default 1).
  GCounter increment(String host, [int by = 1]) =>
      GCounter({...byHost, host: (byHost[host] ?? 0) + by});

  /// Element-wise max with [other] — the CRDT join: idempotent, commutative,
  /// associative, and lossless (no increment is ever dropped). Delegates to
  /// [VectorClock.merge], which is exactly element-wise max over the host map.
  GCounter merge(GCounter other) => GCounter(
    VectorClock.merge(VectorClock(byHost), VectorClock(other.byHost)).vclock,
  );

  Map<String, dynamic> toJson() => byHost;

  @override
  List<Object?> get props => [byHost];

  @override
  String toString() => 'GCounter($byHost → $value)';
}
