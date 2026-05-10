import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/sync/matrix/pipeline/metrics_counters.dart';
import 'package:lotti/features/sync/matrix/pipeline/sync_metrics.dart';

const _syncMetricScalarKeys = <String>[
  'processed',
  'skipped',
  'failures',
  'flushes',
  'catchupBatches',
  'skippedByRetryLimit',
  'retriesScheduled',
  'circuitOpens',
  'processedPerAppliedPct',
  'dbApplied',
  'dbIgnoredByVectorClock',
  'conflictsCreated',
  'dbMissingBase',
  'dbEntryLinkNoop',
  'staleAttachmentPurges',
  'selfEventsSuppressed',
  'signalClientStream',
  'signalTimelineCallbacks',
  'signalTimelineNewEvent',
  'signalTimelineInsert',
  'signalFirstStreamCatchupTriggers',
  'signalCatchupDeferredCount',
  'signalCatchupCoalesceCount',
  'signalLiveScanDeferredInitialCatchupIncomplete',
  'signalLiveScanDeferredCatchupInFlight',
  'signalLiveScanDeferredInFlight',
  'signalNoTimelineCount',
  'wakeDetections',
  'signalConnectivity',
  'signalLatencyLastMs',
  'signalLatencyMinMs',
  'signalLatencyMaxMs',
  'trailingCatchups',
  'liveScanDeferredCount',
  'liveScanCoalesceCount',
  'liveScanTrailingScheduled',
  'queueActive',
  'queueApplied',
  'queueAbandoned',
  'queueRetrying',
];

enum _GeneratedMetricMapPrefix {
  processed,
  droppedByType,
}

class _GeneratedMetricTypeEntry {
  const _GeneratedMetricTypeEntry({
    required this.prefix,
    required this.typeSlot,
    required this.value,
  });

  final _GeneratedMetricMapPrefix prefix;
  final int typeSlot;
  final int value;

  String get typeName {
    switch (typeSlot % 4) {
      case 0:
        return 'journalEntity';
      case 1:
        return 'entryLink';
      case 2:
        return 'task';
      case 3:
        return 'agent';
    }
    throw StateError('unsupported type slot $typeSlot');
  }

  String get mapKey {
    switch (prefix) {
      case _GeneratedMetricMapPrefix.processed:
        return 'processed.$typeName';
      case _GeneratedMetricMapPrefix.droppedByType:
        return 'droppedByType.$typeName';
    }
  }

  @override
  String toString() {
    return '_GeneratedMetricTypeEntry('
        'prefix: $prefix, '
        'typeSlot: $typeSlot, '
        'value: $value'
        ')';
  }
}

class _GeneratedSyncMetricsMapScenario {
  const _GeneratedSyncMetricsMapScenario({
    required this.includePattern,
    required this.valueSeed,
    required this.typedEntries,
    required this.unknownSlot,
  });

  final int includePattern;
  final int valueSeed;
  final List<_GeneratedMetricTypeEntry> typedEntries;
  final int unknownSlot;

  Map<String, int> inputMap() {
    final map = <String, int>{};
    for (var index = 0; index < _syncMetricScalarKeys.length; index++) {
      if ((includePattern + index) % 3 != 0) {
        map[_syncMetricScalarKeys[index]] = valueForIndex(index);
      }
    }
    for (final entry in typedEntries) {
      map[entry.mapKey] = entry.value;
    }
    map['lastIgnoredCount'] = unknownSlot + 1;
    map['lastIgnored.1'] = unknownSlot + 2;
    map['untyped.$unknownSlot'] = unknownSlot + 3;
    return map;
  }

  int valueForIndex(int index) => (valueSeed + index * 7) % 100;

  int expectedScalarValue(String key) {
    final index = _syncMetricScalarKeys.indexOf(key);
    if (index == -1) throw StateError('unsupported scalar key $key');
    return (includePattern + index) % 3 != 0 ? valueForIndex(index) : 0;
  }

  Map<String, int> expectedTypedEntries() {
    final map = <String, int>{};
    for (final entry in typedEntries) {
      map[entry.mapKey] = entry.value;
    }
    return map;
  }

  @override
  String toString() {
    return '_GeneratedSyncMetricsMapScenario('
        'includePattern: $includePattern, '
        'valueSeed: $valueSeed, '
        'typedEntries: $typedEntries, '
        'unknownSlot: $unknownSlot'
        ')';
  }
}

extension _AnySyncMetricsMapScenario on glados.Any {
  glados.Generator<_GeneratedMetricMapPrefix> get metricMapPrefix =>
      glados.AnyUtils(this).choose(_GeneratedMetricMapPrefix.values);

  glados.Generator<_GeneratedMetricTypeEntry> get metricTypeEntry =>
      glados.CombinableAny(this).combine3(
        metricMapPrefix,
        glados.IntAnys(this).intInRange(0, 8),
        glados.IntAnys(this).intInRange(0, 100),
        (
          _GeneratedMetricMapPrefix prefix,
          int typeSlot,
          int value,
        ) => _GeneratedMetricTypeEntry(
          prefix: prefix,
          typeSlot: typeSlot,
          value: value,
        ),
      );

  glados.Generator<_GeneratedSyncMetricsMapScenario>
  get syncMetricsMapScenario => glados.CombinableAny(this).combine4(
    glados.IntAnys(this).intInRange(0, 6),
    glados.IntAnys(this).intInRange(0, 100),
    glados.ListAnys(this).listWithLengthInRange(0, 16, metricTypeEntry),
    glados.IntAnys(this).intInRange(0, 9),
    (
      int includePattern,
      int valueSeed,
      List<_GeneratedMetricTypeEntry> typedEntries,
      int unknownSlot,
    ) => _GeneratedSyncMetricsMapScenario(
      includePattern: includePattern,
      valueSeed: valueSeed,
      typedEntries: typedEntries,
      unknownSlot: unknownSlot,
    ),
  );
}

void main() {
  test('fromMap handles missing keys gracefully', () {
    final metrics = SyncMetrics.fromMap(const <String, dynamic>{});

    expect(metrics.processed, 0);
    expect(metrics.skipped, 0);
    expect(metrics.processedByType, isEmpty);
    expect(metrics.droppedByType, isEmpty);
    expect(metrics.dbApplied, 0);
    expect(metrics.staleAttachmentPurges, 0);
  });

  test('fromMap deserializes processedByType and droppedByType entries', () {
    final metrics = SyncMetrics.fromMap(const <String, dynamic>{
      'processed.journalEntity': 5,
      'processed.entryLink': 1,
      'droppedByType.journalEntity': 2,
    });

    expect(metrics.processedByType['journalEntity'], 5);
    expect(metrics.processedByType['entryLink'], 1);
    expect(metrics.droppedByType['journalEntity'], 2);
  });

  test('toMap includes persisted counters', () {
    const metrics = SyncMetrics(
      processed: 2,
      skipped: 1,
      failures: 0,
      flushes: 1,
      catchupBatches: 4,
      skippedByRetryLimit: 0,
      retriesScheduled: 1,
      circuitOpens: 2,
      dbApplied: 7,
      dbIgnoredByVectorClock: 9,
      conflictsCreated: 11,
      staleAttachmentPurges: 13,
      processedByType: {'journalEntity': 2},
      droppedByType: {'entryLink': 1},
    );

    final map = metrics.toMap();

    expect(map['processed'], 2);
    expect(map['processed.journalEntity'], 2);
    expect(map['droppedByType.entryLink'], 1);
    expect(map['staleAttachmentPurges'], 13);
  });

  test('metrics counters track stale purges and missing base', () {
    final counters = MetricsCounters(collect: true)
      ..incStaleAttachmentPurges()
      ..incDbMissingBase()
      ..incDbMissingBase();

    final snapshot = counters.snapshot();

    expect(snapshot['staleAttachmentPurges'], 1);
    expect(snapshot['dbMissingBase'], 2);
  });

  glados.Glados(
    glados.any.syncMetricsMapScenario,
    glados.ExploreConfig(numRuns: 160),
  ).test('generated maps preserve typed sync metrics through roundtrip', (
    scenario,
  ) {
    final roundTripped = SyncMetrics.fromMap(scenario.inputMap()).toMap();

    for (final key in _syncMetricScalarKeys) {
      expect(
        roundTripped[key],
        scenario.expectedScalarValue(key),
        reason: '$scenario\n$key',
      );
    }

    final expectedTyped = scenario.expectedTypedEntries();
    final actualTypedKeys = roundTripped.keys
        .where(
          (key) =>
              key.startsWith('processed.') || key.startsWith('droppedByType.'),
        )
        .toSet();
    expect(actualTypedKeys, expectedTyped.keys.toSet(), reason: '$scenario');
    for (final entry in expectedTyped.entries) {
      expect(roundTripped[entry.key], entry.value);
    }

    expect(roundTripped.containsKey('lastIgnoredCount'), isFalse);
    expect(roundTripped.containsKey('lastIgnored.1'), isFalse);
    expect(
      roundTripped.containsKey('untyped.${scenario.unknownSlot}'),
      isFalse,
    );
  }, tags: 'glados');
}
