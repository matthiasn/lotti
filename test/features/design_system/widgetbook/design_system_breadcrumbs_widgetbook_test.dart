import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/breadcrumbs/design_system_breadcrumbs.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_breadcrumbs_widgetbook.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('buildDesignSystemBreadcrumbsWidgetbookComponent', () {
    testWidgets('builds the breadcrumbs overview use case', (tester) async {
      final component = buildDesignSystemBreadcrumbsWidgetbookComponent();
      final useCase = component.useCases.single;

      expect(component.name, 'Breadcrumbs');
      expect(useCase.name, 'Overview');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.text('State Matrix'), findsOneWidget);
      expect(find.text('Breadcrumb Trail'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Breadcrumbs'), findsAtLeastNWidgets(1));
      expect(find.byType(DesignSystemBreadcrumbs), findsNWidgets(9));
    });
  });
}
