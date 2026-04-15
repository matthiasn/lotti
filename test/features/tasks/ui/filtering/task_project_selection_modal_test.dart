import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/tasks/ui/filtering/task_project_selection_modal.dart';

import '../../../../helpers/entity_factories.dart';
import '../../../../widget_test_utils.dart';

void main() {
  final categories = [
    CategoryDefinition(
      id: 'cat-1',
      name: 'Work',
      color: '#FF0000',
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
      vectorClock: null,
      private: false,
      active: true,
    ),
    CategoryDefinition(
      id: 'cat-2',
      name: 'Personal',
      color: '#00FF00',
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
      vectorClock: null,
      private: false,
      active: true,
    ),
  ];

  final projects = [
    ProjectWithCategory(
      project: TestProjectFactory.create(
        id: 'proj-1',
        title: 'Alpha',
        categoryId: 'cat-1',
      ),
      categoryId: 'cat-1',
    ),
    ProjectWithCategory(
      project: TestProjectFactory.create(
        id: 'proj-2',
        title: 'Beta',
        categoryId: 'cat-1',
      ),
      categoryId: 'cat-1',
    ),
    ProjectWithCategory(
      project: TestProjectFactory.create(
        id: 'proj-3',
        title: 'Gamma',
        categoryId: 'cat-2',
      ),
      categoryId: 'cat-2',
    ),
  ];

  group('ProjectWithCategory', () {
    test('holds project and category ID', () {
      final pwc = projects.first;
      expect(pwc.project.data.title, 'Alpha');
      expect(pwc.categoryId, 'cat-1');
    });
  });

  group('showProjectSelectionModal', () {
    testWidgets('falls back to category ID when category name not found', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(500, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Project with a categoryId that has no matching CategoryDefinition
      final orphanProject = [
        ProjectWithCategory(
          project: TestProjectFactory.create(
            id: 'proj-orphan',
            title: 'Orphan',
            categoryId: 'unknown-cat',
          ),
          categoryId: 'unknown-cat',
        ),
      ];

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  await showProjectSelectionModal(
                    context: context,
                    projects: orphanProject,
                    categories: const [], // no matching categories
                    initialSelectedIds: const {},
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Falls back to the raw categoryId as the group header
      expect(find.text('unknown-cat'), findsOneWidget);
      expect(find.text('Orphan'), findsOneWidget);
    });

    testWidgets('renders projects grouped by category', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      Set<String>? result;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await showProjectSelectionModal(
                    context: context,
                    projects: projects,
                    categories: categories,
                    initialSelectedIds: const {'proj-1'},
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Category headers are visible
      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Personal'), findsOneWidget);

      // Project names are visible
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      expect(find.text('Gamma'), findsOneWidget);

      // Toggle a project
      await tester.tap(
        find.byKey(
          const ValueKey('design-system-project-selection-option-proj-2'),
        ),
      );
      await tester.pump();

      // Apply
      await tester.tap(
        find.byKey(
          const ValueKey('design-system-project-selection-apply'),
        ),
      );
      await tester.pumpAndSettle();

      expect(result, {'proj-1', 'proj-2'});
    });

    testWidgets('deselecting a project removes it from result', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(500, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      Set<String>? result;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await showProjectSelectionModal(
                    context: context,
                    projects: projects,
                    categories: categories,
                    initialSelectedIds: const {'proj-1', 'proj-3'},
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Deselect proj-1
      await tester.tap(
        find.byKey(
          const ValueKey('design-system-project-selection-option-proj-1'),
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(
          const ValueKey('design-system-project-selection-apply'),
        ),
      );
      await tester.pumpAndSettle();

      expect(result, {'proj-3'});
    });

    testWidgets('returns null when dismissed without applying', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(500, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      Set<String>? result = const {'sentinel'};

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await showProjectSelectionModal(
                    context: context,
                    projects: projects,
                    categories: categories,
                    initialSelectedIds: const {},
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Dismiss
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();

      expect(result, isNull);
    });
  });
}
