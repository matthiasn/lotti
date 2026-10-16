import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_capture_models.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_plan_models.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_timeline_models.dart';
import 'package:lotti/features/daily_os_next/logic/day_briefing.dart';

final _day = DateTime(2026, 10, 15);

const _category = DayAgentCategory(
  id: 'work',
  name: 'Work',
  colorHex: '4F8AF7',
);

TimeBlock _block(
  String id,
  int startHour,
  int minutes, {
  TimeBlockType type = TimeBlockType.ai,
  TimeBlockState state = TimeBlockState.committed,
}) {
  final start = _day.add(Duration(hours: startHour));
  return TimeBlock(
    id: id,
    title: 'Block $id',
    start: start,
    end: start.add(Duration(minutes: minutes)),
    type: type,
    state: state,
    category: _category,
  );
}

DraftPlan _plan(
  List<TimeBlock> blocks, {
  int capacityMinutes = 480,
  int scheduledMinutes = 300,
}) => DraftPlan(
  dayDate: _day,
  blocks: blocks,
  bands: const [],
  capacityMinutes: capacityMinutes,
  scheduledMinutes: scheduledMinutes,
);

DayBriefing _brief(
  DraftPlan plan, {
  bool hasPlan = true,
  DateTime? now,
}) => DayBriefing.of(
  draft: plan,
  hasPlan: hasPlan,
  now: now ?? _day.add(const Duration(hours: 8)),
);

void main() {
  test('says only that there is no plan when the day has none', () {
    final briefing = _brief(DraftPlan.emptyForDay(_day), hasPlan: false);

    expect(briefing.hasPlan, isFalse);
  });

  test('counts planned blocks, never buffers or dropped ones', () {
    final briefing = _brief(
      _plan([
        _block('a', 9, 60),
        _block('b', 11, 15, type: TimeBlockType.buffer),
        _block('c', 13, 60, state: TimeBlockState.dropped),
        _block('d', 14, 30, type: TimeBlockType.cal),
      ]),
    );

    expect(briefing.blockCount, 2);
  });

  test('the next block is the first that starts after now', () {
    final briefing = _brief(
      _plan([_block('late', 15, 30), _block('early', 9, 30)]),
      now: _day.add(const Duration(hours: 10)),
    );

    expect(briefing.next?.id, 'late');
    expect(briefing.nothingLeftToday, isFalse);
  });

  test('a block already running is not next', () {
    final briefing = _brief(
      _plan([_block('running', 9, 120)]),
      now: _day.add(const Duration(hours: 10)),
    );

    expect(briefing.next, isNull);
  });

  test('says nothing is left once every block today has started', () {
    final briefing = _brief(
      _plan([_block('a', 9, 30)]),
      now: _day.add(const Duration(hours: 18)),
    );

    expect(briefing.next, isNull);
    expect(briefing.nothingLeftToday, isTrue);
  });

  test('on a past day, nothing is next and nothing is "left today"', () {
    final briefing = _brief(
      _plan([_block('a', 9, 30)]),
      now: _day.add(const Duration(days: 1, hours: 8)),
    );

    expect(briefing.next, isNull);
    expect(briefing.nothingLeftToday, isFalse);
  });

  test('on a future day, the first block is next', () {
    final briefing = _brief(
      _plan([_block('b', 13, 30), _block('a', 9, 30)]),
      now: _day.subtract(const Duration(days: 1)),
    );

    expect(briefing.next?.id, 'a');
    expect(briefing.nothingLeftToday, isFalse);
  });

  test('an empty plan has nothing left to report', () {
    final briefing = _brief(
      _plan(const []),
      now: _day.add(const Duration(hours: 18)),
    );

    expect(briefing.blockCount, 0);
    expect(briefing.nothingLeftToday, isFalse);
  });

  test('the longest block is the earliest of equals', () {
    final briefing = _brief(
      _plan([
        _block('short', 8, 30),
        _block('first-long', 9, 90),
        _block('second-long', 13, 90),
      ]),
    );

    expect(briefing.longest?.id, 'first-long');
  });

  test('names no longest block with only one', () {
    expect(_brief(_plan([_block('a', 9, 90)])).longest, isNull);
  });

  test('free time is capacity minus what is scheduled', () {
    expect(
      _brief(_plan(const [])).freeMinutes,
      180,
    );
    expect(
      _brief(_plan(const [], scheduledMinutes: 540)).freeMinutes,
      -60,
    );
  });
}
