import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
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
  int acceptedPerPage = 0;
  int? _lastAccepted;

  @override
  int? get lastAcceptedCount => _lastAccepted;

  @override
  Future<bool> onPage(List<Event> events, BootstrapPageInfo info) async {
    pages.add(List<Event>.from(events));
    _lastAccepted = acceptedPerPage;
    return true;
  }
}

Event _buildEvent(String id) {
  final event = _MockEvent();
  when(() => event.eventId).thenReturn(id);
  return event;
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
      await Future<void>.delayed(Duration.zero);
      expect(inFlight, concurrency);
      expect(sink.inFlightWorkerCount, concurrency);
      expect(sink.pendingCount, pageSize - concurrency);

      for (var i = 0; i < pageSize; i++) {
        completers['e$i']!.complete();
        await Future<void>.delayed(Duration.zero);
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
  });
}
