import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';

/// Verifies that all [DesignSystemListItem] widgets in the tree show dividers
/// between items but not after the last one.
void expectDividersOnAllButLast(WidgetTester tester) {
  final items = tester.widgetList<DesignSystemListItem>(
    find.byType(DesignSystemListItem),
  );
  expect(items, isNotEmpty, reason: 'Expected at least one list item');

  final dividerFlags = items.map((item) => item.showDivider).toList();
  for (var i = 0; i < dividerFlags.length - 1; i++) {
    expect(
      dividerFlags[i],
      isTrue,
      reason: 'Item $i should show divider',
    );
  }
  expect(dividerFlags.last, isFalse, reason: 'Last item has no divider');
}
