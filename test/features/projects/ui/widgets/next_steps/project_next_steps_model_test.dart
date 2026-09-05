import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/projects/ui/widgets/next_steps/project_next_steps_model.dart';

import '../../../../agents/test_data/change_set_factories.dart';

void main() {
  group('projectNextStepOutcome', () {
    test('reads the outcome the user produced, not just the status', () {
      expect(
        projectNextStepOutcome(makeTestProjectRecommendation()),
        ProjectNextStepOutcome.pending,
      );
      expect(
        projectNextStepOutcome(
          makeTestProjectRecommendation(
            status: ProjectRecommendationStatus.dismissed,
          ),
        ),
        ProjectNextStepOutcome.dismissed,
      );
      expect(
        projectNextStepOutcome(
          makeTestProjectRecommendation(
            status: ProjectRecommendationStatus.resolved,
            createdTaskId: 'task-1',
          ),
        ),
        ProjectNextStepOutcome.added,
        reason: 'A resolved step that recorded its task was added.',
      );
      expect(
        projectNextStepOutcome(
          makeTestProjectRecommendation(
            status: ProjectRecommendationStatus.resolved,
          ),
        ),
        ProjectNextStepOutcome.done,
        reason: 'A resolved step without a task was marked done elsewhere.',
      );
      expect(
        projectNextStepOutcome(
          makeTestProjectRecommendation(
            status: ProjectRecommendationStatus.superseded,
          ),
        ),
        ProjectNextStepOutcome.done,
        reason: 'A stale row can neither be acted on nor block a summary.',
      );
    });
  });

  group('ProjectNextStepsTally', () {
    test('counts every outcome and knows when a run is fully decided', () {
      final tally = ProjectNextStepsTally.of([
        makeTestProjectRecommendation(id: 'a'),
        makeTestProjectRecommendation(
          id: 'b',
          status: ProjectRecommendationStatus.resolved,
          createdTaskId: 'task-b',
        ),
        makeTestProjectRecommendation(
          id: 'c',
          status: ProjectRecommendationStatus.resolved,
        ),
        makeTestProjectRecommendation(
          id: 'd',
          status: ProjectRecommendationStatus.dismissed,
        ),
        makeTestProjectRecommendation(
          id: 'e',
          status: ProjectRecommendationStatus.dismissed,
        ),
      ]);

      expect(tally.pending, 1);
      expect(tally.added, 1);
      expect(tally.done, 1);
      expect(tally.dismissed, 2);
      expect(tally.total, 5);
      expect(tally.allDecided, isFalse);

      expect(ProjectNextStepsTally.of(const []).allDecided, isFalse);
      expect(
        ProjectNextStepsTally.of([
          makeTestProjectRecommendation(
            status: ProjectRecommendationStatus.dismissed,
          ),
        ]).allDecided,
        isTrue,
      );
    });
  });

  group('visibleProjectNextSteps', () {
    test('caps a long run to the first rows in the agent order', () {
      final steps = List.generate(5, (i) => 'step-$i');
      expect(visibleProjectNextSteps(steps, cap: 3, showAll: false), [
        'step-0',
        'step-1',
        'step-2',
      ]);
      expect(visibleProjectNextSteps(steps, cap: 3, showAll: true), steps);
      expect(visibleProjectNextSteps(steps, cap: 5, showAll: false), steps);
      expect(
        visibleProjectNextSteps(<String>[], cap: 3, showAll: false),
        isEmpty,
      );
    });

    glados.Glados3(
      glados.any.list(glados.any.int),
      glados.any.positiveInt,
      glados.any.bool,
    ).test('always yields a prefix whose length is the cap unless shown all', (
      steps,
      cap,
      showAll,
    ) {
      final visible = visibleProjectNextSteps(
        steps,
        cap: cap,
        showAll: showAll,
      );
      expect(visible, steps.sublist(0, visible.length));
      if (showAll || steps.length <= cap) {
        expect(visible, steps);
      } else {
        expect(visible.length, cap);
      }
    }, tags: 'glados');
  });

  group('projectNextStepsAge', () {
    test('buckets at the minute, hour and day boundaries', () {
      expect(projectNextStepsAge(Duration.zero), (
        unit: ProjectNextStepsAgeUnit.justNow,
        count: 0,
      ));
      expect(
        projectNextStepsAge(const Duration(seconds: 59)).unit,
        ProjectNextStepsAgeUnit.justNow,
      );
      expect(projectNextStepsAge(const Duration(minutes: 1)), (
        unit: ProjectNextStepsAgeUnit.minutes,
        count: 1,
      ));
      expect(projectNextStepsAge(const Duration(minutes: 59, seconds: 30)), (
        unit: ProjectNextStepsAgeUnit.minutes,
        count: 59,
      ));
      expect(projectNextStepsAge(const Duration(hours: 1)), (
        unit: ProjectNextStepsAgeUnit.hours,
        count: 1,
      ));
      expect(projectNextStepsAge(const Duration(hours: 23, minutes: 59)), (
        unit: ProjectNextStepsAgeUnit.hours,
        count: 23,
      ));
      expect(projectNextStepsAge(const Duration(days: 1)), (
        unit: ProjectNextStepsAgeUnit.days,
        count: 1,
      ));
      expect(projectNextStepsAge(const Duration(days: -2)), (
        unit: ProjectNextStepsAgeUnit.justNow,
        count: 0,
      ));
    });

    glados.Glados(glados.any.int).test(
      'never reports a count outside its unit and never a future age',
      (seconds) {
        final elapsed = Duration(seconds: seconds);
        final age = projectNextStepsAge(elapsed);
        switch (age.unit) {
          case ProjectNextStepsAgeUnit.justNow:
            expect(age.count, 0);
            expect(elapsed, lessThan(const Duration(minutes: 1)));
          case ProjectNextStepsAgeUnit.minutes:
            expect(age.count, inInclusiveRange(1, 59));
            expect(age.count, elapsed.inMinutes);
          case ProjectNextStepsAgeUnit.hours:
            expect(age.count, inInclusiveRange(1, 23));
            expect(age.count, elapsed.inHours);
          case ProjectNextStepsAgeUnit.days:
            expect(age.count, greaterThanOrEqualTo(1));
            expect(age.count, elapsed.inDays);
        }
      },
      tags: 'glados',
    );
  });
}
