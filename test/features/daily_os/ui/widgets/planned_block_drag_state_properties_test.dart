import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
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

  // ---------------------------------------------------------------------------
  // Glados properties: copyWith idempotence and the hasChanged contract over
  // generated (start, end, delta) minute triples.
  // ---------------------------------------------------------------------------
  group('PlannedBlockDragState — properties', () {
    PlannedBlockDragState makeState({
      required int startMinutes,
      required int endMinutes,
      int currentStart = -1,
      int currentEnd = -1,
    }) {
      return PlannedBlockDragState(
        mode: PlannedBlockDragMode.move,
        originalBlock: createTestBlock(
          startHour: startMinutes ~/ 60,
          startMinute: startMinutes % 60,
          endHour: endMinutes ~/ 60,
          endMinute: endMinutes % 60,
        ),
        currentStartMinutes: currentStart >= 0 ? currentStart : startMinutes,
        currentEndMinutes: currentEnd >= 0 ? currentEnd : endMinutes,
        date: testDate,
      );
    }

    glados.Glados2(
      glados.IntAnys(glados.any).intInRange(0, 1380),
      glados.IntAnys(glados.any).intInRange(1, 60),
      glados.ExploreConfig(numRuns: 120),
    ).test('copyWith() with no arguments is the identity', (
      startMinutes,
      duration,
    ) {
      final state = makeState(
        startMinutes: startMinutes,
        endMinutes: startMinutes + duration,
      );
      expect(state.copyWith(), state);
      expect(state.copyWith().hashCode, state.hashCode);
    }, tags: 'glados');

    glados.Glados3(
      glados.IntAnys(glados.any).intInRange(0, 1380),
      glados.IntAnys(glados.any).intInRange(1, 60),
      glados.IntAnys(glados.any).intInRange(-120, 121),
      glados.ExploreConfig(numRuns: 120),
    ).test('hasChanged iff current start/end differ from the original', (
      startMinutes,
      duration,
      delta,
    ) {
      final endMinutes = startMinutes + duration;
      // Keep the shifted positions inside the day window — the state's
      // minute domain is [0, 1440).
      final d = delta.clamp(-startMinutes, 1439 - endMinutes);

      final moved = makeState(
        startMinutes: startMinutes,
        endMinutes: endMinutes,
        currentStart: startMinutes + d,
        currentEnd: endMinutes + d,
      );
      expect(
        moved.hasChanged,
        d != 0,
        reason: 'start=$startMinutes dur=$duration delta=$d',
      );

      // Resize-only change: same start, shifted end.
      final resized = makeState(
        startMinutes: startMinutes,
        endMinutes: endMinutes,
        currentStart: startMinutes,
        currentEnd: endMinutes + d,
      );
      expect(resized.hasChanged, d != 0);
    }, tags: 'glados');
  });
}
