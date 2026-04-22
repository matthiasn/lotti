// ignore_for_file: unnecessary_lambdas
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/pipeline/catch_up_strategy.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';

class MockRoom extends Mock implements Room {}

class MockTimeline extends Mock implements Timeline {}

void main() {
  setUpAll(() {
    registerFallbackValue(MockTimeline());
  });

  group('CatchUpStrategy', () {
    test(
      'returns best-effort events when timestamp boundary stays unreachable and snapshot is full',
      () async {
        final room = MockRoom();
        final log = MockLoggingService();
        final created = <MockTimeline>[];

        // Large dataset e0..e4999
        final all = List<Event>.generate(5000, (i) {
          final e = MockEvent();
          when(() => e.eventId).thenReturn('e$i');
          when(
            () => e.originServerTs,
          ).thenReturn(DateTime.fromMillisecondsSinceEpoch(i));
          return e;
        });

        // Snapshot returns the last `limit` events in ascending order
        Future<Timeline> timelineForLimit(int limit) async {
          final tl = MockTimeline();
          created.add(tl);
          final start = all.length > limit ? all.length - limit : 0;
          when(() => tl.events).thenReturn(all.sublist(start));
          when(() => tl.cancelSubscriptions()).thenReturn(null);
          return tl;
        }

        when(() => room.getTimeline(limit: any(named: 'limit'))).thenAnswer((
          invocation,
        ) async {
          final limit = invocation.namedArguments[#limit] as int? ?? 200;
          return timelineForLimit(limit);
        });

        // Backfill attempts happen, but the requested timestamp boundary is
        // still older than the oldest visible event. Best-effort returns all
        // visible events rather than stalling.
        final result = await CatchUpStrategy.collectEventsForCatchUp(
          room: room,
          lastEventId: 'legacy-marker',
          logging: log,
          backfill:
              ({
                required Timeline timeline,
                required String? lastEventId,
                required int pageSize,
                required int? maxPages,
                required LoggingService logging,
                num? untilTimestamp,
              }) async => false,
          preContextSinceTs: -1,
          maxLookback: 5000,
        );

        expect(result.incomplete, isFalse);
        expect(result.timestampAnchored, isTrue);
        expect(result.events, hasLength(5000));
        expect(result.snapshotSize, 5000);
        for (final tl in created) {
          verify(() => tl.cancelSubscriptions()).called(1);
        }
      },
    );

    test(
      'returns best-effort events without escalating when timestamp boundary is unreachable and snapshot not full',
      () async {
        final room = MockRoom();
        final log = MockLoggingService();
        final tl = MockTimeline();

        // Data shorter than the initial limit and still newer than the anchor.
        final all = List<Event>.generate(150, (i) {
          final e = MockEvent();
          when(() => e.eventId).thenReturn('e$i');
          when(
            () => e.originServerTs,
          ).thenReturn(DateTime.fromMillisecondsSinceEpoch(100 + i));
          return e;
        });

        when(
          () => room.getTimeline(limit: any(named: 'limit')),
        ).thenAnswer((_) async => tl);
        when(() => tl.events).thenReturn(all);
        when(() => tl.cancelSubscriptions()).thenReturn(null);

        final result = await CatchUpStrategy.collectEventsForCatchUp(
          room: room,
          lastEventId: 'legacy-marker',
          logging: log,
          backfill:
              ({
                required Timeline timeline,
                required String? lastEventId,
                required int pageSize,
                required int? maxPages,
                required LoggingService logging,
                num? untilTimestamp,
              }) async => true,
          preContextSinceTs: 50,
          maxLookback: 1000,
        );

        // Best-effort: returns all visible events even though the boundary
        // was not reached, preventing pipeline stalls.
        expect(result.incomplete, isFalse);
        expect(result.timestampAnchored, isTrue);
        expect(result.events, hasLength(150));
        expect(result.snapshotSize, 150);
        verify(() => tl.cancelSubscriptions()).called(1);
      },
    );

    test(
      'returns best-effort events when timestamp boundary is unreachable regardless of fallback limit',
      () async {
        final room = MockRoom();
        final log = MockLoggingService();
        final tl = MockTimeline();

        final events = List<Event>.generate(20, (i) {
          final e = MockEvent();
          when(() => e.eventId).thenReturn('e$i');
          when(
            () => e.originServerTs,
          ).thenReturn(DateTime.fromMillisecondsSinceEpoch(100 + i));
          return e;
        });

        when(
          () => room.getTimeline(limit: any(named: 'limit')),
        ).thenAnswer((_) async => tl);
        when(() => tl.events).thenReturn(events);
        when(() => tl.cancelSubscriptions()).thenReturn(null);

        final result = await CatchUpStrategy.collectEventsForCatchUp(
          room: room,
          lastEventId: 'legacy-marker',
          logging: log,
          backfill:
              ({
                required Timeline timeline,
                required String? lastEventId,
                required int pageSize,
                required int? maxPages,
                required LoggingService logging,
                num? untilTimestamp,
              }) async => true,
          missingMarkerFallbackLimit: 3,
          preContextSinceTs: 50,
        );

        // Best-effort: returns all visible events to prevent stalls.
        expect(result.incomplete, isFalse);
        expect(result.timestampAnchored, isTrue);
        expect(result.events, hasLength(20));
        verify(() => tl.cancelSubscriptions()).called(1);
      },
    );
    test('preContextCount=80 bounds timestamp overlap window', () async {
      final room = MockRoom();
      final log = MockLoggingService();
      final tl = MockTimeline();

      // Build ordered events e0..e199 (ts increasing)
      final events = List<Event>.generate(200, (i) {
        final e = MockEvent();
        when(() => e.eventId).thenReturn('e$i');
        when(
          () => e.originServerTs,
        ).thenReturn(DateTime.fromMillisecondsSinceEpoch(i));
        return e;
      });

      when(
        () => room.getTimeline(limit: any(named: 'limit')),
      ).thenAnswer((_) async => tl);
      when(() => tl.events).thenReturn(events);
      when(() => tl.cancelSubscriptions()).thenReturn(null);

      final result = await CatchUpStrategy.collectEventsForCatchUp(
        room: room,
        lastEventId: 'legacy-marker',
        logging: log,
        backfill:
            ({
              required Timeline timeline,
              required String? lastEventId,
              required int pageSize,
              required int? maxPages,
              required LoggingService logging,
              num? untilTimestamp,
            }) async => true,
        preContextSinceTs: 120,
        preContextCount: 80,
        maxLookback: 2000,
      );

      final slice = result.events;
      expect(slice.first.eventId, 'e40');
      verify(() => tl.cancelSubscriptions()).called(greaterThanOrEqualTo(1));
    });

    test('maxLookback=1000 bounds timestamp-boundary lookback', () async {
      final room = MockRoom();
      final log = MockLoggingService();
      final created = <MockTimeline>[];

      // Synthetic large window e0..e9999
      final all = List<Event>.generate(10000, (i) {
        final e = MockEvent();
        when(() => e.eventId).thenReturn('e$i');
        when(
          () => e.originServerTs,
        ).thenReturn(DateTime.fromMillisecondsSinceEpoch(i));
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

      when(() => room.getTimeline(limit: any(named: 'limit'))).thenAnswer((
        invocation,
      ) async {
        final limit = invocation.namedArguments[#limit] as int? ?? 200;
        return timelineForLimit(limit);
      });

      // Request a boundary older than the oldest visible event so lookback
      // continues until maxLookback stops it.
      final result = await CatchUpStrategy.collectEventsForCatchUp(
        room: room,
        lastEventId: 'legacy-marker',
        logging: log,
        backfill:
            ({
              required Timeline timeline,
              required String? lastEventId,
              required int pageSize,
              required int? maxPages,
              required LoggingService logging,
              num? untilTimestamp,
            }) async => false,
        initialLimit: 50,
        preContextSinceTs: -1,
        maxLookback: 1000,
      );

      // Best-effort: returns all visible events up to maxLookback even
      // though the boundary was not reached.
      expect(result.incomplete, isFalse);
      expect(result.timestampAnchored, isTrue);
      expect(result.events, hasLength(1000));
      expect(result.snapshotSize, 1000);
      for (final tl in created) {
        verify(() => tl.cancelSubscriptions()).called(1);
      }
    });
    test('uses backfill and returns timestamp-anchored slice', () async {
      final room = MockRoom();
      final log = MockLoggingService();
      final tl = MockTimeline();

      // Snapshot with events e0..e2 (sorted oldest->newest)
      final events = List<Event>.generate(3, (i) {
        final e = MockEvent();
        when(() => e.eventId).thenReturn('e$i');
        when(
          () => e.originServerTs,
        ).thenReturn(DateTime.fromMillisecondsSinceEpoch(i));
        return e;
      });

      when(
        () => room.getTimeline(limit: any(named: 'limit')),
      ).thenAnswer((_) async => tl);
      when(() => tl.events).thenReturn(events);
      when(() => tl.cancelSubscriptions()).thenReturn(null);

      final result = await CatchUpStrategy.collectEventsForCatchUp(
        room: room,
        lastEventId: 'legacy-marker',
        logging: log,
        backfill:
            ({
              required Timeline timeline,
              required String? lastEventId,
              required int pageSize,
              required int? maxPages,
              required LoggingService logging,
              num? untilTimestamp,
            }) async {
              // backfill attempts and succeeds
              return true;
            },
        preContextSinceTs: 1,
      );

      final slice = result.events;
      expect(result.timestampAnchored, isTrue);
      expect(slice.map((e) => e.eventId), ['e1', 'e2']);
      verify(() => tl.cancelSubscriptions()).called(1);
    });

    test(
      'returns timestampAnchored when cached history crosses the timestamp '
      'boundary even if server backfill reports end-of-timeline',
      () async {
        final room = MockRoom();
        final log = MockLoggingService();
        final tl = MockTimeline();

        Event mk(String id, int ts) {
          final e = MockEvent();
          when(() => e.eventId).thenReturn(id);
          when(
            () => e.originServerTs,
          ).thenReturn(DateTime.fromMillisecondsSinceEpoch(ts));
          return e;
        }

        final events = <Event>[mk('cached-old', 100), mk('cached-new', 300)];
        when(() => room.prev_batch).thenReturn('server-gap-token');
        when(
          () => room.getTimeline(limit: any(named: 'limit')),
        ).thenAnswer((_) async => tl);
        when(() => tl.events).thenReturn(events);
        when(() => tl.cancelSubscriptions()).thenReturn(null);

        final result = await CatchUpStrategy.collectEventsForCatchUp(
          room: room,
          lastEventId: 'legacy-marker',
          logging: log,
          backfill:
              ({
                required Timeline timeline,
                required String? lastEventId,
                required int pageSize,
                required int? maxPages,
                required LoggingService logging,
                num? untilTimestamp,
              }) async => false,
          preContextSinceTs: 150,
        );

        // The local timeline already satisfies the timestamp boundary
        // (cached-old at ts=100 < anchor ts=150), so events are returned
        // even though server backfill reported end-of-timeline.
        // Only events at or after the anchor timestamp are included
        // (preContextCount defaults to 0).
        expect(result.incomplete, isFalse);
        expect(result.timestampAnchored, isTrue);
        expect(
          result.events.map((event) => event.eventId),
          ['cached-new'],
        );
        verify(() => tl.cancelSubscriptions()).called(1);
      },
    );

    test(
      'requires server history to satisfy the timestamp boundary when prev_batch exists',
      () async {
        final room = MockRoom();
        final log = MockLoggingService();
        final tl = MockTimeline();

        Event mk(String id, int ts) {
          final e = MockEvent();
          when(() => e.eventId).thenReturn(id);
          when(
            () => e.originServerTs,
          ).thenReturn(DateTime.fromMillisecondsSinceEpoch(ts));
          return e;
        }

        final events = <Event>[mk('cached-old', 100), mk('cached-new', 300)];
        when(() => room.prev_batch).thenReturn('server-gap-token');
        when(
          () => room.getTimeline(limit: any(named: 'limit')),
        ).thenAnswer((_) async => tl);
        when(() => tl.events).thenReturn(events);
        when(() => tl.cancelSubscriptions()).thenReturn(null);

        final result = await CatchUpStrategy.collectEventsForCatchUp(
          room: room,
          lastEventId: 'legacy-marker',
          logging: log,
          backfill:
              ({
                required Timeline timeline,
                required String? lastEventId,
                required int pageSize,
                required int? maxPages,
                required LoggingService logging,
                num? untilTimestamp,
              }) async {
                events.insert(1, mk('server-gap', 140));
                return true;
              },
          preContextSinceTs: 150,
          preContextCount: 1,
        );

        expect(result.incomplete, isFalse);
        expect(result.timestampAnchored, isTrue);
        expect(result.events.map((event) => event.eventId), [
          'server-gap',
          'cached-new',
        ]);
        verify(() => tl.cancelSubscriptions()).called(1);
      },
    );

    test('falls back to doubling when backfill unavailable', () async {
      final room = MockRoom();
      final log = MockLoggingService();
      final created = <MockTimeline>[];

      // Build a synthetic sequence e0..e9
      final all = List<Event>.generate(10, (i) {
        final e = MockEvent();
        when(() => e.eventId).thenReturn('e$i');
        when(
          () => e.originServerTs,
        ).thenReturn(DateTime.fromMillisecondsSinceEpoch(i));
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

      when(() => room.getTimeline(limit: any(named: 'limit'))).thenAnswer((
        invocation,
      ) async {
        final limit = invocation.namedArguments[#limit] as int? ?? 200;
        return timelineForLimit(limit);
      });

      final result = await CatchUpStrategy.collectEventsForCatchUp(
        room: room,
        lastEventId: 'legacy-marker',
        logging: log,
        backfill:
            ({
              required Timeline timeline,
              required String? lastEventId,
              required int pageSize,
              required int? maxPages,
              required LoggingService logging,
              num? untilTimestamp,
            }) async => false,
        initialLimit: 2,
        preContextSinceTs: 4,
        maxLookback: 8,
      );

      final slice = result.events;
      expect(result.timestampAnchored, isTrue);
      expect(slice.first.eventId, 'e4');
      expect(slice.last.eventId, anyOf('e9'));
      // All created timelines should be cleaned up
      for (final tl in created) {
        verify(() => tl.cancelSubscriptions()).called(1);
      }
    });

    test(
      'no anchor returns small snapshot without expansion when under limit',
      () async {
        final room = MockRoom();
        final log = MockLoggingService();
        final tl = MockTimeline();

        // 10 events — well under the default initialLimit of 200,
        // so no expansion loop should run.
        final events = List<Event>.generate(10, (i) {
          final e = MockEvent();
          when(() => e.eventId).thenReturn('e$i');
          when(
            () => e.originServerTs,
          ).thenReturn(DateTime.fromMillisecondsSinceEpoch(100 + i));
          return e;
        });

        when(
          () => room.getTimeline(limit: any(named: 'limit')),
        ).thenAnswer((_) async => tl);
        when(() => tl.events).thenReturn(events);
        when(() => tl.cancelSubscriptions()).thenReturn(null);

        final result = await CatchUpStrategy.collectEventsForCatchUp(
          room: room,
          lastEventId: null,
          logging: log,
          backfill:
              ({
                required Timeline timeline,
                required String? lastEventId,
                required int pageSize,
                required int? maxPages,
                required LoggingService logging,
                num? untilTimestamp,
              }) async => true,
        );

        expect(result.incomplete, isFalse);
        expect(result.events.length, 10);
        expect(result.events.first.eventId, 'e0');
        expect(result.events.last.eventId, 'e9');
        // Only the initial getTimeline call — no expansion.
        verify(() => room.getTimeline(limit: any(named: 'limit'))).called(1);
        verify(() => tl.cancelSubscriptions()).called(1);
      },
    );

    test(
      'no anchor expands timeline by doubling until all events are fetched',
      () async {
        final room = MockRoom();
        final log = MockLoggingService();
        final created = <MockTimeline>[];

        // 15 events total. initialLimit=5 so the first page is full and
        // the expansion loop doubles to 10, then 20 (capped at 15 actual).
        final all = List<Event>.generate(15, (i) {
          final e = MockEvent();
          when(() => e.eventId).thenReturn('e$i');
          when(
            () => e.originServerTs,
          ).thenReturn(DateTime.fromMillisecondsSinceEpoch(i));
          return e;
        });

        when(() => room.getTimeline(limit: any(named: 'limit'))).thenAnswer((
          invocation,
        ) async {
          final tl = MockTimeline();
          created.add(tl);
          final limit = invocation.namedArguments[#limit] as int? ?? 200;
          final start = all.length > limit ? all.length - limit : 0;
          when(() => tl.events).thenReturn(all.sublist(start));
          when(() => tl.cancelSubscriptions()).thenReturn(null);
          return tl;
        });

        final result = await CatchUpStrategy.collectEventsForCatchUp(
          room: room,
          lastEventId: null,
          logging: log,
          initialLimit: 5,
          maxLookback: 100,
          backfill:
              ({
                required Timeline timeline,
                required String? lastEventId,
                required int pageSize,
                required int? maxPages,
                required LoggingService logging,
                num? untilTimestamp,
              }) async => true,
        );

        expect(result.incomplete, isFalse);
        // All 15 events returned
        expect(result.events.length, 15);
        expect(result.events.first.eventId, 'e0');
        expect(result.events.last.eventId, 'e14');
        // initial(5) → double(10) → double(20) → returns 15 < 20 so stops
        expect(created.length, 3);
        // All expansion timelines are cleaned up
        for (final tl in created.skip(1)) {
          verify(() => tl.cancelSubscriptions()).called(1);
        }
      },
    );

    test(
      'no anchor expansion stops at maxLookback',
      () async {
        final room = MockRoom();
        final log = MockLoggingService();
        final created = <MockTimeline>[];

        // 500 events, but maxLookback=100 should cap the expansion.
        final all = List<Event>.generate(500, (i) {
          final e = MockEvent();
          when(() => e.eventId).thenReturn('e$i');
          when(
            () => e.originServerTs,
          ).thenReturn(DateTime.fromMillisecondsSinceEpoch(i));
          return e;
        });

        when(() => room.getTimeline(limit: any(named: 'limit'))).thenAnswer((
          invocation,
        ) async {
          final tl = MockTimeline();
          created.add(tl);
          final limit = invocation.namedArguments[#limit] as int? ?? 200;
          final start = all.length > limit ? all.length - limit : 0;
          when(() => tl.events).thenReturn(all.sublist(start));
          when(() => tl.cancelSubscriptions()).thenReturn(null);
          return tl;
        });

        final result = await CatchUpStrategy.collectEventsForCatchUp(
          room: room,
          lastEventId: null,
          logging: log,
          initialLimit: 10,
          maxLookback: 100,
          backfill:
              ({
                required Timeline timeline,
                required String? lastEventId,
                required int pageSize,
                required int? maxPages,
                required LoggingService logging,
                num? untilTimestamp,
              }) async => true,
        );

        expect(result.incomplete, isFalse);
        // Returns last 100 events (capped by maxLookback)
        expect(result.events.length, 100);
        expect(result.events.first.eventId, 'e400');
        expect(result.events.last.eventId, 'e499');
        // initial(10) → 20 → 40 → 80 → 100(capped) → still full so
        // loop condition (limit < maxLookback) is false, exits
        for (final tl in created.skip(1)) {
          verify(() => tl.cancelSubscriptions()).called(1);
        }
      },
    );

    test(
      'no anchor expansion stops when no new events are returned',
      () async {
        final room = MockRoom();
        final log = MockLoggingService();
        final created = <MockTimeline>[];

        // Exactly 5 events. initialLimit=5 makes the first page "full",
        // triggering expansion. The second page (limit=10) returns the
        // same 5 events, so expansion stops.
        final all = List<Event>.generate(5, (i) {
          final e = MockEvent();
          when(() => e.eventId).thenReturn('e$i');
          when(
            () => e.originServerTs,
          ).thenReturn(DateTime.fromMillisecondsSinceEpoch(i));
          return e;
        });

        when(() => room.getTimeline(limit: any(named: 'limit'))).thenAnswer((
          invocation,
        ) async {
          final tl = MockTimeline();
          created.add(tl);
          // Always returns all 5 events regardless of limit
          when(() => tl.events).thenReturn(all);
          when(() => tl.cancelSubscriptions()).thenReturn(null);
          return tl;
        });

        final result = await CatchUpStrategy.collectEventsForCatchUp(
          room: room,
          lastEventId: null,
          logging: log,
          initialLimit: 5,
          maxLookback: 100,
          backfill:
              ({
                required Timeline timeline,
                required String? lastEventId,
                required int pageSize,
                required int? maxPages,
                required LoggingService logging,
                num? untilTimestamp,
              }) async => true,
        );

        expect(result.incomplete, isFalse);
        expect(result.events.length, 5);
        // initial(5) → double(10) returns same 5 → breaks
        expect(created.length, 2);
        for (final tl in created.skip(1)) {
          verify(() => tl.cancelSubscriptions()).called(1);
        }
      },
    );

    test(
      'includes pre-context by count around the timestamp boundary',
      () async {
        final room = MockRoom();
        final log = MockLoggingService();
        final tl = MockTimeline();

        // Build ordered events: o1(ts=100), x1(ts=150), x2(ts=200)
        Event mk(String id, int ts) {
          final e = MockEvent();
          when(() => e.eventId).thenReturn(id);
          when(
            () => e.originServerTs,
          ).thenReturn(DateTime.fromMillisecondsSinceEpoch(ts));
          return e;
        }

        final events = <Event>[mk('o1', 100), mk('x1', 150), mk('x2', 200)];

        when(
          () => room.getTimeline(limit: any(named: 'limit')),
        ).thenAnswer((_) async => tl);
        when(() => tl.events).thenReturn(events);
        when(() => tl.cancelSubscriptions()).thenReturn(null);

        final result = await CatchUpStrategy.collectEventsForCatchUp(
          room: room,
          lastEventId: 'legacy-marker',
          logging: log,
          backfill:
              ({
                required Timeline timeline,
                required String? lastEventId,
                required int pageSize,
                required int? maxPages,
                required LoggingService logging,
                num? untilTimestamp,
              }) async {
                return true;
              },
          preContextSinceTs: 150,
          preContextCount: 2, // should include o1 and x1
        );

        final slice = result.events;
        expect(slice.map((e) => e.eventId), ['o1', 'x1', 'x2']);
        verify(() => tl.cancelSubscriptions()).called(1);
      },
    );

    test('includes pre-context by timestamp (since last sync)', () async {
      final room = MockRoom();
      final log = MockLoggingService();
      final tl = MockTimeline();

      // o1(ts=100), x1(ts=150), x2(ts=200)
      Event mk(String id, int ts) {
        final e = MockEvent();
        when(() => e.eventId).thenReturn(id);
        when(
          () => e.originServerTs,
        ).thenReturn(DateTime.fromMillisecondsSinceEpoch(ts));
        return e;
      }

      final events = <Event>[mk('o1', 100), mk('x1', 150), mk('x2', 200)];

      when(
        () => room.getTimeline(limit: any(named: 'limit')),
      ).thenAnswer((_) async => tl);
      when(() => tl.events).thenReturn(events);
      when(() => tl.cancelSubscriptions()).thenReturn(null);

      const sinceTs = 120; // include everything >= 120 -> [x1, x2]
      final result = await CatchUpStrategy.collectEventsForCatchUp(
        room: room,
        lastEventId: 'legacy-marker',
        logging: log,
        backfill:
            ({
              required Timeline timeline,
              required String? lastEventId,
              required int pageSize,
              required int? maxPages,
              required LoggingService logging,
              num? untilTimestamp,
            }) async => true,
        preContextSinceTs: sinceTs,
      );

      final slice = result.events;
      expect(slice.map((e) => e.eventId), ['x1', 'x2']);
      verify(() => tl.cancelSubscriptions()).called(1);
    });

    test(
      'preContextCount=1 includes exactly one before the timestamp boundary',
      () async {
        final room = MockRoom();
        final log = MockLoggingService();
        final tl = MockTimeline();

        // Ordered events: e0(ts=100), m(ts=150)[marker], e1(ts=200)
        Event mk(String id, int ts) {
          final e = MockEvent();
          when(() => e.eventId).thenReturn(id);
          when(
            () => e.originServerTs,
          ).thenReturn(DateTime.fromMillisecondsSinceEpoch(ts));
          return e;
        }

        final e0 = mk('e0', 100);
        final m = mk('m', 150);
        final e1 = mk('e1', 200);
        when(
          () => room.getTimeline(limit: any(named: 'limit')),
        ).thenAnswer((_) async => tl);
        when(() => tl.events).thenReturn(<Event>[e0, m, e1]);
        when(() => tl.cancelSubscriptions()).thenReturn(null);

        final result = await CatchUpStrategy.collectEventsForCatchUp(
          room: room,
          lastEventId: 'legacy-marker',
          logging: log,
          backfill:
              ({
                required Timeline timeline,
                required String? lastEventId,
                required int pageSize,
                required int? maxPages,
                required LoggingService logging,
                num? untilTimestamp,
              }) async => true,
          preContextSinceTs: 150,
          preContextCount: 1,
        );

        final slice = result.events;
        expect(slice.map((e) => e.eventId), ['e0', 'm', 'e1']);
        verify(() => tl.cancelSubscriptions()).called(1);
      },
    );

    test(
      'preContextSinceTs equals earliest timestamp does not over-include',
      () async {
        final room = MockRoom();
        final log = MockLoggingService();
        final tl = MockTimeline();

        // Earliest ts is 100; marker at 150; latest 200
        Event mk(String id, int ts) {
          final e = MockEvent();
          when(() => e.eventId).thenReturn(id);
          when(
            () => e.originServerTs,
          ).thenReturn(DateTime.fromMillisecondsSinceEpoch(ts));
          return e;
        }

        final e0 = mk('e0', 100);
        final m = mk('m', 150);
        final e1 = mk('e1', 200);

        when(
          () => room.getTimeline(limit: any(named: 'limit')),
        ).thenAnswer((_) async => tl);
        when(() => tl.events).thenReturn(<Event>[e0, m, e1]);
        when(() => tl.cancelSubscriptions()).thenReturn(null);

        final result = await CatchUpStrategy.collectEventsForCatchUp(
          room: room,
          lastEventId: 'legacy-marker',
          logging: log,
          backfill:
              ({
                required Timeline timeline,
                required String? lastEventId,
                required int pageSize,
                required int? maxPages,
                required LoggingService logging,
                num? untilTimestamp,
              }) async => true,
          preContextSinceTs: 100, // equals earliest
        );

        final slice = result.events;
        // Expect inclusion from the earliest, with no over-inclusion, and marker present
        expect(slice.map((e) => e.eventId), ['e0', 'm', 'e1']);
        verify(() => tl.cancelSubscriptions()).called(1);
      },
    );

    test(
      'returns best-effort events when older history is not reachable',
      () async {
        final room = MockRoom();
        final log = MockLoggingService();
        final tl = MockTimeline();

        // Simple window e0..e2, marker not present
        final events = List<Event>.generate(3, (i) {
          final e = MockEvent();
          when(() => e.eventId).thenReturn('e$i');
          when(
            () => e.originServerTs,
          ).thenReturn(DateTime.fromMillisecondsSinceEpoch(100 + i));
          return e;
        });

        when(
          () => room.getTimeline(limit: any(named: 'limit')),
        ).thenAnswer((_) async => tl);
        when(() => tl.events).thenReturn(events);
        when(() => tl.cancelSubscriptions()).thenReturn(null);

        final result = await CatchUpStrategy.collectEventsForCatchUp(
          room: room,
          lastEventId: 'legacy-marker',
          logging: log,
          backfill:
              ({
                required Timeline timeline,
                required String? lastEventId,
                required int pageSize,
                required int? maxPages,
                required LoggingService logging,
                num? untilTimestamp,
              }) async => false,
          preContextCount: 5,
          preContextSinceTs: 50,
        );

        // Best-effort: returns all 3 visible events even though the
        // timestamp boundary (50) was not reached.
        expect(result.incomplete, isFalse);
        expect(result.timestampAnchored, isTrue);
        expect(result.events, hasLength(3));
        expect(result.snapshotSize, events.length);
        verify(() => tl.cancelSubscriptions()).called(1);
      },
    );

    test(
      'replays from timestamp boundary after backfill reaches older history',
      () async {
        final room = MockRoom();
        final log = MockLoggingService();
        final tl = MockTimeline();
        num? capturedUntilTimestamp;
        int? capturedMaxPages;

        Event mk(String id, int ts) {
          final e = MockEvent();
          when(() => e.eventId).thenReturn(id);
          when(
            () => e.originServerTs,
          ).thenReturn(DateTime.fromMillisecondsSinceEpoch(ts));
          return e;
        }

        final events = <Event>[mk('e0', 100), mk('e1', 101), mk('e2', 102)];

        when(
          () => room.getTimeline(limit: any(named: 'limit')),
        ).thenAnswer((_) async => tl);
        when(() => tl.events).thenReturn(events);
        when(() => tl.cancelSubscriptions()).thenReturn(null);

        final result = await CatchUpStrategy.collectEventsForCatchUp(
          room: room,
          lastEventId: 'legacy-marker',
          logging: log,
          backfill:
              ({
                required Timeline timeline,
                required String? lastEventId,
                required int pageSize,
                required int? maxPages,
                required LoggingService logging,
                num? untilTimestamp,
              }) async {
                capturedUntilTimestamp = untilTimestamp;
                capturedMaxPages = maxPages;
                events.insert(0, mk('older', 40));
                return true;
              },
          preContextCount: 5,
          preContextSinceTs: 50,
        );

        expect(capturedUntilTimestamp, 50);
        expect(capturedMaxPages, isNull);
        expect(result.incomplete, isFalse);
        expect(result.timestampAnchored, isTrue);
        expect(result.events.map((event) => event.eventId), [
          'older',
          'e0',
          'e1',
          'e2',
        ]);
        expect(result.reachedTimestampBoundary, isTrue);
        verify(() => tl.cancelSubscriptions()).called(1);
      },
    );
  });

  test(
    'returns CatchUpCollection.incomplete when the snapshot is empty '
    'and the timestamp boundary cannot be satisfied — exercises the '
    'incomplete-return branch and its diagnostics log',
    () async {
      final room = MockRoom();
      final log = MockLoggingService();
      final tl = MockTimeline();
      when(
        () => room.getTimeline(limit: any(named: 'limit')),
      ).thenAnswer((_) async => tl);
      when(() => tl.events).thenReturn(<Event>[]);
      when(() => tl.cancelSubscriptions()).thenReturn(null);
      when(() => room.prev_batch).thenReturn(null);

      final result = await CatchUpStrategy.collectEventsForCatchUp(
        room: room,
        lastEventId: null,
        logging: log,
        backfill:
            ({
              required Timeline timeline,
              required String? lastEventId,
              required int pageSize,
              required int? maxPages,
              required LoggingService logging,
              num? untilTimestamp,
            }) async => false,
        preContextSinceTs: 10_000,
      );
      expect(result.incomplete, isTrue);
      expect(result.events, isEmpty);
      expect(result.reachedTimestampBoundary, isFalse);
      verify(
        () => log.captureEvent(
          any<String>(that: contains('catchup.incomplete')),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'),
        ),
      ).called(1);
    },
  );

  test(
    'no-anchor expansion logs through captureException when an '
    'intermediate timeline.cancelSubscriptions throws',
    () async {
      final room = MockRoom();
      final log = MockLoggingService();
      final tl0 = MockTimeline();
      final tl1 = MockTimeline();
      final firstEvents = List<Event>.generate(200, (i) {
        final e = MockEvent();
        when(() => e.eventId).thenReturn('e$i');
        when(
          () => e.originServerTs,
        ).thenReturn(DateTime.fromMillisecondsSinceEpoch(i));
        return e;
      });
      // Second timeline returns the same rows so `nextEvents.length
      // <= ordered.length` short-circuits expansion — but the
      // `finally` still runs `cancelSubscriptions` which we make
      // throw, exercising the catch-and-log branch.
      when(
        () => room.getTimeline(limit: any(named: 'limit')),
      ).thenAnswer((invocation) async {
        final limit = invocation.namedArguments[#limit] as int? ?? 200;
        return limit == 200 ? tl0 : tl1;
      });
      when(() => tl0.events).thenReturn(firstEvents);
      when(() => tl0.cancelSubscriptions()).thenReturn(null);
      when(() => tl1.events).thenReturn(firstEvents);
      when(
        () => tl1.cancelSubscriptions(),
      ).thenThrow(StateError('cleanup boom'));

      final result = await CatchUpStrategy.collectEventsForCatchUp(
        room: room,
        lastEventId: 'legacy-marker',
        logging: log,
        backfill:
            ({
              required Timeline timeline,
              required String? lastEventId,
              required int pageSize,
              required int? maxPages,
              required LoggingService logging,
              num? untilTimestamp,
            }) async => false,
        // preContextSinceTs: null → no-anchor branch.
      );
      expect(result.events, hasLength(200));
      verify(
        () => log.captureException(
          any<Object>(),
          domain: any(named: 'domain'),
          subDomain: any(
            named: 'subDomain',
            that: contains('catchup.noAnchor.cleanup'),
          ),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
        ),
      ).called(1);
    },
  );

  group('collectHistoryForBootstrap', () {
    Event buildEvent(String id, int tsMs) {
      final e = MockEvent();
      when(() => e.eventId).thenReturn(id);
      when(
        () => e.originServerTs,
      ).thenReturn(DateTime.fromMillisecondsSinceEpoch(tsMs));
      return e;
    }

    test(
      'emits each event exactly once without an ever-growing seen-set '
      '(memory bounded by page size, not total history depth)',
      () async {
        final room = MockRoom();
        final log = MockLoggingService();
        final tl = MockTimeline();

        // The SDK stores events in a single mutable list that grows as
        // `requestHistory()` loads older pages — simulate that by
        // starting with the newest 3 events and prepending older ones
        // on each call.
        final events = <Event>[
          buildEvent('e3', 300),
          buildEvent('e4', 400),
          buildEvent('e5', 500),
        ];
        var requests = 0;
        when(
          () => room.getTimeline(limit: any(named: 'limit')),
        ).thenAnswer((_) async => tl);
        when(() => tl.events).thenAnswer((_) => events);
        when(() => tl.canRequestHistory).thenAnswer((_) => requests < 2);
        when(
          () => tl.requestHistory(historyCount: any(named: 'historyCount')),
        ).thenAnswer((_) async {
          requests++;
          if (requests == 1) {
            events
              ..insert(0, buildEvent('e1', 100))
              ..insert(0, buildEvent('e2', 200));
          } else {
            events.insert(0, buildEvent('e0', 50));
          }
        });
        when(() => tl.cancelSubscriptions()).thenReturn(null);

        final collected = <List<String>>[];
        final result = await CatchUpStrategy.collectHistoryForBootstrap(
          room: room,
          logging: log,
          sink: _CollectingBootstrapSink((page) {
            collected.add([for (final e in page) e.eventId]);
          }),
          pageSize: 3,
        );

        // Every event id appears across the emitted pages exactly once
        // — proving the anchor-based dedup. The earlier implementation
        // would have carried a seen-set growing with total history.
        final flat = <String>[
          for (final page in collected) ...page,
        ];
        expect(flat.toSet(), hasLength(flat.length));
        expect(flat, containsAll(['e0', 'e1', 'e2', 'e3', 'e4', 'e5']));
        expect(result.stopReason, BootstrapStopReason.serverExhausted);
        expect(result.totalEvents, flat.length);
      },
    );

    test(
      'timestamp ties between pages are resolved by eventId so a later '
      'page cannot re-emit an already-emitted event at the same ts',
      () async {
        final room = MockRoom();
        final log = MockLoggingService();
        final tl = MockTimeline();

        // First page: two events at ts=100 with ids ordered 'b','a'
        // (lex-descending). The anchor after page 0 should lock to the
        // earliest (ts, eventId) = (100, 'a'). When page 1 adds
        // another ts=100 event with id='c' (lex > 'a'), the strict
        // (ts, id) older-than test must filter it out.
        final events = <Event>[
          buildEvent('a', 100),
          buildEvent('b', 100),
        ];
        var requests = 0;
        when(
          () => room.getTimeline(limit: any(named: 'limit')),
        ).thenAnswer((_) async => tl);
        when(() => tl.events).thenAnswer((_) => events);
        when(() => tl.canRequestHistory).thenAnswer((_) => requests == 0);
        when(
          () => tl.requestHistory(historyCount: any(named: 'historyCount')),
        ).thenAnswer((_) async {
          requests++;
          events.add(buildEvent('c', 100));
        });
        when(() => tl.cancelSubscriptions()).thenReturn(null);

        final collected = <String>[];
        await CatchUpStrategy.collectHistoryForBootstrap(
          room: room,
          logging: log,
          sink: _CollectingBootstrapSink((page) {
            collected.addAll(page.map((e) => e.eventId));
          }),
          pageSize: 3,
        );
        // 'c' has the same timestamp but sorts AFTER 'a', so it is not
        // strictly older than the anchor and must not be re-emitted.
        // Equally, 'a' and 'b' are emitted only once from the first
        // iteration.
        expect(collected, ['a', 'b']);
      },
    );

    test(
      'overallTimeout ends paging with stopReason=error before the next '
      'requestHistory fires',
      () async {
        final room = MockRoom();
        final log = MockLoggingService();
        final tl = MockTimeline();
        final events = <Event>[buildEvent('x', 1)];
        when(
          () => room.getTimeline(limit: any(named: 'limit')),
        ).thenAnswer((_) async => tl);
        when(() => tl.events).thenAnswer((_) => events);
        when(() => tl.canRequestHistory).thenReturn(true);
        when(() => tl.cancelSubscriptions()).thenReturn(null);

        // A zero timeout is already exceeded on the first iteration.
        final result = await CatchUpStrategy.collectHistoryForBootstrap(
          room: room,
          logging: log,
          sink: _CollectingBootstrapSink((_) {}),
          pageSize: 1,
          overallTimeout: Duration.zero,
        );
        expect(result.stopReason, BootstrapStopReason.error);
        verifyNever(
          () => tl.requestHistory(historyCount: any(named: 'historyCount')),
        );
      },
    );

    test(
      'requestHistory throwing is captured on logging and stops paging '
      'with stopReason=error (no unhandled future)',
      () async {
        final room = MockRoom();
        final log = MockLoggingService();
        final tl = MockTimeline();
        when(
          () => room.getTimeline(limit: any(named: 'limit')),
        ).thenAnswer((_) async => tl);
        when(() => tl.events).thenAnswer((_) => <Event>[buildEvent('x', 1)]);
        when(() => tl.canRequestHistory).thenReturn(true);
        when(
          () => tl.requestHistory(historyCount: any(named: 'historyCount')),
        ).thenThrow(StateError('server hung up'));
        when(() => tl.cancelSubscriptions()).thenReturn(null);

        final result = await CatchUpStrategy.collectHistoryForBootstrap(
          room: room,
          logging: log,
          sink: _CollectingBootstrapSink((_) {}),
          pageSize: 1,
        );
        expect(result.stopReason, BootstrapStopReason.error);
        verify(
          () => log.captureException(
            any<Object>(),
            domain: any(named: 'domain'),
            subDomain: any(
              named: 'subDomain',
              that: contains('bootstrap.requestHistory'),
            ),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
          ),
        ).called(1);
      },
    );

    test(
      'timestamp ties on the oldest boundary update the eventId anchor '
      'when the new first id is lex-smaller',
      () async {
        final room = MockRoom();
        final log = MockLoggingService();
        final tl = MockTimeline();
        // Page 0 emits two events at ts=100, oldest by (ts, id) is 'm'.
        final events = <Event>[
          buildEvent('m', 100),
          buildEvent('z', 100),
        ];
        var requests = 0;
        when(
          () => room.getTimeline(limit: any(named: 'limit')),
        ).thenAnswer((_) async => tl);
        when(() => tl.events).thenAnswer((_) => events);
        when(() => tl.canRequestHistory).thenAnswer((_) => requests == 0);
        when(
          () => tl.requestHistory(historyCount: any(named: 'historyCount')),
        ).thenAnswer((_) async {
          requests++;
          // Add an event still at ts=100 but lex-smaller than the
          // current anchor — it must be emitted exactly once because
          // the strict (ts, id) comparison flags it as older.
          events.add(buildEvent('a', 100));
        });
        when(() => tl.cancelSubscriptions()).thenReturn(null);

        final collected = <String>[];
        await CatchUpStrategy.collectHistoryForBootstrap(
          room: room,
          logging: log,
          sink: _CollectingBootstrapSink((page) {
            collected.addAll(page.map((e) => e.eventId));
          }),
          pageSize: 3,
        );
        expect(collected, ['m', 'z', 'a']);
      },
    );

    test(
      'sink cancellation halts paging before the next requestHistory',
      () async {
        final room = MockRoom();
        final log = MockLoggingService();
        final tl = MockTimeline();
        final events = <Event>[buildEvent('x', 1)];
        when(
          () => room.getTimeline(limit: any(named: 'limit')),
        ).thenAnswer((_) async => tl);
        when(() => tl.events).thenAnswer((_) => events);
        when(() => tl.canRequestHistory).thenReturn(true);
        when(() => tl.cancelSubscriptions()).thenReturn(null);

        final result = await CatchUpStrategy.collectHistoryForBootstrap(
          room: room,
          logging: log,
          sink: _CollectingBootstrapSink((_) {}, continueAfterPage: false),
          pageSize: 1,
        );
        expect(result.stopReason, BootstrapStopReason.sinkCancelled);
        verifyNever(
          () => tl.requestHistory(historyCount: any(named: 'historyCount')),
        );
      },
    );

    test(
      'untilTimestamp stops pagination after the first page whose '
      'oldest event is at or below the boundary — reconnect catch-up '
      'does not walk further back than the queue marker',
      () async {
        final room = MockRoom();
        final log = MockLoggingService();
        final tl = MockTimeline();

        // Initial snapshot: three events strictly newer than the boundary.
        final events = <Event>[
          buildEvent('e3', 300),
          buildEvent('e4', 400),
          buildEvent('e5', 500),
        ];
        var requests = 0;
        when(
          () => room.getTimeline(limit: any(named: 'limit')),
        ).thenAnswer((_) async => tl);
        when(() => tl.events).thenAnswer((_) => events);
        when(() => tl.canRequestHistory).thenAnswer((_) => true);
        when(
          () => tl.requestHistory(historyCount: any(named: 'historyCount')),
        ).thenAnswer((_) async {
          requests++;
          if (requests == 1) {
            // This page crosses the boundary (ts=200 == untilTimestamp).
            events
              ..insert(0, buildEvent('e1', 100))
              ..insert(0, buildEvent('e2', 200));
          } else {
            events.insert(0, buildEvent('e0', 50));
          }
        });
        when(() => tl.cancelSubscriptions()).thenReturn(null);

        final collected = <String>[];
        final result = await CatchUpStrategy.collectHistoryForBootstrap(
          room: room,
          logging: log,
          sink: _CollectingBootstrapSink((page) {
            collected.addAll([for (final e in page) e.eventId]);
          }),
          pageSize: 3,
          untilTimestamp: 200,
        );

        expect(result.stopReason, BootstrapStopReason.boundaryReached);
        // Only one requestHistory call: the snapshot alone was all >
        // boundary, so the first page emits e3/e4/e5 and triggers a
        // requestHistory that pulls in e1/e2 (boundary-crossing page).
        // Further pagination is skipped — e0 never makes it out.
        expect(collected, containsAll(['e1', 'e2', 'e3', 'e4', 'e5']));
        expect(collected, isNot(contains('e0')));
      },
    );

    test(
      'untilTimestamp does not trigger early stop when the snapshot is '
      'already entirely older than the boundary — pagination has never '
      'emitted a fresh page, so the first page is still worth the '
      'queue seeing (the queue dedups anything older)',
      () async {
        final room = MockRoom();
        final log = MockLoggingService();
        final tl = MockTimeline();

        // Whole initial snapshot is at ts=50, already below a
        // boundary of 100. The first page's page.first.ts is 50 <= 100,
        // so the boundary check fires immediately after page 0 emits.
        final events = <Event>[buildEvent('a', 50), buildEvent('b', 60)];
        when(
          () => room.getTimeline(limit: any(named: 'limit')),
        ).thenAnswer((_) async => tl);
        when(() => tl.events).thenAnswer((_) => events);
        when(() => tl.canRequestHistory).thenAnswer((_) => true);
        when(() => tl.cancelSubscriptions()).thenReturn(null);

        final collected = <String>[];
        final result = await CatchUpStrategy.collectHistoryForBootstrap(
          room: room,
          logging: log,
          sink: _CollectingBootstrapSink((page) {
            collected.addAll([for (final e in page) e.eventId]);
          }),
          pageSize: 2,
          untilTimestamp: 100,
        );

        expect(result.stopReason, BootstrapStopReason.boundaryReached);
        expect(collected, ['a', 'b']);
        verifyNever(
          () => tl.requestHistory(historyCount: any(named: 'historyCount')),
        );
      },
    );

    test(
      'boundary-crossing page with accepted=0 keeps paginating up to the '
      'cap so an SDK cache with a stale wake-up window can pull more '
      'history and the bridge does not exit prematurely',
      () async {
        final room = MockRoom();
        final log = MockLoggingService();
        final tl = MockTimeline();

        // Every page is at-or-below the boundary (ts <= 100). Without
        // the continuation logic the bridge would stop on page 0. With
        // `acceptedPerPage=0` the sink pretends nothing new applied,
        // so the strategy is expected to keep paginating until the cap.
        final events = <Event>[buildEvent('e-0', 50)];
        var historyCalls = 0;
        when(
          () => room.getTimeline(limit: any(named: 'limit')),
        ).thenAnswer((_) async => tl);
        when(() => tl.events).thenAnswer((_) => events);
        when(() => tl.canRequestHistory).thenAnswer((_) => true);
        when(
          () => tl.requestHistory(historyCount: any(named: 'historyCount')),
        ).thenAnswer((_) async {
          historyCalls++;
          events.insert(0, buildEvent('e-$historyCalls', 50 - historyCalls));
        });
        when(() => tl.cancelSubscriptions()).thenReturn(null);

        final result = await CatchUpStrategy.collectHistoryForBootstrap(
          room: room,
          logging: log,
          sink: _CollectingBootstrapSink((_) {}, acceptedPerPage: 0),
          pageSize: 1,
          untilTimestamp: 100,
          boundaryContinuationCap: 3,
        );

        // Stopped on cap, not on server-exhausted.
        expect(result.stopReason, BootstrapStopReason.boundaryReached);
        // Reached the cap — 3 continuation attempts on top of the
        // initial page = 3 history calls. Fewer would be a regression
        // (stopped too early); more would be a runaway.
        expect(historyCalls, 3);
      },
    );

    test(
      'boundary-crossing page with accepted>0 stops immediately — the '
      'continuation only kicks in when the sink accepted zero events',
      () async {
        final room = MockRoom();
        final log = MockLoggingService();
        final tl = MockTimeline();

        final events = <Event>[buildEvent('e-0', 50)];
        var historyCalls = 0;
        when(
          () => room.getTimeline(limit: any(named: 'limit')),
        ).thenAnswer((_) async => tl);
        when(() => tl.events).thenAnswer((_) => events);
        when(() => tl.canRequestHistory).thenAnswer((_) => true);
        when(
          () => tl.requestHistory(historyCount: any(named: 'historyCount')),
        ).thenAnswer((_) async {
          historyCalls++;
        });
        when(() => tl.cancelSubscriptions()).thenReturn(null);

        final result = await CatchUpStrategy.collectHistoryForBootstrap(
          room: room,
          logging: log,
          // acceptedPerPage=5 — the sink reports a productive page, so
          // the strategy treats the boundary as satisfied and does NOT
          // paginate further.
          sink: _CollectingBootstrapSink((_) {}, acceptedPerPage: 5),
          pageSize: 1,
          untilTimestamp: 100,
          boundaryContinuationCap: 10,
        );

        expect(result.stopReason, BootstrapStopReason.boundaryReached);
        expect(historyCalls, 0);
      },
    );
  });
}

class MockEvent extends Mock implements Event {}

class _CollectingBootstrapSink implements BootstrapSink {
  _CollectingBootstrapSink(
    this._onPage, {
    this.continueAfterPage = true,
    this.acceptedPerPage,
  });

  final void Function(List<Event> page) _onPage;
  final bool continueAfterPage;

  /// When non-null, returned as `lastAcceptedCount` after every
  /// [onPage] call. Drives the
  /// `CatchUpStrategy.boundaryContinuationCap` path: callers set
  /// this to `0` to simulate a sink that sees the page but rejects
  /// all of it (dupes / filtered-out-by-type), or to a positive
  /// count to simulate a productive page.
  final int? acceptedPerPage;

  int _lastAccepted = 0;

  @override
  int? get lastAcceptedCount => acceptedPerPage ?? _lastAccepted;

  @override
  Future<bool> onPage(List<Event> events, BootstrapPageInfo info) async {
    _onPage(events);
    _lastAccepted = events.length;
    return continueAfterPage;
  }
}
