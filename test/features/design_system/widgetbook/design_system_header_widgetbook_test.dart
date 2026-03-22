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

      expect(find.text('Desktop'), findsOneWidget);
      expect(find.text('Mobile'), findsOneWidget);
      expect(find.text('Figma default'), findsNothing);
      expect(find.text('Long title'), findsNothing);
      expect(find.text('Projects'), findsNWidgets(2));
      expect(find.text('API Configuration'), findsNothing);
      expect(find.text('API Documentation'), findsOneWidget);
      expect(find.text('Back'), findsNWidgets(2));
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.byType(DesignSystemHeader), findsOneWidget);

      expect(tester.takeException(), isNull);
    });
  });
}
