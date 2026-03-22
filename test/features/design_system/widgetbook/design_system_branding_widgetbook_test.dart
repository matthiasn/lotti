import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/branding/design_system_brand_logo.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_branding_widgetbook.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('buildDesignSystemBrandingWidgetbookComponent', () {
    testWidgets('builds the branding overview use case', (tester) async {
      final component = buildDesignSystemBrandingWidgetbookComponent();
      final useCase = component.useCases.single;

      expect(component.name, 'Branding');
      expect(useCase.name, 'Overview');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.byType(DesignSystemBrandLogo), findsOneWidget);
    });
  });
}
