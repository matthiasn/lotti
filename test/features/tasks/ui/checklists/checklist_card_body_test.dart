import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_card_body.dart';
import 'package:lotti/features/tasks/ui/checklists/consts.dart';
import 'package:lotti/features/tasks/ui/title_text_field.dart';

import '../../../../test_helper.dart';
import '../../../../widget_test_utils.dart';

void main() {
  group('ChecklistCardBody', () {
    late FocusNode focusNode;

    setUp(() async {
      await setUpTestGetIt();
      focusNode = FocusNode();
    });

    tearDown(() async {
      focusNode.dispose();
      await tearDownTestGetIt();
    });

    testWidgets('shows empty state when itemIds is empty', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: ChecklistCardBody(
              itemIds: const [],
              checklistId: 'checklist-1',
              taskId: 'task-1',
              filter: ChecklistFilter.openOnly,
              completionRate: 0,
              focusNode: focusNode,
              isCreatingItem: false,
              onCreateItem: (_) async {},
              onReorder: (_, __) {},
            ),
          ),
        ),
      );

      expect(find.byType(ChecklistEmptyState), findsOneWidget);
      expect(find.text('No items yet'), findsOneWidget);
    });

    testWidgets('shows add input field', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: ChecklistCardBody(
              itemIds: const [],
              checklistId: 'checklist-1',
              taskId: 'task-1',
              filter: ChecklistFilter.openOnly,
              completionRate: 0,
              focusNode: focusNode,
              isCreatingItem: false,
              onCreateItem: (_) async {},
              onReorder: (_, __) {},
            ),
          ),
        ),
      );

      expect(find.byType(TitleTextField), findsOneWidget);
    });

    testWidgets('shows divider between content and add input', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: ChecklistCardBody(
              itemIds: const [],
              checklistId: 'checklist-1',
              taskId: 'task-1',
              filter: ChecklistFilter.openOnly,
              completionRate: 0,
              focusNode: focusNode,
              isCreatingItem: false,
              onCreateItem: (_) async {},
              onReorder: (_, __) {},
            ),
          ),
        ),
      );

      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('shows ReorderableListView when items exist', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: ChecklistCardBody(
              itemIds: const ['item-1', 'item-2'],
              checklistId: 'checklist-1',
              taskId: 'task-1',
              filter: ChecklistFilter.openOnly,
              completionRate: 0.5,
              focusNode: focusNode,
              isCreatingItem: false,
              onCreateItem: (_) async {},
              onReorder: (_, __) {},
            ),
          ),
        ),
      );

      expect(find.byType(ReorderableListView), findsOneWidget);
    });
  });

  group('ChecklistEmptyState', () {
    testWidgets('renders empty state message', (tester) async {
      await tester.pumpWidget(
        const WidgetTestBench(
          child: ChecklistEmptyState(),
        ),
      );

      expect(find.text('No items yet'), findsOneWidget);
    });

    testWidgets('centers the message', (tester) async {
      await tester.pumpWidget(
        const WidgetTestBench(
          child: ChecklistEmptyState(),
        ),
      );

      expect(find.byType(Center), findsOneWidget);
    });
  });

  group('ChecklistAllDoneState', () {
    testWidgets('renders all done message', (tester) async {
      await tester.pumpWidget(
        const WidgetTestBench(
          child: ChecklistAllDoneState(),
        ),
      );

      // The message comes from localization, so check for the widget
      expect(find.byType(ChecklistAllDoneState), findsOneWidget);
      expect(find.byType(Text), findsOneWidget);
    });
  });
}
