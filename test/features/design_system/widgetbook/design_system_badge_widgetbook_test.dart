import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_badge_widgetbook.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('buildDesignSystemBadgeWidgetbookComponent', () {
    testWidgets('builds the badge overview use case', (tester) async {
      final component = buildDesignSystemBadgeWidgetbookComponent();
      final useCase = component.useCases.single;

      expect(component.name, 'Badges');
      expect(useCase.name, 'Overview');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.text('Type Scale'), findsOneWidget);
      expect(find.text('Status Matrix'), findsOneWidget);
      expect(find.text('Dot'), findsOneWidget);
      expect(find.text('Primary'), findsAtLeastNWidgets(1));
      expect(find.text('Outlined'), findsAtLeastNWidgets(1));
    });
  });
}
