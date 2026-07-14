import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/tasks/ui/header/task_priority_modal_content.dart';

import '../../../../widget_test_utils.dart';

void main() {
  testWidgets('renders every priority in the shared row anatomy', (
    tester,
  ) async {
    await _pump(tester, current: TaskPriority.p1High, onSelected: (_) {});

    expect(find.byType(DesignSystemSelectionRow), findsNWidgets(4));
    expect(find.textContaining('P0 ·'), findsOneWidget);
    expect(find.textContaining('P1 ·'), findsOneWidget);
    expect(find.textContaining('P2 ·'), findsOneWidget);
    expect(find.textContaining('P3 ·'), findsOneWidget);
    expect(find.byType(Divider), findsNothing);
  });

  testWidgets('marks the current priority and reports a new choice', (
    tester,
  ) async {
    TaskPriority? selected;
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      current: TaskPriority.p1High,
      onSelected: (value) => selected = value,
    );

    final current = find.byKey(const ValueKey('task-priority-P1'));
    expect(
      tester.getSemantics(current).flagsCollection.isSelected,
      Tristate.isTrue,
    );
    expect(
      find.descendant(of: current, matching: find.byIcon(Icons.check_rounded)),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('task-priority-P3')));
    await tester.pump();
    expect(selected, TaskPriority.p3Low);
    handle.dispose();
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required TaskPriority current,
  required ValueChanged<TaskPriority> onSelected,
}) async {
  await tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      TaskPriorityModalContent(
        currentPriority: current,
        onSelected: onSelected,
      ),
    ),
  );
}
