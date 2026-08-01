// ignore_for_file: unnecessary_lambdas
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/sync/matrix/pipeline/catch_up_strategy.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';

class _GeneratedHistoryBootstrapScenario {
  const _GeneratedHistoryBootstrapScenario({
    required this.historyPages,
    required this.boundaryContinuationCap,
    required this.acceptedPositive,
  });

  final int historyPages;
  final int boundaryContinuationCap;
  final bool acceptedPositive;

  int get expectedHistoryCalls =>
      acceptedPositive ? 0 : _min(historyPages, boundaryContinuationCap);

  int get expectedPages => expectedHistoryCalls + 1;

  BootstrapStopReason get expectedStopReason {
    if (acceptedPositive) return BootstrapStopReason.boundaryReached;
    return boundaryContinuationCap <= historyPages
        ? BootstrapStopReason.boundaryReached
        : BootstrapStopReason.serverExhausted;
  }

  @override
  String toString() {
    return '_GeneratedHistoryBootstrapScenario('
        'historyPages: $historyPages, '
        'boundaryContinuationCap: $boundaryContinuationCap, '
        'acceptedPositive: $acceptedPositive'
        ')';
  }
}

/// Models the forward walk's budget as *round trips*, which is what the
/// implementation counts.
///
/// The walk starts at one round trip (the anchor `/context` fetch) and spends
/// one more per `requestFuture`. Iteration k therefore begins with
/// `roundTrips == k`, and the budget check that precedes emitting page k trips
/// as soon as `k >= cap`. Because this generator's server hands back exactly
/// one event per request, that is also the worst case the old page-based cap
/// got wrong: a page cap of C stopped after C pages *whatever* they contained,
/// so a walk trailing a live burst spent its whole budget on C events.
class _GeneratedForwardBootstrapScenario {
  const _GeneratedForwardBootstrapScenario({
    required this.futurePages,
    required this.forwardRoundTripCap,
  });

  final int futurePages;
  final int forwardRoundTripCap;

  /// The walk runs out of future pages after `futurePages + 1` emitted pages,
  /// so a cap above that is never reached.
  bool get capTrips => forwardRoundTripCap <= futurePages + 1;

  int get expectedFutureCalls =>
      capTrips ? forwardRoundTripCap - 1 : futurePages;

  int get expectedPages => capTrips ? forwardRoundTripCap - 1 : futurePages + 1;

  BootstrapStopReason get expectedStopReason => capTrips
      ? BootstrapStopReason.boundaryReached
      : BootstrapStopReason.serverExhausted;

  @override
  String toString() {
    return '_GeneratedForwardBootstrapScenario('
        'futurePages: $futurePages, '
        'forwardRoundTripCap: $forwardRoundTripCap'
        ')';
  }
}

extension _AnyCatchUpStrategyScenario on glados.Any {
  glados.Generator<_GeneratedHistoryBootstrapScenario>
  get historyBootstrapScenario => glados.CombinableAny(this).combine3(
    glados.IntAnys(this).intInRange(0, 5),
    glados.IntAnys(this).intInRange(0, 5),
    glados.BoolAny(this).bool,
    (
      int historyPages,
      int boundaryContinuationCap,
      bool acceptedPositive,
    ) => _GeneratedHistoryBootstrapScenario(
      historyPages: historyPages,
      boundaryContinuationCap: boundaryContinuationCap,
      acceptedPositive: acceptedPositive,
    ),
  );

  glados.Generator<_GeneratedForwardBootstrapScenario>
  get forwardBootstrapScenario => glados.CombinableAny(this).combine2(
    glados.IntAnys(this).intInRange(0, 5),
    glados.IntAnys(this).intInRange(1, 6),
    (int futurePages, int forwardRoundTripCap) =>
        _GeneratedForwardBootstrapScenario(
          futurePages: futurePages,
          forwardRoundTripCap: forwardRoundTripCap,
        ),
  );
}

int _min(int a, int b) => a < b ? a : b;

Event _generatedEvent(String id, int timestampMs) {
  final event = MockEvent();
  when(() => event.eventId).thenReturn(id);
  when(
    () => event.originServerTs,
  ).thenReturn(DateTime.fromMillisecondsSinceEpoch(timestampMs));
  return event;
}

void main() {
  setUpAll(() {
    registerFallbackValue(MockTimeline());
  });

  group('collectHistoryForBootstrap', () {
    Event buildEvent(String id, int tsMs) {
      final e = MockEvent();
      when(() => e.eventId).thenReturn(id);
      when(
        () => e.originServerTs,
      ).thenReturn(DateTime.fromMillisecondsSinceEpoch(tsMs));
      return e;
    }

    glados.Glados(
      glados.any.historyBootstrapScenario,
      glados.ExploreConfig(numRuns: 80),
    ).test(
      'generated backward bootstrap honors boundary continuation cap',
      (scenario) async {
        final room = MockRoom();
        final log = MockDomainLogger();
        final timeline = MockTimeline();
        final events = <Event>[_generatedEvent('history-0', 900)];
        var historyCalls = 0;

        when(
          () => room.getTimeline(limit: any(named: 'limit')),
        ).thenAnswer((_) async => timeline);
        when(() => timeline.events).thenAnswer((_) => events);
        when(
          () => timeline.canRequestHistory,
        ).thenAnswer((_) => historyCalls < scenario.historyPages);
        when(
          () => timeline.requestHistory(
            historyCount: any(named: 'historyCount'),
          ),
        ).thenAnswer((_) async {
          historyCalls++;
          events.insert(
            0,
            _generatedEvent('history-$historyCalls', 900 - historyCalls),
          );
        });
        when(timeline.cancelSubscriptions).thenReturn(null);

        final result = await CatchUpStrategy.collectHistoryForBootstrap(
          room: room,
          sink: _CollectingBootstrapSink(
            (_) {},
            acceptedPerPage: scenario.acceptedPositive ? 1 : 0,
          ),
          logging: log,
          pageSize: 1,
          untilTimestamp: 1000,
          boundaryContinuationCap: scenario.boundaryContinuationCap,
        );

        expect(result.stopReason, scenario.expectedStopReason);
        expect(result.totalPages, scenario.expectedPages);
        expect(result.totalEvents, scenario.expectedPages);
        expect(historyCalls, scenario.expectedHistoryCalls);
        verify(timeline.cancelSubscriptions).called(1);
      },
      tags: 'glados',
    );

    test(
      'emits each event exactly once without an ever-growing seen-set '
      '(memory bounded by page size, not total history depth)',
      () async {
        final room = MockRoom();
        final log = MockDomainLogger();
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
      'timestamp ties between pages emit newly loaded events once regardless '
      'of lexical event-id order',
      () async {
        final room = MockRoom();
        final log = MockDomainLogger();
        final tl = MockTimeline();

        // The SDK preserves timeline order for tied timestamps. Event IDs are
        // not pagination anchors, so the later-loaded lexical-greater `c`
        // must still be emitted.
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
        expect(collected, ['a', 'b', 'c']);
        expect(collected.toSet(), hasLength(collected.length));
      },
    );

    test(
      'boundary completion exhausts the entire equal-timestamp bucket',
      () async {
        final room = MockRoom();
        final log = MockDomainLogger();
        final timeline = MockTimeline();
        final events = <Event>[buildEvent(r'$boundary-a', 100)];
        var historyCalls = 0;

        when(
          () => room.getTimeline(limit: any(named: 'limit')),
        ).thenAnswer((_) async => timeline);
        when(() => timeline.events).thenAnswer((_) => events);
        when(
          () => timeline.canRequestHistory,
        ).thenAnswer((_) => historyCalls == 0);
        when(
          () => timeline.requestHistory(
            historyCount: any(named: 'historyCount'),
          ),
        ).thenAnswer((_) async {
          historyCalls++;
          events
            ..insert(0, buildEvent(r'$older', 99))
            ..add(buildEvent(r'$boundary-z', 100));
        });
        when(timeline.cancelSubscriptions).thenReturn(null);

        final collected = <String>[];
        final result = await CatchUpStrategy.collectHistoryForBootstrap(
          room: room,
          logging: log,
          sink: _CollectingBootstrapSink((page) {
            collected.addAll(page.map((event) => event.eventId));
          }),
          pageSize: 1,
          untilTimestamp: 100,
        );

        expect(result.stopReason, BootstrapStopReason.boundaryReached);
        expect(historyCalls, 1);
        expect(
          collected,
          [r'$boundary-a', r'$older', r'$boundary-z'],
          reason:
              'reaching ts=100 must not stop before a later page reveals '
              'another event in the same timestamp bucket',
        );
      },
    );

    test(
      'equal-timestamp boundary continuation stops incomplete at its '
      'request cap',
      () async {
        final room = MockRoom();
        final log = MockDomainLogger();
        final timeline = MockTimeline();
        final events = <Event>[buildEvent(r'$boundary-0', 100)];
        var historyCalls = 0;

        when(
          () => room.getTimeline(limit: any(named: 'limit')),
        ).thenAnswer((_) async => timeline);
        when(() => timeline.events).thenAnswer((_) => events);
        // Keep advertising enough same-timestamp history to exceed the
        // configured cap. The extra terminal call makes the regression
        // deterministic when the cap check is removed: that version reaches
        // serverExhausted after three requests instead of hanging.
        when(
          () => timeline.canRequestHistory,
        ).thenAnswer((_) => historyCalls < 3);
        when(
          () => timeline.requestHistory(
            historyCount: any(named: 'historyCount'),
          ),
        ).thenAnswer((_) async {
          historyCalls++;
          events.add(buildEvent('\$boundary-$historyCalls', 100));
        });
        when(timeline.cancelSubscriptions).thenReturn(null);

        final collected = <String>[];
        final result = await CatchUpStrategy.collectHistoryForBootstrap(
          room: room,
          logging: log,
          sink: _CollectingBootstrapSink((page) {
            collected.addAll(page.map((event) => event.eventId));
          }),
          pageSize: 1,
          untilTimestamp: 100,
          boundaryContinuationCap: 2,
        );

        expect(
          result.stopReason,
          BootstrapStopReason.error,
          reason:
              'a capped collision bucket is incomplete and must retain the '
              'resume floor for a later retry',
        );
        expect(historyCalls, 2);
        expect(collected, [
          r'$boundary-0',
          r'$boundary-1',
          r'$boundary-2',
        ]);
      },
    );

    test(
      'overallTimeout ends paging with stopReason=error before the next '
      'requestHistory fires',
      () async {
        final room = MockRoom();
        final log = MockDomainLogger();
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
      'overallTimeout firing after a successful first page keeps the page '
      'and stops with stopReason=error before the second requestHistory',
      () async {
        final room = MockRoom();
        final log = MockDomainLogger();
        final tl = MockTimeline();
        final events = <Event>[_generatedEvent('first-page', 100)];
        var historyRequests = 0;
        when(
          () => room.getTimeline(limit: any(named: 'limit')),
        ).thenAnswer((_) async => tl);
        when(() => tl.events).thenAnswer((_) => events);
        when(() => tl.canRequestHistory).thenReturn(true);
        when(
          () => tl.requestHistory(historyCount: any(named: 'historyCount')),
        ).thenAnswer((_) async {
          historyRequests++;
          events.add(_generatedEvent('second-page', 50));
        });
        when(() => tl.cancelSubscriptions()).thenReturn(null);

        // Injected step clock: the first deadline check sees zero elapsed
        // (page 1 processes + requestHistory fires), every later read is
        // past the timeout, so the SECOND loop-top check trips before the
        // second page is emitted to the sink.
        final base = DateTime(2026, 4, 23, 10);
        var clockReads = 0;
        DateTime fakeNow() =>
            clockReads++ < 2 ? base : base.add(const Duration(seconds: 10));

        final pages = <List<Event>>[];
        final result = await CatchUpStrategy.collectHistoryForBootstrap(
          room: room,
          logging: log,
          sink: _CollectingBootstrapSink(pages.add),
          pageSize: 1,
          overallTimeout: const Duration(seconds: 1),
          now: fakeNow,
        );

        // First page made it through; the walk stopped on the deadline
        // between requestHistory and the second sink call.
        expect(result.stopReason, BootstrapStopReason.error);
        expect(historyRequests, 1);
        expect(pages, hasLength(1));
        expect(pages.single.single.eventId, 'first-page');
      },
    );

    test(
      'requestHistory throwing is captured on logging and stops paging '
      'with stopReason=error (no unhandled future)',
      () async {
        final room = MockRoom();
        final log = MockDomainLogger();
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
          () => log.error(
            any<LogDomain>(),
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: any(
              named: 'subDomain',
              that: contains('bootstrap.requestHistory'),
            ),
          ),
        ).called(1);
      },
    );

    test(
      'timestamp-bucket dedupe emits a newly loaded lex-smaller collision',
      () async {
        final room = MockRoom();
        final log = MockDomainLogger();
        final tl = MockTimeline();
        // Page 0 emits two events at ts=100.
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
          // Event-id lexical order is irrelevant. The unseen collision must
          // be emitted once because it was not in the timestamp bucket's
          // bounded seen set.
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
        final log = MockDomainLogger();
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
        final log = MockDomainLogger();
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
        final log = MockDomainLogger();
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
        final log = MockDomainLogger();
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
        final log = MockDomainLogger();
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

  group('collectForwardForBootstrap — reconnect forward-walk', () {
    Event buildEvent(String id, int ts) {
      final e = MockEvent();
      when(() => e.eventId).thenReturn(id);
      when(
        () => e.originServerTs,
      ).thenReturn(DateTime.fromMillisecondsSinceEpoch(ts));
      return e;
    }

    glados.Glados(
      glados.any.forwardBootstrapScenario,
      glados.ExploreConfig(numRuns: 80),
    ).test(
      'generated forward bootstrap honors future paging and cap semantics',
      (scenario) async {
        final room = MockRoom();
        final log = MockDomainLogger();
        final timeline = MockTimeline();
        final events = <Event>[
          _generatedEvent(r'$anchor', 1000),
          _generatedEvent(r'$future-0', 1001),
        ];
        var futureCalls = 0;

        when(
          () => room.getTimeline(
            eventContextId: any(named: 'eventContextId'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => timeline);
        when(() => timeline.events).thenAnswer((_) => events);
        when(
          () => timeline.canRequestFuture,
        ).thenAnswer((_) => futureCalls < scenario.futurePages);
        when(
          () => timeline.requestFuture(
            historyCount: any(named: 'historyCount'),
          ),
        ).thenAnswer((_) async {
          futureCalls++;
          events.add(
            _generatedEvent(
              '\$future-$futureCalls',
              1001 + futureCalls,
            ),
          );
        });
        when(timeline.cancelSubscriptions).thenReturn(null);

        final pages = <List<Event>>[];
        final result = await CatchUpStrategy.collectForwardForBootstrap(
          room: room,
          sink: _CollectingBootstrapSink(pages.add, acceptedPerPage: 1),
          logging: log,
          anchorEventId: r'$anchor',
          forwardRoundTripCap: scenario.forwardRoundTripCap,
        );

        expect(result.stopReason, scenario.expectedStopReason);
        expect(result.totalPages, scenario.expectedPages);
        expect(result.totalEvents, scenario.expectedPages);
        expect(futureCalls, scenario.expectedFutureCalls);
        expect(pages, hasLength(scenario.expectedPages));
        for (var index = 0; index < pages.length; index++) {
          expect(pages[index].map((event) => event.eventId).toList(), [
            '\$future-$index',
          ]);
        }
        final expectedCancellations =
            scenario.expectedStopReason == BootstrapStopReason.serverExhausted
            ? 2
            : 1;
        verify(timeline.cancelSubscriptions).called(expectedCancellations);
      },
      tags: 'glados',
    );

    test(
      'forces a server context lookup even when the anchor is already in the '
      'SDK cache',
      () async {
        final room = MockRoom();
        final log = MockDomainLogger();
        final timeline = MockTimeline();
        final anchor = buildEvent(r'$anchor', 100);
        when(
          () => room.getTimeline(
            eventContextId: r'$anchor',
            limit: 0,
          ),
        ).thenAnswer((_) async => timeline);
        when(() => timeline.events).thenReturn([anchor]);
        when(() => timeline.canRequestFuture).thenReturn(false);
        when(timeline.cancelSubscriptions).thenAnswer((_) {});

        final result = await CatchUpStrategy.collectForwardForBootstrap(
          room: room,
          sink: _CollectingBootstrapSink((_) {}),
          logging: log,
          anchorEventId: r'$anchor',
        );

        expect(result.stopReason, BootstrapStopReason.serverExhausted);
        verify(
          () => room.getTimeline(
            eventContextId: r'$anchor',
            limit: 0,
          ),
        ).called(1);
      },
    );

    test(
      'emits events strictly newer than the anchor and stops when the '
      'server runs out of future — this is the load-bearing reconnect '
      'path that backward-walk cannot cover once the cache predates '
      'the gap window',
      () async {
        final room = MockRoom();
        final log = MockDomainLogger();
        final tl = MockTimeline();
        final events = <Event>[
          buildEvent(r'$anchor', 100),
          buildEvent(r'$e1', 110),
          buildEvent(r'$e2', 120),
        ];
        when(
          () => room.getTimeline(
            eventContextId: any(named: 'eventContextId'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => tl);
        when(() => tl.events).thenAnswer((_) => events);
        when(() => tl.canRequestFuture).thenReturn(false);
        when(tl.cancelSubscriptions).thenAnswer((_) {});

        final pages = <List<Event>>[];
        final result = await CatchUpStrategy.collectForwardForBootstrap(
          room: room,
          sink: _CollectingBootstrapSink(pages.add, acceptedPerPage: 2),
          logging: log,
          anchorEventId: r'$anchor',
        );

        expect(result.stopReason, BootstrapStopReason.serverExhausted);
        expect(pages, hasLength(1));
        // Anchor itself is filtered out; only e1/e2 reach the sink.
        expect(pages.single.map((e) => e.eventId).toList(), [r'$e1', r'$e2']);
        // A terminal context probe confirms that the non-empty window was
        // really the server tip, rather than a homeserver-capped response
        // without a forward token.
        verify(tl.cancelSubscriptions).called(2);
      },
    );

    test(
      'anchor missing from the context chunk returns errorNoProgress '
      'so the coordinator can fall back — simulates a server that '
      'compacted the anchor event out of its timeline',
      () async {
        final room = MockRoom();
        final log = MockDomainLogger();
        final tl = MockTimeline();
        when(
          () => room.getTimeline(
            eventContextId: any(named: 'eventContextId'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => tl);
        when(() => tl.events).thenReturn(<Event>[]);
        when(() => tl.canRequestFuture).thenReturn(true);
        when(tl.cancelSubscriptions).thenAnswer((_) {});

        final result = await CatchUpStrategy.collectForwardForBootstrap(
          room: room,
          sink: _CollectingBootstrapSink((_) {}),
          logging: log,
          anchorEventId: r'$missing-anchor',
        );

        expect(result.stopReason, BootstrapStopReason.error);
        expect(result.totalPages, 0);
        expect(result.totalEvents, 0);
      },
    );

    test(
      'walks forward across multiple requestFuture rounds until '
      'canRequestFuture=false — not artificially capped on the first '
      'page',
      () async {
        final room = MockRoom();
        final log = MockDomainLogger();
        final tl = MockTimeline();
        var futureCalls = 0;
        final events = <Event>[
          buildEvent(r'$anchor', 100),
          buildEvent(r'$e1', 110),
        ];
        when(
          () => room.getTimeline(
            eventContextId: any(named: 'eventContextId'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => tl);
        when(() => tl.events).thenAnswer((_) => events);
        when(() => tl.canRequestFuture).thenAnswer((_) => futureCalls < 2);
        when(
          () => tl.requestFuture(historyCount: any(named: 'historyCount')),
        ).thenAnswer((_) async {
          futureCalls++;
          events.add(
            buildEvent(
              r'$e'
              '${futureCalls + 1}',
              110 + futureCalls,
            ),
          );
        });
        when(tl.cancelSubscriptions).thenAnswer((_) {});

        final pages = <List<Event>>[];
        final result = await CatchUpStrategy.collectForwardForBootstrap(
          room: room,
          sink: _CollectingBootstrapSink(pages.add, acceptedPerPage: 1),
          logging: log,
          anchorEventId: r'$anchor',
        );

        expect(result.stopReason, BootstrapStopReason.serverExhausted);
        expect(futureCalls, 2);
        // First page: e1. Second page: e2 (new). Third page: e3 (new).
        expect(
          pages.map((p) => p.map((e) => e.eventId).toList()).toList(),
          [
            [r'$e1'],
            [r'$e2'],
            [r'$e3'],
          ],
        );
      },
    );

    test(
      're-anchors context windows that omit a forward token so a capped '
      'response cannot strand the reconnect tail',
      () async {
        final room = MockRoom();
        final log = MockDomainLogger();
        final firstWindow = MockTimeline();
        final secondWindow = MockTimeline();
        final terminalWindow = MockTimeline();
        final anchor = buildEvent(r'$anchor', 100);
        final first = buildEvent(r'$first', 110);
        final second = buildEvent(r'$second', 120);
        final timelines = <Timeline>[
          firstWindow,
          secondWindow,
          terminalWindow,
        ];
        var contextRequests = 0;

        when(
          () => room.getTimeline(
            eventContextId: any(named: 'eventContextId'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => timelines[contextRequests++]);
        when(() => firstWindow.events).thenReturn([anchor, first]);
        when(() => secondWindow.events).thenReturn([first, second]);
        when(() => terminalWindow.events).thenReturn([second]);
        when(() => firstWindow.canRequestFuture).thenReturn(false);
        when(() => secondWindow.canRequestFuture).thenReturn(false);
        when(() => terminalWindow.canRequestFuture).thenReturn(false);
        when(firstWindow.cancelSubscriptions).thenAnswer((_) {});
        when(secondWindow.cancelSubscriptions).thenAnswer((_) {});
        when(terminalWindow.cancelSubscriptions).thenAnswer((_) {});

        final pages = <List<Event>>[];
        final result = await CatchUpStrategy.collectForwardForBootstrap(
          room: room,
          sink: _CollectingBootstrapSink(pages.add, acceptedPerPage: 1),
          logging: log,
          anchorEventId: r'$anchor',
        );

        expect(result.stopReason, BootstrapStopReason.serverExhausted);
        expect(result.totalEvents, 2);
        expect(
          pages.map((page) => page.single.eventId).toList(),
          [r'$first', r'$second'],
        );
        verify(
          () => room.getTimeline(eventContextId: r'$anchor', limit: 0),
        ).called(1);
        verify(
          () => room.getTimeline(eventContextId: r'$first', limit: 0),
        ).called(1);
        verify(
          () => room.getTimeline(eventContextId: r'$second', limit: 0),
        ).called(1);
        verify(firstWindow.cancelSubscriptions).called(1);
        verify(secondWindow.cancelSubscriptions).called(1);
        verify(terminalWindow.cancelSubscriptions).called(1);
      },
    );

    test(
      're-anchors after a forward token yields no new events so a stale '
      'pagination response cannot strand the reconnect tail',
      () async {
        final room = MockRoom();
        final log = MockDomainLogger();
        final initialWindow = MockTimeline();
        final secondWindow = MockTimeline();
        final terminalWindow = MockTimeline();
        final anchor = buildEvent(r'$anchor', 100);
        final first = buildEvent(r'$first', 110);
        final second = buildEvent(r'$second', 120);
        final timelines = <Timeline>[
          initialWindow,
          secondWindow,
          terminalWindow,
        ];
        var contextRequests = 0;
        var futureRequests = 0;

        when(
          () => room.getTimeline(
            eventContextId: any(named: 'eventContextId'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => timelines[contextRequests++]);
        when(() => initialWindow.events).thenReturn([anchor, first]);
        when(() => secondWindow.events).thenReturn([first, second]);
        when(() => terminalWindow.events).thenReturn([second]);
        when(
          () => initialWindow.canRequestFuture,
        ).thenAnswer((_) => futureRequests == 0);
        when(
          () => initialWindow.requestFuture(
            historyCount: any(named: 'historyCount'),
          ),
        ).thenAnswer((_) async => futureRequests++);
        when(() => secondWindow.canRequestFuture).thenReturn(false);
        when(() => terminalWindow.canRequestFuture).thenReturn(false);
        when(initialWindow.cancelSubscriptions).thenAnswer((_) {});
        when(secondWindow.cancelSubscriptions).thenAnswer((_) {});
        when(terminalWindow.cancelSubscriptions).thenAnswer((_) {});

        final pages = <List<Event>>[];
        final result = await CatchUpStrategy.collectForwardForBootstrap(
          room: room,
          sink: _CollectingBootstrapSink(pages.add, acceptedPerPage: 1),
          logging: log,
          anchorEventId: r'$anchor',
        );

        expect(result.stopReason, BootstrapStopReason.serverExhausted);
        expect(result.totalEvents, 2);
        expect(futureRequests, 1);
        expect(
          pages.map((page) => page.single.eventId).toList(),
          [r'$first', r'$second'],
        );
        verify(
          () => room.getTimeline(eventContextId: r'$anchor', limit: 0),
        ).called(1);
        verify(
          () => room.getTimeline(eventContextId: r'$first', limit: 0),
        ).called(1);
        verify(
          () => room.getTimeline(eventContextId: r'$second', limit: 0),
        ).called(1);
        verify(initialWindow.cancelSubscriptions).called(1);
        verify(secondWindow.cancelSubscriptions).called(1);
        verify(terminalWindow.cancelSubscriptions).called(1);
      },
    );

    test(
      'the round-trip budget counts requests, not emitted pages, so a walk '
      'trailing a live burst one event at a time still gets its full budget '
      '— and reports boundaryReached, which the caller must read as '
      'incomplete because the server still has more',
      () async {
        final room = MockRoom();
        final log = MockDomainLogger();
        final tl = MockTimeline();
        final events = <Event>[
          buildEvent(r'$anchor', 100),
          buildEvent(r'$e1', 110),
        ];
        when(
          () => room.getTimeline(
            eventContextId: any(named: 'eventContextId'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => tl);
        when(() => tl.events).thenAnswer((_) => events);
        when(() => tl.canRequestFuture).thenReturn(true);
        var n = 0;
        when(
          () => tl.requestFuture(historyCount: any(named: 'historyCount')),
        ).thenAnswer((_) async {
          n++;
          events.add(
            buildEvent(
              r'$e'
              '${n + 1}',
              110 + n,
            ),
          );
        });
        when(tl.cancelSubscriptions).thenAnswer((_) {});

        final result = await CatchUpStrategy.collectForwardForBootstrap(
          room: room,
          sink: _CollectingBootstrapSink((_) {}, acceptedPerPage: 1),
          logging: log,
          anchorEventId: r'$anchor',
          forwardRoundTripCap: 3,
        );

        expect(result.stopReason, BootstrapStopReason.boundaryReached);
        // Three round trips: the anchor context fetch plus two
        // `requestFuture` calls, each yielding a single event. The old
        // page-based cap of 3 would have allowed three *pages* here — and,
        // more importantly, a cap of 50 allowed only 50 events instead of the
        // 50 pages x 200 it was sized for.
        expect(result.totalPages, 2);
        expect(result.totalEvents, 2);
        expect(n, 2);
      },
    );

    test(
      'a request whose events all filter out still spends budget — the old '
      'page counter never incremented on an empty page, so a server '
      'returning nothing but already-emitted overlap could spin forever',
      () async {
        final room = MockRoom();
        final log = MockDomainLogger();
        final tl = MockTimeline();
        // The anchor plus one genuinely new event. Every subsequent
        // `requestFuture` "succeeds" but adds nothing, so the strictly-after
        // filter yields an empty page every time while the server keeps
        // advertising a forward token.
        final events = <Event>[
          buildEvent(r'$anchor', 100),
          buildEvent(r'$e1', 110),
        ];
        when(
          () => room.getTimeline(
            eventContextId: any(named: 'eventContextId'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => tl);
        when(() => tl.events).thenAnswer((_) => events);
        when(() => tl.canRequestFuture).thenReturn(true);
        var requests = 0;
        when(
          () => tl.requestFuture(historyCount: any(named: 'historyCount')),
        ).thenAnswer((_) async => requests++);
        when(tl.cancelSubscriptions).thenAnswer((_) {});

        final result = await CatchUpStrategy.collectForwardForBootstrap(
          room: room,
          sink: _CollectingBootstrapSink((_) {}, acceptedPerPage: 1),
          logging: log,
          anchorEventId: r'$anchor',
          forwardRoundTripCap: 4,
        );

        // Terminates on the budget rather than looping. Only the first page
        // carried an event, so the walk stops with an empty page in hand and
        // reports the honest "nothing more to emit" reason.
        expect(requests, 3);
        expect(result.totalPages, 1);
        expect(result.stopReason, BootstrapStopReason.serverExhausted);
      },
    );

    test(
      'getTimeline throwing yields stopReason=error with zero progress '
      '— the coordinator keys on (error, pages=0) to fall back to the '
      'backward walk, so the shape has to match exactly',
      () async {
        final room = MockRoom();
        final log = MockDomainLogger();
        when(
          () => room.getTimeline(
            eventContextId: any(named: 'eventContextId'),
            limit: any(named: 'limit'),
          ),
        ).thenThrow(StateError('context fetch failed'));

        final result = await CatchUpStrategy.collectForwardForBootstrap(
          room: room,
          sink: _CollectingBootstrapSink((_) {}),
          logging: log,
          anchorEventId: r'$anchor',
        );

        expect(result.stopReason, BootstrapStopReason.error);
        expect(result.totalPages, 0);
        expect(result.totalEvents, 0);
      },
    );

    test(
      'sink returning false halts pagination with sinkCancelled before '
      'requestFuture fires — user-cancel / back-pressure paths must '
      'stop promptly, not drain the whole server first',
      () async {
        final room = MockRoom();
        final log = MockDomainLogger();
        final tl = MockTimeline();
        final events = <Event>[
          buildEvent(r'$anchor', 100),
          buildEvent(r'$e1', 110),
        ];
        when(
          () => room.getTimeline(
            eventContextId: any(named: 'eventContextId'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => tl);
        when(() => tl.events).thenAnswer((_) => events);
        when(() => tl.canRequestFuture).thenReturn(true);
        when(tl.cancelSubscriptions).thenAnswer((_) {});

        final result = await CatchUpStrategy.collectForwardForBootstrap(
          room: room,
          sink: _CollectingBootstrapSink(
            (_) {},
            continueAfterPage: false,
            acceptedPerPage: 1,
          ),
          logging: log,
          anchorEventId: r'$anchor',
        );

        expect(result.stopReason, BootstrapStopReason.sinkCancelled);
        expect(result.totalPages, 1);
        // requestFuture must not have been called — sink bailed first.
        verifyNever(
          () => tl.requestFuture(historyCount: any(named: 'historyCount')),
        );
      },
    );

    test(
      'requestFuture throwing is captured on logging and stops paging '
      'with stopReason=error (not serverExhausted) — the bridge uses '
      'this to distinguish "server gave us everything" from "we lost '
      'connectivity mid-walk" and schedule a retry accordingly',
      () async {
        final room = MockRoom();
        final log = MockDomainLogger();
        final tl = MockTimeline();
        final events = <Event>[
          buildEvent(r'$anchor', 100),
          buildEvent(r'$e1', 110),
        ];
        when(
          () => room.getTimeline(
            eventContextId: any(named: 'eventContextId'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => tl);
        when(() => tl.events).thenAnswer((_) => events);
        when(() => tl.canRequestFuture).thenReturn(true);
        when(
          () => tl.requestFuture(historyCount: any(named: 'historyCount')),
        ).thenThrow(StateError('network lost'));
        when(tl.cancelSubscriptions).thenAnswer((_) {});

        final result = await CatchUpStrategy.collectForwardForBootstrap(
          room: room,
          sink: _CollectingBootstrapSink((_) {}, acceptedPerPage: 1),
          logging: log,
          anchorEventId: r'$anchor',
        );

        expect(result.stopReason, BootstrapStopReason.error);
        expect(result.totalPages, 1);
        verify(
          () => log.error(
            any<LogDomain>(),
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: any<String>(
              named: 'subDomain',
              that: contains('requestFuture'),
            ),
          ),
        ).called(1);
      },
    );

    test(
      'same-timestamp ties between pages advance the newestEventId '
      'anchor when the later event id is lex-greater — pins the '
      'anchor semantics that guarantee we never re-emit an event '
      'already sent to the sink',
      () async {
        final room = MockRoom();
        final log = MockDomainLogger();
        final tl = MockTimeline();
        // Two events share ts=110, and the lex-greater one arrives on
        // a later page. The first page sends `$aaaa`, the second
        // page sends `$bbbb` with the same ts; the anchor must
        // advance so a third page never re-sees `$aaaa`.
        final events = <Event>[
          buildEvent(r'$anchor', 100),
          buildEvent(r'$aaaa', 110),
        ];
        var futureCalls = 0;
        when(
          () => room.getTimeline(
            eventContextId: any(named: 'eventContextId'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => tl);
        when(() => tl.events).thenAnswer((_) => events);
        when(() => tl.canRequestFuture).thenAnswer((_) => futureCalls < 1);
        when(
          () => tl.requestFuture(historyCount: any(named: 'historyCount')),
        ).thenAnswer((_) async {
          futureCalls++;
          events.add(buildEvent(r'$bbbb', 110));
        });
        when(tl.cancelSubscriptions).thenAnswer((_) {});

        final pages = <List<Event>>[];
        final result = await CatchUpStrategy.collectForwardForBootstrap(
          room: room,
          sink: _CollectingBootstrapSink(pages.add, acceptedPerPage: 1),
          logging: log,
          anchorEventId: r'$anchor',
        );

        expect(result.stopReason, BootstrapStopReason.serverExhausted);
        expect(
          pages.map((p) => p.map((e) => e.eventId).toList()).toList(),
          [
            [r'$aaaa'],
            [r'$bbbb'],
          ],
          reason:
              r'page 1 must carry only $bbbb — the anchor-advance on '
              r'same-ts ties prevents $aaaa from being re-emitted',
        );
      },
    );

    test(
      'default lastAcceptedCount on BootstrapSink abstract class returns '
      'null — the strategy treats null as "sink does not track" and '
      'falls back to continuing pagination rather than crashing',
      () async {
        final room = MockRoom();
        final log = MockDomainLogger();
        final tl = MockTimeline();
        final anchor = buildEvent(r'$anchor', 100);
        final e1 = buildEvent(r'$e1', 110);
        when(
          () => room.getTimeline(
            eventContextId: any(named: 'eventContextId'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => tl);
        when(() => tl.events).thenReturn([anchor, e1]);
        when(() => tl.canRequestFuture).thenReturn(false);
        when(tl.cancelSubscriptions).thenAnswer((_) {});

        final sink = _BareSink();
        final result = await CatchUpStrategy.collectForwardForBootstrap(
          room: room,
          sink: sink,
          logging: log,
          anchorEventId: r'$anchor',
        );
        expect(result.stopReason, BootstrapStopReason.serverExhausted);
        expect(sink.lastAcceptedCount, isNull);
      },
    );

    test(
      'overallTimeout cuts the walk short with stopReason=error — the '
      'long-poll path through `/messages` can hang under a flaky '
      'network, and a bounded timeout keeps the bridge responsive',
      () async {
        final room = MockRoom();
        final log = MockDomainLogger();
        final tl = MockTimeline();
        final anchorEv = buildEvent(r'$anchor', 100);
        final e1 = buildEvent(r'$e1', 110);
        final events = <Event>[anchorEv];
        when(
          () => room.getTimeline(
            eventContextId: any(named: 'eventContextId'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => tl);
        when(() => tl.events).thenAnswer((_) => events);
        when(() => tl.canRequestFuture).thenReturn(true);
        when(
          () => tl.requestFuture(historyCount: any(named: 'historyCount')),
        ).thenAnswer((_) async => events.add(e1));
        when(tl.cancelSubscriptions).thenAnswer((_) {});

        // Injected step clock: the first loop-top deadline check sees no
        // elapsed time; every later read is past the timeout — no real
        // sleeping needed to trip the deadline on the second iteration.
        final base = DateTime(2026, 4, 23, 10);
        var clockReads = 0;
        DateTime fakeNow() => clockReads++ < 2
            ? base
            : base.add(const Duration(milliseconds: 50));

        final result = await CatchUpStrategy.collectForwardForBootstrap(
          room: room,
          sink: _CollectingBootstrapSink((_) {}, acceptedPerPage: 0),
          logging: log,
          anchorEventId: r'$anchor',
          overallTimeout: const Duration(milliseconds: 10),
          now: fakeNow,
        );

        expect(result.stopReason, BootstrapStopReason.error);
      },
    );
  });
}

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

/// Sink that relies on the [BootstrapSink] default `lastAcceptedCount`
/// getter (returns null). Proves the strategy tolerates sinks that
/// don't expose the accepted-count signal — e.g. diagnostics-only
/// wrappers the bridge might plug in for observability.
class _BareSink extends BootstrapSink {
  @override
  Future<bool> onPage(List<Event> events, BootstrapPageInfo info) async => true;
}
