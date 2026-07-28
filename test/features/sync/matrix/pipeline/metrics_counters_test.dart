import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/sync/matrix/pipeline/metrics_counters.dart';

void main() {
  group('MetricsCounters', () {
    test('the collect gate silences diagnostics counters, not DB outcomes', () {
      // Two different contracts share this class. The collect-gated counters
      // exist for diagnostics runs and must cost nothing in steady state; the
      // DB counters record persistence outcomes that matter whether or not
      // verbose metrics are on.
      final off = MetricsCounters()
        ..bumpDroppedType('journalEntity')
        ..incSignalConnectivity()
        ..incDbApplied()
        ..incDbIgnoredByVectorClock()
        ..incConflictsCreated()
        ..incDbMissingBase()
        ..incDbEntryLinkNoop();
      final offSnap = off.snapshot();

      expect(offSnap.containsKey('droppedByType.journalEntity'), isFalse);
      expect(offSnap['signalConnectivity'], 0);
      expect(offSnap['dbApplied'], 1);
      expect(offSnap['dbIgnoredByVectorClock'], 1);
      expect(offSnap['conflictsCreated'], 1);
      expect(offSnap['dbMissingBase'], 1);
      expect(offSnap['dbEntryLinkNoop'], 1);

      final on = MetricsCounters(collect: true)
        ..bumpDroppedType('journalEntity')
        ..bumpDroppedType('journalEntity')
        ..bumpDroppedType('entryLink')
        ..incSignalConnectivity();
      final onSnap = on.snapshot();

      expect(onSnap['droppedByType.journalEntity'], 2);
      expect(onSnap['droppedByType.entryLink'], 1);
      expect(onSnap['signalConnectivity'], 1);
    });

    test('an empty or null dropped type is not counted', () {
      // The runtime type comes off a decoded envelope and can be absent; a
      // 'droppedByType.' row with an empty suffix would render as a blank
      // label in the stats panel.
      final m = MetricsCounters(collect: true)
        ..bumpDroppedType(null)
        ..bumpDroppedType('');
      final snap = m.snapshot();

      expect(
        snap.keys.where((k) => k.startsWith('droppedByType.')),
        isEmpty,
      );
    });

    test('lastIgnored keeps the newest entries within its cap', () {
      final m = MetricsCounters(lastIgnoredMax: 3);
      for (var i = 1; i <= 5; i++) {
        m.addLastIgnored('ignored-$i');
      }

      expect(m.lastIgnored, ['ignored-3', 'ignored-4', 'ignored-5']);
      expect(m.snapshot()['lastIgnoredCount'], 3);
    });

    // The invariant this whole class was cleaned up to protect: a counter that
    // reports a confident zero forever is worse than no counter — the stats
    // panel reads as "nothing is happening", and at least one debugging
    // session built a false cold-start theory on `catchupBatches: 0`.
    test('every snapshot key is one something can actually increment', () {
      final fresh = MetricsCounters(collect: true).snapshot();

      final live = MetricsCounters(collect: true)
        ..incDbApplied()
        ..incDbIgnoredByVectorClock()
        ..incConflictsCreated()
        ..incDbMissingBase()
        ..incDbEntryLinkNoop()
        ..incSignalConnectivity()
        ..bumpDroppedType('journalEntity')
        ..addLastIgnored('ignored-1');
      final moved = live.snapshot();

      for (final key in fresh.keys) {
        expect(
          moved[key],
          isNot(0),
          reason:
              '$key stayed 0 after exercising every incrementer — it is either '
              'dead or missing a call site. Remove it or wire it up; do not '
              'leave it half-present.',
        );
      }
    });
  });

  glados.Glados(
    glados.any.listWithLengthInRange(0, 40, glados.any.letters),
  ).test(
    'lastIgnored never exceeds its cap and preserves arrival order',
    (
      entries,
    ) {
      const cap = 4;
      final m = MetricsCounters(lastIgnoredMax: cap);
      entries.forEach(m.addLastIgnored);

      expect(m.lastIgnored.length, entries.length < cap ? entries.length : cap);
      expect(
        m.lastIgnored,
        entries.skip(entries.length - m.lastIgnored.length),
      );
    },
    tags: 'glados',
  );
}
