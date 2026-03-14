import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/sdk_pagination_compat.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/models/timeline_chunk.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  group('SdkPaginationCompat', () {
    Event event(String id, int ts) {
      final e = MockEvent();
      when(() => e.eventId).thenReturn(id);
      when(
        () => e.originServerTs,
      ).thenReturn(DateTime.fromMillisecondsSinceEpoch(ts));
      return e;
    }

    void stubLogging(MockLoggingService logging) {
      when(
        () => logging.captureException(
          any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
        ),
      ).thenAnswer((_) async {});
    }

    test(
      'returns false when both marker and timestamp anchors are absent',
      () async {
        final timeline = MockTimeline();
        final logging = MockLoggingService();

        final result = await SdkPaginationCompat.backfillUntilContains(
          timeline: timeline,
          lastEventId: null,
          pageSize: 200,
          maxPages: null,
          logging: logging,
        );

        expect(result, isFalse);
        verifyNever(
          () => logging.captureException(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
          ),
        );
      },
    );

    test(
      'returns true when local history already crosses the timestamp boundary and no server gap is advertised',
      () async {
        final timeline = MockTimeline();
        final room = MockRoom();
        final logging = MockLoggingService();
        final cachedEvents = [event('old', 40), event('new', 200)];

        stubLogging(logging);
        when(() => room.prev_batch).thenReturn(null);
        when(() => timeline.room).thenReturn(room);
        when(() => timeline.events).thenReturn(cachedEvents);

        final result = await SdkPaginationCompat.backfillUntilContains(
          timeline: timeline,
          lastEventId: null,
          pageSize: 200,
          maxPages: null,
          logging: logging,
          untilTimestamp: 50,
        );

        expect(result, isTrue);
        verifyNever(
          () =>
              timeline.requestHistory(historyCount: any(named: 'historyCount')),
        );
      },
    );

    test(
      'pages to timestamp boundary even when no event id is stored',
      () async {
        final timeline = MockTimeline();
        final room = MockRoom();
        final logging = MockLoggingService();

        final newer = <Event>[event('n1', 200), event('n2', 210)];
        final older = <Event>[event('o1', 40), event('o2', 50)];

        var current = newer;
        var requested = 0;
        when(() => room.prev_batch).thenReturn(null);
        when(() => timeline.room).thenReturn(room);
        when(() => timeline.events).thenAnswer((_) => current);
        when(() => timeline.canRequestHistory).thenAnswer((_) => requested < 1);
        when(
          () =>
              timeline.requestHistory(historyCount: any(named: 'historyCount')),
        ).thenAnswer((invocation) async {
          expect(
            invocation.namedArguments[#historyCount],
            200,
          );
          current = [...current, ...older];
          requested++;
        });
        stubLogging(logging);

        final result = await SdkPaginationCompat.backfillUntilContains(
          timeline: timeline,
          lastEventId: null,
          pageSize: 200,
          maxPages: null,
          logging: logging,
          untilTimestamp: 50,
        );

        expect(result, isTrue);
        expect(requested, 1);
        final ordered = [...current]
          ..sort(
            (a, b) => a.originServerTs.compareTo(b.originServerTs),
          );
        expect(
          ordered.first.originServerTs.millisecondsSinceEpoch,
          lessThanOrEqualTo(50),
        );
      },
    );

    test(
      'requires a server history page when prev_batch exists even if cached history already crosses the boundary',
      () async {
        final timeline = MockTimeline();
        final room = MockRoom();
        final logging = MockLoggingService();

        final chunk = TimelineChunk(
          events: [event('cached-new', 200), event('cached-old', 40)],
        );
        final serverGap = event('server-gap', 45);
        var current = chunk.events;
        var requested = 0;

        when(() => room.prev_batch).thenReturn('server-gap-token');
        when(() => timeline.room).thenReturn(room);
        when(() => timeline.chunk).thenReturn(chunk);
        when(() => timeline.events).thenAnswer((_) => current);
        when(() => timeline.canRequestHistory).thenAnswer((_) => requested < 1);
        when(() => timeline.isFragmentedTimeline = any()).thenReturn(true);
        when(() => timeline.allowNewEvent = any()).thenReturn(false);
        when(
          () =>
              timeline.requestHistory(historyCount: any(named: 'historyCount')),
        ).thenAnswer((invocation) async {
          expect(
            invocation.namedArguments[#historyCount],
            200,
          );
          current = [...current, serverGap];
          requested++;
        });
        stubLogging(logging);

        final result = await SdkPaginationCompat.backfillUntilContains(
          timeline: timeline,
          lastEventId: null,
          pageSize: 200,
          maxPages: null,
          logging: logging,
          untilTimestamp: 50,
        );

        expect(result, isTrue);
        expect(requested, 1);
        expect(chunk.prevBatch, 'server-gap-token');
        verify(() => timeline.isFragmentedTimeline = true).called(1);
      },
    );

    test('logs and returns false when requestHistory throws', () async {
      final timeline = MockTimeline();
      final room = MockRoom();
      final logging = MockLoggingService();
      final visibleEvents = [event('new', 200)];

      stubLogging(logging);
      when(() => room.prev_batch).thenReturn(null);
      when(() => timeline.room).thenReturn(room);
      when(() => timeline.events).thenReturn(visibleEvents);
      when(() => timeline.canRequestHistory).thenReturn(true);
      when(
        () => timeline.requestHistory(historyCount: any(named: 'historyCount')),
      ).thenThrow(StateError('boom'));

      final result = await SdkPaginationCompat.backfillUntilContains(
        timeline: timeline,
        lastEventId: null,
        pageSize: 200,
        maxPages: null,
        logging: logging,
        untilTimestamp: 50,
      );

      expect(result, isFalse);
      verify(
        () => logging.captureException(
          any<Object>(that: isA<StateError>()),
          domain: syncLoggingDomain,
          subDomain: 'sdkPagination.requestHistory',
          stackTrace: any<StackTrace>(named: 'stackTrace'),
        ),
      ).called(1);
    });

    test('returns false when paging makes no progress', () async {
      final timeline = MockTimeline();
      final room = MockRoom();
      final logging = MockLoggingService();
      final visibleEvents = [event('new', 200)];

      stubLogging(logging);
      when(() => room.prev_batch).thenReturn(null);
      when(() => timeline.room).thenReturn(room);
      when(() => timeline.events).thenReturn(visibleEvents);
      when(() => timeline.canRequestHistory).thenReturn(true);
      when(
        () => timeline.requestHistory(historyCount: any(named: 'historyCount')),
      ).thenAnswer((_) async {});

      final result = await SdkPaginationCompat.backfillUntilContains(
        timeline: timeline,
        lastEventId: null,
        pageSize: 200,
        maxPages: 1,
        logging: logging,
        untilTimestamp: 50,
      );

      expect(result, isFalse);
    });
  });
}
