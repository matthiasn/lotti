import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_timeline_overlap.dart';

final _day = DateTime(2026, 5, 25);

const _category = DayAgentCategory(
  id: 'cat-work',
  name: 'Work',
  colorHex: '5ED4B7',
);

/// The window the pane derives at default zoom: a 28 px readable block at
/// 1 px per minute.
const _window = Duration(minutes: 28);

/// The pane's token values, so geometry expectations read as the numbers a
/// 300 px lane really produces.
const _lane = 300.0;
const _edge = 8.0;
const _indent = 16.0;
const _gap = 4.0;

/// Minutes into the day, so spans read as clock times at the call site.
int _hm(int hour, [int minute = 0]) => hour * 60 + minute;

TimeBlock _block(String id, int startMinutes, int endMinutes) => TimeBlock(
  id: id,
  title: id,
  start: _day.add(Duration(minutes: startMinutes)),
  end: _day.add(Duration(minutes: endMinutes)),
  type: TimeBlockType.manual,
  state: TimeBlockState.completed,
  category: _category,
);

List<TimelineBlockSlot> _layout(
  List<TimeBlock> blocks, {
  Duration peerWindow = _window,
}) => layoutTimelineBlocks(blocks, peerWindow: peerWindow);

TimelineBlockSlot _slot(List<TimelineBlockSlot> slots, String id) =>
    slots.singleWhere((slot) => slot.block.id == id);

/// `(depth, column, columnCount)` — the whole placement in one comparable
/// value, so an assertion states the expected slot rather than three fields.
(int, int, int) _placement(List<TimelineBlockSlot> slots, String id) {
  final slot = _slot(slots, id);
  return (slot.depth, slot.column, slot.columnCount);
}

Map<String, TimelineBlockInsets> _resolve(
  List<TimelineBlockSlot> slots, {
  double laneWidth = _lane,
}) => resolveTimelineBlockInsets(
  slots,
  laneWidth: laneWidth,
  edgeInset: _edge,
  indent: _indent,
  columnGap: _gap,
);

bool _overlaps(TimeBlock a, TimeBlock b) =>
    a.start.isBefore(b.end) && b.start.isBefore(a.end);

/// A random day of spans plus the window it is laid out with.
class _Scenario {
  const _Scenario(this.blocks, this.window);

  final List<TimeBlock> blocks;
  final Duration window;

  @override
  String toString() =>
      '_Scenario(window: ${window.inMinutes}m, blocks: '
      '${blocks.map((b) => '${b.id}@${b.start.hour}:${b.start.minute}'
          '+${b.duration.inMinutes}m').join(', ')})';
}

extension _AnyOverlap on glados.Any {
  /// A span anywhere in the day, up to five hours long; zero-length allowed,
  /// because instant notes reach the lane too.
  glados.Generator<(int, int)> get _span => glados.CombinableAny(this).combine2(
    glados.IntAnys(this).intInRange(0, 24 * 60),
    glados.IntAnys(this).intInRange(0, 5 * 60 + 1),
    (start, length) => (start, start + length),
  );

  glados.Generator<_Scenario> get scenario =>
      glados.CombinableAny(this).combine2(
        glados.ListAnys(this).listWithLengthInRange(0, 8, _span),
        glados.IntAnys(this).intInRange(1, 91),
        (spans, window) => _Scenario(
          [
            for (final (index, span) in spans.indexed)
              _block('b$index', span.$1, span.$2),
          ],
          Duration(minutes: window),
        ),
      );

  glados.Generator<double> get laneWidth =>
      glados.IntAnys(this).intInRange(0, 601).map((v) => v.toDouble());
}

void main() {
  group('layoutTimelineBlocks — the lane floor', () {
    test('returns no slots for no blocks', () {
      expect(_layout(const []), isEmpty);
    });

    test('a lone block sits on the floor in a single column', () {
      final slots = _layout([_block('a', _hm(9), _hm(10))]);

      expect(_placement(slots, 'a'), (0, 0, 1));
      expect(_slot(slots, 'a').isRaised, isFalse);
      expect(_slot(slots, 'a').parentId, isNull);
    });

    test('blocks that never share a minute all keep the full lane', () {
      final slots = _layout([
        _block('a', _hm(9), _hm(10)),
        _block('b', _hm(11), _hm(12)),
        _block('c', _hm(14), _hm(14, 30)),
      ]);

      for (final id in ['a', 'b', 'c']) {
        expect(_placement(slots, id), (0, 0, 1), reason: id);
      }
    });

    test('a block starting exactly when another ends does not overlap it', () {
      final slots = _layout([
        _block('a', _hm(9), _hm(10)),
        _block('b', _hm(10), _hm(11)),
      ]);

      expect(_placement(slots, 'b'), (0, 0, 1));
    });

    test('a block after the cluster ends returns to the floor', () {
      final slots = _layout([
        _block('a', _hm(9), _hm(10)),
        _block('b', _hm(9, 30), _hm(9, 45)),
        _block('c', _hm(10, 30), _hm(11)),
      ]);

      expect(_placement(slots, 'b'), (1, 0, 1));
      expect(_placement(slots, 'c'), (0, 0, 1));
    });
  });

  group('layoutTimelineBlocks — raising', () {
    test(
      'a block starting a window into a running block is raised above it',
      () {
        final slots = _layout([
          _block('session', _hm(15), _hm(18)),
          _block('call', _hm(16), _hm(16, 30)),
        ]);

        expect(_placement(slots, 'session'), (0, 0, 1));
        expect(_placement(slots, 'call'), (1, 0, 1));
        expect(_slot(slots, 'call').isRaised, isTrue);
        expect(_slot(slots, 'call').parentId, 'session');
      },
    );

    test('nested interruptions rise one level each, each above the last', () {
      final slots = _layout([
        _block('session', _hm(15), _hm(18)),
        _block('coding', _hm(15, 30), _hm(17)),
        _block('call', _hm(16, 10), _hm(16, 40)),
      ]);

      expect(_slot(slots, 'session').depth, 0);
      expect(_slot(slots, 'coding').depth, 1);
      expect(_slot(slots, 'coding').parentId, 'session');
      expect(_slot(slots, 'call').depth, 2);
      expect(_slot(slots, 'call').parentId, 'coding');
    });

    test(
      'a later block rises only above blocks still running at its start',
      () {
        final slots = _layout([
          _block('session', _hm(15), _hm(18)),
          _block('early', _hm(15, 30), _hm(16)),
          _block('late', _hm(17), _hm(17, 30)),
        ]);

        // `early` is over by 17:00, so `late` sits one level up, not two.
        expect(_placement(slots, 'late'), (1, 0, 1));
        expect(_slot(slots, 'late').parentId, 'session');
      },
    );

    test('a block ending inside a raised block still counts it as running', () {
      final slots = _layout([
        _block('a', _hm(15), _hm(15, 40)),
        _block('b', _hm(15, 35), _hm(17)),
        _block('c', _hm(16, 45), _hm(17, 30)),
      ]);

      // `a` is over by 16:45 but `b` (raised above it) is not, so `c`
      // rises above `b` rather than dropping to the floor.
      expect(_slot(slots, 'b').depth, 1);
      expect(_slot(slots, 'c').depth, 2);
      expect(_slot(slots, 'c').parentId, 'b');
    });

    test(
      'a block raised above a pair of peers is measured from the leftmost '
      'one still running',
      () {
        final slots = _layout([
          _block('left', _hm(9), _hm(9, 30)),
          _block('right', _hm(9, 10), _hm(12)),
          _block('call', _hm(10), _hm(10, 30)),
        ]);

        // `left` is over by 10:00; only the right-hand column still runs.
        expect(_placement(slots, 'left'), (0, 0, 2));
        expect(_placement(slots, 'right'), (0, 1, 2));
        expect(_placement(slots, 'call'), (1, 0, 1));
        expect(_slot(slots, 'call').parentId, 'right');
      },
    );

    test(
      'a block raised above a pair both still running is measured from the '
      'left-hand one',
      () {
        final slots = _layout([
          _block('left', _hm(9), _hm(11)),
          _block('right', _hm(9, 10), _hm(12)),
          _block('call', _hm(10), _hm(10, 30)),
        ]);

        expect(_slot(slots, 'call').parentId, 'left');
      },
    );

    test(
      "the parent is fixed when the level opens, so a raised level's peers "
      'share it',
      () {
        final slots = _layout([
          _block('left', _hm(9), _hm(10, 2)),
          _block('right', _hm(9, 10), _hm(12)),
          _block('call', _hm(10), _hm(10, 30)),
          _block('note', _hm(10, 5), _hm(10, 30)),
        ]);

        // `call` opened its level while `left` still ran; `note` joins as a
        // peer after `left` has ended and still measures from `left`.
        expect(_placement(slots, 'call'), (1, 0, 2));
        expect(_placement(slots, 'note'), (1, 1, 2));
        expect(_slot(slots, 'call').parentId, 'left');
        expect(_slot(slots, 'note').parentId, 'left');
      },
    );
  });

  group('layoutTimelineBlocks — peers', () {
    test(
      'blocks starting the same minute are peers in columns, longest first',
      () {
        final slots = _layout([
          _block('short', _hm(9), _hm(9, 30)),
          _block('long', _hm(9), _hm(10)),
        ]);

        expect(_placement(slots, 'long'), (0, 0, 2));
        expect(_placement(slots, 'short'), (0, 1, 2));
      },
    );

    for (final (minutes, expected) in [(27, 'peer'), (28, 'raised')]) {
      test('a block starting $minutes minutes in (window 28) is $expected', () {
        final slots = _layout([
          _block('a', _hm(9), _hm(10)),
          _block('b', _hm(9, minutes), _hm(10)),
        ]);

        expect(
          _placement(slots, 'b'),
          expected == 'peer' ? (0, 1, 2) : (1, 0, 1),
        );
      });
    }

    test('a peer takes over a column whose block has ended', () {
      final slots = _layout([
        _block('a', _hm(9), _hm(10)),
        _block('b', _hm(9), _hm(9, 20)),
        _block('c', _hm(9, 10), _hm(9, 40)),
        _block('d', _hm(9, 25), _hm(9, 50)),
      ]);

      expect(_placement(slots, 'a'), (0, 0, 3));
      expect(_placement(slots, 'b'), (0, 1, 3));
      // `b` still runs at 09:10, so `c` opens a third column …
      expect(_placement(slots, 'c'), (0, 2, 3));
      // … and `d` reuses `b`'s column, free since 09:20.
      expect(_placement(slots, 'd'), (0, 1, 3));
    });

    test(
      'a reused column reports its latest block as the one still running',
      () {
        final slots = _layout([
          _block('a', _hm(9), _hm(9, 20)),
          _block('b', _hm(9, 5), _hm(12)),
          _block('c', _hm(9, 25), _hm(11)),
          _block('call', _hm(10), _hm(10, 30)),
        ]);

        // `a` opened column 0 and `b` column 1; `c` took over column 0 once
        // `a` had ended. At 10:00 `c` is the leftmost block running, so the
        // call measures from `c`, not from the long-gone `a`.
        expect(_placement(slots, 'a'), (0, 0, 2));
        expect(_placement(slots, 'b'), (0, 1, 2));
        expect(_placement(slots, 'c'), (0, 0, 2));
        expect(_slot(slots, 'call').parentId, 'c');
      },
    );

    test(
      "peers are judged against the level's first block, not the last peer",
      () {
        final slots = _layout([
          _block('a', _hm(15), _hm(16)),
          _block('b', _hm(15, 20), _hm(16)),
          _block('c', _hm(15, 40), _hm(16)),
        ]);

        // `c` is 20 minutes after `b` but 40 after `a`, the level's anchor.
        expect(_placement(slots, 'a'), (0, 0, 2));
        expect(_placement(slots, 'b'), (0, 1, 2));
        expect(_placement(slots, 'c'), (1, 0, 1));
      },
    );

    test("a peer of a raised block splits that level's width", () {
      final slots = _layout([
        _block('a', _hm(15), _hm(15, 40)),
        _block('b', _hm(15, 35), _hm(17)),
        _block('c', _hm(16), _hm(16, 30)),
      ]);

      expect(_placement(slots, 'b'), (1, 0, 2));
      expect(_placement(slots, 'c'), (1, 1, 2));
    });

    test(
      'two blocks starting the same minute stay peers with a zero window',
      () {
        final slots = _layout(
          [
            _block('a', _hm(9), _hm(10)),
            _block('b', _hm(9), _hm(9, 30)),
            _block('c', _hm(9, 1), _hm(9, 30)),
          ],
          peerWindow: Duration.zero,
        );

        expect(_placement(slots, 'a'), (0, 0, 2));
        expect(_placement(slots, 'b'), (0, 1, 2));
        // One minute later is outside a zero window.
        expect(_placement(slots, 'c'), (1, 0, 1));
      },
    );
  });

  group('layoutTimelineBlocks — degenerate spans', () {
    test('a zero-length block is placed but holds no column open', () {
      final slots = _layout([
        _block('session', _hm(15), _hm(18)),
        _block('instant', _hm(15, 30), _hm(15, 30)),
        _block('next', _hm(15, 35), _hm(16)),
      ]);

      expect(_placement(slots, 'instant'), (1, 0, 1));
      // `instant` kept nothing running, so `next` starts a fresh level
      // rather than joining or rising above it.
      expect(_placement(slots, 'next'), (1, 0, 1));
      expect(_slot(slots, 'next').parentId, 'session');
    });

    test(
      'a block ending before it starts is treated as instant at its start',
      () {
        final slots = _layout([
          _block('session', _hm(15), _hm(18)),
          _block('backwards', _hm(15, 30), _hm(15, 10)),
          _block('next', _hm(15, 35), _hm(16)),
        ]);

        expect(_placement(slots, 'backwards'), (1, 0, 1));
        expect(_placement(slots, 'next'), (1, 0, 1));
      },
    );
  });

  group('layoutTimelineBlocks — ordering', () {
    test('ties on start and end break by id, whatever the input order', () {
      final a = _block('a', _hm(9), _hm(10));
      final b = _block('b', _hm(9), _hm(10));

      final forward = _layout([a, b]);
      final reversed = _layout([b, a]);

      expect(_placement(forward, 'a'), (0, 0, 2));
      expect(_placement(forward, 'b'), (0, 1, 2));
      expect(
        reversed.map((slot) => slot.toString()),
        forward.map((slot) => slot.toString()),
      );
    });

    test(
      'slots come back in paint order: floor first, deeper levels later',
      () {
        final slots = _layout([
          _block('call', _hm(16, 10), _hm(16, 40)),
          _block('coding', _hm(15, 30), _hm(17)),
          _block('session', _hm(15), _hm(18)),
          _block('coffee', _hm(9), _hm(9, 30)),
          _block('standup', _hm(9), _hm(10)),
        ]);

        expect(slots.map((slot) => slot.block.id), [
          'standup',
          'coffee',
          'session',
          'coding',
          'call',
        ]);
      },
    );
  });

  group('TimelineBlockSlot.horizontalInsets', () {
    TimelineBlockInsets insets(
      TimelineBlockSlot slot, {
      double laneWidth = _lane,
      TimelineBlockInsets? parent,
    }) => slot.horizontalInsets(
      laneWidth: laneWidth,
      edgeInset: _edge,
      indent: _indent,
      columnGap: _gap,
      parent: parent,
    );

    TimelineBlockSlot slot({
      int depth = 0,
      int column = 0,
      int columnCount = 1,
      String? parentId,
    }) => TimelineBlockSlot(
      block: _block('x', _hm(9), _hm(10)),
      depth: depth,
      column: column,
      columnCount: columnCount,
      parentId: parentId ?? (depth > 0 ? 'parent' : null),
    );

    test('a floor block in a single column keeps only the edge gutters', () {
      expect(insets(slot()), (left: 8.0, right: 8.0));
    });

    test(
      'a slot the layout could never produce is refused at construction',
      () {
        // Each would resolve to NaN or negative geometry, or name a parent
        // the level cannot have; the layout never builds one, and the
        // constructor says so.
        expect(() => slot(columnCount: 0), throwsAssertionError);
        expect(() => slot(column: 2, columnCount: 2), throwsAssertionError);
        expect(() => slot(column: -1), throwsAssertionError);
        expect(() => slot(depth: -1), throwsAssertionError);
        expect(
          () => TimelineBlockSlot(
            block: _block('x', _hm(9), _hm(10)),
            depth: 1,
            column: 0,
            columnCount: 1,
          ),
          throwsAssertionError,
        );
        expect(() => slot(parentId: 'floor-with-parent'), throwsAssertionError);
      },
    );

    test(
      "a raised level is indented from its parent's left edge and keeps the "
      "lane's right gutter",
      () {
        final first = insets(slot(depth: 1), parent: (left: 8.0, right: 8.0));
        expect(first, (left: 24.0, right: 8.0));
        expect(insets(slot(depth: 2), parent: first), (left: 40.0, right: 8.0));
      },
    );

    test("the indent never takes more than half the parent's width", () {
      // A 20 px parent gives up 10, not 16.
      expect(
        insets(slot(depth: 1), parent: (left: 8.0, right: 272.0)),
        (left: 18.0, right: 8.0),
      );
    });

    test(
      "a raised level above the left-hand column runs to the lane's right "
      "gutter, not to the column's",
      () {
        expect(
          insets(slot(depth: 1), parent: (left: 8.0, right: 152.0)),
          (left: 24.0, right: 8.0),
        );
      },
    );

    test('a raised level above the right-hand column starts inside it', () {
      expect(
        insets(slot(depth: 1), parent: (left: 152.0, right: 8.0)),
        (left: 168.0, right: 8.0),
      );
    });

    test('peer columns split the usable width with one gap between them', () {
      // (284 − 4) / 2 = 140 per column.
      expect(insets(slot(columnCount: 2)), (left: 8.0, right: 152.0));
      expect(
        insets(slot(column: 1, columnCount: 2)),
        (left: 152.0, right: 8.0),
      );
    });

    test('a raised peer column starts after the indent', () {
      // Region 24..292 = 268; (268 − 2 × 4) / 3 = 86.67 per column.
      final third = insets(
        slot(depth: 1, column: 2, columnCount: 3),
        parent: (left: 8.0, right: 8.0),
      );
      expect(third.left, closeTo(24 + 2 * (86.666 + 4), 0.01));
      expect(third.right, closeTo(8, 0.01));
    });

    test('a lane narrower than its gutters never yields negative geometry', () {
      final cramped = insets(slot(column: 2, columnCount: 3), laneWidth: 10);
      expect(cramped, (left: 10.0, right: 0.0));
    });

    test('a parent narrower than nothing still yields a valid region', () {
      // A parent whose insets exceed the lane (a squeezed cascade) has zero
      // width; the raised level then starts at the parent's left edge.
      expect(
        insets(slot(depth: 1), parent: (left: 300.0, right: 8.0)),
        (left: 300.0, right: 0.0),
      );
    });
  });

  group('resolveTimelineBlockInsets', () {
    test('threads each raised level through its parent', () {
      final insets = _resolve(
        _layout([
          _block('session', _hm(15), _hm(18)),
          _block('coding', _hm(15, 30), _hm(17)),
          _block('call', _hm(16, 10), _hm(16, 40)),
        ]),
      );

      expect(insets['session'], (left: 8.0, right: 8.0));
      expect(insets['coding'], (left: 24.0, right: 8.0));
      expect(insets['call'], (left: 40.0, right: 8.0));
    });

    test(
      "a block raised above the right-hand peer keeps that peer's stripe "
      'and leaves the left-hand peer alone',
      () {
        final insets = _resolve(
          _layout([
            _block('left', _hm(9), _hm(9, 30)),
            _block('right', _hm(9, 10), _hm(12)),
            _block('call', _hm(10), _hm(10, 30)),
          ]),
        );

        expect(insets['left'], (left: 8.0, right: 152.0));
        expect(insets['right'], (left: 152.0, right: 8.0));
        expect(insets['call'], (left: 168.0, right: 8.0));
      },
    );

    test("peers of a raised level split their parent's region", () {
      final insets = _resolve(
        _layout([
          _block('left', _hm(9), _hm(9, 30)),
          _block('right', _hm(9, 10), _hm(12)),
          _block('call', _hm(10), _hm(10, 30)),
          _block('note', _hm(10, 5), _hm(10, 30)),
        ]),
      );

      // Region 168..292 = 124; (124 − 4) / 2 = 60 per column.
      expect(insets['call'], (left: 168.0, right: 72.0));
      expect(insets['note'], (left: 232.0, right: 8.0));
    });

    test('an empty lane resolves to nothing', () {
      expect(_resolve(const []), isEmpty);
    });
  });

  group('layoutTimelineBlocks — properties', () {
    glados.Glados<_Scenario>(
      glados.any.scenario,
      glados.ExploreConfig(numRuns: 150),
    ).test(
      'every block is placed exactly once, in a valid column, floor first',
      (scenario) {
        final slots = _layout(scenario.blocks, peerWindow: scenario.window);

        expect(
          slots.map((slot) => slot.block.id).toSet(),
          scenario.blocks.map((block) => block.id).toSet(),
        );
        expect(slots.length, scenario.blocks.length);
        for (final slot in slots) {
          expect(slot.column, inInclusiveRange(0, slot.columnCount - 1));
        }
        for (var i = 1; i < slots.length; i++) {
          expect(slots[i].depth, greaterThanOrEqualTo(slots[i - 1].depth));
        }
      },
      tags: 'glados',
    );

    glados.Glados<_Scenario>(
      glados.any.scenario,
      glados.ExploreConfig(numRuns: 150),
    ).test(
      'a block that overlaps nothing has the floor to itself',
      (scenario) {
        final slots = _layout(scenario.blocks, peerWindow: scenario.window);

        for (final slot in slots) {
          final alone = scenario.blocks
              .where((other) => other.id != slot.block.id)
              .every((other) => !_overlaps(slot.block, other));
          if (alone) {
            expect(
              (slot.depth, slot.column, slot.columnCount),
              (0, 0, 1),
              reason: '${slot.block.id} overlaps nothing in $scenario',
            );
          }
        }
      },
      tags: 'glados',
    );

    glados.Glados<_Scenario>(
      glados.any.scenario,
      glados.ExploreConfig(numRuns: 150),
    ).test(
      'overlapping blocks on the same level never share a column',
      (scenario) {
        final slots = _layout(scenario.blocks, peerWindow: scenario.window);

        for (final a in slots) {
          for (final b in slots) {
            if (identical(a, b) || a.depth != b.depth) continue;
            if (!_overlaps(a.block, b.block)) continue;
            expect(
              a.column,
              isNot(b.column),
              reason: '${a.block.id} and ${b.block.id} collide in $scenario',
            );
            expect(a.columnCount, b.columnCount);
          }
        }
      },
      tags: 'glados',
    );

    glados.Glados<_Scenario>(
      glados.any.scenario,
      glados.ExploreConfig(numRuns: 150),
    ).test(
      'a raised block never floats: a block one level down, or a peer beside '
      'it, is still running at its start',
      (scenario) {
        final slots = _layout(scenario.blocks, peerWindow: scenario.window);

        for (final raised in slots.where((slot) => slot.isRaised)) {
          // Either it rose above a running block (one level down), or it
          // joined a level kept alive by a peer that started before it.
          final supported = slots.any(
            (other) =>
                !identical(other, raised) &&
                (other.depth == raised.depth - 1 ||
                    other.depth == raised.depth) &&
                !other.block.start.isAfter(raised.block.start) &&
                other.block.end.isAfter(raised.block.start),
          );
          expect(
            supported,
            isTrue,
            reason: '${raised.block.id} floats in $scenario',
          );
        }
      },
      tags: 'glados',
    );

    glados.Glados<_Scenario>(
      glados.any.scenario,
      glados.ExploreConfig(numRuns: 150),
    ).test(
      'a raised block names a parent one level down that started no later, '
      'and precedes it in paint order',
      (scenario) {
        final slots = _layout(scenario.blocks, peerWindow: scenario.window);

        for (final (index, slot) in slots.indexed) {
          if (!slot.isRaised) {
            expect(slot.parentId, isNull);
            continue;
          }
          final parentIndex = slots.indexWhere(
            (other) => other.block.id == slot.parentId,
          );
          expect(parentIndex, greaterThanOrEqualTo(0), reason: '$slot');
          expect(parentIndex, lessThan(index), reason: '$slot');
          final parent = slots[parentIndex];
          expect(parent.depth, slot.depth - 1, reason: '$slot');
          expect(
            parent.block.start.isAfter(slot.block.start),
            isFalse,
            reason: '$slot in $scenario',
          );
        }
      },
      tags: 'glados',
    );

    glados.Glados2<_Scenario, double>(
      glados.any.scenario,
      glados.any.laneWidth,
      glados.ExploreConfig(numRuns: 150),
    ).test(
      'insets stay inside the lane at any width, and a raised level starts '
      'at or after its parent and at most one indent beyond',
      (scenario, laneWidth) {
        final slots = _layout(scenario.blocks, peerWindow: scenario.window);
        final insets = _resolve(slots, laneWidth: laneWidth);

        for (final slot in slots) {
          final own = insets[slot.block.id]!;
          expect(own.left, greaterThanOrEqualTo(0));
          expect(own.right, greaterThanOrEqualTo(0));
          expect(
            own.left + own.right,
            lessThanOrEqualTo(laneWidth + 1e-9),
            reason: '$slot at $laneWidth px in $scenario',
          );
          if (slot.parentId case final parentId?) {
            final parent = insets[parentId]!;
            // Every peer of the level sits at or right of the parent; the
            // level itself (its first column) opens at most one indent in.
            expect(own.left, greaterThanOrEqualTo(parent.left - 1e-9));
            if (slot.column == 0) {
              expect(
                own.left,
                lessThanOrEqualTo(parent.left + _indent + 1e-9),
                reason: '$slot at $laneWidth px in $scenario',
              );
            }
          }
        }
      },
      tags: 'glados',
    );
  });
}
