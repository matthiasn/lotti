import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/utils/timeline_utils.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

class MockEvent extends Mock implements Event {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('computeExponentialBackoff', () {
    test('returns exact powers when jitter = 0 and clamps to max', () {
      // base=200ms, attempts 0 => 200ms
      expect(
        computeExponentialBackoff(0, jitterFraction: 0),
        const Duration(milliseconds: 200),
      );
      // attempts 1 => 400ms
      expect(
        computeExponentialBackoff(1, jitterFraction: 0),
        const Duration(milliseconds: 400),
      );
      // attempts large enough -> capped at 10s (6 -> 200ms * 64 = 12.8s)
      expect(
        computeExponentialBackoff(6, jitterFraction: 0),
        const Duration(seconds: 10),
      );
    });

    test('applies jitter within +/- 20%', () {
      final r = math.Random(42);
      final d = computeExponentialBackoff(3, random: r);
      // base*2^3 = 1600ms, bounds: [1280, 1920]
      expect(d.inMilliseconds, inInclusiveRange(1280, 1920));
    });
  });

  group('findLastIndexByEventId', () {
    Event event(String id) {
      final e = MockEvent();
      when(() => e.eventId).thenReturn(id);
      return e;
    }

    test('empty list returns -1', () {
      final list = <Event>[];
      expect(findLastIndexByEventId(list, 'x'), -1);
    });

    test('finds last index of event', () {
      final list = <Event>[event('a'), event('b'), event('a')];
      expect(findLastIndexByEventId(list, 'a'), 2);
      expect(findLastIndexByEventId(list, 'b'), 1);
    });

    test('returns -1 for null id', () {
      final list = <Event>[event('a'), event('b')];
      expect(findLastIndexByEventId(list, null), -1);
    });
  });

  group('dedupEventsByIdPreserveOrder', () {
    Event event(String id) {
      final e = MockEvent();
      when(() => e.eventId).thenReturn(id);
      return e;
    }

    test('removes duplicates and preserves first occurrence order', () {
      final list = <Event>[
        event('a'),
        event('b'),
        event('a'),
        event('c'),
        event('b')
      ];
      final deduped = dedupEventsByIdPreserveOrder(list);
      expect(deduped.map((e) => e.eventId), ['a', 'b', 'c']);
    });
  });
}
