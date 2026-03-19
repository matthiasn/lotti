import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/projects/ui/widgets/project_selection_modal_content.dart';
import 'package:lotti/features/tasks/ui/header/task_project_widget.dart';
import 'package:lotti/widgets/cards/modern_status_chip.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../widget_test_utils.dart';
import '../../../projects/test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  ProjectEntry makeProject({required String title}) {
    return makeTestProject(
      id: 'proj-1',
      title: title,
      categoryId: 'cat-1',
    );
  }

  group('TaskProjectWidget', () {
    testWidgets('shows project title when project is assigned', (
      tester,
    ) async {
      final project = makeProject(title: 'Alpha Project');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          TaskProjectWidget(
            project: project,
            categoryId: 'cat-1',
            onSave: (id) async => true,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Alpha Project'), findsOneWidget);
      expect(find.byType(ModernStatusChip), findsOneWidget);
      expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
    });

    testWidgets('shows unassigned label when no project', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          TaskProjectWidget(
            project: null,
            categoryId: 'cat-1',
            onSave: (id) async => true,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('No project'), findsOneWidget);
    });

    testWidgets('does nothing on tap when categoryId is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          TaskProjectWidget(
            project: null,
            categoryId: null,
            onSave: (id) async => true,
          ),
        ),
      );
      await tester.pump();

      // Tap the chip — should not open a modal since categoryId is null
      await tester.tap(find.byType(InkWell));
      await tester.pump();

      // No modal should appear — verify no project selection content visible
      expect(find.byType(ProjectSelectionModalContent), findsNothing);
    });

    testWidgets('opens modal on tap when categoryId is set', (tester) async {
      final project = makeProject(title: 'My Project');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          TaskProjectWidget(
            project: project,
            categoryId: 'cat-1',
            onSave: (id) async => true,
          ),
        ),
      );
      await tester.pump();

      // Tap the chip to open the project selection modal
      await tester.tap(find.text('My Project'));
      await tester.pumpAndSettle();

      // The modal should be open
      expect(find.byType(ProjectSelectionModalContent), findsOneWidget);
    });
  });
}
