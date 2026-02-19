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

    Widget buildBody({
      List<String> itemIds = const [],
      double completionRate = 0,
    }) {
      return ProviderScope(
        child: WidgetTestBench(
          child: ChecklistCardBody(
            itemIds: itemIds,
            checklistId: 'checklist-1',
            taskId: 'task-1',
            filter: ChecklistFilter.openOnly,
            completionRate: completionRate,
            focusNode: focusNode,
            isCreatingItem: false,
            onCreateItem: (_) async {},
            onReorder: (_, __) {},
          ),
        ),
      );
    }

    testWidgets('empty list shows empty state, input field, and divider',
        (tester) async {
      await tester.pumpWidget(buildBody());

      expect(find.byType(ChecklistEmptyState), findsOneWidget);
      expect(find.text('No items yet'), findsOneWidget);
      expect(find.byType(TitleTextField), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('non-empty list shows ReorderableListView and input field',
        (tester) async {
      await tester.pumpWidget(
        buildBody(itemIds: ['item-1', 'item-2'], completionRate: 0.5),
      );

      expect(find.byType(ReorderableListView), findsOneWidget);
      expect(find.byType(TitleTextField), findsOneWidget);
      expect(find.byType(ChecklistEmptyState), findsNothing);
    });
  });

  group('ChecklistEmptyState', () {
    testWidgets('renders centered empty message', (tester) async {
      await tester.pumpWidget(
        const WidgetTestBench(child: ChecklistEmptyState()),
      );

      expect(find.text('No items yet'), findsOneWidget);
      expect(find.byType(Center), findsOneWidget);
    });
  });

  group('ChecklistAllDoneState', () {
    testWidgets('renders all done message', (tester) async {
      await tester.pumpWidget(
        const WidgetTestBench(child: ChecklistAllDoneState()),
      );

      expect(find.byType(ChecklistAllDoneState), findsOneWidget);
      expect(find.byType(Text), findsOneWidget);
    });
  });
}
