import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/sync/matrix/pipeline/matrix_stream_helpers.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';

class _GeneratedStreamEvent {
  const _GeneratedStreamEvent({
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
    return '_GeneratedStreamEvent('
        'eventSlot: $eventSlot, '
        'timestampBucket: $timestampBucket, '
        'payload: $payload, '
        'completed: $completed'
        ')';
  }
}

class _GeneratedLiveScanSliceScenario {
  const _GeneratedLiveScanSliceScenario({
    required this.events,
    required this.useLastEventId,
    required this.lastEventSlot,
    required this.tailLimit,
    required this.hasLastTimestamp,
    required this.lastTimestampBucket,
  });

  final List<_GeneratedStreamEvent> events;
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
        <({int index, _GeneratedStreamEvent event})>[
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
    return '_GeneratedLiveScanSliceScenario('
        'events: $events, '
        'useLastEventId: $useLastEventId, '
        'lastEventSlot: $lastEventSlot, '
        'tailLimit: $tailLimit, '
        'hasLastTimestamp: $hasLastTimestamp, '
        'lastTimestampBucket: $lastTimestampBucket'
        ')';
  }
}

class _GeneratedMonotonicFilterScenario {
  const _GeneratedMonotonicFilterScenario({
    required this.events,
    required this.dropOldSyncPayloads,
    required this.hasMarker,
    required this.markerEventSlot,
    required this.markerTimestampBucket,
  });

  final List<_GeneratedStreamEvent> events;
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
        if (_keeps(event)) event.eventId,
    ];
  }

  int expectedSkippedCount() {
    if (!dropOldSyncPayloads) return 0;
    return events.where((event) => !_keeps(event)).length;
  }

  bool _keeps(_GeneratedStreamEvent event) {
    if (!event.payload) return true;
    final newer = _isNewer(event);
    return newer || !completedEventIds.contains(event.eventId);
  }

  bool _isNewer(_GeneratedStreamEvent event) {
    final latestTimestamp = markerTimestamp;
    final latestEventId = markerEventId;
    if (latestTimestamp == null || latestEventId == null) return true;
    if (event.timestampMs > latestTimestamp) return true;
    if (event.timestampMs < latestTimestamp) return false;
    return event.eventId.compareTo(latestEventId) > 0;
  }

  @override
  String toString() {
    return '_GeneratedMonotonicFilterScenario('
        'events: $events, '
        'dropOldSyncPayloads: $dropOldSyncPayloads, '
        'hasMarker: $hasMarker, '
        'markerEventSlot: $markerEventSlot, '
        'markerTimestampBucket: $markerTimestampBucket'
        ')';
  }
}

extension _AnyMatrixStreamHelperScenario on glados.Any {
  glados.Generator<_GeneratedStreamEvent> get streamEvent =>
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
        ) => _GeneratedStreamEvent(
          eventSlot: eventSlot,
          timestampBucket: timestampBucket,
          payload: payload,
          completed: completed,
        ),
      );

  glados.Generator<_GeneratedLiveScanSliceScenario> get liveScanSliceScenario =>
      glados.CombinableAny(this).combine6(
        glados.ListAnys(this).listWithLengthInRange(0, 14, streamEvent),
        glados.BoolAny(this).bool,
        glados.IntAnys(this).intInRange(0, 7),
        glados.IntAnys(this).intInRange(1, 7),
        glados.BoolAny(this).bool,
        glados.IntAnys(this).intInRange(0, 7),
        (
          List<_GeneratedStreamEvent> events,
          bool useLastEventId,
          int lastEventSlot,
          int tailLimit,
          bool hasLastTimestamp,
          int lastTimestampBucket,
        ) => _GeneratedLiveScanSliceScenario(
          events: events,
          useLastEventId: useLastEventId,
          lastEventSlot: lastEventSlot,
          tailLimit: tailLimit,
          hasLastTimestamp: hasLastTimestamp,
          lastTimestampBucket: lastTimestampBucket,
        ),
      );

  glados.Generator<_GeneratedMonotonicFilterScenario>
  get monotonicFilterScenario => glados.CombinableAny(this).combine5(
    glados.ListAnys(this).listWithLengthInRange(1, 14, streamEvent),
    glados.BoolAny(this).bool,
    glados.BoolAny(this).bool,
    glados.IntAnys(this).intInRange(0, 7),
    glados.IntAnys(this).intInRange(0, 7),
    (
      List<_GeneratedStreamEvent> events,
      bool dropOldSyncPayloads,
      bool hasMarker,
      int markerEventSlot,
      int markerTimestampBucket,
    ) => _GeneratedMonotonicFilterScenario(
      events: events,
      dropOldSyncPayloads: dropOldSyncPayloads,
      hasMarker: hasMarker,
      markerEventSlot: markerEventSlot,
      markerTimestampBucket: markerTimestampBucket,
    ),
  );
}

Event _buildGeneratedEvent(_GeneratedStreamEvent generated) {
  final event = MockEvent();
  when(() => event.eventId).thenReturn(generated.eventId);
  when(
    () => event.originServerTs,
  ).thenReturn(DateTime.fromMillisecondsSinceEpoch(generated.timestampMs));
  when(() => event.text).thenReturn(
    generated.payload ? _encodedSyncPayloadText(generated.eventId) : '',
  );
  when(
    () => event.attachmentMimetype,
  ).thenReturn(generated.payload ? '' : 'image/png');
  when(() => event.content).thenReturn(<String, dynamic>{});
  return event;
}

String _encodedSyncPayloadText(String id) {
  return base64.encode(
    utf8.encode(
      json.encode(<String, dynamic>{
        'runtimeType': 'journalEntity',
        'jsonPath': '/generated/$id.json',
      }),
    ),
  );
}

void main() {
  group('matrix_stream_helpers', () {
    test(
      'extractRuntimeTypeFromEvent returns runtimeType from base64 JSON',
      () {
        final ev = MockEvent();
        final jsonPayload = <String, dynamic>{
          'runtimeType': 'entryLink',
          'id': 'abc',
        };
        final text = base64.encode(utf8.encode(json.encode(jsonPayload)));
        when(() => ev.text).thenReturn(text);

        expect(extractRuntimeTypeFromEvent(ev), 'entryLink');
      },
    );

    test('extractRuntimeTypeFromEvent returns null for invalid/empty text', () {
      final ev1 = MockEvent();
      when(() => ev1.text).thenReturn('');
      final ev2 = MockEvent();
      when(() => ev2.text).thenReturn('not-base64');

      expect(extractRuntimeTypeFromEvent(ev1), isNull);
      expect(extractRuntimeTypeFromEvent(ev2), isNull);
    });

    test('extractJsonPathFromEvent returns jsonPath for journalEntity', () {
      final ev = MockEvent();
      final jsonPayload = <String, dynamic>{
        'runtimeType': 'journalEntity',
        'jsonPath': '/sub/a.json',
      };
      final text = base64.encode(utf8.encode(json.encode(jsonPayload)));
      when(() => ev.text).thenReturn(text);

      expect(extractJsonPathFromEvent(ev), '/sub/a.json');
    });

    test('extractJsonPathFromEvent returns jsonPath for agentEntity', () {
      final ev = MockEvent();
      final jsonPayload = <String, dynamic>{
        'runtimeType': 'agentEntity',
        'jsonPath': '/agent_entities/agent-1.json',
      };
      final text = base64.encode(utf8.encode(json.encode(jsonPayload)));
      when(() => ev.text).thenReturn(text);

      expect(
        extractJsonPathFromEvent(ev),
        '/agent_entities/agent-1.json',
      );
    });

    test('extractJsonPathFromEvent returns jsonPath for agentLink', () {
      final ev = MockEvent();
      final jsonPayload = <String, dynamic>{
        'runtimeType': 'agentLink',
        'jsonPath': '/agent_links/link-1.json',
      };
      final text = base64.encode(utf8.encode(json.encode(jsonPayload)));
      when(() => ev.text).thenReturn(text);

      expect(
        extractJsonPathFromEvent(ev),
        '/agent_links/link-1.json',
      );
    });

    test('extractJsonPathFromEvent returns jsonPath for agentBundle', () {
      final ev = MockEvent();
      final jsonPayload = <String, dynamic>{
        'runtimeType': 'agentBundle',
        'jsonPath': '/agent_bundles/run-1.json',
      };
      final text = base64.encode(utf8.encode(json.encode(jsonPayload)));
      when(() => ev.text).thenReturn(text);

      expect(
        extractJsonPathFromEvent(ev),
        '/agent_bundles/run-1.json',
      );
    });

    test(
      'extractJsonPathFromEvent returns jsonPath for outboxBundle — the '
      'receiver-side attachment ingestor relies on this lookup to download '
      'the sidecar holding the bundle children',
      () {
        final ev = MockEvent();
        final jsonPayload = <String, dynamic>{
          'runtimeType': 'outboxBundle',
          'jsonPath': '/outbox_bundles/abc-123.json',
        };
        final text = base64.encode(utf8.encode(json.encode(jsonPayload)));
        when(() => ev.text).thenReturn(text);

        expect(
          extractJsonPathFromEvent(ev),
          '/outbox_bundles/abc-123.json',
        );
      },
    );

    test(
      'extractJsonPathFromEvent returns null for unsupported runtimeType',
      () {
        final ev = MockEvent();
        final jsonPayload = <String, dynamic>{
          'runtimeType': 'entryLink',
          'jsonPath': '/some/path.json',
        };
        final text = base64.encode(utf8.encode(json.encode(jsonPayload)));
        when(() => ev.text).thenReturn(text);

        expect(extractJsonPathFromEvent(ev), isNull);
      },
    );

    test(
      'isLikelySyncPayloadText detects valid base64 JSON with runtimeType',
      () {
        final valid = base64.encode(
          utf8.encode(
            json.encode(<String, dynamic>{
              'runtimeType': 'journalEntity',
            }),
          ),
        );
        final invalidJson = base64.encode(utf8.encode('not json'));

        expect(isLikelySyncPayloadText(valid), isTrue);
        expect(isLikelySyncPayloadText(invalidJson), isFalse);
        expect(isLikelySyncPayloadText(''), isFalse);
        expect(isLikelySyncPayloadText('not-base64'), isFalse);
      },
    );

    test('ringBufferAdd enforces max size, evicts oldest', () {
      final buf = <String>[];
      ringBufferAdd(buf, 'a', 2);
      ringBufferAdd(buf, 'b', 2);
      ringBufferAdd(buf, 'c', 2);

      expect(buf, ['b', 'c']);
      ringBufferAdd(buf, 'd', 2);
      expect(buf, ['c', 'd']);
    });

    test('shouldAdvanceMarker follows TimelineEventOrdering', () {
      // No last processed -> advance
      expect(
        shouldAdvanceMarker(
          candidateTimestamp: 2,
          candidateEventId: 'b',
          lastTimestamp: null,
          lastEventId: null,
        ),
        isTrue,
      );
      // Earlier timestamp -> no advance
      expect(
        shouldAdvanceMarker(
          candidateTimestamp: 1,
          candidateEventId: 'b',
          lastTimestamp: 2,
          lastEventId: 'a',
        ),
        isFalse,
      );
      // Same ts, higher id -> advance
      expect(
        shouldAdvanceMarker(
          candidateTimestamp: 2,
          candidateEventId: 'b',
          lastTimestamp: 2,
          lastEventId: 'a',
        ),
        isTrue,
      );
    });

    test('computeNextScanDelay picks earliestNextDue or default', () {
      final now = DateTime.fromMillisecondsSinceEpoch(1000);
      final later = DateTime.fromMillisecondsSinceEpoch(1200);
      final earlier = DateTime.fromMillisecondsSinceEpoch(900);
      expect(
        computeNextScanDelay(now, later),
        const Duration(milliseconds: 200),
      );
      expect(
        computeNextScanDelay(now, earlier),
        const Duration(milliseconds: 200),
      );
      expect(
        computeNextScanDelay(now, null),
        const Duration(milliseconds: 200),
      );
      expect(
        computeNextScanDelay(
          now,
          later,
          defaultDelay: const Duration(milliseconds: 50),
        ),
        const Duration(milliseconds: 200),
      );
    });

    test('ignoredReasonFromStatus maps to older/equal/unknown', () {
      expect(ignoredReasonFromStatus('a_gt_a'), 'older');
      expect(ignoredReasonFromStatus('a_gt_b'), 'older');
      expect(ignoredReasonFromStatus('equal'), 'equal');
      expect(ignoredReasonFromStatus('x'), 'unknown');
    });

    test('buildLiveScanSlice slices strictly after lastEventId', () {
      final e1 = MockEvent();
      when(() => e1.eventId).thenReturn('a');
      when(
        () => e1.originServerTs,
      ).thenReturn(DateTime.fromMillisecondsSinceEpoch(1));
      final e2 = MockEvent();
      when(() => e2.eventId).thenReturn('b');
      when(
        () => e2.originServerTs,
      ).thenReturn(DateTime.fromMillisecondsSinceEpoch(2));
      final e3 = MockEvent();
      when(() => e3.eventId).thenReturn('c');
      when(
        () => e3.originServerTs,
      ).thenReturn(DateTime.fromMillisecondsSinceEpoch(3));

      final slice = buildLiveScanSlice(
        timelineEvents: [e2, e1, e3],
        lastEventId: 'b',
        tailLimit: 50,
        lastTimestamp: null,
      );
      expect(slice.map((e) => e.eventId), ['c']);
    });

    test('buildLiveScanSlice returns last N when no lastEventId', () {
      final es = <MockEvent>[];
      for (var i = 0; i < 5; i++) {
        final e = MockEvent();
        when(() => e.eventId).thenReturn('e$i');
        when(
          () => e.originServerTs,
        ).thenReturn(DateTime.fromMillisecondsSinceEpoch(i));
        es.add(e);
      }
      final slice = buildLiveScanSlice(
        timelineEvents: es,
        lastEventId: null,
        tailLimit: 2,
        lastTimestamp: null,
      );
      expect(slice.map((e) => e.eventId), ['e3', 'e4']);
    });

    test('buildLiveScanSlice ignores timestamp cutoff (removed)', () {
      final older = MockEvent();
      when(() => older.eventId).thenReturn('old');
      when(
        () => older.originServerTs,
      ).thenReturn(DateTime.fromMillisecondsSinceEpoch(1000));
      final newer = MockEvent();
      when(() => newer.eventId).thenReturn('new');
      when(
        () => newer.originServerTs,
      ).thenReturn(DateTime.fromMillisecondsSinceEpoch(3000));

      final slice = buildLiveScanSlice(
        timelineEvents: [older, newer],
        lastEventId: null,
        tailLimit: 10,
        lastTimestamp: 3000,
      );
      expect(slice.map((e) => e.eventId), ['old', 'new']);
    });

    test('buildLiveScanSlice deduplicates by eventId preserving order', () {
      final a1 = MockEvent();
      when(() => a1.eventId).thenReturn('a');
      when(
        () => a1.originServerTs,
      ).thenReturn(DateTime.fromMillisecondsSinceEpoch(1));
      final a2 = MockEvent();
      when(() => a2.eventId).thenReturn('a');
      when(
        () => a2.originServerTs,
      ).thenReturn(DateTime.fromMillisecondsSinceEpoch(1));
      final b = MockEvent();
      when(() => b.eventId).thenReturn('b');
      when(
        () => b.originServerTs,
      ).thenReturn(DateTime.fromMillisecondsSinceEpoch(2));

      final slice = buildLiveScanSlice(
        timelineEvents: [a2, b, a1],
        lastEventId: null,
        tailLimit: 10,
        lastTimestamp: null,
      );
      expect(slice.map((e) => e.eventId), ['a', 'b']);
    });

    glados.Glados(
      glados.any.liveScanSliceScenario,
    ).test(
      'generated live scan slices match the stable sort/tail/dedupe model',
      (scenario) {
        final slice = buildLiveScanSlice(
          timelineEvents: [
            for (final event in scenario.events) _buildGeneratedEvent(event),
          ],
          lastEventId: scenario.lastEventId,
          tailLimit: scenario.tailLimit,
          lastTimestamp: scenario.lastTimestamp,
        );

        expect(
          slice.map((event) => event.eventId).toList(),
          scenario.expectedEventIds(),
        );
      },
      tags: 'glados',
    );

    test(
      'filterSyncPayloadsByMonotonic drops old payloads, keeps retries/attachments',
      () {
        Event mk(String id, int ts, {bool payload = true}) {
          final e = MockEvent();
          when(() => e.eventId).thenReturn(id);
          when(
            () => e.originServerTs,
          ).thenReturn(DateTime.fromMillisecondsSinceEpoch(ts));
          if (payload) {
            final jsonPayload = <String, dynamic>{
              'runtimeType': 'journalEntity',
              'jsonPath': '/x.json',
            };
            final text = base64.encode(utf8.encode(json.encode(jsonPayload)));
            when(() => e.text).thenReturn(text);
            when(() => e.attachmentMimetype).thenReturn('');
          } else {
            when(() => e.text).thenReturn('');
            when(() => e.attachmentMimetype).thenReturn('image/png');
          }
          when(() => e.content).thenReturn(<String, dynamic>{});
          return e;
        }

        final old = mk('E0', 100);
        final equal = mk('E1', 200);
        final newer = mk('E2', 201);
        final att = mk('A1', 50, payload: false);
        var skipped = 0;

        // With nothing completed: keep all events (including ones with pending retries)
        // This fixes the bug where failed events were incorrectly dropped
        final kept = filterSyncPayloadsByMonotonic(
          events: [old, equal, newer, att],
          dropOldSyncPayloads: true,
          lastTimestamp: 200,
          lastEventId: 'E1',
          wasCompleted: (_) => false,
          onSkipped: () => skipped++,
        );
        expect(
          kept.map((e) => e.eventId),
          containsAll(['E0', 'E1', 'E2', 'A1']),
        );
        expect(skipped, 0);

        // Mark old events as completed -> they get dropped
        skipped = 0;
        final kept2 = filterSyncPayloadsByMonotonic(
          events: [old, equal, newer, att],
          dropOldSyncPayloads: true,
          lastTimestamp: 200,
          lastEventId: 'E1',
          wasCompleted: (id) => id == 'E0' || id == 'E1',
          onSkipped: () => skipped++,
        );
        expect(kept2.map((e) => e.eventId), containsAll(['E2', 'A1']));
        expect(
          kept2.any((e) => e.eventId == 'E0' || e.eventId == 'E1'),
          isFalse,
        );
        expect(skipped, 2);
      },
    );

    glados.Glados(
      glados.any.monotonicFilterScenario,
    ).test(
      'generated monotonic filtering keeps attachments and pending retries',
      (scenario) {
        var skipped = 0;
        final kept = filterSyncPayloadsByMonotonic(
          events: [
            for (final event in scenario.events) _buildGeneratedEvent(event),
          ],
          dropOldSyncPayloads: scenario.dropOldSyncPayloads,
          lastTimestamp: scenario.markerTimestamp,
          lastEventId: scenario.markerEventId,
          wasCompleted: scenario.completedEventIds.contains,
          onSkipped: () => skipped++,
        );

        expect(
          kept.map((event) => event.eventId).toList(),
          scenario.expectedEventIds(),
        );
        expect(skipped, scenario.expectedSkippedCount());
      },
      tags: 'glados',
    );
  });
}
