import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_item_widget.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_suggestions_widget.dart';

import '../../../../test_helper.dart';
import '../../../../widget_test_utils.dart';

void main() {
  group('ChecklistSuggestionsWidget UI Tests', () {
    testWidgets('ChecklistSuggestionsWidget renders correctly', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          // Wrap in ProviderScope to satisfy Riverpod dependencies
          child: WidgetTestBench(
            child: ChecklistSuggestionsWidget(itemId: 'test-id'),
          ),
        ),
      );

      // Widget should be created, even without providers set up
      expect(find.byType(ChecklistSuggestionsWidget), findsOneWidget);
    });

    testWidgets('ChecklistItemWidget renders correctly in suggestions context',
        (tester) async {
      // Create test item data
      const testItem = ChecklistItemData(
        title: 'Test suggestion',
        isChecked: false,
        linkedChecklists: [],
      );

      // Build a widget with a ChecklistItemWidget using proper localization
      // and a Material widget (provided by Scaffold in makeTestableWidgetWithScaffold)
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ChecklistItemWidget(
            title: testItem.title,
            isChecked: testItem.isChecked,
            onChanged: (_) {},
            readOnly: true,
            showEditIcon: false,
          ),
        ),
      );

      // Verify the ChecklistItemWidget is displayed correctly
      expect(find.byType(ChecklistItemWidget), findsOneWidget);

      // Verify the text appears somewhere in the widget tree
      expect(find.textContaining('Test suggestion'), findsWidgets);

      // Verify it's shown as read-only (not interactive)
      final checkbox =
          tester.widget<CheckboxListTile>(find.byType(CheckboxListTile));
      expect(checkbox.onChanged, isNull);
    });
  });
}
