// ignore_for_file: avoid_redundant_argument_values

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

enum GeneratedCounterState {
  absent,
  received,
  missing,
  requested,
  backfilled,
  deleted,
  unresolvable,
}

class SequenceGapScenario {
  const SequenceGapScenario({
    required this.observedCounter,
    required this.counterStates,
  });

  final int observedCounter;
  final List<GeneratedCounterState> counterStates;

  int? lastResolvedPrefix() {
    if (!counterStates.any((state) => state.isStored)) return null;

    var prefix = 0;
    for (final state in counterStates) {
      if (!state.isResolvedWatermark) break;
      prefix++;
    }
    return prefix;
  }

  List<({String hostId, int counter})> expectedGaps(String hostId) {
    final baseline = lastResolvedPrefix() ?? 0;
    return [
      for (var counter = baseline + 1; counter < observedCounter; counter++)
        if (!stateAt(counter).isResolvedWatermark)
          (hostId: hostId, counter: counter),
    ];
  }

  bool insertsNewMissingCounter(int counter) {
    final baseline = lastResolvedPrefix() ?? 0;
    return counter > baseline &&
        counter < observedCounter &&
        stateAt(counter) == GeneratedCounterState.absent;
  }

  GeneratedCounterState stateAt(int counter) {
    final index = counter - 1;
    if (index < 0 || index >= counterStates.length) {
      return GeneratedCounterState.absent;
    }
    return counterStates[index];
  }

  SyncSequenceStatus expectedObservedStatus() {
    final current = stateAt(observedCounter);
    return switch (current) {
      GeneratedCounterState.received => SyncSequenceStatus.received,
      GeneratedCounterState.backfilled => SyncSequenceStatus.backfilled,
      GeneratedCounterState.requested => SyncSequenceStatus.backfilled,
      _ => SyncSequenceStatus.received,
    };
  }

  SyncSequenceStatus? expectedStatusAfterReceive(int counter) {
    if (counter == observedCounter) return expectedObservedStatus();
    if (insertsNewMissingCounter(counter)) return SyncSequenceStatus.missing;

    final current = stateAt(counter);
    if (current == GeneratedCounterState.absent) return null;
    return current.syncStatus;
  }

  int expectedLastResolvedPrefixAfterReceive() {
    var prefix = 0;
    final maxCounter = observedCounter > counterStates.length
        ? observedCounter
        : counterStates.length;
    for (var counter = 1; counter <= maxCounter; counter++) {
      final status = expectedStatusAfterReceive(counter);
      if (status == null || !status.isResolvedWatermark) break;
      prefix++;
    }
    return prefix;
  }

  @override
  String toString() {
    return 'SequenceGapScenario('
        'observedCounter: $observedCounter, '
        'counterStates: $counterStates'
        ')';
  }
}

class CoveredClockGapScenario {
  const CoveredClockGapScenario({
    required this.observedCounter,
    required this.coveredFlags,
  });

  final int observedCounter;
  final List<bool> coveredFlags;

  Set<int> get coveredCounters => {
    for (var i = 0; i < coveredFlags.length; i++)
      if (coveredFlags[i]) i + 1,
  };

  int get coveredResolvedPrefix {
    final covered = coveredCounters;
    var prefix = 0;
    while (covered.contains(prefix + 1)) {
      prefix++;
    }
    return prefix;
  }

  List<({String hostId, int counter})> expectedGaps(String hostId) {
    return [
      for (
        var counter = coveredResolvedPrefix + 1;
        counter < observedCounter;
        counter++
      )
        if (!coveredCounters.contains(counter))
          (hostId: hostId, counter: counter),
    ];
  }

  bool insertsNewMissingCounter(int counter) {
    return counter > coveredResolvedPrefix &&
        counter < observedCounter &&
        !coveredCounters.contains(counter);
  }

  SyncSequenceStatus? expectedStatusAfterReceive(int counter) {
    if (counter == observedCounter) return SyncSequenceStatus.received;
    if (coveredCounters.contains(counter)) return SyncSequenceStatus.received;
    if (insertsNewMissingCounter(counter)) return SyncSequenceStatus.missing;
    return null;
  }

  int expectedLastResolvedPrefixAfterReceive() {
    var prefix = 0;
    final coveredMax = coveredCounters.isEmpty
        ? 0
        : coveredCounters.reduce((a, b) => a > b ? a : b);
    final maxCounter = observedCounter > coveredMax
        ? observedCounter
        : coveredMax;
    for (var counter = 1; counter <= maxCounter; counter++) {
      final status = expectedStatusAfterReceive(counter);
      if (status == null || !status.isResolvedWatermark) break;
      prefix++;
    }
    return prefix;
  }

  @override
  String toString() {
    return 'CoveredClockGapScenario('
        'observedCounter: $observedCounter, '
        'coveredFlags: $coveredFlags'
        ')';
  }
}

class GeneratedHostClock {
  const GeneratedHostClock({
    required this.included,
    required this.knownOnline,
    required this.resolvedPrefix,
    required this.observedCounter,
  });

  final bool included;
  final bool knownOnline;
  final int resolvedPrefix;
  final int observedCounter;

  @override
  String toString() {
    return 'GeneratedHostClock('
        'included: $included, '
        'knownOnline: $knownOnline, '
        'resolvedPrefix: $resolvedPrefix, '
        'observedCounter: $observedCounter'
        ')';
  }
}

class MultiHostGapScenario {
  const MultiHostGapScenario({
    required this.originatorResolvedPrefix,
    required this.originatorObservedCounter,
    required this.bob,
    required this.charlie,
    required this.ownHost,
  });

  final int originatorResolvedPrefix;
  final int originatorObservedCounter;
  final GeneratedHostClock bob;
  final GeneratedHostClock charlie;
  final GeneratedHostClock ownHost;

  Map<String, int> vectorClock({
    required String myHostId,
    required String aliceHostId,
    required String bobHostId,
    required String charlieHostId,
  }) {
    return {
      aliceHostId: originatorObservedCounter,
      if (bob.included) bobHostId: bob.observedCounter,
      if (charlie.included) charlieHostId: charlie.observedCounter,
      if (ownHost.included) myHostId: ownHost.observedCounter,
    };
  }

  List<({String hostId, int counter})> expectedGaps({
    required String aliceHostId,
    required String bobHostId,
    required String charlieHostId,
  }) {
    return [
      ...expectedHostGaps(
        hostId: aliceHostId,
        resolvedPrefix: originatorResolvedPrefix,
        observedCounter: originatorObservedCounter,
        shouldDetectGaps: true,
      ),
      if (bob.included)
        ...expectedHostGaps(
          hostId: bobHostId,
          resolvedPrefix: bob.resolvedPrefix,
          observedCounter: bob.observedCounter,
          shouldDetectGaps: bob.knownOnline,
        ),
      if (charlie.included)
        ...expectedHostGaps(
          hostId: charlieHostId,
          resolvedPrefix: charlie.resolvedPrefix,
          observedCounter: charlie.observedCounter,
          shouldDetectGaps: charlie.knownOnline,
        ),
    ];
  }

  bool get insertsNewMissing =>
      originatorObservedCounter > originatorResolvedPrefix + 1 ||
      (bob.included &&
          bob.knownOnline &&
          bob.observedCounter > bob.resolvedPrefix + 1) ||
      (charlie.included &&
          charlie.knownOnline &&
          charlie.observedCounter > charlie.resolvedPrefix + 1);

  int? expectedResolvedPrefixAfterReceive({
    required String hostId,
    required String aliceHostId,
    required String bobHostId,
    required String charlieHostId,
    required String myHostId,
  }) {
    if (hostId == aliceHostId) {
      return expectedPrefixAfterObserved(
        resolvedPrefix: originatorResolvedPrefix,
        observedCounter: originatorObservedCounter,
        observedRecorded: true,
      );
    }
    if (hostId == bobHostId) {
      return expectedPrefixAfterObserved(
        resolvedPrefix: bob.resolvedPrefix,
        observedCounter: bob.observedCounter,
        observedRecorded: bob.included,
      );
    }
    if (hostId == charlieHostId) {
      return expectedPrefixAfterObserved(
        resolvedPrefix: charlie.resolvedPrefix,
        observedCounter: charlie.observedCounter,
        observedRecorded: charlie.included,
      );
    }
    if (hostId == myHostId) {
      return expectedPrefixAfterObserved(
        resolvedPrefix: ownHost.resolvedPrefix,
        observedCounter: ownHost.observedCounter,
        observedRecorded: false,
      );
    }
    throw ArgumentError.value(hostId, 'hostId');
  }

  @override
  String toString() {
    return 'MultiHostGapScenario('
        'originatorResolvedPrefix: $originatorResolvedPrefix, '
        'originatorObservedCounter: $originatorObservedCounter, '
        'bob: $bob, '
        'charlie: $charlie, '
        'ownHost: $ownHost'
        ')';
  }
}

enum BackfillResponseKind { deleted, unresolvable, hint }

class BackfillResponseStateScenario {
  const BackfillResponseStateScenario({
    required this.existingState,
    required this.responseKind,
    required this.existingPayloadType,
    required this.responsePayloadType,
  });

  static const existingEntryId = 'existing-response-entry';
  static const hintEntryId = 'hint-response-entry';

  final GeneratedCounterState existingState;
  final BackfillResponseKind responseKind;
  final SyncSequencePayloadType existingPayloadType;
  final SyncSequencePayloadType responsePayloadType;

  bool get hasExistingEntry => existingState.isStored;

  SyncSequenceStatus? get expectedStatus {
    return switch (responseKind) {
      BackfillResponseKind.deleted => switch (existingState) {
        GeneratedCounterState.absent => null,
        GeneratedCounterState.received => SyncSequenceStatus.received,
        GeneratedCounterState.backfilled => SyncSequenceStatus.backfilled,
        _ => SyncSequenceStatus.deleted,
      },
      BackfillResponseKind.unresolvable => switch (existingState) {
        // Incoming `unresolvable=true` is authoritative for the originator's
        // own counter, so the receiver records it as the terminal [burned]
        // non-event — unless a strictly better local success state already
        // won (received / backfilled / deleted), which is preserved.
        GeneratedCounterState.absent => SyncSequenceStatus.burned,
        GeneratedCounterState.received => SyncSequenceStatus.received,
        GeneratedCounterState.backfilled => SyncSequenceStatus.backfilled,
        GeneratedCounterState.deleted => SyncSequenceStatus.deleted,
        _ => SyncSequenceStatus.burned,
      },
      BackfillResponseKind.hint => switch (existingState) {
        GeneratedCounterState.absent => SyncSequenceStatus.requested,
        GeneratedCounterState.received => SyncSequenceStatus.received,
        GeneratedCounterState.backfilled => SyncSequenceStatus.backfilled,
        GeneratedCounterState.deleted => SyncSequenceStatus.deleted,
        GeneratedCounterState.unresolvable => SyncSequenceStatus.requested,
        _ => existingState.syncStatus,
      },
    };
  }

  String? get expectedEntryId {
    return switch (responseKind) {
      BackfillResponseKind.deleted => hasExistingEntry ? existingEntryId : null,
      BackfillResponseKind.unresolvable => switch (existingState) {
        GeneratedCounterState.absent => null,
        GeneratedCounterState.received => existingEntryId,
        GeneratedCounterState.backfilled => existingEntryId,
        GeneratedCounterState.deleted => existingEntryId,
        _ => null,
      },
      BackfillResponseKind.hint => switch (existingState) {
        GeneratedCounterState.absent => hintEntryId,
        GeneratedCounterState.received => existingEntryId,
        GeneratedCounterState.backfilled => existingEntryId,
        GeneratedCounterState.deleted => existingEntryId,
        _ => hintEntryId,
      },
    };
  }

  SyncSequencePayloadType? get expectedPayloadType {
    if (expectedStatus == null) {
      return null;
    }

    return switch (responseKind) {
      BackfillResponseKind.deleted => existingPayloadType,
      BackfillResponseKind.unresolvable => switch (existingState) {
        GeneratedCounterState.received ||
        GeneratedCounterState.backfilled ||
        GeneratedCounterState.deleted => existingPayloadType,
        _ => responsePayloadType,
      },
      BackfillResponseKind.hint => switch (existingState) {
        GeneratedCounterState.received ||
        GeneratedCounterState.backfilled ||
        GeneratedCounterState.deleted => existingPayloadType,
        _ => responsePayloadType,
      },
    };
  }

  @override
  String toString() {
    return 'BackfillResponseStateScenario('
        'existingState: $existingState, '
        'responseKind: $responseKind, '
        'existingPayloadType: $existingPayloadType, '
        'responsePayloadType: $responsePayloadType'
        ')';
  }
}

class StatefulSequenceEvent {
  const StatefulSequenceEvent({
    required this.observedCounter,
    required this.coveredFlags,
    required this.requestMissingAfter,
  });

  final int observedCounter;
  final List<bool> coveredFlags;
  final bool requestMissingAfter;

  Set<int> get coveredCounters => {
    for (var i = 0; i < coveredFlags.length; i++)
      if (coveredFlags[i]) i + 1,
  };

  int get maxCounter {
    final maxCovered = coveredCounters.isEmpty
        ? 0
        : coveredCounters.reduce((a, b) => a > b ? a : b);
    return observedCounter > maxCovered ? observedCounter : maxCovered;
  }

  @override
  String toString() {
    return 'StatefulSequenceEvent('
        'observedCounter: $observedCounter, '
        'coveredFlags: $coveredFlags, '
        'requestMissingAfter: $requestMissingAfter'
        ')';
  }
}

class StatefulSequenceScenario {
  const StatefulSequenceScenario({
    required this.deferMissingCallback,
    required this.events,
  });

  final bool deferMissingCallback;
  final List<StatefulSequenceEvent> events;

  @override
  String toString() {
    return 'StatefulSequenceScenario('
        'deferMissingCallback: $deferMissingCallback, '
        'events: $events'
        ')';
  }
}

class StatefulSequenceApplyResult {
  const StatefulSequenceApplyResult({
    required this.gaps,
    required this.insertedNewMissing,
    required this.requestedAfter,
  });

  final List<({String hostId, int counter})> gaps;
  final bool insertedNewMissing;
  final List<({String hostId, int counter})> requestedAfter;
}

class StatefulSequenceModel {
  StatefulSequenceModel({required this.hostId});

  final String hostId;
  final Map<int, SyncSequenceStatus> _statuses = {};

  StatefulSequenceApplyResult apply(StatefulSequenceEvent event) {
    for (final counter in event.coveredCounters) {
      if (counter == event.observedCounter) continue;
      final existing = _statuses[counter];
      if (existing == null ||
          existing == SyncSequenceStatus.missing ||
          existing == SyncSequenceStatus.requested) {
        _statuses[counter] = SyncSequenceStatus.received;
      }
    }

    final baseline = lastResolvedPrefix() ?? 0;
    final gapCandidates = expectedHostGaps(
      hostId: hostId,
      resolvedPrefix: baseline,
      observedCounter: event.observedCounter,
      shouldDetectGaps: true,
    );
    final gaps = <({String hostId, int counter})>[];
    var insertedNewMissing = false;
    for (final gap in gapCandidates) {
      final existingStatus = _statuses[gap.counter];
      if (existingStatus == null) {
        gaps.add(gap);
        _statuses[gap.counter] = SyncSequenceStatus.missing;
        insertedNewMissing = true;
      } else if (!existingStatus.isResolvedWatermark) {
        gaps.add(gap);
      }
    }

    final observedStatus = _statuses[event.observedCounter];
    if (observedStatus == SyncSequenceStatus.requested) {
      _statuses[event.observedCounter] = SyncSequenceStatus.backfilled;
    } else if (observedStatus != SyncSequenceStatus.received &&
        observedStatus != SyncSequenceStatus.backfilled) {
      _statuses[event.observedCounter] = SyncSequenceStatus.received;
    }

    final requestedAfter = <({String hostId, int counter})>[];
    if (event.requestMissingAfter) {
      for (final entry in _statuses.entries) {
        if (entry.value == SyncSequenceStatus.missing) {
          requestedAfter.add((hostId: hostId, counter: entry.key));
        }
      }
      for (final requested in requestedAfter) {
        _statuses[requested.counter] = SyncSequenceStatus.requested;
      }
    }

    return StatefulSequenceApplyResult(
      gaps: gaps,
      insertedNewMissing: insertedNewMissing,
      requestedAfter: requestedAfter,
    );
  }

  SyncSequenceStatus? statusAt(int counter) => _statuses[counter];

  int? lastResolvedPrefix() {
    if (_statuses.isEmpty) return null;

    var prefix = 0;
    while (_statuses[prefix + 1]?.isResolvedWatermark ?? false) {
      prefix++;
    }
    return prefix;
  }

  int get maxCounter =>
      _statuses.keys.fold(0, (max, key) => key > max ? key : max);
}

extension GeneratedCounterStateX on GeneratedCounterState {
  bool get isStored => this != GeneratedCounterState.absent;

  bool get isResolvedWatermark =>
      this == GeneratedCounterState.received ||
      this == GeneratedCounterState.backfilled ||
      this == GeneratedCounterState.deleted ||
      this == GeneratedCounterState.unresolvable;

  SyncSequenceStatus get syncStatus {
    return switch (this) {
      GeneratedCounterState.received => SyncSequenceStatus.received,
      GeneratedCounterState.missing => SyncSequenceStatus.missing,
      GeneratedCounterState.requested => SyncSequenceStatus.requested,
      GeneratedCounterState.backfilled => SyncSequenceStatus.backfilled,
      GeneratedCounterState.deleted => SyncSequenceStatus.deleted,
      GeneratedCounterState.unresolvable => SyncSequenceStatus.unresolvable,
      GeneratedCounterState.absent => throw StateError(
        'Absent generated counters do not have a sync status',
      ),
    };
  }
}

extension SyncSequenceStatusX on SyncSequenceStatus {
  bool get isResolvedWatermark =>
      this == SyncSequenceStatus.received ||
      this == SyncSequenceStatus.backfilled ||
      this == SyncSequenceStatus.deleted ||
      this == SyncSequenceStatus.unresolvable ||
      this == SyncSequenceStatus.burned;
}

extension AnySequenceGapScenario on glados.Any {
  glados.Generator<GeneratedCounterState> get generatedCounterState =>
      glados.AnyUtils(this).choose(GeneratedCounterState.values);

  glados.Generator<BackfillResponseKind> get backfillResponseKind =>
      glados.AnyUtils(this).choose(BackfillResponseKind.values);

  glados.Generator<SyncSequencePayloadType> get generatedPayloadType =>
      glados.AnyUtils(this).choose(SyncSequencePayloadType.values);

  glados.Generator<BackfillResponseStateScenario>
  get backfillResponseStateScenario => glados.CombinableAny(this).combine4(
    generatedCounterState,
    backfillResponseKind,
    generatedPayloadType,
    generatedPayloadType,
    (
      GeneratedCounterState existingState,
      BackfillResponseKind responseKind,
      SyncSequencePayloadType existingPayloadType,
      SyncSequencePayloadType responsePayloadType,
    ) => BackfillResponseStateScenario(
      existingState: existingState,
      responseKind: responseKind,
      existingPayloadType: existingPayloadType,
      responsePayloadType: responsePayloadType,
    ),
  );

  glados.Generator<SequenceGapScenario> get sequenceGapScenario =>
      glados.CombinableAny(this).combine2(
        glados.IntAnys(this).intInRange(1, 13),
        glados.ListAnys(
          this,
        ).listWithLengthInRange(8, 9, generatedCounterState),
        (int observedCounter, List<GeneratedCounterState> counterStates) =>
            SequenceGapScenario(
              observedCounter: observedCounter,
              counterStates: counterStates,
            ),
      );

  glados.Generator<CoveredClockGapScenario> get coveredClockGapScenario =>
      glados.CombinableAny(this).combine2(
        glados.IntAnys(this).intInRange(1, 13),
        glados.ListAnys(
          this,
        ).listWithLengthInRange(8, 9, glados.BoolAny(this).bool),
        (int observedCounter, List<bool> coveredFlags) =>
            CoveredClockGapScenario(
              observedCounter: observedCounter,
              coveredFlags: coveredFlags,
            ),
      );

  glados.Generator<GeneratedHostClock> get generatedHostClock =>
      glados.CombinableAny(this).combine4(
        glados.BoolAny(this).bool,
        glados.BoolAny(this).bool,
        glados.IntAnys(this).intInRange(0, 7),
        glados.IntAnys(this).intInRange(1, 13),
        (
          bool included,
          bool knownOnline,
          int resolvedPrefix,
          int observedCounter,
        ) => GeneratedHostClock(
          included: included,
          knownOnline: knownOnline,
          resolvedPrefix: resolvedPrefix,
          observedCounter: observedCounter,
        ),
      );

  glados.Generator<MultiHostGapScenario> get multiHostGapScenario =>
      glados.CombinableAny(this).combine5(
        glados.IntAnys(this).intInRange(0, 7),
        glados.IntAnys(this).intInRange(1, 13),
        generatedHostClock,
        generatedHostClock,
        generatedHostClock,
        (
          int originatorResolvedPrefix,
          int originatorObservedCounter,
          GeneratedHostClock bob,
          GeneratedHostClock charlie,
          GeneratedHostClock ownHost,
        ) => MultiHostGapScenario(
          originatorResolvedPrefix: originatorResolvedPrefix,
          originatorObservedCounter: originatorObservedCounter,
          bob: bob,
          charlie: charlie,
          ownHost: ownHost,
        ),
      );

  glados.Generator<StatefulSequenceEvent> get statefulSequenceEvent =>
      glados.CombinableAny(this).combine3(
        glados.IntAnys(this).intInRange(1, 17),
        glados.ListAnys(
          this,
        ).listWithLengthInRange(12, 13, glados.BoolAny(this).bool),
        glados.BoolAny(this).bool,
        (
          int observedCounter,
          List<bool> coveredFlags,
          bool requestMissingAfter,
        ) => StatefulSequenceEvent(
          observedCounter: observedCounter,
          coveredFlags: coveredFlags,
          requestMissingAfter: requestMissingAfter,
        ),
      );

  glados.Generator<StatefulSequenceScenario> get statefulSequenceScenario =>
      glados.CombinableAny(this).combine2(
        glados.BoolAny(this).bool,
        glados.ListAnys(
          this,
        ).listWithLengthInRange(1, 7, statefulSequenceEvent),
        (bool deferMissingCallback, List<StatefulSequenceEvent> events) =>
            StatefulSequenceScenario(
              deferMissingCallback: deferMissingCallback,
              events: events,
            ),
      );
}

List<({String hostId, int counter})> expectedHostGaps({
  required String hostId,
  required int resolvedPrefix,
  required int observedCounter,
  required bool shouldDetectGaps,
}) {
  if (!shouldDetectGaps || observedCounter <= resolvedPrefix + 1) {
    return const [];
  }
  return [
    for (var counter = resolvedPrefix + 1; counter < observedCounter; counter++)
      (hostId: hostId, counter: counter),
  ];
}

int? expectedPrefixAfterObserved({
  required int resolvedPrefix,
  required int observedCounter,
  required bool observedRecorded,
}) {
  if (!observedRecorded) return resolvedPrefix == 0 ? null : resolvedPrefix;
  return observedCounter == resolvedPrefix + 1
      ? resolvedPrefix + 1
      : resolvedPrefix;
}

Future<void> seedGeneratedSequenceScenario({
  required SyncDatabase database,
  required String hostId,
  required SequenceGapScenario scenario,
}) async {
  final seedDate = DateTime(2024, 3, 15, 10);
  for (var index = 0; index < scenario.counterStates.length; index++) {
    final state = scenario.counterStates[index];
    if (!state.isStored) continue;

    final counter = index + 1;
    await database.recordSequenceEntry(
      SyncSequenceLogCompanion(
        hostId: Value(hostId),
        counter: Value(counter),
        entryId: Value('seeded-$counter'),
        originatingHostId: Value(hostId),
        status: Value(state.syncStatus.index),
        createdAt: Value(seedDate),
        updatedAt: Value(seedDate),
      ),
    );
  }
}

Future<void> seedResolvedPrefix({
  required SyncDatabase database,
  required String hostId,
  required int resolvedPrefix,
}) async {
  final seedDate = DateTime(2024, 3, 15, 10);
  for (var counter = 1; counter <= resolvedPrefix; counter++) {
    await database.recordSequenceEntry(
      SyncSequenceLogCompanion(
        hostId: Value(hostId),
        counter: Value(counter),
        entryId: Value('seeded-$hostId-$counter'),
        originatingHostId: Value(hostId),
        status: Value(SyncSequenceStatus.received.index),
        createdAt: Value(seedDate),
        updatedAt: Value(seedDate),
      ),
    );
  }
}

class RealSequenceLogTestBench {
  RealSequenceLogTestBench._({required this.database, required this.service});

  factory RealSequenceLogTestBench.create({required String myHostId}) {
    final database = SyncDatabase(inMemoryDatabase: true, background: false);
    final vcService = MockVectorClockService();
    final logging = MockDomainLogger();
    final bench = RealSequenceLogTestBench._(
      database: database,
      service: SyncSequenceLogService(
        syncDatabase: database,
        vectorClockService: vcService,
        loggingService: logging,
      ),
    );
    bench.service.onMissingEntriesDetected = () {
      bench.missingCallbackCount++;
    };

    when(vcService.getHost).thenAnswer((_) async => myHostId);
    when(
      () => logging.log(
        any<LogDomain>(),
        any<String>(),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenReturn(null);
    when(
      () => logging.error(
        any<LogDomain>(),
        any<Object>(),
        stackTrace: any<StackTrace>(named: 'stackTrace'),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenAnswer((_) async {});

    return bench;
  }

  final SyncDatabase database;
  final SyncSequenceLogService service;
  int missingCallbackCount = 0;

  Future<void> close() => database.close();
}

Future<void> expectObservedCounter({
  required SyncDatabase database,
  required String hostId,
  required int counter,
  required String entryId,
}) async {
  final entry = await database.getEntryByHostAndCounter(hostId, counter);
  expect(entry, isNotNull);
  expect(entry?.entryId, entryId);
  expect(entry?.status, SyncSequenceStatus.received.index);
}

SyncSequenceLogItem createLogItem(
  String hostId,
  int counter, {
  SyncSequenceStatus status = SyncSequenceStatus.missing,
  String? entryId,
  String? originatingHostId,
}) {
  return SyncSequenceLogItem(
    hostId: hostId,
    counter: counter,
    entryId: entryId,
    payloadType: 0, // SyncSequencePayloadType.journalEntity.index
    originatingHostId: originatingHostId,
    status: status.index,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
    requestCount: 0,
  );
}

/// Registers the fallback values shared by the split facade suites.
void registerSyncSequenceLogFallbackValues() {
  registerFallbackValue(
    SyncSequenceLogCompanion(
      hostId: const Value(''),
      counter: const Value(0),
      status: const Value(0),
      createdAt: Value(DateTime(2024)),
      updatedAt: Value(DateTime(2024)),
    ),
  );
  registerFallbackValue(SyncSequenceStatus.received);
  registerFallbackValue(SyncSequencePayloadType.journalEntity);
  registerFallbackValue(Duration.zero);
}

/// Shared mock wiring for the split [SyncSequenceLogService] facade suites.
class SyncSequenceLogServiceTestBench {
  SyncSequenceLogServiceTestBench._({
    required this.mockDb,
    required this.mockVcService,
    required this.mockLogging,
    required this.service,
  });

  factory SyncSequenceLogServiceTestBench.create({
    required String myHostId,
    required String aliceHostId,
    required String bobHostId,
  }) {
    final mockDb = MockSyncDatabase();
    final mockVcService = MockVectorClockService();
    final mockLogging = MockDomainLogger();

    when(mockVcService.getHost).thenAnswer((_) async => myHostId);
    when(
      () => mockLogging.log(
        any<LogDomain>(),
        any<String>(),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenReturn(null);
    when(
      () => mockDb.updateHostActivity(any(), any()),
    ).thenAnswer((_) async => 1);
    when(
      () => mockDb.getCountersForHostInRange(any(), any(), any()),
    ).thenAnswer((_) async => <int>{});
    when(
      () => mockDb.batchInsertSequenceEntries(any()),
    ).thenAnswer((_) async {});
    when(
      () => mockDb.getHostLastSeen(aliceHostId),
    ).thenAnswer((_) async => DateTime(2025, 1, 1));
    when(
      () => mockDb.getHostLastSeen(bobHostId),
    ).thenAnswer((_) async => DateTime(2025, 1, 1));
    when(
      () => mockDb.getPendingEntriesByPayloadId(
        payloadType: any(named: 'payloadType'),
        payloadId: any(named: 'payloadId'),
      ),
    ).thenAnswer((_) async => []);

    return SyncSequenceLogServiceTestBench._(
      mockDb: mockDb,
      mockVcService: mockVcService,
      mockLogging: mockLogging,
      service: SyncSequenceLogService(
        syncDatabase: mockDb,
        vectorClockService: mockVcService,
        loggingService: mockLogging,
      ),
    );
  }

  final MockSyncDatabase mockDb;
  final MockVectorClockService mockVcService;
  final MockDomainLogger mockLogging;
  final SyncSequenceLogService service;
}
