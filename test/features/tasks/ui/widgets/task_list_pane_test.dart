import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/ui/model/task_list_detail_models.dart';
import 'package:lotti/features/tasks/ui/widgets/task_list_pane.dart';

import '../../../../helpers/entity_factories.dart';
import '../../../../widget_test_utils.dart';

void main() {
  Widget wrap(Widget child) {
    return makeTestableWidget2(
      Theme(
        data: DesignSystemTheme.dark(),
        child: Scaffold(
          body: SizedBox(width: 402, height: 900, child: child),
        ),
      ),
      mediaQueryData: const MediaQueryData(size: Size(500, 1000)),
    );
  }

  TaskRecord makeTaskRecord({
    required String id,
    required String title,
    required CategoryDefinition category,
  }) {
    final task = TestTaskFactory.create(
      id: id,
      title: title,
      categoryId: category.id,
      dateFrom: DateTime(2026, 4, 8, 9),
      dateTo: DateTime(2026, 4, 8, 10),
    );

    return TaskRecord(
      task: task,
      category: category,
      sectionTitle: 'P1 High',
      sectionDate: DateTime(2026, 4, 8),
      projectTitle: 'Design system',
      timeRange: '09:00-10:00',
      labels: const <TaskShowcaseLabel>[],
      aiSummary: 'summary',
      description: 'description',
      trackedDurationLabel: '1h 30m',
      trackerEntries: const <TaskShowcaseTimeEntry>[],
      checklistItems: const <TaskShowcaseChecklistItem>[],
      audioEntries: const <TaskShowcaseAudioEntry>[],
    );
  }

  group('TaskListSectionsList', () {
    testWidgets(
      'hides the upper divider when hovering the next row in the same section',
      (tester) async {
        final category = CategoryDefinition(
          id: 'cat-1',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          name: 'Work',
          vectorClock: null,
          private: false,
          active: true,
          favorite: false,
          color: '#3355FF',
          icon: CategoryIcon.work,
        );
        final sections = [
          TaskListSection(
            title: 'P1 High',
            sectionDate: DateTime(2026, 4, 8),
            tasks: [
              makeTaskRecord(
                id: 'task-1',
                title: 'First task',
                category: category,
              ),
              makeTaskRecord(
                id: 'task-2',
                title: 'Second task',
                category: category,
              ),
            ],
          ),
        ];

        await tester.pumpWidget(
          wrap(
            TaskListSectionsList(
              sections: sections,
              sortOption: TaskSortOption.byPriority,
              selectedTaskId: null,
              bottomPadding: 0,
              onTaskSelected: (_) {},
            ),
          ),
        );
        await tester.pump();

        expect(
          find.byKey(const ValueKey('task-browse-divider-task-1')),
          findsOneWidget,
        );

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        addTearDown(gesture.removePointer);
        await gesture.addPointer();
        await gesture.moveTo(
          tester.getCenter(
            find.byKey(const ValueKey('task-browse-row-task-2')),
          ),
        );
        await tester.pump();

        expect(
          find.byKey(const ValueKey('task-browse-divider-task-1')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('task-browse-divider-slot-task-1')),
          findsOneWidget,
        );
      },
    );
  });
}
