import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_list_item_widgetbook.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('buildDesignSystemListItemWidgetbookComponent', () {
    testWidgets('builds the list item overview use case', (tester) async {
      final component = buildDesignSystemListItemWidgetbookComponent();
      final useCase = component.useCases.single;

      expect(component.name, 'List');
      expect(useCase.name, 'Overview');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.text('List Item Variants'), findsOneWidget);
      expect(
        find.byType(DesignSystemListItem),
        findsAtLeastNWidgets(5),
      );
    });
  });
}
