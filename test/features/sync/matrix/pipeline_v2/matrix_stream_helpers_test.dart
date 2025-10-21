import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/pipeline_v2/matrix_stream_helpers.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

class MockEvent extends Mock implements Event {}

void main() {
  group('matrix_stream_helpers', () {
    test('extractRuntimeTypeFromEvent returns runtimeType from base64 JSON',
        () {
      final ev = MockEvent();
      final jsonPayload = <String, dynamic>{
        'runtimeType': 'entryLink',
        'id': 'abc',
      };
      final text = base64.encode(utf8.encode(json.encode(jsonPayload)));
      when(() => ev.text).thenReturn(text);

      expect(extractRuntimeTypeFromEvent(ev), 'entryLink');
    });

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

    test('isLikelySyncPayloadText detects valid base64 JSON with runtimeType',
        () {
      final valid = base64.encode(utf8.encode(json.encode(<String, dynamic>{
        'runtimeType': 'journalEntity',
      })));
      final invalidJson = base64.encode(utf8.encode('not json'));

      expect(isLikelySyncPayloadText(valid), isTrue);
      expect(isLikelySyncPayloadText(invalidJson), isFalse);
      expect(isLikelySyncPayloadText(''), isFalse);
      expect(isLikelySyncPayloadText('not-base64'), isFalse);
    });

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
          computeNextScanDelay(now, later), const Duration(milliseconds: 200));
      expect(computeNextScanDelay(now, earlier),
          const Duration(milliseconds: 200));
      expect(
          computeNextScanDelay(now, null), const Duration(milliseconds: 200));
      expect(
        computeNextScanDelay(now, later,
            defaultDelay: const Duration(milliseconds: 50)),
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
      when(() => e1.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(1));
      final e2 = MockEvent();
      when(() => e2.eventId).thenReturn('b');
      when(() => e2.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(2));
      final e3 = MockEvent();
      when(() => e3.eventId).thenReturn('c');
      when(() => e3.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(3));

      final slice = buildLiveScanSlice(
        timelineEvents: [e2, e1, e3],
        lastEventId: 'b',
        tailLimit: 50,
        lastTimestamp: null,
        tsGate: const Duration(seconds: 2),
      );
      expect(slice.map((e) => e.eventId), ['c']);
    });

    test('buildLiveScanSlice returns last N when no lastEventId', () {
      final es = <MockEvent>[];
      for (var i = 0; i < 5; i++) {
        final e = MockEvent();
        when(() => e.eventId).thenReturn('e$i');
        when(() => e.originServerTs)
            .thenReturn(DateTime.fromMillisecondsSinceEpoch(i));
        es.add(e);
      }
      final slice = buildLiveScanSlice(
        timelineEvents: es,
        lastEventId: null,
        tailLimit: 2,
        lastTimestamp: null,
        tsGate: const Duration(seconds: 2),
      );
      expect(slice.map((e) => e.eventId), ['e3', 'e4']);
    });

    test('buildLiveScanSlice applies timestamp cutoff', () {
      final older = MockEvent();
      when(() => older.eventId).thenReturn('old');
      when(() => older.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(1000));
      final newer = MockEvent();
      when(() => newer.eventId).thenReturn('new');
      when(() => newer.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(3000));

      final slice = buildLiveScanSlice(
        timelineEvents: [older, newer],
        lastEventId: null,
        tailLimit: 10,
        lastTimestamp: 3000, // cutoff = 3000 - 2000 = 1000
        tsGate: const Duration(seconds: 2),
      );
      expect(slice.map((e) => e.eventId), ['old', 'new']);

      final slice2 = buildLiveScanSlice(
        timelineEvents: [older, newer],
        lastEventId: null,
        tailLimit: 10,
        lastTimestamp: 3500, // cutoff = 3500 - 2000 = 1500 -> drop 'old'
        tsGate: const Duration(seconds: 2),
      );
      expect(slice2.map((e) => e.eventId), ['new']);
    });

    test('buildLiveScanSlice deduplicates by eventId preserving order', () {
      final a1 = MockEvent();
      when(() => a1.eventId).thenReturn('a');
      when(() => a1.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(1));
      final a2 = MockEvent();
      when(() => a2.eventId).thenReturn('a');
      when(() => a2.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(1));
      final b = MockEvent();
      when(() => b.eventId).thenReturn('b');
      when(() => b.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(2));

      final slice = buildLiveScanSlice(
        timelineEvents: [a2, b, a1],
        lastEventId: null,
        tailLimit: 10,
        lastTimestamp: null,
        tsGate: const Duration(seconds: 2),
      );
      expect(slice.map((e) => e.eventId), ['a', 'b']);
    });

    test(
        'filterSyncPayloadsByMonotonic drops old payloads, keeps retries/attachments',
        () {
      Event mk(String id, int ts, {bool payload = true}) {
        final e = MockEvent();
        when(() => e.eventId).thenReturn(id);
        when(() => e.originServerTs)
            .thenReturn(DateTime.fromMillisecondsSinceEpoch(ts));
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
      final kept = filterSyncPayloadsByMonotonic(
        events: [old, equal, newer, att],
        dropOldSyncPayloads: true,
        lastTimestamp: 200,
        lastEventId: 'E1',
        hasAttempts: (_) => false,
        onSkipped: () => skipped++,
      );
      expect(kept.map((e) => e.eventId), containsAllInOrder(['E2', 'A1']));
      expect(kept.any((e) => e.eventId == 'E0' || e.eventId == 'E1'), isFalse);
      expect(skipped, 2);

      // Mark equal as retrying -> kept
      skipped = 0;
      final kept2 = filterSyncPayloadsByMonotonic(
        events: [old, equal, newer, att],
        dropOldSyncPayloads: true,
        lastTimestamp: 200,
        lastEventId: 'E1',
        hasAttempts: (id) => id == 'E1',
        onSkipped: () => skipped++,
      );
      expect(kept2.map((e) => e.eventId), containsAll(['E1', 'E2', 'A1']));
      expect(kept2.any((e) => e.eventId == 'E0'), isFalse);
      expect(skipped, 1);
    });
  });
}
