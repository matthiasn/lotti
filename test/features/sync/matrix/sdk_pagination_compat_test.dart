import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/sdk_pagination_compat.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/models/timeline_chunk.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

enum _GeneratedMarkerKind {
  none,
  initial,
  page,
  missing,
}

class _GeneratedVisibleEvent {
  const _GeneratedVisibleEvent({
    required this.id,
    required this.timestampMs,
  });

  final String id;
  final int timestampMs;
}

class _GeneratedPaginationScenario {
  const _GeneratedPaginationScenario({
    required this.initialBuckets,
    required this.pageBuckets,
    required this.hasTimestamp,
    required this.boundaryBucket,
    required this.markerKind,
    required this.markerSlot,
    required this.hasPrevBatch,
    required this.unlimitedPages,
    required this.maxPages,
    required this.throwAt,
    required this.noProgressAt,
  });

  final List<int> initialBuckets;
  final List<int> pageBuckets;
  final bool hasTimestamp;
  final int boundaryBucket;
  final _GeneratedMarkerKind markerKind;
  final int markerSlot;
  final bool hasPrevBatch;
  final bool unlimitedPages;
  final int maxPages;
  final int throwAt;
  final int noProgressAt;

  num? get untilTimestamp => hasTimestamp ? 1000 + boundaryBucket : null;

  int? get maxPagesArgument => unlimitedPages ? null : maxPages;

  String? get lastEventId {
    switch (markerKind) {
      case _GeneratedMarkerKind.none:
        return null;
      case _GeneratedMarkerKind.initial:
        return r'$initial-'
            '$markerSlot';
      case _GeneratedMarkerKind.page:
        return r'$page-'
            '$markerSlot';
      case _GeneratedMarkerKind.missing:
        return r'$missing-marker';
    }
  }

  List<_GeneratedVisibleEvent> get initialEvents => [
    for (var index = 0; index < initialBuckets.length; index++)
      _GeneratedVisibleEvent(
        id:
            r'$initial-'
            '$index',
        timestampMs: 1000 + initialBuckets[index],
      ),
  ];

  _GeneratedVisibleEvent pageEvent(int index) => _GeneratedVisibleEvent(
    id:
        r'$page-'
        '$index',
    timestampMs: 1000 + pageBuckets[index],
  );

  bool expectedResult() {
    final anchorId = lastEventId;
    final boundary = untilTimestamp;
    if (anchorId == null && boundary == null) return false;

    final events = [...initialEvents];
    var pages = 0;
    var requested = 0;
    var boundaryReached = false;
    var markerReached = false;
    final requireServerBoundaryPage = hasPrevBatch && boundary != null;

    while (maxPagesArgument == null || pages < maxPagesArgument!) {
      final sorted = [...events]
        ..sort((a, b) => a.timestampMs.compareTo(b.timestampMs));
      final tsBoundaryMet =
          boundary != null &&
          sorted.isNotEmpty &&
          sorted.first.timestampMs <= boundary;
      if (tsBoundaryMet && (!requireServerBoundaryPage || boundaryReached)) {
        return true;
      }

      markerReached = events.any((event) => event.id == anchorId);
      if (markerReached && !requireServerBoundaryPage && boundary == null) {
        return true;
      }

      if (requested >= pageBuckets.length) break;
      final beforeCount = events.length;
      if (throwAt == requested) break;
      if (noProgressAt == requested) {
        requested++;
        if (events.length <= beforeCount) break;
      }

      final appended = pageEvent(requested);
      events.add(appended);
      requested++;
      if (boundary != null && appended.timestampMs <= boundary) {
        boundaryReached = true;
      }
      pages++;
    }

    if (boundary != null && !requireServerBoundaryPage && events.isNotEmpty) {
      final sorted = [...events]
        ..sort((a, b) => a.timestampMs.compareTo(b.timestampMs));
      if (sorted.first.timestampMs <= boundary) return true;
    }
    if (boundary != null) return boundaryReached;
    return markerReached || boundaryReached;
  }

  @override
  String toString() {
    return '_GeneratedPaginationScenario('
        'initialBuckets: $initialBuckets, '
        'pageBuckets: $pageBuckets, '
        'hasTimestamp: $hasTimestamp, '
        'boundaryBucket: $boundaryBucket, '
        'markerKind: $markerKind, '
        'markerSlot: $markerSlot, '
        'hasPrevBatch: $hasPrevBatch, '
        'unlimitedPages: $unlimitedPages, '
        'maxPages: $maxPages, '
        'throwAt: $throwAt, '
        'noProgressAt: $noProgressAt'
        ')';
  }
}

class _GeneratedPaginationTail {
  const _GeneratedPaginationTail({
    required this.hasPrevBatch,
    required this.unlimitedPages,
    required this.maxPages,
    required this.throwAt,
    required this.noProgressAt,
  });

  final bool hasPrevBatch;
  final bool unlimitedPages;
  final int maxPages;
  final int throwAt;
  final int noProgressAt;
}

class _GeneratedMarkerSpec {
  const _GeneratedMarkerSpec({
    required this.kind,
    required this.slot,
  });

  final _GeneratedMarkerKind kind;
  final int slot;
}

extension _AnySdkPaginationScenario on glados.Any {
  glados.Generator<_GeneratedMarkerKind> get markerKind =>
      glados.AnyUtils(this).choose(_GeneratedMarkerKind.values);

  glados.Generator<_GeneratedMarkerSpec> get markerSpec =>
      glados.CombinableAny(this).combine2(
        markerKind,
        glados.IntAnys(this).intInRange(0, 5),
        (
          _GeneratedMarkerKind kind,
          int slot,
        ) => _GeneratedMarkerSpec(kind: kind, slot: slot),
      );

  glados.Generator<_GeneratedPaginationTail> get paginationTail =>
      glados.CombinableAny(this).combine5(
        glados.BoolAny(this).bool,
        glados.BoolAny(this).bool,
        glados.IntAnys(this).intInRange(0, 5),
        glados.IntAnys(this).intInRange(0, 6),
        glados.IntAnys(this).intInRange(0, 6),
        (
          bool hasPrevBatch,
          bool unlimitedPages,
          int maxPages,
          int throwAt,
          int noProgressAt,
        ) => _GeneratedPaginationTail(
          hasPrevBatch: hasPrevBatch,
          unlimitedPages: unlimitedPages,
          maxPages: maxPages,
          throwAt: throwAt,
          noProgressAt: noProgressAt,
        ),
      );

  glados.Generator<_GeneratedPaginationScenario> get paginationScenario =>
      glados.CombinableAny(this).combine6(
        glados.ListAnys(
          this,
        ).listWithLengthInRange(0, 4, glados.IntAnys(this).intInRange(0, 9)),
        glados.ListAnys(
          this,
        ).listWithLengthInRange(0, 5, glados.IntAnys(this).intInRange(0, 9)),
        glados.BoolAny(this).bool,
        glados.IntAnys(this).intInRange(0, 9),
        markerSpec,
        paginationTail,
        (
          List<int> initialBuckets,
          List<int> pageBuckets,
          bool hasTimestamp,
          int boundaryBucket,
          _GeneratedMarkerSpec marker,
          _GeneratedPaginationTail tail,
        ) => _GeneratedPaginationScenario(
          initialBuckets: initialBuckets,
          pageBuckets: pageBuckets,
          hasTimestamp: hasTimestamp,
          boundaryBucket: boundaryBucket,
          markerKind: marker.kind,
          markerSlot: marker.slot,
          hasPrevBatch: tail.hasPrevBatch,
          unlimitedPages: tail.unlimitedPages,
          maxPages: tail.maxPages,
          throwAt: tail.throwAt,
          noProgressAt: tail.noProgressAt,
        ),
      );
}

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

    void stubLogging(MockLoggingService logging) => stubLoggingService(logging);

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

    test(
      'does not short-circuit on marker when untilTimestamp is set',
      () async {
        final timeline = MockTimeline();
        final room = MockRoom();
        final logging = MockLoggingService();

        // Events contain the marker but don't cross the timestamp boundary
        final events = [event('marker-id', 200), event('new', 300)];
        var current = events;
        final older = [event('old', 40)];
        var requested = 0;

        stubLogging(logging);
        when(() => room.prev_batch).thenReturn(null);
        when(() => timeline.room).thenReturn(room);
        when(() => timeline.events).thenAnswer((_) => current);
        when(() => timeline.canRequestHistory).thenAnswer((_) => requested < 1);
        when(
          () => timeline.requestHistory(
            historyCount: any(named: 'historyCount'),
          ),
        ).thenAnswer((_) async {
          current = [...current, ...older];
          requested++;
        });

        final result = await SdkPaginationCompat.backfillUntilContains(
          timeline: timeline,
          lastEventId: 'marker-id',
          pageSize: 200,
          maxPages: null,
          logging: logging,
          untilTimestamp: 50,
        );

        // Should have paged to reach the timestamp boundary, not stopped at
        // the marker
        expect(result, isTrue);
        expect(requested, 1);
      },
    );

    test(
      'returns true immediately when marker is found and no timestamp is set',
      () async {
        final timeline = MockTimeline();
        final room = MockRoom();
        final logging = MockLoggingService();

        final visibleEvents = [event('target-id', 200), event('other', 300)];

        stubLogging(logging);
        when(() => room.prev_batch).thenReturn(null);
        when(() => timeline.room).thenReturn(room);
        when(() => timeline.events).thenReturn(visibleEvents);

        final result = await SdkPaginationCompat.backfillUntilContains(
          timeline: timeline,
          lastEventId: 'target-id',
          pageSize: 200,
          maxPages: null,
          logging: logging,
        );

        expect(result, isTrue);
        verifyNever(
          () => timeline.requestHistory(
            historyCount: any(named: 'historyCount'),
          ),
        );
      },
    );

    test(
      'returns true via fallback when marker is found after paging '
      'without timestamp',
      () async {
        final timeline = MockTimeline();
        final room = MockRoom();
        final logging = MockLoggingService();

        final initial = <Event>[event('other', 200)];
        final withMarker = <Event>[
          event('other', 200),
          event('target-id', 100),
        ];
        var current = initial;
        var requested = 0;

        stubLogging(logging);
        when(() => room.prev_batch).thenReturn(null);
        when(() => timeline.room).thenReturn(room);
        when(() => timeline.events).thenAnswer((_) => current);
        when(
          () => timeline.canRequestHistory,
        ).thenAnswer((_) => requested < 1);
        when(
          () => timeline.requestHistory(
            historyCount: any(named: 'historyCount'),
          ),
        ).thenAnswer((_) async {
          current = withMarker;
          requested++;
        });

        final result = await SdkPaginationCompat.backfillUntilContains(
          timeline: timeline,
          lastEventId: 'target-id',
          pageSize: 200,
          maxPages: null,
          logging: logging,
        );

        // Marker found on second iteration but canRequestHistory is false,
        // so it falls through the loop and returns via markerReached fallback
        expect(result, isTrue);
        expect(requested, 1);
      },
    );

    test(
      'returns false via boundaryReached fallback when timestamp boundary '
      'is not reached and history is exhausted',
      () async {
        final timeline = MockTimeline();
        final room = MockRoom();
        final logging = MockLoggingService();

        // Events don't cross the timestamp boundary (all newer than 50)
        final visibleEvents = [event('e1', 200), event('e2', 300)];

        stubLogging(logging);
        when(() => room.prev_batch).thenReturn(null);
        when(() => timeline.room).thenReturn(room);
        when(() => timeline.events).thenReturn(visibleEvents);
        when(() => timeline.canRequestHistory).thenReturn(false);

        final result = await SdkPaginationCompat.backfillUntilContains(
          timeline: timeline,
          lastEventId: null,
          pageSize: 200,
          maxPages: null,
          logging: logging,
          untilTimestamp: 50,
        );

        // untilTimestamp is set, boundaryReached is false → returns false
        expect(result, isFalse);
      },
    );

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

    glados.Glados(
      glados.any.paginationScenario,
      glados.ExploreConfig(numRuns: 140),
    ).test(
      'generated page streams match marker and timestamp boundary model',
      (scenario) async {
        final timeline = MockTimeline();
        final room = MockRoom();
        final logging = MockLoggingService();
        final chunk = TimelineChunk(
          events: [
            for (final generated in scenario.initialEvents)
              event(generated.id, generated.timestampMs),
          ],
        );
        var current = [...chunk.events];
        var requested = 0;

        stubLogging(logging);
        when(
          () => room.prev_batch,
        ).thenReturn(scenario.hasPrevBatch ? 'generated-prev-batch' : null);
        when(() => timeline.room).thenReturn(room);
        when(() => timeline.chunk).thenReturn(chunk);
        when(() => timeline.events).thenAnswer((_) => current);
        when(
          () => timeline.canRequestHistory,
        ).thenAnswer((_) => requested < scenario.pageBuckets.length);
        when(() => timeline.isFragmentedTimeline = any()).thenReturn(true);
        when(() => timeline.allowNewEvent = any()).thenReturn(false);
        when(
          () => timeline.requestHistory(
            historyCount: any(named: 'historyCount'),
          ),
        ).thenAnswer((_) async {
          if (scenario.throwAt == requested) {
            throw StateError('generated requestHistory failure');
          }
          if (scenario.noProgressAt == requested) {
            requested++;
            return;
          }
          final generated = scenario.pageEvent(requested);
          current = [...current, event(generated.id, generated.timestampMs)];
          requested++;
        });

        final result = await SdkPaginationCompat.backfillUntilContains(
          timeline: timeline,
          lastEventId: scenario.lastEventId,
          pageSize: 200,
          maxPages: scenario.maxPagesArgument,
          logging: logging,
          untilTimestamp: scenario.untilTimestamp,
        );

        expect(result, scenario.expectedResult());
      },
    );
  });
}
