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
      visibleTaskIds: visibleTaskIds,
      workingHoursEndHour: workingHoursEndHour,
      capacityMinutes: capacityMinutes,
    ),
    blocks: blocks,
    toolCalls: toolCalls,
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
