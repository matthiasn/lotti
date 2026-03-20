import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_button_widgetbook.dart';
import 'package:widgetbook/widgetbook.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('buildDesignSystemWidgetbookFolder', () {
    testWidgets('builds the button overview use case and includes badges', (
      tester,
    ) async {
      final folder = buildDesignSystemWidgetbookFolder();
      final components = folder.children!
          .whereType<WidgetbookComponent>()
          .toList();
      final buttonComponent = components.singleWhere(
        (component) => component.name == 'Buttons',
      );
      final badgeComponent = components.singleWhere(
        (component) => component.name == 'Badges',
      );
      final chipComponent = components.singleWhere(
        (component) => component.name == 'Chips',
      );
      final useCase = buttonComponent.useCases.single;

      expect(folder.name, 'Design System');
      expect(components.map((component) => component.name), [
        'Buttons',
        'Badges',
        'Chips',
      ]);
      expect(badgeComponent.useCases.single.name, 'Overview');
      expect(chipComponent.useCases.single.name, 'Overview');
      expect(useCase.name, 'Overview');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.text('Size Scale'), findsOneWidget);
      expect(find.text('Variant Matrix'), findsOneWidget);
      expect(find.text('Medium'), findsOneWidget);

      await tester.tap(find.byType(DesignSystemButton).first);
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
