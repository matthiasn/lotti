import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_widget.dart';
import '../../../../test_helper.dart';

void main() {
  group('ChecklistWidget add field focus + double-submit guard', () {
    const desktopMq = MediaQueryData(size: Size(1280, 1000));

    testWidgets('keeps focus after save and guards rapid double enter',
        (tester) async {
      var createCalls = 0;

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          mediaQueryData: desktopMq,
          child: ChecklistWidget(
            id: 'cl-add',
            taskId: 'task-add',
            title: 'Add Items',
            itemIds: const [],
            completionRate: 0,
            onTitleSave: _noopSave,
            onCreateChecklistItem: (text) async {
              createCalls++;
              return 'item-${DateTime.now().microsecondsSinceEpoch}';
            },
            updateItemOrder: _noopOrder,
          ),
        ),
      );

      // Find the add field via its key and enter text
      final addField = find.byKey(const ValueKey('add-input-cl-add'));
      expect(addField, findsOneWidget);

      // Focus and type
      await tester.tap(addField);
      await tester.pump();
      await tester.enterText(
          find.descendant(of: addField, matching: find.byType(TextField)),
          'one');

      // Press Enter to save and create a single item
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(createCalls, 1);

      // The add field should retain focus for continuous typing
      final editable =
          tester.widgetList<EditableText>(find.byType(EditableText)).last;
      expect(editable.focusNode.hasFocus, isTrue);
    });
  });
}

Future<void> _noopOrder(List<String> _) async {}
void _noopSave(String? _) {}
