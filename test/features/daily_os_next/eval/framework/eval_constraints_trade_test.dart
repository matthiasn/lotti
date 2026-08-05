import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';

import 'eval_constraints.dart';
import 'eval_constraints_test_helpers.dart';
import 'eval_models.dart';

void main() {
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
          now: DateTime(2026, 7, 18, 8),
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

    test('accepts since after an omitted task disposition', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'context',
              startHour: 9,
              endHour: 10,
              reason: 'task-c was omitted since the day was full.',
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

    test('accepts a postponed task as a deferred casualty', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'context',
              startHour: 9,
              endHour: 10,
              reason: 'task-c was postponed due to capacity.',
            ),
          ],
          corpus: const [EvalCorpusTask(taskId: 'task-c', title: 'Core')],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, allOf(contains('task-c'), contains('deferred')));
    });

    test('accepts an unavoidable-choice omission', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'context',
              startHour: 9,
              endHour: 10,
              reason: 'We had no choice but to omit task-c due to capacity.',
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

    test('accepts a task id as an active omission object', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'context',
              startHour: 9,
              endHour: 10,
              reason: 'We omitted task-c due to capacity.',
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

    test('rejects a possessive non-task head as an omission object', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'context',
              startHour: 9,
              endHour: 10,
              reason: "We omitted task-c's meeting due to capacity.",
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

    test('rejects an imperative omission object', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'context',
              startHour: 9,
              endHour: 10,
              reason: 'Omit task-c due to capacity.',
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

    test('accepts a task id in a coordinated active omission object', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'context',
              startHour: 9,
              endHour: 10,
              reason: 'We omitted task-a and task-c due to capacity.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(taskId: 'task-a', title: 'Alpha'),
            EvalCorpusTask(taskId: 'task-c', title: 'Core'),
          ],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c'));
    });

    test('accepts a full task title as an active omission object', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'context',
              startHour: 9,
              endHour: 10,
              reason: 'We omitted Core due to capacity.',
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

    test('accepts an exact task title that is also a non-task head', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'context',
              startHour: 9,
              endHour: 10,
              reason: 'Meeting was omitted due to capacity.',
            ),
          ],
          corpus: const [EvalCorpusTask(taskId: 'task-c', title: 'Meeting')],
          decidedTaskIds: const ['task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, contains('task-c'));
    });

    test('accepts an affirmative adverb after an omitted disposition', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'context',
              startHour: 9,
              endHour: 10,
              reason: 'task-c was omitted entirely due to capacity.',
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

    test('accepts coordinated task omission subjects', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'context',
              startHour: 9,
              endHour: 10,
              reason: 'task-c and task-d were omitted due to capacity.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(taskId: 'task-c', title: 'Core'),
            EvalCorpusTask(taskId: 'task-d', title: 'Dependency'),
          ],
          decidedTaskIds: const ['task-c', 'task-d'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isTrue);
      expect(result.detail, allOf(contains('task-c'), contains('task-d')));
    });

    test('accepts an Oxford-comma task omission subject', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'context',
              startHour: 9,
              endHour: 10,
              reason:
                  'task-a, task-b, and task-c were omitted due to capacity.',
            ),
          ],
          corpus: const [
            EvalCorpusTask(taskId: 'task-a', title: 'Alpha'),
            EvalCorpusTask(taskId: 'task-b', title: 'Beta'),
            EvalCorpusTask(taskId: 'task-c', title: 'Core'),
          ],
          decidedTaskIds: const ['task-a', 'task-b', 'task-c'],
          requiresConflictSurfaced: true,
        ),
      );

      expect(result.passed, isTrue);
      expect(
        result.detail,
        allOf(contains('task-a'), contains('task-b'), contains('task-c')),
      );
    });

    test('rejects a historical omitted-task disclosure', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'context',
              startHour: 9,
              endHour: 10,
              reason: 'Yesterday, task-c was omitted due to capacity.',
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

    test('preserves a scheduling omission before causal negation', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'context',
              startHour: 9,
              endHour: 10,
              reason: 'task-c cannot be scheduled because no time remains.',
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
      'could not be scheduled',
      'will not be scheduled',
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

    test('rejects neither-nor trade dispositions', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'context',
              startHour: 9,
              endHour: 10,
              reason: 'task-c was neither omitted nor deferred.',
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
      'task-c denied being omitted.',
      'task-c requires deferring.',
      'task-c was almost omitted.',
      'task-c was supposed to be omitted.',
      'task-c was meant to be omitted.',
      'task-c was going to be omitted.',
      'task-c considered deferring.',
      'task-c is likely to be omitted.',
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

    test('rejects a long-form negated trade complement', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'context',
              startHour: 9,
              endHour: 10,
              reason: 'task-c never actually got around to omitting the task.',
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

    test('rejects an interrogative trade disclosure', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'context',
              startHour: 9,
              endHour: 10,
              reason: 'Was task-c omitted?',
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

    test('does not treat plural conflict objects as trade dispositions', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'task-c-block',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'task-c resolves conflicts.',
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

    test('accepts a task-bound scheduling-conflict noun', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'task-c-block',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'task-c has a scheduling conflict with the meeting.',
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

    test('tomorrow is not a deferral on a future-day plan', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'context',
              startHour: 9,
              endHour: 10,
              reason: 'task-c is scheduled for tomorrow.',
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

    test('rejects a fully omitted remainder owned by an object complement', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'context',
              startHour: 9,
              endHour: 10,
              reason: 'task-c reviews a recording with 120 minutes remaining.',
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

    test('ends negation at a contrastive replacement disposition', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'context',
              startHour: 9,
              endHour: 10,
              reason: 'task-c was not dropped but deferred to a later day.',
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

    test('normalizes synonymous cross-field omission denials', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'context',
              startHour: 9,
              endHour: 10,
              reason: 'task-c was omitted due to capacity.',
              note: 'task-c was not left out after all.',
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

    test('normalizes equivalent inability scheduling denials', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'context',
              startHour: 9,
              endHour: 10,
              reason: 'task-c was unable to be scheduled.',
              note: 'It is false that task-c was unable to be scheduled.',
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

    test('denied left-out does not cancel left-unfinished', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'task-c-block',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason:
                  'task-c was not left out; '
                  'task-c was left unfinished.',
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
          now: DateTime(2026, 7, 18, 8),
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

    test('does not borrow a future meeting scheduling denial', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'task-c-block',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'task-c notes that the meeting will not be scheduled.',
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

    test('outer falsehood denies a positive conflict disclosure', () {
      final result = scoreSurfacedConflict(
        outcome(
          blocks: [
            block(
              id: 'task-c-block',
              startHour: 9,
              endHour: 10,
              taskId: 'task-c',
              reason: 'It is false that task-c conflicts.',
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
}
