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

  group('TimelineEventOrdering.sortStableByTimestamp', () {
    test('preserves original order for equal timestamps', () {
      final first = _MockEvent();
      final second = _MockEvent();
      final later = _MockEvent();

      when(() => first.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(1000));
      when(() => second.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(1000));
      when(() => later.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(2000));

      when(() => first.eventId).thenReturn(r'$0002');
      when(() => second.eventId).thenReturn(r'$0001');
      when(() => later.eventId).thenReturn(r'$0003');

      final ordered = TimelineEventOrdering.sortStableByTimestamp(
        [first, second, later],
      );

      expect(ordered, [first, second, later]);
    });
  });

  group('TimelineEventOrdering.timestampCollisionStats', () {
    test('reports collisions with sample timestamps', () {
      final a = _MockEvent();
      final b = _MockEvent();
      final c = _MockEvent();
      final d = _MockEvent();

      when(() => a.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(1000));
      when(() => b.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(1000));
      when(() => c.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(2000));
      when(() => d.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(1000));

      when(() => a.eventId).thenReturn(r'$a');
      when(() => b.eventId).thenReturn(r'$b');
      when(() => c.eventId).thenReturn(r'$c');
      when(() => d.eventId).thenReturn(r'$d');

      final stats = TimelineEventOrdering.timestampCollisionStats(
        [a, b, c, d],
        sampleLimit: 5,
      );

      expect(stats.groupCount, 1);
      expect(stats.eventCount, 3);
      expect(stats.sample.length, 1);
      expect(stats.sample.first.ts, 1000);
      expect(stats.sample.first.count, 3);
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
