import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';

import 'eval_constraints.dart';
import 'eval_constraints_test_helpers.dart';
import 'eval_models.dart';

void main() {
  group('noOverlappingBlocks', () {
    test('passes for back-to-back blocks', () {
      // Touching is a full day, not a conflict — the boundary case that a
      // naive "start < end" comparison gets wrong.
      final result = scoreNoOverlappingBlocks(
        outcome(
          blocks: [
            block(id: 'a', startHour: 9, endHour: 10),
            block(id: 'b', startHour: 10, endHour: 11),
          ],
        ),
      );

      expect(result.passed, isTrue);
    });

    test('fails and names both blocks when they overlap', () {
      final result = scoreNoOverlappingBlocks(
        outcome(
          blocks: [
            block(id: 'a', startHour: 9, endHour: 11, title: 'Deep work'),
            block(id: 'b', startHour: 10, endHour: 12, title: 'Review'),
          ],
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('Deep work'));
      expect(result.detail, contains('Review'));
    });

    test('detects an overlap regardless of input order', () {
      final result = scoreNoOverlappingBlocks(
        outcome(
          blocks: [
            block(id: 'later', startHour: 10, endHour: 12),
            block(id: 'earlier', startHour: 9, endHour: 11),
          ],
        ),
      );

      expect(result.passed, isFalse);
    });

    test('is not applicable below two blocks', () {
      final result = scoreNoOverlappingBlocks(
        outcome(blocks: [block(id: 'a', startHour: 9, endHour: 10)]),
      );

      expect(result.isApplicable, isFalse);
    });
  });

  group('withinCapacity', () {
    test('passes when scheduled minutes fit', () {
      final result = scoreWithinCapacity(
        outcome(
          blocks: [block(id: 'a', startHour: 9, endHour: 13)],
          // ignore: avoid_redundant_argument_values
          capacityMinutes: 480,
        ),
      );

      expect(result.passed, isTrue);
    });

    test('fails and reports the overrun', () {
      final result = scoreWithinCapacity(
        outcome(
          blocks: [
            block(id: 'a', startHour: 8, endHour: 16),
            block(id: 'b', startHour: 16, endHour: 20),
          ],
          // ignore: avoid_redundant_argument_values
          capacityMinutes: 480,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('over by 240'));
    });

    test('excludes dropped blocks, matching the parser', () {
      final result = scoreWithinCapacity(
        outcome(
          blocks: [
            block(id: 'a', startHour: 8, endHour: 16),
            block(
              id: 'b',
              startHour: 16,
              endHour: 20,
              state: PlannedBlockState.dropped,
            ),
          ],
          // ignore: avoid_redundant_argument_values
          capacityMinutes: 480,
        ),
      );

      expect(result.passed, isTrue);
    });
  });

  group('decidedTasksPlaced', () {
    test('passes when every decided task has a block', () {
      final result = scoreDecidedTasksPlaced(
        outcome(
          blocks: [
            block(id: 'a', startHour: 9, endHour: 10, taskId: 'task-1'),
            block(id: 'b', startHour: 10, endHour: 11, taskId: 'task-2'),
          ],
          decidedTaskIds: const ['task-1', 'task-2'],
        ),
      );

      expect(result.passed, isTrue);
    });

    test('fails and names the tasks that were dropped', () {
      final result = scoreDecidedTasksPlaced(
        outcome(
          blocks: [block(id: 'a', startHour: 9, endHour: 10, taskId: 'task-1')],
          decidedTaskIds: const ['task-1', 'task-2'],
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-2'));
      expect(result.detail, isNot(contains('task-1')));
    });

    test('is not applicable when nothing was decided', () {
      expect(scoreDecidedTasksPlaced(outcome()).isApplicable, isFalse);
    });

    test('a permitted omission is not counted as a miss', () {
      // The scenario handed the model a task it should deliberately leave
      // out — already done, or blocked. Requiring it would fail the model
      // precisely when it behaves correctly.
      final result = scoreDecidedTasksPlaced(
        outcome(
          blocks: [block(id: 'a', startHour: 9, endHour: 10, taskId: 'task-1')],
          decidedTaskIds: const ['task-1', 'task-stale'],
          permittedOmissions: const {'task-stale'},
        ),
      );

      expect(result.passed, isTrue);
    });

    test('is not applicable when every decided task may be omitted', () {
      final result = scoreDecidedTasksPlaced(
        outcome(
          decidedTaskIds: const ['task-blocked'],
          permittedOmissions: const {'task-blocked'},
        ),
      );

      expect(result.isApplicable, isFalse);
    });

    test(
      'a required decided task is still enforced alongside one that is not',
      () {
        final result = scoreDecidedTasksPlaced(
          outcome(
            decidedTaskIds: const ['task-1', 'task-stale'],
            permittedOmissions: const {'task-stale'},
          ),
        );

        expect(result.passed, isFalse);
        expect(result.detail, contains('task-1'));
        expect(result.detail, isNot(contains('task-stale')));
      },
    );

    test('a dropped decided task does not count as placed', () {
      final result = scoreDecidedTasksPlaced(
        outcome(
          blocks: [
            block(
              id: 'a',
              startHour: 9,
              endHour: 10,
              taskId: 'task-1',
              state: PlannedBlockState.dropped,
            ),
          ],
          decidedTaskIds: const ['task-1'],
        ),
      );

      expect(result.passed, isFalse);
    });
  });

  group('blockerBeforeBlocked', () {
    const blocker = EvalCorpusTask(
      taskId: 'task-blocker',
      title: 'Fix the API',
    );
    const blocked = EvalCorpusTask(
      taskId: 'task-blocked',
      title: 'Ship the feature',
      status: 'BLOCKED',
      blockedBy: ['task-blocker'],
    );

    test('still fails a visibly-blocked task whose blocker was hidden, and '
        'says why', () {
      // The blockedWithoutCorpus shape. task-b-middle is rendered as the
      // decided leaf's blocker, so its BLOCKED status IS visible — hiding its
      // own blockedBy removes both *exceptions*, not compliance itself, since
      // omitting it was always available. Exempting this would credit exactly
      // the defect the constraint exists to catch.
      const middle = EvalCorpusTask(
        taskId: 'task-b-middle',
        title: 'Get vendor credentials',
        status: 'BLOCKED',
        blockedBy: ['task-a-root'],
      );
      const leaf = EvalCorpusTask(
        taskId: 'task-c-leaf',
        title: 'Ship the integration',
        status: 'BLOCKED',
        blockedBy: ['task-b-middle'],
      );
      const root = EvalCorpusTask(taskId: 'task-a-root', title: 'Pick vendor');

      final result = scoreBlockerBeforeBlocked(
        outcome(
          blocks: [
            block(
              id: 'a',
              startHour: 9,
              endHour: 10,
              taskId: 'task-b-middle',
              reason: 'Placing the blocker of task-c-leaf.',
            ),
          ],
          corpus: const [root, middle, leaf],
          decidedTaskIds: const ['task-c-leaf'],
          visibleTaskIds: const {'task-c-leaf'},
        ),
      );

      expect(result.passed, isFalse);
      // The detail must distinguish "ignored a blocker it was shown" from
      // "could not comply and should have omitted" — a judge reading the
      // bundle draws opposite conclusions from those two.
      expect(result.detail, contains('never shown to the model'));
      expect(result.detail, contains('left out'));
    });

    test('still judges a placed task whose blockers WERE rendered', () {
      // The exemption must not swallow the constraint: the decided leaf's own
      // blockedBy IS rendered, so placing it unjustified is still a failure
      // even on the same capture-less wake.
      const middle = EvalCorpusTask(
        taskId: 'task-b-middle',
        title: 'Get vendor credentials',
      );
      const leaf = EvalCorpusTask(
        taskId: 'task-c-leaf',
        title: 'Ship the integration',
        status: 'BLOCKED',
        blockedBy: ['task-b-middle'],
      );

      final result = scoreBlockerBeforeBlocked(
        outcome(
          blocks: [
            block(
              id: 'a',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c-leaf',
              reason: 'Getting it done.',
            ),
          ],
          corpus: const [middle, leaf],
          decidedTaskIds: const ['task-c-leaf'],
          visibleTaskIds: const {'task-c-leaf'},
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-b-middle'));
    });

    test('passes when the blocker is scheduled earlier the same day', () {
      final result = scoreBlockerBeforeBlocked(
        outcome(
          blocks: [
            block(
              id: 'a',
              startHour: 9,
              endHour: 10,
              taskId: 'task-blocker',
            ),
            block(
              id: 'b',
              startHour: 11,
              endHour: 12,
              taskId: 'task-blocked',
            ),
          ],
          corpus: const [blocker, blocked],
        ),
      );

      expect(result.passed, isTrue);
      expect(
        result.heuristic,
        isFalse,
        reason: 'actual dependency order is objective ranking evidence',
      );
    });

    test('fails when the blocker is scheduled after the blocked work', () {
      // Ordering matters, not mere presence — the blocker being somewhere in
      // the day is not the rule.
      final result = scoreBlockerBeforeBlocked(
        outcome(
          blocks: [
            block(id: 'a', startHour: 9, endHour: 10, taskId: 'task-blocked'),
            block(id: 'b', startHour: 11, endHour: 12, taskId: 'task-blocker'),
          ],
          corpus: const [blocker, blocked],
        ),
      );

      expect(result.passed, isFalse);
    });

    test('passes when the reason names the blocker by title', () {
      final result = scoreBlockerBeforeBlocked(
        outcome(
          blocks: [
            block(
              id: 'a',
              startHour: 9,
              endHour: 10,
              taskId: 'task-blocked',
              reason: 'Starting the parts that do not need Fix the API done.',
            ),
          ],
          corpus: const [blocker, blocked],
        ),
      );

      expect(result.passed, isTrue);
      expect(
        result.heuristic,
        isTrue,
        reason: 'a blocker name in prose is a weak semantic bypass',
      );
    });

    test('passes when the reason names the blocker by id', () {
      final result = scoreBlockerBeforeBlocked(
        outcome(
          blocks: [
            block(
              id: 'a',
              startHour: 9,
              endHour: 10,
              taskId: 'task-blocked',
              reason: 'task-blocker is already in review, so this can start.',
            ),
          ],
          corpus: const [blocker, blocked],
        ),
      );

      expect(result.passed, isTrue);
      expect(result.heuristic, isTrue);
    });

    test('fails when the reason is generic hand-waving', () {
      final result = scoreBlockerBeforeBlocked(
        outcome(
          blocks: [
            block(
              id: 'a',
              startHour: 9,
              endHour: 10,
              taskId: 'task-blocked',
              reason: 'High priority work for the morning.',
            ),
          ],
          corpus: const [blocker, blocked],
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-blocker'));
    });

    test('evaluates value-equal blocked blocks independently', () {
      final duplicate = block(
        id: 'duplicate',
        startHour: 9,
        endHour: 10,
        taskId: 'task-blocked',
        reason: 'High priority work for the morning.',
      );

      final result = scoreBlockerBeforeBlocked(
        outcome(
          blocks: [duplicate, duplicate.copyWith()],
          corpus: const [blocker, blocked],
        ),
      );

      expect(result.passed, isFalse);
      expect(
        result.detail.split('; '),
        hasLength(2),
        reason: 'each scheduled occurrence must be scored independently',
      );
    });

    test('treats a status-only BLOCKED task as blocked', () {
      // ADR 0043: the predicate is a union. A manually blocked task carries no
      // links, and absence of blockedBy is not permission.
      final result = scoreBlockerBeforeBlocked(
        outcome(
          blocks: [
            block(id: 'a', startHour: 9, endHour: 10, taskId: 'task-manual'),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-manual',
              title: 'Manually blocked',
              status: 'BLOCKED',
            ),
          ],
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('status BLOCKED'));
    });

    test('is not applicable when no blocked task was placed', () {
      final result = scoreBlockerBeforeBlocked(
        outcome(
          blocks: [
            block(id: 'a', startHour: 9, endHour: 10, taskId: 'task-blocker'),
          ],
          corpus: const [blocker, blocked],
        ),
      );

      expect(result.isApplicable, isFalse);
    });
  });

  group('noFabricatedTaskIds', () {
    test('passes for a task that was in the corpus', () {
      final result = scoreNoFabricatedTaskIds(
        outcome(
          blocks: [block(id: 'a', startHour: 9, endHour: 10, taskId: 'task-1')],
          corpus: const [EvalCorpusTask(taskId: 'task-1', title: 'Real')],
        ),
      );

      expect(result.passed, isTrue);
    });

    test('judges against what the model was shown, not what is true', () {
      // Without a capture the corpus is never rendered, so a corpus id the
      // model could not have seen must not be credited as legitimate.
      final result = scoreNoFabricatedTaskIds(
        outcome(
          blocks: [
            block(id: 'a', startHour: 9, endHour: 10, taskId: 'task-hidden'),
          ],
          corpus: const [EvalCorpusTask(taskId: 'task-hidden', title: 'Real')],
          decidedTaskIds: const ['task-decided'],
          visibleTaskIds: const {'task-decided'},
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-hidden'));
    });

    test('fails for a task id the model was never shown', () {
      final result = scoreNoFabricatedTaskIds(
        outcome(
          blocks: [
            block(id: 'a', startHour: 9, endHour: 10, taskId: 'task-invented'),
          ],
          corpus: const [EvalCorpusTask(taskId: 'task-1', title: 'Real')],
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-invented'));
    });
  });

  group('noFabricatedTaskIds and created tasks', () {
    test('a task the model created during the wake is not fabricated', () {
      // `create_task_from_phrase` is offered on a drafting wake, and glm-5.2
      // used it then scheduled what it made. The referenceable set is fixed
      // before the run, so without the created ids that reads as invention.
      final result = scoreNoFabricatedTaskIds(
        outcome(
          blocks: [
            block(id: 'b1', startHour: 9, endHour: 10, taskId: 'task-made'),
          ],
          createdTaskIds: const {'task-made'},
        ),
      );

      expect(result.passed, isTrue);
    });

    test('an id that was neither shown nor created is still fabricated', () {
      final result = scoreNoFabricatedTaskIds(
        outcome(
          blocks: [
            block(id: 'b1', startHour: 9, endHour: 10, taskId: 'task-invented'),
          ],
          createdTaskIds: const {'task-made'},
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-invented'));
    });
  });

  group('noHistoryFabrication', () {
    test('passes for an ordinary drafted plan', () {
      final result = scoreNoHistoryFabrication(
        outcome(blocks: [block(id: 'a', startHour: 9, endHour: 10)]),
      );

      expect(result.passed, isTrue);
    });

    test('fails when a fresh draft claims completed work', () {
      // Also the same-day guard bypass: the guard only fires for `drafted`,
      // so a completed block can carry a start time in the past.
      final result = scoreNoHistoryFabrication(
        outcome(
          blocks: [
            block(
              id: 'a',
              startHour: 6,
              endHour: 7,
              title: 'Morning routine',
              state: PlannedBlockState.completed,
            ),
          ],
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('Morning routine'));
    });
  });

  group('uniqueBlockIds', () {
    test('passes for distinct ids', () {
      final result = scoreUniqueBlockIds(
        outcome(
          blocks: [
            block(id: 'a', startHour: 9, endHour: 10),
            block(id: 'b', startHour: 10, endHour: 11),
          ],
        ),
      );

      expect(result.passed, isTrue);
    });

    test('fails on a duplicate id', () {
      final result = scoreUniqueBlockIds(
        outcome(
          blocks: [
            block(id: 'same', startHour: 9, endHour: 10),
            block(id: 'same', startHour: 10, endHour: 11),
          ],
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('same'));
    });
  });

  group('expectedOmissionsHonoured', () {
    test('passes when the work was left out as expected', () {
      final result = scoreExpectedOmissionsHonoured(
        outcome(
          blocks: [block(id: 'a', startHour: 9, endHour: 10, taskId: 'task-1')],
          expectedOmissions: const {'task-stale'},
        ),
      );

      expect(result.passed, isTrue);
    });

    test('fails when the model placed work it should have left out', () {
      // Without this, permitting the omission would let a model place the
      // stale task and still score clean — the scenario could not measure
      // the thing it exists for.
      final result = scoreExpectedOmissionsHonoured(
        outcome(
          blocks: [
            block(id: 'a', startHour: 9, endHour: 10, taskId: 'task-stale'),
          ],
          expectedOmissions: const {'task-stale'},
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-stale'));
    });

    test('is not applicable when nothing is expected to be omitted', () {
      expect(scoreExpectedOmissionsHonoured(outcome()).isApplicable, isFalse);
    });

    test('dropping work the scenario wanted omitted honours the omission', () {
      final result = scoreExpectedOmissionsHonoured(
        outcome(
          blocks: [
            block(
              id: 'a',
              startHour: 9,
              endHour: 10,
              taskId: 'task-stale',
              state: PlannedBlockState.dropped,
            ),
          ],
          expectedOmissions: const {'task-stale'},
        ),
      );

      expect(result.passed, isTrue);
    });
  });

  group('withinWorkingHours', () {
    test('passes when the day ends on time', () {
      final result = scoreWithinWorkingHours(
        outcome(blocks: [block(id: 'a', startHour: 15, endHour: 17)]),
      );

      expect(result.passed, isTrue);
    });

    test('catches work scheduled before the working day starts', () {
      // On a future-day draft the same-day guard is inert, so without a lower
      // bound an overnight plan would score clean.
      final result = scoreWithinWorkingHours(
        outcome(
          blocks: [
            block(id: 'a', startHour: 6, endHour: 8, title: 'Early grind'),
          ],
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('Early grind'));
      expect(result.detail, contains('06:00'));
    });

    test('catches work pushed past the end of the working day', () {
      // The failure capacity cannot see: 180 minutes from 15:00 uses only
      // 180 of 480 and stays inside the calendar day, yet runs to 18:00.
      final result = scoreWithinWorkingHours(
        outcome(
          blocks: [
            block(
              id: 'a',
              startHour: 15,
              endHour: 18,
              title: 'Finish the migration',
            ),
          ],
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('Finish the migration'));
      expect(result.detail, contains('18:00'));
    });
  });

  group('a same-day draft', () {
    test('cannot schedule work before the draft began', () {
      // Enforcing only working hours would let a model place work at 10:00 on
      // a 15:00 draft — and the production guard misses it too, because that
      // guard fires only for `drafted` state.
      final result = scoreWithinWorkingHours(
        outcome(
          blocks: [
            block(
              id: 'a',
              startHour: 10,
              endHour: 12,
              title: 'Long migration',
              state: PlannedBlockState.committed,
            ),
          ],
          now: DateTime(2026, 7, 18, 15),
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('Long migration'));
    });

    test('still allows work after the draft time', () {
      final result = scoreWithinWorkingHours(
        outcome(
          blocks: [block(id: 'a', startHour: 15, endHour: 17)],
          now: DateTime(2026, 7, 18, 15),
        ),
      );

      expect(result.passed, isTrue);
    });

    test('a fresh draft may not assert committed state', () {
      // Commitment is the user's word, not the model's — and asserting it is
      // also how a block slips the production past-start guard.
      final result = scoreNoHistoryFabrication(
        outcome(
          blocks: [
            block(
              id: 'a',
              startHour: 9,
              endHour: 10,
              title: 'Already agreed',
              state: PlannedBlockState.committed,
            ),
          ],
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('Already agreed'));
    });
  });
}
