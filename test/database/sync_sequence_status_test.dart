// Tests for the pure `SyncSequenceStatus` resolved-set contract
// (`lib/database/sync_sequence_status.dart`). No database needed.
import 'package:glados/glados.dart';
import 'package:lotti/database/sync_db.dart';

void main() {
  group('SyncSequenceStatusX.isResolved', () {
    // The resolved set is the single source of truth behind the watermark CTEs
    // and the `idx_sync_sequence_log_resolved_host_counter` partial index,
    // whose WHERE clauses inline these status indices as SQL literals.
    const resolvedStatuses = {
      SyncSequenceStatus.received,
      SyncSequenceStatus.backfilled,
      SyncSequenceStatus.deleted,
      SyncSequenceStatus.unresolvable,
      SyncSequenceStatus.burned,
    };

    test('is true exactly for the documented resolved set', () {
      // Exhaustive loop instead of a Glados sample: the domain is the
      // 9-value enum itself, so iterating it covers every case.
      for (final status in SyncSequenceStatus.values) {
        expect(
          status.isResolved,
          resolvedStatuses.contains(status),
          reason: '$status',
        );
      }
    });

    test('resolved indices match the SQL literals IN (0, 3, 4, 5, 8)', () {
      final resolvedIndices = {
        for (final status in SyncSequenceStatus.values)
          if (status.isResolved) status.index,
      };
      expect(resolvedIndices, {0, 3, 4, 5, 8});
    });

    test('burned and burnPending sit on opposite sides of the split', () {
      // burnPending is a transient own-host marker awaiting its broadcast;
      // burned is its terminal, resolved successor.
      expect(SyncSequenceStatus.burnPending.isResolved, isFalse);
      expect(SyncSequenceStatus.burned.isResolved, isTrue);
    });
  });
}
