import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/logic/habits/habit_completion_resolution.dart';

const List<HabitCompletionType> _completionTypes = [
  HabitCompletionType.success,
  HabitCompletionType.skip,
  HabitCompletionType.fail,
];

HabitCompletionEntry _completion({
  required String id,
  required String habitId,
  required DateTime day,
  required DateTime writtenAt,
  required HabitCompletionType completionType,
  DateTime? createdAt,
  DateTime? updatedAt,
  DateTime? dateTo,
}) {
  final effectiveDateTo = dateTo ?? day;
  return HabitCompletionEntry(
    meta: Metadata(
      id: id,
      createdAt: createdAt ?? writtenAt,
      updatedAt: updatedAt ?? writtenAt,
      dateFrom: day,
      dateTo: effectiveDateTo,
      private: false,
    ),
    data: HabitCompletionData(
      dateFrom: day,
      dateTo: effectiveDateTo,
      habitId: habitId,
      completionType: completionType,
    ),
  );
}

class _GeneratedHabitCompletionScenario {
  const _GeneratedHabitCompletionScenario({
    required this.habitCountSeed,
    required this.dayCountSeed,
    required this.writeCountSeed,
    required this.habitSeed,
    required this.daySeed,
    required this.statusSeed,
    required this.orderSeed,
  });

  final int habitCountSeed;
  final int dayCountSeed;
  final int writeCountSeed;
  final int habitSeed;
  final int daySeed;
  final int statusSeed;
  final int orderSeed;

  int get habitCount => (habitCountSeed % 4) + 1;
  int get dayCount => (dayCountSeed % 5) + 1;
  int get writeCount => (writeCountSeed % 24) + 1;

  List<HabitCompletionEntry> get chronologicalEntries {
    final baseDay = DateTime(2024, 3);
    final baseWrittenAt = DateTime(2024, 4, 1, 8);

    return List.generate(writeCount, (index) {
      final habitIndex = (habitSeed + index * 3) % habitCount;
      final dayIndex = (daySeed + index * 5) % dayCount;
      final statusIndex = (statusSeed + index * 7) % _completionTypes.length;
      final day = baseDay.add(Duration(days: dayIndex, hours: habitIndex));
      final writtenAt = baseWrittenAt.add(Duration(minutes: index));

      return _completion(
        id: 'completion-$index-h$habitIndex-d$dayIndex',
        habitId: 'habit-$habitIndex',
        day: day,
        writtenAt: writtenAt,
        completionType: _completionTypes[statusIndex],
      );
    });
  }

  List<HabitCompletionEntry> get shuffledEntries {
    final entries = chronologicalEntries.toList();

    for (var i = 0; i < entries.length; i++) {
      final swapWith = (orderSeed + i * 11) % entries.length;
      final current = entries[i];
      entries[i] = entries[swapWith];
      entries[swapWith] = current;
    }

    return orderSeed.isEven ? entries : entries.reversed.toList();
  }

  Map<String, HabitCompletionEntry> get expectedLatestByKey {
    final expected = <String, HabitCompletionEntry>{};

    for (final entry in chronologicalEntries) {
      expected[habitCompletionDayKey(entry)] = entry;
    }

    return expected;
  }

  @override
  String toString() {
    return '_GeneratedHabitCompletionScenario('
        'habitCountSeed: $habitCountSeed, '
        'dayCountSeed: $dayCountSeed, '
        'writeCountSeed: $writeCountSeed, '
        'habitSeed: $habitSeed, '
        'daySeed: $daySeed, '
        'statusSeed: $statusSeed, '
        'orderSeed: $orderSeed)';
  }
}

extension _AnyGeneratedHabitCompletionScenario on glados.Any {
  glados.Generator<_GeneratedHabitCompletionScenario>
  get habitCompletionScenario => glados.CombinableAny(this).combine7(
    glados.IntAnys(this).intInRange(0, 10000),
    glados.IntAnys(this).intInRange(0, 10000),
    glados.IntAnys(this).intInRange(0, 10000),
    glados.IntAnys(this).intInRange(0, 10000),
    glados.IntAnys(this).intInRange(0, 10000),
    glados.IntAnys(this).intInRange(0, 10000),
    glados.IntAnys(this).intInRange(0, 10000),
    (
      int habitCountSeed,
      int dayCountSeed,
      int writeCountSeed,
      int habitSeed,
      int daySeed,
      int statusSeed,
      int orderSeed,
    ) => _GeneratedHabitCompletionScenario(
      habitCountSeed: habitCountSeed,
      dayCountSeed: dayCountSeed,
      writeCountSeed: writeCountSeed,
      habitSeed: habitSeed,
      daySeed: daySeed,
      statusSeed: statusSeed,
      orderSeed: orderSeed,
    ),
  );
}

void main() {
  group('latestHabitCompletionsByDay', () {
    test('keeps the newest write for the same habit and day', () {
      final day = DateTime(2024, 3, 15, 21);
      final older = _completion(
        id: 'older-success',
        habitId: 'habit-1',
        day: day,
        writtenAt: DateTime(2024, 3, 15, 22),
        completionType: HabitCompletionType.success,
      );
      final newer = _completion(
        id: 'newer-fail',
        habitId: 'habit-1',
        day: day,
        writtenAt: DateTime(2024, 3, 15, 23),
        completionType: HabitCompletionType.fail,
      );

      final result = latestHabitCompletionsByDay([newer, older]);

      expect(result, hasLength(1));
      expect(result.single.meta.id, 'newer-fail');
      expect(result.single.data.completionType, HabitCompletionType.fail);
    });

    test('keeps separate habits and days independent', () {
      final firstDay = DateTime(2024, 3, 15, 21);
      final secondDay = DateTime(2024, 3, 16, 21);

      final result = latestHabitCompletionsByDay([
        _completion(
          id: 'habit-1-day-1-older',
          habitId: 'habit-1',
          day: firstDay,
          writtenAt: DateTime(2024, 3, 15, 22),
          completionType: HabitCompletionType.success,
        ),
        _completion(
          id: 'habit-1-day-1-newer',
          habitId: 'habit-1',
          day: firstDay,
          writtenAt: DateTime(2024, 3, 15, 23),
          completionType: HabitCompletionType.skip,
        ),
        _completion(
          id: 'habit-1-day-2',
          habitId: 'habit-1',
          day: secondDay,
          writtenAt: DateTime(2024, 3, 16, 22),
          completionType: HabitCompletionType.fail,
        ),
        _completion(
          id: 'habit-2-day-1',
          habitId: 'habit-2',
          day: firstDay,
          writtenAt: DateTime(2024, 3, 15, 22),
          completionType: HabitCompletionType.success,
        ),
      ]);

      expect(result.map((entry) => entry.meta.id), [
        'habit-1-day-1-newer',
        'habit-2-day-1',
        'habit-1-day-2',
      ]);
    });

    test('uses the id tie-breaker when write timestamps match', () {
      final day = DateTime(2024, 3, 15, 21);
      final writtenAt = DateTime(2024, 3, 15, 22);
      final lowerId = _completion(
        id: 'same-time-a',
        habitId: 'habit-1',
        day: day,
        writtenAt: writtenAt,
        completionType: HabitCompletionType.success,
      );
      final higherId = _completion(
        id: 'same-time-b',
        habitId: 'habit-1',
        day: day,
        writtenAt: writtenAt,
        completionType: HabitCompletionType.fail,
      );

      final result = latestHabitCompletionsByDay([higherId, lowerId]);

      expect(result, hasLength(1));
      expect(result.single.meta.id, 'same-time-b');
      expect(result.single.data.completionType, HabitCompletionType.fail);
    });

    test('uses createdAt when updatedAt timestamps match', () {
      final day = DateTime(2024, 3, 15, 21);
      final updatedAt = DateTime(2024, 3, 15, 23);
      final olderCreatedAt = _completion(
        id: 'created-earlier',
        habitId: 'habit-1',
        day: day,
        writtenAt: updatedAt,
        updatedAt: updatedAt,
        createdAt: DateTime(2024, 3, 15, 21),
        completionType: HabitCompletionType.success,
      );
      final newerCreatedAt = _completion(
        id: 'created-later',
        habitId: 'habit-1',
        day: day,
        writtenAt: updatedAt,
        updatedAt: updatedAt,
        createdAt: DateTime(2024, 3, 15, 22),
        completionType: HabitCompletionType.fail,
      );

      final result = latestHabitCompletionsByDay([
        newerCreatedAt,
        olderCreatedAt,
      ]);

      expect(result.single.meta.id, 'created-later');
      expect(result.single.data.completionType, HabitCompletionType.fail);
    });

    test('uses dateTo when write timestamps match', () {
      final day = DateTime(2024, 3, 15, 21);
      final writtenAt = DateTime(2024, 3, 15, 23);
      final earlierDateTo = _completion(
        id: 'date-to-earlier',
        habitId: 'habit-1',
        day: day,
        writtenAt: writtenAt,
        dateTo: DateTime(2024, 3, 15, 21),
        completionType: HabitCompletionType.success,
      );
      final laterDateTo = _completion(
        id: 'date-to-later',
        habitId: 'habit-1',
        day: day,
        writtenAt: writtenAt,
        dateTo: DateTime(2024, 3, 15, 22),
        completionType: HabitCompletionType.skip,
      );

      final result = latestHabitCompletionsByDay([laterDateTo, earlierDateTo]);

      expect(result.single.meta.id, 'date-to-later');
      expect(result.single.data.completionType, HabitCompletionType.skip);
    });

    test('ignores non-habit journal entities', () {
      final writtenAt = DateTime(2024, 3, 15, 22);
      final nonHabit = JournalEntity.journalEntry(
        meta: Metadata(
          id: 'journal-entry',
          createdAt: writtenAt,
          updatedAt: writtenAt,
          dateFrom: writtenAt,
          dateTo: writtenAt,
        ),
      );

      final result = latestHabitCompletionsByDay([
        nonHabit,
        _completion(
          id: 'habit-entry',
          habitId: 'habit-1',
          day: writtenAt,
          writtenAt: writtenAt,
          completionType: HabitCompletionType.success,
        ),
      ]);

      expect(result, hasLength(1));
      expect(result.single.meta.id, 'habit-entry');
    });

    glados.Glados(
      glados.any.habitCompletionScenario,
      glados.ExploreConfig(numRuns: 160),
    ).test('returns the latest write for every generated habit/day', (
      scenario,
    ) {
      final result = latestHabitCompletionsByDay(scenario.shuffledEntries);
      final actualByKey = {
        for (final entry in result) habitCompletionDayKey(entry): entry,
      };
      final expectedByKey = scenario.expectedLatestByKey;

      expect(
        actualByKey.keys,
        unorderedEquals(expectedByKey.keys),
        reason: '$scenario',
      );

      for (final key in expectedByKey.keys) {
        expect(
          actualByKey[key]?.meta.id,
          expectedByKey[key]?.meta.id,
          reason: '$scenario key=$key',
        );
        expect(
          actualByKey[key]?.data.completionType,
          expectedByKey[key]?.data.completionType,
          reason: '$scenario key=$key',
        );
      }
    }, tags: 'glados');
  });
}
