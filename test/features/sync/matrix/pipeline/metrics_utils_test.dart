import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/sync/matrix/pipeline/metrics_utils.dart';

// ---------------------------------------------------------------------------
// Glados generators
// ---------------------------------------------------------------------------

extension _AnyMetricsUtils on glados.Any {
  glados.Generator<Map<String, int>> get smallStringIntMap =>
      glados.CombinableAny(this).combine2(
        glados.ListAnys(this).listWithLengthInRange(0, 5, _typeKey),
        glados.ListAnys(this).listWithLengthInRange(0, 5, _nonNegInt),
        (List<String> keys, List<int> values) {
          final map = <String, int>{};
          for (var i = 0; i < keys.length && i < values.length; i++) {
            map[keys[i]] = values[i];
          }
          return map;
        },
      );

  glados.Generator<String> get _typeKey =>
      glados.AnyUtils(this).choose(const <String>[
        'journalEntity',
        'entryLink',
        'task',
        'agent',
        'notification',
      ]);

  glados.Generator<int> get _nonNegInt =>
      glados.IntAnys(this).intInRange(0, 500);

  glados.Generator<List<String>> get lastIgnoredList =>
      glados.ListAnys(this).listWithLengthInRange(
        0,
        8,
        glados.any.letterOrDigits,
      );

  glados.Generator<_SnapshotScenario> get snapshotScenario =>
      glados.CombinableAny(this).combine4(
        _nonNegInt,
        smallStringIntMap,
        smallStringIntMap,
        lastIgnoredList,
        (
          int seed,
          Map<String, int> processedByType,
          Map<String, int> droppedByType,
          List<String> lastIgnored,
        ) => _SnapshotScenario(
          seed: seed,
          processedByType: processedByType,
          droppedByType: droppedByType,
          lastIgnored: lastIgnored,
        ),
      );
}

class _SnapshotScenario {
  _SnapshotScenario({
    required this.seed,
    required this.processedByType,
    required this.droppedByType,
    required this.lastIgnored,
  });

  final int seed;
  final Map<String, int> processedByType;
  final Map<String, int> droppedByType;
  final List<String> lastIgnored;

  @override
  String toString() =>
      '_SnapshotScenario('
      'seed: $seed, '
      'processedByType: $processedByType, '
      'droppedByType: $droppedByType, '
      'lastIgnored: $lastIgnored'
      ')';
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('MetricsUtils.buildSnapshot — static examples', () {
    test('scalar fields are stored at the expected keys', () {
      final snap = MetricsUtils.buildSnapshot(
        processed: 10,
        skipped: 2,
        failures: 1,
        flushes: 3,
        catchupBatches: 5,
        skippedByRetryLimit: 7,
        retriesScheduled: 4,
        circuitOpens: 0,
        processedByType: const <String, int>{},
        droppedByType: const <String, int>{},
        dbApplied: 8,
        dbIgnoredByVectorClock: 6,
        conflictsCreated: 9,
        lastIgnored: const <String>[],
      );

      expect(snap['processed'], 10);
      expect(snap['skipped'], 2);
      expect(snap['failures'], 1);
      expect(snap['flushes'], 3);
      expect(snap['catchupBatches'], 5);
      expect(snap['skippedByRetryLimit'], 7);
      expect(snap['retriesScheduled'], 4);
      expect(snap['circuitOpens'], 0);
      expect(snap['dbApplied'], 8);
      expect(snap['dbIgnoredByVectorClock'], 6);
      expect(snap['conflictsCreated'], 9);
    });

    test('processedByType entries are namespaced with processed. prefix', () {
      final snap = MetricsUtils.buildSnapshot(
        processed: 0,
        skipped: 0,
        failures: 0,
        flushes: 0,
        catchupBatches: 0,
        skippedByRetryLimit: 0,
        retriesScheduled: 0,
        circuitOpens: 0,
        processedByType: const <String, int>{'journalEntity': 3, 'task': 7},
        droppedByType: const <String, int>{},
        dbApplied: 0,
        dbIgnoredByVectorClock: 0,
        conflictsCreated: 0,
        lastIgnored: const <String>[],
      );

      expect(snap['processed.journalEntity'], 3);
      expect(snap['processed.task'], 7);
      expect(snap.containsKey('journalEntity'), isFalse);
    });

    test('droppedByType entries are namespaced with droppedByType. prefix', () {
      final snap = MetricsUtils.buildSnapshot(
        processed: 0,
        skipped: 0,
        failures: 0,
        flushes: 0,
        catchupBatches: 0,
        skippedByRetryLimit: 0,
        retriesScheduled: 0,
        circuitOpens: 0,
        processedByType: const <String, int>{},
        droppedByType: const <String, int>{'entryLink': 11},
        dbApplied: 0,
        dbIgnoredByVectorClock: 0,
        conflictsCreated: 0,
        lastIgnored: const <String>[],
      );

      expect(snap['droppedByType.entryLink'], 11);
      expect(snap.containsKey('entryLink'), isFalse);
    });

    test('lastIgnoredCount equals the list length', () {
      final snap = MetricsUtils.buildSnapshot(
        processed: 0,
        skipped: 0,
        failures: 0,
        flushes: 0,
        catchupBatches: 0,
        skippedByRetryLimit: 0,
        retriesScheduled: 0,
        circuitOpens: 0,
        processedByType: const <String, int>{},
        droppedByType: const <String, int>{},
        dbApplied: 0,
        dbIgnoredByVectorClock: 0,
        conflictsCreated: 0,
        lastIgnored: const <String>['abc', 'defgh'],
      );

      expect(snap['lastIgnoredCount'], 2);
    });

    test(
      'lastIgnored.N entries store the string length at 1-based index',
      () {
        final snap = MetricsUtils.buildSnapshot(
          processed: 0,
          skipped: 0,
          failures: 0,
          flushes: 0,
          catchupBatches: 0,
          skippedByRetryLimit: 0,
          retriesScheduled: 0,
          circuitOpens: 0,
          processedByType: const <String, int>{},
          droppedByType: const <String, int>{},
          dbApplied: 0,
          dbIgnoredByVectorClock: 0,
          conflictsCreated: 0,
          lastIgnored: const <String>['ab', 'xyz', 'hello world'],
        );

        // lastIgnored.1 = 'ab'.length = 2
        // lastIgnored.2 = 'xyz'.length = 3
        // lastIgnored.3 = 'hello world'.length = 11
        expect(snap['lastIgnored.1'], 2);
        expect(snap['lastIgnored.2'], 3);
        expect(snap['lastIgnored.3'], 11);
        expect(snap.containsKey('lastIgnored.4'), isFalse);
      },
    );

    test(
      'empty lastIgnored produces lastIgnoredCount=0 and no lastIgnored.N',
      () {
        final snap = MetricsUtils.buildSnapshot(
          processed: 0,
          skipped: 0,
          failures: 0,
          flushes: 0,
          catchupBatches: 0,
          skippedByRetryLimit: 0,
          retriesScheduled: 0,
          circuitOpens: 0,
          processedByType: const <String, int>{},
          droppedByType: const <String, int>{},
          dbApplied: 0,
          dbIgnoredByVectorClock: 0,
          conflictsCreated: 0,
          lastIgnored: const <String>[],
        );

        expect(snap['lastIgnoredCount'], 0);
        expect(snap.keys.any((k) => k.startsWith('lastIgnored.')), isFalse);
      },
    );

    test('both type maps together do not collide with scalar keys', () {
      final snap = MetricsUtils.buildSnapshot(
        processed: 42,
        skipped: 1,
        failures: 2,
        flushes: 3,
        catchupBatches: 4,
        skippedByRetryLimit: 5,
        retriesScheduled: 6,
        circuitOpens: 7,
        processedByType: const <String, int>{'agent': 100},
        droppedByType: const <String, int>{'agent': 200},
        dbApplied: 8,
        dbIgnoredByVectorClock: 9,
        conflictsCreated: 10,
        lastIgnored: const <String>['x'],
      );

      // Scalar 'processed' stays at 42
      expect(snap['processed'], 42);
      // Namespaced entries differ from the scalar
      expect(snap['processed.agent'], 100);
      expect(snap['droppedByType.agent'], 200);
    });
  });

  // -------------------------------------------------------------------------
  // Glados properties
  // -------------------------------------------------------------------------

  group('MetricsUtils.buildSnapshot — Glados properties', () {
    glados.Glados(
      glados.any.snapshotScenario,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'lastIgnoredCount always equals lastIgnored.length',
      (scenario) {
        final snap = MetricsUtils.buildSnapshot(
          processed: scenario.seed,
          skipped: 0,
          failures: 0,
          flushes: 0,
          catchupBatches: 0,
          skippedByRetryLimit: 0,
          retriesScheduled: 0,
          circuitOpens: 0,
          processedByType: scenario.processedByType,
          droppedByType: scenario.droppedByType,
          dbApplied: 0,
          dbIgnoredByVectorClock: 0,
          conflictsCreated: 0,
          lastIgnored: scenario.lastIgnored,
        );

        expect(
          snap['lastIgnoredCount'],
          scenario.lastIgnored.length,
          reason: '$scenario',
        );
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.snapshotScenario,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'processedByType keys are all namespaced with processed. prefix',
      (scenario) {
        final snap = MetricsUtils.buildSnapshot(
          processed: scenario.seed,
          skipped: 0,
          failures: 0,
          flushes: 0,
          catchupBatches: 0,
          skippedByRetryLimit: 0,
          retriesScheduled: 0,
          circuitOpens: 0,
          processedByType: scenario.processedByType,
          droppedByType: scenario.droppedByType,
          dbApplied: 0,
          dbIgnoredByVectorClock: 0,
          conflictsCreated: 0,
          lastIgnored: scenario.lastIgnored,
        );

        for (final entry in scenario.processedByType.entries) {
          expect(
            snap['processed.${entry.key}'],
            entry.value,
            reason: 'key: processed.${entry.key}, $scenario',
          );
        }
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.snapshotScenario,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'droppedByType keys are all namespaced with droppedByType. prefix',
      (scenario) {
        final snap = MetricsUtils.buildSnapshot(
          processed: scenario.seed,
          skipped: 0,
          failures: 0,
          flushes: 0,
          catchupBatches: 0,
          skippedByRetryLimit: 0,
          retriesScheduled: 0,
          circuitOpens: 0,
          processedByType: scenario.processedByType,
          droppedByType: scenario.droppedByType,
          dbApplied: 0,
          dbIgnoredByVectorClock: 0,
          conflictsCreated: 0,
          lastIgnored: scenario.lastIgnored,
        );

        for (final entry in scenario.droppedByType.entries) {
          expect(
            snap['droppedByType.${entry.key}'],
            entry.value,
            reason: 'key: droppedByType.${entry.key}, $scenario',
          );
        }
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.snapshotScenario,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'lastIgnored.N stores length of the Nth string (1-indexed)',
      (scenario) {
        final snap = MetricsUtils.buildSnapshot(
          processed: scenario.seed,
          skipped: 0,
          failures: 0,
          flushes: 0,
          catchupBatches: 0,
          skippedByRetryLimit: 0,
          retriesScheduled: 0,
          circuitOpens: 0,
          processedByType: const <String, int>{},
          droppedByType: const <String, int>{},
          dbApplied: 0,
          dbIgnoredByVectorClock: 0,
          conflictsCreated: 0,
          lastIgnored: scenario.lastIgnored,
        );

        for (var i = 0; i < scenario.lastIgnored.length; i++) {
          expect(
            snap['lastIgnored.${i + 1}'],
            scenario.lastIgnored[i].length,
            reason: 'index ${i + 1}, $scenario',
          );
        }
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.snapshotScenario,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'scalar processed field always matches the input value',
      (scenario) {
        final snap = MetricsUtils.buildSnapshot(
          processed: scenario.seed,
          skipped: 0,
          failures: 0,
          flushes: 0,
          catchupBatches: 0,
          skippedByRetryLimit: 0,
          retriesScheduled: 0,
          circuitOpens: 0,
          processedByType: scenario.processedByType,
          droppedByType: scenario.droppedByType,
          dbApplied: 0,
          dbIgnoredByVectorClock: 0,
          conflictsCreated: 0,
          lastIgnored: scenario.lastIgnored,
        );

        expect(
          snap['processed'],
          scenario.seed,
          reason: '$scenario',
        );
      },
      tags: 'glados',
    );
  });
}
