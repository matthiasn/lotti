import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/tasks/ui/model/task_browse_models.dart';
import 'package:lotti/features/tasks/ui/widgets/task_browse_list_item_rows.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_chips.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('SectionHeaderTitle', () {
    Future<void> pumpTitle(
      WidgetTester tester,
      TaskBrowseSectionKey sectionKey, {
      String? titleOverride,
    }) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SectionHeaderTitle(
            sectionKey: sectionKey,
            titleOverride: titleOverride,
          ),
        ),
      );
      await tester.pump();
    }

    const priorityTitles = {
      TaskPriority.p0Urgent: 'P0 Urgent',
      TaskPriority.p1High: 'P1 High',
      TaskPriority.p2Medium: 'P2 Medium',
      TaskPriority.p3Low: 'P3 Low',
    };

    for (final MapEntry(key: priority, value: title)
        in priorityTitles.entries) {
      testWidgets('priority section ${priority.short} reads "$title"', (
        tester,
      ) async {
        await pumpTitle(tester, TaskBrowseSectionKey.priority(priority));

        expect(find.text(title), findsOneWidget);
        final glyph = tester.widget<TaskShowcasePriorityGlyph>(
          find.byType(TaskShowcasePriorityGlyph),
        );
        expect(glyph.priority, priority);
      });
    }

    testWidgets('a title override replaces the derived label and glyph', (
      tester,
    ) async {
      await pumpTitle(
        tester,
        const TaskBrowseSectionKey.priority(TaskPriority.p3Low),
        titleOverride: 'Iceberg errands',
      );

      expect(find.text('Iceberg errands'), findsOneWidget);
      expect(find.text('P3 Low'), findsNothing);
      expect(find.byType(TaskShowcasePriorityGlyph), findsNothing);
    });

    testWidgets('a no-due-date section shows its label without a glyph', (
      tester,
    ) async {
      await pumpTitle(tester, const TaskBrowseSectionKey.noDueDate());

      expect(find.text('No due date'), findsOneWidget);
      expect(find.byType(TaskShowcasePriorityGlyph), findsNothing);
    });
  });
}
