import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/daily_os/state/timeline_data_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testDate = DateTime(2026, 1, 15);

  JournalEntity createTestEntry({
    required String id,
    required String? categoryId,
    required DateTime dateFrom,
    required DateTime dateTo,
  }) {
    return JournalEntity.journalEntry(
      meta: Metadata(
        id: id,
        createdAt: dateFrom,
        updatedAt: dateFrom,
        dateFrom: dateFrom,
        dateTo: dateTo,
        categoryId: categoryId,
      ),
    );
  }

  group('PlannedTimeSlot', () {
    test('calculates duration correctly', () {
      final slot = PlannedTimeSlot(
        startTime: testDate.add(const Duration(hours: 9)),
        endTime: testDate.add(const Duration(hours: 11, minutes: 30)),
        categoryId: 'cat-work',
        block: PlannedBlock(
          id: 'block-1',
          categoryId: 'cat-work',
          startTime: testDate.add(const Duration(hours: 9)),
          endTime: testDate.add(const Duration(hours: 11, minutes: 30)),
        ),
      );

      expect(slot.duration, equals(const Duration(hours: 2, minutes: 30)));
    });

    test('exposes category id', () {
      final slot = PlannedTimeSlot(
        startTime: testDate.add(const Duration(hours: 9)),
        endTime: testDate.add(const Duration(hours: 10)),
        categoryId: 'cat-work',
        block: PlannedBlock(
          id: 'block-1',
          categoryId: 'cat-work',
          startTime: testDate.add(const Duration(hours: 9)),
          endTime: testDate.add(const Duration(hours: 10)),
        ),
      );

      expect(slot.categoryId, equals('cat-work'));
    });

    test('exposes block', () {
      final block = PlannedBlock(
        id: 'block-1',
        categoryId: 'cat-work',
        startTime: testDate.add(const Duration(hours: 9)),
        endTime: testDate.add(const Duration(hours: 10)),
      );
      final slot = PlannedTimeSlot(
        startTime: block.startTime,
        endTime: block.endTime,
        categoryId: block.categoryId,
        block: block,
      );

      expect(slot.block, equals(block));
    });
  });

  group('ActualTimeSlot', () {
    test('calculates duration correctly', () {
      final entry = createTestEntry(
        id: 'entry-1',
        categoryId: 'cat-work',
        dateFrom: testDate.add(const Duration(hours: 9)),
        dateTo: testDate.add(const Duration(hours: 10, minutes: 45)),
      );
      final slot = ActualTimeSlot(
        startTime: entry.meta.dateFrom,
        endTime: entry.meta.dateTo,
        categoryId: entry.meta.categoryId,
        entry: entry,
      );

      expect(slot.duration, equals(const Duration(hours: 1, minutes: 45)));
    });

    test('exposes entry', () {
      final entry = createTestEntry(
        id: 'entry-1',
        categoryId: 'cat-work',
        dateFrom: testDate.add(const Duration(hours: 9)),
        dateTo: testDate.add(const Duration(hours: 10)),
      );
      final slot = ActualTimeSlot(
        startTime: entry.meta.dateFrom,
        endTime: entry.meta.dateTo,
        categoryId: entry.meta.categoryId,
        entry: entry,
      );

      expect(slot.entry.meta.id, equals('entry-1'));
    });

    test('can have linked parent', () {
      final parentEntry = createTestEntry(
        id: 'task-1',
        categoryId: 'cat-work',
        dateFrom: testDate,
        dateTo: testDate.add(const Duration(days: 1)),
      );
      final childEntry = createTestEntry(
        id: 'time-entry-1',
        categoryId: null,
        dateFrom: testDate.add(const Duration(hours: 9)),
        dateTo: testDate.add(const Duration(hours: 10)),
      );
      final slot = ActualTimeSlot(
        startTime: childEntry.meta.dateFrom,
        endTime: childEntry.meta.dateTo,
        categoryId: parentEntry.meta.categoryId, // from parent
        entry: childEntry,
        linkedFrom: parentEntry,
      );

      expect(slot.linkedFrom, isNotNull);
      expect(slot.linkedFrom!.meta.id, equals('task-1'));
      expect(slot.categoryId, equals('cat-work'));
    });

    test('linkedFrom defaults to null', () {
      final entry = createTestEntry(
        id: 'entry-1',
        categoryId: 'cat-work',
        dateFrom: testDate.add(const Duration(hours: 9)),
        dateTo: testDate.add(const Duration(hours: 10)),
      );
      final slot = ActualTimeSlot(
        startTime: entry.meta.dateFrom,
        endTime: entry.meta.dateTo,
        categoryId: entry.meta.categoryId,
        entry: entry,
      );

      expect(slot.linkedFrom, isNull);
    });
  });

  group('DailyTimelineData', () {
    test('returns empty allEntries when no actual slots', () {
      final data = DailyTimelineData(
        date: testDate,
        plannedSlots: [],
        actualSlots: [],
        dayStartHour: 8,
        dayEndHour: 18,
      );

      expect(data.allEntries, isEmpty);
    });

    test('allEntries returns entries from actual slots', () {
      final entry1 = createTestEntry(
        id: 'entry-1',
        categoryId: 'cat-work',
        dateFrom: testDate.add(const Duration(hours: 9)),
        dateTo: testDate.add(const Duration(hours: 10)),
      );
      final entry2 = createTestEntry(
        id: 'entry-2',
        categoryId: 'cat-personal',
        dateFrom: testDate.add(const Duration(hours: 14)),
        dateTo: testDate.add(const Duration(hours: 15)),
      );

      final data = DailyTimelineData(
        date: testDate,
        plannedSlots: [],
        actualSlots: [
          ActualTimeSlot(
            startTime: entry1.meta.dateFrom,
            endTime: entry1.meta.dateTo,
            categoryId: entry1.meta.categoryId,
            entry: entry1,
          ),
          ActualTimeSlot(
            startTime: entry2.meta.dateFrom,
            endTime: entry2.meta.dateTo,
            categoryId: entry2.meta.categoryId,
            entry: entry2,
          ),
        ],
        dayStartHour: 8,
        dayEndHour: 18,
      );

      expect(data.allEntries.length, equals(2));
      expect(data.allEntries[0].meta.id, equals('entry-1'));
      expect(data.allEntries[1].meta.id, equals('entry-2'));
    });

    test('totalPlannedDuration sums planned slot durations', () {
      final data = DailyTimelineData(
        date: testDate,
        plannedSlots: [
          PlannedTimeSlot(
            startTime: testDate.add(const Duration(hours: 9)),
            endTime: testDate.add(const Duration(hours: 11)), // 2 hours
            categoryId: 'cat-work',
            block: PlannedBlock(
              id: 'block-1',
              categoryId: 'cat-work',
              startTime: testDate.add(const Duration(hours: 9)),
              endTime: testDate.add(const Duration(hours: 11)),
            ),
          ),
          PlannedTimeSlot(
            startTime: testDate.add(const Duration(hours: 14)),
            endTime:
                testDate.add(const Duration(hours: 15, minutes: 30)), // 1.5h
            categoryId: 'cat-personal',
            block: PlannedBlock(
              id: 'block-2',
              categoryId: 'cat-personal',
              startTime: testDate.add(const Duration(hours: 14)),
              endTime: testDate.add(const Duration(hours: 15, minutes: 30)),
            ),
          ),
        ],
        actualSlots: [],
        dayStartHour: 8,
        dayEndHour: 18,
      );

      expect(
        data.totalPlannedDuration,
        equals(const Duration(hours: 3, minutes: 30)),
      );
    });

    test('totalPlannedDuration returns zero when no planned slots', () {
      final data = DailyTimelineData(
        date: testDate,
        plannedSlots: [],
        actualSlots: [],
        dayStartHour: 8,
        dayEndHour: 18,
      );

      expect(data.totalPlannedDuration, equals(Duration.zero));
    });

    test('totalActualDuration sums actual slot durations', () {
      final entry1 = createTestEntry(
        id: 'entry-1',
        categoryId: 'cat-work',
        dateFrom: testDate.add(const Duration(hours: 9)),
        dateTo:
            testDate.add(const Duration(hours: 10, minutes: 30)), // 1.5 hours
      );
      final entry2 = createTestEntry(
        id: 'entry-2',
        categoryId: 'cat-personal',
        dateFrom: testDate.add(const Duration(hours: 14)),
        dateTo: testDate.add(const Duration(hours: 15)), // 1 hour
      );

      final data = DailyTimelineData(
        date: testDate,
        plannedSlots: [],
        actualSlots: [
          ActualTimeSlot(
            startTime: entry1.meta.dateFrom,
            endTime: entry1.meta.dateTo,
            categoryId: entry1.meta.categoryId,
            entry: entry1,
          ),
          ActualTimeSlot(
            startTime: entry2.meta.dateFrom,
            endTime: entry2.meta.dateTo,
            categoryId: entry2.meta.categoryId,
            entry: entry2,
          ),
        ],
        dayStartHour: 8,
        dayEndHour: 18,
      );

      expect(
        data.totalActualDuration,
        equals(const Duration(hours: 2, minutes: 30)),
      );
    });

    test('totalActualDuration returns zero when no actual slots', () {
      final data = DailyTimelineData(
        date: testDate,
        plannedSlots: [],
        actualSlots: [],
        dayStartHour: 8,
        dayEndHour: 18,
      );

      expect(data.totalActualDuration, equals(Duration.zero));
    });

    test('exposes date', () {
      final data = DailyTimelineData(
        date: testDate,
        plannedSlots: [],
        actualSlots: [],
        dayStartHour: 8,
        dayEndHour: 18,
      );

      expect(data.date, equals(testDate));
    });

    test('exposes day bounds', () {
      final data = DailyTimelineData(
        date: testDate,
        plannedSlots: [],
        actualSlots: [],
        dayStartHour: 7,
        dayEndHour: 22,
      );

      expect(data.dayStartHour, equals(7));
      expect(data.dayEndHour, equals(22));
    });
  });
}
