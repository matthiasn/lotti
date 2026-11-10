import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/daily_os_next/logic/day_agenda_order.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';

const _category = DayAgentCategory(id: 'c', name: 'C', colorHex: '000000');
final _day = DateTime(2026, 5, 26);

TimeBlock _block(String id, int hour, {bool dropped = false}) => TimeBlock(
  id: id,
  title: id,
  start: _day.add(Duration(hours: hour)),
  end: _day.add(Duration(hours: hour + 1)),
  type: TimeBlockType.ai,
  state: dropped ? TimeBlockState.dropped : TimeBlockState.drafted,
  category: _category,
);

AgendaItem _item(String id, List<String> blocks) => AgendaItem(
  id: id,
  title: id,
  category: _category,
  linkedBlockIds: blocks,
);

DraftPlan _plan(List<TimeBlock> blocks, List<AgendaItem> items) => DraftPlan(
  dayDate: _day,
  blocks: blocks,
  bands: const [],
  capacityMinutes: 480,
  scheduledMinutes: 0,
  agendaItems: items,
);

List<(String, int?)> _order(DraftPlan plan) => [
  for (final (:item, :start) in agendaItemsByStart(plan))
    (item.id, start?.hour),
];

void main() {
  group('agendaItemsByStart', () {
    test('is empty for a plan without items', () {
      expect(agendaItemsByStart(_plan(const [], const [])), isEmpty);
    });

    test('sorts items by their start, not plan order', () {
      expect(
        _order(
          _plan(
            [_block('b9', 9), _block('b13', 13)],
            [
              _item('late', ['b13']),
              _item('early', ['b9']),
            ],
          ),
        ),
        [('early', 9), ('late', 13)],
      );
    });

    test('an item starts at the earliest of its blocks', () {
      expect(
        _order(
          _plan(
            [_block('b14', 14), _block('b8', 8)],
            [
              _item('split', ['b14', 'b8']),
            ],
          ),
        ),
        [('split', 8)],
      );
    });

    test('a dropped block holds no time', () {
      expect(
        _order(
          _plan(
            [_block('gone', 7, dropped: true), _block('kept', 12)],
            [
              _item('moved', ['gone', 'kept']),
            ],
          ),
        ),
        [('moved', 12)],
      );
    });

    test('ids that name no block are ignored', () {
      expect(
        _order(
          _plan(
            [_block('b10', 10)],
            [
              _item('x', ['nope', 'b10']),
            ],
          ),
        ),
        [('x', 10)],
      );
    });

    test('an item with no start sorts after one with a start', () {
      expect(
        _order(
          _plan(
            [_block('b10', 10)],
            [
              _item('loose', const []),
              _item('timed', ['b10']),
            ],
          ),
        ),
        [('timed', 10), ('loose', null)],
      );
    });

    test('an item with a start sorts before one without', () {
      expect(
        _order(
          _plan(
            [_block('b10', 10)],
            [
              _item('timed', ['b10']),
              _item('loose', const []),
            ],
          ),
        ),
        [('timed', 10), ('loose', null)],
      );
    });

    test('items without a start keep plan order among themselves', () {
      expect(
        _order(
          _plan(const [], [_item('a', const []), _item('b', const [])]),
        ),
        [('a', null), ('b', null)],
      );
    });

    test('items starting together keep plan order', () {
      expect(
        _order(
          _plan(
            [_block('x', 9), _block('y', 9)],
            [
              _item('second', ['y']),
              _item('first', ['x']),
            ],
          ),
        ),
        [('second', 9), ('first', 9)],
      );
    });

    glados.Glados(
      glados.any.list(glados.any.intInRange(-1, 24)),
    ).test(
      'is a permutation, timed items ascending then the rest in plan order',
      (hours) {
        // -1 stands for an item with no block.
        final plan = _plan(
          [
            for (final (i, h) in hours.indexed)
              if (h >= 0) _block('b$i', h),
          ],
          [
            for (final (i, h) in hours.indexed)
              _item('i$i', h >= 0 ? ['b$i'] : const []),
          ],
        );
        final ordered = agendaItemsByStart(plan);

        expect(
          ordered.map((e) => e.item.id).toSet(),
          {for (var i = 0; i < hours.length; i++) 'i$i'},
        );
        final starts = ordered.map((e) => e.start).toList();
        final firstLoose = starts.indexOf(null);
        final timed = firstLoose < 0 ? starts : starts.sublist(0, firstLoose);
        expect(timed.every((s) => s != null), isTrue);
        for (var i = 1; i < timed.length; i++) {
          expect(timed[i]!.isBefore(timed[i - 1]!), isFalse);
        }
        if (firstLoose >= 0) {
          final loose = ordered.sublist(firstLoose);
          expect(loose.every((e) => e.start == null), isTrue);
          final indices = [
            for (final e in loose) int.parse(e.item.id.substring(1)),
          ];
          expect(indices, [...indices]..sort());
        }
      },
      tags: 'glados',
    );
  });
}
