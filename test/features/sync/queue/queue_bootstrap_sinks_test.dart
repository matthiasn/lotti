import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/pipeline/catch_up_strategy.dart';
import 'package:lotti/features/sync/queue/queue_bootstrap_sinks.dart';
import 'package:matrix/matrix.dart';

BootstrapPageInfo _pageInfo({int pageIndex = 0}) => BootstrapPageInfo(
  pageIndex: pageIndex,
  totalEventsSoFar: 0,
  oldestTimestampSoFar: null,
  serverHasMore: true,
  elapsed: Duration.zero,
);

/// Configurable inner [BootstrapSink] that records each [onPage] call and
/// replays scripted accepted-counts / continue-flags.
class _FakeInnerSink implements BootstrapSink {
  _FakeInnerSink({
    this.acceptedPerPage,
    this.continueResult = true,
  });

  final List<int> calls = <int>[];
  final int? acceptedPerPage;
  final bool continueResult;
  int? _lastAccepted;

  @override
  int? get lastAcceptedCount => _lastAccepted;

  @override
  Future<bool> onPage(List<Event> events, BootstrapPageInfo info) async {
    calls.add(info.pageIndex);
    _lastAccepted = acceptedPerPage;
    return continueResult;
  }
}

void main() {
  group('ProgressForwardingSink', () {
    test(
      'forwards the page to inner and relays its continue flag and count',
      () async {
        final inner = _FakeInnerSink(acceptedPerPage: 4);
        final progressed = <int>[];
        final sink = ProgressForwardingSink(
          inner: inner,
          onProgress: (info) => progressed.add(info.pageIndex),
        );

        final keepGoing = await sink.onPage(const [], _pageInfo(pageIndex: 2));

        expect(keepGoing, isTrue);
        expect(inner.calls, [2]);
        expect(progressed, [2]);
        expect(sink.lastAcceptedCount, 4);
      },
    );

    test('relays a stop signal from the inner sink', () async {
      final inner = _FakeInnerSink(continueResult: false);
      final sink = ProgressForwardingSink(inner: inner);

      expect(await sink.onPage(const [], _pageInfo()), isFalse);
    });

    test(
      'swallows a throwing onProgress and still delegates to inner',
      () async {
        final inner = _FakeInnerSink();
        final sink = ProgressForwardingSink(
          inner: inner,
          onProgress: (_) => throw StateError('setState on unmounted widget'),
        );

        final keepGoing = await sink.onPage(const [], _pageInfo());

        expect(keepGoing, isTrue);
        expect(inner.calls, hasLength(1));
      },
    );
  });

  group('TotalAcceptedCountingSink', () {
    test('accumulates the inner accepted-count across pages', () async {
      final inner = _FakeInnerSink(acceptedPerPage: 3);
      final sink = TotalAcceptedCountingSink(inner);

      await sink.onPage(const [], _pageInfo());
      await sink.onPage(const [], _pageInfo(pageIndex: 1));

      expect(sink.totalAccepted, 6);
      expect(sink.lastAcceptedCount, 3);
    });

    test('treats a null inner count as zero contribution', () async {
      final inner = _FakeInnerSink();
      final sink = TotalAcceptedCountingSink(inner);

      await sink.onPage(const [], _pageInfo());

      expect(sink.totalAccepted, 0);
      expect(sink.lastAcceptedCount, isNull);
    });

    test('relays the inner continue flag', () async {
      final inner = _FakeInnerSink(acceptedPerPage: 1, continueResult: false);
      final sink = TotalAcceptedCountingSink(inner);

      expect(await sink.onPage(const [], _pageInfo()), isFalse);
      expect(sink.totalAccepted, 1);
    });
  });
}
