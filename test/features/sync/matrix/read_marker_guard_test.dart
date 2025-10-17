import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/read_marker_service.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

class MockTimeline extends Mock implements Timeline {}

class MockEvent extends Mock implements Event {}

void main() {
  group('isStrictlyNewerInTimeline', () {
    test('true when candidate has greater server ts', () {
      final tl = MockTimeline();
      final older = MockEvent();
      final newer = MockEvent();
      when(() => older.eventId).thenReturn('e_old');
      when(() => newer.eventId).thenReturn('e_new');
      when(() => older.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(100));
      when(() => newer.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(200));
      when(() => tl.events).thenReturn(<Event>[older, newer]);

      expect(
        isStrictlyNewerInTimeline(
          timeline: tl,
          candidateEventId: 'e_new',
          baseEventId: 'e_old',
        ),
        isTrue,
      );
    });

    test('false when candidate has smaller server ts', () {
      final tl = MockTimeline();
      final older = MockEvent();
      final newer = MockEvent();
      when(() => older.eventId).thenReturn('e_old');
      when(() => newer.eventId).thenReturn('e_new');
      when(() => older.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(100));
      when(() => newer.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(200));
      when(() => tl.events).thenReturn(<Event>[older, newer]);

      expect(
        isStrictlyNewerInTimeline(
          timeline: tl,
          candidateEventId: 'e_old',
          baseEventId: 'e_new',
        ),
        isFalse,
      );
    });

    test('tie by ts broken by lexicographically larger eventId', () {
      final tl = MockTimeline();
      final a = MockEvent();
      final b = MockEvent();
      when(() => a.eventId).thenReturn('e1');
      when(() => b.eventId).thenReturn('e2');
      when(() => a.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(100));
      when(() => b.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(100));
      when(() => tl.events).thenReturn(<Event>[a, b]);

      // b is newer than a due to id tie-break
      expect(
        isStrictlyNewerInTimeline(
          timeline: tl,
          candidateEventId: 'e2',
          baseEventId: 'e1',
        ),
        isTrue,
      );
      // a is not newer than b
      expect(
        isStrictlyNewerInTimeline(
          timeline: tl,
          candidateEventId: 'e1',
          baseEventId: 'e2',
        ),
        isFalse,
      );
    });

    test('false when either event is missing in timeline', () {
      final tl = MockTimeline();
      final a = MockEvent();
      when(() => a.eventId).thenReturn('e1');
      when(() => a.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(100));
      when(() => tl.events).thenReturn(<Event>[a]);
      expect(
        isStrictlyNewerInTimeline(
          timeline: tl,
          candidateEventId: 'e1',
          baseEventId: 'missing',
        ),
        isFalse,
      );
    });
  });
}
