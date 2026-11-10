import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/logic/day_category_totals.dart';

const _work = DayAgentCategory(id: 'work', name: 'Work', colorHex: '5ED4B7');
const _health = DayAgentCategory(
  id: 'health',
  name: 'Health',
  colorHex: 'F5A623',
);
const _admin = DayAgentCategory(id: 'admin', name: 'Admin', colorHex: '8E8E93');

final _day = DateTime(2026, 11, 10);

TimeBlock _block(
  String id,
  DayAgentCategory category, {
  required int startHour,
  required int minutes,
  TimeBlockState state = TimeBlockState.drafted,
}) {
  final start = _day.add(Duration(hours: startHour));
  return TimeBlock(
    id: id,
    title: id,
    start: start,
    end: start.add(Duration(minutes: minutes)),
    type: TimeBlockType.ai,
    state: state,
    category: category,
  );
}

DraftPlan _plan(List<TimeBlock> blocks) => DraftPlan(
  dayDate: _day,
  blocks: blocks,
  bands: const [],
  capacityMinutes: 480,
  scheduledMinutes: 0,
);

void main() {
  group('categoryTotalsFor', () {
    test('returns nothing for a plan without blocks', () {
      expect(categoryTotalsFor(_plan(const [])), isEmpty);
    });

    test('adds up the minutes of every block in a category', () {
      final totals = categoryTotalsFor(
        _plan([
          _block('a', _work, startHour: 9, minutes: 60),
          _block('b', _work, startHour: 11, minutes: 45),
        ]),
      );

      expect(totals, hasLength(1));
      expect(totals.single.category, _work);
      expect(totals.single.minutes, 105);
    });

    test('leaves dropped blocks out of the totals', () {
      final totals = categoryTotalsFor(
        _plan([
          _block('kept', _work, startHour: 9, minutes: 30),
          _block(
            'dropped',
            _work,
            startHour: 10,
            minutes: 90,
            state: TimeBlockState.dropped,
          ),
        ]),
      );

      expect(totals.single.minutes, 30);
    });

    test('omits a category whose only blocks were dropped', () {
      final totals = categoryTotalsFor(
        _plan([
          _block('kept', _work, startHour: 9, minutes: 30),
          _block(
            'dropped',
            _health,
            startHour: 10,
            minutes: 90,
            state: TimeBlockState.dropped,
          ),
        ]),
      );

      expect(totals.map((t) => t.category.id), ['work']);
    });

    test('sorts categories by planned minutes, largest first', () {
      final totals = categoryTotalsFor(
        _plan([
          _block('admin', _admin, startHour: 8, minutes: 15),
          _block('work', _work, startHour: 9, minutes: 120),
          _block('health', _health, startHour: 12, minutes: 60),
        ]),
      );

      expect(totals.map((t) => t.category.id), ['work', 'health', 'admin']);
      expect(totals.map((t) => t.minutes), [120, 60, 15]);
    });

    test('keys totals by category id and reports the last block category', () {
      const renamed = DayAgentCategory(
        id: 'work',
        name: 'Deep work',
        colorHex: '3366FF',
      );
      final totals = categoryTotalsFor(
        _plan([
          _block('a', _work, startHour: 9, minutes: 30),
          _block('b', renamed, startHour: 10, minutes: 30),
        ]),
      );

      expect(totals, hasLength(1));
      expect(totals.single.minutes, 60);
      expect(totals.single.category, renamed);
    });
  });
}
