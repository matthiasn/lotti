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
  });
}
