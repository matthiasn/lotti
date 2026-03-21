import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_search_widgetbook.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('buildDesignSystemSearchWidgetbookComponent', () {
    testWidgets('builds the search overview use case', (tester) async {
      final component = buildDesignSystemSearchWidgetbookComponent();
      final useCase = component.useCases.single;

      expect(component.name, 'Search');
      expect(useCase.name, 'Overview');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.text('Size Scale'), findsOneWidget);
      expect(find.text('Filled'), findsOneWidget);
      expect(find.text('Type user'), findsAtLeastNWidgets(1));
      expect(find.text('Lotti search'), findsAtLeastNWidgets(1));
      expect(find.byType(DesignSystemSearch), findsNWidgets(4));
    });
  });
}
