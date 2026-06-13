// Tests for outbox retention pruning (`lib/database/sync_db_outbox_prune.dart`).
import 'package:glados/glados.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';

import 'sync_db_test_utils.dart';

/// Position of a row's `updated_at` relative to the prune cutoff.
/// `pruneSentOutboxItemsChunked` deletes rows where
/// `updated_at < cutoff`, so `atCutoff` rows are intentionally kept —
/// the strict-less-than is the bit the property test exercises.
enum GeneratedOutboxAge { fresh, atCutoff, old }

class PruneRowSpec {
  const PruneRowSpec({
    required this.status,
    required this.age,
  });

  final GeneratedOutboxStatus status;
  final GeneratedOutboxAge age;

  /// Only `(sent, old)` rows are eligible for pruning. Live state
  /// (pending / sending) is never touched regardless of age, error
  /// rows are forensic and kept forever, fresh/atCutoff sent rows are
  /// inside the retention window.
  bool isPrunable({required Duration retention, required DateTime now}) {
    return status == GeneratedOutboxStatus.sent &&
        age == GeneratedOutboxAge.old;
  }

  /// `expiredSending` and `activeSending` both map to the
  /// `OutboxStatus.sending` literal in the table — the prune predicate
  /// only inspects `status` and `updated_at`, so this collapse loses no
  /// information.
  OutboxStatus get dbStatus => switch (status) {
    GeneratedOutboxStatus.pending => OutboxStatus.pending,
    GeneratedOutboxStatus.expiredSending => OutboxStatus.sending,
    GeneratedOutboxStatus.activeSending => OutboxStatus.sending,
    GeneratedOutboxStatus.sent => OutboxStatus.sent,
    GeneratedOutboxStatus.error => OutboxStatus.error,
  };

  DateTime updatedAtValue({
    required Duration retention,
    required DateTime now,
  }) {
    final cutoff = now.subtract(retention);
    return switch (age) {
      GeneratedOutboxAge.fresh => now.subtract(const Duration(hours: 1)),
      GeneratedOutboxAge.atCutoff => cutoff,
      GeneratedOutboxAge.old => cutoff.subtract(const Duration(days: 1)),
    };
  }

  @override
  String toString() => 'PruneRowSpec(status: $status, age: $age)';
}

class PruneScenario {
  const PruneScenario({
    required this.rows,
    required this.chunkSize,
    required this.retentionDays,
  });

  static final now = DateTime(2026, 5, 9, 12);

  final List<PruneRowSpec> rows;
  final int chunkSize;
  final int retentionDays;

  Duration get retention => Duration(days: retentionDays);

  int get expectedDeleted => rows
      .where((row) => row.isPrunable(retention: retention, now: now))
      .length;

  /// `pruneSentOutboxItemsChunked` calls `onProgress` exactly once per
  /// loop iteration — including the terminating pass whose chunk
  /// returns `< chunkSize`. So the number of emissions is
  /// `(deleted ~/ chunkSize) + 1`, and emission `i` carries
  /// `min((i + 1) * chunkSize, deleted)` as the running total.
  List<int> get expectedProgress {
    final emissions = (expectedDeleted ~/ chunkSize) + 1;
    return [
      for (var i = 0; i < emissions; i++)
        if ((i + 1) * chunkSize < expectedDeleted)
          (i + 1) * chunkSize
        else
          expectedDeleted,
    ];
  }

  @override
  String toString() =>
      'PruneScenario('
      'rows: $rows, '
      'chunkSize: $chunkSize, '
      'retentionDays: $retentionDays'
      ')';
}

extension AnyPruneScenario on Any {
  Generator<GeneratedOutboxAge> get generatedOutboxAge =>
      choose(GeneratedOutboxAge.values);

  Generator<PruneRowSpec> get pruneRowSpec => combine2(
    any.generatedOutboxStatus,
    generatedOutboxAge,
    (GeneratedOutboxStatus status, GeneratedOutboxAge age) =>
        PruneRowSpec(status: status, age: age),
  );

  /// Scenario space for `pruneSentOutboxItemsChunked`. `chunkSize`
  /// stays small (1–6) so generated row counts realistically straddle
  /// chunk boundaries — the loop's terminator condition (`n < chunkSize`)
  /// is the bit most likely to harbor an off-by-one. `retentionDays`
  /// covers the realistic configured-retention window from
  /// `SyncTuning.outboxSentRetention` and a few neighbours.
  Generator<PruneScenario> get pruneScenario => combine3(
    listWithLengthInRange(0, 14, pruneRowSpec),
    intInRange(1, 6),
    intInRange(1, 7),
    (List<PruneRowSpec> rows, int chunkSize, int retentionDays) =>
        PruneScenario(
          rows: rows,
          chunkSize: chunkSize,
          retentionDays: retentionDays,
        ),
  );
}
