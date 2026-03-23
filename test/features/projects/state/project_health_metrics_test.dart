import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/features/projects/state/project_health_metrics.dart';

import '../test_utils.dart';

void main() {
  final now = DateTime(2026, 4, 2, 9, 30);

  group('computeProjectHealthMetrics', () {
    test('returns blocked when the project itself is on hold', () {
      final project = makeTestProject(
        status: ProjectStatus.onHold(
          id: 'status-1',
          createdAt: now,
          utcOffset: 0,
          reason: 'Waiting on approval',
        ),
      );

      final metrics = computeProjectHealthMetrics(
        project: project,
        linkedTasks: const [],
        now: now,
      );

      expect(metrics.band, ProjectHealthBand.blocked);
      expect(metrics.reason.kind, ProjectHealthReasonKind.projectOnHold);
    });

    test('returns blocked when linked tasks are stalled', () {
      final project = makeTestProject();
      final stalledTask =
          makeTestTask(
            title: 'Blocked task',
            createdAt: now.subtract(const Duration(days: 1)),
          ).copyWith(
            data:
                makeTestTask(
                  createdAt: now.subtract(const Duration(days: 1)),
                ).data.copyWith(
                  status: TaskStatus.blocked(
                    id: 'blocked-1',
                    createdAt: now.subtract(const Duration(days: 1)),
                    utcOffset: 0,
                    reason: 'Need input',
                  ),
                ),
          );

      final metrics = computeProjectHealthMetrics(
        project: project,
        linkedTasks: [stalledTask],
        now: now,
      );

      expect(metrics.band, ProjectHealthBand.blocked);
      expect(metrics.stalledTaskCount, 1);
      expect(metrics.reason.kind, ProjectHealthReasonKind.stalledTasks);
    });

    test('returns atRisk when linked tasks are overdue', () {
      final project = makeTestProject();
      final overdueTask =
          makeTestTask(
            createdAt: now.subtract(const Duration(days: 2)),
          ).copyWith(
            data:
                makeTestTask(
                  createdAt: now.subtract(const Duration(days: 2)),
                ).data.copyWith(
                  due: DateTime(2026, 3, 31),
                ),
          );

      final metrics = computeProjectHealthMetrics(
        project: project,
        linkedTasks: [overdueTask],
        now: now,
      );

      expect(metrics.band, ProjectHealthBand.atRisk);
      expect(metrics.overdueTaskCount, 1);
      expect(metrics.reason.kind, ProjectHealthReasonKind.overdueTasks);
    });

    test('returns watch when active work has no recent progress', () {
      final project = makeTestProject();
      final quietTask =
          makeTestTask(
            createdAt: now.subtract(const Duration(days: 12)),
          ).copyWith(
            data:
                makeTestTask(
                  createdAt: now.subtract(const Duration(days: 12)),
                ).data.copyWith(
                  status: TaskStatus.inProgress(
                    id: 'progress-1',
                    createdAt: now.subtract(const Duration(days: 12)),
                    utcOffset: 0,
                  ),
                ),
          );

      final metrics = computeProjectHealthMetrics(
        project: project,
        linkedTasks: [quietTask],
        now: now,
      );

      expect(metrics.band, ProjectHealthBand.watch);
      expect(metrics.hasRecentTaskUpdate, isFalse);
      expect(metrics.reason.kind, ProjectHealthReasonKind.noRecentProgress);
    });

    test('returns surviving when there are no linked tasks yet', () {
      final project = makeTestProject();

      final metrics = computeProjectHealthMetrics(
        project: project,
        linkedTasks: const [],
        now: now,
      );

      expect(metrics.band, ProjectHealthBand.surviving);
      expect(metrics.reason.kind, ProjectHealthReasonKind.noLinkedTasks);
    });

    test(
      'returns surviving when the summary is outdated but work is moving',
      () {
        final project = makeTestProject();
        final activeTask =
            makeTestTask(
              createdAt: now.subtract(const Duration(days: 1)),
            ).copyWith(
              data:
                  makeTestTask(
                    createdAt: now.subtract(const Duration(days: 1)),
                  ).data.copyWith(
                    status: TaskStatus.inProgress(
                      id: 'progress-2',
                      createdAt: now.subtract(const Duration(days: 1)),
                      utcOffset: 0,
                    ),
                  ),
            );

        final metrics = computeProjectHealthMetrics(
          project: project,
          linkedTasks: [activeTask],
          agentSummary: ProjectAgentSummaryState(
            agentId: 'agent-1',
            hasReport: true,
            pendingProjectActivityAt: now.subtract(const Duration(hours: 3)),
          ),
          now: now,
        );

        expect(metrics.band, ProjectHealthBand.surviving);
        expect(metrics.isSummaryOutdated, isTrue);
        expect(metrics.reason.kind, ProjectHealthReasonKind.summaryOutdated);
      },
    );

    test('returns onTrack when recent progress is steady', () {
      final project = makeTestProject();
      final completedTask =
          makeTestTask(
            createdAt: now.subtract(const Duration(days: 2)),
          ).copyWith(
            data:
                makeTestTask(
                  createdAt: now.subtract(const Duration(days: 2)),
                ).data.copyWith(
                  status: TaskStatus.done(
                    id: 'done-1',
                    createdAt: now.subtract(const Duration(days: 2)),
                    utcOffset: 0,
                  ),
                ),
          );

      final metrics = computeProjectHealthMetrics(
        project: project,
        linkedTasks: [completedTask],
        now: now,
      );

      expect(metrics.band, ProjectHealthBand.onTrack);
      expect(metrics.reason.kind, ProjectHealthReasonKind.steadyProgress);
      expect(metrics.score, greaterThanOrEqualTo(80));
    });
  });
}
