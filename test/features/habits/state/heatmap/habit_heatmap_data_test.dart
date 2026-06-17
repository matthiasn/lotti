import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/habits/state/heatmap/habit_heatmap_data.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:lotti/utils/first_day_of_week.dart';
import 'package:lotti/widgets/charts/utils.dart';

HabitDefinition _habit({
  required String id,
  String categoryId = 'cat-1',
  DateTime? activeFrom,
}) {
  return HabitDefinition(
    id: id,
    name: id,
    description: '',
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
    vectorClock: null,
    private: false,
    active: true,
    activeFrom: activeFrom,
    categoryId: categoryId,
    habitSchedule: const HabitSchedule.daily(requiredCompletions: 1),
  );
}

HabitCompletionEntry _completion({
  required String habitId,
  required DateTime date,
  HabitCompletionType type = HabitCompletionType.success,
}) {
  return HabitCompletionEntry(
    meta: Metadata(
      id: '$habitId-${date.ymd}',
      createdAt: date,
      updatedAt: date,
      dateFrom: date,
      dateTo: date,
      private: false,
    ),
    data: HabitCompletionData(
      dateFrom: date,
      dateTo: date,
      habitId: habitId,
      completionType: type,
    ),
  );
}

void main() {
  // A Monday→Sunday week, used as the default range for most cases.
  const rangeStart = '2024-03-11'; // Monday
  const rangeEnd = '2024-03-17'; // Sunday
  HeatmapDay dayFor(List<HeatmapDay> days, String ymd) =>
      days.firstWhere((d) => d.ymd == ymd);

  group('HeatmapDay', () {
    test('intensity is 0 and not in active range when nothing is active', () {
      const day = HeatmapDay(
        ymd: '2024-03-15',
        successCount: 0,
        activeCount: 0,
        isToday: false,
      );
      expect(day.intensity, 0);
      expect(day.isInActiveRange, isFalse);
    });

    test('intensity is the success fraction', () {
      const day = HeatmapDay(
        ymd: '2024-03-15',
        successCount: 1,
        activeCount: 2,
        isToday: false,
      );
      expect(day.intensity, 0.5);
      expect(day.isInActiveRange, isTrue);
    });

    test('intensity clamps above full', () {
      const day = HeatmapDay(
        ymd: '2024-03-15',
        successCount: 3,
        activeCount: 2,
        isToday: false,
      );
      expect(day.intensity, 1.0);
    });
  });

  group('buildHeatmapDays', () {
    List<HeatmapDay> build({
      List<JournalEntity> completions = const [],
      List<HabitDefinition> habits = const [],
      Set<String> categories = const {},
      String start = rangeStart,
      String end = rangeEnd,
      String today = '2024-03-15',
    }) {
      return buildHeatmapDays(
        completions: completions,
        habitDefinitions: habits,
        rangeStartYmd: start,
        rangeEndYmd: end,
        selectedCategoryIds: categories,
        todayYmd: today,
      );
    }

    test('spans the inclusive range, ascending with no gaps', () {
      final days = build(
        habits: [_habit(id: 'h1', activeFrom: DateTime(2024))],
      );
      final expectedYmds = daysInRange(
        rangeStart: DateTime.parse(rangeStart),
        rangeEnd: DateTime.parse(rangeEnd),
      );
      expect(days.map((d) => d.ymd).toList(), expectedYmds);
      expect(days.first.ymd, rangeStart);
      expect(days.last.ymd, rangeEnd);
    });

    test('no habits at all → every day neutral (active count 0)', () {
      final days = build();
      expect(days, hasLength(7));
      expect(days.every((d) => d.activeCount == 0), isTrue);
      expect(days.every((d) => d.intensity == 0), isTrue);
      expect(days.every((d) => !d.isInActiveRange), isTrue);
    });

    test('active habit with no completions → denominator 1, intensity 0', () {
      final days = build(
        habits: [_habit(id: 'h1', activeFrom: DateTime(2024))],
      );
      expect(days.every((d) => d.activeCount == 1), isTrue);
      expect(days.every((d) => d.successCount == 0), isTrue);
      expect(days.every((d) => d.isInActiveRange), isTrue);
    });

    test('single success → that day is fully complete', () {
      final days = build(
        habits: [_habit(id: 'h1', activeFrom: DateTime(2024))],
        completions: [
          _completion(habitId: 'h1', date: DateTime(2024, 3, 15)),
        ],
      );
      final d = dayFor(days, '2024-03-15');
      expect(d.successCount, 1);
      expect(d.activeCount, 1);
      expect(d.intensity, 1.0);
    });

    test('two active habits, one success → intensity 0.5', () {
      final days = build(
        habits: [
          _habit(id: 'h1', activeFrom: DateTime(2024)),
          _habit(id: 'h2', activeFrom: DateTime(2024)),
        ],
        completions: [
          _completion(habitId: 'h1', date: DateTime(2024, 3, 15)),
        ],
      );
      final d = dayFor(days, '2024-03-15');
      expect(d.successCount, 1);
      expect(d.activeCount, 2);
      expect(d.intensity, 0.5);
    });

    test('back-dated success of a not-yet-active habit joins the union', () {
      // h2 becomes active after the range, but has a success inside it: it
      // must raise BOTH numerator and denominator that day, never exceeding 1.
      final days = build(
        habits: [
          _habit(id: 'h1', activeFrom: DateTime(2024)),
          _habit(id: 'h2', activeFrom: DateTime(2024, 3, 20)),
        ],
        completions: [
          _completion(habitId: 'h2', date: DateTime(2024, 3, 15)),
        ],
      );
      final d = dayFor(days, '2024-03-15');
      expect(d.successCount, 1);
      expect(d.activeCount, 2); // h1 active + h2 recorded
      expect(d.intensity, 0.5);
      expect(days.every((day) => day.intensity <= 1.0), isTrue);
    });

    test('days before any habit existed are neutral', () {
      final days = build(
        habits: [_habit(id: 'h1', activeFrom: DateTime(2024, 3, 14))],
      );
      expect(dayFor(days, '2024-03-11').isInActiveRange, isFalse);
      expect(dayFor(days, '2024-03-13').activeCount, 0);
      expect(dayFor(days, '2024-03-14').activeCount, 1);
      expect(dayFor(days, '2024-03-17').activeCount, 1);
    });

    test('skip and fail raise the denominator but not the numerator', () {
      final days = build(
        habits: [_habit(id: 'h1', activeFrom: DateTime(2024))],
        completions: [
          _completion(
            habitId: 'h1',
            date: DateTime(2024, 3, 12),
            type: HabitCompletionType.fail,
          ),
          _completion(
            habitId: 'h1',
            date: DateTime(2024, 3, 13),
            type: HabitCompletionType.skip,
          ),
        ],
      );
      final failDay = dayFor(days, '2024-03-12');
      final skipDay = dayFor(days, '2024-03-13');
      expect(failDay.successCount, 0);
      expect(failDay.activeCount, 1);
      expect(failDay.isInActiveRange, isTrue);
      expect(failDay.intensity, 0);
      expect(skipDay.successCount, 0);
      expect(skipDay.activeCount, 1);
    });

    test('category filter ignores excluded habits entirely', () {
      // h1 (cat-1) is never active in range; h2 (cat-2) succeeds. Filtering to
      // cat-1 must drop h2's completion AND h2 from the denominator → neutral.
      final days = build(
        habits: [
          _habit(id: 'h1', activeFrom: DateTime(2024, 4)),
          _habit(id: 'h2', categoryId: 'cat-2', activeFrom: DateTime(2024)),
        ],
        completions: [
          _completion(habitId: 'h2', date: DateTime(2024, 3, 15)),
        ],
        categories: {'cat-1'},
      );
      expect(days.every((d) => d.activeCount == 0), isTrue);
      expect(days.every((d) => d.successCount == 0), isTrue);
    });

    test('category filter that matches nothing → all neutral', () {
      final days = build(
        habits: [_habit(id: 'h1', activeFrom: DateTime(2024))],
        categories: {'cat-unknown'},
      );
      expect(days.every((d) => d.activeCount == 0), isTrue);
    });

    test('isToday is set on exactly the matching day', () {
      final days = build(
        habits: [_habit(id: 'h1', activeFrom: DateTime(2024))],
      );
      expect(days.where((d) => d.isToday).map((d) => d.ymd), ['2024-03-15']);
    });

    test('ignores non-completion journal entities', () {
      final unrelated = JournalEntity.journalEntry(
        meta: Metadata(
          id: 'note-1',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
          private: false,
        ),
      );
      final days = build(
        habits: [_habit(id: 'h1', activeFrom: DateTime(2024))],
        completions: [unrelated],
      );
      expect(dayFor(days, '2024-03-15').successCount, 0);
    });
  });

  group('groupIntoWeekColumns', () {
    // 10-day span Wed 2024-03-06 → Fri 2024-03-15.
    List<HeatmapDay> tenDays() => buildHeatmapDays(
      completions: const [],
      habitDefinitions: [_habit(id: 'h1', activeFrom: DateTime(2024))],
      rangeStartYmd: '2024-03-06',
      rangeEndYmd: '2024-03-15',
      selectedCategoryIds: const {},
      todayYmd: '2024-03-15',
    );

    String? ymdAt(List<List<HeatmapDay?>> cols, int col, int row) =>
        cols[col][row]?.ymd;

    test('empty input → no columns', () {
      expect(groupIntoWeekColumns(const [], firstDayOfWeekIndex: 1), isEmpty);
    });

    test('Monday-first alignment with leading and trailing nulls', () {
      final cols = groupIntoWeekColumns(tenDays(), firstDayOfWeekIndex: 1);
      expect(cols, hasLength(2));
      // First column: Mon/Tue missing (before range), Wed 06 at row 2.
      expect(cols[0][0], isNull);
      expect(cols[0][1], isNull);
      expect(ymdAt(cols, 0, 2), '2024-03-06');
      expect(ymdAt(cols, 0, 6), '2024-03-10'); // Sunday
      // Second column: Mon 11 at row 0, Fri 15 at row 4, Sat/Sun trailing null.
      expect(ymdAt(cols, 1, 0), '2024-03-11');
      expect(ymdAt(cols, 1, 4), '2024-03-15');
      expect(cols[1][5], isNull);
      expect(cols[1][6], isNull);
    });

    test('Sunday-first realigns the column boundaries', () {
      final cols = groupIntoWeekColumns(tenDays(), firstDayOfWeekIndex: 0);
      expect(cols, hasLength(2));
      // Sunday-first: Wed 06 sits at row 3; the new week starts on Sun 10.
      expect(ymdAt(cols, 0, 3), '2024-03-06');
      expect(ymdAt(cols, 1, 0), '2024-03-10'); // Sunday begins the column
      expect(ymdAt(cols, 1, 1), '2024-03-11');
    });

    test('Saturday-first realigns the column boundaries', () {
      final cols = groupIntoWeekColumns(tenDays(), firstDayOfWeekIndex: 6);
      expect(cols, hasLength(2));
      // Saturday-first: the new week starts on Sat 09.
      expect(ymdAt(cols, 0, 4), '2024-03-06');
      expect(ymdAt(cols, 1, 0), '2024-03-09'); // Saturday begins the column
      expect(ymdAt(cols, 1, 6), '2024-03-15');
    });

    test('a single day yields one column with one filled slot', () {
      final cols = groupIntoWeekColumns(
        [
          const HeatmapDay(
            ymd: '2024-03-13',
            successCount: 1,
            activeCount: 1,
            isToday: false,
          ),
        ],
        firstDayOfWeekIndex: 1,
      );
      expect(cols, hasLength(1));
      // 2024-03-13 is a Wednesday → row 2 (Monday-first).
      expect(ymdAt(cols, 0, 2), '2024-03-13');
      expect(cols[0].whereType<HeatmapDay>(), hasLength(1));
    });

    test('an exact Mon→Sun week fills a single column with no nulls', () {
      final week = buildHeatmapDays(
        completions: const [],
        habitDefinitions: [_habit(id: 'h1', activeFrom: DateTime(2024))],
        rangeStartYmd: '2024-03-11',
        rangeEndYmd: '2024-03-17',
        selectedCategoryIds: const {},
        todayYmd: '2024-03-15',
      );
      final cols = groupIntoWeekColumns(week, firstDayOfWeekIndex: 1);
      expect(cols, hasLength(1));
      expect(cols[0].whereType<HeatmapDay>(), hasLength(7));
    });

    test('leading null count matches leadingBlankDayCount', () {
      // 2024-03-01 is a Friday → 4 leading blanks Monday-first.
      final firstWeek = buildHeatmapDays(
        completions: const [],
        habitDefinitions: [_habit(id: 'h1', activeFrom: DateTime(2024))],
        rangeStartYmd: '2024-03-01',
        rangeEndYmd: '2024-03-07',
        selectedCategoryIds: const {},
        todayYmd: '2024-03-01',
      );
      final cols = groupIntoWeekColumns(firstWeek, firstDayOfWeekIndex: 1);
      final blanks = leadingBlankDayCount(
        year: 2024,
        month: 3,
        firstDayOfWeekIndex: 1,
      );
      expect(blanks, 4);
      for (var row = 0; row < blanks; row++) {
        expect(cols[0][row], isNull);
      }
      expect(ymdAt(cols, 0, blanks), '2024-03-01');
    });
  });

  group('currentStreaksByHabit', () {
    const today = '2026-06-17';
    final habit = _habit(id: 'h1', activeFrom: DateTime(2024));

    Map<String, int> streaks(List<JournalEntity> completions) =>
        currentStreaksByHabit(
          completions: completions,
          habitDefinitions: [habit],
          todayYmd: today,
        );

    test('counts consecutive kept days ending today', () {
      final result = streaks([
        _completion(habitId: 'h1', date: DateTime(2026, 6, 15)),
        _completion(habitId: 'h1', date: DateTime(2026, 6, 16)),
        _completion(habitId: 'h1', date: DateTime(2026, 6, 17)),
      ]);
      expect(result['h1'], 3);
    });

    test('counts from yesterday when today is not recorded yet', () {
      final result = streaks([
        _completion(habitId: 'h1', date: DateTime(2026, 6, 15)),
        _completion(habitId: 'h1', date: DateTime(2026, 6, 16)),
      ]);
      expect(result['h1'], 2);
    });

    test('a gap ends the streak', () {
      final result = streaks([
        _completion(habitId: 'h1', date: DateTime(2026, 6, 14)),
        // 6-15 missing
        _completion(habitId: 'h1', date: DateTime(2026, 6, 16)),
        _completion(habitId: 'h1', date: DateTime(2026, 6, 17)),
      ]);
      expect(result['h1'], 2);
    });

    test('a skip keeps the streak, a fail does not extend it', () {
      final result = streaks([
        _completion(
          habitId: 'h1',
          date: DateTime(2026, 6, 16),
          type: HabitCompletionType.skip,
        ),
        _completion(
          habitId: 'h1',
          date: DateTime(2026, 6, 17),
          type: HabitCompletionType.fail,
        ),
      ]);
      // Today is a fail (not kept) → fall back to yesterday's skip → 1.
      expect(result['h1'], 1);
    });

    test('no completions → zero', () {
      expect(streaks([])['h1'], 0);
    });

    test('habits are independent and unknown ids are ignored', () {
      final result = currentStreaksByHabit(
        completions: [
          _completion(habitId: 'h1', date: DateTime(2026, 6, 17)),
          _completion(habitId: 'other', date: DateTime(2026, 6, 17)),
        ],
        habitDefinitions: [
          habit,
          _habit(id: 'h2', activeFrom: DateTime(2024)),
        ],
        todayYmd: today,
      );
      expect(result['h1'], 1);
      expect(result['h2'], 0);
      expect(result.containsKey('other'), isFalse);
    });
  });

  group('HabitHeatmapData', () {
    test('empty() is the loading placeholder', () {
      final data = HabitHeatmapData.empty();
      expect(data.days, isEmpty);
      expect(data.hasHabits, isFalse);
      expect(data.isLoading, isTrue);
      expect(data.streaksByHabit, isEmpty);
    });

    test('copyWith replaces only the given fields', () {
      final base = HabitHeatmapData.empty();
      const day = HeatmapDay(
        ymd: '2024-03-15',
        successCount: 1,
        activeCount: 1,
        isToday: true,
      );
      final next = base.copyWith(
        days: [day],
        hasHabits: true,
        isLoading: false,
        streaksByHabit: {'h1': 5},
      );
      expect(next.days, [day]);
      expect(next.hasHabits, isTrue);
      expect(next.isLoading, isFalse);
      expect(next.streaksByHabit, {'h1': 5});
      // Unchanged copy keeps prior values.
      expect(next.copyWith().streaksByHabit, {'h1': 5});
    });

    test('value equality by fields', () {
      expect(HabitHeatmapData.empty(), HabitHeatmapData.empty());
    });
  });
}
