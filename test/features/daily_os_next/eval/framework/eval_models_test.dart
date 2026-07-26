import 'package:flutter_test/flutter_test.dart';

import 'eval_models.dart';

/// Direct coverage for the eval value types.
///
/// These carry real semantics — ADR 0043's blocked predicate, the difference
/// between what is true and what the model was shown — so they are tested
/// here rather than incidentally through whichever consumer happens to touch
/// them.
void main() {
  final planDate = DateTime(2026, 7, 18);

  EvalFixtureInputs inputs({
    List<EvalCorpusTask> corpus = const [],
    List<String> decidedTaskIds = const [],
    Set<String>? visibleTaskIds,
  }) => EvalFixtureInputs(
    dayId: 'dayplan-2026-07-18',
    planDate: planDate,
    corpus: corpus,
    decidedTaskIds: decidedTaskIds,
    visibleTaskIds: visibleTaskIds,
  );

  group('EvalCorpusTask.isBlocked', () {
    test('a task with blockers is blocked', () {
      const task = EvalCorpusTask(
        taskId: 'task-1',
        title: 'Ship it',
        blockedBy: ['task-0'],
      );

      expect(task.isBlocked, isTrue);
    });

    test('a BLOCKED status with no links is still blocked', () {
      // ADR 0043's predicate is a union. A manually blocked task carries no
      // typed links, and absence of blockedBy means link-ready, not free to
      // schedule.
      const task = EvalCorpusTask(
        taskId: 'task-1',
        title: 'Ship it',
        status: 'BLOCKED',
      );

      expect(task.isBlocked, isTrue);
    });

    test('status matching is case-insensitive', () {
      const task = EvalCorpusTask(
        taskId: 'task-1',
        title: 'Ship it',
        status: 'blocked',
      );

      expect(task.isBlocked, isTrue);
    });

    test('an ordinary open task is not blocked', () {
      const task = EvalCorpusTask(taskId: 'task-1', title: 'Ship it');

      expect(task.isBlocked, isFalse);
    });
  });

  group('EvalFixtureInputs.taskById', () {
    test('finds a seeded task', () {
      final found = inputs(
        corpus: const [EvalCorpusTask(taskId: 'task-1', title: 'Ship it')],
      ).taskById('task-1');

      expect(found?.title, 'Ship it');
    });

    test('returns null for an id the fixture never seeded', () {
      expect(inputs().taskById('nope'), isNull);
    });
  });

  group('EvalFixtureInputs.referenceableTaskIds', () {
    test('defaults to the whole corpus plus decided tasks', () {
      final referenceable = inputs(
        corpus: const [EvalCorpusTask(taskId: 'task-corpus', title: 'A')],
        decidedTaskIds: const ['task-decided'],
      ).referenceableTaskIds;

      expect(referenceable, {'task-corpus', 'task-decided'});
    });

    test('collapses to the explicit set when the corpus was not shown', () {
      // The corpus is rendered only inside the capture context, so a wake
      // without one can name nothing but its decided tasks — while the corpus
      // itself stays available as ground truth.
      final subject = inputs(
        corpus: const [EvalCorpusTask(taskId: 'task-hidden', title: 'A')],
        decidedTaskIds: const ['task-decided'],
        visibleTaskIds: const {'task-decided'},
      );

      expect(subject.referenceableTaskIds, {'task-decided'});
      expect(subject.taskById('task-hidden'), isNotNull);
    });

    test('includes blockers a visible task names through blockedBy', () {
      // A decided task carries its one-hop blockedBy even with no capture, and
      // the blocked-work rule tells the model to schedule that blocker first.
      // Leaving the blocker id out would make noFabricatedTaskIds fail a model
      // for doing exactly what the prompt asked.
      final subject = inputs(
        corpus: const [
          EvalCorpusTask(
            taskId: 'task-c-leaf',
            title: 'Ship the integration',
            status: 'BLOCKED',
            blockedBy: ['task-b-middle'],
          ),
          EvalCorpusTask(taskId: 'task-b-middle', title: 'Get credentials'),
        ],
        decidedTaskIds: const ['task-c-leaf'],
        visibleTaskIds: const {'task-c-leaf'},
      );

      expect(subject.referenceableTaskIds, {'task-c-leaf', 'task-b-middle'});
    });

    test('stops at one hop, matching ADR 0043', () {
      // task-a-root is never rendered: only task-c-leaf's own blockers are,
      // and a blocker's blockers are not resolved. Naming it really would be
      // fabrication, so the pair keeps its measured gap.
      final subject = inputs(
        corpus: const [
          EvalCorpusTask(
            taskId: 'task-c-leaf',
            title: 'Ship the integration',
            status: 'BLOCKED',
            blockedBy: ['task-b-middle'],
          ),
          EvalCorpusTask(
            taskId: 'task-b-middle',
            title: 'Get credentials',
            status: 'BLOCKED',
            blockedBy: ['task-a-root'],
          ),
          EvalCorpusTask(taskId: 'task-a-root', title: 'Pick a vendor'),
        ],
        decidedTaskIds: const ['task-c-leaf'],
        visibleTaskIds: const {'task-c-leaf'},
      );

      expect(subject.referenceableTaskIds, {'task-c-leaf', 'task-b-middle'});
      expect(subject.referenceableTaskIds, isNot(contains('task-a-root')));
    });
  });

  group('EvalConstraintResult', () {
    test('a not-applicable result is distinguishable from a pass', () {
      const notApplicable = EvalConstraintResult.notApplicable('x', 'nothing');
      const passed = EvalConstraintResult(
        id: 'x',
        passed: true,
        detail: 'fine',
      );

      expect(notApplicable.isApplicable, isFalse);
      expect(notApplicable.passed, isNull);
      expect(passed.isApplicable, isTrue);
    });
  });

  group('EvalRunOutcome.rejections', () {
    test('surfaces only the tool calls that were rejected', () {
      final outcome = EvalRunOutcome(
        inputs: inputs(),
        toolCalls: const [
          EvalToolCall(
            name: 'draft_day_plan',
            accepted: false,
            rejectionMessage: 'blocks must stay within the planDate day',
          ),
          EvalToolCall(name: 'draft_day_plan', accepted: true),
        ],
      );

      expect(outcome.rejections, hasLength(1));
      expect(
        outcome.rejections.single.rejectionMessage,
        contains('within the planDate day'),
      );
    });
  });
}
