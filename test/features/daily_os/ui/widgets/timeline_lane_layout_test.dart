import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/daily_os/state/timeline_data_controller.dart';
import 'package:lotti/features/daily_os/ui/widgets/timeline_lane_layout.dart';

final _day = DateTime(2024, 3, 15);

ActualTimeSlot _slot({
  required String id,
  required int startMinute,
  required int endMinute,
  String? categoryId,
}) {
  final start = _day.add(Duration(minutes: startMinute));
  final end = _day.add(Duration(minutes: endMinute));
  return ActualTimeSlot(
    startTime: start,
    endTime: end,
    categoryId: categoryId,
    entry: JournalEntity.journalEntry(
      meta: Metadata(
        id: id,
        createdAt: start,
        updatedAt: start,
        dateFrom: start,
        dateTo: end,
      ),
      entryText: EntryText(plainText: id),
    ),
  );
}

bool _overlaps(ActualTimeSlot a, ActualTimeSlot b) =>
    a.startTime.isBefore(b.endTime) && b.startTime.isBefore(a.endTime);

/// A generated set of slots with deliberately colliding intervals and a
/// small category pool so nesting (same category, contained) and lane
/// sharing both occur frequently.
class _LaneScenario {
  _LaneScenario({required int rawCount, required int seed})
    : slots = List.generate(rawCount % 7 + 1, (i) {
        final start = (seed * 7 + i * 13) % 540;
        final length = (seed + i * 29) % 120 + 10;
        final category = switch ((seed + i) % 3) {
          0 => 'cat-a',
          1 => 'cat-b',
          _ => null,
        };
        return _slot(
          id: 'slot-$seed-$i',
          startMinute: start,
          endMinute: start + length,
          categoryId: category,
        );
      });

  final List<ActualTimeSlot> slots;

  @override
  String toString() =>
      '_LaneScenario(${slots.map((s) => '${s.entry.meta.id}'
          '[${s.startTime.hour}:${s.startTime.minute}-'
          '${s.endTime.hour}:${s.endTime.minute} ${s.categoryId}]').join(', ')})';
}

extension _AnyLaneScenario on glados.Any {
  glados.Generator<_LaneScenario> get laneScenario => combine2(
    intInRange(1, 100),
    intInRange(0, 1000),
    (int rawCount, int seed) => _LaneScenario(rawCount: rawCount, seed: seed),
  );
}

void main() {
  group('slotContains', () {
    test('requires same non-null category and strict containment', () {
      final parent = _slot(
        id: 'p',
        startMinute: 0,
        endMinute: 120,
        categoryId: 'cat-a',
      );
      final child = _slot(
        id: 'c',
        startMinute: 30,
        endMinute: 60,
        categoryId: 'cat-a',
      );
      expect(slotContains(parent, child), isTrue);

      // Different category -> no containment.
      expect(
        slotContains(
          parent,
          _slot(id: 'x', startMinute: 30, endMinute: 60, categoryId: 'cat-b'),
        ),
        isFalse,
      );
      // Null category -> never contains.
      expect(
        slotContains(
          _slot(id: 'n', startMinute: 0, endMinute: 120),
          _slot(id: 'y', startMinute: 30, endMinute: 60),
        ),
        isFalse,
      );
      // Identical bounds -> not a parent/child pair.
      expect(
        slotContains(
          parent,
          _slot(id: 'z', startMinute: 0, endMinute: 120, categoryId: 'cat-a'),
        ),
        isFalse,
      );
    });
  });

  group('assignLanes static cases', () {
    test('empty input yields no assignments and lane count 1', () {
      final assignments = assignLanes([]);
      expect(assignments, isEmpty);
      expect(laneCountFor(assignments), 1);
    });

    test('single slot lands on lane 0', () {
      final assignments = assignLanes([
        _slot(id: 'a', startMinute: 0, endMinute: 60, categoryId: 'cat-a'),
      ]);
      expect(assignments, hasLength(1));
      expect(assignments.single.laneIndex, 0);
      expect(laneCountFor(assignments), 1);
    });

    test(
      'two fully-overlapping same-category slots nest instead of '
      'taking two lanes',
      () {
        final assignments = assignLanes([
          _slot(id: 'long', startMinute: 0, endMinute: 120, categoryId: 'c'),
          _slot(id: 'short', startMinute: 30, endMinute: 60, categoryId: 'c'),
        ]);
        expect(assignments, hasLength(1));
        expect(assignments.single.children, hasLength(1));
        expect(laneCountFor(assignments), 1);
      },
    );

    test('two overlapping different-category slots take separate lanes', () {
      final assignments = assignLanes([
        _slot(id: 'a', startMinute: 0, endMinute: 60, categoryId: 'cat-a'),
        _slot(id: 'b', startMinute: 30, endMinute: 90, categoryId: 'cat-b'),
      ]);
      expect(assignments, hasLength(2));
      expect(
        assignments.map((a) => a.laneIndex).toSet(),
        {0, 1},
      );
      expect(laneCountFor(assignments), 2);
    });

    test('three-way overlap needs three lanes; disjoint slot reuses one', () {
      final assignments = assignLanes([
        _slot(id: 'a', startMinute: 0, endMinute: 90, categoryId: 'cat-a'),
        _slot(id: 'b', startMinute: 10, endMinute: 80, categoryId: 'cat-b'),
        _slot(id: 'c', startMinute: 20, endMinute: 70),
        // Starts after everything ended -> reuses an existing lane.
        _slot(id: 'd', startMinute: 100, endMinute: 130, categoryId: 'cat-b'),
      ]);
      expect(laneCountFor(assignments), 3);
      final laneOfD = assignments
          .singleWhere((a) => a.slot.entry.meta.id == 'd')
          .laneIndex;
      expect(laneOfD, lessThan(3));
    });
  });

  group('generated lane/nesting invariants', () {
    glados.Glados(
      glados.any.laneScenario,
      glados.ExploreConfig(numRuns: 150),
    ).test('no two overlapping parents share a lane; every slot appears '
        'exactly once; lane count = max index + 1', (scenario) {
      final assignments = assignLanes(scenario.slots);

      // Every input slot appears exactly once — as a parent or as a child.
      final seen = <String>[
        for (final a in assignments) ...[
          a.slot.entry.meta.id,
          for (final c in a.children) c.entry.meta.id,
        ],
      ];
      expect(
        seen..sort(),
        scenario.slots.map((s) => s.entry.meta.id).toList()..sort(),
        reason: '$scenario',
      );

      // Overlapping parents never share a lane.
      for (var i = 0; i < assignments.length; i++) {
        for (var j = i + 1; j < assignments.length; j++) {
          if (_overlaps(assignments[i].slot, assignments[j].slot)) {
            expect(
              assignments[i].laneIndex,
              isNot(assignments[j].laneIndex),
              reason:
                  'overlap on same lane: ${assignments[i].slot.entry.meta.id} '
                  'vs ${assignments[j].slot.entry.meta.id} in $scenario',
            );
          }
        }
      }

      // Lane count is max index + 1 for non-empty input.
      expect(
        laneCountFor(assignments),
        assignments.map((a) => a.laneIndex).reduce((a, b) => a > b ? a : b) + 1,
        reason: '$scenario',
      );
    }, tags: 'glados');

    glados.Glados(
      glados.any.laneScenario,
      glados.ExploreConfig(numRuns: 150),
    ).test('groupNestedSlots never assigns a slot as both parent and child '
        'and every child is genuinely contained', (scenario) {
      final groups = groupNestedSlots(scenario.slots);

      final parents = groups.keys.map((s) => s.entry.meta.id).toSet();
      final children = <String>{
        for (final list in groups.values)
          for (final c in list) c.entry.meta.id,
      };
      expect(
        parents.intersection(children),
        isEmpty,
        reason: '$scenario',
      );

      for (final entry in groups.entries) {
        for (final child in entry.value) {
          expect(
            slotContains(entry.key, child),
            isTrue,
            reason:
                '${child.entry.meta.id} not contained by '
                '${entry.key.entry.meta.id} in $scenario',
          );
        }
      }
    }, tags: 'glados');

    glados.Glados(
      glados.any.laneScenario,
      glados.ExploreConfig(numRuns: 150),
    ).test('assignLanesToSlots never puts two overlapping slots on the '
        'same lane', (scenario) {
      final assignments = assignLanesToSlots(scenario.slots);

      expect(assignments, hasLength(scenario.slots.length));
      for (var i = 0; i < assignments.length; i++) {
        for (var j = i + 1; j < assignments.length; j++) {
          if (_overlaps(assignments[i].slot, assignments[j].slot)) {
            expect(
              assignments[i].laneIndex,
              isNot(assignments[j].laneIndex),
              reason: '$scenario',
            );
          }
        }
      }
    }, tags: 'glados');
  });
}
