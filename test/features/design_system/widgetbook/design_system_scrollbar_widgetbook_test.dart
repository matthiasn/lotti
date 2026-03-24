import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/scrollbars/design_system_scrollbar.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_scrollbar_widgetbook.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('buildDesignSystemScrollbarWidgetbookComponent', () {
    testWidgets('builds the scrollbar overview use case', (tester) async {
      final component = buildDesignSystemScrollbarWidgetbookComponent();
      final useCase = component.useCases.single;

      expect(component.name, 'Scrollbar');
      expect(useCase.name, 'Overview');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.text('Scrollbar Sizes'), findsOneWidget);
      expect(find.byType(DesignSystemScrollbar), findsNWidgets(2));
    });
  });
}
