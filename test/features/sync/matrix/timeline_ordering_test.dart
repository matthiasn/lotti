import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/sync/matrix/timeline_ordering.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

class _GeneratedOrderingEvent {
  const _GeneratedOrderingEvent({
    required this.eventSlot,
    required this.timestampBucket,
  });

  final int eventSlot;
  final int timestampBucket;

  String get eventId => '\$generated-$eventSlot';

  int get timestampMs => 1000 + timestampBucket;

  @override
  String toString() {
    return '_GeneratedOrderingEvent('
        'eventSlot: $eventSlot, '
        'timestampBucket: $timestampBucket'
        ')';
  }
}

class _GeneratedOrderingScenario {
  const _GeneratedOrderingScenario({required this.events});

  final List<_GeneratedOrderingEvent> events;

  List<String> expectedStableSortedIds() {
    final indexed =
        <({int index, _GeneratedOrderingEvent event})>[
          for (var index = 0; index < events.length; index++)
            (index: index, event: events[index]),
        ]..sort((a, b) {
          final tsCompare = a.event.timestampMs.compareTo(b.event.timestampMs);
          if (tsCompare != 0) return tsCompare;
          return a.index.compareTo(b.index);
        });

    return [for (final item in indexed) item.event.eventId];
  }

  ({int groupCount, int eventCount}) expectedCollisionStats() {
    final counts = <int, int>{};
    for (final event in events) {
      counts[event.timestampMs] = (counts[event.timestampMs] ?? 0) + 1;
    }
    var groupCount = 0;
    var eventCount = 0;
    for (final count in counts.values) {
      if (count > 1) {
        groupCount++;
        eventCount += count;
      }
    }
    return (groupCount: groupCount, eventCount: eventCount);
  }

  @override
  String toString() {
    return '_GeneratedOrderingScenario(events: $events)';
  }
}

class _GeneratedIsNewerScenario {
  const _GeneratedIsNewerScenario({
    required this.candidateTimestampBucket,
    required this.candidateEventSlot,
    required this.hasLatestTimestamp,
    required this.hasLatestEventId,
    required this.latestTimestampBucket,
    required this.latestEventSlot,
  });

  final int candidateTimestampBucket;
  final int candidateEventSlot;
  final bool hasLatestTimestamp;
  final bool hasLatestEventId;
  final int latestTimestampBucket;
  final int latestEventSlot;

  int get candidateTimestamp => 1000 + candidateTimestampBucket;

  String get candidateEventId => '\$generated-$candidateEventSlot';

  int? get latestTimestamp =>
      hasLatestTimestamp ? 1000 + latestTimestampBucket : null;

  String? get latestEventId =>
      hasLatestEventId ? '\$generated-$latestEventSlot' : null;

  bool get expected {
    final latestTs = latestTimestamp;
    final latestId = latestEventId;
    if (latestTs == null || latestId == null) return true;
    if (candidateTimestamp > latestTs) return true;
    if (candidateTimestamp < latestTs) return false;
    return candidateEventId.compareTo(latestId) > 0;
  }

  @override
  String toString() {
    return '_GeneratedIsNewerScenario('
        'candidateTimestampBucket: $candidateTimestampBucket, '
        'candidateEventSlot: $candidateEventSlot, '
        'hasLatestTimestamp: $hasLatestTimestamp, '
        'hasLatestEventId: $hasLatestEventId, '
        'latestTimestampBucket: $latestTimestampBucket, '
        'latestEventSlot: $latestEventSlot'
        ')';
  }
}

extension _AnyTimelineOrderingScenario on glados.Any {
  glados.Generator<_GeneratedOrderingEvent> get orderingEvent =>
      glados.CombinableAny(this).combine2(
        glados.IntAnys(this).intInRange(0, 8),
        glados.IntAnys(this).intInRange(0, 6),
        (int eventSlot, int timestampBucket) => _GeneratedOrderingEvent(
          eventSlot: eventSlot,
          timestampBucket: timestampBucket,
        ),
      );

  glados.Generator<_GeneratedOrderingScenario> get orderingScenario =>
      glados.ListAnys(
            this,
          )
          .listWithLengthInRange(0, 14, orderingEvent)
          .map(
            (events) => _GeneratedOrderingScenario(events: events),
          );

  glados.Generator<_GeneratedIsNewerScenario> get isNewerScenario =>
      glados.CombinableAny(this).combine6(
        glados.IntAnys(this).intInRange(0, 6),
        glados.IntAnys(this).intInRange(0, 8),
        glados.BoolAny(this).bool,
        glados.BoolAny(this).bool,
        glados.IntAnys(this).intInRange(0, 6),
        glados.IntAnys(this).intInRange(0, 8),
        (
          int candidateTimestampBucket,
          int candidateEventSlot,
          bool hasLatestTimestamp,
          bool hasLatestEventId,
          int latestTimestampBucket,
          int latestEventSlot,
        ) => _GeneratedIsNewerScenario(
          candidateTimestampBucket: candidateTimestampBucket,
          candidateEventSlot: candidateEventSlot,
          hasLatestTimestamp: hasLatestTimestamp,
          hasLatestEventId: hasLatestEventId,
          latestTimestampBucket: latestTimestampBucket,
          latestEventSlot: latestEventSlot,
        ),
      );
}

Event _generatedEvent(_GeneratedOrderingEvent generated) {
  final event = MockEvent();
  when(
    () => event.originServerTs,
  ).thenReturn(DateTime.fromMillisecondsSinceEpoch(generated.timestampMs));
  when(() => event.eventId).thenReturn(generated.eventId);
  return event;
}

void main() {
  late MockEvent older;
  late MockEvent newer;

  setUp(() {
    older = MockEvent();
    newer = MockEvent();

    when(
      () => older.originServerTs,
    ).thenReturn(DateTime.fromMillisecondsSinceEpoch(1000));
    when(() => older.eventId).thenReturn(r'$0001');

    when(
      () => newer.originServerTs,
    ).thenReturn(DateTime.fromMillisecondsSinceEpoch(2000));
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
      final first = MockEvent();
      final second = MockEvent();
      final later = MockEvent();

      when(
        () => first.originServerTs,
      ).thenReturn(DateTime.fromMillisecondsSinceEpoch(1000));
      when(
        () => second.originServerTs,
      ).thenReturn(DateTime.fromMillisecondsSinceEpoch(1000));
      when(
        () => later.originServerTs,
      ).thenReturn(DateTime.fromMillisecondsSinceEpoch(2000));

      when(() => first.eventId).thenReturn(r'$0002');
      when(() => second.eventId).thenReturn(r'$0001');
      when(() => later.eventId).thenReturn(r'$0003');

      final ordered = TimelineEventOrdering.sortStableByTimestamp(
        [first, second, later],
      );

      expect(ordered, [first, second, later]);
    });

    glados.Glados(
      glados.any.orderingScenario,
    ).test(
      'generated stable ordering preserves input order inside timestamp ties',
      (scenario) {
        final events = [
          for (final event in scenario.events) _generatedEvent(event),
        ];
        final ordered = TimelineEventOrdering.sortStableByTimestamp(events);

        expect(
          ordered.map((event) => event.eventId).toList(),
          scenario.expectedStableSortedIds(),
        );
      },
    );
  });

  group('TimelineEventOrdering.timestampCollisionStats', () {
    test('reports collisions with sample timestamps', () {
      final a = MockEvent();
      final b = MockEvent();
      final c = MockEvent();
      final d = MockEvent();

      when(
        () => a.originServerTs,
      ).thenReturn(DateTime.fromMillisecondsSinceEpoch(1000));
      when(
        () => b.originServerTs,
      ).thenReturn(DateTime.fromMillisecondsSinceEpoch(1000));
      when(
        () => c.originServerTs,
      ).thenReturn(DateTime.fromMillisecondsSinceEpoch(2000));
      when(
        () => d.originServerTs,
      ).thenReturn(DateTime.fromMillisecondsSinceEpoch(1000));

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

    glados.Glados(
      glados.any.orderingScenario,
    ).test(
      'generated collision stats count duplicated timestamp groups',
      (scenario) {
        final stats = TimelineEventOrdering.timestampCollisionStats(
          [
            for (final event in scenario.events) _generatedEvent(event),
          ],
        );
        final expected = scenario.expectedCollisionStats();

        expect(stats.groupCount, expected.groupCount);
        expect(stats.eventCount, expected.eventCount);
        expect(stats.sample, hasLength(lessThanOrEqualTo(stats.groupCount)));
      },
    );
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

    glados.Glados(
      glados.any.isNewerScenario,
    ).test(
      'generated marker comparisons match timestamp then event-id ordering',
      (scenario) {
        expect(
          TimelineEventOrdering.isNewer(
            candidateTimestamp: scenario.candidateTimestamp,
            candidateEventId: scenario.candidateEventId,
            latestTimestamp: scenario.latestTimestamp,
            latestEventId: scenario.latestEventId,
          ),
          scenario.expected,
        );
      },
    );
  });
}
