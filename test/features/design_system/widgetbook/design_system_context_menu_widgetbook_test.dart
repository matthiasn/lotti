import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_context_menu_widgetbook.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('buildDesignSystemContextMenuWidgetbookComponent', () {
    testWidgets('builds the context menu overview use case', (tester) async {
      final component = buildDesignSystemContextMenuWidgetbookComponent();
      final useCase = component.useCases.single;

      expect(component.name, 'Context menu');
      expect(useCase.name, 'Overview');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.text('Context Menu Variants'), findsOneWidget);
      expect(find.byType(DesignSystemContextMenu), findsNWidgets(3));
    });
  });
}
