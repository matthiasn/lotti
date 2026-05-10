import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/sync/matrix/utils/timeline_utils.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';

class _GeneratedBackoffScenario {
  const _GeneratedBackoffScenario({
    required this.attempts,
    required this.baseMs,
    required this.maxExtraMs,
  });

  final int attempts;
  final int baseMs;
  final int maxExtraMs;

  int get maxMs => baseMs + maxExtraMs;

  int get expectedMs {
    final raw = baseMs * math.pow(2, attempts);
    return raw.clamp(baseMs.toDouble(), maxMs.toDouble()).round();
  }

  @override
  String toString() {
    return '_GeneratedBackoffScenario('
        'attempts: $attempts, '
        'baseMs: $baseMs, '
        'maxExtraMs: $maxExtraMs'
        ')';
  }
}

class _GeneratedTimelineIdsScenario {
  const _GeneratedTimelineIdsScenario({
    required this.idSlots,
    required this.targetSlot,
  });

  final List<int> idSlots;
  final int targetSlot;

  String get targetId => 'generated-$targetSlot';

  List<String> get ids => [
    for (final slot in idSlots) 'generated-$slot',
  ];

  int get expectedLastIndex {
    for (var index = ids.length - 1; index >= 0; index--) {
      if (ids[index] == targetId) return index;
    }
    return -1;
  }

  List<String> get expectedDedupedIds {
    final seen = <String>{};
    return [
      for (final id in ids)
        if (seen.add(id)) id,
    ];
  }

  @override
  String toString() {
    return '_GeneratedTimelineIdsScenario('
        'idSlots: $idSlots, '
        'targetSlot: $targetSlot'
        ')';
  }
}

extension _AnyTimelineUtilsScenario on glados.Any {
  glados.Generator<_GeneratedBackoffScenario> get backoffScenario =>
      glados.CombinableAny(this).combine3(
        glados.IntAnys(this).intInRange(0, 8),
        glados.IntAnys(this).intInRange(1, 20),
        glados.IntAnys(this).intInRange(0, 80),
        (
          int attempts,
          int baseMs,
          int maxExtraMs,
        ) => _GeneratedBackoffScenario(
          attempts: attempts,
          baseMs: baseMs,
          maxExtraMs: maxExtraMs,
        ),
      );

  glados.Generator<_GeneratedTimelineIdsScenario> get timelineIdsScenario =>
      glados.CombinableAny(this).combine2(
        glados.ListAnys(
          this,
        ).listWithLengthInRange(0, 14, glados.IntAnys(this).intInRange(0, 6)),
        glados.IntAnys(this).intInRange(0, 6),
        (List<int> idSlots, int targetSlot) => _GeneratedTimelineIdsScenario(
          idSlots: idSlots,
          targetSlot: targetSlot,
        ),
      );
}

Event _event(String id) {
  final event = MockEvent();
  when(() => event.eventId).thenReturn(id);
  return event;
}

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

    glados.Glados(
      glados.any.backoffScenario,
    ).test(
      'generated jitter-free exponential backoff matches clamp model',
      (scenario) {
        final actual = computeExponentialBackoff(
          scenario.attempts,
          base: Duration(milliseconds: scenario.baseMs),
          max: Duration(milliseconds: scenario.maxMs),
          jitterFraction: 0,
        );

        expect(actual.inMilliseconds, scenario.expectedMs);
      },
      tags: 'glados',
    );
  });

  group('findLastIndexByEventId', () {
    Event event(String id) {
      return _event(id);
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
      return _event(id);
    }

    test('removes duplicates and preserves first occurrence order', () {
      final list = <Event>[
        event('a'),
        event('b'),
        event('a'),
        event('c'),
        event('b'),
      ];
      final deduped = dedupEventsByIdPreserveOrder(list);
      expect(deduped.map((e) => e.eventId), ['a', 'b', 'c']);
    });
  });

  glados.Glados(
    glados.any.timelineIdsScenario,
  ).test(
    'generated timeline id utilities match last-index and dedupe models',
    (scenario) {
      final events = [for (final id in scenario.ids) _event(id)];

      expect(
        findLastIndexByEventId(events, scenario.targetId),
        scenario.expectedLastIndex,
      );
      expect(findLastIndexByEventId(events, null), -1);
      expect(
        dedupEventsByIdPreserveOrder(
          events,
        ).map((event) => event.eventId).toList(),
        scenario.expectedDedupedIds,
      );
    },
    tags: 'glados',
  );
}
