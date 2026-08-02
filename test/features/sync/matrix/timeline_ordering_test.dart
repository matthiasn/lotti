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

  @override
  String toString() {
    return '_GeneratedOrderingScenario(events: $events)';
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
      glados.ListAnys(this)
          .listWithLengthInRange(0, 14, orderingEvent)
          .map((events) => _GeneratedOrderingScenario(events: events));
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
      expect(TimelineEventOrdering.timestamp(older), 1000);
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

      final ordered = TimelineEventOrdering.sortStableByTimestamp([
        first,
        second,
        later,
      ]);

      expect(ordered, [first, second, later]);
    });

    glados.Glados(glados.any.orderingScenario).test(
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
      tags: 'glados',
    );
  });
}
