import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/timeline_ordering.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

class _MockEvent extends Mock implements Event {}

void main() {
  late _MockEvent older;
  late _MockEvent newer;

  setUp(() {
    older = _MockEvent();
    newer = _MockEvent();

    when(() => older.originServerTs)
        .thenReturn(DateTime.fromMillisecondsSinceEpoch(1000));
    when(() => older.eventId).thenReturn(r'$0001');

    when(() => newer.originServerTs)
        .thenReturn(DateTime.fromMillisecondsSinceEpoch(2000));
    when(() => newer.eventId).thenReturn(r'$0002');
  });

  group('TimelineEventOrdering.timestamp', () {
    test('returns milliseconds since epoch', () {
      expect(
        TimelineEventOrdering.timestamp(older),
        1000,
      );
    });
  });

  group('TimelineEventOrdering.compare', () {
    test('sorts events chronologically (oldest first)', () {
      final events = [newer, older]..sort(TimelineEventOrdering.compare);
      expect(events, [older, newer]);
    });

    test('falls back to eventId when timestamps match', () {
      final eventA = _MockEvent();
      final eventB = _MockEvent();
      when(() => eventA.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(2000));
      when(() => eventB.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(2000));
      when(() => eventA.eventId).thenReturn(r'$0001');
      when(() => eventB.eventId).thenReturn(r'$0002');

      expect(
        TimelineEventOrdering.compare(eventA, eventB),
        lessThan(0),
      );
      expect(
        TimelineEventOrdering.compare(eventB, eventA),
        greaterThan(0),
      );
    });
  });

  group('TimelineEventOrdering.isNewer', () {
    test('returns true when no previous marker exists', () {
      expect(
        TimelineEventOrdering.isNewer(
          candidateTimestamp: 2000,
          candidateEventId: r'$newer',
          latestTimestamp: null,
          latestEventId: null,
        ),
        isTrue,
      );
    });

    test('returns true when candidate timestamp is greater', () {
      expect(
        TimelineEventOrdering.isNewer(
          candidateTimestamp: 2000,
          candidateEventId: r'$0002',
          latestTimestamp: 1000,
          latestEventId: r'$0001',
        ),
        isTrue,
      );
    });

    test('returns false when candidate timestamp is smaller', () {
      expect(
        TimelineEventOrdering.isNewer(
          candidateTimestamp: 1000,
          candidateEventId: r'$0001',
          latestTimestamp: 2000,
          latestEventId: r'$0002',
        ),
        isFalse,
      );
    });

    test('uses eventId lexicographically when timestamps match', () {
      expect(
        TimelineEventOrdering.isNewer(
          candidateTimestamp: 2000,
          candidateEventId: r'$0002',
          latestTimestamp: 2000,
          latestEventId: r'$0001',
        ),
        isTrue,
      );

      expect(
        TimelineEventOrdering.isNewer(
          candidateTimestamp: 2000,
          candidateEventId: r'$0001',
          latestTimestamp: 2000,
          latestEventId: r'$0002',
        ),
        isFalse,
      );
    });
  });
}
