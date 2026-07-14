import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/projects/state/project_providers.dart';
import 'package:lotti/features/projects/ui/widgets/project_selection_modal_content.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

void main() {
  const categoryId = 'cat-modal-1';

  setUpAll(registerAllFallbackValues);

  Future<void> pumpModalContentWithLoader(
    WidgetTester tester, {
    required Future<List<ProjectEntry>> Function() loadProjects,
    required Future<void> Function(ProjectEntry? project) onProjectSelected,
    String? currentProjectId,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              body: ProjectSelectionModalContent(
                categoryId: categoryId,
                onProjectSelected: onProjectSelected,
                currentProjectId: currentProjectId,
              ),
            ),
          ),
        ),
        overrides: [
          projectsForCategoryProvider(categoryId).overrideWith(
            (ref) => loadProjects(),
          ),
        ],
      ),
    );
    await tester.pump();
  }

  /// Pumps the modal content inside a Navigator so that Navigator.pop works.
  Future<void> pumpModalContent(
    WidgetTester tester, {
    required List<ProjectEntry> projects,
    required Future<void> Function(ProjectEntry? project) onProjectSelected,
    String? currentProjectId,
  }) => pumpModalContentWithLoader(
    tester,
    loadProjects: () async => projects,
    onProjectSelected: onProjectSelected,
    currentProjectId: currentProjectId,
  );

  Future<void> pumpModalBody(
    WidgetTester tester, {
    required AsyncValue<List<ProjectEntry>> projectsAsync,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              body: ProjectSelectionModalBody(
                projectsAsync: projectsAsync,
                onProjectSelected: (_) async {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('ProjectSelectionModalContent', () {
    testWidgets('shows "No project" option', (tester) async {
      await pumpModalContent(
        tester,
        projects: [],
        onProjectSelected: (_) async {},
      );

      expect(find.text('No project'), findsOneWidget);
      expect(find.byIcon(Icons.do_not_disturb_alt_outlined), findsOneWidget);
      expect(find.byType(Divider), findsNothing);

      final row = tester.widget<DesignSystemSelectionRow>(
        find.byKey(const ValueKey('project-none')),
      );
      expect(row.selected, isTrue);
    });

    testWidgets('shows project titles from provider', (tester) async {
      final projects = [
        makeTestProject(
          id: 'p-1',
          title: 'Project Alpha',
          categoryId: categoryId,
        ),
        makeTestProject(
          id: 'p-2',
          title: 'Project Beta',
          categoryId: categoryId,
        ),
      ];

      await pumpModalContent(
        tester,
        projects: projects,
        onProjectSelected: (_) async {},
      );

      expect(find.text('Project Alpha'), findsOneWidget);
      expect(find.text('Project Beta'), findsOneWidget);
      // Verify status chips are shown
      expect(find.text('Open'), findsNWidgets(2));
      expect(
        find.byType(DesignSystemSelectionRow),
        findsNWidgets(projects.length + 1),
      );
      expect(find.byType(Divider), findsNothing);
    });

    testWidgets('marks the current project instead of No project', (
      tester,
    ) async {
      final project = makeTestProject(
        id: 'p-current',
        title: 'Current project',
        categoryId: categoryId,
      );

      await pumpModalContent(
        tester,
        projects: [project],
        currentProjectId: project.meta.id,
        onProjectSelected: (_) async {},
      );

      final noneRow = tester.widget<DesignSystemSelectionRow>(
        find.byKey(const ValueKey('project-none')),
      );
      final projectRow = tester.widget<DesignSystemSelectionRow>(
        find.byKey(const ValueKey('project-p-current')),
      );
      expect(noneRow.selected, isFalse);
      expect(projectRow.selected, isTrue);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('shows a loading state while projects resolve', (tester) async {
      final pending = Completer<List<ProjectEntry>>();
      await pumpModalContentWithLoader(
        tester,
        loadProjects: () => pending.future,
        onProjectSelected: (_) async {},
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows a localized error when projects fail', (tester) async {
      await pumpModalBody(
        tester,
        projectsAsync: AsyncError(
          Exception('load failed'),
          StackTrace.current,
        ),
      );

      expect(find.text('Error loading projects'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets(
      'calls onProjectSelected with null when "No project" tapped',
      (tester) async {
        ProjectEntry? selectedProject;
        var callbackCalled = false;

        await pumpModalContent(
          tester,
          projects: [
            makeTestProject(
              id: 'p-1',
              title: 'Some Project',
              categoryId: categoryId,
            ),
          ],
          onProjectSelected: (project) async {
            callbackCalled = true;
            selectedProject = project;
          },
        );

        await tester.tap(find.text('No project'));
        await tester.pump();

        expect(callbackCalled, isTrue);
        expect(selectedProject, isNull);
      },
    );

    testWidgets(
      'calls onProjectSelected with project when project tapped',
      (tester) async {
        final project = makeTestProject(
          id: 'p-select',
          title: 'Pick This',
          categoryId: categoryId,
        );
        ProjectEntry? selectedProject;
        var callbackCalled = false;

        await pumpModalContent(
          tester,
          projects: [project],
          onProjectSelected: (p) async {
            callbackCalled = true;
            selectedProject = p;
          },
        );

        await tester.tap(find.text('Pick This'));
        await tester.pump();

        expect(callbackCalled, isTrue);
        expect(selectedProject, isNotNull);
        expect(selectedProject!.meta.id, 'p-select');
        expect(selectedProject!.data.title, 'Pick This');
      },
    );

    testWidgets('does not pop after the content is unmounted mid-selection', (
      tester,
    ) async {
      final callback = Completer<void>();
      await pumpModalContent(
        tester,
        projects: [],
        onProjectSelected: (_) => callback.future,
      );

      await tester.tap(find.text('No project'));
      await tester.pumpWidget(const SizedBox.shrink());
      callback.complete();
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
