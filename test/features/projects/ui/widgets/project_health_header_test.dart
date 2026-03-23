import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/features/projects/state/project_health_metrics.dart';
import 'package:lotti/features/projects/state/project_providers.dart';
import 'package:lotti/features/projects/ui/widgets/project_health_header.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

void main() {
  final now = DateTime(2024, 3, 15);
  const categoryId = 'cat-1';

  late MockNavService mockNavService;

  setUpAll(registerAllFallbackValues);

  setUp(() async {
    await setUpTestGetIt(
      additionalSetup: () {
        mockNavService = MockNavService();
        when(
          () => mockNavService.beamToNamed(any(), data: any(named: 'data')),
        ).thenReturn(null);
        getIt.registerSingleton<NavService>(mockNavService);
      },
    );
  });

  tearDown(tearDownTestGetIt);

  /// Helper to pump the widget with common overrides.
  Future<void> pumpHeader(
    WidgetTester tester, {
    required List<ProjectEntry> projects,
    Set<String> selectedProjectIds = const {},
    void Function(String)? onToggleProject,
    void Function(Set<String>)? onClearStale,
    Map<String, int> taskCounts = const {},
    Map<String, ProjectAgentSummaryState?> projectSummaries = const {},
    Map<String, ProjectHealthMetrics?> projectHealthMetrics = const {},
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        ProjectHealthHeader(
          categoryId: categoryId,
          selectedProjectIds: selectedProjectIds,
          onToggleProject: onToggleProject ?? (_) {},
          onClearStale: onClearStale ?? (_) {},
        ),
        overrides: [
          projectsForCategoryProvider(categoryId).overrideWith(
            (ref) async => projects,
          ),
          for (final entry in taskCounts.entries)
            projectTaskCountProvider(entry.key).overrideWith(
              (ref) async => entry.value,
            ),
          for (final entry in projectSummaries.entries)
            projectAgentSummaryProvider(entry.key).overrideWith(
              (ref) async => entry.value,
            ),
          for (final project in projects)
            projectHealthMetricsProvider(project.meta.id).overrideWith(
              (ref) async =>
                  projectHealthMetrics[project.meta.id] ??
                  makeTestProjectHealthMetrics(),
            ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  group('ProjectHealthHeader', () {
    testWidgets('shows nothing when loading', (tester) async {
      final completer = Completer<List<ProjectEntry>>();

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ProjectHealthHeader(
            categoryId: categoryId,
            selectedProjectIds: const {},
            onToggleProject: (_) {},
            onClearStale: (_) {},
          ),
          overrides: [
            projectsForCategoryProvider(categoryId).overrideWith(
              (ref) => completer.future,
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('Projects'), findsNothing);
    });

    testWidgets('shows nothing when error', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ProjectHealthHeader(
            categoryId: categoryId,
            selectedProjectIds: const {},
            onToggleProject: (_) {},
            onClearStale: (_) {},
          ),
          overrides: [
            projectsForCategoryProvider(categoryId).overrideWith(
              (ref) => throw Exception('DB error'),
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('Projects'), findsNothing);
    });

    testWidgets('shows outdated message without scheduled time', (
      tester,
    ) async {
      final project = makeTestProject(
        id: 'proj-no-wake',
        title: 'No Wake',
        categoryId: categoryId,
      );

      await pumpHeader(
        tester,
        projects: [project],
        taskCounts: {'proj-no-wake': 1},
        projectSummaries: {
          'proj-no-wake': ProjectAgentSummaryState(
            agentId: 'agent-1',
            hasReport: true,
            pendingProjectActivityAt: DateTime(2026, 3, 22, 12),
          ),
        },
      );

      await tester.tap(find.text('Projects'));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Summary outdated'), findsOneWidget);
    });

    testWidgets('shows nothing when no projects', (tester) async {
      await pumpHeader(tester, projects: []);
      expect(find.text('Projects'), findsNothing);
    });

    testWidgets('collapsed shows summary with project and task count', (
      tester,
    ) async {
      final projects = [
        makeTestProject(id: 'proj-1', title: 'Alpha', categoryId: categoryId),
        makeTestProject(
          id: 'proj-2',
          title: 'Beta',
          categoryId: categoryId,
          status: ProjectStatus.active(
            id: uuid.v1(),
            createdAt: now,
            utcOffset: 0,
          ),
        ),
      ];

      await pumpHeader(
        tester,
        projects: projects,
        taskCounts: {'proj-1': 3, 'proj-2': 1},
      );

      expect(find.text('Projects'), findsOneWidget);
      expect(find.text('2 projects, 4 tasks'), findsOneWidget);
      // Individual projects should NOT be visible when collapsed
      expect(find.text('Alpha'), findsNothing);
      expect(find.text('Beta'), findsNothing);
    });

    testWidgets('shows selected count badge when projects are filtered', (
      tester,
    ) async {
      final projects = [
        makeTestProject(id: 'proj-1', title: 'Alpha', categoryId: categoryId),
        makeTestProject(id: 'proj-2', title: 'Beta', categoryId: categoryId),
      ];

      await pumpHeader(
        tester,
        projects: projects,
        selectedProjectIds: {'proj-1'},
        taskCounts: {'proj-1': 2, 'proj-2': 1},
      );

      // Badge shows the count of selected projects
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('tapping expands to show per-project rows', (tester) async {
      final projects = [
        makeTestProject(id: 'proj-1', title: 'Alpha', categoryId: categoryId),
        makeTestProject(
          id: 'proj-2',
          title: 'Beta',
          categoryId: categoryId,
          status: ProjectStatus.active(
            id: uuid.v1(),
            createdAt: now,
            utcOffset: 0,
          ),
        ),
      ];

      await pumpHeader(
        tester,
        projects: projects,
        taskCounts: {'proj-1': 3, 'proj-2': 1},
      );

      await tester.tap(find.text('Projects'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('On Track'), findsNWidgets(2));
    });

    testWidgets('shows outdated summary message for stale project reports', (
      tester,
    ) async {
      final project = makeTestProject(
        id: 'proj-stale',
        title: 'Stale Project',
        categoryId: categoryId,
      );

      await pumpHeader(
        tester,
        projects: [project],
        taskCounts: {'proj-stale': 2},
        projectSummaries: {
          'proj-stale': ProjectAgentSummaryState(
            agentId: 'agent-1',
            hasReport: true,
            pendingProjectActivityAt: DateTime(2026, 3, 22, 12),
            scheduledWakeAt: DateTime(2026, 3, 23, 6),
          ),
        },
      );

      await tester.tap(find.text('Projects'));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Summary outdated'), findsOneWidget);
      expect(find.textContaining('2026'), findsOneWidget);
      expect(find.text('On Track'), findsOneWidget);
    });

    testWidgets('tapping again collapses the header', (tester) async {
      final projects = [
        makeTestProject(id: 'proj-1', title: 'Alpha', categoryId: categoryId),
      ];

      await pumpHeader(
        tester,
        projects: projects,
        taskCounts: {'proj-1': 2},
      );

      await tester.tap(find.text('Projects'));
      await tester.pump();
      expect(find.text('Alpha'), findsOneWidget);

      await tester.tap(find.text('Projects'));
      await tester.pump();
      expect(find.text('Alpha'), findsNothing);
    });

    testWidgets('tapping a project row calls onToggleProject', (tester) async {
      final project = makeTestProject(
        id: 'proj-toggle',
        title: 'Toggle Me',
        categoryId: categoryId,
      );
      String? toggledId;

      await pumpHeader(
        tester,
        projects: [project],
        onToggleProject: (id) => toggledId = id,
        taskCounts: {'proj-toggle': 0},
      );

      // Expand first
      await tester.tap(find.text('Projects'));
      await tester.pump();

      // Tap the project row (not the navigate icon)
      await tester.tap(find.text('Toggle Me'));
      await tester.pump();

      expect(toggledId, equals('proj-toggle'));
    });

    testWidgets(
      'navigate icon on project row navigates to project detail',
      (tester) async {
        final project = makeTestProject(
          id: 'proj-nav',
          title: 'Navigate Me',
          categoryId: categoryId,
        );

        await pumpHeader(
          tester,
          projects: [project],
          taskCounts: {'proj-nav': 0},
        );

        await tester.tap(find.text('Projects'));
        await tester.pump();

        // Tap the forward arrow icon button on the project row
        await tester.tap(find.byIcon(Icons.arrow_forward_ios_rounded));
        await tester.pump();

        verify(
          () => mockNavService.beamToNamed('/settings/projects/proj-nav'),
        ).called(1);
      },
    );

    testWidgets(
      'settings icon on summary card navigates to category details',
      (tester) async {
        final project = makeTestProject(
          id: 'proj-1',
          title: 'Any',
          categoryId: categoryId,
        );

        await pumpHeader(
          tester,
          projects: [project],
          taskCounts: {'proj-1': 0},
        );

        await tester.tap(find.byIcon(Icons.settings_outlined));
        await tester.pump();

        verify(
          () => mockNavService.beamToNamed('/settings/categories/$categoryId'),
        ).called(1);
      },
    );

    testWidgets('stale project IDs trigger onClearStale callback', (
      tester,
    ) async {
      final project = makeTestProject(
        id: 'proj-valid',
        title: 'Valid',
        categoryId: categoryId,
      );
      Set<String>? clearedStale;

      await pumpHeader(
        tester,
        projects: [project],
        selectedProjectIds: {'proj-valid', 'proj-gone'},
        onClearStale: (stale) => clearedStale = stale,
        taskCounts: {'proj-valid': 1},
      );

      // Post-frame callback fires on next pump.
      await tester.pump();

      expect(clearedStale, isNotNull);
      expect(clearedStale, contains('proj-gone'));
      expect(clearedStale, isNot(contains('proj-valid')));
    });
  });
}
