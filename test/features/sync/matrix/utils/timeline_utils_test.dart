import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/sync/matrix/utils/timeline_utils.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';

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
