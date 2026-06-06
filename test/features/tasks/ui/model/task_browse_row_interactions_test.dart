import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/tasks/ui/model/task_browse_row_interactions.dart';

/// Glados generators for row-interaction property tests.
extension _AnyRowInteractionId on glados.Any {
  /// Generates short alphanumeric IDs (or empty string to model absent IDs).
  glados.Generator<String> get taskId => glados.any.letterOrDigits;
}

void main() {
  // ---------------------------------------------------------------------------
  // taskRowInteractionPriority — worked examples
  // ---------------------------------------------------------------------------

  group('taskRowInteractionPriority', () {
    test('returns 2 when taskId == selectedTaskId', () {
      expect(
        taskRowInteractionPriority(
          taskId: 'task-1',
          selectedTaskId: 'task-1',
          hoveredTaskId: null,
        ),
        equals(2),
      );
    });

    test('returns 2 when taskId == selectedTaskId even if also hovered', () {
      expect(
        taskRowInteractionPriority(
          taskId: 'task-1',
          selectedTaskId: 'task-1',
          hoveredTaskId: 'task-1',
        ),
        equals(2),
      );
    });

    test('returns 1 when taskId == hoveredTaskId but not selected', () {
      expect(
        taskRowInteractionPriority(
          taskId: 'task-2',
          selectedTaskId: 'task-1',
          hoveredTaskId: 'task-2',
        ),
        equals(1),
      );
    });

    test('returns 0 when taskId matches neither', () {
      expect(
        taskRowInteractionPriority(
          taskId: 'task-3',
          selectedTaskId: 'task-1',
          hoveredTaskId: 'task-2',
        ),
        equals(0),
      );
    });

    test('returns 0 when both selectedTaskId and hoveredTaskId are null', () {
      expect(
        taskRowInteractionPriority(
          taskId: 'task-1',
          selectedTaskId: null,
          hoveredTaskId: null,
        ),
        equals(0),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // taskRowInteractionPriority — Glados properties
  // ---------------------------------------------------------------------------

  group('taskRowInteractionPriority — properties', () {
    glados.Glados3(
      glados.any.taskId,
      glados.any.taskId,
      glados.any.taskId,
      glados.ExploreConfig(numRuns: 120),
    ).test('priority is 2 iff taskId equals selectedTaskId', (
      taskId,
      selectedId,
      hoveredId,
    ) {
      final priority = taskRowInteractionPriority(
        taskId: taskId,
        selectedTaskId: selectedId.isEmpty ? null : selectedId,
        hoveredTaskId: hoveredId.isEmpty ? null : hoveredId,
      );
      if (taskId == selectedId && selectedId.isNotEmpty) {
        expect(priority, equals(2));
      } else {
        expect(priority, isNot(equals(2)));
      }
    }, tags: 'glados');

    glados.Glados2(
      glados.any.taskId,
      glados.any.taskId,
      glados.ExploreConfig(numRuns: 120),
    ).test('result is always 0, 1, or 2', (taskId, otherId) {
      final priority = taskRowInteractionPriority(
        taskId: taskId,
        selectedTaskId: otherId.isEmpty ? null : otherId,
        hoveredTaskId: null,
      );
      expect(priority, inInclusiveRange(0, 2));
    }, tags: 'glados');
  });

  // ---------------------------------------------------------------------------
  // buildTaskBrowseRowInteraction — worked examples
  // ---------------------------------------------------------------------------

  group('buildTaskBrowseRowInteraction', () {
    test('isolated unselected row: no overlaps, no divider', () {
      final result = buildTaskBrowseRowInteraction(
        taskId: 'task-1',
        previousTaskIdInSection: null,
        nextTaskIdInSection: null,
      );
      expect(result.topOverlap, equals(0));
      expect(result.bottomOverlap, equals(0));
      expect(result.showDividerBelow, isFalse);
    });

    test(
      'selected row with neighbor both sides: has upper and lower overlap',
      () {
        final result = buildTaskBrowseRowInteraction(
          taskId: 'task-2',
          previousTaskIdInSection: 'task-1',
          nextTaskIdInSection: 'task-3',
          selectedTaskId: 'task-2',
        );
        // current priority = 2; previous priority = 0; next priority = 0.
        // hasUpperInteraction = true (previous exists, current > 0).
        // hasLowerInteraction = true (next exists, current > 0).
        // topOverlap: current(2) > previous(0) → overlap value.
        expect(result.topOverlap, greaterThan(0));
        // bottomOverlap: current(2) >= next(0) → overlap value.
        expect(result.bottomOverlap, greaterThan(0));
      },
    );

    test(
      'hovered row with neighbor both sides: has upper and lower overlap',
      () {
        final result = buildTaskBrowseRowInteraction(
          taskId: 'task-2',
          previousTaskIdInSection: 'task-1',
          nextTaskIdInSection: 'task-3',
          hoveredTaskId: 'task-2',
        );
        expect(result.topOverlap, greaterThan(0));
        expect(result.bottomOverlap, greaterThan(0));
      },
    );

    test('two adjacent unselected rows show divider below first', () {
      final result = buildTaskBrowseRowInteraction(
        taskId: 'task-1',
        previousTaskIdInSection: null,
        nextTaskIdInSection: 'task-2',
      );
      // Both current and next have priority 0 → showDividerBelow = true.
      expect(result.showDividerBelow, isTrue);
    });

    test('no divider when next is selected', () {
      final result = buildTaskBrowseRowInteraction(
        taskId: 'task-1',
        previousTaskIdInSection: null,
        nextTaskIdInSection: 'task-2',
        selectedTaskId: 'task-2',
      );
      // next has priority 2 → showDividerBelow = false.
      expect(result.showDividerBelow, isFalse);
    });

    test('no divider when current is selected', () {
      final result = buildTaskBrowseRowInteraction(
        taskId: 'task-1',
        previousTaskIdInSection: null,
        nextTaskIdInSection: 'task-2',
        selectedTaskId: 'task-1',
      );
      expect(result.showDividerBelow, isFalse);
    });

    test('no divider when next task is null', () {
      final result = buildTaskBrowseRowInteraction(
        taskId: 'task-1',
        previousTaskIdInSection: 'task-0',
        nextTaskIdInSection: null,
      );
      expect(result.showDividerBelow, isFalse);
    });

    test('topOverlap is 0 when previous neighbor is null', () {
      final result = buildTaskBrowseRowInteraction(
        taskId: 'task-1',
        previousTaskIdInSection: null,
        nextTaskIdInSection: 'task-2',
        selectedTaskId: 'task-1',
      );
      // hasUpperInteraction requires previousTaskIdInSection != null.
      expect(result.topOverlap, equals(0));
    });

    test('custom overlap value is respected', () {
      const customOverlap = 4.0;
      final result = buildTaskBrowseRowInteraction(
        taskId: 'task-1',
        previousTaskIdInSection: 'task-0',
        nextTaskIdInSection: 'task-2',
        selectedTaskId: 'task-1',
        overlap: customOverlap,
      );
      // current(2) > previous(0): topOverlap = customOverlap
      expect(result.topOverlap, equals(customOverlap));
      // current(2) >= next(0): bottomOverlap = customOverlap
      expect(result.bottomOverlap, equals(customOverlap));
    });

    test(
      'selected neighbor has higher priority → current loses topOverlap',
      () {
        // current = hovered (priority 1), previous = selected (priority 2).
        // hasUpperInteraction = true; current(1) > previous(2) is false
        // → topOverlap = 0.
        final result = buildTaskBrowseRowInteraction(
          taskId: 'task-2',
          previousTaskIdInSection: 'task-1',
          nextTaskIdInSection: null,
          selectedTaskId: 'task-1',
          hoveredTaskId: 'task-2',
        );
        expect(result.topOverlap, equals(0));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // buildTaskBrowseRowInteraction — Glados properties
  // ---------------------------------------------------------------------------

  group('buildTaskBrowseRowInteraction — properties', () {
    glados.Glados2(
      glados.any.taskId,
      glados.any.taskId,
      glados.ExploreConfig(numRuns: 120),
    ).test('result is idempotent (same args → equal result)', (
      taskId,
      otherId,
    ) {
      final id = taskId.isEmpty ? 'default' : taskId;
      final other = otherId.isEmpty ? null : otherId;

      final r1 = buildTaskBrowseRowInteraction(
        taskId: id,
        previousTaskIdInSection: other,
        nextTaskIdInSection: other,
        selectedTaskId: other,
      );
      final r2 = buildTaskBrowseRowInteraction(
        taskId: id,
        previousTaskIdInSection: other,
        nextTaskIdInSection: other,
        selectedTaskId: other,
      );

      expect(r1.topOverlap, equals(r2.topOverlap));
      expect(r1.bottomOverlap, equals(r2.bottomOverlap));
      expect(r1.showDividerBelow, equals(r2.showDividerBelow));
    }, tags: 'glados');

    glados.Glados3(
      glados.any.taskId,
      glados.any.taskId,
      glados.any.taskId,
      glados.ExploreConfig(numRuns: 120),
    ).test('showDividerBelow is only true when nextTaskIdInSection is non-null '
        'and both current and next priority are 0', (taskId, prevId, nextId) {
      final id = taskId.isEmpty ? 'task' : taskId;
      final prev = prevId.isEmpty ? null : prevId;
      final next = nextId.isEmpty ? null : nextId;

      // No selected/hovered → all priorities are 0.
      final result = buildTaskBrowseRowInteraction(
        taskId: id,
        previousTaskIdInSection: prev,
        nextTaskIdInSection: next,
      );

      if (next == null) {
        expect(
          result.showDividerBelow,
          isFalse,
          reason: 'no next → no divider',
        );
      } else {
        // With no selection, all priorities are 0, so divider should appear.
        expect(
          result.showDividerBelow,
          isTrue,
          reason: 'next exists, both priorities 0 → divider',
        );
      }
    }, tags: 'glados');
  });
}
