import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/headers/design_system_header.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_header_widgetbook.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('buildDesignSystemHeaderWidgetbookComponent', () {
    testWidgets('builds the header overview use case', (tester) async {
      final component = buildDesignSystemHeaderWidgetbookComponent();
      final useCase = component.useCases.single;

      expect(component.name, 'Header');
      expect(useCase.name, 'Overview');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );
      await tester.pump();

      expect(find.text('Variant Matrix'), findsOneWidget);
      expect(find.text('Figma default'), findsOneWidget);
      expect(find.text('Long title'), findsOneWidget);
      expect(find.text('API Configuration'), findsNWidgets(3));
      expect(find.text('API Documentation'), findsNWidgets(2));
      expect(find.byType(DesignSystemHeader), findsNWidgets(2));

      expect(tester.takeException(), isNull);
    });
  });
}
