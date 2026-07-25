import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';

import 'eval_scenario.dart';

/// A fixture that lies about what it contains is worse than no fixture: it
/// produces a confident report about a scenario that was never actually
/// exercised. These assert the fixtures are internally coherent, and that the
/// blocked pair is the controlled comparison it claims to be.
void main() {
  final planDate = DateTime(2026, 7, 18);

  EvalScenario byId(String id) =>
      evalScenarios.firstWhere((scenario) => scenario.id == id);

  test('every scenario has a unique id and states its intent', () {
    final ids = evalScenarios.map((scenario) => scenario.id).toList();

    expect(ids.toSet(), hasLength(ids.length), reason: 'duplicate scenario id');
    for (final scenario in evalScenarios) {
      expect(
        scenario.intent,
        isNotEmpty,
        reason: '${scenario.id} must say what it is trying to find out',
      );
    }
  });

  test('every scenario but the restraint control gives the model work', () {
    // The first live run produced one generic buffer block against an empty
    // corpus — correct, and uninformative. Only the control is allowed to be
    // empty now.
    for (final scenario in evalScenarios) {
      if (scenario.id == 'restraint') {
        expect(scenario.tasks, isEmpty);
        continue;
      }
      expect(
        scenario.tasks,
        isNotEmpty,
        reason: '${scenario.id} would measure only that the pipeline runs',
      );
    }
  });

  test('decided task ids all exist in their scenario corpus', () {
    for (final scenario in evalScenarios) {
      final known = {for (final task in scenario.tasks) task.id};
      for (final decided in scenario.decidedTaskIds) {
        expect(
          known,
          contains(decided),
          reason:
              '${scenario.id} decides on $decided, which it never seeds — '
              'the model would be asked to place a task it cannot see',
        );
      }
    }
  });

  test('blockedBy references resolve within the scenario', () {
    for (final scenario in evalScenarios) {
      final known = {for (final task in scenario.tasks) task.id};
      for (final task in scenario.tasks) {
        for (final blockerId in task.blockedBy) {
          expect(
            known,
            contains(blockerId),
            reason:
                '${scenario.id}: ${task.id} is blocked by $blockerId, '
                'which the fixture never seeds',
          );
        }
      }
    }
  });

  test('a scenario requiring escalation says what reason would be true', () {
    // An empty reason set with requiresConflictSurfaced would make escalation
    // impossible to satisfy, leaving only the reason-text path.
    for (final scenario in evalScenarios) {
      if (!scenario.requiresConflictSurfaced) continue;
      expect(
        scenario.conflictEscalationReasons,
        isNotEmpty,
        reason:
            '${scenario.id} requires a conflict to be surfaced but names '
            'no escalation reason that could be true of it',
      );
    }
  });

  test('the blocked pair differs only in whether a capture is present', () {
    // This pair exists to isolate one variable: the corpus is rendered only
    // inside the capture context, so without a capture the model gets ADR
    // 0043's rule and none of the data. Anything else differing would
    // confound that comparison.
    final withCapture = byId('blockedChain');
    final withoutCapture = byId('blockedWithoutCorpus');

    expect(withCapture.includeCapture, isTrue);
    expect(withoutCapture.includeCapture, isFalse);
    expect(
      withoutCapture.tasks.map((task) => task.id),
      withCapture.tasks.map((task) => task.id),
    );
    expect(withoutCapture.decidedTaskIds, withCapture.decidedTaskIds);
    expect(withoutCapture.capacityMinutes, withCapture.capacityMinutes);
    expect(withoutCapture.startHour, withCapture.startHour);
    expect(
      withoutCapture.requiredTaskIds,
      withCapture.requiredTaskIds,
      reason:
          'ground truth must not move with visibility, or an identical '
          'plan would be graded differently in the two reports and the rate '
          'gap could no longer be attributed to the hidden corpus',
    );
    expect(withoutCapture.permittedOmissions, withCapture.permittedOmissions);
    expect(withoutCapture.expectedOmissions, withCapture.expectedOmissions);
  });

  test('a stale task must be left out, not merely allowed to be', () {
    // Two different things: permitting the omission stops a correct model
    // failing, but only expecting it catches a model that places the work
    // anyway — which is the behaviour this scenario exists to measure.
    final stale = byId('staleDecidedTask');

    expect(stale.expectedOmissions, contains('task-stale-invoice'));
    expect(
      stale.expectedOmissions,
      isNot(contains('task-real-review')),
      reason: 'the genuinely required task must still be required',
    );
    expect(
      stale.inputsFor(planDate).permittedOmissions,
      contains('task-stale-invoice'),
      reason: 'an expected omission is permitted by construction',
    );
  });

  test(
    'a blocked leaf may be omitted or sequenced, so it is only permitted',
    () {
      // Placing it behind its blocker is equally correct, so expecting the
      // omission would fail a model that sequenced the day properly.
      for (final id in ['blockedChain', 'blockedWithoutCorpus']) {
        final scenario = byId(id);
        expect(scenario.permittedOmissions, contains('task-c-leaf'));
        expect(
          scenario.expectedOmissions,
          isEmpty,
          reason: '$id must not punish a correctly sequenced placement',
        );
      }
    },
  );

  test('overCommitted may drop work, but must not do so in silence', () {
    final scenario = byId('overCommitted');

    expect(
      scenario.permittedOmissions,
      containsAll(scenario.decidedTaskIds),
      reason: 'requiring all four would punish surfacing the conflict',
    );
    expect(
      scenario.requiresConflictSurfaced,
      isTrue,
      reason:
          'permitting every omission without this lets a model ignore '
          'twelve hours of work and score clean',
    );
  });

  test('restraint forbids invented work, or it measures nothing', () {
    final scenario = byId('restraint');

    expect(scenario.tasks, isEmpty);
    expect(
      scenario.forbidsInventedWork,
      isTrue,
      reason:
          'without this the control cannot tell staying quiet from '
          'confidently inventing a task',
    );
  });

  test('blockedChain requires reaching the ready root', () {
    // Omitting the permitted leaf and scheduling something unrelated would
    // leave both hops untouched while every constraint reported clean.
    final scenario = byId('blockedChain');

    expect(scenario.requiredTaskIds, contains('task-a-root'));
    expect(
      scenario.permittedOmissions,
      contains('task-c-leaf'),
      reason: 'the leaf stays optional; only the root is required',
    );
  });

  test('crowdedDay names the work a competent plan must include', () {
    // Generic constraints are all satisfied by a single well-formed block, so
    // without this the scenario cannot tell a good plan from one that
    // scheduled the least urgent thing available.
    final scenario = byId('crowdedDay');

    expect(scenario.requiredTaskIds, {
      'task-overdue-invoice',
      'task-due-today-review',
      'task-inprogress-migration',
    });
    for (final required in scenario.requiredTaskIds) {
      expect(
        scenario.tasks.map((task) => task.id),
        contains(required),
        reason: '$required is required but never seeded',
      );
    }
    expect(
      scenario.requiredTaskIds,
      isNot(contains('task-later-onboarding')),
      reason: 'work due in two weeks is exactly what a good plan may skip',
    );
  });

  test('lateStart carries the working-hours end the scenario turns on', () {
    final inputs = byId('lateStart').inputsFor(planDate);

    expect(inputs.workingHoursEndHour, 17);
    expect(
      inputs.now!.hour,
      lessThan(inputs.workingHoursEndHour),
      reason: 'the draft must start while working hours remain',
    );
  });

  test('a capture-less scenario declares the corpus invisible', () {
    // The visibility semantics themselves are covered in eval_models_test;
    // what belongs here is that the fixture actually sets them, since the
    // scenario pair is meaningless otherwise.
    expect(
      byId('blockedWithoutCorpus').inputsFor(planDate).visibleTaskIds,
      isNotNull,
    );
    expect(
      byId('blockedChain').inputsFor(planDate).visibleTaskIds,
      isNull,
      reason: 'a scenario with a capture shows the model everything',
    );
  });

  test('overCommitted genuinely does not fit', () {
    final scenario = byId('overCommitted');
    final decidedMinutes = scenario.tasks
        .where((task) => scenario.decidedTaskIds.contains(task.id))
        .fold<int>(0, (sum, task) => sum + (task.estimateMinutes ?? 0));

    expect(
      decidedMinutes,
      greaterThan(scenario.capacityMinutes),
      reason: 'a scenario named overCommitted that fits proves nothing',
    );
  });

  test('lateStart leaves less time than its longest task needs', () {
    final scenario = byId('lateStart');
    final longest = scenario.tasks
        .map((task) => task.estimateMinutes ?? 0)
        .reduce((a, b) => a > b ? a : b);
    // Working hours end at 17:00 by default config.
    final remainingMinutes = (17 - scenario.startHour!) * 60;

    expect(
      longest,
      greaterThan(remainingMinutes),
      reason: 'the tension is a task that cannot fit in what remains',
    );
  });

  test('the blocked chain is two hops, which ADR 0043 does not close', () {
    final scenario = byId('blockedChain');
    final leaf = scenario.tasks.firstWhere((t) => t.id == 'task-c-leaf');
    final middle = scenario.tasks.firstWhere((t) => t.id == 'task-b-middle');

    expect(leaf.blockedBy, ['task-b-middle']);
    expect(middle.blockedBy, ['task-a-root']);
    expect(
      scenario.decidedTaskIds,
      contains('task-c-leaf'),
      reason:
          'the decided task must be the far end of the chain, or the '
          'transitive question never arises',
    );
  });

  test('seeded tasks carry the fields the corpus builder reads', () {
    final scenario = byId('crowdedDay');
    final tasks = scenario.tasksFor(planDate);

    expect(tasks, hasLength(scenario.tasks.length));
    final invoice = tasks.firstWhere((t) => t.id == 'task-overdue-invoice');
    expect(invoice.data.title, 'Send the overdue client invoice');
    expect(invoice.data.estimate, const Duration(minutes: 30));
    expect(invoice.meta.categoryId, evalDefaultCategoryId);
    expect(
      invoice.data.due!.isBefore(planDate),
      isTrue,
      reason: 'a negative dueOffsetDays must land before the plan date',
    );
  });

  test('overdue and due-today tasks are the ones offered to the due reads', () {
    final scenario = byId('crowdedDay');

    final due = scenario.overdueOrDueTodayFor(planDate).map((t) => t.id);

    expect(due, contains('task-overdue-invoice'));
    expect(due, contains('task-due-today-review'));
    expect(
      due,
      isNot(contains('task-later-onboarding')),
      reason: 'a task due in two weeks is not due today',
    );
  });

  test('in-progress work is offered to the in-progress read', () {
    final scenario = byId('crowdedDay');

    expect(
      scenario.inProgressFor(planDate).map((t) => t.id),
      ['task-inprogress-migration'],
    );
  });

  test('scenario inputs mirror the seeded corpus for the scorers', () {
    final scenario = byId('blockedChain');
    final inputs = scenario.inputsFor(planDate);

    expect(inputs.corpus.map((task) => task.taskId), [
      for (final task in scenario.tasks) task.id,
    ]);
    final leaf = inputs.taskById('task-c-leaf')!;
    expect(leaf.isBlocked, isTrue);
    expect(leaf.blockedBy, ['task-b-middle']);
    final unrelated = inputs.taskById('task-unrelated')!;
    expect(unrelated.isBlocked, isFalse);
  });

  test('the fixture resolver answers only for the ids it was asked about', () {
    final scenario = byId('blockedChain');
    final resolver = EvalFixtureDependencyResolver(scenario.blockedStatus);

    return resolver.resolveBlockedStatus({'task-c-leaf'}).then((resolved) {
      expect(resolved.keys, ['task-c-leaf']);
      expect(resolved['task-c-leaf']!.single.taskId, 'task-b-middle');
      expect(
        resolved['task-c-leaf']!.single.title,
        'Wire up the vendor integration',
        reason: 'the blocker title is what the prompt rule lets a reason name',
      );
    });
  });

  test('a task blocked by status alone still reads as blocked', () {
    // ADR 0043's predicate is a union: absence of blockedBy means link-ready,
    // not free to schedule.
    final scenario = byId('blockedChain');
    final tasks = scenario.tasksFor(planDate);
    final middle = tasks.firstWhere((t) => t.id == 'task-b-middle');

    expect(middle.data.status, isA<TaskBlocked>());
  });
}
