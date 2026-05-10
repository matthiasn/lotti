import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/database/journal_update_result.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_stream_processor.dart';
import 'package:lotti/features/sync/matrix/pipeline/metrics_counters.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';

enum _GeneratedPayloadType {
  entryLink,
  journalEntity,
  task,
  empty,
}

enum _GeneratedSkipReason {
  none,
  olderOrEqual,
  conflict,
  overwritePrevented,
  missingBase,
}

enum _GeneratedConflictStatus {
  olderByAGtA,
  olderByAGtB,
  equal,
  unknown,
  mixedEqual,
}

class _GeneratedApplyDiagnostics {
  const _GeneratedApplyDiagnostics({
    required this.payloadType,
    required this.applied,
    required this.skipReason,
    required this.conflictStatus,
    required this.eventSlot,
  });

  final _GeneratedPayloadType payloadType;
  final bool applied;
  final _GeneratedSkipReason skipReason;
  final _GeneratedConflictStatus conflictStatus;
  final int eventSlot;

  String get eventId => 'event-$eventSlot';

  String get payloadTypeValue {
    switch (payloadType) {
      case _GeneratedPayloadType.entryLink:
        return 'entryLink';
      case _GeneratedPayloadType.journalEntity:
        return 'journalEntity';
      case _GeneratedPayloadType.task:
        return 'task';
      case _GeneratedPayloadType.empty:
        return '';
    }
  }

  JournalUpdateSkipReason? get skipReasonValue {
    switch (skipReason) {
      case _GeneratedSkipReason.none:
        return null;
      case _GeneratedSkipReason.olderOrEqual:
        return JournalUpdateSkipReason.olderOrEqual;
      case _GeneratedSkipReason.conflict:
        return JournalUpdateSkipReason.conflict;
      case _GeneratedSkipReason.overwritePrevented:
        return JournalUpdateSkipReason.overwritePrevented;
      case _GeneratedSkipReason.missingBase:
        return JournalUpdateSkipReason.missingBase;
    }
  }

  String get conflictStatusValue {
    switch (conflictStatus) {
      case _GeneratedConflictStatus.olderByAGtA:
        return 'a_gt_a';
      case _GeneratedConflictStatus.olderByAGtB:
        return 'a_gt_b';
      case _GeneratedConflictStatus.equal:
        return 'equal';
      case _GeneratedConflictStatus.unknown:
        return 'parallel';
      case _GeneratedConflictStatus.mixedEqual:
        return 'remote_equal_but_stale';
    }
  }

  SyncApplyDiagnostics toDiagnostics() {
    return SyncApplyDiagnostics(
      eventId: eventId,
      payloadType: payloadTypeValue,
      vectorClock: null,
      conflictStatus: conflictStatusValue,
      applied: applied,
      skipReason: skipReasonValue,
    );
  }

  @override
  String toString() {
    return '_GeneratedApplyDiagnostics('
        'payloadType: $payloadType, '
        'applied: $applied, '
        'skipReason: $skipReason, '
        'conflictStatus: $conflictStatus, '
        'eventSlot: $eventSlot'
        ')';
  }
}

class _GeneratedProcessorScenario {
  const _GeneratedProcessorScenario({
    required this.counterCollect,
    required this.processorCollect,
    required this.lastIgnoredMax,
    required this.connectivitySignals,
    required this.diagnostics,
  });

  final bool counterCollect;
  final bool processorCollect;
  final int lastIgnoredMax;
  final int connectivitySignals;
  final List<_GeneratedApplyDiagnostics> diagnostics;

  @override
  String toString() {
    return '_GeneratedProcessorScenario('
        'counterCollect: $counterCollect, '
        'processorCollect: $processorCollect, '
        'lastIgnoredMax: $lastIgnoredMax, '
        'connectivitySignals: $connectivitySignals, '
        'diagnostics: $diagnostics'
        ')';
  }
}

class _ExpectedProcessorMetrics {
  _ExpectedProcessorMetrics({
    required this.counterCollect,
    required this.processorCollect,
    required this.lastIgnoredMax,
  });

  final bool counterCollect;
  final bool processorCollect;
  final int lastIgnoredMax;
  final Map<String, int> counters = <String, int>{
    'dbApplied': 0,
    'dbIgnoredByVectorClock': 0,
    'conflictsCreated': 0,
    'dbMissingBase': 0,
    'dbEntryLinkNoop': 0,
    'signalConnectivity': 0,
  };
  final Map<String, int> droppedByType = <String, int>{};
  final List<String> lastIgnored = <String>[];

  void recordConnectivitySignals(int count) {
    if (counterCollect && processorCollect) {
      counters['signalConnectivity'] = count;
    }
  }

  void report(_GeneratedApplyDiagnostics diag) {
    final payloadType = diag.payloadTypeValue;
    if (payloadType == 'entryLink') {
      if (diag.applied) {
        _bump('dbApplied');
      } else {
        _bump('dbEntryLinkNoop');
        _bumpDroppedType('entryLink');
        _addLastIgnored('${diag.eventId}:entryLink.noop');
      }
      return;
    }

    if (diag.applied) {
      _bump('dbApplied');
      return;
    }

    switch (diag.skipReasonValue) {
      case JournalUpdateSkipReason.conflict:
        _bump('conflictsCreated');
      case JournalUpdateSkipReason.missingBase:
        _bump('dbMissingBase');
      case JournalUpdateSkipReason.overwritePrevented:
      case JournalUpdateSkipReason.olderOrEqual:
      case null:
        _bump('dbIgnoredByVectorClock');
        _bumpDroppedType(payloadType);
    }
    _addLastIgnored('${diag.eventId}:${_labelFor(diag)}');
  }

  void _bump(String key) {
    counters.update(key, (value) => value + 1);
  }

  void _bumpDroppedType(String payloadType) {
    if (!counterCollect || payloadType.isEmpty) return;
    droppedByType.update(payloadType, (value) => value + 1, ifAbsent: () => 1);
  }

  void _addLastIgnored(String value) {
    lastIgnored.add(value);
    if (lastIgnored.length > lastIgnoredMax) {
      lastIgnored.removeAt(0);
    }
  }

  String _labelFor(_GeneratedApplyDiagnostics diag) {
    final reason = diag.skipReasonValue;
    if (reason != null && reason != JournalUpdateSkipReason.olderOrEqual) {
      return reason.label;
    }
    return _ignoredReasonFromStatus(diag.conflictStatusValue);
  }

  String _ignoredReasonFromStatus(String status) {
    if (status.contains('a_gt_a') || status.contains('a_gt_b')) {
      return 'older';
    }
    if (status.contains('equal')) {
      return 'equal';
    }
    return 'unknown';
  }
}

extension _AnyGeneratedProcessorScenario on glados.Any {
  glados.Generator<_GeneratedPayloadType> get generatedPayloadType =>
      glados.AnyUtils(this).choose(_GeneratedPayloadType.values);

  glados.Generator<_GeneratedSkipReason> get generatedSkipReason =>
      glados.AnyUtils(this).choose(_GeneratedSkipReason.values);

  glados.Generator<_GeneratedConflictStatus> get generatedConflictStatus =>
      glados.AnyUtils(this).choose(_GeneratedConflictStatus.values);

  glados.Generator<_GeneratedApplyDiagnostics> get generatedDiagnostics =>
      glados.CombinableAny(this).combine5(
        generatedPayloadType,
        glados.IntAnys(this).intInRange(0, 2),
        generatedSkipReason,
        generatedConflictStatus,
        glados.IntAnys(this).intInRange(0, 9),
        (
          _GeneratedPayloadType payloadType,
          int appliedSlot,
          _GeneratedSkipReason skipReason,
          _GeneratedConflictStatus conflictStatus,
          int eventSlot,
        ) => _GeneratedApplyDiagnostics(
          payloadType: payloadType,
          applied: appliedSlot == 1,
          skipReason: skipReason,
          conflictStatus: conflictStatus,
          eventSlot: eventSlot,
        ),
      );

  glados.Generator<_GeneratedProcessorScenario> get processorScenario =>
      glados.CombinableAny(this).combine5(
        glados.IntAnys(this).intInRange(0, 2),
        glados.IntAnys(this).intInRange(0, 2),
        glados.IntAnys(this).intInRange(0, 6),
        glados.IntAnys(this).intInRange(0, 5),
        glados.ListAnys(
          this,
        ).listWithLengthInRange(1, 36, generatedDiagnostics),
        (
          int counterCollectSlot,
          int processorCollectSlot,
          int lastIgnoredMax,
          int connectivitySignals,
          List<_GeneratedApplyDiagnostics> diagnostics,
        ) => _GeneratedProcessorScenario(
          counterCollect: counterCollectSlot == 1,
          processorCollect: processorCollectSlot == 1,
          lastIgnoredMax: lastIgnoredMax,
          connectivitySignals: connectivitySignals,
          diagnostics: diagnostics,
        ),
      );
}

void main() {
  glados.Glados(
    glados.any.processorScenario,
    glados.ExploreConfig(numRuns: 180),
  ).test(
    'generated diagnostics update DB metrics, drop maps, and ignored logs',
    (scenario) {
      final counters = MetricsCounters(
        collect: scenario.counterCollect,
        lastIgnoredMax: scenario.lastIgnoredMax,
      );
      final processor = MatrixStreamProcessor(
        metricsCounters: counters,
        collectMetrics: scenario.processorCollect,
      );
      final expected = _ExpectedProcessorMetrics(
        counterCollect: scenario.counterCollect,
        processorCollect: scenario.processorCollect,
        lastIgnoredMax: scenario.lastIgnoredMax,
      )..recordConnectivitySignals(scenario.connectivitySignals);

      for (var i = 0; i < scenario.connectivitySignals; i++) {
        processor.recordConnectivitySignal();
      }
      for (final diag in scenario.diagnostics) {
        processor.reportDbApplyDiagnostics(diag.toDiagnostics());
        expected.report(diag);
      }

      final snapshot = processor.metricsSnapshot();
      for (final entry in expected.counters.entries) {
        expect(
          snapshot[entry.key],
          entry.value,
          reason: '$scenario\n${entry.key}',
        );
      }

      final actualDroppedKeys = snapshot.keys
          .where((key) => key.startsWith('droppedByType.'))
          .toSet();
      final expectedDroppedKeys = expected.droppedByType.keys
          .map((key) => 'droppedByType.$key')
          .toSet();
      expect(actualDroppedKeys, expectedDroppedKeys, reason: '$scenario');
      for (final entry in expected.droppedByType.entries) {
        expect(snapshot['droppedByType.${entry.key}'], entry.value);
      }

      expect(snapshot['lastIgnoredCount'], expected.lastIgnored.length);
      for (var index = 0; index < expected.lastIgnored.length; index++) {
        expect(
          snapshot['lastIgnored.${index + 1}'],
          expected.lastIgnored[index].length,
        );
      }

      final diagnostics = processor.diagnosticsStrings();
      expect(
        diagnostics['lastIgnoredCount'],
        expected.lastIgnored.length.toString(),
      );
      expect(
        diagnostics['entryLink.noops'],
        expected.counters['dbEntryLinkNoop'].toString(),
      );
      final ignoredKeys = diagnostics.keys
          .where((key) => key.startsWith('lastIgnored.'))
          .toList();
      expect(ignoredKeys.length, expected.lastIgnored.length);
      for (var index = 0; index < expected.lastIgnored.length; index++) {
        expect(
          diagnostics['lastIgnored.${index + 1}'],
          expected.lastIgnored[index],
        );
      }
    },
    tags: 'glados',
  );
}
