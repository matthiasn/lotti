import 'dart:convert';

import 'package:glados/glados.dart' as glados;
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';

class GeneratedStreamEvent {
  const GeneratedStreamEvent({
    required this.eventSlot,
    required this.timestampBucket,
    required this.payload,
    required this.completed,
  });

  final int eventSlot;
  final int timestampBucket;
  final bool payload;
  final bool completed;

  String get eventId => '\$generated-$eventSlot';

  int get timestampMs => 1000 + timestampBucket;

  @override
  String toString() {
    return 'GeneratedStreamEvent('
        'eventSlot: $eventSlot, '
        'timestampBucket: $timestampBucket, '
        'payload: $payload, '
        'completed: $completed'
        ')';
  }
}

class GeneratedLiveScanSliceScenario {
  const GeneratedLiveScanSliceScenario({
    required this.events,
    required this.useLastEventId,
    required this.lastEventSlot,
    required this.tailLimit,
    required this.hasLastTimestamp,
    required this.lastTimestampBucket,
  });

  final List<GeneratedStreamEvent> events;
  final bool useLastEventId;
  final int lastEventSlot;
  final int tailLimit;
  final bool hasLastTimestamp;
  final int lastTimestampBucket;

  String? get lastEventId =>
      useLastEventId ? '\$generated-$lastEventSlot' : null;

  int? get lastTimestamp =>
      hasLastTimestamp ? 1000 + lastTimestampBucket : null;

  List<String> expectedEventIds() {
    final ordered =
        <({int index, GeneratedStreamEvent event})>[
          for (var index = 0; index < events.length; index++)
            (index: index, event: events[index]),
        ]..sort((a, b) {
          final timestampCompare = a.event.timestampMs.compareTo(
            b.event.timestampMs,
          );
          if (timestampCompare != 0) return timestampCompare;
          return a.index.compareTo(b.index);
        });

    final marker = lastEventId;
    var markerIndex = -1;
    if (marker != null) {
      for (var index = ordered.length - 1; index >= 0; index--) {
        if (ordered[index].event.eventId == marker) {
          markerIndex = index;
          break;
        }
      }
    }

    final slice = markerIndex >= 0
        ? ordered.sublist(markerIndex + 1)
        : ordered.isEmpty
        ? ordered
        : ordered.sublist(
            (ordered.length - tailLimit).clamp(0, ordered.length),
          );

    final seen = <String>{};
    return [
      for (final item in slice)
        if (seen.add(item.event.eventId)) item.event.eventId,
    ];
  }

  @override
  String toString() {
    return 'GeneratedLiveScanSliceScenario('
        'events: $events, '
        'useLastEventId: $useLastEventId, '
        'lastEventSlot: $lastEventSlot, '
        'tailLimit: $tailLimit, '
        'hasLastTimestamp: $hasLastTimestamp, '
        'lastTimestampBucket: $lastTimestampBucket'
        ')';
  }
}

class GeneratedMonotonicFilterScenario {
  const GeneratedMonotonicFilterScenario({
    required this.events,
    required this.dropOldSyncPayloads,
    required this.hasMarker,
    required this.markerEventSlot,
    required this.markerTimestampBucket,
  });

  final List<GeneratedStreamEvent> events;
  final bool dropOldSyncPayloads;
  final bool hasMarker;
  final int markerEventSlot;
  final int markerTimestampBucket;

  String? get markerEventId =>
      hasMarker ? '\$generated-$markerEventSlot' : null;

  int? get markerTimestamp => hasMarker ? 1000 + markerTimestampBucket : null;

  Set<String> get completedEventIds => {
    for (final event in events)
      if (event.completed) event.eventId,
  };

  List<String> expectedEventIds() {
    if (!dropOldSyncPayloads) {
      return [for (final event in events) event.eventId];
    }
    return [
      for (final event in events)
        if (hKeeps(event)) event.eventId,
    ];
  }

  int expectedSkippedCount() {
    if (!dropOldSyncPayloads) return 0;
    return events.where((event) => !hKeeps(event)).length;
  }

  bool hKeeps(GeneratedStreamEvent event) {
    if (!event.payload) return true;
    final newer = hIsNewer(event);
    return newer || !completedEventIds.contains(event.eventId);
  }

  bool hIsNewer(GeneratedStreamEvent event) {
    final latestTimestamp = markerTimestamp;
    final latestEventId = markerEventId;
    if (latestTimestamp == null || latestEventId == null) return true;
    if (event.timestampMs > latestTimestamp) return true;
    if (event.timestampMs < latestTimestamp) return false;
    return event.eventId.compareTo(latestEventId) > 0;
  }

  @override
  String toString() {
    return 'GeneratedMonotonicFilterScenario('
        'events: $events, '
        'dropOldSyncPayloads: $dropOldSyncPayloads, '
        'hasMarker: $hasMarker, '
        'markerEventSlot: $markerEventSlot, '
        'markerTimestampBucket: $markerTimestampBucket'
        ')';
  }
}

extension AnyMatrixStreamHelperScenario on glados.Any {
  glados.Generator<GeneratedStreamEvent> get streamEvent =>
      glados.CombinableAny(this).combine4(
        glados.IntAnys(this).intInRange(0, 7),
        glados.IntAnys(this).intInRange(0, 7),
        glados.BoolAny(this).bool,
        glados.BoolAny(this).bool,
        (
          int eventSlot,
          int timestampBucket,
          bool payload,
          bool completed,
        ) => GeneratedStreamEvent(
          eventSlot: eventSlot,
          timestampBucket: timestampBucket,
          payload: payload,
          completed: completed,
        ),
      );

  glados.Generator<GeneratedLiveScanSliceScenario> get liveScanSliceScenario =>
      glados.CombinableAny(this).combine6(
        glados.ListAnys(this).listWithLengthInRange(0, 14, streamEvent),
        glados.BoolAny(this).bool,
        glados.IntAnys(this).intInRange(0, 7),
        glados.IntAnys(this).intInRange(1, 7),
        glados.BoolAny(this).bool,
        glados.IntAnys(this).intInRange(0, 7),
        (
          List<GeneratedStreamEvent> events,
          bool useLastEventId,
          int lastEventSlot,
          int tailLimit,
          bool hasLastTimestamp,
          int lastTimestampBucket,
        ) => GeneratedLiveScanSliceScenario(
          events: events,
          useLastEventId: useLastEventId,
          lastEventSlot: lastEventSlot,
          tailLimit: tailLimit,
          hasLastTimestamp: hasLastTimestamp,
          lastTimestampBucket: lastTimestampBucket,
        ),
      );

  glados.Generator<GeneratedMonotonicFilterScenario>
  get monotonicFilterScenario => glados.CombinableAny(this).combine5(
    glados.ListAnys(this).listWithLengthInRange(1, 14, streamEvent),
    glados.BoolAny(this).bool,
    glados.BoolAny(this).bool,
    glados.IntAnys(this).intInRange(0, 7),
    glados.IntAnys(this).intInRange(0, 7),
    (
      List<GeneratedStreamEvent> events,
      bool dropOldSyncPayloads,
      bool hasMarker,
      int markerEventSlot,
      int markerTimestampBucket,
    ) => GeneratedMonotonicFilterScenario(
      events: events,
      dropOldSyncPayloads: dropOldSyncPayloads,
      hasMarker: hasMarker,
      markerEventSlot: markerEventSlot,
      markerTimestampBucket: markerTimestampBucket,
    ),
  );
}

Event hBuildGeneratedEvent(GeneratedStreamEvent generated) {
  final event = MockEvent();
  when(() => event.eventId).thenReturn(generated.eventId);
  when(
    () => event.originServerTs,
  ).thenReturn(DateTime.fromMillisecondsSinceEpoch(generated.timestampMs));
  when(() => event.text).thenReturn(
    generated.payload ? hEncodedSyncPayloadText(generated.eventId) : '',
  );
  when(
    () => event.attachmentMimetype,
  ).thenReturn(generated.payload ? '' : 'image/png');
  when(() => event.content).thenReturn(<String, dynamic>{});
  return event;
}

String hEncodedSyncPayloadText(String id) {
  return base64.encode(
    utf8.encode(
      json.encode(<String, dynamic>{
        'runtimeType': 'journalEntity',
        'jsonPath': '/generated/$id.json',
      }),
    ),
  );
}
