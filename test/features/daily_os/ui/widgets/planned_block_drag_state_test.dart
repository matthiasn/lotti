import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/features/daily_os/ui/widgets/planned_block_drag_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testDate = DateTime(2026, 1, 15);

  PlannedBlock createTestBlock({
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
  }) {
    return PlannedBlock(
      id: 'test-block-id',
      categoryId: 'test-category',
      startTime: testDate.add(Duration(hours: startHour, minutes: startMinute)),
      endTime: testDate.add(Duration(hours: endHour, minutes: endMinute)),
    );
  }

  group('PlannedBlockDragMode', () {
    test('has all expected values', () {
      expect(
        PlannedBlockDragMode.values,
        containsAll([
          PlannedBlockDragMode.none,
          PlannedBlockDragMode.move,
          PlannedBlockDragMode.resizeTop,
          PlannedBlockDragMode.resizeBottom,
        ]),
      );
    });
  });

  group('PlannedBlockDragState', () {
    test('initializes with correct values', () {
      final block = createTestBlock(
        startHour: 9,
        startMinute: 30,
        endHour: 10,
        endMinute: 30,
      );

      final state = PlannedBlockDragState(
        mode: PlannedBlockDragMode.move,
        originalBlock: block,
        currentStartMinutes: 9 * 60 + 30, // 570
        currentEndMinutes: 10 * 60 + 30, // 630
        date: testDate,
      );

      expect(state.mode, equals(PlannedBlockDragMode.move));
      expect(state.originalBlock, equals(block));
      expect(state.currentStartMinutes, equals(570));
      expect(state.currentEndMinutes, equals(630));
      expect(state.date, equals(testDate));
    });

    group('currentDuration', () {
      test('calculates duration correctly', () {
        final block = createTestBlock(
          startHour: 9,
          startMinute: 0,
          endHour: 10,
          endMinute: 0,
        );

        final state = PlannedBlockDragState(
          mode: PlannedBlockDragMode.move,
          originalBlock: block,
          currentStartMinutes: 9 * 60,
          currentEndMinutes: 10 * 60,
          date: testDate,
        );

        expect(state.currentDuration, equals(const Duration(minutes: 60)));
      });

      test('returns updated duration during resize', () {
        final block = createTestBlock(
          startHour: 9,
          startMinute: 0,
          endHour: 10,
          endMinute: 0,
        );

        // Resized to 9:15 - 10:00
        final state = PlannedBlockDragState(
          mode: PlannedBlockDragMode.resizeTop,
          originalBlock: block,
          currentStartMinutes: 9 * 60 + 15,
          currentEndMinutes: 10 * 60,
          date: testDate,
        );

        expect(state.currentDuration, equals(const Duration(minutes: 45)));
      });
    });

    group('startDateTime', () {
      test('converts start minutes to DateTime correctly', () {
        final block = createTestBlock(
          startHour: 9,
          startMinute: 0,
          endHour: 10,
          endMinute: 0,
        );

        final state = PlannedBlockDragState(
          mode: PlannedBlockDragMode.move,
          originalBlock: block,
          currentStartMinutes: 10 * 60 + 30, // Moved to 10:30
          currentEndMinutes: 11 * 60 + 30,
          date: testDate,
        );

        expect(state.startDateTime, equals(DateTime(2026, 1, 15, 10, 30)));
      });

      test('handles midnight correctly', () {
        final block = createTestBlock(
          startHour: 23,
          startMinute: 0,
          endHour: 23,
          endMinute: 30,
        );

        final state = PlannedBlockDragState(
          mode: PlannedBlockDragMode.move,
          originalBlock: block,
          currentStartMinutes: 0, // Midnight
          currentEndMinutes: 30,
          date: testDate,
        );

        expect(state.startDateTime, equals(DateTime(2026, 1, 15)));
      });
    });

    group('endDateTime', () {
      test('converts end minutes to DateTime correctly', () {
        final block = createTestBlock(
          startHour: 9,
          startMinute: 0,
          endHour: 10,
          endMinute: 0,
        );

        final state = PlannedBlockDragState(
          mode: PlannedBlockDragMode.resizeBottom,
          originalBlock: block,
          currentStartMinutes: 9 * 60,
          currentEndMinutes: 11 * 60 + 15, // Extended to 11:15
          date: testDate,
        );

        expect(state.endDateTime, equals(DateTime(2026, 1, 15, 11, 15)));
      });
    });

    group('hasChanged', () {
      test('returns false when position matches original', () {
        final block = createTestBlock(
          startHour: 9,
          startMinute: 30,
          endHour: 10,
          endMinute: 30,
        );

        final state = PlannedBlockDragState(
          mode: PlannedBlockDragMode.move,
          originalBlock: block,
          currentStartMinutes: 9 * 60 + 30,
          currentEndMinutes: 10 * 60 + 30,
          date: testDate,
        );

        expect(state.hasChanged, isFalse);
      });

      test('returns true when start time changed', () {
        final block = createTestBlock(
          startHour: 9,
          startMinute: 30,
          endHour: 10,
          endMinute: 30,
        );

        final state = PlannedBlockDragState(
          mode: PlannedBlockDragMode.move,
          originalBlock: block,
          currentStartMinutes: 10 * 60, // Changed from 9:30 to 10:00
          currentEndMinutes: 11 * 60, // Also moved
          date: testDate,
        );

        expect(state.hasChanged, isTrue);
      });

      test('returns true when end time changed', () {
        final block = createTestBlock(
          startHour: 9,
          startMinute: 0,
          endHour: 10,
          endMinute: 0,
        );

        final state = PlannedBlockDragState(
          mode: PlannedBlockDragMode.resizeBottom,
          originalBlock: block,
          currentStartMinutes: 9 * 60,
          currentEndMinutes: 10 * 60 + 30, // Extended by 30 min
          date: testDate,
        );

        expect(state.hasChanged, isTrue);
      });

      test('returns true when only start time changed by 1 minute', () {
        final block = createTestBlock(
          startHour: 9,
          startMinute: 0,
          endHour: 10,
          endMinute: 0,
        );

        final state = PlannedBlockDragState(
          mode: PlannedBlockDragMode.resizeTop,
          originalBlock: block,
          currentStartMinutes: 9 * 60 + 1, // Changed by just 1 minute
          currentEndMinutes: 10 * 60,
          date: testDate,
        );

        expect(state.hasChanged, isTrue);
      });
    });

    group('copyWith', () {
      test('copies all values when no overrides', () {
        final block = createTestBlock(
          startHour: 9,
          startMinute: 0,
          endHour: 10,
          endMinute: 0,
        );

        final state = PlannedBlockDragState(
          mode: PlannedBlockDragMode.move,
          originalBlock: block,
          currentStartMinutes: 9 * 60,
          currentEndMinutes: 10 * 60,
          date: testDate,
        );

        final copy = state.copyWith();

        expect(copy.mode, equals(state.mode));
        expect(copy.originalBlock, equals(state.originalBlock));
        expect(copy.currentStartMinutes, equals(state.currentStartMinutes));
        expect(copy.currentEndMinutes, equals(state.currentEndMinutes));
        expect(copy.date, equals(state.date));
      });

      test('overrides mode', () {
        final block = createTestBlock(
          startHour: 9,
          startMinute: 0,
          endHour: 10,
          endMinute: 0,
        );

        final state = PlannedBlockDragState(
          mode: PlannedBlockDragMode.move,
          originalBlock: block,
          currentStartMinutes: 9 * 60,
          currentEndMinutes: 10 * 60,
          date: testDate,
        );

        final copy = state.copyWith(mode: PlannedBlockDragMode.resizeTop);

        expect(copy.mode, equals(PlannedBlockDragMode.resizeTop));
        expect(copy.originalBlock, equals(state.originalBlock));
      });

      test('overrides start minutes', () {
        final block = createTestBlock(
          startHour: 9,
          startMinute: 0,
          endHour: 10,
          endMinute: 0,
        );

        final state = PlannedBlockDragState(
          mode: PlannedBlockDragMode.move,
          originalBlock: block,
          currentStartMinutes: 9 * 60,
          currentEndMinutes: 10 * 60,
          date: testDate,
        );

        final copy = state.copyWith(currentStartMinutes: 9 * 60 + 30);

        expect(copy.currentStartMinutes, equals(9 * 60 + 30));
        expect(copy.currentEndMinutes, equals(10 * 60)); // Unchanged
      });

      test('overrides end minutes', () {
        final block = createTestBlock(
          startHour: 9,
          startMinute: 0,
          endHour: 10,
          endMinute: 0,
        );

        final state = PlannedBlockDragState(
          mode: PlannedBlockDragMode.move,
          originalBlock: block,
          currentStartMinutes: 9 * 60,
          currentEndMinutes: 10 * 60,
          date: testDate,
        );

        final copy = state.copyWith(currentEndMinutes: 11 * 60);

        expect(copy.currentStartMinutes, equals(9 * 60)); // Unchanged
        expect(copy.currentEndMinutes, equals(11 * 60));
      });

      test('preserves originalBlock and date', () {
        final block = createTestBlock(
          startHour: 9,
          startMinute: 0,
          endHour: 10,
          endMinute: 0,
        );

        final state = PlannedBlockDragState(
          mode: PlannedBlockDragMode.move,
          originalBlock: block,
          currentStartMinutes: 9 * 60,
          currentEndMinutes: 10 * 60,
          date: testDate,
        );

        final copy = state.copyWith(
          mode: PlannedBlockDragMode.resizeBottom,
          currentStartMinutes: 10 * 60,
          currentEndMinutes: 12 * 60,
        );

        expect(copy.originalBlock, equals(block));
        expect(copy.date, equals(testDate));
      });
    });

    group('equality', () {
      test('equal states are equal', () {
        final block = createTestBlock(
          startHour: 9,
          startMinute: 0,
          endHour: 10,
          endMinute: 0,
        );

        final state1 = PlannedBlockDragState(
          mode: PlannedBlockDragMode.move,
          originalBlock: block,
          currentStartMinutes: 9 * 60,
          currentEndMinutes: 10 * 60,
          date: testDate,
        );

        final state2 = PlannedBlockDragState(
          mode: PlannedBlockDragMode.move,
          originalBlock: block,
          currentStartMinutes: 9 * 60,
          currentEndMinutes: 10 * 60,
          date: testDate,
        );

        expect(state1, equals(state2));
        expect(state1.hashCode, equals(state2.hashCode));
      });

      test('different modes are not equal', () {
        final block = createTestBlock(
          startHour: 9,
          startMinute: 0,
          endHour: 10,
          endMinute: 0,
        );

        final state1 = PlannedBlockDragState(
          mode: PlannedBlockDragMode.move,
          originalBlock: block,
          currentStartMinutes: 9 * 60,
          currentEndMinutes: 10 * 60,
          date: testDate,
        );

        final state2 = PlannedBlockDragState(
          mode: PlannedBlockDragMode.resizeTop,
          originalBlock: block,
          currentStartMinutes: 9 * 60,
          currentEndMinutes: 10 * 60,
          date: testDate,
        );

        expect(state1, isNot(equals(state2)));
      });

      test('different times are not equal', () {
        final block = createTestBlock(
          startHour: 9,
          startMinute: 0,
          endHour: 10,
          endMinute: 0,
        );

        final state1 = PlannedBlockDragState(
          mode: PlannedBlockDragMode.move,
          originalBlock: block,
          currentStartMinutes: 9 * 60,
          currentEndMinutes: 10 * 60,
          date: testDate,
        );

        final state2 = PlannedBlockDragState(
          mode: PlannedBlockDragMode.move,
          originalBlock: block,
          currentStartMinutes: 9 * 60 + 15, // Different start
          currentEndMinutes: 10 * 60 + 15,
          date: testDate,
        );

        expect(state1, isNot(equals(state2)));
      });
    });

    group('toString', () {
      test('returns readable representation', () {
        final block = createTestBlock(
          startHour: 9,
          startMinute: 0,
          endHour: 10,
          endMinute: 0,
        );

        final state = PlannedBlockDragState(
          mode: PlannedBlockDragMode.move,
          originalBlock: block,
          currentStartMinutes: 9 * 60,
          currentEndMinutes: 10 * 60,
          date: testDate,
        );

        expect(
          state.toString(),
          contains('PlannedBlockDragState'),
        );
        expect(state.toString(), contains('move'));
        expect(state.toString(), contains('540')); // 9 * 60
        expect(state.toString(), contains('600')); // 10 * 60
      });
    });
  });

  group('Integration scenarios', () {
    test('move operation: drag block 30 minutes later', () {
      final block = createTestBlock(
        startHour: 9,
        startMinute: 0,
        endHour: 10,
        endMinute: 0,
      );

      // Initial state at drag start
      var state = PlannedBlockDragState(
        mode: PlannedBlockDragMode.move,
        originalBlock: block,
        currentStartMinutes: 9 * 60,
        currentEndMinutes: 10 * 60,
        date: testDate,
      );

      expect(state.hasChanged, isFalse);

      // Update during drag: move 30 minutes later
      state = state.copyWith(
        currentStartMinutes: 9 * 60 + 30,
        currentEndMinutes: 10 * 60 + 30,
      );

      expect(state.hasChanged, isTrue);
      expect(state.currentDuration, equals(const Duration(minutes: 60)));
      expect(state.startDateTime, equals(DateTime(2026, 1, 15, 9, 30)));
      expect(state.endDateTime, equals(DateTime(2026, 1, 15, 10, 30)));
    });

    test('resize top: shrink block by 15 minutes', () {
      final block = createTestBlock(
        startHour: 9,
        startMinute: 0,
        endHour: 10,
        endMinute: 0,
      );

      var state = PlannedBlockDragState(
        mode: PlannedBlockDragMode.resizeTop,
        originalBlock: block,
        currentStartMinutes: 9 * 60,
        currentEndMinutes: 10 * 60,
        date: testDate,
      );

      // Drag top down 15 minutes
      state = state.copyWith(currentStartMinutes: 9 * 60 + 15);

      expect(state.hasChanged, isTrue);
      expect(state.currentDuration, equals(const Duration(minutes: 45)));
      expect(state.startDateTime, equals(DateTime(2026, 1, 15, 9, 15)));
      expect(state.endDateTime, equals(DateTime(2026, 1, 15, 10)));
    });

    test('resize bottom: extend block by 30 minutes', () {
      final block = createTestBlock(
        startHour: 9,
        startMinute: 0,
        endHour: 10,
        endMinute: 0,
      );

      var state = PlannedBlockDragState(
        mode: PlannedBlockDragMode.resizeBottom,
        originalBlock: block,
        currentStartMinutes: 9 * 60,
        currentEndMinutes: 10 * 60,
        date: testDate,
      );

      // Drag bottom down 30 minutes
      state = state.copyWith(currentEndMinutes: 10 * 60 + 30);

      expect(state.hasChanged, isTrue);
      expect(state.currentDuration, equals(const Duration(minutes: 90)));
      expect(state.startDateTime, equals(DateTime(2026, 1, 15, 9)));
      expect(state.endDateTime, equals(DateTime(2026, 1, 15, 10, 30)));
    });

    test('cancelled drag: hasChanged remains false', () {
      final block = createTestBlock(
        startHour: 9,
        startMinute: 0,
        endHour: 10,
        endMinute: 0,
      );

      final state = PlannedBlockDragState(
        mode: PlannedBlockDragMode.move,
        originalBlock: block,
        currentStartMinutes: 9 * 60,
        currentEndMinutes: 10 * 60,
        date: testDate,
      );

      // User starts drag but cancels without moving
      expect(state.hasChanged, isFalse);
    });
  });
}
