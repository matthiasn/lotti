import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/motion/size_fade_entrance.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_card_body.dart';
import 'package:lotti/features/tasks/ui/checklists/consts.dart';

import '../../../../widget_test_utils.dart';

void main() {
  testWidgets('a newly inserted item is wired to the size entrance', (
    tester,
  ) async {
    var itemIds = <String>[];
    late StateSetter outerSetState;
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        StatefulBuilder(
          builder: (context, setState) {
            outerSetState = setState;
            return Body(
              itemIds: itemIds,
              checklistId: 'cl-1',
              taskId: 'task-1',
              filter: ChecklistFilter.all,
              completionRate: 0,
              activeTotalCount: itemIds.length,
              focusNode: focusNode,
              onCreateItem: (_) async {},
            );
          },
        ),
      ),
    );
    await tester.pump();

    outerSetState(() => itemIds = ['new-item']);
    await tester.pump();
    await tester.pump();

    final entranceWidget = tester.widget<SizeFadeEntrance>(
      find.byType(SizeFadeEntrance, skipOffstage: false),
    );
    expect(entranceWidget.animate, isTrue);
    final entrance = tester.widget<SizeTransition>(
      find.descendant(
        of: find.byType(SizeFadeEntrance, skipOffstage: false),
        matching: find.byType(SizeTransition, skipOffstage: false),
        skipOffstage: false,
      ),
    );
    expect(entrance.sizeFactor.value, 0);

    // The shared SizeFadeEntrance suite owns the tween geometry. Tear this
    // provider-heavy row down before unrelated async dependencies resolve.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('switching checklists resets tracking for later insertions', (
    tester,
  ) async {
    var checklistId = 'cl-1';
    var itemIds = <String>[];
    late StateSetter outerSetState;
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        StatefulBuilder(
          builder: (context, setState) {
            outerSetState = setState;
            return Body(
              itemIds: itemIds,
              checklistId: checklistId,
              taskId: 'task-1',
              filter: ChecklistFilter.all,
              completionRate: 0,
              activeTotalCount: itemIds.length,
              focusNode: focusNode,
              onCreateItem: (_) async {},
            );
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(SizeFadeEntrance), findsNothing);

    outerSetState(() {
      checklistId = 'cl-2';
    });
    await tester.pump();
    expect(find.byType(SizeFadeEntrance), findsNothing);

    outerSetState(() => itemIds = ['item-2']);
    await tester.pump();
    await tester.pump();

    final replacementEntrance = tester.widget<SizeFadeEntrance>(
      find.byKey(const ValueKey('row-cl-2-item-2'), skipOffstage: false),
    );
    expect(replacementEntrance.animate, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
