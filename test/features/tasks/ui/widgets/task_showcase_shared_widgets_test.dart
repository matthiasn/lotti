import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_shared_widgets.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Widget wrap(Widget child) {
    return makeTestableWidget2(
      Theme(
        data: DesignSystemTheme.dark(),
        child: Scaffold(
          body: Center(child: child),
        ),
      ),
    );
  }

  Finder rootContainer(Finder widgetFinder) {
    return find.descendant(
      of: widgetFinder,
      matching: find.byWidgetPredicate(
        (widget) => widget is Container && widget.child is Row,
      ),
    );
  }

  group('Task showcase shared widgets', () {
    testWidgets('renders compact task detail chip heights', (tester) async {
      await tester.pumpWidget(
        wrap(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const TaskShowcaseCategoryChip(
                label: 'Work',
                icon: Icons.work_rounded,
                colorHex: '#4AB6E8',
              ),
              const SizedBox(height: 8),
              const TaskShowcaseMetaChip(
                icon: Icons.watch_later_outlined,
                label: 'Due: Apr 1, 2026',
              ),
              const SizedBox(height: 8),
              const TaskShowcaseLabelChip(
                label: 'Bug fix',
                color: Colors.blue,
                outlined: true,
              ),
              const SizedBox(height: 8),
              const TaskShowcaseSectionPill(
                icon: Icons.timer_outlined,
                label: 'Timer',
                active: true,
              ),
              const SizedBox(height: 8),
              TaskShowcaseStatusLabel(
                status: TaskStatus.open(
                  id: 'open',
                  createdAt: DateTime(2024),
                  utcOffset: 0,
                ),
                expanded: true,
              ),
            ],
          ),
        ),
      );

      expect(
        tester
            .getSize(
              rootContainer(
                find.widgetWithText(TaskShowcaseCategoryChip, 'Work'),
              ),
            )
            .height,
        18,
      );
      expect(
        tester
            .getSize(
              rootContainer(
                find.widgetWithText(TaskShowcaseMetaChip, 'Due: Apr 1, 2026'),
              ),
            )
            .height,
        20,
      );
      expect(
        tester
            .getSize(
              find.descendant(
                of: find.widgetWithText(TaskShowcaseLabelChip, 'Bug fix'),
                matching: find.byType(Container),
              ),
            )
            .height,
        20,
      );
      expect(
        tester
            .getSize(
              rootContainer(
                find.widgetWithText(TaskShowcaseSectionPill, 'Timer'),
              ),
            )
            .height,
        24,
      );
      expect(
        tester
            .getSize(
              rootContainer(
                find.widgetWithText(TaskShowcaseStatusLabel, 'Open'),
              ),
            )
            .height,
        28,
      );
    });

    testWidgets('renders TaskShowcaseStatusGlyph for all status types', (
      tester,
    ) async {
      final statuses = [
        TaskStatus.open(id: 's1', createdAt: DateTime(2024), utcOffset: 0),
        TaskStatus.groomed(id: 's2', createdAt: DateTime(2024), utcOffset: 0),
        TaskStatus.inProgress(
          id: 's3',
          createdAt: DateTime(2024),
          utcOffset: 0,
        ),
        TaskStatus.blocked(
          id: 's4',
          createdAt: DateTime(2024),
          utcOffset: 0,
          reason: 'blocked',
        ),
        TaskStatus.onHold(
          id: 's5',
          createdAt: DateTime(2024),
          utcOffset: 0,
          reason: 'on hold',
        ),
        TaskStatus.done(id: 's6', createdAt: DateTime(2024), utcOffset: 0),
        TaskStatus.rejected(id: 's7', createdAt: DateTime(2024), utcOffset: 0),
      ];

      await tester.pumpWidget(
        wrap(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final status in statuses)
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: TaskShowcaseStatusGlyph(status: status),
                ),
            ],
          ),
        ),
      );

      expect(
        find.byType(TaskShowcaseStatusGlyph),
        findsNWidgets(statuses.length),
      );
    });

    testWidgets('renders TaskShowcasePriorityGlyph for all priority levels', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TaskShowcasePriorityGlyph(priority: TaskPriority.p0Urgent),
              TaskShowcasePriorityGlyph(priority: TaskPriority.p1High),
              TaskShowcasePriorityGlyph(priority: TaskPriority.p2Medium),
              TaskShowcasePriorityGlyph(priority: TaskPriority.p3Low),
            ],
          ),
        ),
      );

      expect(find.byType(TaskShowcasePriorityGlyph), findsNWidgets(4));
    });
  });
}
