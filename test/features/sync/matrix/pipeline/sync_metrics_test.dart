import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/sync/matrix/pipeline/sync_metrics.dart';

void main() {
  group('SyncMetrics', () {
    test('defaults every counter to zero', () {
      const metrics = SyncMetrics();

      expect(metrics.dbApplied, 0);
      expect(metrics.dbIgnoredByVectorClock, 0);
      expect(metrics.conflictsCreated, 0);
      expect(metrics.dbMissingBase, 0);
      expect(metrics.dbEntryLinkNoop, 0);
      expect(metrics.signalConnectivity, 0);
      expect(metrics.queueActive, 0);
      expect(metrics.queueApplied, 0);
      expect(metrics.queueAbandoned, 0);
      expect(metrics.queueRetrying, 0);
      expect(metrics.droppedByType, isEmpty);
    });

    test('fromMap reads the flat snapshot the pipeline produces', () {
      final metrics = SyncMetrics.fromMap(<String, dynamic>{
        'dbApplied': 12,
        'dbIgnoredByVectorClock': 3,
        'conflictsCreated': 1,
        'dbMissingBase': 2,
        'dbEntryLinkNoop': 4,
        'signalConnectivity': 5,
        'queueActive': 6,
        'queueApplied': 7,
        'queueAbandoned': 8,
        'queueRetrying': 9,
        'droppedByType.journalEntity': 10,
        'droppedByType.entryLink': 11,
      });

      expect(metrics.dbApplied, 12);
      expect(metrics.dbIgnoredByVectorClock, 3);
      expect(metrics.conflictsCreated, 1);
      expect(metrics.dbMissingBase, 2);
      expect(metrics.dbEntryLinkNoop, 4);
      expect(metrics.signalConnectivity, 5);
      expect(metrics.queueActive, 6);
      expect(metrics.queueApplied, 7);
      expect(metrics.queueAbandoned, 8);
      expect(metrics.queueRetrying, 9);
      expect(metrics.droppedByType, {'journalEntity': 10, 'entryLink': 11});
    });

    test('fromMap treats absent and null values as zero', () {
      // The snapshot crosses an untyped boundary (isolate/actor payloads and
      // older builds), so a missing or null key must not throw.
      final metrics = SyncMetrics.fromMap(<String, dynamic>{
        'dbApplied': null,
        'queueActive': 4,
      });

      expect(metrics.dbApplied, 0);
      expect(metrics.conflictsCreated, 0);
      expect(metrics.queueActive, 4);
    });

    test('an unknown key is ignored rather than crashing the panel', () {
      // A peer or an older build can carry keys this version has dropped —
      // notably the pre-queue throughput counters removed with the dead-code
      // cleanup. They must not reach the UI, and must not throw.
      final metrics = SyncMetrics.fromMap(<String, dynamic>{
        'catchupBatches': 99,
        'processed': 42,
        'dbApplied': 1,
      });

      expect(metrics.dbApplied, 1);
      expect(metrics.toMap().containsKey('catchupBatches'), isFalse);
      expect(metrics.toMap().containsKey('processed'), isFalse);
    });
  });

  glados.Glados2(glados.any.positiveInt, glados.any.positiveInt).test(
    'toMap/fromMap round-trips every counter',
    (a, b) {
      final original = SyncMetrics(
        dbApplied: a,
        dbIgnoredByVectorClock: b,
        conflictsCreated: a,
        dbMissingBase: b,
        dbEntryLinkNoop: a,
        signalConnectivity: b,
        queueActive: a,
        queueApplied: b,
        queueAbandoned: a,
        queueRetrying: b,
        droppedByType: {'journalEntity': a, 'entryLink': b},
      );

      final round = SyncMetrics.fromMap(original.toMap());

      expect(round.toMap(), original.toMap());
    },
    tags: 'glados',
  );
}
