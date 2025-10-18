// ignore_for_file: unnecessary_lambdas
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/pipeline_v2/catch_up_strategy.dart';
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

    test('with no marker id, returns snapshot events (no rewind)', () async {
      final room = MockRoom();
      final log = MockLogging();
      final tl = MockTimeline();

      // Start with newer window (ts 300..309), then page older (200..209), then (100..109)
      final window300 = List<Event>.generate(10, (i) {
        final e = MockEvent();
        when(() => e.eventId).thenReturn('e3_$i');
        when(() => e.originServerTs)
            .thenReturn(DateTime.fromMillisecondsSinceEpoch(300 + i));
        return e;
      });
      final window200 = List<Event>.generate(10, (i) {
        final e = MockEvent();
        when(() => e.eventId).thenReturn('e2_$i');
        when(() => e.originServerTs)
            .thenReturn(DateTime.fromMillisecondsSinceEpoch(200 + i));
        return e;
      });
      final window100 = List<Event>.generate(10, (i) {
        final e = MockEvent();
        when(() => e.eventId).thenReturn('e1_$i');
        when(() => e.originServerTs)
            .thenReturn(DateTime.fromMillisecondsSinceEpoch(100 + i));
        return e;
      });

      // Events getter returns current window snapshot
      var current = window300;
      when(() => tl.events).thenAnswer((_) => current);
      when(() => tl.cancelSubscriptions()).thenReturn(null);
      when(() => room.getTimeline(limit: any(named: 'limit')))
          .thenAnswer((_) async => tl);

      // Allow pagination twice
      var page = 0;
      when(() => tl.canRequestHistory).thenAnswer((_) => page < 2);
      when(() => tl.requestHistory()).thenAnswer((_) async {
        if (page == 0) {
          current = window200;
        } else if (page == 1) {
          current = window100;
        }
        page++;
      });

      final slice = await CatchUpStrategy.collectEventsForCatchUp(
        room: room,
        lastEventId: null,
        logging: log,
        backfill: ({
          required Timeline timeline,
          required String? lastEventId,
          required int pageSize,
          required int maxPages,
          required LoggingService logging,
        }) async =>
            true,
      );

      expect(slice, isNotEmpty);
      // No threshold slicing; returns current window (300..309)
      expect(slice.first.originServerTs.millisecondsSinceEpoch, 300);
      expect(slice.last.originServerTs.millisecondsSinceEpoch, 309);
      verify(() => tl.cancelSubscriptions()).called(1);
    });

    test('includes pre-context by count even when strictly-after is non-empty',
        () async {
      final room = MockRoom();
      final log = MockLogging();
      final tl = MockTimeline();

      // Build ordered events: o1(ts=100), x1(ts=150), x2(ts=200)
      Event mk(String id, int ts) {
        final e = MockEvent();
        when(() => e.eventId).thenReturn(id);
        when(() => e.originServerTs)
            .thenReturn(DateTime.fromMillisecondsSinceEpoch(ts));
        return e;
      }

      final events = <Event>[mk('o1', 100), mk('x1', 150), mk('x2', 200)];

      when(() => room.getTimeline(limit: any(named: 'limit')))
          .thenAnswer((_) async => tl);
      when(() => tl.events).thenReturn(events);
      when(() => tl.cancelSubscriptions()).thenReturn(null);

      final slice = await CatchUpStrategy.collectEventsForCatchUp(
        room: room,
        lastEventId: 'x1',
        logging: log,
        backfill: ({
          required Timeline timeline,
          required String? lastEventId,
          required int pageSize,
          required int maxPages,
          required LoggingService logging,
        }) async {
          // Marker already present; no need to paginate.
          return true;
        },
        preContextCount: 2, // should include o1 and x1
      );

      // Start should rewind to include o1 (pre-context), not just strictly-after x1
      expect(slice.map((e) => e.eventId), ['o1', 'x1', 'x2']);
      verify(() => tl.cancelSubscriptions()).called(1);
    });

    test('includes pre-context by timestamp (since last sync)', () async {
      final room = MockRoom();
      final log = MockLogging();
      final tl = MockTimeline();

      // o1(ts=100), x1(ts=150), x2(ts=200)
      Event mk(String id, int ts) {
        final e = MockEvent();
        when(() => e.eventId).thenReturn(id);
        when(() => e.originServerTs)
            .thenReturn(DateTime.fromMillisecondsSinceEpoch(ts));
        return e;
      }

      final events = <Event>[mk('o1', 100), mk('x1', 150), mk('x2', 200)];

      when(() => room.getTimeline(limit: any(named: 'limit')))
          .thenAnswer((_) async => tl);
      when(() => tl.events).thenReturn(events);
      when(() => tl.cancelSubscriptions()).thenReturn(null);

      const sinceTs = 120; // include everything >= 120 -> [x1, x2]
      final slice = await CatchUpStrategy.collectEventsForCatchUp(
        room: room,
        lastEventId: 'x1',
        logging: log,
        backfill: ({
          required Timeline timeline,
          required String? lastEventId,
          required int pageSize,
          required int maxPages,
          required LoggingService logging,
        }) async =>
            true,
        preContextSinceTs: sinceTs,
      );

      expect(slice.map((e) => e.eventId), ['x1', 'x2']);
      verify(() => tl.cancelSubscriptions()).called(1);
    });
  });
}

class MockEvent extends Mock implements Event {}
