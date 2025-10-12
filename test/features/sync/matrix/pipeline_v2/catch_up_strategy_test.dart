// ignore_for_file: unnecessary_lambdas
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/pipeline/catch_up_strategy.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

class MockRoom extends Mock implements Room {}

class MockTimeline extends Mock implements Timeline {}

class MockLogging extends Mock implements LoggingService {}

void main() {
  setUpAll(() {
    registerFallbackValue(MockTimeline());
  });

  group('CatchUpStrategy', () {
    test('uses backfill and returns slice strictly after lastEventId',
        () async {
      final room = MockRoom();
      final log = MockLogging();
      final tl = MockTimeline();

      // Snapshot with events e0..e2 (sorted oldest->newest)
      final events = List<Event>.generate(3, (i) {
        final e = MockEvent();
        when(() => e.eventId).thenReturn('e$i');
        when(() => e.originServerTs)
            .thenReturn(DateTime.fromMillisecondsSinceEpoch(i));
        return e;
      });

      when(() => room.getTimeline(limit: any(named: 'limit')))
          .thenAnswer((_) async => tl);
      when(() => tl.events).thenReturn(events);
      when(() => tl.cancelSubscriptions()).thenReturn(null);

      final slice = await CatchUpStrategy.collectEventsForCatchUp(
        room: room,
        lastEventId: 'e1',
        logging: log,
        backfill: ({
          required Timeline timeline,
          required String? lastEventId,
          required int pageSize,
          required int maxPages,
          required LoggingService logging,
        }) async {
          // backfill attempts and succeeds (but current snapshot already contains last)
          return true;
        },
      );

      expect(slice.map((e) => e.eventId), ['e2']);
      verify(() => tl.cancelSubscriptions()).called(1);
    });

    test('falls back to doubling when backfill unavailable', () async {
      final room = MockRoom();
      final log = MockLogging();
      final created = <MockTimeline>[];

      // Build a synthetic sequence e0..e9
      final all = List<Event>.generate(10, (i) {
        final e = MockEvent();
        when(() => e.eventId).thenReturn('e$i');
        when(() => e.originServerTs)
            .thenReturn(DateTime.fromMillisecondsSinceEpoch(i));
        return e;
      });

      Future<Timeline> timelineForLimit(int limit) async {
        final tl = MockTimeline();
        created.add(tl);
        final start = all.length > limit ? all.length - limit : 0;
        when(() => tl.events).thenReturn(all.sublist(start));
        when(() => tl.cancelSubscriptions()).thenReturn(null);
        return tl;
      }

      when(() => room.getTimeline(limit: any(named: 'limit')))
          .thenAnswer((invocation) async {
        final limit = invocation.namedArguments[#limit] as int? ?? 200;
        return timelineForLimit(limit);
      });

      final slice = await CatchUpStrategy.collectEventsForCatchUp(
        room: room,
        lastEventId: 'e3',
        logging: log,
        backfill: ({
          required Timeline timeline,
          required String? lastEventId,
          required int pageSize,
          required int maxPages,
          required LoggingService logging,
        }) async =>
            false,
        initialLimit: 2,
        maxLookback: 8,
      );

      // Should include strictly after e3 and be sorted
      expect(slice.first.eventId, 'e4');
      expect(slice.last.eventId, anyOf('e9'));
      // All created timelines should be cleaned up
      for (final tl in created) {
        verify(() => tl.cancelSubscriptions()).called(1);
      }
    });
  });
}

class MockEvent extends Mock implements Event {}
