import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';
import 'package:lotti/features/plaza/ui/checklist_ticks.dart';
import 'package:lotti/features/plaza/ui/task_side_panel.dart';

import '../../../widget_test_utils.dart';

void main() {
  final task = PlazaTask(
    id: 'p',
    createdAt: DateTime.utc(2026, 7),
    title: 'Confirm the interplanetary sardine cargo pods',
    state: PlazaTaskState.inProgress,
    progress: 0.25,
    checklistItems: 4,
    openChecklistItems: const ['Check bay two', 'Check the cold ring'],
    linkedTaskIds: const ['a', 'b', 'c', 'd', 'e'],
    categoryColor: 0xFFC9B458,
    due: DateTime.utc(2026, 7, 18),
  );
  final attention = attentionFor(task, DateTime.utc(2026, 7, 15));

  testWidgets('shows category, title, chip, meta and ticks items', (
    tester,
  ) async {
    final ticks = ChecklistTicks();
    var closed = 0;
    await tester.pumpWidget(
      makeTestableWidget2(
        Scaffold(
          body: Stack(
            children: [
              TaskSidePanel(
                attention: attention,
                categoryLabel: 'supplies',
                ticks: ticks,
                onClose: () => closed++,
              ),
            ],
          ),
        ),
        mediaQueryData: const MediaQueryData(size: Size(1200, 900)),
      ),
    );
    expect(find.text('SUPPLIES'), findsOneWidget);
    expect(
      find.text('Confirm the interplanetary sardine cargo pods'),
      findsOneWidget,
    );
    expect(find.text('IN PROGRESS'), findsOneWidget);
    expect(find.text('due Jul 18 · links 5'), findsOneWidget);

    await tester.tap(find.text('Check bay two'));
    await tester.pump();
    expect(ticks.isTicked('p', 0), isTrue);
    expect(
      tester.widget<Text>(find.text('Check bay two')).style?.decoration,
      TextDecoration.lineThrough,
    );
    // A tick from the wall shows here too.
    ticks.toggle('p', 1);
    await tester.pump();
    expect(
      tester.widget<Text>(find.text('Check the cold ring')).style?.decoration,
      TextDecoration.lineThrough,
    );

    await tester.tap(find.byTooltip('Close'));
    expect(closed, 1);
  });
}
