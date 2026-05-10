import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/sync/matrix/pipeline/catch_up_strategy.dart';
import 'package:lotti/features/sync/queue/attachment_aware_bootstrap_sink.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

BootstrapPageInfo _pageInfo({int pageIndex = 0, int totalEventsSoFar = 0}) {
  return BootstrapPageInfo(
    pageIndex: pageIndex,
    totalEventsSoFar: totalEventsSoFar,
    oldestTimestampSoFar: null,
    serverHasMore: true,
    elapsed: Duration.zero,
  );
}

class _MockEvent extends Mock implements Event {}

class _RecordingInnerSink implements BootstrapSink {
  final List<List<Event>> pages = <List<Event>>[];
  final List<bool> results = <bool>[];
  final List<int> acceptedCounts = <int>[];
  int acceptedPerPage = 0;
  int? _lastAccepted;

  @override
  int? get lastAcceptedCount => _lastAccepted;

  @override
  Future<bool> onPage(List<Event> events, BootstrapPageInfo info) async {
    final pageIndex = pages.length;
    pages.add(List<Event>.from(events));
    _lastAccepted = pageIndex < acceptedCounts.length
        ? acceptedCounts[pageIndex]
        : acceptedPerPage;
    if (pageIndex < results.length) {
      return results[pageIndex];
    }
    return true;
  }
}

Event _buildEvent(String id) {
  final event = _MockEvent();
  when(() => event.eventId).thenReturn(id);
  return event;
}

enum _GeneratedAttachmentFailureKind { none, first, last, everySecond, all }

class _GeneratedAttachmentSinkPage {
  const _GeneratedAttachmentSinkPage({
    required this.size,
    required this.shouldContinue,
    required this.acceptedCount,
  });

  final int size;
  final bool shouldContinue;
  final int acceptedCount;

  @override
  String toString() {
    return '_GeneratedAttachmentSinkPage('
        'size: $size, '
        'shouldContinue: $shouldContinue, '
        'acceptedCount: $acceptedCount'
        ')';
  }
}

class _GeneratedAttachmentSinkScenario {
  const _GeneratedAttachmentSinkScenario({
    required this.concurrency,
    required this.failureKind,
    required this.pages,
  });

  final int concurrency;
  final _GeneratedAttachmentFailureKind failureKind;
  final List<_GeneratedAttachmentSinkPage> pages;

  int get effectiveConcurrency => concurrency < 1 ? 1 : concurrency;

  List<bool> get pageResults =>
      pages.map((page) => page.shouldContinue).toList();

  List<int> get acceptedCounts =>
      pages.map((page) => page.acceptedCount).toList();

  List<List<String>> get pageEventIds {
    return [
      for (var pageIndex = 0; pageIndex < pages.length; pageIndex++)
        [
          for (
            var eventIndex = 0;
            eventIndex < pages[pageIndex].size;
            eventIndex++
          )
            eventIdAt(pageIndex, eventIndex),
        ],
    ];
  }

  List<String> get eventIds =>
      pageEventIds.expand((page) => page).toList(growable: false);

  Set<String> get failingEventIds {
    final ids = eventIds;
    switch (failureKind) {
      case _GeneratedAttachmentFailureKind.none:
        return <String>{};
      case _GeneratedAttachmentFailureKind.first:
        return ids.isEmpty ? <String>{} : <String>{ids.first};
      case _GeneratedAttachmentFailureKind.last:
        return ids.isEmpty ? <String>{} : <String>{ids.last};
      case _GeneratedAttachmentFailureKind.everySecond:
        return {
          for (var i = 0; i < ids.length; i++)
            if (i.isOdd) ids[i],
        };
      case _GeneratedAttachmentFailureKind.all:
        return ids.toSet();
    }
  }

  int? get expectedLastAcceptedCount =>
      acceptedCounts.isEmpty ? null : acceptedCounts.last;

  String eventIdAt(int pageIndex, int eventIndex) {
    return 'generated-p$pageIndex-e$eventIndex';
  }

  @override
  String toString() {
    return '_GeneratedAttachmentSinkScenario('
        'concurrency: $concurrency, '
        'failureKind: $failureKind, '
        'pages: $pages'
        ')';
  }
}

extension _AnyGeneratedAttachmentSinkScenario on glados.Any {
  glados.Generator<_GeneratedAttachmentFailureKind> get attachmentFailureKind =>
      glados.AnyUtils(this).choose(_GeneratedAttachmentFailureKind.values);

  glados.Generator<_GeneratedAttachmentSinkPage> get attachmentSinkPage =>
      glados.CombinableAny(this).combine3(
        glados.IntAnys(this).intInRange(0, 8),
        glados.BoolAny(this).bool,
        glados.IntAnys(this).intInRange(0, 25),
        (
          int size,
          bool shouldContinue,
          int acceptedCount,
        ) => _GeneratedAttachmentSinkPage(
          size: size,
          shouldContinue: shouldContinue,
          acceptedCount: acceptedCount,
        ),
      );

  glados.Generator<_GeneratedAttachmentSinkScenario>
  get attachmentSinkScenario => glados.CombinableAny(this).combine3(
    glados.IntAnys(this).intInRange(0, 6),
    attachmentFailureKind,
    glados.ListAnys(this).listWithLengthInRange(0, 8, attachmentSinkPage),
    (
      int concurrency,
      _GeneratedAttachmentFailureKind failureKind,
      List<_GeneratedAttachmentSinkPage> pages,
    ) => _GeneratedAttachmentSinkScenario(
      concurrency: concurrency,
      failureKind: failureKind,
      pages: pages,
    ),
  );
}

void main() {
  group('AttachmentAwareBootstrapSink', () {
    test('bounds concurrent attachment work to the configured limit', () async {
      const pageSize = 200;
      const concurrency = 4;
      var maxObserved = 0;
      var inFlight = 0;
      final completers = <String, Completer<void>>{};

      final sink = AttachmentAwareBootstrapSink(
        inner: _RecordingInnerSink(),
        // ignore: avoid_redundant_argument_values
        concurrency: concurrency,
        processAttachment: (event) async {
          inFlight++;
          if (inFlight > maxObserved) maxObserved = inFlight;
          final c = Completer<void>();
          completers[event.eventId] = c;
          await c.future;
          inFlight--;
        },
      );

      final events = List.generate(pageSize, (i) => _buildEvent('e$i'));
      await sink.onPage(events, _pageInfo());

      // Let the pool spin up, then release attachments one at a time so we
      // can verify the cap holds both at saturation and while draining.
      await Future<void>.value();
      expect(inFlight, concurrency);
      expect(sink.inFlightWorkerCount, concurrency);
      expect(sink.pendingCount, pageSize - concurrency);

      for (var i = 0; i < pageSize; i++) {
        completers['e$i']!.complete();
        await Future<void>.value();
      }
      await sink.drain();

      expect(maxObserved, concurrency);
      expect(sink.inFlightWorkerCount, 0);
      expect(sink.pendingCount, 0);
    });

    test(
      'a single failing attachment does not stop the worker from draining',
      () async {
        final processed = <String>[];
        final sink = AttachmentAwareBootstrapSink(
          inner: _RecordingInnerSink(),
          concurrency: 2,
          processAttachment: (event) async {
            if (event.eventId == 'bad') {
              throw StateError('simulated ingestor failure');
            }
            processed.add(event.eventId);
          },
        );

        await sink.onPage(
          [_buildEvent('a'), _buildEvent('bad'), _buildEvent('b')],
          _pageInfo(),
        );
        await sink.drain();

        expect(processed, containsAll(<String>['a', 'b']));
        expect(processed.contains('bad'), isFalse);
      },
    );

    test(
      'forwards events and lastAcceptedCount unchanged to the inner sink',
      () async {
        final inner = _RecordingInnerSink()..acceptedPerPage = 17;
        final sink = AttachmentAwareBootstrapSink(
          inner: inner,
          concurrency: 2,
          processAttachment: (_) async {},
        );

        final events = [_buildEvent('x'), _buildEvent('y')];
        final result = await sink.onPage(
          events,
          _pageInfo(pageIndex: 3),
        );
        await sink.drain();

        expect(result, isTrue);
        expect(inner.pages, hasLength(1));
        expect(
          inner.pages.single.map((e) => e.eventId),
          equals(<String>['x', 'y']),
        );
        expect(sink.lastAcceptedCount, 17);
      },
    );

    test('drain resolves immediately when idle', () async {
      final sink = AttachmentAwareBootstrapSink(
        inner: _RecordingInnerSink(),
        processAttachment: (_) async {},
      );
      await sink.drain();
      expect(sink.pendingCount, 0);
      expect(sink.inFlightWorkerCount, 0);
    });

    test('workers keep draining across multiple pages', () async {
      final processed = <String>[];
      final sink = AttachmentAwareBootstrapSink(
        inner: _RecordingInnerSink(),
        concurrency: 2,
        processAttachment: (event) async {
          processed.add(event.eventId);
        },
      );

      await sink.onPage(
        [_buildEvent('p1a'), _buildEvent('p1b')],
        _pageInfo(),
      );
      await sink.onPage(
        [_buildEvent('p2a'), _buildEvent('p2b'), _buildEvent('p2c')],
        _pageInfo(pageIndex: 1, totalEventsSoFar: 2),
      );
      await sink.drain();

      expect(
        processed,
        containsAll(<String>['p1a', 'p1b', 'p2a', 'p2b', 'p2c']),
      );
    });

    test('clamps sub-one concurrency to 1 instead of stalling', () async {
      final sink = AttachmentAwareBootstrapSink(
        inner: _RecordingInnerSink(),
        concurrency: 0,
        processAttachment: (_) async {},
      );

      await sink.onPage([_buildEvent('x')], _pageInfo());
      await sink.drain();

      expect(sink.pendingCount, 0);
    });

    glados.Glados(
      glados.any.attachmentSinkScenario,
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'generated pages forward unchanged while attachment workers drain',
      (scenario) async {
        final inner = _RecordingInnerSink()
          ..results.addAll(scenario.pageResults)
          ..acceptedCounts.addAll(scenario.acceptedCounts);
        final failingEventIds = scenario.failingEventIds;
        final attempted = <String>[];
        final duplicateAttempts = <String>[];
        final completers = <String, Completer<void>>{};
        var inFlight = 0;
        var maxObserved = 0;

        final sink = AttachmentAwareBootstrapSink(
          inner: inner,
          concurrency: scenario.concurrency,
          processAttachment: (event) async {
            final eventId = event.eventId;
            if (completers.containsKey(eventId)) {
              duplicateAttempts.add(eventId);
            }
            attempted.add(eventId);
            inFlight++;
            if (inFlight > maxObserved) maxObserved = inFlight;
            final completer = Completer<void>();
            completers[eventId] = completer;
            try {
              await completer.future;
              if (failingEventIds.contains(eventId)) {
                throw StateError('generated attachment failure');
              }
            } finally {
              inFlight--;
            }
          },
        );

        final observedResults = <bool>[];
        var totalEventsSoFar = 0;
        final pageEventIds = scenario.pageEventIds;
        for (var pageIndex = 0; pageIndex < pageEventIds.length; pageIndex++) {
          final events = [
            for (final eventId in pageEventIds[pageIndex]) _buildEvent(eventId),
          ];
          observedResults.add(
            await sink.onPage(
              events,
              _pageInfo(
                pageIndex: pageIndex,
                totalEventsSoFar: totalEventsSoFar,
              ),
            ),
          );
          totalEventsSoFar += events.length;
          expect(
            sink.inFlightWorkerCount,
            lessThanOrEqualTo(scenario.effectiveConcurrency),
            reason: '$scenario',
          );
        }

        final expectedIds = scenario.eventIds;
        final releasedIds = <String>{};
        while (releasedIds.length < expectedIds.length) {
          final startedIds = [
            for (final eventId in expectedIds)
              if (completers.containsKey(eventId) &&
                  !releasedIds.contains(eventId))
                eventId,
          ];
          expect(startedIds, isNotEmpty, reason: '$scenario');
          for (final eventId in startedIds) {
            releasedIds.add(eventId);
            completers[eventId]!.complete();
          }
          await Future<void>.value();
        }

        await sink.drain();

        expect(observedResults, scenario.pageResults, reason: '$scenario');
        expect(
          inner.pages
              .map((page) => page.map((event) => event.eventId).toList())
              .toList(),
          pageEventIds,
          reason: '$scenario',
        );
        expect(attempted, hasLength(expectedIds.length), reason: '$scenario');
        expect(attempted, unorderedEquals(expectedIds), reason: '$scenario');
        expect(duplicateAttempts, isEmpty, reason: '$scenario');
        expect(
          maxObserved,
          lessThanOrEqualTo(scenario.effectiveConcurrency),
          reason: '$scenario',
        );
        expect(sink.pendingCount, 0, reason: '$scenario');
        expect(sink.inFlightWorkerCount, 0, reason: '$scenario');
        expect(
          sink.lastAcceptedCount,
          scenario.expectedLastAcceptedCount,
          reason: '$scenario',
        );
      },
    );
  });
}
