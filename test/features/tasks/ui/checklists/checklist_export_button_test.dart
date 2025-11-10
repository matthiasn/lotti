import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_widget.dart';

import '../../../../test_helper.dart';

void main() {
  testWidgets('shows export in overflow menu and triggers callback',
      (tester) async {
    var called = 0;

    await tester.pumpWidget(
      WidgetTestBench(
        mediaQueryData: const MediaQueryData(size: Size(1280, 1000)),
        child: ChecklistWidget(
          id: 'id',
          taskId: 'tid',
          title: 'Title',
          itemIds: const [],
          onTitleSave: (_) {},
          onCreateChecklistItem: (_) async => null,
          completionRate: 0.5,
          updateItemOrder: (_) async {},
          onExportMarkdown: () {
            called++;
          },
        ),
      ),
    );

    // Open overflow and tap Export
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export checklist as Markdown'));
    await tester.pump();

    expect(called, 1);
  });

  testWidgets('does not show export item when callback is null',
      (tester) async {
    await tester.pumpWidget(
      WidgetTestBench(
        mediaQueryData: const MediaQueryData(size: Size(1280, 1000)),
        child: ChecklistWidget(
          id: 'id',
          taskId: 'tid',
          title: 'Title',
          itemIds: const [],
          onTitleSave: (_) {},
          onCreateChecklistItem: (_) async => null,
          completionRate: 0,
          updateItemOrder: (_) async {},
          // onExportMarkdown is null here
        ),
      ),
    );

    // Opening overflow should not show Export
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Export checklist as Markdown'), findsNothing);
  });
}
