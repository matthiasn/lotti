import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';

import 'eval_constraints.dart';
import 'eval_constraints_test_helpers.dart';
import 'eval_models.dart';

void main() {
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
}
