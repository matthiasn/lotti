import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/day_plan.dart';

import 'eval_constraints.dart';
import 'eval_models.dart';

/// The scorers are pure, so these run in ordinary CI: no provider, no
/// database, no pipeline. Every scorer is exercised in both directions,
/// because a scorer that only ever passes is indistinguishable from one that
/// is broken.
void main() {
  final planDate = DateTime(2026, 7, 18);

  PlannedBlock block({
    required String id,
    required int startHour,
    required int endHour,
    String? taskId,
    String? note,
    String? reason,
    String? title,
    PlannedBlockType type = PlannedBlockType.ai,
    PlannedBlockState state = PlannedBlockState.drafted,
  }) => PlannedBlock(
    id: id,
    categoryId: 'cat-1',
    startTime: DateTime(2026, 7, 18, startHour),
    endTime: DateTime(2026, 7, 18, endHour),
    taskId: taskId,
    note: note,
    reason: reason,
    title: title ?? id,
    type: type,
    state: state,
  );

  EvalRunOutcome outcome({
    List<PlannedBlock> blocks = const [],
    List<EvalCorpusTask> corpus = const [],
    List<String> decidedTaskIds = const [],
    Set<String> permittedOmissions = const {},
    Set<String> expectedOmissions = const {},
    Set<String> requiredTaskIds = const {},
    bool requiresConflictSurfaced = false,
    bool forbidsInventedWork = false,
    Set<String> conflictEscalationReasons = const {'overCommitted'},
    DateTime? now,
    bool planPersisted = true,
    int workingHoursStartHour = 9,
    int workingHoursEndHour = 17,
    Set<String>? visibleTaskIds,
    List<EvalToolCall> toolCalls = const [],
    int capacityMinutes = 480,
    EvalDirective? directive,
    Set<String> createdTaskIds = const {},
  }) => EvalRunOutcome(
    inputs: EvalFixtureInputs(
      dayId: 'dayplan-2026-07-18',
      planDate: planDate,
      corpus: corpus,
      decidedTaskIds: decidedTaskIds,
      permittedOmissions: permittedOmissions,
      expectedOmissions: expectedOmissions,
      requiredTaskIds: requiredTaskIds,
      requiresConflictSurfaced: requiresConflictSurfaced,
      forbidsInventedWork: forbidsInventedWork,
      conflictEscalationReasons: conflictEscalationReasons,
      now: now,
      visibleTaskIds: visibleTaskIds,
      workingHoursStartHour: workingHoursStartHour,
      workingHoursEndHour: workingHoursEndHour,
      capacityMinutes: capacityMinutes,
      directive: directive,
    ),
    blocks: blocks,
    toolCalls: toolCalls,
    planPersisted: planPersisted,
    createdTaskIds: createdTaskIds,
  );

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
  });

  group('respectsEstimates stands down on an impossible day', () {
    const long = EvalCorpusTask(
      taskId: 'task-long',
      title: 'Finish the migration',
      estimateMinutes: 180,
    );

    test('a shortened block is compression when the day had room', () {
      final result = scoreRespectsEstimates(
        outcome(
          blocks: [
            block(id: 'a', startHour: 9, endHour: 10, taskId: 'task-long'),
          ],
          corpus: const [long],
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('180min estimate'));
    });

    test('a plan of tokens fails even on a day that cannot fit', () {
      // The hole in standing down entirely: shortening every task to a token
      // leaves requiredWorkPlaced satisfied, estimate-capacity under the cap,
      // and surfacedConflict silent because nothing was omitted. The question
      // becomes "did the plan use the time it had", not "did each task get its
      // estimate", which is impossible here.
      final result = scoreRespectsEstimates(
        outcome(
          blocks: [
            block(id: 'a', startHour: 15, endHour: 15, taskId: 'task-long'),
          ],
          corpus: const [long],
          now: DateTime(2026, 7, 18, 15),
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('not a partial placement'));
    });

    test('required work reduced to a token fails, even if the total fills', () {
      // The hole in an aggregate-only check: one long task supplies the fill
      // while the work the scenario requires is shortened to a minute each.
      // requiredWorkPlaced only checks that the id appears, so nothing else
      // objects.
      const invoice = EvalCorpusTask(
        taskId: 'task-invoice',
        title: 'Send the overdue invoice',
        estimateMinutes: 30,
      );

      final result = scoreRespectsEstimates(
        outcome(
          blocks: [
            block(id: 'a', startHour: 15, endHour: 16, taskId: 'task-long'),
            block(
              id: 'b',
              startHour: 16,
              endHour: 16,
              taskId: 'task-invoice',
            ).copyWith(title: 'Send the overdue invoice'),
          ],
          corpus: const [long, invoice],
          requiredTaskIds: const {'task-invoice'},
          now: DateTime(2026, 7, 18, 15),
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('reduced to a token'));
      expect(result.detail, contains('Send the overdue invoice'));
    });

    test('required work shortened but still substantial is allowed', () {
      // A genuinely partial placement is the point on an impossible day, so
      // the floor is deliberately generous — it catches a token, not a trim.
      const invoice = EvalCorpusTask(
        taskId: 'task-invoice',
        title: 'Send the overdue invoice',
        estimateMinutes: 30,
      );

      final result = scoreRespectsEstimates(
        outcome(
          blocks: [
            block(id: 'a', startHour: 15, endHour: 16, taskId: 'task-long'),
            block(
              id: 'b',
              startHour: 16,
              endHour: 16,
              taskId: 'task-invoice',
            ).copyWith(endTime: DateTime(2026, 7, 18, 16, 15)),
          ],
          corpus: const [long, invoice],
          requiredTaskIds: const {'task-invoice'},
          now: DateTime(2026, 7, 18, 15),
        ),
      );

      expect(result.passed, isTrue);
    });

    test('the same block is a partial placement when it could not fit', () {
      // The measured case: every lateStart sample placed
      // "Finish the database migration (partial — 60 of 180 min)", exactly what
      // the prompt asks for on a day that cannot hold the work, and was marked
      // down for the label it was told to write.
      final result = scoreRespectsEstimates(
        outcome(
          blocks: [
            block(id: 'a', startHour: 15, endHour: 16, taskId: 'task-long'),
          ],
          corpus: const [long],
          now: DateTime(2026, 7, 18, 15),
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('cannot hold this work'));
      expect(result.detail, contains('fills'));
    });

    test('plannableMinutes follows the clock, not just capacity', () {
      // lateStart advertises 480 minutes of capacity while leaving under two
      // hours of clock; scoring against capacity alone would call an
      // impossible day satisfiable.
      //
      // 115, not 120: the prompt advertises 15:05, so counting from 15:00
      // would credit five minutes the model was forbidden to use.
      expect(
        outcome(now: DateTime(2026, 7, 18, 15)).inputs.plannableMinutes,
        115,
      );
    });

    test('a day that has not begun gets the whole working day', () {
      // No `now` means a future-day draft: nothing is in the past, so the
      // budget is capacity against the full 09:00-17:00 window.
      expect(outcome().inputs.plannableMinutes, 480);
    });

    test('a same-day draft at the opening bell loses only the headroom', () {
      // 09:00 on the plan day still advertises 09:05, so 475 is the honest
      // figure — the five minutes are real and the model may not use them.
      expect(
        outcome(now: DateTime(2026, 7, 18, 9)).inputs.plannableMinutes,
        475,
      );
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

  group('noInventedWork', () {
    test('catches substantive work on a day with nothing to do', () {
      // The gap the restraint control could not see: no taskId means
      // fabrication scoring is inapplicable, and everything else passes.
      final result = scoreNoInventedWork(
        outcome(
          blocks: [
            block(
              id: 'a',
              startHour: 9,
              endHour: 11,
              title: 'Write a proposal',
            ),
          ],
          forbidsInventedWork: true,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('Write a proposal'));
    });

    test('an invented calendar event is still invented', () {
      // `cal` mirrors a real event, so on a day with no calendar seeded an
      // appointment the model made up is exactly what this control is for.
      final result = scoreNoInventedWork(
        outcome(
          blocks: [
            PlannedBlock(
              id: 'a',
              categoryId: 'cat-1',
              startTime: DateTime(2026, 7, 18, 9),
              endTime: DateTime(2026, 7, 18, 10),
              title: 'Dentist appointment',
              type: PlannedBlockType.cal,
            ),
          ],
          forbidsInventedWork: true,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('Dentist appointment'));
    });

    test('a buffer block is structuring open time, not inventing work', () {
      final result = scoreNoInventedWork(
        outcome(
          blocks: [
            PlannedBlock(
              id: 'a',
              categoryId: 'cat-1',
              startTime: DateTime(2026, 7, 18, 9),
              endTime: DateTime(2026, 7, 18, 11),
              title: 'Open buffer',
              type: PlannedBlockType.buffer,
            ),
          ],
          forbidsInventedWork: true,
        ),
      );

      expect(result.passed, isTrue);
    });

    test('is not applicable when the day has real work', () {
      expect(scoreNoInventedWork(outcome()).isApplicable, isFalse);
    });
  });

  group('respectsEstimates', () {
    const bigTask = EvalCorpusTask(
      taskId: 'task-big',
      title: 'Rewrite the ingestion pipeline',
      estimateMinutes: 240,
    );

    test('passes when the block roughly matches the estimate', () {
      final result = scoreRespectsEstimates(
        outcome(
          blocks: [
            block(id: 'a', startHour: 9, endHour: 13, taskId: 'task-big'),
          ],
          corpus: const [bigTask],
        ),
      );

      expect(result.passed, isTrue);
    });

    test('catches an impossible day made to look feasible by compression', () {
      // The cheapest way to fit four multi-hour tasks into one day is to
      // pretend each takes an hour. Capacity alone would call that a pass.
      final result = scoreRespectsEstimates(
        outcome(
          blocks: [
            block(id: 'a', startHour: 9, endHour: 10, taskId: 'task-big'),
          ],
          corpus: const [bigTask],
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('60min'));
      expect(result.detail, contains('240min'));
    });

    test('sums a task split across blocks before judging it', () {
      // 60 + 120 fully schedules a 180-minute task. Comparing each block
      // against the whole estimate would fail the first half of a correctly
      // scheduled task.
      final result = scoreRespectsEstimates(
        outcome(
          blocks: [
            block(id: '1', startHour: 9, endHour: 10, taskId: 'task-split'),
            block(id: '2', startHour: 10, endHour: 12, taskId: 'task-split'),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-split',
              title: 'Split work',
              estimateMinutes: 180,
            ),
          ],
        ),
      );

      expect(result.passed, isTrue);
    });

    test('is not applicable when no placed task carries an estimate', () {
      final result = scoreRespectsEstimates(
        outcome(
          blocks: [block(id: 'a', startHour: 9, endHour: 10, taskId: 'task-x')],
          corpus: const [
            EvalCorpusTask(taskId: 'task-x', title: 'No estimate'),
          ],
        ),
      );

      expect(result.isApplicable, isFalse);
    });
  });

  group('compliedWithoutRejection', () {
    test('an accepted non-drafting call earns no compliance credit', () {
      // The failure mode this guard exists for: a wake that called
      // `raise_day_status` and stopped has a non-empty tool log and an empty
      // rejection list, so a naive "no rejections" read would hand it a pass
      // for a run that never attempted a plan.
      final result = scoreCompliedWithoutRejection(
        outcome(
          planPersisted: false,
          toolCalls: const [
            EvalToolCall(name: 'raise_day_status', accepted: true),
          ],
        ),
      );

      expect(result.isApplicable, isFalse);
      expect(result.detail, contains('draft_day_plan'));
    });

    test('a run that called nothing is not applicable, not compliant', () {
      // An empty rejection list would otherwise read as "accepted on the first
      // attempt", so a model that was never reached, or that answered in prose
      // without calling the tool, would collect a compliance pass it did
      // nothing to earn — and aggregate scores would reward failing loudest.
      final result = scoreCompliedWithoutRejection(outcome());

      expect(result.isApplicable, isFalse);
      expect(result.detail, contains('draft_day_plan'));
    });

    test('a failed run with rejections is still scored as non-compliant', () {
      // Inapplicability is about having made no attempt. A model that tried,
      // was corrected, and still produced nothing has demonstrated exactly
      // what this constraint measures.
      final result = scoreCompliedWithoutRejection(
        outcome(
          planPersisted: false,
          toolCalls: const [
            EvalToolCall(
              name: 'draft_day_plan',
              accepted: false,
              rejectionMessage: 'blocks must stay within the planDate day',
            ),
          ],
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('1 rejection'));
    });

    test('passes when the first tool call was accepted', () {
      final result = scoreCompliedWithoutRejection(
        outcome(
          toolCalls: const [
            EvalToolCall(name: 'draft_day_plan', accepted: true),
          ],
        ),
      );

      expect(result.passed, isTrue);
    });

    test('fails and carries the rejection text the model received', () {
      // The whole point of this scorer: the persisted plan is legal either
      // way, so the correction the model needed is the only signal.
      final result = scoreCompliedWithoutRejection(
        outcome(
          toolCalls: const [
            EvalToolCall(
              name: 'draft_day_plan',
              accepted: false,
              rejectionMessage:
                  'drafted non-calendar blocks for today must not start '
                  'before current time',
            ),
            EvalToolCall(name: 'draft_day_plan', accepted: true),
          ],
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('must not start before current time'));
    });
  });

  group('dropped blocks are not placements', () {
    test('a dropped required task does not count as placed', () {
      // Production excludes dropped blocks from the day, so crediting one as
      // a placement would let a model satisfy every placement constraint
      // while committing to nothing.
      final result = scoreRequiredWorkPlaced(
        outcome(
          blocks: [
            block(
              id: 'a',
              startHour: 9,
              endHour: 10,
              taskId: 'task-overdue',
              state: PlannedBlockState.dropped,
            ),
          ],
          requiredTaskIds: const {'task-overdue'},
        ),
      );

      expect(result.passed, isFalse);
    });

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

    test('dropping work the scenario wanted omitted honours the omission', () {
      // The other direction of the same inconsistency: a dropped stale task
      // used to fail the omission constraint even though it was not scheduled.
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

  group('taskWorkIsTyped', () {
    PlannedBlock typed({
      required String id,
      required PlannedBlockType type,
      String? taskId,
      int startHour = 9,
      int endHour = 11,
    }) => PlannedBlock(
      id: id,
      categoryId: 'cat-1',
      startTime: DateTime(2026, 7, 18, startHour),
      endTime: DateTime(2026, 7, 18, endHour),
      title: id,
      taskId: taskId,
      type: type,
    );

    test('a buffer carrying a task is reported, not silently uncredited', () {
      final result = scoreTaskWorkIsTyped(
        outcome(
          blocks: [
            typed(
              id: 'buffer-1',
              type: PlannedBlockType.buffer,
              taskId: 'task-1',
            ),
          ],
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('buffer'));
      expect(result.detail, contains('task-1'));
    });

    test('work blocks carrying tasks are fine', () {
      final result = scoreTaskWorkIsTyped(
        outcome(
          blocks: [
            typed(id: 'ai-1', type: PlannedBlockType.ai, taskId: 'task-1'),
          ],
        ),
      );

      expect(result.passed, isTrue);
    });

    test('a task on a buffer earns no placement credit', () {
      // The attack this closes: label a plausible-length buffer with every
      // required task id and satisfy placement, capacity and estimates
      // without scheduling any actual work.
      final result = scoreRequiredWorkPlaced(
        outcome(
          blocks: [
            typed(
              id: 'buffer-1',
              type: PlannedBlockType.buffer,
              taskId: 'task-required',
            ),
          ],
          requiredTaskIds: const {'task-required'},
        ),
      );

      expect(result.passed, isFalse);
    });
  });

  group('withinCapacityByEstimate', () {
    const tasks = [
      EvalCorpusTask(taskId: 'task-a', title: 'A', estimateMinutes: 240),
      EvalCorpusTask(taskId: 'task-b', title: 'B', estimateMinutes: 180),
      EvalCorpusTask(taskId: 'task-c', title: 'C', estimateMinutes: 120),
      EvalCorpusTask(taskId: 'task-d', title: 'D', estimateMinutes: 180),
    ];

    test('catches a coordinated shrink that clears every per-task ratio', () {
      // 160/120/80/120 sums to exactly 480 and each allocation exceeds half
      // its estimate, so the per-task check passes — but 720 minutes of work
      // does not fit in 480 however the blocks are labelled.
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(id: '1', startHour: 9, endHour: 11, taskId: 'task-a'),
            block(id: '2', startHour: 11, endHour: 13, taskId: 'task-b'),
            block(id: '3', startHour: 13, endHour: 14, taskId: 'task-c'),
            block(id: '4', startHour: 14, endHour: 16, taskId: 'task-d'),
          ],
          corpus: tasks,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('720min'));
      expect(result.detail, contains('over by 240'));
    });

    test('passes when the placed work genuinely fits', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(id: '1', startHour: 9, endHour: 13, taskId: 'task-a'),
            block(id: '2', startHour: 13, endHour: 16, taskId: 'task-b'),
            block(id: 'break', startHour: 16, endHour: 17),
          ],
          corpus: tasks,
        ),
      );

      expect(result.passed, isTrue);
    });

    test('an overlong allocation cannot cancel another estimate shortfall', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(id: 'long', startHour: 9, endHour: 13, taskId: 'task-long'),
            block(
              id: 'short',
              startHour: 13,
              endHour: 17,
              taskId: 'task-short',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-long',
              title: 'Long allocation',
              estimateMinutes: 120,
            ),
            EvalCorpusTask(
              taskId: 'task-short',
              title: 'Short allocation',
              estimateMinutes: 360,
            ),
          ],
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('600min'));
      expect(result.detail, contains('over by 120'));
    });

    test('uses the clock-bounded planning window after a late start', () {
      const lateTasks = [
        EvalCorpusTask(
          taskId: 'invoice',
          title: 'Send invoice',
          estimateMinutes: 30,
        ),
        EvalCorpusTask(
          taskId: 'reply',
          title: 'Reply to client',
          estimateMinutes: 25,
        ),
        EvalCorpusTask(
          taskId: 'migration',
          title: 'Finish migration',
          estimateMinutes: 180,
        ),
      ];
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'invoice',
              startHour: 15,
              endHour: 16,
              taskId: 'invoice',
            ).copyWith(
              startTime: DateTime(2026, 7, 18, 15, 5),
              endTime: DateTime(2026, 7, 18, 15, 35),
            ),
            block(
              id: 'reply',
              startHour: 15,
              endHour: 16,
              taskId: 'reply',
            ).copyWith(
              startTime: DateTime(2026, 7, 18, 15, 35),
              endTime: DateTime(2026, 7, 18, 16),
            ),
            block(
              id: 'migration',
              startHour: 16,
              endHour: 17,
              taskId: 'migration',
            ),
          ],
          corpus: lateTasks,
          now: DateTime(2026, 7, 18, 15),
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('235min against 115min'));
      expect(result.detail, contains('over by 120'));
    });

    test('charges non-task blocks alongside estimated task work', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'primary',
              startHour: 9,
              endHour: 15,
              taskId: 'task-primary',
            ),
            block(
              id: 'partial',
              startHour: 15,
              endHour: 16,
              taskId: 'task-c',
              reason: 'Partial: 60 of 120 minutes are scheduled.',
            ),
            block(
              id: 'buffer',
              startHour: 16,
              endHour: 17,
              type: PlannedBlockType.buffer,
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-primary',
              title: 'Primary',
              estimateMinutes: 420,
            ),
            EvalCorpusTask(
              taskId: 'task-c',
              title: 'C',
              estimateMinutes: 120,
            ),
          ],
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('540min'));
    });

    test(
      'charges an explicit partial placement at its represented minutes',
      () {
        final result = scoreWithinCapacityByEstimate(
          outcome(
            blocks: [
              block(id: '1', startHour: 9, endHour: 13, taskId: 'task-a'),
              block(id: '2', startHour: 13, endHour: 16, taskId: 'task-b'),
              block(
                id: '3',
                startHour: 16,
                endHour: 17,
                taskId: 'task-c',
                reason:
                    'Only 60m of the 120m estimate fits in the remaining slot. '
                    'One candidate interview can be completed; the second and '
                    'Task D are deferred.',
              ),
            ],
            corpus: tasks,
          ),
        );

        expect(result.passed, isTrue);
        expect(result.detail, contains('task-c'));
        expect(result.detail, contains('60min partial'));
        expect(result.detail, contains('480min'));
        expect(result.heuristic, isTrue);
        expect(
          EvalConstraintSignals.kindFor(
            EvalConstraintIds.withinCapacityByEstimate,
          ),
          'mixed',
        );
      },
    );

    test('accepts the prompt contract of partial plus concrete remainder', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'This placement is partial; 60 minutes remain for later.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c 60min partial of 120min'));
    });

    for (final modifier in ['more', 'additional']) {
      test('accepts a $modifier-minutes remainder modifier', () {
        final result = scoreWithinCapacityByEstimate(
          outcome(
            blocks: [
              block(
                id: 'partial',
                startHour: 9,
                endHour: 10,
                taskId: 'task-c',
                reason:
                    'This placement is partial; '
                    '60 $modifier minutes remain for later.',
              ),
            ],
            corpus: tasks,
            capacityMinutes: 60,
          ),
        );

        expect(result.passed, isTrue);
        expect(result.detail, contains('task-c 60min partial of 120min'));
      });
    }

    test('accepts a still-remaining modifier in partial arithmetic', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  'This placement is partial; '
                  '60 minutes still remain for later.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c 60min partial of 120min'));
    });

    test('accepts a remainder followed by a negative-fit explanation', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  'This placement is partial; '
                  '60 minutes remain and no more fits today.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c 60min partial of 120min'));
    });

    test('rejects speculative remainder arithmetic', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'Partial; task-c might have 60 minutes remaining.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    for (final wording in ['partially', 'partly']) {
      test('accepts $wording scheduled work with a matching remainder', () {
        final result = scoreWithinCapacityByEstimate(
          outcome(
            blocks: [
              block(
                id: 'partial',
                startHour: 9,
                endHour: 10,
                taskId: 'task-c',
                reason:
                    'task-c is $wording scheduled; '
                    '60 minutes remain for later.',
              ),
            ],
            corpus: tasks,
            capacityMinutes: 60,
          ),
        );

        expect(result.passed, isTrue);
        expect(result.detail, contains('task-c 60min partial of 120min'));
      });
    }

    test('does not treat partial dependency as placement evidence', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  'task-c is partially dependent on the API; '
                  '60 minutes remain for later.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    test('rejects a modal partial-and-remainder claim', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  'task-c might be partially scheduled; '
                  '60 minutes remain for later.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    test('rejects a progressive non-task partial subject', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  'The meeting is being partially scheduled; '
                  '60 minutes remain for task-c.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    test('an objectively fitting partial remains objective', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  'Partial: 60 of 120 minutes are scheduled; '
                  '60 minutes remain for later.',
            ),
          ],
          corpus: tasks,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.heuristic, isFalse);
      expect(result.detail, contains('task-c 60min partial of 120min'));
    });

    test('accepts compact completed-of-estimate minute arithmetic', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  'Partial placement: 60 of 120 estimated minutes. '
                  'Remaining 60 min roll to a future day.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c 60min partial of 120min'));
    });

    test('accepts explicit out-of partial arithmetic', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'Partial: 60 minutes out of 120 minutes are scheduled.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c 60min partial of 120min'));
    });

    test('accepts a prepositive estimate qualifier', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: '60 minutes of an estimated 120 minutes are scheduled.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c 60min partial of 120min'));
    });

    test('rejects speculative partial arithmetic', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'task-c might schedule 60 of 120 minutes.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    for (final obligation in [
      'must schedule',
      'needs to schedule',
      'is required to schedule',
    ]) {
      test('rejects obligation-only allocation: $obligation', () {
        final result = scoreWithinCapacityByEstimate(
          outcome(
            blocks: [
              block(
                id: 'partial',
                startHour: 9,
                endHour: 10,
                taskId: 'task-c',
                reason: 'task-c $obligation 60 of 120 minutes.',
              ),
            ],
            corpus: tasks,
            capacityMinutes: 60,
          ),
        );

        expect(result.passed, isFalse);
        expect(result.detail, contains('task-c allocated 60min of 120min'));
      });
    }

    test('rejects a failed allocation action', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'task-c failed to schedule 60 of 120 minutes.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    test('rejects a near-miss allocation action', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'task-c almost scheduled 60 of 120 minutes.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    for (final failedAction in [
      'unsuccessfully scheduled',
      'failed scheduling',
    ]) {
      test('rejects a leading failure qualifier: $failedAction', () {
        final result = scoreWithinCapacityByEstimate(
          outcome(
            blocks: [
              block(
                id: 'partial',
                startHour: 9,
                endHour: 10,
                taskId: 'task-c',
                reason: 'task-c $failedAction 60 of 120 minutes.',
              ),
            ],
            corpus: tasks,
            capacityMinutes: 60,
          ),
        );

        expect(result.passed, isFalse);
        expect(result.detail, contains('task-c allocated 60min of 120min'));
      });
    }

    test('rejects an allocation failure after the arithmetic', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  'task-c scheduled 60 of 120 minutes, but the allocation '
                  'failed.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    test('ignores a non-task allocation failure after arithmetic', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  'task-c scheduled 60 of 120 minutes, but the meeting '
                  'allocation failed.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c 60min partial of 120min'));
    });

    test('rejects an attempted allocation action', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'task-c attempted to schedule 60 of 120 minutes.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    test('rejects an intention-only allocation action', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'task-c intended to schedule 60 of 120 minutes.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    test('rejects an inability-only allocation action', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'task-c was unable to schedule 60 of 120 minutes.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    test('rejects an avoided allocation action', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'task-c avoided scheduling 60 of 120 minutes.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    test('rejects a passively prevented allocation action', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  'task-c was prevented from being scheduled '
                  'for 60 of 120 minutes.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    test('preserves a scheduling denial after dash punctuation', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: '60 of 120 minutes — not scheduled.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    test('allows unrelated negation outside the partial arithmetic', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  'Partial: 60 of 120 minutes are scheduled, '
                  'with no room for the remaining work.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c 60min partial of 120min'));
    });

    test('accepts affirmative exact-cap wording', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: '60 of 120 minutes are scheduled and no more.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c 60min partial of 120min'));
    });

    test('accepts a leading exact-cap allocation', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  'No more than 60 of 120 minutes are scheduled; '
                  '60 minutes remain.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c 60min partial of 120min'));
    });

    test('accepts affirmative not-only allocation wording', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  'Not only are 60 of 120 minutes scheduled; '
                  'the remainder is deferred.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c 60min partial of 120min'));
    });

    test('accepts a split after a negative fit quantifier', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'Not all work fits so 60 of 120 minutes are scheduled.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c 60min partial of 120min'));
    });

    test('allows a later explanation that the full task cannot fit', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  'Partial: 60 of 120 minutes are scheduled because '
                  'the full task cannot fit today.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c 60min partial of 120min'));
    });

    test('allows a partial explanation with a negative quantifier', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  'Partial because not all work fits; '
                  '60 minutes remain for later.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c 60min partial of 120min'));
    });

    test('allows a partial remainder qualified for today', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  'This placement is partial for today: '
                  '60 minutes remain.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c 60min partial of 120min'));
    });

    test('accepts a future-tense partial remainder', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  'This placement is partial; '
                  '60 minutes will remain.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c 60min partial of 120min'));
    });

    test('accepts a future passive partial remainder', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  'This placement is partial; '
                  '60 minutes will be left for tomorrow.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c 60min partial of 120min'));
    });

    test('accepts an inflected carry disposition for the remainder', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  'This placement is partial. '
                  'Remaining 60 minutes are carried over to tomorrow.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c 60min partial of 120min'));
    });

    test('ignores unrelated remainder arithmetic in another subject', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  '60 of 120 minutes are scheduled for this task. '
                  '15 minutes remain in the meeting.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c 60min partial of 120min'));
    });

    test('rejects a partial claim owned by a meeting', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  'The meeting is partial. '
                  '60 minutes remain for task-c.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    test('charges a countdown before a meeting at the full estimate', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  'This placement is partial; '
                  '60 minutes remain before the meeting starts.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    test('ignores unrelated completed-estimate arithmetic', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  '60 of 120 minutes are scheduled for this task. '
                  'The meeting used 15 of 30 minutes.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c 60min partial of 120min'));
    });

    test('keeps a valid split beside separate meeting allocation', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  '60 of 120 minutes are scheduled for this task while '
                  '30 minutes are scheduled for the meeting.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c 60min partial of 120min'));
    });

    test('keeps an explicit task split during a meeting', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  '60 of 120 minutes are scheduled for task-c '
                  'during the meeting.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c 60min partial of 120min'));
    });

    test('rejects a task-labelled split allocated to a meeting', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  'task-c: 60 of 120 minutes are scheduled for the meeting.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    test('rejects arithmetic not governed by the allocation action', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  'task-c scheduled the meeting after reviewing '
                  '60 of 120 minutes of recordings.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    test('accepts an exact modifier before allocation arithmetic', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'task-c scheduled exactly 60 of 120 minutes.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c 60min partial of 120min'));
    });

    test('rejects arithmetic not governing a later allocation action', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  'task-c reviewed 60 of 120 minutes of recordings '
                  'before scheduling the meeting.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    test('accepts an affirmative adverb in a trailing allocation bridge', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'task-c: 60 of 120 minutes were successfully scheduled.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c 60min partial of 120min'));
    });

    for (final auxiliary in ['do', 'does', 'did']) {
      test('accepts an emphatic $auxiliary allocation bridge', () {
        final result = scoreWithinCapacityByEstimate(
          outcome(
            blocks: [
              block(
                id: 'partial',
                startHour: 9,
                endHour: 10,
                taskId: 'task-c',
                reason: 'task-c: 60 of 120 minutes $auxiliary fit.',
              ),
            ],
            corpus: tasks,
            capacityMinutes: 60,
          ),
        );

        expect(result.passed, isTrue);
        expect(result.detail, contains('task-c 60min partial of 120min'));
      });
    }

    test('rejects a negative adverb in a trailing allocation bridge', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  'task-c: 60 of 120 minutes were unsuccessfully scheduled.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    test('accepts a task qualifier before the remainder verb', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  'This placement is partial; '
                  '60 minutes of this task remain for tomorrow.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c 60min partial of 120min'));
    });

    test('allows a current-task split beside a deferred casualty', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  '60 of 120 minutes are scheduled for task-c while '
                  'Prepare the board deck is deferred.',
            ),
          ],
          corpus: const [
            ...tasks,
            EvalCorpusTask(
              taskId: 'task-deck',
              title: 'Prepare the board deck',
              estimateMinutes: 120,
            ),
          ],
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c 60min partial of 120min'));
    });

    test('keeps the owning task implicit beside a deferred casualty', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  '60 of 120 minutes are scheduled while '
                  'Prepare the board deck is deferred.',
            ),
          ],
          corpus: const [
            ...tasks,
            EvalCorpusTask(
              taskId: 'task-deck',
              title: 'Prepare the board deck',
              estimateMinutes: 120,
            ),
          ],
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c 60min partial of 120min'));
    });

    test('keeps ownership when a deferred casualty appears first', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  'Although Prepare the board deck is deferred, '
                  '60 of 120 minutes are scheduled for this task.',
            ),
          ],
          corpus: const [
            ...tasks,
            EvalCorpusTask(
              taskId: 'task-deck',
              title: 'Prepare the board deck',
              estimateMinutes: 120,
            ),
          ],
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c 60min partial of 120min'));
    });

    test('accepts a noun-qualified leading remainder', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  'This placement is partial; '
                  'the remaining work is 60 minutes and will be deferred.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c 60min partial of 120min'));
    });

    test('audits a partial task across all of its scheduled blocks', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial-1',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
            ).copyWith(endTime: DateTime(2026, 7, 18, 9, 30)),
            block(
              id: 'partial-2',
              startHour: 10,
              endHour: 11,
              taskId: 'task-c',
              reason: 'Only 60 minutes of the 120-minute estimate fit.',
            ).copyWith(endTime: DateTime(2026, 7, 18, 10, 30)),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c 60min partial of 120min'));
    });

    test('charges a split naming another task by its bare title', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  'Prepare the board deck completed 60 of 120 minutes; '
                  'Current work is deferred.',
            ),
          ],
          corpus: const [
            ...tasks,
            EvalCorpusTask(
              taskId: 'task-deck',
              title: 'Prepare the board deck',
              estimateMinutes: 120,
            ),
          ],
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    test('charges a split allocated to another task', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  '60 of 120 minutes are allocated to Task D; '
                  'Task C is deferred.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    test('charges a comma-scoped leading task split to that task', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'For task-d, 60 of 120 minutes are scheduled.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    test('charges a has-linked split to the named task', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'task-d has 60 of 120 minutes scheduled.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    test('charges a remainder explicitly naming another task', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  'This placement is partial. '
                  'Remaining 60 minutes of Prepare the board deck '
                  'are deferred.',
            ),
          ],
          corpus: const [
            ...tasks,
            EvalCorpusTask(
              taskId: 'task-deck',
              title: 'Prepare the board deck',
              estimateMinutes: 120,
            ),
          ],
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    test('charges omitted split arithmetic at the full estimate', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: '30 of 120 minutes are unscheduled for this task.',
            ).copyWith(endTime: DateTime(2026, 7, 18, 9, 30)),
          ],
          corpus: tasks,
          capacityMinutes: 30,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 30min of 120min'));
    });

    test(
      'does not borrow a later allocation action for omitted arithmetic',
      () {
        final result = scoreWithinCapacityByEstimate(
          outcome(
            blocks: [
              block(
                id: 'partial',
                startHour: 9,
                endHour: 10,
                taskId: 'task-c',
                reason:
                    '30 of 120 minutes are omitted while the rest is '
                    'scheduled for this task.',
              ).copyWith(endTime: DateTime(2026, 7, 18, 9, 30)),
            ],
            corpus: tasks,
            capacityMinutes: 30,
          ),
        );

        expect(result.passed, isFalse);
        expect(result.detail, contains('task-c allocated 30min of 120min'));
      },
    );

    test('does not bind a meeting remainder through a later disposition', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  'Partial; 60 minutes remain for the meeting while '
                  'task-c is deferred.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    test('does not borrow another task partial mention', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'Task D is partial. 60 minutes remain.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    test('does not treat partial inside a task title as capacity evidence', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-migration',
              reason:
                  'Focused work on Partial index migration; '
                  '60 minutes remain for later.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-migration',
              title: 'Partial index migration',
              estimateMinutes: 120,
            ),
          ],
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(
        result.detail,
        contains('task-migration allocated 60min of 120min'),
      );
    });

    test('does not treat a partial index as capacity evidence', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  "Focused work on task-c's partial index; "
                  '60 minutes remain for later.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    test('rejects a partial claim owned by a meeting with a task modifier', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  'The meeting for task-c is partial; '
                  '60 minutes remain for task-c.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    test('rejects an adverbial partial claim owned by a meeting', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  'The meeting was only partial; '
                  '60 minutes remain for task-c.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    test('does not borrow a postpositive task partial label', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'Partial: task-d; 60 minutes remain for later.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    test('accepts a postpositive current-task partial label', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'Partial: task-c; 60 minutes remain for later.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c 60min partial of 120min'));
    });

    test('audits contradictory remainder arithmetic in the note', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'Partial: 60 of 120 minutes are scheduled.',
              note: '90 minutes remain for this task.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    test('audits a bare contradictory remainder in the note', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: '60 of 120 minutes are scheduled.',
              note: '90 minutes remain.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    test('accepts a matching bare remainder in the note', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: '60 of 120 minutes are scheduled.',
              note: '60 minutes remain.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c 60min partial of 120min'));
    });

    test('a standalone note denial vetoes reason-field partial credit', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: '60 of 120 minutes are scheduled.',
              note: 'task-c was not scheduled after all.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    test('a speculative note denial does not veto partial credit', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: '60 of 120 minutes are scheduled.',
              note: 'this task might not be scheduled after all.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c 60min partial of 120min'));
    });

    test('a full-completion note vetoes reason-field partial credit', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: '60 of 120 minutes are scheduled.',
              note: 'task-c was fully scheduled after all.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    test('a fully planned day note preserves task partial credit', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: '60 of 120 minutes are scheduled.',
              note: 'Fully planned day.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c 60min partial of 120min'));
    });

    test('a fully planned-for-day note preserves task partial credit', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: '60 of 120 minutes are scheduled.',
              note: 'Fully planned for the day.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c 60min partial of 120min'));
    });

    test('another task denial does not veto partial credit', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: '60 of 120 minutes are scheduled.',
              note: 'task-d was not scheduled after all.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-c',
              title: 'Core',
              estimateMinutes: 120,
            ),
            EvalCorpusTask(taskId: 'task-d', title: 'Dependency'),
          ],
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isTrue);
    });

    test('a meeting denial with a task modifier does not veto credit', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: '60 of 120 minutes are scheduled.',
              note: 'The meeting for task-c was not scheduled.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c 60min partial of 120min'));
    });

    test('qualified non-completion preserves partial credit', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  'task-c was not fully scheduled; '
                  '60 of 120 minutes are scheduled.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isTrue);
    });

    test('a possessive meeting remainder cannot earn partial credit', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  'task-c is partial; '
                  'the meeting has 60 minutes remaining.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    test('a meeting that leaves a remainder cannot earn partial credit', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  'task-c is partial; '
                  'the meeting leaves 60 minutes remaining.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    test(
      'a standalone completion denial vetoes reason-field partial credit',
      () {
        final result = scoreWithinCapacityByEstimate(
          outcome(
            blocks: [
              block(
                id: 'partial',
                startHour: 9,
                endHour: 10,
                taskId: 'task-c',
                reason: '60 of 120 minutes are completed.',
                note: 'task-c was not completed after all.',
              ),
            ],
            corpus: tasks,
            capacityMinutes: 60,
          ),
        );

        expect(result.passed, isFalse);
        expect(result.detail, contains('task-c allocated 60min of 120min'));
      },
    );

    test('a subjectless completion denial vetoes partial credit', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: '60 of 120 minutes are completed.',
              note: 'Not completed after all.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    test(
      'note-only partial arithmetic does not satisfy the reason contract',
      () {
        final result = scoreWithinCapacityByEstimate(
          outcome(
            blocks: [
              block(
                id: 'partial',
                startHour: 9,
                endHour: 10,
                taskId: 'task-c',
                reason: 'Focused work on task-c.',
                note:
                    'Partial: 60 of 120 minutes are scheduled; '
                    '60 minutes remain for later.',
              ),
            ],
            corpus: tasks,
            capacityMinutes: 60,
          ),
        );

        expect(result.passed, isFalse);
        expect(result.detail, contains('task-c allocated 60min of 120min'));
      },
    );

    test('preserves distinct task ids when titles collide', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: "task-d's 60 of 120 minutes are scheduled.",
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-c',
              title: 'Review',
              estimateMinutes: 120,
            ),
            EvalCorpusTask(
              taskId: 'task-d',
              title: 'Review',
              estimateMinutes: 120,
            ),
          ],
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    test('charges remaining-of-estimate prose at the full estimate', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: '30 of the 120 minutes remain for this task.',
            ).copyWith(endTime: DateTime(2026, 7, 18, 9, 30)),
          ],
          corpus: tasks,
          capacityMinutes: 30,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 30min of 120min'));
    });

    test('does not treat a trailing schedule as completed allocation', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'task-c: 30 of 120 minutes remain to be scheduled.',
            ).copyWith(endTime: DateTime(2026, 7, 18, 9, 30)),
          ],
          corpus: tasks,
          capacityMinutes: 30,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 30min of 120min'));
    });

    test('does not treat remaining scheduled time as unfinished work', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  "task-c's placement is partial; "
                  '60 minutes remain scheduled as planned.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    test('rejects task-bound numeric continuity as unfinished work', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  'task-c is partial; '
                  '60 minutes remain scheduled as planned.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    for (final badDisclosure in <({String name, String? reason})>[
      (
        name: 'vague partial prose',
        reason: 'Partial interview work; finish the rest later.',
      ),
      (name: 'silent compression', reason: null),
      (name: 'blank disclosure', reason: '   '),
      (
        name: 'concrete duration without a partial split',
        reason: 'Scheduled 60 minutes for the interview task.',
      ),
      (
        name: 'numbers that contradict the block',
        reason:
            'Partial: 90 minutes of the 120-minute task are scheduled; '
            '30 minutes remain.',
      ),
      (
        name: 'matching split with a contradictory remainder',
        reason:
            'Partial: 60 minutes of the 120-minute task are scheduled; '
            '30 minutes remain.',
      ),
      (
        name: 'matching split with a contradictory prefix remainder',
        reason:
            'Partial: 60 of 120 estimated minutes are scheduled. '
            'Remaining 30 min move to tomorrow.',
      ),
      (
        name: 'a negated partial disclosure',
        reason: 'This is not a partial placement; 60 minutes remain for later.',
      ),
      (
        name: 'a contracted negated partial disclosure',
        reason: "This isn't a partial placement; 60 minutes remain for later.",
      ),
      (
        name: 'a negated completed-estimate split',
        reason:
            'This block does not schedule 60 of the 120 minutes; '
            'it is only a placeholder.',
      ),
      (
        name: 'a completed-estimate split followed by negation',
        reason:
            '60 of the 120 minutes are not scheduled; '
            'this block is only a placeholder.',
      ),
      (
        name: 'an uncontracted cannot-negated split',
        reason:
            '60 of the 120 minutes cannot be scheduled; '
            'this block is only a placeholder.',
      ),
      (
        name: 'a long-form negated completed-estimate split',
        reason:
            'We do not have enough room to schedule '
            '60 of the 120 minutes for this task.',
      ),
      (
        name: 'an unrelated workday remainder',
        reason:
            'Partial progress is recorded; '
            '60 minutes remain in the workday.',
      ),
      (
        name: 'a nearby partial with a meeting remainder',
        reason:
            'This placement is partial, '
            '60 minutes remain for the meeting.',
      ),
      (
        name: 'an unrelated workday completed-estimate split',
        reason:
            'Only 60 of the 120 minutes are available in the workday; '
            'this task is deferred.',
      ),
      (
        name: 'a completed-estimate split scheduled for a meeting',
        reason:
            '60 of the 120 minutes are scheduled for the meeting; '
            'this task is deferred.',
      ),
      (
        name: 'unrelated estimated meeting arithmetic',
        reason: 'The meeting used 60 of 120 estimated minutes.',
      ),
      (
        name: 'another task completed-estimate split',
        reason:
            'Task D completed 60 of 120 minutes; '
            'Task C is deferred.',
      ),
      (
        name: 'another task possessive completed-estimate split',
        reason: "task-d's 60 of 120 minutes are scheduled.",
      ),
    ]) {
      test('charges ${badDisclosure.name} at the full estimate', () {
        final result = scoreWithinCapacityByEstimate(
          outcome(
            blocks: [
              block(id: '1', startHour: 9, endHour: 13, taskId: 'task-a'),
              block(id: '2', startHour: 13, endHour: 16, taskId: 'task-b'),
              block(
                id: '3',
                startHour: 16,
                endHour: 17,
                taskId: 'task-c',
                reason: badDisclosure.reason,
              ),
            ],
            corpus: tasks,
          ),
        );

        expect(result.passed, isFalse);
        expect(result.detail, contains('540min'));
        expect(result.detail, contains('over by 60'));
      });
    }

    test('attributes arithmetic to another task with a short title', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'PR has 60 of 120 minutes scheduled.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-c',
              title: 'Core',
              estimateMinutes: 120,
            ),
            EvalCorpusTask(
              taskId: 'task-pr',
              title: 'PR',
              estimateMinutes: 120,
            ),
          ],
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    test('does not treat an article as a one-letter task title', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  'Partial: 60 minutes of a 120-minute estimate are scheduled.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-c',
              title: 'Core',
              estimateMinutes: 120,
            ),
            EvalCorpusTask(
              taskId: 'task-a',
              title: 'A',
              estimateMinutes: 60,
            ),
          ],
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c 60min partial of 120min'));
    });

    for (final estimate in <int?>[null, 0]) {
      test('is not applicable for a placed task with estimate $estimate', () {
        final result = scoreWithinCapacityByEstimate(
          outcome(
            blocks: [
              block(id: 'unknown', startHour: 9, endHour: 10, taskId: 'task-x'),
            ],
            corpus: [
              EvalCorpusTask(
                taskId: 'task-x',
                title: 'X',
                estimateMinutes: estimate,
              ),
            ],
          ),
        );

        expect(result.isApplicable, isFalse);
        expect(result.detail, contains('no placed task carries an estimate'));
      });
    }

    test('a zero-duration placeholder never earns partial credit', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'zero',
              startHour: 9,
              endHour: 9,
              taskId: 'task-c',
              reason:
                  'Partial: 0 minutes of the 120-minute task are scheduled; '
                  '120 minutes remain.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 0,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('charged at 120min'));
      expect(result.detail, isNot(contains('audited partials')));
    });

    test('a token placement never earns partial credit', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(id: 'a', startHour: 9, endHour: 13, taskId: 'task-a'),
            block(id: 'b', startHour: 13, endHour: 16, taskId: 'task-b'),
            block(
              id: 'token',
              startHour: 16,
              endHour: 17,
              taskId: 'task-c',
              reason:
                  'Partial: 1 minute of the 120-minute task is scheduled; '
                  '119 minutes remain.',
            ).copyWith(endTime: DateTime(2026, 7, 18, 16, 1)),
            block(
              id: 'substantive',
              startHour: 16,
              endHour: 17,
              taskId: 'task-d',
              reason:
                  'Partial: 59 minutes of the 180-minute task are scheduled; '
                  '121 minutes remain.',
            ).copyWith(
              startTime: DateTime(2026, 7, 18, 16, 1),
            ),
          ],
          corpus: tasks,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 1min of 120min'));
    });

    test('the 10 percent boundary is a substantive partial placement', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'boundary',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  'Partial: 12 minutes of the 120-minute task are scheduled; '
                  '108 minutes remain.',
            ).copyWith(endTime: DateTime(2026, 7, 18, 9, 12)),
          ],
          corpus: tasks,
          capacityMinutes: 12,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c 12min partial of 120min'));
    });

    test('overlapping blocks cannot manufacture a substantive partial', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            for (var i = 0; i < 12; i++)
              block(
                id: 'overlap-$i',
                startHour: 9,
                endHour: 10,
                taskId: 'task-c',
                reason: i == 0
                    ? 'Partial: 12 minutes of the 120-minute task are '
                          'scheduled; 108 minutes remain.'
                    : null,
              ).copyWith(endTime: DateTime(2026, 7, 18, 9, 1)),
          ],
          corpus: tasks,
          capacityMinutes: 12,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 12min of 120min'));
    });

    for (final type in [PlannedBlockType.buffer, PlannedBlockType.cal]) {
      test('${type.name} blocks do not count as estimated task placements', () {
        final result = scoreWithinCapacityByEstimate(
          outcome(
            blocks: [
              block(
                id: 'non-work',
                startHour: 9,
                endHour: 10,
                taskId: 'task-c',
                reason:
                    'Partial: 60 minutes of the 120-minute task are scheduled; '
                    '60 minutes remain.',
                type: type,
              ),
            ],
            corpus: tasks,
            capacityMinutes: 60,
          ),
        );

        expect(result.isApplicable, isFalse);
        expect(result.detail, contains('no placed task carries an estimate'));
      });
    }

    glados.Glados<int>(
      glados.any.intInRange(15, 106),
      glados.ExploreConfig(numRuns: 120),
    ).test('matching partial disclosures preserve capacity arithmetic', (
      allocated,
    ) {
      const estimate = 120;
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  'Partial: $allocated minutes of the $estimate-minute task '
                  'are scheduled; ${estimate - allocated} minutes remain.',
            ).copyWith(
              endTime: DateTime(2026, 7, 18, 9).add(
                Duration(minutes: allocated),
              ),
            ),
          ],
          corpus: tasks,
          capacityMinutes: allocated,
        ),
      );

      expect(
        result.passed,
        isTrue,
        reason: 'allocated=$allocated, estimate=$estimate',
      );
    }, tags: 'glados');
  });

  group('requiredWorkPlaced', () {
    test('fails when the day ignores the work it turns on', () {
      final result = scoreRequiredWorkPlaced(
        outcome(
          blocks: [
            block(id: 'a', startHour: 9, endHour: 11, taskId: 'task-later'),
          ],
          requiredTaskIds: const {'task-overdue', 'task-today'},
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-overdue'));
    });

    test('passes when every named task is placed', () {
      final result = scoreRequiredWorkPlaced(
        outcome(
          blocks: [
            block(id: 'a', startHour: 9, endHour: 10, taskId: 'task-overdue'),
            block(id: 'b', startHour: 10, endHour: 11, taskId: 'task-today'),
          ],
          requiredTaskIds: const {'task-overdue', 'task-today'},
        ),
      );

      expect(result.passed, isTrue);
    });
  });

  group('surfacedConflict', () {
    const dropped = [
      EvalCorpusTask(taskId: 'task-deck', title: 'Prepare the board deck'),
      EvalCorpusTask(taskId: 'task-report', title: 'Close the quarterly'),
    ];

    test('fails when an impossible day is absorbed in silence', () {
      // The gap permitting omissions opened: one ordinary buffer block,
      // hours of requested work ignored, nothing said.
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'a',
              startHour: 9,
              endHour: 10,
              reason: 'Open buffer for the morning.',
            ),
          ],
          corpus: dropped,
          decidedTaskIds: const ['task-deck', 'task-report'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('without naming a casualty'));
    });

    test('a conflict word alone is not surfacing anything', () {
      // "Deferred" names no casualty and gives the user nothing to act on.
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'a',
              startHour: 9,
              endHour: 10,
              reason: 'Deferred — preserving capacity.',
            ),
          ],
          corpus: dropped,
          decidedTaskIds: const ['task-deck', 'task-report'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isFalse);
    });

    test('passes when the reason names what was left out', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'a',
              startHour: 9,
              endHour: 13,
              reason:
                  'Prepare the board deck moved to tomorrow — all four '
                  'do not fit today.',
            ),
          ],
          corpus: dropped,
          decidedTaskIds: const ['task-deck', 'task-report'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-deck'));
    });

    test('accepts a causal qualifier after an omitted task disposition', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'context',
              startHour: 9,
              endHour: 10,
              reason: 'task-c was omitted due to capacity.',
            ),
          ],
          corpus: const [EvalCorpusTask(taskId: 'task-c', title: 'Core')],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c'));
    });

    test('keeps a deferral despite another task causal negation', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'task-c-block',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  'task-c was deferred because Deployment was not scheduled.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-c',
              title: 'C',
              estimateMinutes: 120,
            ),
            EvalCorpusTask(
              taskId: 'task-d',
              title: 'Deployment',
              estimateMinutes: 60,
            ),
          ],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c'));
    });

    test('accepts an omission from the day plan', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'context',
              startHour: 9,
              endHour: 10,
              reason: "task-c was omitted from today's plan.",
            ),
          ],
          corpus: const [EvalCorpusTask(taskId: 'task-c', title: 'Core')],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c'));
    });

    test('accepts an explicit not-scheduled trade', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'context',
              startHour: 9,
              endHour: 10,
              reason: 'task-c was not scheduled due to capacity.',
            ),
          ],
          corpus: const [EvalCorpusTask(taskId: 'task-c', title: 'Core')],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c'));
    });

    for (final inability in [
      'cannot be scheduled',
      "can't be scheduled",
      "couldn't be scheduled",
      'was unable to be scheduled',
      "wasn't able to be scheduled",
    ]) {
      test('accepts an inability-based scheduling omission: $inability', () {
        final result = scoreSurfacedConflict(
          outcome(
            blocks: [
              block(
                id: 'context',
                startHour: 9,
                endHour: 10,
                reason: 'task-c $inability due to capacity.',
              ),
            ],
            corpus: const [EvalCorpusTask(taskId: 'task-c', title: 'Core')],
            decidedTaskIds: const ['task-c'],
            requiresConflictSurfaced: true,
          ),
        );

        expect(result.passed, isTrue);
        expect(result.detail, contains('task-c'));
      });
    }

    test('rejects a denial of an explicit not-scheduled trade', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'context',
              startHour: 9,
              endHour: 10,
              reason:
                  'It is not true that task-c was not scheduled due to '
                  'capacity.',
            ),
          ],
          corpus: const [EvalCorpusTask(taskId: 'task-c', title: 'Core')],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('without naming a casualty'));
    });

    test('accepts an omission before a contrast predicate', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'context',
              startHour: 9,
              endHour: 10,
              reason:
                  'task-c was omitted but the remaining plan stayed intact.',
            ),
          ],
          corpus: const [EvalCorpusTask(taskId: 'task-c', title: 'Core')],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c'));
    });

    for (final reason in [
      'task-c might be omitted.',
      'task-c could be deferred.',
      'task-c may ultimately need to be deferred.',
      'task-c may need to be shortened and ultimately deferred.',
    ]) {
      test('rejects a speculative trade disposition: $reason', () {
        final result = scoreSurfacedConflict(
          outcome(
            blocks: [
              block(
                id: 'context',
                startHour: 9,
                endHour: 10,
                reason: reason,
              ),
            ],
            corpus: const [EvalCorpusTask(taskId: 'task-c', title: 'Core')],
            decidedTaskIds: const ['task-c'],
            requiresConflictSurfaced: true,
          ),
        );

        expect(result.passed, isFalse);
        expect(result.detail, contains('without naming a casualty'));
      });
    }

    for (final reason in [
      'task-c attempted to be omitted.',
      'task-c failed to be omitted.',
      'task-c requires deferring.',
      'task-c was almost omitted.',
    ]) {
      test('rejects a non-asserted trade disposition: $reason', () {
        final result = scoreSurfacedConflict(
          outcome(
            blocks: [
              block(
                id: 'context',
                startHour: 9,
                endHour: 10,
                reason: reason,
              ),
            ],
            corpus: const [EvalCorpusTask(taskId: 'task-c', title: 'Core')],
            decidedTaskIds: const ['task-c'],
            requiresConflictSurfaced: true,
          ),
        );

        expect(result.passed, isFalse);
        expect(result.detail, contains('without naming a casualty'));
      });
    }

    test('is not applicable when nothing was actually left out', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(id: 'a', startHour: 9, endHour: 10, taskId: 'task-deck'),
          ],
          corpus: dropped,
          decidedTaskIds: const ['task-deck'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.isApplicable, isFalse);
    });

    test('counts an audited partial remainder as deferred work', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'a',
              startHour: 9,
              endHour: 10,
              taskId: 'task-deck',
              reason:
                  'Partial: 60 minutes of the 120-minute Prepare the board '
                  'deck estimate fit; 60 minutes remain for tomorrow.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-deck',
              title: 'Prepare the board deck',
              estimateMinutes: 120,
            ),
          ],
          decidedTaskIds: const ['task-deck'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-deck'));
    });

    test('an unnamed audited partial remainder does not surface the trade', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'a',
              startHour: 9,
              endHour: 10,
              taskId: 'task-deck',
              reason:
                  'Partial: 60 of 120 estimated minutes fit; '
                  '60 minutes remain.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-deck',
              title: 'Prepare the board deck',
              estimateMinutes: 120,
            ),
          ],
          decidedTaskIds: const ['task-deck'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('without naming a casualty'));
    });

    test('an undisclosed shortening still requires a named casualty', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'deck',
              startHour: 9,
              endHour: 10,
              taskId: 'task-deck',
              reason: 'Focused work.',
            ),
            block(
              id: 'report',
              startHour: 10,
              endHour: 11,
              taskId: 'task-report',
              reason: 'Focused work.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-deck',
              title: 'Prepare the board deck',
              estimateMinutes: 120,
            ),
            EvalCorpusTask(
              taskId: 'task-report',
              title: 'Close the quarterly',
              estimateMinutes: 120,
            ),
          ],
          decidedTaskIds: const ['task-deck', 'task-report'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.isApplicable, isTrue);
      expect(result.passed, isFalse);
      expect(result.detail, contains('without naming a casualty'));
    });

    test('naming shortened work without a trade does not surface it', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'deck',
              startHour: 9,
              endHour: 10,
              taskId: 'task-deck',
              reason: 'Focused work on Prepare the board deck.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-deck',
              title: 'Prepare the board deck',
              estimateMinutes: 120,
            ),
          ],
          decidedTaskIds: const ['task-deck'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('without naming a casualty'));
    });

    test('does not treat a trade word inside the task title as evidence', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'migration',
              startHour: 9,
              endHour: 10,
              taskId: 'task-migration',
              reason: 'Focused work on Partial index migration.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-migration',
              title: 'Partial index migration',
              estimateMinutes: 120,
            ),
          ],
          decidedTaskIds: const ['task-migration'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('without naming a casualty'));
    });

    test('does not treat a partial index as trade evidence', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'task-c-block',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: "Focused work on task-c's partial index.",
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-c',
              title: 'C',
              estimateMinutes: 120,
            ),
          ],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('without naming a casualty'));
    });

    test('does not treat deferred revenue as trade evidence', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'task-c-block',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'task-c documents deferred revenue.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-c',
              title: 'C',
              estimateMinutes: 120,
            ),
          ],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('without naming a casualty'));
    });

    test('does not treat unscheduled maintenance as trade evidence', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'task-c-block',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'task-c documents unscheduled maintenance.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-c',
              title: 'C',
              estimateMinutes: 120,
            ),
          ],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('without naming a casualty'));
    });

    test('does not treat later reference as trade evidence', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'task-c-block',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'task-c formats notes for later reference.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-c',
              title: 'C',
              estimateMinutes: 120,
            ),
          ],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('without naming a casualty'));
    });

    test('does not treat a terminal purpose phrase as trade evidence', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'task-c-block',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'task-c formats notes for later.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-c',
              title: 'C',
              estimateMinutes: 120,
            ),
          ],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('without naming a casualty'));
    });

    test('does not treat a conflict object as a trade disposition', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'task-c-block',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'task-c resolves conflict.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-c',
              title: 'C',
              estimateMinutes: 120,
            ),
          ],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('without naming a casualty'));
    });

    test('does not treat a trade object as a trade disposition', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'task-c-block',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'task-c evaluates a trade.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-c',
              title: 'C',
              estimateMinutes: 120,
            ),
          ],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('without naming a casualty'));
    });

    for (final reason in [
      'task-c reviews trade policy.',
      'task-c carries over balances from the old ledger.',
    ]) {
      test('does not treat domain prose as trade evidence: $reason', () {
        final result = scoreSurfacedConflict(
          outcome(
            blocks: [
              block(
                id: 'task-c-block',
                startHour: 9,
                endHour: 10,
                taskId: 'task-c',
                reason: reason,
              ),
            ],
            corpus: const [
              EvalCorpusTask(
                taskId: 'task-c',
                title: 'C',
                estimateMinutes: 120,
              ),
            ],
            decidedTaskIds: const ['task-c'],
            requiresConflictSurfaced: true,
          ),
        );

        expect(result.passed, isFalse);
        expect(result.detail, contains('without naming a casualty'));
      });
    }

    test('validates a fully omitted task remainder against its estimate', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'context',
              startHour: 9,
              endHour: 10,
              reason: 'task-c: 5 minutes remain for later.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-c',
              title: 'C',
              estimateMinutes: 120,
            ),
          ],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('without naming a casualty'));
    });

    test('accepts a contracted negative-fit disclosure', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'context',
              startHour: 9,
              endHour: 10,
              reason: "task-c doesn't fit today.",
            ),
          ],
          corpus: const [EvalCorpusTask(taskId: 'task-c', title: 'C')],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c'));
    });

    test('accepts label punctuation before negative-fit disclosure', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'context',
              startHour: 9,
              endHour: 10,
              reason: 'task-c: Cannot fit today.',
            ),
          ],
          corpus: const [EvalCorpusTask(taskId: 'task-c', title: 'C')],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c'));
    });

    test('rejects a speculative fully omitted task remainder', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'context',
              startHour: 9,
              endHour: 10,
              reason: 'task-c may leave a remainder: 120 minutes.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-c',
              title: 'Core',
              estimateMinutes: 120,
            ),
          ],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('without naming a casualty'));
    });

    test('accepts a future-tense negative-fit disclosure', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'context',
              startHour: 9,
              endHour: 10,
              type: PlannedBlockType.buffer,
              reason: 'task-c will not fit today.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-c',
              title: 'C',
              estimateMinutes: 120,
            ),
          ],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c'));
    });

    test('does not bind a payload negative-fit claim to the named task', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'task-c-block',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'task-c validates that the payload cannot fit in memory.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-c',
              title: 'Core',
              estimateMinutes: 120,
            ),
          ],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('without naming a casualty'));
    });

    test('a denied disposition does not cancel a different asserted one', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'task-c-block',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'task-c was not dropped; it was deferred to tomorrow.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-c',
              title: 'Core',
              estimateMinutes: 120,
            ),
          ],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c'));
    });

    test('accepts a trade outside a task title containing a trade word', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'migration',
              startHour: 9,
              endHour: 10,
              taskId: 'task-migration',
              reason: 'Partial: Partial index migration.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-migration',
              title: 'Partial index migration',
              estimateMinutes: 120,
            ),
          ],
          decidedTaskIds: const ['task-migration'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-migration'));
    });

    test('does not combine task naming and trade across fields', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'task-c-block',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'Focused work on task-c.',
              note: 'Partial attendance only.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-c',
              title: 'C',
              estimateMinutes: 120,
            ),
          ],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('without naming a casualty'));
    });

    test('accepts a task-named trade in the note', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'task-c-block',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'Focused work.',
              note: 'task-c is partial.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-c',
              title: 'C',
              estimateMinutes: 120,
            ),
          ],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c'));
    });

    test('rejects contradictory task-named claims across fields', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'task-c-block',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'task-c is partial.',
              note: 'task-c is not partial.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-c',
              title: 'C',
              estimateMinutes: 120,
            ),
          ],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('without naming a casualty'));
    });

    test('rejects a trade retracted by full completion', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'context',
              startHour: 9,
              endHour: 10,
              reason:
                  'task-c was omitted, but it was fully scheduled after all.',
            ),
          ],
          corpus: const [EvalCorpusTask(taskId: 'task-c', title: 'Core')],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('without naming a casualty'));
    });

    test('rejects a cross-field full-completion retraction', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'context',
              startHour: 9,
              endHour: 10,
              reason: 'task-c was omitted due to capacity.',
              note: 'task-c was fully scheduled after all.',
            ),
          ],
          corpus: const [EvalCorpusTask(taskId: 'task-c', title: 'Core')],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('without naming a casualty'));
    });

    test('normalizes equivalent cross-field scheduling denials', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'context',
              startHour: 9,
              endHour: 10,
              reason: 'task-c cannot be scheduled.',
              note: "It is false that task-c can't be scheduled.",
            ),
          ],
          corpus: const [EvalCorpusTask(taskId: 'task-c', title: 'Core')],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('without naming a casualty'));
    });

    test('does not find a casualty id inside another task id', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'task-c-block',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'task-c2 is deferred.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-c',
              title: 'C',
              estimateMinutes: 120,
            ),
            EvalCorpusTask(
              taskId: 'task-c2',
              title: 'C2',
              estimateMinutes: 60,
            ),
          ],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('without naming a casualty'));
    });

    test('task binding prose alone does not disclose a shortening', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'deck',
              startHour: 9,
              endHour: 10,
              taskId: 'task-deck',
              reason: 'Focused work on task-deck for this task.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-deck',
              title: 'Prepare the board deck',
              estimateMinutes: 120,
            ),
          ],
          decidedTaskIds: const ['task-deck'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('without naming a casualty'));
    });

    test('continuity prose does not disclose a shortening', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'task-c-block',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'task-c remains scheduled as planned.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-c',
              title: 'C',
              estimateMinutes: 120,
            ),
          ],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('without naming a casualty'));
    });

    test('left-unchanged continuity does not disclose a shortening', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'task-c-block',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'task-c was left unchanged.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-c',
              title: 'C',
              estimateMinutes: 120,
            ),
          ],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('without naming a casualty'));
    });

    test('left-unfinished disposition discloses a shortening', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'task-c-block',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'task-c was left unfinished.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-c',
              title: 'C',
              estimateMinutes: 120,
            ),
          ],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c'));
    });

    test('transitive left-unfinished disposition discloses a shortening', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'task-c-block',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'task-c left some work unfinished.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-c',
              title: 'C',
              estimateMinutes: 120,
            ),
          ],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c'));
    });

    test('quantified shortening discloses a trade', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'task-c-block',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'task-c was shortened by 60 minutes.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-c',
              title: 'C',
              estimateMinutes: 120,
            ),
          ],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c'));
    });

    test('moving a block to a clock slot does not disclose a shortening', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'task-c-block',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'task-c moved to the 10:00 slot.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-c',
              title: 'C',
              estimateMinutes: 120,
            ),
          ],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('without naming a casualty'));
    });

    test('moving a task to tomorrow discloses a shortening', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'task-c-block',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'task-c moved to tomorrow.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-c',
              title: 'C',
              estimateMinutes: 120,
            ),
          ],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c'));
    });

    test('zero remainder does not disclose a shortening', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'task-c-block',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'task-c: 0 minutes remain; everything is complete.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-c',
              title: 'C',
              estimateMinutes: 120,
            ),
          ],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('without naming a casualty'));
    });

    test('does not borrow another task trade in the same reason', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'task-c-block',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'Focused work on task-c; task-d is deferred.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-c',
              title: 'C',
              estimateMinutes: 120,
            ),
            EvalCorpusTask(
              taskId: 'task-d',
              title: 'D',
              estimateMinutes: 60,
            ),
          ],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('without naming a casualty'));
    });

    test('a bare mention does not disclose a fully omitted task', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'task-deck-block',
              startHour: 9,
              endHour: 10,
              taskId: 'task-deck',
              reason:
                  'Focused on task-deck after reviewing '
                  'task-report requirements.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(taskId: 'task-deck', title: 'Deck'),
            EvalCorpusTask(taskId: 'task-report', title: 'Report'),
          ],
          decidedTaskIds: const ['task-deck', 'task-report'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('without naming a casualty'));
    });

    test('a partial claim does not disclose a fully omitted task', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'context',
              startHour: 9,
              endHour: 10,
              type: PlannedBlockType.buffer,
              reason: 'task-c is partial.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-c',
              title: 'C',
              estimateMinutes: 120,
            ),
          ],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('without naming a casualty'));
    });

    test('an avoided disposition does not disclose a fully omitted task', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'context',
              startHour: 9,
              endHour: 10,
              type: PlannedBlockType.buffer,
              reason: 'task-c avoided being omitted.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-c',
              title: 'C',
              estimateMinutes: 120,
            ),
          ],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('without naming a casualty'));
    });

    test('an avoided getting-complement does not disclose an omission', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'context',
              startHour: 9,
              endHour: 10,
              type: PlannedBlockType.buffer,
              reason: 'task-c avoided getting omitted.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-c',
              title: 'C',
              estimateMinutes: 120,
            ),
          ],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('without naming a casualty'));
    });

    test('does not borrow a meeting disposition in the same reason', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'task-c-block',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'Focused work on task-c; the meeting is deferred.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-c',
              title: 'C',
              estimateMinutes: 120,
            ),
          ],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('without naming a casualty'));
    });

    test('does not borrow a meeting claim with a task modifier', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'task-c-block',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'The meeting for task-c is partial.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-c',
              title: 'C',
              estimateMinutes: 120,
            ),
          ],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('without naming a casualty'));
    });

    test('does not borrow a scheduled meeting disposition', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'task-c-block',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  'Focused work on task-c; '
                  'the meeting is scheduled for later.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-c',
              title: 'C',
              estimateMinutes: 120,
            ),
          ],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('without naming a casualty'));
    });

    test('accepts a remainder-subject disposition', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'task-c-block',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'Focused work on task-c; the remainder is deferred.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-c',
              title: 'C',
              estimateMinutes: 120,
            ),
          ],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c'));
    });

    test('does not borrow another task future-tense trade', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'task-c-block',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'Focused work on task-c; task-d will be deferred.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-c',
              title: 'C',
              estimateMinutes: 120,
            ),
            EvalCorpusTask(
              taskId: 'task-d',
              title: 'D',
              estimateMinutes: 60,
            ),
          ],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('without naming a casualty'));
    });

    test('negated partial does not disclose a shortening', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'task-c-block',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'task-c is not partial.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-c',
              title: 'C',
              estimateMinutes: 120,
            ),
          ],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('without naming a casualty'));
    });

    for (final reason in [
      'task-c is partial; task-c is not partial.',
      'task-c is not partial; task-c is partial.',
    ]) {
      test('contradictory partial claims do not disclose: $reason', () {
        final result = scoreSurfacedConflict(
          outcome(
            blocks: [
              block(
                id: 'task-c-block',
                startHour: 9,
                endHour: 10,
                taskId: 'task-c',
                reason: reason,
              ),
            ],
            corpus: const [
              EvalCorpusTask(
                taskId: 'task-c',
                title: 'C',
                estimateMinutes: 120,
              ),
            ],
            decidedTaskIds: const ['task-c'],
            requiresConflictSurfaced: true,
          ),
        );

        expect(result.passed, isFalse);
        expect(result.detail, contains('without naming a casualty'));
      });
    }

    for (final reason in [
      'task-c conflicts with the client meeting.',
      'task-c is conflicting with the meeting.',
    ]) {
      test('accepts an inflected conflict disclosure: $reason', () {
        final result = scoreSurfacedConflict(
          outcome(
            blocks: [
              block(
                id: 'task-c-block',
                startHour: 9,
                endHour: 10,
                taskId: 'task-c',
                reason: reason,
              ),
            ],
            corpus: const [
              EvalCorpusTask(
                taskId: 'task-c',
                title: 'C',
                estimateMinutes: 120,
              ),
            ],
            decidedTaskIds: const ['task-c'],
            requiresConflictSurfaced: true,
          ),
        );

        expect(result.passed, isTrue);
        expect(result.detail, contains('task-c'));
      });
    }

    test('denied conflict does not disclose a shortening', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'task-c-block',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'There is no conflict for task-c.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-c',
              title: 'C',
              estimateMinutes: 120,
            ),
          ],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('without naming a casualty'));
    });

    test('conflict-free wording does not disclose a shortening', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'task-c-block',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'task-c uses a conflict-free schedule.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-c',
              title: 'C',
              estimateMinutes: 120,
            ),
          ],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('without naming a casualty'));
    });

    test('without-conflict wording does not disclose a shortening', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'task-c-block',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'task-c proceeds without conflict.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-c',
              title: 'Core',
              estimateMinutes: 120,
            ),
          ],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('without naming a casualty'));
    });

    test('outer negation denies a cannot-fit disclosure', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'task-c-block',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'It is not true that task-c cannot fit.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-c',
              title: 'C',
              estimateMinutes: 120,
            ),
          ],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('without naming a casualty'));
    });

    test('an unqualified cannot-fit disclosure surfaces the shortening', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'task-c-block',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'task-c cannot fit.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-c',
              title: 'C',
              estimateMinutes: 120,
            ),
          ],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c'));
    });

    test('does not find a casualty title inside another word', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'review',
              startHour: 9,
              endHour: 10,
              taskId: 'task-review',
              reason: 'Partial preview of the material; 60 minutes remain.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-review',
              title: 'Review',
              estimateMinutes: 120,
            ),
          ],
          decidedTaskIds: const ['task-review'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('without naming a casualty'));
    });

    test('does not find a casualty title inside a hyphenated task id', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'weekly',
              startHour: 9,
              endHour: 10,
              taskId: 'weekly-report',
              reason: 'Reviewed weekly-report. Deferred.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(taskId: 'task-report', title: 'Report'),
            EvalCorpusTask(taskId: 'weekly-report', title: 'Weekly'),
          ],
          decidedTaskIds: const ['task-report'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('without naming a casualty'));
    });

    test('unrelated trade prose does not disclose a shortening', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'deck',
              startHour: 9,
              endHour: 10,
              taskId: 'task-deck',
              reason: 'Focused work on Prepare the board deck.',
            ),
            block(
              id: 'buffer',
              startHour: 10,
              endHour: 11,
              type: PlannedBlockType.buffer,
              reason: 'Keep the remaining hour open for email.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-deck',
              title: 'Prepare the board deck',
              estimateMinutes: 120,
            ),
          ],
          decidedTaskIds: const ['task-deck'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('without naming a casualty'));
    });

    test('passes when the escalation actually names the conflict', () {
      final result = scoreSurfacedConflict(
        outcome(
          corpus: dropped,
          decidedTaskIds: const ['task-deck', 'task-report'],
          requiresConflictSurfaced: true,
          toolCalls: const [
            EvalToolCall(
              name: 'raise_day_status',
              accepted: true,
              arguments: {
                'status': 'attentionNeeded',
                'reasons': ['overCommitted'],
              },
            ),
          ],
        ),
      );

      expect(result.passed, isTrue);
    });

    test('an onTrack status is not an escalation', () {
      // The tool accepts onTrack and dayClosed too; matching the call by name
      // alone would let a model satisfy this by reporting the day is fine.
      final result = scoreSurfacedConflict(
        outcome(
          corpus: dropped,
          decidedTaskIds: const ['task-deck', 'task-report'],
          requiresConflictSurfaced: true,
          toolCalls: const [
            EvalToolCall(
              name: 'raise_day_status',
              accepted: true,
              arguments: {'status': 'onTrack'},
            ),
          ],
        ),
      );

      expect(result.passed, isFalse);
    });

    test('a reason that cannot be true of this day is not an escalation', () {
      // The scenario seeds no directive, so escalating as
      // directiveUnsatisfiable claims something false. A shared default
      // accepting both reasons would have credited it.
      final result = scoreSurfacedConflict(
        outcome(
          corpus: dropped,
          decidedTaskIds: const ['task-deck', 'task-report'],
          requiresConflictSurfaced: true,
          // ignore: avoid_redundant_argument_values
          conflictEscalationReasons: const {'overCommitted'},
          toolCalls: const [
            EvalToolCall(
              name: 'raise_day_status',
              accepted: true,
              arguments: {
                'status': 'attentionNeeded',
                'reasons': ['directiveUnsatisfiable'],
              },
            ),
          ],
        ),
      );

      expect(result.passed, isFalse);
    });

    test('an unrelated attentionNeeded reason is not an escalation', () {
      final result = scoreSurfacedConflict(
        outcome(
          corpus: dropped,
          decidedTaskIds: const ['task-deck', 'task-report'],
          requiresConflictSurfaced: true,
          toolCalls: const [
            EvalToolCall(
              name: 'raise_day_status',
              accepted: true,
              arguments: {
                'status': 'attentionNeeded',
                'reasons': ['processingBlocked'],
              },
            ),
          ],
        ),
      );

      expect(
        result.passed,
        isFalse,
        reason: 'processingBlocked describes a different problem entirely',
      );
    });

    test('a rejected escalation does not count', () {
      final result = scoreSurfacedConflict(
        outcome(
          corpus: dropped,
          decidedTaskIds: const ['task-deck', 'task-report'],
          requiresConflictSurfaced: true,
          toolCalls: const [
            EvalToolCall(
              name: 'raise_day_status',
              accepted: false,
              arguments: {
                'status': 'attentionNeeded',
                'reasons': ['overCommitted'],
              },
            ),
          ],
        ),
      );

      expect(result.passed, isFalse);
    });

    test('is not applicable when the day is satisfiable', () {
      expect(scoreSurfacedConflict(outcome()).isApplicable, isFalse);
    });
  });

  group('a run that produced no plan', () {
    test('scores every plan-reading constraint as inapplicable', () {
      // An empty block list would otherwise read as "no overlaps, nothing
      // fabricated, every omission honoured" — a clean sweep for a failed run.
      final results = scoreAll(
        outcome(
          planPersisted: false,
          decidedTaskIds: const ['task-1'],
          expectedOmissions: const {'task-stale'},
          requiredTaskIds: const {'task-1'},
          corpus: const [EvalCorpusTask(taskId: 'task-1', title: 'A')],
        ),
      );

      for (final result in results) {
        if (result.id == EvalConstraintIds.compliedWithoutRejection) continue;
        expect(
          result.isApplicable,
          isFalse,
          reason: '${result.id} credited a run that produced no plan',
        );
      }
    });
  });

  group('noFabricatedCalendarBlocks', () {
    PlannedBlock calendarBlock({
      String id = 'cal-1',
      int startHour = 9,
      int endHour = 11,
    }) => PlannedBlock(
      id: id,
      categoryId: 'cat-1',
      startTime: DateTime(2026, 7, 18, startHour),
      endTime: DateTime(2026, 7, 18, endHour),
      title: id,
      type: PlannedBlockType.cal,
    );

    test('a real plan with no calendar claim passes', () {
      // The prompt explicitly offers `cal` as the way to place work before the
      // current time, so declining it is the behaviour being measured. If this
      // were merely inapplicable the constraint could only ever be n/a or fail
      // and would never show a success rate.
      final result = scoreNoFabricatedCalendarBlocks(
        outcome(blocks: [block(id: 'b1', startHour: 9, endHour: 10)]),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('none claiming to be a calendar event'));
    });

    test('a plan with no blocks at all is not applicable', () {
      final result = scoreNoFabricatedCalendarBlocks(outcome());

      expect(result.isApplicable, isFalse);
      expect(result.detail, contains('no blocks'));
    });

    test('any calendar block fails, because there is no calendar to mirror', () {
      // The day agent is shown no calendar events at all — `calendarBlocks` is
      // a deferred parameter RealDayAgent drops — so a `cal` block asserts an
      // import that never happened, and the plan editor will then refuse to
      // let the user edit it here.
      final result = scoreNoFabricatedCalendarBlocks(
        outcome(blocks: [calendarBlock(startHour: 14, endHour: 15)]),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('no calendar to mirror'));
      expect(result.detail, contains('14:00'));
    });

    test('names the past-start guard when the block predates the draft', () {
      // This is the case the constraint exists for: `cal` is the only type the
      // parser exempts from the same-day past-start guard, so it is how a
      // model plans the past without being rejected.
      final result = scoreNoFabricatedCalendarBlocks(
        outcome(
          // ignore: avoid_redundant_argument_values — the hours are the point
          blocks: [calendarBlock(startHour: 9, endHour: 11)],
          now: DateTime(2026, 7, 18, 15),
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('past-start guard'));
      expect(result.detail, contains('09:00'));
    });

    test('a dropped calendar block is still a fabricated claim', () {
      // Dropping declines the *work*; it does not retract the claim that an
      // external event exists. The block is still persisted, still projected
      // (only the capacity meter filters dropped), still drawn on the
      // timeline, and still refused by the plan editor — so the user sees an
      // uneditable phantom calendar event either way.
      final result = scoreNoFabricatedCalendarBlocks(
        outcome(
          blocks: [
            PlannedBlock(
              id: 'cal-dropped',
              categoryId: 'cat-1',
              startTime: DateTime(2026, 7, 18, 9),
              endTime: DateTime(2026, 7, 18, 10),
              title: 'cal-dropped',
              type: PlannedBlockType.cal,
              state: PlannedBlockState.dropped,
            ),
          ],
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('cal-dropped'));
    });

    test('blames the state, not the type, when the block is not drafted', () {
      // The guard fires only for `state == drafted`, so a committed block
      // would have slipped through as `ai` or `manual` too. Blaming `cal`
      // here would point a reader at the wrong fix.
      final result = scoreNoFabricatedCalendarBlocks(
        outcome(
          blocks: [
            PlannedBlock(
              id: 'cal-committed',
              categoryId: 'cat-1',
              startTime: DateTime(2026, 7, 18, 9),
              endTime: DateTime(2026, 7, 18, 11),
              title: 'cal-committed',
              type: PlannedBlockType.cal,
              state: PlannedBlockState.committed,
            ),
          ],
          now: DateTime(2026, 7, 18, 15),
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('the state bypassed it here'));
      expect(
        result.detail,
        isNot(contains('exempts `cal`')),
        reason: 'the calendar exemption is not what let this through',
      );
    });

    test('is inapplicable when no plan was persisted', () {
      final result = scoreNoFabricatedCalendarBlocks(
        outcome(planPersisted: false),
      );

      expect(result.isApplicable, isFalse);
    });

    test('catches what withinWorkingHours reports as a different failure', () {
      // Both fire on the same block, and that is the point: the working-hours
      // constraint already detected it, but attributed it to a time-window
      // violation. A report that only said "outside working hours" would send
      // someone to fix the wrong thing.
      final subject = outcome(
        // ignore: avoid_redundant_argument_values — the hours are the point
        blocks: [calendarBlock(startHour: 9, endHour: 11)],
        now: DateTime(2026, 7, 18, 15),
      );

      expect(scoreWithinWorkingHours(subject).passed, isFalse);
      expect(scoreNoFabricatedCalendarBlocks(subject).passed, isFalse);
      expect(
        scoreNoFabricatedCalendarBlocks(subject).detail,
        isNot(contains('outside')),
      );
    });
  });

  group('directiveHonoured', () {
    const commitments = [
      EvalDirectiveCommitment(
        id: 'commit-deck',
        title: 'Prepare the board deck',
        minutes: 180,
      ),
      EvalDirectiveCommitment(
        id: 'commit-1-1s',
        title: 'Run the weekly 1:1s',
        minutes: 90,
      ),
    ];
    const directive = EvalDirective(
      commitments: commitments,
      availableMinutes: 240,
    );

    PlannedBlock titled(String title, {String? reason}) => PlannedBlock(
      id: title,
      categoryId: 'cat-1',
      startTime: DateTime(2026, 7, 18, 9),
      endTime: DateTime(2026, 7, 18, 12),
      title: title,
      reason: reason,
    );

    test('is not applicable when the wake was given no directive', () {
      final result = scoreDirectiveHonoured(outcome());

      expect(result.isApplicable, isFalse);
      expect(result.detail, contains('no directive'));
    });

    test('fails when a commitment is dropped without a word', () {
      // Nothing in the write path enforces the directive — it is prompt text
      // and the plan writer never reads it back — so a dropped commitment
      // persists a clean-looking plan.
      final result = scoreDirectiveHonoured(
        outcome(
          blocks: [titled('Prepare the board deck')],
          directive: directive,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('commit-1-1s'));
      expect(
        result.detail,
        contains('dropped without a word'),
        reason: 'the report has to say which commitment vanished',
      );
    });

    test('passes when every commitment is represented in the plan', () {
      final result = scoreDirectiveHonoured(
        outcome(
          blocks: [
            titled('Prepare the board deck'),
            titled('Run the weekly 1:1s'),
          ],
          directive: directive,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('represented'));
    });

    test('accepts a commitment named only in a block reason', () {
      // A commitment can be honoured inside other work; the prompt asks for
      // it to be represented, not to be its own titled block.
      final result = scoreDirectiveHonoured(
        outcome(
          blocks: [
            titled('Prepare the board deck'),
            titled('Leadership block', reason: 'Covers commit-1-1s.'),
          ],
          directive: directive,
        ),
      );

      expect(result.passed, isTrue);
    });

    test('escalation answers for every commitment left unplaced', () {
      // Escalation is directive-level: a model that says the orders cannot be
      // satisfied has answered for all of them, which is what the prompt asks.
      final result = scoreDirectiveHonoured(
        outcome(
          blocks: [titled('Prepare the board deck')],
          directive: directive,
          toolCalls: const [
            EvalToolCall(
              name: 'raise_day_status',
              accepted: true,
              arguments: {
                'status': 'attentionNeeded',
                'reasons': ['directiveUnsatisfiable'],
              },
            ),
          ],
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('escalated'));
    });

    test('an escalation under a different reason is not silence', () {
      // From the live runs: glm-5.2 raised attentionNeeded with reason
      // `overCommitted` and a note naming the casualties in plain words
      // ("Interviews and 1:1s cannot fit"). Scoring that as SILENTLY DROPPED
      // accused it of the one thing it visibly did not do. The reason-label
      // gap is real but far weaker, so it is reported, not failed.
      final result = scoreDirectiveHonoured(
        outcome(
          blocks: [titled('Prepare the board deck')],
          directive: directive,
          toolCalls: const [
            EvalToolCall(
              name: 'raise_day_status',
              accepted: true,
              arguments: {
                'status': 'attentionNeeded',
                'reasons': ['overCommitted'],
                'note': 'Interviews and 1:1s cannot fit — defer one.',
              },
            ),
          ],
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('not under the directiveUnsatisfiable'));
    });

    test('a bare escalation with no note answers for nothing', () {
      // The hole the previous version left: any accepted attentionNeeded with
      // an allowlisted reason credited every commitment, so a model could drop
      // all three and pass on a day-level remark that never mentions the
      // directive. Under a reason other than the prompt's, the call has to
      // carry a note.
      final result = scoreDirectiveHonoured(
        outcome(
          blocks: [titled('Prepare the board deck')],
          directive: directive,
          toolCalls: const [
            EvalToolCall(
              name: 'raise_day_status',
              accepted: true,
              arguments: {
                'status': 'attentionNeeded',
                'reasons': ['overCommitted'],
              },
            ),
          ],
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('commit-1-1s'));
    });

    test('the prompt reason needs no note to speak for itself', () {
      final result = scoreDirectiveHonoured(
        outcome(
          blocks: [titled('Prepare the board deck')],
          directive: directive,
          toolCalls: const [
            EvalToolCall(
              name: 'raise_day_status',
              accepted: true,
              arguments: {
                'status': 'attentionNeeded',
                'reasons': ['directiveUnsatisfiable'],
              },
            ),
          ],
        ),
      );

      expect(result.passed, isTrue);
    });

    test('silence with no escalation at all still fails', () {
      final result = scoreDirectiveHonoured(
        outcome(
          blocks: [titled('Prepare the board deck')],
          directive: directive,
          toolCalls: const [
            EvalToolCall(name: 'record_observations', accepted: true),
          ],
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('commit-1-1s'));
    });

    test('a rejected or unrelated escalation does not answer for anything', () {
      for (final call in const [
        EvalToolCall(
          name: 'raise_day_status',
          accepted: false,
          arguments: {
            'status': 'attentionNeeded',
            'reasons': ['directiveUnsatisfiable'],
          },
        ),
        EvalToolCall(
          name: 'raise_day_status',
          accepted: true,
          arguments: {
            // Says the pipeline is stuck; answers for no commitment.
            'status': 'attentionNeeded',
            'reasons': ['processingBlocked'],
          },
        ),
        EvalToolCall(
          name: 'raise_day_status',
          accepted: true,
          arguments: {
            'status': 'onTrack',
            'reasons': ['directiveUnsatisfiable'],
          },
        ),
      ]) {
        final result = scoreDirectiveHonoured(
          outcome(
            blocks: [titled('Prepare the board deck')],
            directive: directive,
            toolCalls: [call],
          ),
        );

        expect(
          result.passed,
          isFalse,
          reason:
              'status=${call.arguments['status']} accepted=${call.accepted}',
        );
      }
    });

    test('a trade must name the commitment it collides with', () {
      // The prompt says the diff's reason names the colliding commitment.
      // "Traded something away" without saying what gives the user nothing.
      final vague = scoreDirectiveHonoured(
        outcome(
          blocks: [titled('Prepare the board deck')],
          directive: directive,
          toolCalls: const [
            EvalToolCall(
              name: 'propose_plan_diff',
              accepted: true,
              arguments: {
                'changes': [
                  {'action': 'dropped', 'reason': 'Something had to give.'},
                ],
              },
            ),
          ],
        ),
      );
      final named = scoreDirectiveHonoured(
        outcome(
          blocks: [titled('Prepare the board deck')],
          directive: directive,
          toolCalls: const [
            EvalToolCall(
              name: 'propose_plan_diff',
              accepted: true,
              arguments: {
                'changes': [
                  {
                    'action': 'dropped',
                    'reason':
                        'Run the weekly 1:1s collides with the board deck.',
                  },
                ],
              },
            ),
          ],
        ),
      );

      expect(vague.passed, isFalse);
      expect(named.passed, isTrue);
      expect(named.detail, contains('traded'));
    });

    test('a dropped block does not count as representing a commitment', () {
      // Dropping is the model declining the work, which is the opposite of
      // honouring the order.
      final result = scoreDirectiveHonoured(
        outcome(
          blocks: [
            PlannedBlock(
              id: 'b1',
              categoryId: 'cat-1',
              startTime: DateTime(2026, 7, 18, 9),
              endTime: DateTime(2026, 7, 18, 12),
              title: 'Prepare the board deck',
              state: PlannedBlockState.dropped,
            ),
            titled('Run the weekly 1:1s'),
          ],
          directive: directive,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('commit-deck'));
    });
  });

  group('scoreAll', () {
    test('returns every constraint in report order', () {
      final results = scoreAll(outcome());

      expect(
        results.map((result) => result.id),
        EvalConstraintIds.all,
        reason:
            'a constraint dropped from scoreAll would silently stop being '
            'measured while the report still looked complete',
      );
    });

    test('marks inapplicable constraints rather than passing them', () {
      // An empty plan must not read as a clean sweep — that would make the
      // laziest possible model look like the best one.
      final results = scoreAll(outcome());

      expect(
        results.where((result) => result.isApplicable),
        isEmpty,
        reason:
            'an empty run demonstrates nothing at all — including about '
            'compliance, which it never attempted',
      );
    });
  });
}
