import 'package:flutter_test/flutter_test.dart';
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
    String? reason,
    String? title,
    PlannedBlockState state = PlannedBlockState.drafted,
  }) => PlannedBlock(
    id: id,
    categoryId: 'cat-1',
    startTime: DateTime(2026, 7, 18, startHour),
    endTime: DateTime(2026, 7, 18, endHour),
    taskId: taskId,
    reason: reason,
    title: title ?? id,
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
    ),
    blocks: blocks,
    toolCalls: toolCalls,
    planPersisted: planPersisted,
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
          ],
          corpus: tasks,
        ),
      );

      expect(result.passed, isTrue);
    });
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

    test('a plan claiming no calendar events is not applicable', () {
      final result = scoreNoFabricatedCalendarBlocks(
        outcome(blocks: [block(id: 'b1', startHour: 9, endHour: 10)]),
      );

      expect(result.isApplicable, isFalse);
      expect(result.detail, contains('no calendar events'));
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

    test('reports a dropped calendar block as no claim at all', () {
      // A dropped block is the model declining, and production excludes it
      // from the day; scoring it would punish the right call.
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

      expect(result.isApplicable, isFalse);
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
        results.where((result) => result.isApplicable).map((r) => r.id),
        [EvalConstraintIds.compliedWithoutRejection],
      );
    });
  });
}
