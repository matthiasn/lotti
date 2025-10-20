import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_widget.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../test_helper.dart';

void main() {
  testWidgets('shows export icon and triggers callback', (tester) async {
    var called = 0;

    await tester.pumpWidget(
      WidgetTestBench(
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

    final iconFinder = find.byIcon(MdiIcons.exportVariant);
    expect(iconFinder, findsOneWidget);

    await tester.tap(iconFinder);
    await tester.pump();

    expect(called, 1);
  });

  testWidgets('does not show export icon when callback is null',
      (tester) async {
    await tester.pumpWidget(
      WidgetTestBench(
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

    // No export icon should be rendered when callback is not provided
    expect(find.byIcon(MdiIcons.exportVariant), findsNothing);
  });
}
