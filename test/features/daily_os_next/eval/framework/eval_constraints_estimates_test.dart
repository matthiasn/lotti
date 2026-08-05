import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/day_plan.dart';

import 'eval_constraints.dart';
import 'eval_constraints_test_helpers.dart';
import 'eval_models.dart';

void main() {
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

    const thirdPersonAllocationPredicates = [
      'schedules',
      'allocates',
      'completes',
      'plans',
      'places',
    ];
    for (final allocationPredicate in thirdPersonAllocationPredicates) {
      test('accepts third-person $allocationPredicate split evidence', () {
        final result = scoreWithinCapacityByEstimate(
          outcome(
            blocks: [
              block(
                id: 'partial',
                startHour: 9,
                endHour: 10,
                taskId: 'task-c',
                reason:
                    'task-c $allocationPredicate 60 of 120 minutes for today.',
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

    for (final allocationPredicate in thirdPersonAllocationPredicates) {
      test(
        'rejects third-person $allocationPredicate with a full contradiction',
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
                      'task-c $allocationPredicate 60 of 120 minutes for today. '
                      'task-c fully $allocationPredicate all 120 minutes '
                      'after all.',
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
    }

    for (final allocationPredicate in thirdPersonAllocationPredicates) {
      test(
        'rejects a directly denied third-person $allocationPredicate claim',
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
                      'task-c $allocationPredicate 60 of 120 minutes for today. '
                      'task-c never $allocationPredicate the task after all.',
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
    }

    for (final allocationPredicate in thirdPersonAllocationPredicates) {
      test(
        'rejects non-task subject $allocationPredicate split evidence',
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
                      'The coordinator $allocationPredicate '
                      '60 of 120 minutes for today.',
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
    }

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

    test('rejects a numeric suffix inside a formatted remainder', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'Partial: 1,060 minutes remain for later.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    test('rejects a positive match inside a negative remainder', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'Partial: -60 minutes remain for later.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
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

    test('rejects a likely-to allocation action', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'task-c is likely to schedule 60 of 120 minutes.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    test('rejects counterfactual allocation evidence', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  'If task-c were scheduled for 60 of 120 minutes, '
                  'but it was not.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    test('rejects future-dated allocation evidence', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'task-c will schedule 60 of 120 minutes next week.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
          now: DateTime(2026, 7, 18, 8),
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    test('rejects tomorrow-dated allocation evidence on a same-day run', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'task-c will schedule 60 of 120 minutes tomorrow.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
          now: DateTime(2026, 7, 18, 8),
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    test('accepts tomorrow allocation evidence on a future-day run', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'task-c will schedule 60 of 120 minutes tomorrow.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c 60min partial of 120min'));
    });

    test('rejects imperative allocation evidence', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'Schedule for 60 of 120 minutes.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    test('ignores a negator inside the current task title', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  'No-code prototype scheduled 60 of 120 minutes for today.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-c',
              title: 'No-code prototype',
              estimateMinutes: 120,
            ),
          ],
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c 60min partial of 120min'));
    });

    test('ignores a title-contained negator for a partial label', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  'No-code prototype is partial; '
                  '60 minutes remain for later.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-c',
              title: 'No-code prototype',
              estimateMinutes: 120,
            ),
          ],
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c 60min partial of 120min'));
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

    test('rejects a supposed-to allocation action', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'task-c was supposed to schedule 60 of 120 minutes.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    test('rejects a meant-to allocation action', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'task-c was meant to schedule 60 of 120 minutes.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    test('rejects a going-to allocation action', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'task-c was going to schedule 60 of 120 minutes.',
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

    test('rejects a trailing allocation failure qualifier', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  'task-c: 60 of 120 minutes were scheduled unsuccessfully.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

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

    test('rejects a failed action after the allocation arithmetic', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  'task-c scheduled 60 of 120 minutes, but failed to '
                  'allocate the task.',
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

    test('ignores a postpositive non-task allocation failure', () {
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
                  'failed for the meeting.',
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

    test('rejects a considered allocation action', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'task-c considered scheduling 60 of 120 minutes.',
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

    test('accepts for directly introducing allocation arithmetic', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'task-c was scheduled for 60 of 120 minutes.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c 60min partial of 120min'));
    });

    test('keeps declarative evidence before a trailing question', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  'task-c scheduled 60 of 120 minutes, '
                  'but why force the rest?',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c 60min partial of 120min'));
    });

    for (final historicalScope in ['yesterday', 'last week']) {
      test('rejects allocation arithmetic scoped to $historicalScope', () {
        final result = scoreWithinCapacityByEstimate(
          outcome(
            blocks: [
              block(
                id: 'partial',
                startHour: 9,
                endHour: 10,
                taskId: 'task-c',
                reason:
                    'task-c was scheduled 60 of 120 minutes '
                    '$historicalScope.',
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

    test('rejects a leading historical allocation scope', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'Yesterday, task-c scheduled 60 of 120 minutes.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
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

    test('does not treat an allocation verb inside a task id as evidence', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-fit',
              reason: 'task-fit 60 of 120 minutes.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-fit',
              title: 'Core',
              estimateMinutes: 120,
            ),
          ],
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-fit allocated 60min of 120min'));
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

    test('rejects a numeric remainder owned by an object complement', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  'Partial; task-c reviews a recording with '
                  '60 minutes remaining.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    test('rejects a numeric remainder owned by an unrelated subject', () {
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
                  'the battery shows 60 minutes remaining.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    test('rejects split arithmetic owned by an object complement', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  'task-c reviews a meeting with '
                  '60 of 120 minutes scheduled.',
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

    test('an outer falsehood split note vetoes partial credit', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'task-c scheduled 60 of 120 minutes.',
              note: 'It is false that task-c scheduled 60 of 120 minutes.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    for (final auditBlock
        in <
          ({
            String label,
            PlannedBlockType type,
            String? taskId,
          })
        >[
          (
            label: 'another task',
            type: PlannedBlockType.ai,
            taskId: 'task-d',
          ),
          (
            label: 'a buffer',
            type: PlannedBlockType.buffer,
            taskId: null,
          ),
        ]) {
      test(
        'a task-named note on ${auditBlock.label} vetoes partial credit',
        () {
          final result = scoreWithinCapacityByEstimate(
            outcome(
              blocks: [
                block(
                  id: 'partial',
                  startHour: 9,
                  endHour: 10,
                  taskId: 'task-c',
                  reason: 'task-c scheduled 60 of 120 minutes.',
                ),
                block(
                  id: 'audit-block',
                  startHour: 10,
                  endHour: 11,
                  type: auditBlock.type,
                  taskId: auditBlock.taskId,
                  reason: 'Plan context.',
                  note: 'task-c was not scheduled after all.',
                ),
              ],
              corpus: const [
                EvalCorpusTask(
                  taskId: 'task-c',
                  title: 'Core',
                  estimateMinutes: 120,
                ),
                EvalCorpusTask(
                  taskId: 'task-d',
                  title: 'Dependency',
                  estimateMinutes: 60,
                ),
              ],
              capacityMinutes: 120,
            ),
          );

          expect(result.passed, isFalse);
          expect(result.detail, contains('task-c allocated 60min of 120min'));
        },
      );
    }

    test('a task-named reason on another block vetoes partial credit', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'task-c scheduled 60 of 120 minutes.',
            ),
            block(
              id: 'other-task',
              startHour: 10,
              endHour: 11,
              taskId: 'task-d',
              reason: 'task-c was fully scheduled after all.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(
              taskId: 'task-c',
              title: 'Core',
              estimateMinutes: 120,
            ),
            EvalCorpusTask(
              taskId: 'task-d',
              title: 'Dependency',
              estimateMinutes: 60,
            ),
          ],
          capacityMinutes: 120,
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

    test('a postpositive full-completion note vetoes partial credit', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'task-c scheduled 60 of 120 minutes.',
              note: 'task-c was scheduled in full after all.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isFalse);
      expect(result.detail, contains('task-c allocated 60min of 120min'));
    });

    test('a historical full-completion note preserves partial credit', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'task-c scheduled 60 of 120 minutes.',
              note: 'task-c was fully scheduled yesterday.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c 60min partial of 120min'));
    });

    test('a historical allocation denial preserves current partial credit', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'task-c scheduled 60 of 120 minutes.',
              note: 'task-c was not scheduled yesterday.',
            ),
          ],
          corpus: tasks,
          capacityMinutes: 60,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c 60min partial of 120min'));
    });

    test(
      'an outer falsehood full-completion note preserves partial credit',
      () {
        final result = scoreWithinCapacityByEstimate(
          outcome(
            blocks: [
              block(
                id: 'partial',
                startHour: 9,
                endHour: 10,
                taskId: 'task-c',
                reason: '60 of 120 minutes are scheduled.',
                note: 'It is false that task-c was fully scheduled.',
              ),
            ],
            corpus: tasks,
            capacityMinutes: 60,
          ),
        );

        expect(result.passed, isTrue);
        expect(result.detail, contains('task-c 60min partial of 120min'));
      },
    );

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

    test('a fully planned possessive day note preserves partial credit', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: '60 of 120 minutes are scheduled.',
              note: 'Fully planned our day.',
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

    test('a possessive task meeting cannot own allocation arithmetic', () {
      final result = scoreWithinCapacityByEstimate(
        outcome(
          blocks: [
            block(
              id: 'partial',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: "task-c's meeting has 60 of 120 minutes scheduled.",
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
}
