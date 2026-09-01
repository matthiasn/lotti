import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/tasks/ui/widgets/task_estimate_progress_bar.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('TaskEstimateProgressBar.fraction', () {
    test('is the tracked share of the estimate, clamped to one', () {
      expect(
        TaskEstimateProgressBar.fraction(
          tracked: const Duration(minutes: 30),
          estimate: const Duration(hours: 2),
        ),
        0.25,
      );
      expect(
        TaskEstimateProgressBar.fraction(
          tracked: const Duration(hours: 3),
          estimate: const Duration(hours: 2),
        ),
        1,
      );
    });

    test('is zero for a non-positive estimate or no tracked time', () {
      expect(
        TaskEstimateProgressBar.fraction(
          tracked: const Duration(hours: 1),
          estimate: Duration.zero,
        ),
        0,
      );
      expect(
        TaskEstimateProgressBar.fraction(
          tracked: Duration.zero,
          estimate: const Duration(hours: 1),
        ),
        0,
      );
      expect(
        TaskEstimateProgressBar.fraction(
          tracked: const Duration(minutes: -5),
          estimate: const Duration(hours: 1),
        ),
        0,
      );
    });

    glados.Glados2(
      glados.any.intInRange(0, 100000),
      glados.any.intInRange(1, 100000),
    ).test(
      'stays within [0, 1] and saturates exactly when overtime',
      (trackedSeconds, estimateSeconds) {
        final tracked = Duration(seconds: trackedSeconds);
        final estimate = Duration(seconds: estimateSeconds);
        final fraction = TaskEstimateProgressBar.fraction(
          tracked: tracked,
          estimate: estimate,
        );
        expect(fraction, inInclusiveRange(0, 1));
        final overtime = TaskEstimateProgressBar.isOvertime(
          tracked: tracked,
          estimate: estimate,
        );
        if (overtime) {
          expect(fraction, 1);
        } else {
          expect(fraction, trackedSeconds / estimateSeconds);
        }
      },
      tags: ['glados'],
    );
  });

  group('TaskEstimateProgressBar', () {
    testWidgets('paints green within the estimate and red once over', (
      tester,
    ) async {
      for (final (tracked, overtime) in [
        (const Duration(minutes: 30), false),
        (const Duration(minutes: 90), true),
      ]) {
        await tester.pumpWidget(
          makeTestableWidget(
            Center(
              child: TaskEstimateProgressBar(
                tracked: tracked,
                estimate: const Duration(hours: 1),
              ),
            ),
          ),
        );
        final context = tester.element(find.byType(LinearProgressIndicator));
        final bar = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );
        expect(
          bar.color,
          overtime
              ? TaskShowcasePalette.error(context)
              : TaskShowcasePalette.success(context),
          reason: 'tracked=$tracked',
        );
        expect(bar.value, overtime ? 1 : 0.5, reason: 'tracked=$tracked');
        expect(
          tester.getSize(find.byType(LinearProgressIndicator)),
          const Size(36, 6),
        );
      }
    });
  });
}
